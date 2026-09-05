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

    /// 1–120 minutes. Short budgets are the common case ("you get seven more minutes"), so below
    /// `fineStepThresholdSeconds` the dial moves a minute at a time; above it, two.
    public static let budgetRangeSeconds = 60...7200
    public static let budgetStepSeconds = 120
    public static let fineBudgetStepSeconds = 60
    public static let fineStepThresholdSeconds = 900        // 15 minutes
    public static let defaultBudgetSeconds = 3600

    /// The step to use around a given budget.
    public static func budgetStep(near seconds: Int) -> Int {
        seconds < fineStepThresholdSeconds ? fineBudgetStepSeconds : budgetStepSeconds
    }

    /// Each warning: 1–15 minutes before the end (0 in the UI means "off").
    public static let warningOffsetRange = 60...900
    public static let warningStepSeconds = 60
    public static let maxWarnings = 3
    public static let defaultWarningOffsets = [600, 300, 60]

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
        if minutes >= 12 { return [600, 300, 60] }
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
        self.init(dailyBudgetSeconds: budget, warningOffsetsSeconds: offsets, selectedActivities: activities)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dailyBudgetSeconds, forKey: .dailyBudgetSeconds)
        try c.encode(warningOffsetsSeconds, forKey: .warningOffsetsSeconds)
        try c.encode(selectedActivities, forKey: .selectedActivities)
    }
}
