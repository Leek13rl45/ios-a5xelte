/* Runtime regression: nested local uses, cross-process visibility and
 * cleanup when a client exits without balancing its use contribution. */
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurfaceRef.h>
#include <spawn.h>
#include <poll.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
extern char **environ;
static int failures;
static void check(IOSurfaceRef surface, const char *step, int count, bool active)
{
    int actual = IOSurfaceGetUseCount(surface);
    bool used = IOSurfaceIsInUse(surface);
    bool ok = actual == count && used == active;
    printf("surface-use-probe: %s local %d expected %d in-use %d expected %d: %s\n",
        step, actual, count, used, active, ok ? "OK" : "FAIL");
    failures += !ok;
}
int main(int argc, char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        if (argc == 3 && !strcmp(argv[1], "--child")) {
            IOSurfaceRef surface = IOSurfaceLookup((IOSurfaceID)strtoul(argv[2], NULL, 10));
            char ready = surface ? 1 : 0;
            if (surface) IOSurfaceIncrementUseCount(surface);
            (void)write(3, &ready, 1);
            if (!surface) return 3;
            for (;;) pause();
        }
        IOSurfaceRef surface = IOSurfaceCreate((__bridge CFDictionaryRef)@{
            (__bridge NSString *)kIOSurfaceWidth: @16,
            (__bridge NSString *)kIOSurfaceHeight: @16,
            (__bridge NSString *)kIOSurfaceBytesPerElement: @4,
            (__bridge NSString *)kIOSurfaceBytesPerRow: @64,
            (__bridge NSString *)kIOSurfaceAllocSize: @4096,
            (__bridge NSString *)kIOSurfacePixelFormat: @((uint32_t)'BGRA')
        });
        if (!surface) { printf("surface-use-probe: create FAILED\n"); return 2; }
        check(surface, "initial", 0, false);
        IOSurfaceIncrementUseCount(surface); check(surface, "increment", 1, true);
        IOSurfaceIncrementUseCount(surface); check(surface, "nested increment", 2, true);
        IOSurfaceDecrementUseCount(surface); check(surface, "nested decrement", 1, true);
        IOSurfaceDecrementUseCount(surface); check(surface, "balanced", 0, false);
        IOSurfaceDecrementUseCount(surface); check(surface, "extra decrement", 0, false);
        int ready[2];
        if (pipe(ready)) { CFRelease(surface); return 4; }
        char number[32]; snprintf(number, sizeof(number), "%u", IOSurfaceGetID(surface));
        posix_spawn_file_actions_t actions; posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_addclose(&actions, ready[0]);
        posix_spawn_file_actions_adddup2(&actions, ready[1], 3);
        if (ready[1] != 3) posix_spawn_file_actions_addclose(&actions, ready[1]);
        char *args[] = { "/private/var/herolte/hero-surface-use-probe", "--child", number, NULL };
        pid_t child = -1;
        int error = posix_spawn(&child, args[0], &actions, NULL, args, environ);
        posix_spawn_file_actions_destroy(&actions); close(ready[1]);
        struct pollfd wait = { .fd = ready[0], .events = POLLIN };
        char value = 0;
        if (!error && poll(&wait, 1, 3000) > 0 && read(ready[0], &value, 1) == 1 && value)
            check(surface, "other process active", 0, true);
        else { printf("surface-use-probe: other process FAILED spawn %d\n", error); failures++; }
        close(ready[0]);
        if (!error) {
            int status; kill(child, SIGKILL); waitpid(child, &status, 0);
            for (unsigned i = 0; i < 100 && IOSurfaceIsInUse(surface); i++) usleep(20000);
            check(surface, "other process killed", 0, false);
        }
        CFRelease(surface);
        printf("surface-use-probe: %d failures\n", failures);
        return failures ? 1 : 0;
    }
}
