//  ScreenTimeConfiguration.swift
//  ScreenTimeNext
//
//  PRD §12, §6.5, §6.6 — parent-configured settings.
//  Framework-free: imports Foundation only. See ScreenTimeNext/README.md.

import Foundation

/// Parent-configured settings. PRD §12.
public struct ScreenTimeConfiguration: Codable, Equatable, Sendable {

    /// Daily budget in SECONDS (PRD §12). Convert to minutes at the presentation layer only.
    public var dailyBudgetSeconds: Int

    /// Warning toggles. PRD §6.6 — all three default to enabled.
    public var warning10Enabled: Bool
    public var warning5Enabled: Bool
    public var warning1Enabled: Bool

    /// The activities the parent approved for the child to choose from. PRD §6.7.
    public var selectedActivities: [TransitionActivity]

    /// PRD §6.5 — default 60 minutes.
    public static let defaultBudgetSeconds = 3600

    /// PRD §6.5 — presets in minutes: 15, 30, 45, 60, 90, 120.
    public static let budgetPresetsSeconds: [Int] = [900, 1800, 2700, 3600, 5400, 7200]

    public init(
        dailyBudgetSeconds: Int = ScreenTimeConfiguration.defaultBudgetSeconds,
        warning10Enabled: Bool = true,
        warning5Enabled: Bool = true,
        warning1Enabled: Bool = true,
        selectedActivities: [TransitionActivity] = []
    ) {
        self.dailyBudgetSeconds = dailyBudgetSeconds
        self.warning10Enabled = warning10Enabled
        self.warning5Enabled = warning5Enabled
        self.warning1Enabled = warning1Enabled
        self.selectedActivities = selectedActivities
    }

    public static let `default` = ScreenTimeConfiguration()
}
