//  MonitoringCoordinator.swift
//  ScreenTimeNext
//
//  Task 010 — decides WHEN the DeviceActivity registration is written, so no view has to.
//
//  Rule 3 — this is not a timer and never polls. It reacts to three moments and nothing else:
//  launch, a configuration or selection change, and returning to the foreground (where a change
//  made on another device, or a system reset, may have happened while we were gone).

import Foundation
import ScreenTimeNextCore

@MainActor
final class MonitoringCoordinator {

    private let monitoring: any ScreenTimeMonitoringService
    private let storage: any ScreenTimeStorageService
    private let selection: any ScreenTimeSelectionService
    private let shield: any ScreenTimeShieldService
    private var observer: NSObjectProtocol?
    private var sessionObserver: NSObjectProtocol?

    /// The last failure, kept so the dashboard can say enforcement is not armed rather than
    /// leaving a parent to assume it is.
    private(set) var lastError: ScreenTimeMonitoringError?

    init(monitoring: any ScreenTimeMonitoringService,
         storage: any ScreenTimeStorageService,
         selection: any ScreenTimeSelectionService,
         shield: any ScreenTimeShieldService) {
        self.monitoring = monitoring
        self.storage = storage
        self.selection = selection
        self.shield = shield
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let sessionObserver { NotificationCenter.default.removeObserver(sessionObserver) }
    }

    func start() {
        observer = NotificationCenter.default.addObserver(forName: .configurationDidChange,
                                                          object: nil,
                                                          queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.synchronize() }
        }
        // D-047 — a session starting, ending or being extended moves every alarm, so it needs its
        // own signal: a parent's settings and a child's session change for different reasons.
        sessionObserver = NotificationCenter.default.addObserver(forName: .sessionDidChange,
                                                                 object: nil,
                                                                 queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.synchronize() }
        }
        Task { await synchronize() }
    }

    /// D-047 — set the wake-ups for the session that is running, or clear them if none is.
    ///
    /// Called from the same place as everything else, so there is one moment where the device is
    /// made to match the records rather than several that can disagree.
    private func synchronizeSessionAlarms() async {
        let configuration = (try? storage.loadConfiguration()) ?? .default
        guard let window = (try? storage.loadSessionWindow()) ?? nil,
              window.remainingSeconds(at: Date()) > 0 else {
            await monitoring.clearSessionAlarms()
            return
        }
        // Only the reminders that fit this window: one longer than the session has no moment to
        // fire in, and `effectiveWarningOffsets` is the one place that judgement lives.
        let offsets = configuration.effectiveWarningOffsets(forWindowSeconds: window.totalSeconds)
        try? await monitoring.scheduleSessionAlarms(endsAt: window.endsAt, warningOffsetsSeconds: offsets)
    }

    /// Make the registration AND the shield match what the parent has set. Safe to call as often
    /// as we like: the service compares against what is already registered and does nothing when
    /// they agree, and `Enforcement.reconcile` recomputes from stored state every time.
    func synchronize() async {
        // Task 012 — the shield first. If the app was closed through midnight, or a parent changed
        // the budget from under a spent day, this is the moment a child gets their device back.
        Enforcement.reconcile(storage: storage, selection: selection, shield: shield)
        await synchronizeSessionAlarms()

        guard let snapshot = try? selection.loadSelection(), !snapshot.summary.isEmpty else {
            // Nothing picked — nothing to watch, and a registration over nothing would fire never
            // while looking armed.
            try? await monitoring.stopMonitoring()
            lastError = nil
            return
        }
        let configuration = (try? storage.loadConfiguration()) ?? .default
        do {
            try await monitoring.restartMonitoring(budgetSeconds: configuration.dailyBudgetSeconds,
                                                   warningOffsetsSeconds: configuration.warningOffsetsSeconds,
                                                   selection: snapshot)
            lastError = nil
        } catch let error as ScreenTimeMonitoringError {
            lastError = error
        } catch {
            lastError = .unknown(String(describing: error))
        }
    }
}
