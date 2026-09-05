//  ScreenTimeNextApp.swift
//  ScreenTimeNext
//
//  App entry point. Task 001/002. Root navigation is Task 003.

import SwiftUI
import ScreenTimeNextCore

@main
struct ScreenTimeNextApp: App {

    /// Phase 0 (D-007): the whole app runs on mocks — no entitlement, no device required.
    /// Phase 1 swaps real adapters in here, and nowhere else.
    private let container: ServiceContainer = .mocks()

    var body: some Scene {
        WindowGroup {
            RootView()
                .services(container)
        }
    }
}
