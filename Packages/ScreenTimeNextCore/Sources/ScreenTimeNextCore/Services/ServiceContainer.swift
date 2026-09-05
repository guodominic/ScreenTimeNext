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

    public init(
        authorization: any ScreenTimeAuthorizationService,
        selection: any ScreenTimeSelectionService,
        monitoring: any ScreenTimeMonitoringService,
        shield: any ScreenTimeShieldService,
        storage: any ScreenTimeStorageService
    ) {
        self.authorization = authorization
        self.selection = selection
        self.monitoring = monitoring
        self.shield = shield
        self.storage = storage
    }

    /// Everything mocked. This is what Phase 0 runs on (D-007) and what previews use.
    public static func mocks(
        authorization: MockScreenTimeAuthorizationService = MockScreenTimeAuthorizationService(),
        selection: MockScreenTimeSelectionService = MockScreenTimeSelectionService(),
        monitoring: MockScreenTimeMonitoringService = MockScreenTimeMonitoringService(),
        shield: MockScreenTimeShieldService = MockScreenTimeShieldService(),
        storage: InMemoryScreenTimeStorageService = InMemoryScreenTimeStorageService()
    ) -> ServiceContainer {
        ServiceContainer(authorization: authorization, selection: selection,
                         monitoring: monitoring, shield: shield, storage: storage)
    }
}
