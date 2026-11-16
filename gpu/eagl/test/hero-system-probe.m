/* Network/clock bootstrap and diagnostics alongside hero-oslog. Drop as test.
 * Optional HERO_PROBE_FRONT captures a local RAW after stopping the rear test.
 * No credentials, location requests, or TLS overrides. */
#import <Foundation/Foundation.h>
#include <spawn.h>
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <ifaddrs.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include "../../camera/hakios.camera.h"

extern char **environ;

static void
network_state(void)
{
	struct ifaddrs *list = NULL;
	if (getifaddrs(&list))
		return;
	for (struct ifaddrs *i = list; i; i = i->ifa_next) {
		if (!i->ifa_addr || (i->ifa_addr->sa_family != AF_INET && i->ifa_addr->sa_family != AF_INET6))
			continue;
		char address[NI_MAXHOST];
		if (!getnameinfo(i->ifa_addr, i->ifa_addr->sa_len, address, sizeof(address), NULL, 0, NI_NUMERICHOST))
			printf("hero-system-probe: interface %s flags %#x address %s\n", i->ifa_name, i->ifa_flags, address);
	}
	freeifaddrs(list);
}

static void
bootstrap_clock(void)
{
	if (time(NULL) >= 1577836800)
		return;
	/* Prefer a real network clock. Validate server mode, synchronization,
	 * stratum and echoed origin token before accepting a reply. */
	struct addrinfo hints = { .ai_family = AF_INET, .ai_socktype = SOCK_DGRAM }, *list = NULL;
	if (getaddrinfo("time.apple.com", "123", &hints, &list) == 0) {
		int tried = 0;
		for (struct addrinfo *a = list; a && tried++ < 2; a = a->ai_next) {
			int fd = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
			if (fd < 0)
				continue;
			struct timeval timeout = { .tv_sec = 3 };
			setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
			unsigned char query[48] = { 0x23 }, reply[512];
			arc4random_buf(query + 40, 8);
			ssize_t n = -1;
			if (connect(fd, a->ai_addr, a->ai_addrlen) == 0 && send(fd, query, sizeof(query), 0) == sizeof(query))
				n = recv(fd, reply, sizeof(reply), 0);
			close(fd);
			if (n < 48 || (reply[0] & 7) != 4 || (reply[0] >> 6) == 3 || !reply[1] || reply[1] > 15 ||
			    memcmp(reply + 24, query + 40, 8))
				continue;
			uint32_t seconds, fraction;
			memcpy(&seconds, reply + 40, 4);
			memcpy(&fraction, reply + 44, 4);
			double epoch = (double)ntohl(seconds) - 2208988800.0 + (double)ntohl(fraction) / 4294967296.0;
			if (epoch < 1577836800 || epoch > 2085978495)
				continue;
			struct timeval now = { .tv_sec = (time_t)epoch, .tv_usec = (suseconds_t)((epoch - (time_t)epoch) * 1e6) };
			int result = settimeofday(&now, NULL);
			printf("hero-system-probe: network clock %.0f set %s\n", epoch, result == 0 ? "OK" : strerror(errno));
			if (!result) {
				freeaddrinfo(list);
				return;
			}
		}
		freeaddrinfo(list);
	}
	/* A fresh host-generated UTC seed is a diagnostic fallback when network
	 * time is not yet reachable. It is refreshed for each installation. */
	FILE *f = fopen("/private/var/herolte/clock.seed", "r");
	long long seed = 0;
	if (f) {
		if (fscanf(f, "%lld", &seed) != 1)
			seed = 0;
		fclose(f);
	}
	if (seed >= 1577836800 && seed < 2085978495) {
		struct timespec uptime;
		clock_gettime(CLOCK_MONOTONIC, &uptime);
		struct timeval now = { .tv_sec = (time_t)seed + uptime.tv_sec };
		int result = settimeofday(&now, NULL);
		printf("hero-system-probe: host UTC seed %lld set %s\n", seed, result == 0 ? "OK" : strerror(errno));
	}
}

static int
save_sample(const char *path, const void *buffer, size_t size)
{
	int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
	if (fd < 0)
		return -1;
	size_t done = 0;
	while (done < size) {
		ssize_t n = write(fd, (const char *)buffer + done, size - done);
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0)
			break;
		done += (size_t)n;
	}
	int result = done == size && fsync(fd) == 0 ? 0 : -1;
	close(fd);
	return result;
}

static void
front_sample(void)
{
	if (!getenv("HERO_PROBE_FRONT"))
		return;
	/* hero-run's rear-camera test starts at 45 s. This probe starts at 20 s;
	 * wait until it has stopped, then restore its shared resources first. */
	sleep(45);
	int off = 0, level = 7;
	if (sysctlbyname("kern.herolte_rcam", NULL, NULL, &off, sizeof(off))) {
		printf("hero-system-probe: rear power-down failed: %s; front sample skipped\n", strerror(errno));
		return;
	}
	if (sysctlbyname("kern.notefe_cam", NULL, NULL, &level, sizeof(level))) {
		printf("hero-system-probe: front initialization failed: %s\n", strerror(errno));
		return;
	}
	int device = open(HAKIOS_CAMERA_DEVICE, O_RDWR);
	if (device < 0) {
		printf("hero-system-probe: front open: %s\n", strerror(errno));
		return;
	}
	struct hakios_camera_frame header = { 0 };
	ssize_t n = read(device, &header, sizeof(header));
	if (n != sizeof(header) || memcmp(header.magic, HAKIOS_CAMERA_MAGIC, 8) ||
	    header.header_bytes != sizeof(header) || header.sensor != 2 ||
	    !header.width || !header.height || header.width > 4032 || header.height > 3024 ||
	    header.stride < header.width * 5 / 4 || header.stride > header.width * 4) {
		printf("hero-system-probe: unexpected front frame header (%ld bytes)\n", (long)n);
		close(device);
		return;
	}
	size_t size = header.header_bytes + (size_t)header.stride * header.height;
	void *buffer = malloc(size);
	if (buffer) {
		/* Preserve the kernel header plus packed RAW10, before color processing. */
		int result = -1;
		for (int i = 0; i < 5; i++) {
			n = read(device, buffer, size);
			if (n == (ssize_t)size) {
				struct hakios_camera_frame *frame = buffer;
				if (frame->sensor == 2 && frame->header_bytes == header.header_bytes &&
				    frame->width == header.width && frame->height == header.height && frame->stride == header.stride)
					result = save_sample("/private/var/herolte/front-sample.rwframe", buffer, size);
			}
		}
		printf("hero-system-probe: front RAW sample %ux%u stride %u Bayer %u, save %s\n",
		    header.width, header.height, header.stride, header.bayer, result == 0 ? "OK" : "FAILED");
		free(buffer);
	}
	close(device);
}

static void
check_url(NSString *address)
{
	NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	config.timeoutIntervalForRequest = 12;
	config.timeoutIntervalForResource = 15;
	config.HTTPCookieStorage = nil;
	config.URLCache = nil;
	NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
	dispatch_semaphore_t done = dispatch_semaphore_create(0);
	__block NSData *body;
	__block NSURLResponse *reply;
	__block NSError *failure;
	NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:address]
	    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		body = data;
		reply = response;
		failure = error;
		dispatch_semaphore_signal(done);
	}];
	[task resume];
	if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 17 * NSEC_PER_SEC))) {
		[task cancel];
		printf("hero-system-probe: %s TIMEOUT\n", address.UTF8String);
	} else {
		NSInteger status = [reply isKindOfClass:NSHTTPURLResponse.class] ? [(NSHTTPURLResponse *)reply statusCode] : 0;
		printf("hero-system-probe: %s HTTP %ld bytes %lu error %s/%ld: %.600s\n", address.UTF8String,
		    (long)status, (unsigned long)body.length, failure.domain.UTF8String ?: "none", (long)failure.code,
		    failure.localizedDescription.UTF8String ?: "none");
		NSError *underlying = failure.userInfo[NSUnderlyingErrorKey];
		if (underlying)
			printf("hero-system-probe: underlying %s/%ld: %.600s\n", underlying.domain.UTF8String,
			    (long)underlying.code, underlying.localizedDescription.UTF8String);
	}
	[session invalidateAndCancel];
}

int
main(void)
{
	@autoreleasepool {
		setvbuf(stdout, NULL, _IOLBF, 0);
		printf("hero-system-probe: epoch %.0f, UTC %s\n", [NSDate date].timeIntervalSince1970,
		    [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]].UTF8String);
		char *args[] = { "/private/var/herolte/hero-oslog", NULL };
		pid_t logger = -1;
		int error = posix_spawn(&logger, args[0], NULL, NULL, args, environ);
		printf("hero-system-probe: logger spawn %d\n", error);
		/* Network is brought up independently during boot. Let it settle. */
		sleep(15);
		network_state();
		bootstrap_clock();
		check_url(@"https://www.apple.com/library/test/success.html");
		check_url(@"https://weather-data.apple.com/");
		/* An HTTP rejection from this unauthenticated endpoint still proves
		 * DNS/TLS transport. It does not prove Weather's authenticated API works. */
		front_sample();
		network_state();
		bootstrap_clock();
		printf("hero-system-probe: late UTC %s\n", [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]].UTF8String);
		check_url(@"https://www.apple.com/library/test/success.html");
		check_url(@"https://weather-data.apple.com/");
		if (error == 0) {
			int status = 0;
			waitpid(logger, &status, 0);
			printf("hero-system-probe: logger status %#x\n", status);
		}
	}
	return 0;
}
