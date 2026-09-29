#ifndef LEDGERFORGE_BACKGROUND_ACTIVITY_BRIDGE_H
#define LEDGERFORGE_BACKGROUND_ACTIVITY_BRIDGE_H
#include <stdbool.h>
#include <stdint.h>

// The bridge owns XPC state only. Swift owns persisted UTC targets, enrollment,
// due rules, clients and publication. Callback values contain no source data.
typedef void (^LFBackgroundStart)(uint64_t token, double targetUnix);
void lf_background_begin(double targetUnix, bool replaceCriteria, LFBackgroundStart start);
void lf_background_finish(uint64_t token, bool rearm, double nextTargetUnix);
// A Mach-control request temporarily suppresses idle exit while Swift owns
// accepted work. Its completion supplies the durable successor target.
void lf_background_control_begin(void);
void lf_background_control_finish(bool rearm, double nextTargetUnix);
// Used only when configuration has no ordinary clock target but a Mach
// control request may still arrive. It schedules one bounded idle exit.
void lf_background_wait_for_control(LFBackgroundStart start);
void lf_background_cancel(void);
#endif
