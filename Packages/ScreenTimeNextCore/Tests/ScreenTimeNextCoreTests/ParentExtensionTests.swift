//  ParentExtensionTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 013 (session half) — QA-11: the parent extension works after expiration.

import XCTest
@testable import ScreenTimeNextCore

final class ParentExtensionTests: XCTestCase {

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private var storage: InMemoryScreenTimeStorageService!
    private var scheduler: MockNotificationScheduler!
    private var clock: Clock!
    private var controller: SessionController!

    override func setUpWithError() throws {
        storage = InMemoryScreenTimeStorageService()
        scheduler = MockNotificationScheduler()
        clock = Clock(Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600))
        let c = clock!
        controller = SessionController(storage: storage, notifications: scheduler, now: { c.now })
        try storage.save(ChildProfile(name: "Ivy"))
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 900
        try storage.save(config)
    }

    /// QA-11 — extension after expiry reopens the session.
    func testExtendAfterExpiryResumesSession() throws {
        try controller.start()
        clock.advance(900)
        XCTAssertEqual(try controller.tick().state, .finished)
        let snap = try controller.extend(bySeconds: 600)
        // D-044 — the reminders are 5 and 1 minutes now, so ten minutes of extra time lands well
        // clear of both: the child gets an ordinary session back, not a session already warning.
        XCTAssertEqual(snap?.state, .active, "+10 at zero is past both reminders")
        XCTAssertEqual(snap?.remainingSeconds, 600)
        clock.advance(1)
        XCTAssertEqual(try controller.tick().remainingSeconds, 599)
    }

    func testExtendMidSessionAddsTime() throws {
        try controller.start()
        clock.advance(300)   // 600 left
        let snap = try controller.extend(bySeconds: 1200)
        XCTAssertEqual(snap?.remainingSeconds, 1800)
        XCTAssertEqual(snap?.state, .active, "resumes at the natural stage")
    }

    func testStackedExtensionsAccumulate() throws {
        try controller.start()
        clock.advance(900)
        try controller.extend(bySeconds: 600)
        try controller.extend(bySeconds: 600)
        XCTAssertEqual(try controller.tick().remainingSeconds, 1200)
        XCTAssertEqual(try storage.loadSessionWindow()?.totalSeconds, 2100)
    }

    func testExtensionKeepsChoiceAndReschedulesNotifications() throws {
        try controller.start()
        try controller.choose(.outside)
        clock.advance(900)
        let plansBefore = scheduler.plans.count
        let snap = try controller.extend(bySeconds: 1200)
        XCTAssertEqual(snap?.chosenActivity, .outside)
        XCTAssertEqual(scheduler.plans.count, plansBefore + 1)
        // New plan is derived from the new end: full set again (20 minutes ahead).
        XCTAssertEqual(scheduler.latestPlan?.count, 3, "D-044 — two reminders plus the finish")
    }

    func testExtensionIsBeyondBudgetSoRemainingTodayStaysZero() throws {
        try controller.start()
        clock.advance(900)
        try controller.extend(bySeconds: 600)
        XCTAssertEqual(try controller.remainingBudgetSeconds(), 0)
        clock.advance(600)
        XCTAssertEqual(try controller.tick().state, .finished)
        // Finalizing records the full extended length as used.
        try controller.endEarly()
        XCTAssertEqual(try storage.loadDailyUsage(for: clock.now)?.usedSeconds, 1500)
    }

    func testNothingToExtendReturnsNil() throws {
        XCTAssertNil(try controller.extend(bySeconds: 600))
        try controller.start()
        XCTAssertNil(try controller.extend(bySeconds: 0))
        XCTAssertNil(try controller.extend(bySeconds: -60))
    }

    func testYesterdaysWindowCannotBeExtended() throws {
        try controller.start()
        clock.advance(24 * 3600)
        XCTAssertNil(try controller.extend(bySeconds: 600))
        XCTAssertNil(try storage.loadSessionWindow(), "rollover finalized it")
    }
}
