//  MonitorReport.swift
//  ScreenTimeNextCore
//
//  Task 010 — what the DeviceActivityMonitor extension has to say for itself.
//
//  The extension runs in its own process, for a few hundred milliseconds, possibly while the app is
//  not running at all (PRD §14). It cannot call the app, so the only thing it can do is leave a
//  note in the shared container and let the app find it later. This is that note.
//
//  §16: an entry carries a callback name, an activity name we chose ourselves, and a timestamp.
//  Never a token, never an app name — the extension knows which apps tripped the threshold and
//  must not write that down anywhere.

import Foundation

/// One callback the extension received.
public struct MonitorReport: Codable, Equatable, Sendable {

    /// The `DeviceActivityMonitor` callbacks we override, by the name Apple gives them.
    public enum Event: String, Codable, CaseIterable, Sendable {
        case intervalDidStart
        case intervalDidEnd
        case thresholdReached
        case warningBeforeIntervalEnds
        case warningBeforeThreshold

        // D-049 — what the child was actually SHOWN. The shield is drawn in a third process that
        // nothing else can see into, so "the reminder fired" and "the child saw the reminder" were
        // two different claims and we could only check the first. Now both are on the dashboard.
        case shieldShownReminder
        case shieldShownChooser
        case shieldShownFinished
        case shieldShownSpent

        /// D-055 — iOS asked the configuration extension for a screen. Recorded before any work,
        /// so its absence beside a raised shield means the extension never ran at all.
        case shieldExtensionEntered

        /// D-056 — an alarm arrived before its moment, because the window's end moved after it was
        /// set. Recorded rather than acted on, so the drift is visible instead of silent.
        case staleAlarmIgnored

        /// D-058 — the alarm was due and we tried, but there was nothing to cover: no selection, no
        /// Screen Time access, or a selection that would not decode. The shield did NOT go up.
        case shieldNotRaisedNothingCovered
    }

    public let event: Event
    /// Our own activity name (`MonitoringName.dailyActivity`), not anything of the child's.
    public let activity: String
    public let at: Date

    public init(event: Event, activity: String, at: Date) {
        self.event = event
        self.activity = activity
        self.at = at
    }
}
