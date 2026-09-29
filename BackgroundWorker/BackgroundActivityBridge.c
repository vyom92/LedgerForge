#include "BackgroundActivityBridge.h"
#include <Block.h>
#include <dispatch/dispatch.h>
#include <math.h>
#include <os/log.h>
#include <stdlib.h>
#include <sys/time.h>
#include <xpc/xpc.h>

static const char *activityID = "com.vyom.LedgerForge.BackgroundWorker.updates";
static dispatch_queue_t stateQueue;
static dispatch_once_t once;
// Every mutable field below is accessed only on stateQueue. External Swift
// callbacks are asynchronous and never enter this queue synchronously.
static LFBackgroundStart startWork;
static xpc_activity_t continued;
static uint64_t delivery, idleEpoch, controlWork;
static double target;
static bool replacing, successorRequested;
static double successorTarget;
static os_log_t lifecycleLog;

static double nowUnix(void) {
    struct timeval value; gettimeofday(&value, NULL);
    return value.tv_sec + value.tv_usec / 1000000.0;
}
static void event(const char *name) {
    os_log_with_type(lifecycleLog, OS_LOG_TYPE_DEFAULT,
        "event=%{public}s token=%llu targetUTC=%.6f actualUTC=%.6f",
        name, (unsigned long long)delivery, target, nowUnix());
}
static void initialize(void) {
    dispatch_once(&once, ^{
        stateQueue = dispatch_queue_create("com.vyom.LedgerForge.BackgroundWorker.state", DISPATCH_QUEUE_SERIAL);
        lifecycleLog = os_log_create("com.vyom.LedgerForge.BackgroundWorker", "activity");
    });
}
static xpc_object_t criteria(void) {
    xpc_object_t value = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_bool(value, XPC_ACTIVITY_REPEATING, false);
    xpc_dictionary_set_int64(value, XPC_ACTIVITY_DELAY, (int64_t)fmax(0, ceil(target - nowUnix())));
    xpc_dictionary_set_int64(value, XPC_ACTIVITY_GRACE_PERIOD, 0);
    xpc_dictionary_set_string(value, XPC_ACTIVITY_PRIORITY, XPC_ACTIVITY_PRIORITY_UTILITY);
    return value;
}
static void idleExit(void) {
    // The qualified prototype exits after arming WAIT. Retain its bounded
    // handoff grace, guarded against a RUN that starts in the meantime. This
    // is a single idle-exit action, not a resident clock or polling loop.
    uint64_t epoch = ++idleEpoch;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), stateQueue, ^{
        if (epoch == idleEpoch && continued == NULL && controlWork == 0) { event("idle_exit"); exit(0); }
    });
}
static void checkIn(void);
static void requestCheckIn(void) {
    // xpc_activity_register may invoke its handler promptly. Never call it
    // while holding stateQueue because the handler serializes back to it.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ checkIn(); });
}
static void requestSuccessor(double nextTargetUnix) {
    if (!isfinite(nextTargetUnix)) return;
    if (!successorRequested || nextTargetUnix < successorTarget) successorTarget = nextTargetUnix;
    successorRequested = true;
}
static void armSuccessorIfIdle(void) {
    if (continued != NULL || !successorRequested) return;
    target = successorTarget; successorRequested = false; replacing = true;
    requestCheckIn();
}
static void handle(xpc_activity_t activity) {
    xpc_activity_state_t state = xpc_activity_get_state(activity);
    if (state == XPC_ACTIVITY_STATE_CHECK_IN) {
        xpc_object_t previous = xpc_activity_copy_criteria(activity);
        bool existing = previous != NULL && xpc_dictionary_get_count(previous) != 0;
        if (previous) xpc_release(previous);
        if (replacing || !existing) {
            xpc_object_t next = criteria();
            xpc_activity_set_criteria(activity, next); xpc_release(next);
            replacing = false; event("criteria_armed");
        } else { event("check_in_preserved"); }
        idleExit();
        return;
    }
    if (state != XPC_ACTIVITY_STATE_RUN || continued != NULL) return;
    ++idleEpoch; ++delivery;
    if (nowUnix() < target) {
        event("early_callback_rejected");
        if (!xpc_activity_set_state(activity, XPC_ACTIVITY_STATE_DONE)) { event("invalid_done"); exit(2); }
        requestSuccessor(target); armSuccessorIfIdle();
        return;
    }
    if (!xpc_activity_set_state(activity, XPC_ACTIVITY_STATE_CONTINUE)) { event("invalid_continue"); exit(2); }
    xpc_retain(activity); continued = activity;
    event("run_continued");
    startWork(delivery, target);
}
static void checkIn(void) {
    xpc_activity_register(activityID, XPC_ACTIVITY_CHECK_IN, ^(xpc_activity_t activity) {
        // XPC calls its handler on its own queue. Serializing our state does
        // not keep that queue or a thread lock across the Swift async work.
        dispatch_sync(stateQueue, ^{ handle(activity); });
    });
}
void lf_background_begin(double targetUnix, bool replaceCriteria, LFBackgroundStart start) {
    initialize();
    if (!isfinite(targetUnix) || start == NULL) exit(2);
    LFBackgroundStart copy = Block_copy(start);
    dispatch_async(stateQueue, ^{
        if (startWork) Block_release(startWork);
        startWork = copy; target = targetUnix; replacing = replaceCriteria;
        event("process_checked_in"); requestCheckIn();
    });
}
void lf_background_finish(uint64_t token, bool rearm, double nextTargetUnix) {
    initialize();
    dispatch_async(stateQueue, ^{
        if (token != delivery || continued == NULL) { event("stale_completion_ignored"); return; }
        xpc_activity_t completed = continued; continued = NULL;
        bool done = xpc_activity_set_state(completed, XPC_ACTIVITY_STATE_DONE);
        xpc_release(completed);
        event(done ? "run_done" : "invalid_done");
        if (!done) exit(2);
        bool hasSuccessor = successorRequested;
        if (rearm && isfinite(nextTargetUnix)) {
            requestSuccessor(nextTargetUnix); hasSuccessor = true;
        }
        if (hasSuccessor) { armSuccessorIfIdle(); }
        else { xpc_activity_unregister(activityID); idleExit(); }
    });
}
void lf_background_control_begin(void) {
    initialize();
    dispatch_async(stateQueue, ^{
        ++controlWork;
        // Invalidate any bounded idle exit that was armed after CHECK_IN.
        ++idleEpoch; event("control_accepted");
    });
}
void lf_background_control_finish(bool rearm, double nextTargetUnix) {
    initialize();
    dispatch_async(stateQueue, ^{
        if (controlWork == 0) { event("stale_control_completion_ignored"); return; }
        --controlWork;
        bool hasSuccessor = successorRequested;
        if (rearm && isfinite(nextTargetUnix)) {
            requestSuccessor(nextTargetUnix); hasSuccessor = true;
        }
        if (hasSuccessor) { armSuccessorIfIdle(); }
        else if (controlWork == 0 && continued == NULL) {
            idleExit();
        }
        event("control_finished");
    });
}
void lf_background_wait_for_control(LFBackgroundStart start) {
    initialize();
    if (start == NULL) exit(2);
    LFBackgroundStart copy = Block_copy(start);
    dispatch_async(stateQueue, ^{
        if (startWork) Block_release(startWork);
        startWork = copy;
        xpc_activity_unregister(activityID);
        event("control_wait"); idleExit();
    });
}
void lf_background_cancel(void) {
    initialize();
    dispatch_async(stateQueue, ^{
        ++idleEpoch;
        if (continued) {
            bool done = xpc_activity_set_state(continued, XPC_ACTIVITY_STATE_DONE);
            if (!done) event("cancel_invalid_done");
            xpc_release(continued); continued = NULL;
        }
        xpc_activity_unregister(activityID); event("cancelled"); exit(0);
    });
}
