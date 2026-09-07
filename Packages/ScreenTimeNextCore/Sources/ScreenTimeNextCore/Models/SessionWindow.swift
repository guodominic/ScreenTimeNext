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

    /// D-019 — how long this window was worth at Start, before any parent extension.
    ///
    /// Needed so that re-deriving the window from a changed daily budget can tell "time the budget
    /// allows" apart from "time a parent deliberately granted on top of it" (§15) and never claws
    /// an extension back. Windows written before this existed decode as their full length, which
    /// makes `grantedSeconds` zero — the honest answer when we cannot know.
    public private(set) var budgetSecondsAtStart: Int

    /// D-050 — seconds the clock was stopped while a transition screen was up.
    ///
    /// Kept apart from `budgetSecondsAtStart` and from a parent's extension so all three stay
    /// answerable separately: what the budget paid for, what a parent granted, and what the child
    /// was not charged for because they could not use the device.
    public private(set) var pausedSeconds: Int

    public init(startedAt: Date, endsAt: Date, chosenActivity: TransitionActivity? = nil,
                budgetSecondsAtStart: Int? = nil,
                pausedSeconds: Int = 0) {
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.chosenActivity = chosenActivity
        self.pausedSeconds = max(0, pausedSeconds)
        self.budgetSecondsAtStart = budgetSecondsAtStart
            ?? max(0, Int(endsAt.timeIntervalSince(startedAt).rounded(.down)))
    }

    public init(startedAt: Date, budgetSeconds: Int, chosenActivity: TransitionActivity? = nil) {
        self.startedAt = startedAt
        self.endsAt = startedAt.addingTimeInterval(TimeInterval(budgetSeconds))
        self.chosenActivity = chosenActivity
        self.budgetSecondsAtStart = max(0, budgetSeconds)
        self.pausedSeconds = 0
    }

    // MARK: Codable — tolerant of windows written before `budgetSecondsAtStart` existed

    private enum CodingKeys: String, CodingKey {
        case startedAt, endsAt, chosenActivity, budgetSecondsAtStart, pausedSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let started = try c.decode(Date.self, forKey: .startedAt)
        let ends = try c.decode(Date.self, forKey: .endsAt)
        self.startedAt = started
        self.endsAt = ends
        self.chosenActivity = try c.decodeIfPresent(TransitionActivity.self, forKey: .chosenActivity)
        self.budgetSecondsAtStart = try c.decodeIfPresent(Int.self, forKey: .budgetSecondsAtStart)
            ?? max(0, Int(ends.timeIntervalSince(started).rounded(.down)))
        // D-050 — a window written before pausing existed was never paused.
        self.pausedSeconds = try c.decodeIfPresent(Int.self, forKey: .pausedSeconds) ?? 0
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

    /// Seconds a parent has granted beyond what the budget paid for (§15). Paused time is not a
    /// grant — the child was never able to spend it — so it comes back out.
    public var grantedSeconds: Int { max(0, totalSeconds - budgetSecondsAtStart - pausedSeconds) }

    /// D-050 — the clock stopped while the child could not use the device, so give the time back.
    ///
    /// `seconds` is capped by the caller: crediting an unbounded pause would let a session that was
    /// interrupted at 8pm still be running at midnight, which is not what any parent meant by
    /// "fifteen minutes".
    public func paused(bySeconds seconds: Int) -> SessionWindow {
        guard seconds > 0 else { return self }
        return SessionWindow(startedAt: startedAt,
                             endsAt: endsAt.addingTimeInterval(TimeInterval(seconds)),
                             chosenActivity: chosenActivity,
                             budgetSecondsAtStart: budgetSecondsAtStart,
                             pausedSeconds: pausedSeconds + seconds)
    }

    /// Grant a parent extension (PRD §6.16, §15). Returns a new window; does not mutate in place.
    /// `budgetSecondsAtStart` is carried over untouched — that is what makes the extra time
    /// identifiable as a grant later.
    public func extended(bySeconds seconds: Int) -> SessionWindow {
        SessionWindow(startedAt: startedAt,
                      endsAt: endsAt.addingTimeInterval(TimeInterval(seconds)),
                      chosenActivity: chosenActivity,
                      budgetSecondsAtStart: budgetSecondsAtStart,
                      pausedSeconds: pausedSeconds)
    }
}
