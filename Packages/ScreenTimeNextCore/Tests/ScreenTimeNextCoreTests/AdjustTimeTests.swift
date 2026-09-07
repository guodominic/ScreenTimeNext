//  AdjustTimeTests.swift
//  ScreenTimeNextCoreTests
//
//  D-052 / D-053 — a parent adding or taking back minutes from the dashboard.
//
//  The bug these pin was reported from a real device: after adding time, both the child's timer
//  and the Dynamic Island went on saying the session was over. The cause was the monotonic
//  ratchet in `WarningStateEngine` — it exists so clock jitter cannot walk a session backward,
//  and `.finished` is the top of it. Moving the window's END is not jitter, and every
//  `SessionController` holds its own latch, so the dashboard's recovery never reached the timer's.

import XCTest
@testable import ScreenTimeNextCore

final class AdjustTimeTests: XCTestCase {

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private var storage: InMemoryScreenTimeStorageService!
    private var clock: Clock!

    override func setUpWithError() throws {
        storage = InMemoryScreenTimeStorageService()
        clock = Clock(Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600))
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 900
        try storage.save(config)
    }

    private func makeController() -> SessionController {
        let c = clock!
        return SessionController(storage: storage, now: { c.now })
    }

    // MARK: D-052 — "+3" means three minutes from now

    func testAddingTimeToAnExpiredSessionCountsFromNow() throws {
        let controller = makeController()
        try controller.start()
        clock.advance(1200)                                  // 5 minutes past the end
        XCTAssertEqual(try controller.tick().remainingSeconds, 0)

        let snap = try XCTUnwrap(try controller.adjust(bySeconds: 180))
        XCTAssertEqual(snap.remainingSeconds, 180,
                       "three minutes from now, not three past an end that has been and gone")
    }

    func testAddingTimeToARunningSessionExtendsTheEnd() throws {
        let controller = makeController()
        try controller.start()
        clock.advance(300)                                   // 600 left
        let snap = try XCTUnwrap(try controller.adjust(bySeconds: 180))
        XCTAssertEqual(snap.remainingSeconds, 780, "added to the end, not to now")
    }

    func testTakingTimeBackShortensTheWindow() throws {
        let controller = makeController()
        try controller.start()
        clock.advance(300)                                   // 600 left
        let snap = try XCTUnwrap(try controller.adjust(bySeconds: -180))
        XCTAssertEqual(snap.remainingSeconds, 420)
    }

    /// A session cannot be made to have ended in the past — the window would invert, and an
    /// inverted window is what left the Dynamic Island with nothing to draw.
    func testTakingBackMoreThanIsLeftStopsAtNowRatherThanInverting() throws {
        let controller = makeController()
        try controller.start()
        clock.advance(100)
        _ = try controller.adjust(bySeconds: -3600)

        let window = try XCTUnwrap(try storage.loadSessionWindow())
        XCTAssertEqual(window.remainingSeconds(at: clock.now), 0)
        XCTAssertGreaterThanOrEqual(window.endsAt, window.startedAt,
                                    "startedAt...endsAt has to stay a valid range")
        XCTAssertEqual(window.endsAt, clock.now)
    }

    // MARK: D-053 — the ratchet lets go when the end moves

    func testAddingTimeBringsAFinishedSessionBack() throws {
        let controller = makeController()
        try controller.start()
        clock.advance(900)
        XCTAssertEqual(try controller.tick().state, .finished)

        _ = try controller.adjust(bySeconds: 180)
        let snap = try controller.tick()
        XCTAssertNotEqual(snap.state, .finished, "there are three minutes on it")
        XCTAssertEqual(snap.remainingSeconds, 180)
    }

    /// The reported bug. The dashboard and the child's timer are two `SessionController`s over one
    /// storage; the parent adjusts on the first and the child is looking at the second.
    func testASecondControllerAlsoRecovers() throws {
        let dashboard = makeController()
        let timer = makeController()

        try dashboard.start()
        clock.advance(900)
        XCTAssertEqual(try timer.tick().state, .finished, "the timer has latched Time's Up")

        _ = try dashboard.adjust(bySeconds: 180)

        let snap = try timer.tick()
        XCTAssertEqual(snap.remainingSeconds, 180, "the timer must show the new time, not zero")
        XCTAssertNotEqual(snap.state, .finished)
    }

    /// The ratchet still does its job second to second: an end that has NOT moved cannot be walked
    /// backward by the clock stuttering.
    func testTheRatchetStillHoldsWhenTheEndHasNotMoved() throws {
        let controller = makeController()
        try controller.start()
        clock.advance(890)                                   // 10 left → the last reminder
        XCTAssertEqual(try controller.tick().state, .finalWarning)

        clock.advance(-600)                                  // clock jitters backward
        XCTAssertEqual(try controller.tick().state, .finalWarning,
                       "a session does not go back to .active because the clock moved")
    }

    /// D-050 — the same rule has to cover the paused clock, which also moves the end.
    func testCreditingAPauseAlsoReleasesTheLatch() throws {
        let controller = makeController()
        try controller.start()
        clock.advance(900)
        XCTAssertEqual(try controller.tick().state, .finished)

        let window = try XCTUnwrap(try storage.loadSessionWindow())
        try storage.save(window.paused(bySeconds: 120))

        let snap = try controller.tick()
        XCTAssertEqual(snap.remainingSeconds, 120)
        XCTAssertNotEqual(snap.state, .finished)
    }
}
