//  ScreenTimeNextApp.swift
//  ScreenTimeNext
//
//  App entry point. Task 001/002. Root navigation is Task 003.

import SwiftUI
import ScreenTimeNextCore

@main
struct ScreenTimeNextApp: App {

    /// D-023 — Phase 1. Persistence is the App Group container (the only one the extensions can
    /// read); the Screen Time services are swapped for real adapters here, one task at a time.
    /// This is the ONLY place any of that is decided.
    ///
    /// Real so far: authorization (Task 004) and selection (Task 005). Monitoring (010) and the
    /// shield (011) are still mocked, so the app runs end to end while they are built.
    private let container: ServiceContainer = ScreenTimeNextApp.makeContainer()

    private static func makeContainer() -> ServiceContainer {
        // The App Group store can only fail to open when provisioning is wrong. Falling back to the
        // mock keeps the app usable (and says so on the dashboard) instead of crashing at launch.
        let selection: any ScreenTimeSelectionService
        if let shared = AppGroupSelectionService() {
            selection = shared
        } else {
            selection = MockScreenTimeSelectionService()
        }
        return .live(authorization: FamilyControlsAuthorizationService(),
                     selection: selection,
                     notifications: UserNotificationScheduler(),
                     presence: LiveActivityPresenter())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .services(container)
        }
    }
}
