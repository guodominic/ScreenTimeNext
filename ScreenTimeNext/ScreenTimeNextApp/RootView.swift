//  RootView.swift
//  ScreenTimeNext
//
//  Task 003. Routes between onboarding and the (placeholder) home based on whether a child
//  profile exists. Reads services from the environment only.

import SwiftUI
import Combine
import ScreenTimeNextCore

struct RootView: View {
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase

    private enum Route { case loading, onboarding, home }
    @State private var route: Route = .loading
    @State private var showChildTimer = false

    var body: some View {
        Group {
            switch route {
            case .loading:
                ProgressView()
            case .onboarding:
                OnboardingFlow(services: services) { route = .home }
            case .home:
                ParentDashboardView(services: services,
                                    onOpenTimer: { showChildTimer = true },
                                    onReset: { reset() })
            }
        }
        .task {
            route = hasProfile ? .home : .onboarding
            presentTimerIfSessionExists()
        }
        // During a session the device is the child's: however the app is opened, the timer is
        // what they see. The Parents control (D-011) is the way to the dashboard.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { presentTimerIfSessionExists() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChildTimer)) { _ in
            if route == .home { showChildTimer = true }
        }
        .fullScreenCover(isPresented: $showChildTimer) {
            NavigationStack {
                ChildTimerView(services: services)
            }
        }
    }

    private func presentTimerIfSessionExists() {
        guard route == .home else { return }
        if (try? services.makeSessionController().tick())?.window != nil {
            showChildTimer = true
        }
    }

    private var hasProfile: Bool {
        (try? services.storage.loadChildProfile()) != nil
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
