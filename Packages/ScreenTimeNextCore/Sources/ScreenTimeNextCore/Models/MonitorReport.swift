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
