//  EdgeCaseTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 017 — the §17 scenarios that can be reproduced without a device: termination/restart,
//  midnight, timezone, date/time changes, configuration changes, authorization revoked.
//  QA-12, QA-13, QA-14 (Phase 0 scope). Bypass/shield scenarios are Phase 1.

import XCTest
@testable import ScreenTimeNextCore

final class EdgeCaseTests: XCTestCase {

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private var clock: Clock!
    private var directory: URL!

    override func setUpWithError() throws {
        clock = Clock(Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600))
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EdgeCaseTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A controller on REAL file storage — "restart" = a fresh controller + fresh storage instance.
    private func boot(budget: Int = 1200, calendar: Calendar = .current) throws -> (SessionController, FileStorageService) {
        let storage = try FileStorageService(directory: directory)
        if try storage.loadChildProfile() == nil {
            try storage.save(ChildProfile(name: "Ivy"))
            var config = ScreenTimeConfiguration.default
            config.dailyBudgetSeconds = budget
            try storage.save(config)
        }
        let c = clock!
        return (SessionController(storage: storage, calendar: calendar, now: { c.now }), storage)
    }

    // MARK: QA-12 — restart does not destroy configuration or the session

    func testDeviceRestartMidSessionKeepsEverything() throws {
        let (a, _) = try boot()
        try a.start()
        try a.choose(.reading)
        clock.advance(500)

        let (b, storageB) = try boot()   // "restart"
        let snap = try b.restore()
        XCTAssertEqual(try storageB.loadConfiguration().dailyBudgetSeconds, 1200)
        XCTAssertEqual(try storageB.loadChildProfile()?.name, "Ivy")
        XCTAssertEqual(snap.remainingSeconds, 700)
        XCTAssertEqual(snap.chosenActivity, .reading)
        XCTAssertEqual(snap.state, .active)
    }

    func testRestartInEveryStageRestoresThatStage() throws {
        for (elapsed, expected) in [(0, ScreenTimeState.active), (700, .firstWarning), (950, .secondWarning), (1150, .finalWarning), (1200, .finished)] {
            try? FileManager.default.removeItem(at: directory)
            clock = Clock(Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600))
            let (a, _) = try boot()
            try a.start()
            clock.advance(TimeInterval(elapsed))
            let (b, _) = try boot()
            XCTAssertEqual(try b.restore().state, expected, "after \(elapsed)s")
        }
    }

    // MARK: QA-13 — midnight

    func testSessionSpanningMidnightIsNotCutOff() throws {
        let midnight = Calendar.current.startOfDay(for: clock.now.addingTimeInterval(24 * 3600))
        clock.now = midnight.addingTimeInterval(-10 * 60)   // 23:50
        let (c, _) = try boot(budget: 1200)
        try c.start()
        clock.now = midnight.addingTimeInterval(5 * 60)     // 00:05 — 15 of 20 minutes elapsed
        let snap = try c.tick()
        XCTAssertEqual(snap.state, .secondWarning)
        XCTAssertEqual(snap.remainingSeconds, 300)
    }

    func testFinishedSessionFromYesterdayIsFinalizedOnYesterday() throws {
        let midnight = Calendar.current.startOfDay(for: clock.now.addingTimeInterval(24 * 3600))
        clock.now = midnight.addingTimeInterval(-10 * 60)
        let (c, storage) = try boot(budget: 1200)
        try c.start()
        clock.now = midnight.addingTimeInterval(20 * 60)    // 00:20 — ended at 00:10
        let snap = try c.tick()
        XCTAssertEqual(snap.state, .idle, "new day")
        XCTAssertEqual(snap.remainingSeconds, 1200, "full budget today")
        XCTAssertEqual(try storage.loadDailyUsage(for: midnight.addingTimeInterval(-60))?.usedSeconds, 1200, "usage on the day it started")
        XCTAssertNil(try storage.loadDailyUsage(for: clock.now))
    }

    // MARK: Timezone change

    func testTimezoneChangeDoesNotEndARunningSession() throws {
        var tokyo = Calendar(identifier: .gregorian); tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var newYork = Calendar(identifier: .gregorian); newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // Start under one calendar, tick under another: "same day" flips, the window must survive.
        let (a, _) = try boot(calendar: newYork)
        try a.start()
        clock.advance(300)
        let (b, _) = try boot(calendar: tokyo)
        let snap = try b.tick()
        XCTAssertEqual(snap.remainingSeconds, 900)
        XCTAssertNotEqual(snap.state, .idle)
    }

    // MARK: Date/time changes

    func testForwardClockJumpEndsTheSession() throws {
        let (c, _) = try boot()
        try c.start()
        clock.advance(3 * 3600)
        XCTAssertEqual(try c.tick().state, .finished)
    }

    func testBackwardClockJumpCannotExceedWindowLength() throws {
        let (c, _) = try boot()
        try c.start()
        clock.advance(600)
        clock.advance(-24 * 3600)
        let snap = try c.tick()
        XCTAssertEqual(snap.remainingSeconds, 1200)
        XCTAssertNotEqual(snap.state, .idle, "a running window is never discarded by a clock change")
    }

    // MARK: Configuration changes mid-session

    func testBudgetChangeMidSessionAppliesToTheNextSession() throws {
        let (c, storage) = try boot(budget: 1200)
        try c.start()
        clock.advance(100)
        var config = try storage.loadConfiguration()
        config.dailyBudgetSeconds = 3600
        try storage.save(config)
        XCTAssertEqual(try c.tick().remainingSeconds, 1100, "running window is fixed")
        try c.endEarly()   // 100 s used
        XCTAssertEqual(try c.start().remainingSeconds, 3500, "next session sees the new budget")
    }

    func testActivityChangeMidSessionIsLive() throws {
        let (c, storage) = try boot()
        try c.start()
        var config = try storage.loadConfiguration()
        config.selectedActivities = [.bath]
        try storage.save(config)
        XCTAssertEqual(try c.availableActivities(), [.bath])
    }

    // MARK: QA-14 — authorization revoked (Phase 0 scope)

    /// Revocation is an enforcement concern (Phase 1). The session timer keeps running, the parent
    /// dashboard shows it, the child sees nothing technical (§7.6).
    func testRevocationDoesNotStopTheTimer() async throws {
        let auth = MockScreenTimeAuthorizationService()
        _ = try await auth.requestAuthorization()
        let (c, _) = try boot()
        try c.start()
        auth.revoke()
        clock.advance(60)
        let status = await auth.status
        XCTAssertEqual(status, .revoked)
        XCTAssertEqual(try c.tick().remainingSeconds, 1140)
    }
}
