//  SessionWindow.swift
//  ScreenTimeNext
//
//  Encodes Rule 4 — absolute timestamps are the source of truth.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

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
    /// What the child chose to do next (PRD §6.11). Lives and dies with the session, so it
    /// carries through to Time's Up and is gone by the next Start. Optional for decode-compat.
    public var chosenActivity: TransitionActivity?

    public init(startedAt: Date, endsAt: Date, chosenActivity: TransitionActivity? = nil) {
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.chosenActivity = chosenActivity
    }

    public init(startedAt: Date, budgetSeconds: Int, chosenActivity: TransitionActivity? = nil) {
        self.startedAt = startedAt
        self.endsAt = startedAt.addingTimeInterval(TimeInterval(budgetSeconds))
        self.chosenActivity = chosenActivity
    }

    /// Total length of the window in seconds.
    public var totalSeconds: Int {
        max(0, Int(endsAt.timeIntervalSince(startedAt).rounded(.down)))
    }

    /// Remaining seconds at `now`: never negative, and never more than the window's total length.
    /// The upper clamp is a cheap defence against the clock being moved backward (PRD §17):
    /// a child who sets the clock back cannot manufacture more time than the session had.
    public func remainingSeconds(at now: Date) -> Int {
        let raw = Int(endsAt.timeIntervalSince(now).rounded(.down))
        return min(max(0, raw), totalSeconds)
    }

    public func hasExpired(at now: Date) -> Bool {
        remainingSeconds(at: now) == 0
    }

    /// Grant a parent extension (PRD §6.16, §15). Returns a new window; does not mutate in place.
    public func extended(bySeconds seconds: Int) -> SessionWindow {
        SessionWindow(startedAt: startedAt, endsAt: endsAt.addingTimeInterval(TimeInterval(seconds)), chosenActivity: chosenActivity)
    }
}
