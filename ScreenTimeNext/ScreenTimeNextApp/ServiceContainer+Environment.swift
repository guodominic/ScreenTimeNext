//  ServiceContainer+Environment.swift
//  ScreenTimeNext
//
//  Task 002. Injects the ServiceContainer into the SwiftUI environment so views resolve
//  services rather than constructing them (Rule 2). The app decides ONCE, at the root,
//  which container is live; nothing below it knows whether services are real or mocked.

import SwiftUI
import ScreenTimeNextCore

private struct ServiceContainerKey: EnvironmentKey {
    nonisolated static let defaultValue: ServiceContainer = .mocks()
}

extension EnvironmentValues {
    var services: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

extension View {
    /// Install a container for this view tree. Call once, at the app root.
    func services(_ container: ServiceContainer) -> some View {
        environment(\.services, container)
    }
}
