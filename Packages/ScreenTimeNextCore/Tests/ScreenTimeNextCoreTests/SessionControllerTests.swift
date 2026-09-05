//  SessionControllerTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 007 — QA-06 (countdown survives background/foreground) and QA-07 (state progression),
//  under the D-006 session-window model. The clock is injected; nothing sleeps.

import XCTest
@testable import ScreenTimeNextCore

final class SessionControllerTests: XCTestCase {

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private var storage: InMemoryScreenTimeStorageService!
    private var clock: Clock!
    private var controller: SessionController!
    private var noon: Date!

    override func setUpWithError() throws {
        storage = InMemoryScreenTimeStorageService()
        noon = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        clock = Clock(noon)
        let c = clock!
        controller = SessionController(storage: storage, now: { c.now })
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 1200   // 20 minutes keeps the walk-through short
        try storage.save(config)
    }

    func testFreshDayIsIdleWithFullBudget() throws {
        let snap = try controller.restore()
        XCTAssertEqual(snap.state, .idle)
        XCTAssertEqual(snap.remainingSeconds, 1200)
        XCTAssertNil(snap.window)
    }

    func testStartCreatesAndPersistsWindow() throws {
        let snap = try controller.start()
        XCTAssertEqual(snap.state, .active)
        XCTAssertEqual(snap.remainingSeconds, 1200)
        XCTAssertEqual(try storage.loadSessionWindow()?.startedAt, noon)
    }

    /// QA-07 — the full progression, driven only by the clock.
    func testProgressionThroughWarningsToFinished() throws {
        try controller.start()
        clock.advance(599)   // 601 left
        XCTAssertEqual(try controller.tick().state, .active)
        clock.advance(1)     // 600 left — inclusive boundary
        XCTAssertEqual(try controller.tick().state, .warning10)
        clock.advance(300)   // 300 left
        XCTAssertEqual(try controller.tick().state, .warning5)
        clock.advance(240)   // 60 left
        XCTAssertEqual(try controller.tick().state, .warning1)
        clock.advance(60)    // 0 left
        let done = try controller.tick()
        XCTAssertEqual(done.state, .finished)
        XCTAssertEqual(done.remainingSeconds, 0)
    }

    /// QA-06 — backgrounded for 20 minutes: a fresh controller on the same storage (relaunch)
    /// reports the right remaining time immediately, with no catch-up.
    func testRelaunchAfterLongGapRestoresCorrectRemaining() throws {
        try controller.start()
        clock.advance(700)
        let c = clock!
        let relaunched = SessionController(storage: storage, now: { c.now })
        let snap = try relaunched.restore()
        XCTAssertEqual(snap.remainingSeconds, 500)
        XCTAssertEqual(snap.state, .warning10)
    }

    func testFinishedWindowCountsAgainstBudgetEvenBeforeFinalization() throws {
        try controller.start()
        clock.advance(1200)
        XCTAssertEqual(try controller.tick().state, .finished)
        XCTAssertEqual(try controller.remainingBudgetSeconds(), 0, "the window itself is the in-flight record")
        XCTAssertNil(try storage.loadDailyUsage(for: noon), "nothing folded into DailyUsage until finalized")
        // Starting again finalizes the old window (1200 recorded) and yields finished with no window.
        let again = try controller.start()
        XCTAssertEqual(again.state, .finished)
        XCTAssertNil(again.window)
        XCTAssertEqual(try storage.loadDailyUsage(for: noon)?.usedSeconds, 1200)
        XCTAssertNil(try storage.loadSessionWindow())
    }

    /// The scenario that motivated the accounting rule: time ran out while the app was killed.
    func testExpiryWhileAppWasKilledStillCountsAfterRelaunch() throws {
        try controller.start()
        clock.advance(5000)   // long after expiry, app was closed the whole time
        let c = clock!
        let relaunched = SessionController(storage: storage, now: { c.now })
        XCTAssertEqual(try relaunched.restore().state, .finished)
        XCTAssertEqual(try relaunched.remainingBudgetSeconds(), 0)
        XCTAssertEqual(try relaunched.start().state, .finished, "cannot restart today")
    }

    func testEndEarlyRecordsPartialUsageAndReturnsToIdle() throws {
        try controller.start()
        clock.advance(300)
        let snap = try controller.endEarly()
        XCTAssertEqual(snap.state, .idle)
        XCTAssertEqual(snap.remainingSeconds, 900)
        XCTAssertNil(try storage.loadSessionWindow())
        XCTAssertEqual(try storage.loadDailyUsage(for: noon)?.usedSeconds, 300)
        // A second session today gets only what is left.
        XCTAssertEqual(try controller.start().remainingSeconds, 900)
    }

    /// PRD §11 — a window from yesterday is finalized on ITS day; today starts idle with a full budget.
    func testWindowFromAnotherDayIsFinalizedAndDiscarded() throws {
        try controller.start()
        clock.advance(24 * 3600)
        let snap = try controller.tick()
        XCTAssertEqual(snap.state, .idle)
        XCTAssertNil(try storage.loadSessionWindow())
        XCTAssertEqual(snap.remainingSeconds, 1200, "new day, full budget")
        XCTAssertEqual(try storage.loadDailyUsage(for: noon)?.usedSeconds, 1200, "yesterday got its usage")
        XCTAssertNil(try storage.loadDailyUsage(for: clock.now))
    }

    /// PRD §17 — clock moved backward cannot manufacture time beyond the window's length.
    func testBackwardClockChangeIsClamped() throws {
        try controller.start()
        clock.advance(600)
        XCTAssertEqual(try controller.tick().remainingSeconds, 600)
        clock.advance(-3600)   // child sets the clock back an hour
        XCTAssertEqual(try controller.tick().remainingSeconds, 1200, "clamped to the window total, not 4200")
    }

    func testSessionNeverStepsBackwardOnJitter() throws {
        try controller.start()
        clock.advance(900)   // 300 left → warning5
        XCTAssertEqual(try controller.tick().state, .warning5)
        clock.advance(-2)    // tiny jitter back to 302
        XCTAssertEqual(try controller.tick().state, .warning5)
    }

    func testDisabledWarningIsEnteredButDisplayedAsActive() throws {
        var config = try storage.loadConfiguration()
        config.warning10Enabled = false
        try storage.save(config)
        try controller.start()
        clock.advance(650)   // 550 left → warning10
        let snap = try controller.tick()
        XCTAssertEqual(snap.state, .warning10)
        XCTAssertFalse(snap.presentsWarning)
        XCTAssertEqual(snap.displayState, .active)
    }
}
