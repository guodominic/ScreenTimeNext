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

    private let services: ServiceContainer
    private let controller: SessionController
    private var tickTask: Task<Void, Never>?

    init(services: ServiceContainer) {
        self.services = services
        controller = SessionController(storage: services.storage)
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
        let storage = services.storage
        profile = try? storage.loadChildProfile()
        configuration = (try? storage.loadConfiguration()) ?? .default
        selectionSummary = (try? services.selection.loadSelection())?.summary ?? .empty
        protectionState = (try? storage.loadProtectionState()) ?? .unshielded
        refreshSession()
    }

    private func refreshSession() {
        session = (try? controller.tick()) ?? .idle
        remainingTodaySeconds = (try? controller.remainingBudgetSeconds()) ?? 0
    }

    // MARK: Parent actions

    func endSession() {
        _ = try? controller.endEarly()
        refreshSession()
    }

    // MARK: Presentation helpers

    var sessionStatusText: String {
        switch session.state {
        case .idle:      return "Not started"
        case .active, .extended: return "In progress"
        case .warning10: return "10-minute warning"
        case .warning5:  return "5-minute warning"
        case .warning1:  return "1-minute warning"
        case .finished:  return "Finished"
        }
    }

    var sessionIsRunning: Bool { session.window != nil && session.state != .finished }

    var protectionText: String {
        switch protectionState {
        case .unshielded:          return "Not shielded"
        case .shielded:            return "Shielded"
        case .temporarilyExtended: return "Extended by parent"
        }
    }
}
