//  ScreenTimeNextApp.swift
//  ScreenTimeNext
//
//  App entry point. Task 001/002. Root navigation is Task 003.

import SwiftUI
import ScreenTimeNextCore

@main
struct ScreenTimeNextApp: App {

    /// Phase 0 (D-007): Screen Time services mocked, persistence real (app container).
    /// Phase 1 swaps real adapters and the App Group container in here, and nowhere else.
    private let container: ServiceContainer = .phase0(notifications: UserNotificationScheduler())

    var body: some Scene {
        WindowGroup {
            RootView()
                .services(container)
        }
    }
}
