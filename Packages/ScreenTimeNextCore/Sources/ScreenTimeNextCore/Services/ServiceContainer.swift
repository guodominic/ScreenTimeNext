//  ServiceContainer.swift
//  ScreenTimeNextCore
//
//  Task 002. The single dependency boundary between SwiftUI and everything else.
//  Views never construct services; they receive this container (see the app target's
//  ServiceContainer+Environment.swift) and talk to protocols only. Rules 1 and 2.

import Foundation

public struct ServiceContainer: Sendable {
    public let authorization: any ScreenTimeAuthorizationService
    public let selection: any ScreenTimeSelectionService
    public let monitoring: any ScreenTimeMonitoringService
    public let shield: any ScreenTimeShieldService
    public let storage: any ScreenTimeStorageService
    public let notifications: any NotificationScheduling

    public init(
        authorization: any ScreenTimeAuthorizationService,
        selection: any ScreenTimeSelectionService,
        monitoring: any ScreenTimeMonitoringService,
        shield: any ScreenTimeShieldService,
        storage: any ScreenTimeStorageService,
        notifications: any NotificationScheduling = MockNotificationScheduler()
    ) {
        self.authorization = authorization
        self.selection = selection
        self.monitoring = monitoring
        self.shield = shield
        self.storage = storage
        self.notifications = notifications
    }

    /// A SessionController on this container's storage and notification scheduler.
    /// Every view model uses this so there is exactly one way to build one.
    public func makeSessionController() -> SessionController {
        SessionController(storage: storage, notifications: notifications)
    }

    /// Everything mocked. This is what Phase 0 runs on (D-007) and what previews use.
    public static func mocks(
        authorization: MockScreenTimeAuthorizationService = MockScreenTimeAuthorizationService(),
        selection: MockScreenTimeSelectionService = MockScreenTimeSelectionService(),
        monitoring: MockScreenTimeMonitoringService = MockScreenTimeMonitoringService(),
        shield: MockScreenTimeShieldService = MockScreenTimeShieldService(),
        storage: InMemoryScreenTimeStorageService = InMemoryScreenTimeStorageService(),
        notifications: MockNotificationScheduler = MockNotificationScheduler()
    ) -> ServiceContainer {
        ServiceContainer(authorization: authorization, selection: selection,
                         monitoring: monitoring, shield: shield, storage: storage,
                         notifications: notifications)
    }

    // MARK: Phase 0 (D-007)

    /// What the app actually runs on before the paid membership exists: the four Screen Time
    /// services mocked, persistence real (app container). Falls back to in-memory storage only if
    /// the container cannot be opened — and reports that through `storageIsVolatile`.
    public static func phase0(notifications: any NotificationScheduling = MockNotificationScheduler()) -> ServiceContainer {
        let storage: any ScreenTimeStorageService
        if let file = try? FileStorageService.appContainer() {
            storage = file
        } else {
            storage = InMemoryScreenTimeStorageService()
        }
        return ServiceContainer(
            authorization: MockScreenTimeAuthorizationService(),
            selection: MockScreenTimeSelectionService(),
            monitoring: MockScreenTimeMonitoringService(),
            shield: MockScreenTimeShieldService(),
            storage: storage,
            notifications: notifications
        )
    }

    /// True when the container had to fall back to memory (nothing survives a relaunch).
    public var storageIsVolatile: Bool {
        storage is InMemoryScreenTimeStorageService
    }
}
