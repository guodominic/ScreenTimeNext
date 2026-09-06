//  ParentDashboardViewModel.swift
//  ScreenTimeNext
//
//  Task 014 — PRD §6.9. Everything the dashboard shows is re-read from storage on appear and on
//  foreground (PRD §14: the extension may have changed protection state while the app was closed).

import SwiftUI
import Observation
import ScreenTimeNextCore

@Observable
final class ParentDashboardViewModel {

    private(set) var profile: ChildProfile?
    private(set) var configuration: ScreenTimeConfiguration = .default
    private(set) var selectionSummary: SelectionSummary = .empty
    private(set) var protectionState: ProtectionState = .unshielded
    private(set) var session: ChildSessionSnapshot = .idle
    private(set) var remainingTodaySeconds: Int = 0
    private(set) var notificationsDenied = false
    /// D-016 — the minutes shown on the idle hero; seeded from the saved budget so a repeat
    /// "fifteen minutes" is two taps from launch.
    var quickMinutes: Int = ScreenTimeConfiguration.defaultBudgetSeconds / 60
    private(set) var authorization: ScreenTimeAuthorizationStatus = .notDetermined
    /// Task 004 — a request in flight, and whatever went wrong last time. Both are parent-facing.
    private(set) var isRequestingAuthorization = false
    private(set) var authorizationError: String?

    private let services: ServiceContainer
    private let controller: SessionController
    private var tickTask: Task<Void, Never>?

    init(services: ServiceContainer) {
        self.services = services
        controller = services.makeSessionController()
    }

    func appeared() {
        reload()
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshSession()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func disappeared() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Full re-read: appear, foreground, after Settings.
    func reload() {
        Task {
            notificationsDenied = await services.notifications.isPermissionDenied
            authorization = await services.authorization.status
        }
        let storage = services.storage
        profile = try? storage.loadChildProfile()
        configuration = (try? storage.loadConfiguration()) ?? .default
        if session.window == nil {
            quickMinutes = configuration.dailyBudgetSeconds / 60
        }
        selectionSummary = (try? services.selection.loadSelection())?.summary ?? .empty
        protectionState = (try? storage.loadProtectionState()) ?? .unshielded
        refreshSession()
    }

    private func refreshSession() {
        session = (try? controller.tick()) ?? .idle
        remainingTodaySeconds = (try? controller.remainingBudgetSeconds()) ?? 0
    }

    // MARK: Parent actions

    /// Task 004 / QA-02 — ask for Family Controls access. Every failure ends somewhere the parent
    /// can act: a message that names the fix, never a dead end.
    func requestAuthorization() {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        authorizationError = nil
        Task {
            defer { isRequestingAuthorization = false }
            do {
                authorization = try await services.authorization.requestAuthorization()
            } catch ScreenTimeAuthorizationError.denied {
                authorization = await services.authorization.status
                authorizationError = nil      // the row already explains a decline and offers Settings
            } catch ScreenTimeAuthorizationError.entitlementUnavailable {
                authorization = await services.authorization.status
                authorizationError = "Screen Time access isn't available in this build."
            } catch let ScreenTimeAuthorizationError.unknown(message) {
                authorization = await services.authorization.status
                authorizationError = message
            } catch {
                authorization = await services.authorization.status
                authorizationError = "Something went wrong. Please try again."
            }
        }
    }


    /// Nudge the idle dial by one step — a minute under 15, two above (D-017).
    func adjustQuickMinutes(_ direction: Int) {
        let range = ScreenTimeConfiguration.budgetRangeSeconds
        let probe = direction < 0 ? (quickMinutes - 1) * 60 : quickMinutes * 60
        let step = ScreenTimeConfiguration.budgetStep(near: probe) / 60
        quickMinutes = min(max(quickMinutes + direction * step, range.lowerBound / 60), range.upperBound / 60)
    }

    /// D-016 — set today's budget from the hero and open a session in one action.
    func startSession() {
        // Only the budget changes here — everything else the parent has arranged (reminders,
        // activities, category order, "my usual") is carried across untouched (D-019).
        var config = configuration
        config.dailyBudgetSeconds = quickMinutes * 60
        try? services.storage.save(config)
        _ = try? controller.start()
        reload()
    }

    func endSession() {
        _ = try? controller.endEarly()
        refreshSession()
    }

    /// Task 013 (session half, D-010). Phase 1 adds: remove ScreenTimeNext-managed shield,
    /// adjust monitoring, reapply on expiry — all through the same protocols.
    func extend(minutes: Int) {
        guard (try? controller.extend(bySeconds: minutes * 60)) != nil else { return }
        _ = try? services.shield.removeShield()
        try? services.storage.save(ProtectionState.temporarilyExtended)
        reload()
    }

    var canExtend: Bool { session.window != nil }

    // MARK: Presentation helpers

    var sessionStatusText: String {
        switch session.state {
        case .idle:      return "Not started"
        case .active:    return "In progress"
        case .extended:  return "Extended"
        case .firstWarning, .secondWarning, .finalWarning:
            if let m = session.activeWarningMinutes { return "\(m)-minute reminder" }
            return "Reminder"
        case .finished:  return "Finished"
        }
    }

    /// Remaining ÷ budget for the hero ring (0…1). During a session, the live window counts.
    var remainingFraction: Double {
        let budget = max(1, configuration.dailyBudgetSeconds)
        let shown = session.window != nil ? session.remainingSeconds : remainingTodaySeconds
        return min(1, Double(shown) / Double(budget))
    }

    var sessionIsRunning: Bool { session.window != nil && session.state != .finished }

    var authorizationText: String {
        switch authorization {
        case .notDetermined: return "Not requested"
        case .approved:      return "Allowed"
        case .denied:        return "Declined"
        case .revoked:       return "Turned off in Settings"
        }
    }

    var protectionText: String {
        switch protectionState {
        case .unshielded:          return "Not shielded"
        case .shielded:            return "Shielded"
        case .temporarilyExtended: return "Extended by parent"
        }
    }
}
