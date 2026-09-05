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

    private let controller: SessionController
    private let storage: any ScreenTimeStorageService
    private var tickTask: Task<Void, Never>?

    init(services: ServiceContainer) {
        storage = services.storage
        controller = services.makeSessionController()
    }

    // MARK: Lifecycle

    func appeared() {
        childName = (try? storage.loadChildProfile())?.name ?? ""
        run { try controller.restore() }
        startTicking()
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

    var availableActivities: [TransitionActivity] {
        (try? controller.availableActivities()) ?? TransitionActivity.allCases
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
