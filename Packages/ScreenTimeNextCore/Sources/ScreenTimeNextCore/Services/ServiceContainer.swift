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
    public let presence: any SessionPresenting

    public init(
        authorization: any ScreenTimeAuthorizationService,
        selection: any ScreenTimeSelectionService,
        monitoring: any ScreenTimeMonitoringService,
        shield: any ScreenTimeShieldService,
        storage: any ScreenTimeStorageService,
        notifications: any NotificationScheduling = MockNotificationScheduler(),
        presence: any SessionPresenting = MockSessionPresenter()
    ) {
        self.authorization = authorization
        self.selection = selection
        self.monitoring = monitoring
        self.shield = shield
        self.storage = storage
        self.notifications = notifications
        self.presence = presence
    }

    /// A SessionController on this container's storage and notification scheduler.
    /// Every view model uses this so there is exactly one way to build one.
    public func makeSessionController() -> SessionController {
        SessionController(storage: storage, notifications: notifications, presence: presence)
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
    public static func phase0(notifications: any NotificationScheduling = MockNotificationScheduler(),
                              presence: any SessionPresenting = MockSessionPresenter()) -> ServiceContainer {
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
            notifications: notifications,
            presence: presence
        )
    }

    // MARK: Phase 1 (D-023)

    /// What the app runs on now that the paid membership exists.
    ///
    /// Storage moves to the App Group, because that is the only directory the DeviceActivityMonitor
    /// and Shield extensions can read — with a one-time copy of anything already in the app's own
    /// container, so an existing setup is not silently reset. The four Screen Time services are
    /// still passed in: they are swapped for the real FamilyControls adapters target by target
    /// (Tasks 004, 005, 010, 011), and until each one lands its mock keeps the app running.
    public static func live(authorization: any ScreenTimeAuthorizationService = MockScreenTimeAuthorizationService(),
                            selection: any ScreenTimeSelectionService = MockScreenTimeSelectionService(),
                            monitoring: any ScreenTimeMonitoringService = MockScreenTimeMonitoringService(),
                            shield: any ScreenTimeShieldService = MockScreenTimeShieldService(),
                            notifications: any NotificationScheduling = MockNotificationScheduler(),
                            presence: any SessionPresenting = MockSessionPresenter()) -> ServiceContainer {
        let storage: any ScreenTimeStorageService
        if let file = try? FileStorageService.shared() {
            storage = file
        } else {
            storage = InMemoryScreenTimeStorageService()
        }
        return ServiceContainer(authorization: authorization, selection: selection,
                                monitoring: monitoring, shield: shield, storage: storage,
                                notifications: notifications, presence: presence)
    }

    /// True when the storage lives in the App Group — i.e. when an extension could read it.
    /// False means the entitlement or provisioning is not in place and enforcement cannot work,
    /// however healthy the app itself looks.
    public var storageIsShared: Bool {
        (storage as? FileStorageService)?.directory.path.contains("Shared/AppGroup") ?? false
    }

    /// True when the container had to fall back to memory (nothing survives a relaunch).
    public var storageIsVolatile: Bool {
        storage is InMemoryScreenTimeStorageService
    }
}
