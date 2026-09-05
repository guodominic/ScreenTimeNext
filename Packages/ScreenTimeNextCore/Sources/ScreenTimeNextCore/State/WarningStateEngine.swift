//  WarningStateEngine.swift
//  ScreenTimeNext
//
//  PRD §11 — deterministic state transitions. Task 008.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

import Foundation

/// Deterministic session-state logic. PRD §11.
///
/// Pure and framework-free by design: this is the piece that can be fully unit-tested without a
/// device or the Family Controls entitlement.
///
/// **Separation of concerns (docs/DECISIONS.md D-004, proposed):** the natural stage is computed
/// from remaining time ALONE. Warning toggles (PRD §6.6) control *presentation*, not the state
/// machine. This keeps transitions deterministic regardless of configuration, and means a disabled
/// warning is "entered but not shown" rather than skipped.
public enum WarningStateEngine {

    /// Warning boundaries in seconds. PRD §6.6, §6.11–§6.13.
    public enum Threshold {
        public static let warning10 = 600
        public static let warning5  = 300
        public static let warning1  = 60
    }

    /// The stage implied by remaining time alone.
    ///
    /// Boundaries are inclusive (`<=`): at exactly 600 seconds remaining the stage is `.warning10`.
    public static func stage(remainingSeconds: Int) -> ScreenTimeState {
        if remainingSeconds <= 0 { return .finished }
        if remainingSeconds <= Threshold.warning1 { return .warning1 }
        if remainingSeconds <= Threshold.warning5 { return .warning5 }
        if remainingSeconds <= Threshold.warning10 { return .warning10 }
        return .active
    }

    /// Monotonic ordering used to prevent a session stepping backward on clock jitter.
    private static func rank(_ state: ScreenTimeState) -> Int {
        switch state {
        case .idle:      return 0
        case .active:    return 1
        case .warning10: return 2
        case .warning5:  return 3
        case .warning1:  return 4
        case .finished:  return 5
        case .extended:  return 6   // handled explicitly before ranking is consulted
        }
    }

    /// The next state, given the current state and remaining time.
    ///
    /// - `.idle` is left alone: starting a session is an explicit event (`start()`), not a
    ///   consequence of time passing.
    /// - `.extended` resumes into the stage implied by the new remaining time (PRD §11:
    ///   `extended → active`).
    /// - Otherwise the session never moves backward. Only `grantExtension()` may do that.
    public static func next(current: ScreenTimeState, remainingSeconds: Int) -> ScreenTimeState {
        switch current {
        case .idle:
            return .idle
        case .extended:
            return stage(remainingSeconds: remainingSeconds)
        default:
            let natural = stage(remainingSeconds: remainingSeconds)
            return rank(natural) >= rank(current) ? natural : current
        }
    }

    /// Explicit transition: the child begins a session. PRD §11 `idle → active`.
    public static func start(remainingSeconds: Int) -> ScreenTimeState {
        stage(remainingSeconds: remainingSeconds)
    }

    /// Explicit transition: a parent grants an extension. PRD §11 `finished | shielded → extended`.
    ///
    /// Deliberately unconditional: PRD §6.16 does not restrict when a parent may extend, and
    /// `ProtectionState` — not this enum — tracks whether content is currently shielded
    /// (docs/DECISIONS.md D-002). Task 013 decides whether stacked extensions need validation here.
    public static func grantExtension() -> ScreenTimeState {
        .extended
    }

    /// Explicit transition: day rollover returns the session to `.idle`. PRD §11, Task 017 (QA-13).
    public static func dayRollover() -> ScreenTimeState {
        .idle
    }

    /// Whether a warning stage should be PRESENTED, given the parent's toggles (PRD §6.6).
    /// The state machine is unaffected by these toggles — see the type documentation.
    public static func shouldPresent(
        _ state: ScreenTimeState,
        configuration: ScreenTimeConfiguration
    ) -> Bool {
        switch state {
        case .warning10: return configuration.warning10Enabled
        case .warning5:  return configuration.warning5Enabled
        case .warning1:  return configuration.warning1Enabled
        default:         return true
        }
    }
}
