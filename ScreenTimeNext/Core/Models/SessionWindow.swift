//  SessionWindow.swift
//  ScreenTimeNext
//
//  Encodes Rule 4 — absolute timestamps are the source of truth.
//  Framework-free: imports Foundation only. See ScreenTimeNext/README.md.

import Foundation

/// A screen-time session expressed as ABSOLUTE timestamps.
///
/// Architecture Rule 4: absolute timestamps are the source of truth for countdown rendering.
/// A `Timer` may drive redraws; it may never be the source of truth. On every tick and on every
/// foreground, recompute remaining time from `endsAt` and the current date.
public struct SessionWindow: Codable, Equatable, Sendable {
    public let startedAt: Date
    /// Moves forward when a parent grants an extension (PRD §15).
    public var endsAt: Date

    public init(startedAt: Date, endsAt: Date) {
        self.startedAt = startedAt
        self.endsAt = endsAt
    }

    public init(startedAt: Date, budgetSeconds: Int) {
        self.startedAt = startedAt
        self.endsAt = startedAt.addingTimeInterval(TimeInterval(budgetSeconds))
    }

    /// Remaining seconds at `now`, never negative.
    public func remainingSeconds(at now: Date) -> Int {
        max(0, Int(endsAt.timeIntervalSince(now).rounded(.down)))
    }

    public func hasExpired(at now: Date) -> Bool {
        remainingSeconds(at: now) == 0
    }

    /// Grant a parent extension (PRD §6.16, §15). Returns a new window; does not mutate in place.
    public func extended(bySeconds seconds: Int) -> SessionWindow {
        SessionWindow(startedAt: startedAt, endsAt: endsAt.addingTimeInterval(TimeInterval(seconds)))
    }
}
