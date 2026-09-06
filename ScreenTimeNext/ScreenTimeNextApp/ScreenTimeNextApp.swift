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
    /// Real so far: authorization (004), selection (005), monitoring (010) and the shield (011).
    /// Task 012 is what decides WHEN the shield goes up.
    private let container: ServiceContainer = ScreenTimeNextApp.makeContainer()

    /// Task 010 — owns the DeviceActivity registration so no view has to think about it. Held
    /// here because it must outlive every screen: the schedule is the app's, not a screen's.
    @State private var monitoring: MonitoringCoordinator?

    private static func makeContainer() -> ServiceContainer {
        // The App Group store can only fail to open when provisioning is wrong. Falling back to the
        // mock keeps the app usable (and says so on the dashboard) instead of crashing at launch.
        let selection: any ScreenTimeSelectionService
        if let shared = AppGroupSelectionService() {
            selection = shared
        } else {
            selection = MockScreenTimeSelectionService()
        }
        // The shield needs the same storage the container will use, so it is built here rather
        // than defaulted: a shield that wrote its ProtectionState somewhere else would leave the
        // dashboard describing a device it is not looking at.
        let storage: (any ScreenTimeStorageService)? = try? FileStorageService.shared()
        return .live(authorization: FamilyControlsAuthorizationService(),
                     selection: selection,
                     monitoring: DeviceActivityMonitoringService(),
                     shield: ManagedSettingsShieldService(storage: storage),
                     notifications: UserNotificationScheduler(),
                     presence: LiveActivityPresenter(),
                     unlock: LocalAuthenticationUnlockService())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .services(container)
                .task {
                    guard monitoring == nil else { return }
                    let coordinator = MonitoringCoordinator(monitoring: container.monitoring,
                                                            storage: container.storage,
                                                            selection: container.selection,
                                                            shield: container.shield)
                    monitoring = coordinator
                    coordinator.start()
                }
        }
    }
}
