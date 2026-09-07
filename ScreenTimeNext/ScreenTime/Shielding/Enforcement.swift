//  Enforcement.swift
//  ScreenTimeNext
//
//  Task 012 — the one place that decides WHEN the shield is up. PRD §14, §15.
//
//  Task 010 proved the system wakes us when the budget is spent. Task 011 built what the child then
//  sees. This is the sentence in between, and it is deliberately ONE sentence, in ONE function,
//  callable from every process that might need to act on it:
//
//      Covered apps are shielded exactly when today's budget is gone.
//
//  Everything else follows from that. A fresh morning has budget, so nothing is shielded. A running
//  session has budget, so nothing is shielded. The moment the last second goes, the shield is up —
//  whether the app is open, backgrounded, or force-quit, because the DeviceActivity extension calls
//  this too. A parent adding ten minutes gives the budget back, so the shield comes down on the
//  same rule rather than through a special case.
//
//  D-042 records the one case this rule deliberately leaves open: a parent who presses "End" with
//  budget still on the clock stops the session but does NOT block the device, because they ended a
//  round, not the day.
//
//  Rule 3 — nothing here assumes the app is alive or that it will be called again. Every call
//  recomputes from stored state and absolute timestamps (Rule 4), so a missed call costs nothing
//  and a repeated call changes nothing.

import Foundation
import ScreenTimeNextCore

enum Enforcement {

    /// Make the device match the rule. Safe to call as often as you like, from anywhere.
    ///
    /// Returns the state it settled on, so a caller that wants to say something about it can,
    /// without asking a second question.
    @discardableResult
    static func reconcile(storage: any ScreenTimeStorageService,
                          selection: any ScreenTimeSelectionService,
                          shield: any ScreenTimeShieldService,
                          now: Date = Date()) -> ProtectionState {
        let controller = SessionController(storage: storage, now: { now })
        let remaining = (try? controller.remainingBudgetSeconds()) ?? 0

        guard remaining <= 0 else {
            // There is time left today. Whatever we shielded earlier comes down — including after a
            // parent extends, which is the same event as far as this rule is concerned.
            try? shield.removeShield()
            return .unshielded
        }

        // Time is up. Shield exactly what the parent picked, and nothing else (§15).
        guard let picked = (try? selection.loadSelection()) ?? nil, !picked.summary.isEmpty else {
            // Nothing was ever chosen, so there is nothing to cover. Raising an empty shield would
            // be a device that feels broken for no reason a parent could explain.
            try? shield.removeShield()
            return .unshielded
        }
        do {
            try shield.applyShield(for: picked)
            return .shielded
        } catch {
            // The selection could not be decoded, or covers nothing enforceable. Leaving a stale
            // shield up would be worse than none: the parent has no way to lift it from here.
            try? shield.removeShield()
            return .unshielded
        }
    }

    /// D-043 — raise the shield WITHOUT consulting the rule.
    ///
    /// This is the mid-session reminder, and it is the one case that must not go through
    /// `reconcile`: there is time left, so the rule would say "unshielded" and take the reminder
    /// straight back down. The shield is not the end here, it is the heads-up — and the child gets
    /// their remaining minutes back by pressing the button (`ShieldActionExtension`), which is what
    /// makes this a pause rather than a punishment (D-012).
    static func raiseReminderShieldFromAppGroup() {
        guard let storage = try? FileStorageService.shared(),
              let selectionService = AppGroupSelectionService(),
              let picked = (try? selectionService.loadSelection()) ?? nil,
              !picked.summary.isEmpty else { return }
        try? ManagedSettingsShieldService(storage: storage).applyShield(for: picked)
        // D-050 — the clock stops here. The child cannot use the device while this is up, so
        // charging them for the time would be charging them for our own interruption.
        MonitorJournal()?.markShieldRaised()
    }

    /// D-050 — re-arm this session's alarms from whatever the window says now.
    ///
    /// Called when the end alarm fires and finds time left, which means a transition screen paused
    /// the clock after the alarms were set. Only processes with `DeviceActivity` can do this, which
    /// is why the credit itself lives in the package and this does not.
    static func rearmSessionAlarmsFromAppGroup(now: Date = Date()) {
        guard let storage = try? FileStorageService.shared(),
              let window = (try? storage.loadSessionWindow()) ?? nil,
              window.remainingSeconds(at: now) > 0 else { return }
        let configuration = (try? storage.loadConfiguration()) ?? .default
        try? SessionAlarmScheduler.schedule(
            endsAt: window.endsAt,
            warningOffsetsSeconds: configuration.effectiveWarningOffsets(forWindowSeconds: window.totalSeconds),
            now: now)
    }

    /// The same rule, wired to the App Group for a caller that has no service container — i.e. an
    /// extension woken by the system with no app process (Rule 5).
    @discardableResult
    static func reconcileFromAppGroup(now: Date = Date()) -> ProtectionState {
        guard let storage = try? FileStorageService.shared(),
              let selection = AppGroupSelectionService() else { return .unshielded }
        return reconcile(storage: storage,
                         selection: selection,
                         shield: ManagedSettingsShieldService(storage: storage),
                         now: now)
    }
}
