//  MockServicesTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 002. The mocks are Phase 0's production services (D-007), so their contracts get tests.

import XCTest
@testable import ScreenTimeNextCore

final class MockServicesTests: XCTestCase {

    // MARK: Authorization

    func testAuthorizationApproveScript() async throws {
        let auth = MockScreenTimeAuthorizationService()
        let before = await auth.status
        XCTAssertEqual(before, .notDetermined)
        let result = try await auth.requestAuthorization()
        XCTAssertEqual(result, .approved)
        XCTAssertEqual(auth.requestCount, 1)
    }

    /// QA-02 — denial must surface as an error the UI can handle, and leave a readable status.
    func testAuthorizationDenyScriptThrowsAndRecordsDenied() async {
        let auth = MockScreenTimeAuthorizationService(script: .deny)
        do {
            _ = try await auth.requestAuthorization()
            XCTFail("expected denial")
        } catch ScreenTimeAuthorizationError.denied {
            let status = await auth.status
            XCTAssertEqual(status, .denied)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testRevokeMovesApprovedToRevoked() async throws {
        let auth = MockScreenTimeAuthorizationService()
        _ = try await auth.requestAuthorization()
        auth.revoke()
        let status = await auth.status
        XCTAssertEqual(status, .revoked)
    }

    // MARK: Selection

    func testSelectionRoundTripAndDecodeFailure() throws {
        let sel = MockScreenTimeSelectionService()
        XCTAssertNil(try sel.loadSelection())
        let snap = MockScreenTimeSelectionService.sampleSnapshot()
        try sel.save(snap)
        XCTAssertEqual(try sel.loadSelection(), snap)
        sel.setFailDecoding(true)
        XCTAssertThrowsError(try sel.loadSelection())
    }

    // MARK: Shield — QA-10 / Rule 6 idempotency contract

    func testShieldApplyAndRemoveAreCountedAndStateful() throws {
        let shield = MockScreenTimeShieldService()
        let snap = MockScreenTimeSelectionService.sampleSnapshot()
        XCTAssertEqual(shield.currentProtectionState, .unshielded)
        try shield.applyShield(for: snap)
        try shield.applyShield(for: snap)
        XCTAssertEqual(shield.currentProtectionState, .shielded)
        XCTAssertEqual(shield.applyCount, 2, "the mock counts calls; the real adapter (Task 011) must make the 2nd a no-op")
        try shield.removeShield()
        XCTAssertEqual(shield.currentProtectionState, .unshielded)
        XCTAssertNil(shield.lastShielded)
    }

    func testShieldRejectsEmptySelection() {
        let shield = MockScreenTimeShieldService()
        let empty = SelectionSnapshot(payload: Data(), summary: .empty)
        XCTAssertThrowsError(try shield.applyShield(for: empty))
    }

    // MARK: Monitoring

    func testMonitoringRecordsRegistrationsAndRestart() async throws {
        let mon = MockScreenTimeMonitoringService()
        let snap = MockScreenTimeSelectionService.sampleSnapshot()
        var running = await mon.isMonitoring
        XCTAssertFalse(running)
        try await mon.startMonitoring(budgetSeconds: 3600, selection: snap)
        try await mon.restartMonitoring(budgetSeconds: 1800, selection: snap)
        running = await mon.isMonitoring
        XCTAssertTrue(running)
        XCTAssertEqual(mon.registrations.map(\.budgetSeconds), [3600, 1800])
        XCTAssertEqual(mon.stopCount, 1)
    }

    // MARK: Storage

    func testInMemoryStorageRoundTripsEveryRecord() throws {
        let store = InMemoryScreenTimeStorageService()
        XCTAssertEqual(try store.loadConfiguration(), .default, "missing config yields defaults")

        let profile = ChildProfile(name: "Ivy")
        try store.save(profile)
        XCTAssertEqual(try store.loadChildProfile(), profile)

        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 1800
        try store.save(config)
        XCTAssertEqual(try store.loadConfiguration().dailyBudgetSeconds, 1800)

        let noon = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        try store.save(DailyUsage(date: noon, budgetSeconds: 1800, usedSeconds: 600))
        let sameDayLater = noon.addingTimeInterval(3 * 3600)
        XCTAssertEqual(try store.loadDailyUsage(for: sameDayLater)?.usedSeconds, 600, "usage is bucketed by calendar day")

        let window = SessionWindow(startedAt: noon, budgetSeconds: 1800)
        try store.save(window)
        XCTAssertEqual(try store.loadSessionWindow(), window)
        try store.clearSessionWindow()
        XCTAssertNil(try store.loadSessionWindow())

        try store.save(ProtectionState.shielded)
        XCTAssertEqual(try store.loadProtectionState(), .shielded)
    }

    func testStorageFailureSurfacesAsContainerUnavailable() {
        let store = InMemoryScreenTimeStorageService()
        store.setFailing(true)
        XCTAssertThrowsError(try store.loadConfiguration()) { error in
            guard case ScreenTimeStorageError.containerUnavailable = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    // MARK: Container

    func testMockContainerWiresEverything() async {
        let container = ServiceContainer.mocks()
        let status = await container.authorization.status
        XCTAssertEqual(status, .notDetermined)
        XCTAssertEqual(container.shield.currentProtectionState, .unshielded)
        XCTAssertEqual(try? container.storage.loadConfiguration(), .default)
    }
}
