//  ScreenTimeConfiguration.swift
//  ScreenTimeNextCore
//
//  PRD §12, §6.5, §6.6 — parent-configured settings. D-013: warnings are up to three configurable
//  offsets (minutes before the end) instead of fixed 10/5/1 toggles; budget is a 2–120 minute dial.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

import Foundation

public struct ScreenTimeConfiguration: Codable, Equatable, Sendable {

    /// Daily budget in SECONDS (PRD §12). Convert to minutes at the presentation layer only.
    /// Always clamped to `budgetRangeSeconds`, however it is set.
    public var dailyBudgetSeconds: Int {
        get { storedBudgetSeconds }
        set { storedBudgetSeconds = Self.clampBudget(newValue) }
    }

    /// Seconds before the end at which to warn. Always normalized — unique, clamped to
    /// `warningOffsetRange`, sorted descending (earliest first), at most `maxWarnings` — however it
    /// is set, so no caller can leave an impossible configuration behind. Empty = no warnings; the
    /// "finished" notification is always sent.
    public var warningOffsetsSeconds: [Int] {
        get { storedWarningOffsets }
        set { storedWarningOffsets = Self.normalizedOffsets(newValue) }
    }

    private var storedBudgetSeconds: Int
    private var storedWarningOffsets: [Int]

    /// The activities the parent approved for the child to choose from. PRD §6.7.
    public var selectedActivities: [TransitionActivity]

    // MARK: Ranges (D-013)

    /// D-034 — 1 to 90 minutes, one minute at a time, everywhere.
    ///
    /// The two-minute step above fifteen was a compromise for dragging a dial across a long range,
    /// and it cost the thing that actually matters: a parent saying "twenty-three minutes, then
    /// dinner" could not set twenty-three. 120 was a number nobody uses — a session that long is a
    /// different decision, not a longer version of this one — so the range shrank and the dial
    /// stays comfortable to drag.
    public static let budgetRangeSeconds = 60...5400
    public static let budgetStepSeconds = 60
    public static let defaultBudgetSeconds = 900

    /// Each warning: 1–15 minutes before the end (0 in the UI means "off").
    public static let warningOffsetRange = 60...900
    public static let warningStepSeconds = 60
    /// D-044 — TWO reminders, not three. The shield made the count a product decision rather than
    /// a preference: a child using a covered app meets three full-screen interruptions in one
    /// session (heads-up, choose what's next, time's up), and a fourth is nagging. The third
    /// interruption is the end itself, which is not a dial.
    public static let maxWarnings = 2
    public static let defaultWarningOffsets = [300, 60]

    public init(
        dailyBudgetSeconds: Int = ScreenTimeConfiguration.defaultBudgetSeconds,
        warningOffsetsSeconds: [Int] = ScreenTimeConfiguration.defaultWarningOffsets,
        selectedActivities: [TransitionActivity] = []
    ) {
        self.storedBudgetSeconds = Self.clampBudget(dailyBudgetSeconds)
        self.storedWarningOffsets = Self.normalizedOffsets(warningOffsetsSeconds)
        self.selectedActivities = selectedActivities
    }

    public static let `default` = ScreenTimeConfiguration()

    // MARK: Normalization

    public static func clampBudget(_ seconds: Int) -> Int {
        min(max(seconds, budgetRangeSeconds.lowerBound), budgetRangeSeconds.upperBound)
    }

    /// Sensible reminder defaults for a budget (D-013):
    /// ≥ 12 min → 10 / 5 / 1; 4–11 min → halfway + last minute; 2–3 min → last minute only.
    public static func defaultWarningOffsets(forBudgetSeconds budget: Int) -> [Int] {
        let minutes = budget / 60
        // D-044 — two, and the last one is always the final minute: that is the one the child acts
        // on. The first is spaced off the budget so a 15-minute session does not get its heads-up
        // before it has really started.
        if minutes >= 12 { return [300, 60] }
        if minutes >= 4 { return [(minutes / 2) * 60, 60] }
        return [60]
    }

    /// The reminders that can actually fire for a window of `windowSeconds`: strictly shorter than
    /// the window (a reminder at or beyond the window's length would fire at Start or never).
    /// Every consumer — engine, notifications, UI summaries — must use this, never the raw list.
    public func effectiveWarningOffsets(forWindowSeconds windowSeconds: Int) -> [Int] {
        warningOffsetsSeconds.filter { $0 < windowSeconds }
    }

    /// Largest reminder offset that makes sense for a budget (D-013 UI bound): budget − 1 minute,
    /// capped by the reminder range.
    public static func maxWarningOffset(forBudgetSeconds budget: Int) -> Int {
        min(warningOffsetRange.upperBound, max(0, budget - warningStepSeconds))
    }

    /// D-019 — the reminder dials, made impossible to set wrong.
    ///
    /// Reminder 1 fires before reminder 2, which fires before reminder 3, so their minutes-before-
    /// the-end must strictly DESCEND: 10 / 5 / 1, never 5 / 10 / 2. `normalizedOffsets` used to
    /// silently re-sort whatever the dials produced, which meant the parent could set 5 / 10 / 2
    /// and get something else back. This clamps instead, in place, so the illegal state is never
    /// reachable and nothing is reordered behind the parent's back.
    ///
    /// - `changedIndex` is the dial the parent just moved: it keeps its value, and its neighbours
    ///   give way around it. Pass nil to tidy the whole array (e.g. after the budget shrank).
    /// - 0 means "off". A slot that is off forces every LATER slot off too: reminder 3 without a
    ///   reminder 2 is a numbering lie.
    public static func clampedDescendingMinutes(_ raw: [Int],
                                                capMinutes: Int,
                                                changedIndex: Int? = nil) -> [Int] {
        var m = raw
        while m.count < maxWarnings { m.append(0) }
        m = Array(m.prefix(maxWarnings)).map { max(0, min($0, max(0, capMinutes))) }

        let pivot = changedIndex.map { max(0, min($0, maxWarnings - 1)) } ?? 0

        // Everything after the moved dial must be strictly smaller than the slot before it.
        for i in (pivot + 1)..<maxWarnings {
            let ceiling = m[i - 1] - 1
            if m[i - 1] == 0 || ceiling < 1 { m[i] = 0 } else { m[i] = min(m[i], ceiling) }
        }
        // Everything before it must be strictly larger — raise it if there is room, otherwise the
        // moved dial itself has to give way (it cannot be larger than the cap).
        if pivot > 0 {
            for i in stride(from: pivot, to: 0, by: -1) where m[i] > 0 {
                if m[i - 1] <= m[i] {
                    let raised = m[i] + 1
                    if raised <= capMinutes { m[i - 1] = raised } else { m[i] = max(0, m[i - 1] - 1) }
                }
            }
            // The backward pass can LOWER a dial that the forward pass already sized against its
            // old value, leaving a stale neighbour: 15/15/15 with dial 2 moved came out 15/14/14.
            // One more descending sweep settles it, and it cannot disturb the moved dial — by now
            // the dial before it is exactly one larger.
            for i in 1..<maxWarnings {
                let ceiling = m[i - 1] - 1
                if m[i - 1] == 0 || ceiling < 1 { m[i] = 0 } else { m[i] = min(m[i], ceiling) }
            }
        }
        // A slot that is off ends the list.
        if let firstOff = m.firstIndex(of: 0) {
            for i in firstOff..<maxWarnings { m[i] = 0 }
        }
        return m
    }

    /// The upper bound for dial `index`, given what the other dials currently say. This is what
    /// makes the dial physically unable to pass its neighbour.
    public static func warningDialUpperBound(index: Int, minutes: [Int], capMinutes: Int) -> Int {
        guard index > 0 else { return max(0, capMinutes) }
        let previous = index - 1 < minutes.count ? minutes[index - 1] : 0
        guard previous > 1 else { return 0 }
        return min(max(0, capMinutes), previous - 1)
    }

    /// Drops non-positive values, clamps, de-duplicates, sorts earliest-first, caps at three.
    public static func normalizedOffsets(_ offsets: [Int]) -> [Int] {
        let cleaned = offsets
            .filter { $0 > 0 }
            .map { min(max($0, warningOffsetRange.lowerBound), warningOffsetRange.upperBound) }
        return Array(Set(cleaned)).sorted(by: >).prefix(maxWarnings).map { $0 }
    }

    // MARK: Codable — tolerant of the pre-D-013 shape (warning10Enabled / warning5Enabled / warning1Enabled)

    private enum CodingKeys: String, CodingKey {
        case dailyBudgetSeconds, warningOffsetsSeconds, selectedActivities
        case warning10Enabled, warning5Enabled, warning1Enabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let budget = try c.decodeIfPresent(Int.self, forKey: .dailyBudgetSeconds) ?? Self.defaultBudgetSeconds
        let activities = try c.decodeIfPresent([TransitionActivity].self, forKey: .selectedActivities) ?? []
        let offsets: [Int]
        if let stored = try c.decodeIfPresent([Int].self, forKey: .warningOffsetsSeconds) {
            offsets = stored
        } else {
            // Legacy toggles → offsets.
            var legacy: [Int] = []
            if try c.decodeIfPresent(Bool.self, forKey: .warning10Enabled) ?? true { legacy.append(600) }
            if try c.decodeIfPresent(Bool.self, forKey: .warning5Enabled) ?? true { legacy.append(300) }
            if try c.decodeIfPresent(Bool.self, forKey: .warning1Enabled) ?? true { legacy.append(60) }
            offsets = legacy
        }
        // D-035 — a record written by an older build may still carry `selectedCategories`. It is
        // ignored: those were our own catalogue rows, and rows that shield nothing are not setup.
        self.init(dailyBudgetSeconds: budget, warningOffsetsSeconds: offsets, selectedActivities: activities)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dailyBudgetSeconds, forKey: .dailyBudgetSeconds)
        try c.encode(warningOffsetsSeconds, forKey: .warningOffsetsSeconds)
        try c.encode(selectedActivities, forKey: .selectedActivities)
    }
}
