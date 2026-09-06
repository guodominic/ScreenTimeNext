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
    /// D-031 / D-036 — nil means no PIN is set yet, which after D-036 can only be true on the
    /// very first visit to this screen: arriving here without one is what triggers setting one.
    private(set) var parentPIN: ParentPIN?

    private let controller: SessionController
    private let storage: any ScreenTimeStorageService
    private let services: ServiceContainer
    private var tickTask: Task<Void, Never>?
    /// Task 012 — the last state we acted on. The shield is reconciled when the state CHANGES, not
    /// once a second: the rule is idempotent, but writing ManagedSettings sixty times a minute for
    /// no reason is not something to do on a child's device.
    private var lastEnforcedState: ScreenTimeState?

    init(services: ServiceContainer) {
        self.services = services
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
        parentPIN = try? storage.loadParentPIN()
    }

    func disappeared() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Foreground, clock change, anything that makes the last redraw untrustworthy.
    func refresh() {
        run { try controller.tick() }
    }

    // MARK: The parent PIN (D-036)

    /// D-036 — set on the first visit to this screen, before the child is ever left alone with it.
    /// Writing it here rather than in Settings is the point: a gate a parent has to go and find is
    /// a gate most families never set up, and this screen is the one that needs it.
    /// Returns false when the PIN did NOT reach storage. The caller must keep the pad up in that
    /// case: dismissing on a failed save is how a parent ends up being asked to set a PIN again
    /// tomorrow with no idea why.
    @discardableResult
    func setParentPIN(_ pin: ParentPIN) -> Bool {
        do {
            try storage.save(pin)
            // Read it back. A save that "succeeded" into a container the next launch cannot open
            // is the failure this whole check exists to catch, and it is silent otherwise.
            guard (try? storage.loadParentPIN()) != nil else {
                errorText = "That PIN could not be saved on this device."
                return false
            }
            parentPIN = pin
            errorText = nil
            return true
        } catch {
            errorText = "That PIN could not be saved. Please try again."
            return false
        }
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

    /// Task 012 — called after every state change. `Enforcement` owns the rule; this only decides
    /// when to ask it.
    private func enforceIfStateChanged() {
        guard snapshot.state != lastEnforcedState else { return }
        lastEnforcedState = snapshot.state
        Enforcement.reconcile(storage: services.storage,
                              selection: services.selection,
                              shield: services.shield)
    }

    private func run(_ operation: () throws -> ChildSessionSnapshot) {
        do {
            snapshot = try operation()
            errorText = nil
            enforceIfStateChanged()
        } catch {
            // Storage trouble is a parent problem, not a child one: keep the last good snapshot.
            errorText = "Something went wrong. Ask a grown-up to check the app."
        }
    }
}
