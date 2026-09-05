//  ChooserPlacementTests.swift
//  ScreenTimeNextCoreTests
//
//  D-016 — the child is asked what to do next at the SECOND-TO-LAST reminder.

import XCTest
@testable import ScreenTimeNextCore

final class ChooserPlacementTests: XCTestCase {

    func testChooserIsTheSecondToLastReminder() {
        XCTAssertEqual(WarningStateEngine.chooserIndex(warningCount: 3), 1)   // 10/5/1 → the 5
        XCTAssertEqual(WarningStateEngine.chooserIndex(warningCount: 2), 0)   // 10/1   → the 10
        XCTAssertEqual(WarningStateEngine.chooserIndex(warningCount: 1), 0,
                       "with a single reminder there is no second-to-last")
        XCTAssertNil(WarningStateEngine.chooserIndex(warningCount: 0))
    }

    func testIsChooserMatchesTheIndex() {
        XCTAssertFalse(WarningStateEngine.isChooser(warningAt: 0, count: 3))
        XCTAssertTrue(WarningStateEngine.isChooser(warningAt: 1, count: 3))
        XCTAssertFalse(WarningStateEngine.isChooser(warningAt: 2, count: 3))
    }

    /// End to end: with 10/5/1 the chooser appears at 5 minutes, not at 10, and stays available
    /// afterwards until the child picks.
    func testChoosingMomentArrivesAtTheSecondToLastReminder() throws {
        final class Clock: @unchecked Sendable { var now: Date; init(_ d: Date) { now = d } }
        let storage = InMemoryScreenTimeStorageService()
        var config = ScreenTimeConfiguration.default        // reminders 10/5/1
        config.dailyBudgetSeconds = 3600
        try storage.save(config)
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        let controller = SessionController(storage: storage, now: { clock.now })

        try controller.start()
        clock.now = clock.now.addingTimeInterval(3000)      // 600 left → first reminder
        var snap = try controller.tick()
        XCTAssertEqual(snap.state, .firstWarning)
        XCTAssertFalse(snap.isChoosingMoment, "too early — this is the 10-minute reminder")

        clock.now = clock.now.addingTimeInterval(300)       // 300 left → second-to-last
        snap = try controller.tick()
        XCTAssertEqual(snap.state, .secondWarning)
        XCTAssertTrue(snap.isChoosingMoment)

        clock.now = clock.now.addingTimeInterval(240)       // 60 left → still unchosen, still offered
        snap = try controller.tick()
        XCTAssertEqual(snap.state, .finalWarning)
        XCTAssertTrue(snap.isChoosingMoment)

        try controller.choose(.lego)
        XCTAssertFalse(try controller.tick().isChoosingMoment, "chosen — stop asking")
    }
}
