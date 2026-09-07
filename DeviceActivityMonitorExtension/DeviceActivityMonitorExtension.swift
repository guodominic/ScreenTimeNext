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
        // A session alarm's interval starting means nothing — it is the END we care about, and its
        // start is 16 minutes earlier only because the platform requires a minimum length.
        guard activity.rawValue == MonitoringName.dailyActivity else { return }
        // A new day's window opened. The threshold's accrual starts over with it, so yesterday's
        // shield has to come down — this is the callback that gives a child their morning back.
        journal?.record(.intervalDidStart, activity: activity.rawValue)
        Enforcement.reconcileFromAppGroup()
    }

    /// D-047 — this is now the callback that matters most.
    ///
    /// A session's moments are schedules that END at them, so "3 minutes left" and "time's up"
    /// both arrive here, on the clock, with the app not running. The daily 00:00–23:59 window ends
    /// here too, which is why the name is checked rather than assumed.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let name = activity.rawValue

        if name == MonitoringName.sessionEnd {
            journal?.record(.thresholdReached, activity: name)
            Enforcement.reconcileFromAppGroup()
            return
        }

        if MonitoringName.isSessionWarning(name) {
            // Still time left, so the rule would take this straight back down — raise it directly.
            journal?.record(.warningBeforeThreshold, activity: name)
            Enforcement.raiseReminderShieldFromAppGroup()
            return
        }

        journal?.record(.intervalDidEnd, activity: name)
    }

    /// D-047 — only ONE threshold survives: the daily budget. Reminders moved to `intervalDidEnd`
    /// above, because a threshold measures usage and a reminder is a time.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
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
