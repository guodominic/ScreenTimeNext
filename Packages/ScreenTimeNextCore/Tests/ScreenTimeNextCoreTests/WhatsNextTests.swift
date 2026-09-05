//  WhatsNextTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 009 — QA-08: the child can select a next activity, and it survives to Time's Up.

import XCTest
@testable import ScreenTimeNextCore

final class WhatsNextTests: XCTestCase {

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private var storage: InMemoryScreenTimeStorageService!
    private var clock: Clock!
    private var controller: SessionController!

    override func setUpWithError() throws {
        storage = InMemoryScreenTimeStorageService()
        clock = Clock(Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600))
        let c = clock!
        controller = SessionController(storage: storage, now: { c.now })
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 900
        config.selectedActivities = [.lego, .reading]
        try storage.save(config)
    }

    func testAvailableActivitiesAreTheParentsPicks() throws {
        XCTAssertEqual(try controller.availableActivities(), [.lego, .reading])
    }

    /// D-009 — empty parent set offers the whole fixed set.
    func testEmptyParentSetOffersAllEight() throws {
        var config = try storage.loadConfiguration()
        config.selectedActivities = []
        try storage.save(config)
        XCTAssertEqual(try controller.availableActivities(), TransitionActivity.allCases)
    }

    func testChoiceIsPersistedOnTheWindowAndSurvivesRelaunch() throws {
        try controller.start()
        clock.advance(400)   // 500 left → warning10
        let snap = try controller.choose(.lego)
        XCTAssertEqual(snap.chosenActivity, .lego)
        XCTAssertEqual(try storage.loadSessionWindow()?.chosenActivity, .lego)

        let c = clock!
        let relaunched = SessionController(storage: storage, now: { c.now })
        XCTAssertEqual(try relaunched.restore().chosenActivity, .lego)
    }

    func testChoiceCarriesThroughToFinishedAndClearsOnNextStart() throws {
        try controller.start()
        try controller.choose(.reading)
        clock.advance(900)
        let done = try controller.tick()
        XCTAssertEqual(done.state, .finished)
        XCTAssertEqual(done.chosenActivity, .reading, "Time's Up can name it")
        // Next day, next session: no leftover choice.
        clock.advance(24 * 3600)
        let next = try controller.start()
        XCTAssertNil(next.chosenActivity)
    }

    func testChoosingWithoutASessionIsANoOp() throws {
        let snap = try controller.choose(.snack)
        XCTAssertEqual(snap.state, .idle)
        XCTAssertNil(snap.chosenActivity)
        XCTAssertNil(try storage.loadSessionWindow())
    }

    func testChoiceCanBeChanged() throws {
        try controller.start()
        try controller.choose(.lego)
        XCTAssertEqual(try controller.choose(.reading).chosenActivity, .reading)
    }

    func testExtensionKeepsTheChoice() {
        let w = SessionWindow(startedAt: Date(), budgetSeconds: 60, chosenActivity: .bath)
        XCTAssertEqual(w.extended(bySeconds: 600).chosenActivity, .bath)
    }

    func testEveryActivityHasChildFacingCopy() {
        for a in TransitionActivity.allCases {
            XCTAssertFalse(a.invitation.isEmpty)
            XCTAssertFalse(a.symbolName.isEmpty)
            XCTAssertFalse(a.displayName.isEmpty)
        }
    }
}
