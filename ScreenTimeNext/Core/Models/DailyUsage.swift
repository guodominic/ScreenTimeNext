//  DailyUsage.swift
//  ScreenTimeNext
//
//  PRD §12 — one day's budget and accrued usage.
//  Framework-free: imports Foundation only. See ScreenTimeNext/README.md.

import Foundation

/// One day's budget and accrued usage. PRD §12.
public struct DailyUsage: Codable, Equatable, Sendable {
    /// The calendar day this record covers. Day rollover is Task 017 (QA-13).
    public var date: Date
    public var budgetSeconds: Int
    public var usedSeconds: Int

    public init(date: Date, budgetSeconds: Int, usedSeconds: Int = 0) {
        self.date = date
        self.budgetSeconds = budgetSeconds
        self.usedSeconds = usedSeconds
    }

    /// Never negative.
    public var remainingSeconds: Int {
        max(0, budgetSeconds - usedSeconds)
    }

    public var isExhausted: Bool {
        remainingSeconds == 0
    }
}
