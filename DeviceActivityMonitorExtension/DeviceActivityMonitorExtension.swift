//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitorExtension
//
//  Task 010 — the process the system wakes when the daily budget threshold is crossed. PRD §14.
//
//  Everything about this file is shaped by one fact: it runs for a moment, in its own process,
//  usually while the app is not running, and is killed as soon as it returns (Rule 3). So:
//    · no async work, no timers, no waiting — anything not finished by the time these methods
//      return did not happen;
//    · no UI, no notifications scheduled from here (Task 016 owns those, from the app);
//    · the only way to speak to the app is the App Group (Rule 5), and the only thing written is
//      a callback name and a timestamp (§16 — never a token, never an app name).
//
//  Task 012 — this is now the process that RAISES the shield when the budget runs out. It is the
//  only one that can: the app is usually not running at that moment, which is the whole point.
//  The decision itself lives in `Enforcement.reconcile`, shared with the app, so "when is the
//  shield up" has exactly one answer in this codebase rather than one per process.

import DeviceActivity
import ScreenTimeNextCore

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    /// `nil` only when the App Group cannot be opened, which means provisioning is wrong and this
    /// extension had no way to reach the app in the first place.
    private let journal = MonitorJournal()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // A new day's window opened. The threshold's accrual starts over with it, so yesterday's
        // shield has to come down — this is the callback that gives a child their morning back.
        journal?.record(.intervalDidStart, activity: activity.rawValue)
        Enforcement.reconcileFromAppGroup()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        journal?.record(.intervalDidEnd, activity: activity.rawValue)
    }

    /// Two kinds of threshold arrive here (D-043), told apart by name because a name is all the
    /// system gives us and opening storage to answer "which one was that" would be work done in a
    /// process that may be killed the moment it returns.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        if MonitoringName.isWarningThreshold(event.rawValue) {
            // A reminder. The child is very likely INSIDE a covered app right now — that is why the
            // usage accrued — so this is the moment the heads-up is worth something. Raise the
            // shield directly: the rule would remove it, because there is still time left.
            journal?.record(.warningBeforeThreshold, activity: activity.rawValue)
            Enforcement.raiseReminderShieldFromAppGroup()
            return
        }

        // The one that ends it: today's budget is spent, and this is very likely the only process
        // of ours that is running.
        journal?.record(.thresholdReached, activity: activity.rawValue)
        Enforcement.reconcileFromAppGroup()
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        journal?.record(.warningBeforeIntervalEnds, activity: activity.rawValue)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        journal?.record(.warningBeforeThreshold, activity: activity.rawValue)
    }
}
