//  ChildTimerViewModel.swift
//  ScreenTimeNext
//
//  Task 007. Drives the child timer from SessionController. The 1-second loop only triggers
//  redraws; every displayed value is recomputed from the persisted SessionWindow (Rule 4).

import SwiftUI
import Observation
import ScreenTimeNextCore

@Observable
final class ChildTimerViewModel {

    private(set) var snapshot: ChildSessionSnapshot = .idle
    private(set) var childName: String = ""
    private(set) var errorText: String?
    /// D-019 — stored, not computed. A computed property that reads storage touches no observable
    /// state, so SwiftUI had no reason to redraw the chooser when the parent changed the activity
    /// list in Settings.
    private(set) var availableActivities: [TransitionActivity] = TransitionActivity.allCases

    private let controller: SessionController
    private let storage: any ScreenTimeStorageService
    private var tickTask: Task<Void, Never>?

    init(services: ServiceContainer) {
        storage = services.storage
        controller = services.makeSessionController()
    }

    // MARK: Lifecycle

    func appeared() {
        reloadParentSettings()
        run { try controller.restore() }
        startTicking()
    }

    /// D-019 — the parent saved Settings while this session was running. Re-read everything that
    /// came from them, and let the controller re-derive the window from the new daily budget.
    func configurationChanged() {
        reloadParentSettings()
        if let updated = (try? controller.applyConfigurationChange()) ?? nil {
            snapshot = updated
            errorText = nil
        } else {
            refresh()
        }
    }

    private func reloadParentSettings() {
        childName = (try? storage.loadChildProfile())?.name ?? ""
        availableActivities = (try? controller.availableActivities()) ?? TransitionActivity.allCases
    }

    func disappeared() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Foreground, clock change, anything that makes the last redraw untrustworthy.
    func refresh() {
        run { try controller.tick() }
    }

    // MARK: Child actions

    func start() {
        run { try controller.start() }
    }

    /// PRD §6.11 — pick what to do next. Task 009.
    func choose(_ activity: TransitionActivity) {
        run { try controller.choose(activity) }
    }

    // MARK: Internals

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func run(_ operation: () throws -> ChildSessionSnapshot) {
        do {
            snapshot = try operation()
            errorText = nil
        } catch {
            // Storage trouble is a parent problem, not a child one: keep the last good snapshot.
            errorText = "Something went wrong. Ask a grown-up to check the app."
        }
    }
}
