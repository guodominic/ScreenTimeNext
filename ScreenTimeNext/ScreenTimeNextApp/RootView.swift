//  RootView.swift
//  ScreenTimeNext
//
//  Routes between first-run setup, the parent dashboard, and the child timer. D-016: after setup
//  the parent is handed a RUNNING timer, and any launch during a session shows the timer.
//  Reads services from the environment only.

import SwiftUI
import Combine
import ScreenTimeNextCore

struct RootView: View {
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase

    private enum Route { case loading, onboarding, home }
    @State private var route: Route = .loading
    @State private var showChildTimer = false
    /// A notification tapped before the app finished routing — honoured once `route` settles.
    @State private var pendingTimerRequest = false
    /// D-046 — a parent came through the gate and is on the dashboard on purpose.
    ///
    /// Without this, `presentTimerIfSessionExists` fires on every return to `.active` and drags
    /// them straight back to the timer. Face ID made it obvious — its system sheet takes the scene
    /// inactive and hands it back active, so unlocking bounced the parent out of the screen they
    /// had just unlocked — but the PIN had the same bug more quietly: glance at a notification,
    /// come back, and the dashboard is gone.
    @State private var parentIsAtTheDashboard = false

    var body: some View {
        Group {
            switch route {
            case .loading:
                ProgressView()
            case .onboarding:
                OnboardingFlow(services: services) {
                    route = .home
                    showChildTimer = true      // D-016: hand over a running timer, not a summary
                }
            case .home:
                ParentDashboardView(services: services,
                                    onOpenTimer: {
                                        // Chosen, so the auto-present rule applies again from here.
                                        parentIsAtTheDashboard = false
                                        showChildTimer = true
                                    },
                                    onReset: { reset() })
            }
        }
        .task {
            route = isSetUp ? .home : .onboarding
            honourPendingTimerRequest()
            presentTimerIfSessionExists()
        }
        // During a session the device is the child's: however the app is opened, the timer is
        // what they see. The Parents control (D-011) is the way to the dashboard.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                honourPendingTimerRequest()
                presentTimerIfSessionExists()
            case .background:
                // D-046 — the app really went away, so the device may be back in the child's
                // hands. `.inactive` deliberately does NOT do this: that is a system sheet (Face
                // ID), the app switcher, or the notification shade, and the parent never left.
                parentIsAtTheDashboard = false
            default:
                break
            }
        }
        // A warning was tapped. If routing hasn't finished yet (cold launch straight from the
        // notification), remember it and honour it as soon as it has.
        .onReceive(NotificationCenter.default.publisher(for: .openChildTimer)) { _ in
            pendingTimerRequest = true
            honourPendingTimerRequest()
        }
        .fullScreenCover(isPresented: $showChildTimer) {
            NavigationStack {
                ChildTimerView(services: services)
            }
        }
        .onChange(of: showChildTimer) { wasShowing, isShowing in
            // Dismissed rather than presented: the only way out of the timer is the parent gate
            // (D-036), so this closing IS a parent arriving at the dashboard.
            if wasShowing && !isShowing { parentIsAtTheDashboard = true }
        }
    }

    /// A reminder was tapped. Two sources, because one of them can fire before this view exists:
    /// the in-process broadcast (app already running) and the latch (launched BY the tap).
    private func honourPendingTimerRequest() {
        let latched = TimerRoutingLatch.shared.consume()
        guard pendingTimerRequest || latched else { return }
        guard route == .home else {
            pendingTimerRequest = true      // still onboarding — honour it once routing settles
            return
        }
        pendingTimerRequest = false
        showChildTimer = true
    }

    private func presentTimerIfSessionExists() {
        guard route == .home else { return }
        // D-046 — the parent unlocked their way out here. Leave them where they meant to be.
        guard !parentIsAtTheDashboard else { return }
        if (try? services.makeSessionController().tick())?.window != nil {
            showChildTimer = true
        }
    }

    /// D-016 — setup is "has a configuration been written", not "is there a profile": the name is
    /// optional now, so a saved budget is what marks the app as set up.
    private var isSetUp: Bool {
        (try? services.storage.hasStoredConfiguration()) ?? false
    }

    /// Parent-initiated "start over": erase ScreenTimeNext's own records, then onboard again.
    private func reset() {
        try? services.storage.eraseAll()
        try? services.selection.clearSelection()
        route = .onboarding
    }
}

#Preview("Fresh install") {
    RootView().services(.mocks())
}

private func storageWithProfile() -> InMemoryScreenTimeStorageService {
    let storage = InMemoryScreenTimeStorageService()
    try? storage.save(ChildProfile(name: "Ivy"))
    return storage
}

#Preview("Already set up") {
    RootView().services(.mocks(storage: storageWithProfile()))
}
