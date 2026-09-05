//  WarningStateEngine.swift
//  ScreenTimeNextCore
//
//  PRD §11 — deterministic state transitions, driven by remaining time and the parent's warning
//  offsets (D-013). Pure and framework-free by design.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

import Foundation

public enum WarningStateEngine {

    /// Which configured warning (earliest-first index) has been reached, if any.
    /// Boundaries are inclusive: at exactly `offset` seconds remaining the warning is reached.
    public static func reachedWarningIndex(remainingSeconds: Int, warningOffsets: [Int]) -> Int? {
        let offsets = ScreenTimeConfiguration.normalizedOffsets(warningOffsets)
        let passed = offsets.filter { remainingSeconds <= $0 }.count
        return passed == 0 ? nil : passed - 1
    }

    /// The role a warning index plays, given how many warnings exist.
    public static func role(ofWarningAt index: Int, count: Int) -> ScreenTimeState {
        if index == 0 { return .firstWarning }
        if index == count - 1 { return .finalWarning }
        return .secondWarning
    }

    /// D-016 — where the child is asked to choose what's next: the **second-to-last** reminder.
    /// Close enough to the end to feel real, far enough that they aren't choosing under pressure
    /// in the final minute. With a single reminder there is no second-to-last, so it is that one.
    public static func chooserIndex(warningCount count: Int) -> Int? {
        guard count > 0 else { return nil }
        return count == 1 ? 0 : count - 2
    }

    /// True when the warning at `index` is the one that carries the activity chooser.
    public static func isChooser(warningAt index: Int, count: Int) -> Bool {
        chooserIndex(warningCount: count) == index
    }

    /// The stage implied by remaining time alone.
    public static func stage(remainingSeconds: Int, warningOffsets: [Int]) -> ScreenTimeState {
        if remainingSeconds <= 0 { return .finished }
        let offsets = ScreenTimeConfiguration.normalizedOffsets(warningOffsets)
        guard let index = reachedWarningIndex(remainingSeconds: remainingSeconds, warningOffsets: offsets) else {
            return .active
        }
        return role(ofWarningAt: index, count: offsets.count)
    }

    /// The offset (seconds before end) of the warning currently in force, for copy like "5 minutes left".
    public static func activeWarningOffset(remainingSeconds: Int, warningOffsets: [Int]) -> Int? {
        let offsets = ScreenTimeConfiguration.normalizedOffsets(warningOffsets)
        guard let index = reachedWarningIndex(remainingSeconds: remainingSeconds, warningOffsets: offsets) else { return nil }
        return offsets[index]
    }

    /// Monotonic ordering used to prevent a session stepping backward on clock jitter.
    private static func rank(_ state: ScreenTimeState) -> Int {
        switch state {
        case .idle:          return 0
        case .active:        return 1
        case .firstWarning:  return 2
        case .secondWarning: return 3
        case .finalWarning:  return 4
        case .finished:      return 5
        case .extended:      return 6   // handled explicitly before ranking is consulted
        }
    }

    /// The next state, given the current state and remaining time.
    /// - `.idle` is left alone: starting a session is an explicit event (`start`).
    /// - `.extended` resumes into the stage implied by the new remaining time (§11).
    /// - Otherwise the session never moves backward; only `grantExtension()` may.
    public static func next(current: ScreenTimeState, remainingSeconds: Int, warningOffsets: [Int]) -> ScreenTimeState {
        switch current {
        case .idle:
            return .idle
        case .extended:
            return stage(remainingSeconds: remainingSeconds, warningOffsets: warningOffsets)
        default:
            let natural = stage(remainingSeconds: remainingSeconds, warningOffsets: warningOffsets)
            return rank(natural) >= rank(current) ? natural : current
        }
    }

    /// Explicit transition: the child begins a session. §11 `idle → active`.
    public static func start(remainingSeconds: Int, warningOffsets: [Int]) -> ScreenTimeState {
        stage(remainingSeconds: remainingSeconds, warningOffsets: warningOffsets)
    }

    /// Explicit transition: a parent grants an extension. §11 `finished | shielded → extended`.
    public static func grantExtension() -> ScreenTimeState { .extended }

    /// Explicit transition: day rollover returns the session to `.idle`. §11.
    public static func dayRollover() -> ScreenTimeState { .idle }
}
