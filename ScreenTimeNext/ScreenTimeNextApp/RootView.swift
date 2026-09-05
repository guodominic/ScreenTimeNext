//  RootView.swift
//  ScreenTimeNext
//
//  Task 003. Routes between onboarding and the (placeholder) home based on whether a child
//  profile exists. Reads services from the environment only.

import SwiftUI
import ScreenTimeNextCore

struct RootView: View {
    @Environment(\.services) private var services

    private enum Route { case loading, onboarding, home }
    @State private var route: Route = .loading

    var body: some View {
        Group {
            switch route {
            case .loading:
                ProgressView()
            case .onboarding:
                OnboardingFlow(services: services) { route = .home }
            case .home:
                HomePlaceholderView { reset() }
            }
        }
        .task { route = hasProfile ? .home : .onboarding }
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
