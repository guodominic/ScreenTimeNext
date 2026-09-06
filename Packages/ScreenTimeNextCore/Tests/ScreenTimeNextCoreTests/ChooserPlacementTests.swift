//  ChooserPlacementTests.swift
//  ScreenTimeNextCoreTests
//
//  D-016 — the child is asked what to do next at the SECOND-TO-LAST reminder.

import XCTest
@testable import ScreenTimeNextCore

final class ChooserPlacementTests: XCTestCase {

    func testChooserIsTheSecondToLastReminder() {
        // D-044 — the LAST reminder asks, not the second-to-last. The sequence a child meets is
        // heads-up → decide → go, and asking on the first shield puts the decision before they
        // have felt the time running out.
        XCTAssertEqual(WarningStateEngine.chooserIndex(warningCount: 3), 2)
        XCTAssertEqual(WarningStateEngine.chooserIndex(warningCount: 2), 1)   // 5/1 → the 1
        XCTAssertEqual(WarningStateEngine.chooserIndex(warningCount: 1), 0,
                       "with a single reminder there is no second-to-last")
        XCTAssertNil(WarningStateEngine.chooserIndex(warningCount: 0))
    }

    func testIsChooserMatchesTheIndex() {
        XCTAssertFalse(WarningStateEngine.isChooser(warningAt: 0, count: 3))
        XCTAssertFalse(WarningStateEngine.isChooser(warningAt: 1, count: 3))
        XCTAssertTrue(WarningStateEngine.isChooser(warningAt: 2, count: 3))
    }

    /// End to end: with 10/5/1 the chooser appears at 5 minutes, not at 10, and stays available
    /// afterwards until the child picks.
    /// D-044 — the sequence a child actually meets: heads-up, then decide, then the end.
    func testChoosingMomentArrivesAtTheLastReminder() throws {
        final class Clock: @unchecked Sendable { var now: Date; init(_ d: Date) { now = d } }
        let storage = InMemoryScreenTimeStorageService()
        var config = ScreenTimeConfiguration.default        // reminders 5/1
        config.dailyBudgetSeconds = 3600
        try storage.save(config)
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        let controller = SessionController(storage: storage, now: { clock.now })

        try controller.start()
        clock.now = clock.now.addingTimeInterval(3000)      // 600 left → before any reminder
        var snap = try controller.tick()
        XCTAssertEqual(snap.state, .active)
        XCTAssertFalse(snap.isChoosingMoment, "nothing has happened yet")

        clock.now = clock.now.addingTimeInterval(300)       // 300 left → the heads-up
        snap = try controller.tick()
        XCTAssertEqual(snap.state, .firstWarning)
        XCTAssertFalse(snap.isChoosingMoment, "too early — asking now gets an answer that expires")

        clock.now = clock.now.addingTimeInterval(240)       // 60 left → the one that asks
        snap = try controller.tick()
        XCTAssertEqual(snap.state, .finalWarning)
        XCTAssertTrue(snap.isChoosingMoment)

        try controller.choose(.lego)
        XCTAssertFalse(try controller.tick().isChoosingMoment, "chosen — stop asking")
    }
}
