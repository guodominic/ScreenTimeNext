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
                                    onOpenTimer: { showChildTimer = true },
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
            if phase == .active {
                honourPendingTimerRequest()
                presentTimerIfSessionExists()
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
