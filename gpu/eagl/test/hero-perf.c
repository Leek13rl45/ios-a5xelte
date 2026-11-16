/* Opt-in CPU snapshots for the port. No scheduling or process changes.
 * PROC_PIDTASKINFO flavor/layout follows this XNU's bsd/sys/proc_info.h.
 * Its total CPU times are Mach ticks (fill_taskprocinfo), so compare them
 * to mach_absolute_time directly, not an assumed nanosecond clock. */
#include <mach/mach_time.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int proc_listallpids(void *, int);
int proc_name(int, void *, uint32_t);
int proc_pidinfo(int, int, uint64_t, void *, int);
struct task_snapshot {
    uint64_t virtual_size, resident_size, total_user, total_system, threads_user, threads_system;
    int32_t counters[12];
};
_Static_assert(sizeof(struct task_snapshot) == 96, "PROC_PIDTASKINFO ABI");
struct sample { int pid; uint64_t cpu, resident; char name[64]; };
static struct sample previous[2048], current[2048], ranked[2048];
static int descending(const void *a, const void *b)
{
    uint64_t x = ((const struct sample *)a)->cpu, y = ((const struct sample *)b)->cpu;
    return (x < y) - (x > y);
}
int main(int argc, char **argv)
{
    int seconds = argc == 2 ? atoi(argv[1]) : 240;
    if (seconds < 5 || seconds > 300) return 2;
    setvbuf(stdout, NULL, _IOLBF, 0);
    uint64_t last = 0, began = mach_absolute_time();
    unsigned old_count = 0;
    mach_timebase_info_data_t tb; mach_timebase_info(&tb);
    printf("hero-perf: read-only snapshots, CPU 100%% = one core; duration %d seconds\n", seconds);
    for (;;) {
        int pids[2048], count = proc_listallpids(pids, sizeof(pids));
        unsigned used = 0;
        uint64_t now = mach_absolute_time();
        double elapsed = (double)(now - began) * tb.numer / tb.denom / 1e9;
        for (int i = 0; i < count && i < 2048; i++) {
            struct task_snapshot info;
            if (pids[i] <= 0 || proc_pidinfo(pids[i], 4, 0, &info, sizeof(info)) != sizeof(info)) continue;
            struct sample *s = &current[used];
            memset(s, 0, sizeof(*s));
            s->pid = pids[i]; s->cpu = info.total_user + info.total_system; s->resident = info.resident_size;
            proc_name(s->pid, s->name, sizeof(s->name));
            ranked[used] = *s; ranked[used].cpu = 0;
            for (unsigned j = 0; j < old_count; j++)
                if (previous[j].pid == s->pid && !strcmp(previous[j].name, s->name)) {
                    if (s->cpu >= previous[j].cpu) ranked[used].cpu = s->cpu - previous[j].cpu;
                    break;
                }
            used++;
        }
        if (last && now > last) {
            qsort(ranked, used, sizeof(ranked[0]), descending);
            printf("hero-perf: elapsed %.1f seconds; %u tasks\n", elapsed, used);
            for (unsigned i = 0; i < used && i < 8; i++)
                printf("hero-perf: pid %d %s CPU %.1f%% resident %.1f MiB\n", ranked[i].pid,
                    ranked[i].name, 100.0 * ranked[i].cpu / (now - last), ranked[i].resident / 1048576.0);
        }
        memcpy(previous, current, used * sizeof(current[0])); old_count = used; last = now;
        if (elapsed >= seconds) break;
        sleep(5);
    }
    return 0;
}
