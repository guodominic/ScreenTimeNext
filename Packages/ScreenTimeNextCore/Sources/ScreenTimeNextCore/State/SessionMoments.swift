//  SessionMoments.swift
//  ScreenTimeNextCore
//
//  D-056 — when each of a session's alarms is DUE, recomputed from the window as it stands now.
//
//  Why this has to exist. A session's alarms are wall-clock schedules registered when the session
//  starts (D-047). The window's end then MOVES: a transition screen pauses the clock (D-050), a
//  parent adds or takes back minutes (D-052). The alarms cannot move themselves — they were set by
//  a process that is long gone — so every alarm that arrives is a question, not an answer:
//  *is this still due?*
//
//  D-050 gave that check to the session-end alarm only, on the reasoning that "an early alarm is
//  self-correcting". It is not, and the reminders never got the check at all. A reminder alarm made
//  early by a pause raised a shield that was not due, the child dismissed it, the dismissal paid
//  back more paused time, the end moved again — and the countdown drifted while transition screens
//  appeared at times that matched nothing. That is the loop this closes.
//
//  Framework-free (Foundation only), because the process that needs the answer is an extension.

import Foundation

public enum SessionMoments {

    /// How far off its due time an alarm may be and still count as on time.
    ///
    /// Generous in the LATE direction by construction (a late alarm is still due), and this only
    /// bounds the early side. Twenty seconds absorbs ordinary scheduling jitter without letting a
    /// pause of any real length through.
    public static let toleranceSeconds: TimeInterval = 20

    /// When the alarm named `name` should fire for this window, or nil if the name is not one of
    /// this session's moments — or names a reminder the configuration no longer has.
    public static func due(for name: String,
                           window: SessionWindow,
                           configuration: ScreenTimeConfiguration) -> Date? {
        if name == MonitoringName.sessionEnd { return window.endsAt }
        guard let index = MonitoringName.warningIndex(of: name) else { return nil }
        let offsets = configuration.effectiveWarningOffsets(forWindowSeconds: window.totalSeconds)
        guard offsets.indices.contains(index) else { return nil }
        return window.endsAt.addingTimeInterval(-TimeInterval(offsets[index]))
    }

    /// True when this alarm has arrived EARLY — the window's end moved after it was set.
    ///
    /// An early alarm must not act. It should re-arm the session from the current window and get
    /// out of the way; the replacement will arrive at the right moment.
    public static func isEarly(_ name: String,
                               window: SessionWindow,
                               configuration: ScreenTimeConfiguration,
                               now: Date = Date()) -> Bool {
        guard let due = due(for: name, window: window, configuration: configuration) else { return false }
        return now < due.addingTimeInterval(-toleranceSeconds)
    }
}
