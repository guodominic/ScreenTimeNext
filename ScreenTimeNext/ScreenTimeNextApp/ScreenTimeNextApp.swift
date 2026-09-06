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
    private let container: ServiceContainer = .live(notifications: UserNotificationScheduler(),
                                                   presence: LiveActivityPresenter())

    var body: some Scene {
        WindowGroup {
            RootView()
                .services(container)
        }
    }
}
