/* Network/clock bootstrap and diagnostics alongside hero-oslog. Drop as test.
 * Optional HERO_PROBE_FRONT captures a local RAW after stopping the rear test;
 * HERO_PROBE_CAMERA / HERO_PROBE_WEATHER open those apps for diagnosis.
 * HERO_TIMEZONE=Asia/Seoul opts into a persistent localtime-link correction.
 * No credentials, location requests, or TLS overrides. */
#import <Foundation/Foundation.h>
#include <spawn.h>
#include <arpa/inet.h>
#include <errno.h>
#include <dlfcn.h>
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
#include <signal.h>
#include <objc/message.h>
#include <notify.h>
#include <sys/mman.h>
#include <unistd.h>
#include "../../camera/hakios.camera.h"

extern char **environ;
static pid_t detail_logger = -1;

static int
signal_process(const char *name, int signal)
{
	int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL };
	size_t size = 0;
	if (sysctl(mib, 3, NULL, &size, NULL, 0))
		return 0;
	struct kinfo_proc *processes = malloc(size);
	int killed = 0;
	if (processes && !sysctl(mib, 3, processes, &size, NULL, 0))
		for (size_t i = 0; i < size / sizeof(*processes); i++)
			if (!strcmp(processes[i].kp_proc.p_comm, name))
				killed += kill(processes[i].kp_proc.p_pid, signal) == 0;
	free(processes);
	printf("hero-system-probe: signal %s %d: %d\n", name, signal, killed);
	return killed;
}

static void
restart_process(const char *name)
{
	(void)signal_process(name, SIGKILL);
}

static BOOL
open_application(NSString *bundle)
{
	dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
	dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
	Class cls = NSClassFromString(@"LSApplicationWorkspace");
	SEL workspaceSelector = NSSelectorFromString(@"defaultWorkspace");
	id workspace = [cls respondsToSelector:workspaceSelector] ?
	    ((id (*)(id, SEL))objc_msgSend)(cls, workspaceSelector) : nil;
	SEL open = NSSelectorFromString(@"openApplicationWithBundleID:");
	BOOL ok = [workspace respondsToSelector:open] &&
	    ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace, open, bundle);
	if (!ok) {
		void *sbs = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
		int (*launch)(CFStringRef, Boolean) = sbs ? dlsym(sbs, "SBSLaunchApplicationWithIdentifier") : NULL;
		if (launch) {
			int result = launch((__bridge CFStringRef)bundle, false);
			printf("hero-system-probe: SpringBoard launch %s result %d\n", bundle.UTF8String, result);
			ok = result == 0;
		}
	}
	printf("hero-system-probe: open %s %s (workspace %d)\n", bundle.UTF8String, ok ? "accepted" : "unavailable", workspace != nil);
	return ok;
}

static void
start_detail_logger(const char *processes, const char *words, const char *path, int seconds)
{
	char selected[256], filtered[256], duration[64];
	snprintf(selected, sizeof(selected), "HERO_OSLOG_PROCS=%s", processes);
	snprintf(filtered, sizeof(filtered), "HERO_OSLOG_WORDS=%s", words);
	snprintf(duration, sizeof(duration), "HERO_OSLOG_SECONDS=%d", seconds);
	/* Isolate private message decoding from the primary stable logger. */
	size_t count = 0, used = 0;
	while (environ[count]) count++;
	char **environment = calloc(count + 8, sizeof(char *));
	if (environment) {
		for (size_t i = 0; i < count; i++)
			if (strncmp(environ[i], "HERO_OSLOG_", 11))
				environment[used++] = environ[i];
		const char *settings[] = { duration, selected,
		    filtered, "HERO_OSLOG_MAX=3000",
		    "HERO_OSLOG_MAX_PROCESS=1500", "HERO_OSLOG_COMPOSED=1",
		    "HERO_OSLOG_EXCLUDE=Failed to start the workgroup,HALS_AHPPlugIn" };
		for (unsigned i = 0; i < sizeof(settings)/sizeof(settings[0]); i++)
			environment[used++] = (char *)settings[i];
		posix_spawn_file_actions_t actions;
		posix_spawn_file_actions_init(&actions);
		posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO,
		    path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
		posix_spawn_file_actions_adddup2(&actions, STDOUT_FILENO, STDERR_FILENO);
		char *args[] = { "/private/var/herolte/hero-oslog", NULL };
		int error = posix_spawn(&detail_logger, args[0], &actions, NULL, args, environment);
		printf("hero-system-probe: separate decoder spawn %d pid %d\n", error, detail_logger);
		posix_spawn_file_actions_destroy(&actions);
		free(environment);
	}
}

static void
open_photo(void)
{
	if (!getenv("HERO_PROBE_PHOTO"))
		return;
	start_detail_logger("Camera,mediaserverd,assetsd,photolibraryd,photoanalysisd",
	    "error,fail,jpeg,heif,heic,encode,save,photo,stillimage",
	    "/private/var/herolte/photo-compose.out", 200);
	/* App registration is still starting when this probe first runs. */
	sleep(45);
	restart_process("Camera");
	for (unsigned attempt = 0; attempt < 9; attempt++) {
		if (open_application(@"com.apple.camera")) {
			if (getenv("HERO_PROBE_SHUTTER")) {
				/* Diagnostic-only virtual volume-down tap. The kernel gates
				 * synthetic input behind herobot=1 and root. */
				sleep(15);
				const char *down = "k 2 1", *up = "k 2 0";
				int pressed = sysctlbyname("kern.notefe_hid", NULL, NULL, (void *)down, strlen(down));
				int press_error = pressed ? errno : 0;
				usleep(150000);
				int released = sysctlbyname("kern.notefe_hid", NULL, NULL, (void *)up, strlen(up));
				printf("hero-system-probe: diagnostic shutter key down %d errno %d up %d\n",
				    pressed, press_error, released);
			}
			break;
		}
		sleep(5);
	}
}

static void
open_weather(void)
{
	if (!getenv("HERO_PROBE_WEATHER"))
		return;
	if (getenv("HERO_WEATHER_COMPOSE"))
		start_detail_logger("Weather,weatherd", "error,fail,response,status",
		    "/private/var/herolte/weather-compose.out", 45);
	/* Retry after network/clock bootstrap, clearing the daemon's early-boot
	 * request state. The user's saved cities and settings stay intact. */
	restart_process("weatherd");
	restart_process("Weather");
	open_application(@"com.apple.weather");
}

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
bootstrap_clock(BOOL retry_network)
{
	if (!retry_network && time(NULL) >= 1577836800)
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
	/* A late network retry must not replace an already valid running clock
	 * with an older installation seed if SNTP is unavailable. */
	if (retry_network && time(NULL) >= 1577836800)
		return;
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
configure_timezone(void)
{
	const char *zone = getenv("HERO_TIMEZONE");
	if (!zone || strcmp(zone, "Asia/Seoul"))
		return;
	/* The phone's current localtime link was US/Pacific. Change the system
	 * timezone link, leaving Unix/UTC time untouched. Validate installed tzdata
	 * and preserve the old link before the opt-in change. */
	const char *path = "/private/var/db/timezone/localtime";
	const char *target = "/var/db/timezone/zoneinfo/Asia/Seoul";
	const char *temporary = "/private/var/db/timezone/localtime.herolte";
	char signature[4], previous[1024];
	int fd = open(target, O_RDONLY);
	ssize_t n = fd >= 0 ? read(fd, signature, sizeof(signature)) : -1;
	if (fd >= 0)
		close(fd);
	if (n != sizeof(signature) || memcmp(signature, "TZif", 4)) {
		printf("hero-system-probe: timezone: Seoul tzdata unavailable; no change\n");
		return;
	}
	n = readlink(path, previous, sizeof(previous) - 1);
	if (n < 0) {
		printf("hero-system-probe: timezone: cannot read current link: %s\n", strerror(errno));
		return;
	}
	previous[n] = 0;
	if (strcmp(previous, target)) {
		if (save_sample("/private/var/herolte/timezone-before.txt", previous, (size_t)n)) {
			printf("hero-system-probe: timezone: cannot back up current link\n");
			return;
		}
		unlink(temporary);
		if (symlink(target, temporary) || rename(temporary, path)) {
			printf("hero-system-probe: timezone: link update failed: %s\n", strerror(errno));
			unlink(temporary);
			return;
		}
		sync();
	}
	tzset();
	[NSTimeZone resetSystemTimeZone];
	notify_post("com.apple.system.timezone");
	NSTimeZone *system = NSTimeZone.systemTimeZone;
	printf("hero-system-probe: timezone %s offset %ld seconds (previous %s)\n",
	    system.name.UTF8String, (long)[system secondsFromGMT], previous);
}

static void
rear_close(int device)
{
	/* Other media descriptors may remain open while their process is
	 * suspended. Release the physical rear source explicitly. */
	struct hakios_camera_command select = { .command = HAKIOS_CAMERA_SENSOR, .a = 2, .b = ~0u };
	(void)write(device, &select, sizeof(select));
	close(device);
}

static void
rear_sample(void)
{
	if (!getenv("HERO_PROBE_REAR"))
		return;
	int supported = 0;
	size_t length = sizeof(supported);
	if (sysctlbyname("kern.herolte_rcam_device", &supported, &length, NULL, 0) || supported != 1) {
		printf("hero-system-probe: physical rear device API unavailable\n");
		return;
	}
	int device = open(HAKIOS_CAMERA_DEVICE, O_RDWR);
	struct hakios_camera_command select = { .command = HAKIOS_CAMERA_SENSOR, .a = 1, .b = ~0u };
	struct hakios_camera_frame header = { 0 };
	if (device < 0 || write(device, &select, sizeof(select)) != sizeof(select) ||
	    read(device, &header, sizeof(header)) != sizeof(header) ||
	    memcmp(header.magic, HAKIOS_CAMERA_MAGIC, 8) || header.header_bytes != sizeof(header) ||
	    header.sensor != 1 || header.width != 2016 || header.height != 1512 || header.stride != 2520 ||
	    header.format != 1 || header.bayer > 3) {
		printf("hero-system-probe: rear initialization/header failed: %s, sensor %u %ux%u stride %u\n",
		    strerror(errno), header.sensor, header.width, header.height, header.stride);
		if (device >= 0)
			rear_close(device);
		return;
	}
	/* File-backed storage avoids another full-frame anonymous allocation in
	 * this diagnostic process. Only publish a complete, validated read. */
	size_t size = header.header_bytes + (size_t)header.stride * header.height;
	const char *part = "/private/var/herolte/rear-sample.rwframe.part";
	int file = open(part, O_RDWR | O_CREAT | O_TRUNC, 0644), good = 0;
	void *map = MAP_FAILED;
	if (file >= 0 && !ftruncate(file, size))
		map = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, file, 0);
	uint64_t previous = header.sequence;
	if (map != MAP_FAILED) {
		for (int i = 0; i < 12; i++) {
			ssize_t n = read(device, map, size);
			struct hakios_camera_frame *frame = map;
			if (n != (ssize_t)size || memcmp(frame->magic, HAKIOS_CAMERA_MAGIC, 8) ||
			    frame->header_bytes != sizeof(header) || frame->sensor != 1 ||
			    frame->width != header.width || frame->height != header.height ||
			    frame->stride != header.stride || frame->sequence <= previous) {
				printf("hero-system-probe: rear frame %d invalid (%ld bytes): %s\n", i, (long)n, strerror(errno));
				good = 0;
				break;
			}
			previous = frame->sequence;
			good++;
		}
		if (good && (msync(map, size, MS_SYNC) || fsync(file)))
			good = 0;
		munmap(map, size);
	}
	if (file >= 0)
		close(file);
	rear_close(device);
	if (good && rename(part, "/private/var/herolte/rear-sample.rwframe"))
		good = 0;
	if (!good)
		unlink(part);
	printf("hero-system-probe: physical rear %ux%u stride %u Bayer %u: %d complete reads, sequence %llu, save %s\n",
	    header.width, header.height, header.stride, header.bayer, good, (unsigned long long)previous, good ? "OK" : "FAILED");
}

static void
front_capture(void)
{
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
	struct hakios_camera_command select = { .command = HAKIOS_CAMERA_SENSOR, .a = 2, .b = ~0u };
	if (write(device, &select, sizeof(select)) != sizeof(select)) {
		printf("hero-system-probe: front selection failed: %s\n", strerror(errno));
		close(device);
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
	const char *work = "/private/var/herolte/front-capture.work";
	int storage = open(work, O_RDWR | O_CREAT | O_TRUNC, 0644);
	void *buffer = MAP_FAILED;
	if (storage >= 0 && !ftruncate(storage, size))
		buffer = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, storage, 0);
	if (buffer != MAP_FAILED) {
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
		if (getenv("HERO_PROBE_FRONT_GAIN")) {
			const unsigned gains[] = { 32, 64, 32 };
			const char *paths[] = { "/private/var/herolte/front-gain32.rwframe",
			    "/private/var/herolte/front-gain64.rwframe", "/private/var/herolte/front-gain32-repeat.rwframe" };
			for (unsigned phase = 0; phase < 3; phase++) {
				struct hakios_camera_command control = { .command = HAKIOS_CAMERA_EXPOSURE,
				    .a = 512, .b = gains[phase], .c = header.frame_lines_min };
				int saved = -1;
				if (write(device, &control, sizeof(control)) == sizeof(control)) {
					for (int settle = 0; settle < 6; settle++)
						n = read(device, buffer, size);
					struct hakios_camera_frame *frame = buffer;
					if (n == (ssize_t)size && frame->sensor == 2 && frame->width == header.width &&
					    frame->height == header.height && frame->stride == header.stride &&
					    frame->header_bytes == sizeof(header) && frame->gain == gains[phase] && frame->exposure_lines == 512)
						saved = save_sample(paths[phase], buffer, size);
				}
				printf("hero-system-probe: front gain phase %u request %u/32 exposure 512: %s\n",
				    phase, gains[phase], saved == 0 ? "saved" : "FAILED");
			}
			struct hakios_camera_command restore = { .command = HAKIOS_CAMERA_EXPOSURE,
			    .a = header.exposure_lines, .b = header.gain, .c = header.frame_lines };
			(void)write(device, &restore, sizeof(restore));
		}
		munmap(buffer, size);
	}
	if (storage >= 0)
		close(storage);
	unlink(work);
	close(device);
}

static void
front_sample(void)
{
	if (!getenv("HERO_PROBE_FRONT"))
		return;
	sleep(45);
	restart_process("Camera");
	/* Killing media restarts its prewarming readers, which can change the
	 * global physical source between our header and frame reads. Suspend
	 * those readers while sampling, then always resume and restart them. */
	(void)signal_process("mediaserverd", SIGSTOP);
	@try {
		rear_sample();
		front_capture();
	} @finally {
		(void)signal_process("mediaserverd", SIGCONT);
	}
	restart_process("mediaserverd");
	if (getenv("HERO_PROBE_CAMERA")) {
		sleep(8);
		restart_process("Camera");
		open_application(@"com.apple.camera");
		int seconds = getenv("HERO_PROBE_CAMERA_SECONDS") ? atoi(getenv("HERO_PROBE_CAMERA_SECONDS")) : 15;
		sleep((unsigned)(seconds > 0 && seconds <= 45 ? seconds : 15));
	}
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

/* Change only Camera's Live Photo preference, through the mobile user's
 * CFPreferences service. Keep clock/device work in the privileged parent. */
static int
camera_live_off_child(void)
{
	CFStringRef domain = CFSTR("com.apple.camera"), key = CFSTR("CAMUserPreferenceDesiredIrisMode");
	CFTypeRef before = CFPreferencesCopyAppValue(key, domain);
	int off = 0;
	CFNumberRef value = CFNumberCreate(NULL, kCFNumberIntType, &off);
	CFPreferencesSetAppValue(key, value, domain);
	Boolean synced = CFPreferencesAppSynchronize(domain);
	CFTypeRef after = CFPreferencesCopyAppValue(key, domain);
	printf("hero-system-probe: mobile Camera Live Photo preference %s -> %s, sync %d uid %u\n",
	    before ? [(__bridge id)before description].UTF8String : "unset",
	    after ? [(__bridge id)after description].UTF8String : "unset", synced, getuid());
	if (before) CFRelease(before);
	if (after) CFRelease(after);
	CFRelease(value);
	return synced ? 0 : 1;
}

static void
configure_camera(void)
{
	if (!getenv("HERO_CAMERA_LIVE_PHOTO_OFF"))
		return;
	NSString *path = @"/private/var/mobile/Library/Preferences/com.apple.camera.plist";
	NSString *backup = @"/private/var/herolte/camera-preferences-before.plist";
	if (![[NSFileManager defaultManager] fileExistsAtPath:backup])
		[[NSData dataWithContentsOfFile:path] writeToFile:backup atomically:YES];
	pid_t child = fork();
	if (!child) {
		if (setgid(501) || setuid(501)) _exit(126);
		execl("/private/var/herolte/test", "hero-system-probe", "--camera-live-off", NULL);
		_exit(127);
	}
	if (child < 0) {
		printf("hero-system-probe: Camera preference child failed: %s\n", strerror(errno));
		return;
	}
	int status = 0;
	for (unsigned waited = 0; waited < 100; waited++) {
		if (waitpid(child, &status, WNOHANG) == child) {
			printf("hero-system-probe: Camera preference child status %#x\n", status);
			return;
		}
		usleep(100000);
	}
	kill(child, SIGKILL);
	waitpid(child, &status, 0);
	printf("hero-system-probe: Camera preference child timed out\n");
}

int
main(int argc, char **argv)
{
	@autoreleasepool {
		if (argc == 2 && !strcmp(argv[1], "--camera-live-off"))
			return camera_live_off_child();
		setvbuf(stdout, NULL, _IOLBF, 0);
		configure_camera();
		configure_timezone();
		printf("hero-system-probe: epoch %.0f, UTC %s\n", [NSDate date].timeIntervalSince1970,
		    [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]].UTF8String);
		char *args[] = { "/private/var/herolte/hero-oslog", NULL };
		pid_t logger = -1;
		int error = posix_spawn(&logger, args[0], NULL, NULL, args, environ);
		printf("hero-system-probe: logger spawn %d\n", error);
		/* Network is brought up independently during boot. Let it settle. */
		sleep(15);
		network_state();
		bootstrap_clock(NO);
		check_url(@"https://www.apple.com/library/test/success.html");
		check_url(@"https://weather-data.apple.com/");
		/* An HTTP rejection from this unauthenticated endpoint still proves
		 * DNS/TLS transport. It does not prove Weather's authenticated API works. */
		open_photo();
		front_sample();
		if (!getenv("HERO_PROBE_FRONT") && getenv("HERO_PROBE_NETWORK_WAIT")) {
			int seconds = atoi(getenv("HERO_PROBE_NETWORK_WAIT"));
			if (seconds > 90)
				seconds = 90;
			for (int waited = 0; waited < seconds; waited += 3) {
				struct ifaddrs *interfaces = NULL;
				BOOL ready = NO;
				if (!getifaddrs(&interfaces)) {
					for (struct ifaddrs *i = interfaces; i; i = i->ifa_next)
						if (i->ifa_addr && !strcmp(i->ifa_name, "en0") && i->ifa_addr->sa_family == AF_INET)
							ready = YES;
					freeifaddrs(interfaces);
				}
				if (ready)
					break;
				sleep(3);
			}
		}
		network_state();
		bootstrap_clock(YES);
		printf("hero-system-probe: late UTC %s\n", [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]].UTF8String);
		check_url(@"https://www.apple.com/library/test/success.html");
		check_url(@"https://weather-data.apple.com/");
		open_weather();
		if (error == 0) {
			int status = 0;
			waitpid(logger, &status, 0);
			printf("hero-system-probe: logger status %#x\n", status);
		}
		if (detail_logger > 0) {
			int status = 0;
			waitpid(detail_logger, &status, 0);
			printf("hero-system-probe: separate decoder status %#x\n", status);
		}
		sync();
	}
	return 0;
}
