//  LiveSettingsChangeTests.swift
//  ScreenTimeNextCoreTests
//
//  D-019 — settings changed while a session is running must reach the running session.
//
//  Reminders and activities always did: they are re-read from storage on every tick. The DAILY
//  BUDGET did not. A window is a wall-clock window (D-006) whose end was fixed at Start, so a
//  parent who raised the budget from 15 to 30 minutes mid-session changed a number on the
//  dashboard and nothing the child could see. These tests pin the fix.

import XCTest
@testable import ScreenTimeNextCore

final class LiveSettingsChangeTests: XCTestCase {

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
        try setBudget(minutes: 15)
    }

    private func setBudget(minutes: Int) throws {
        var config = (try? storage.loadConfiguration()) ?? .default
        config.dailyBudgetSeconds = minutes * 60
        try storage.save(config)
    }

    // MARK: Budget

    func testRaisingTheBudgetMidSessionExtendsTheRunningWindow() throws {
        _ = try controller.start()
        clock.advance(5 * 60)                       // five minutes used
        try setBudget(minutes: 30)

        let snap = try XCTUnwrap(try controller.applyConfigurationChange())
        XCTAssertEqual(snap.remainingSeconds, 25 * 60, "30 minutes of budget, five already spent")
        XCTAssertNotNil(snap.window)
    }

    func testLoweringTheBudgetMidSessionShortensTheRunningWindow() throws {
        _ = try controller.start()
        clock.advance(5 * 60)
        try setBudget(minutes: 6)

        let snap = try XCTUnwrap(try controller.applyConfigurationChange())
        XCTAssertEqual(snap.remainingSeconds, 60)
    }

    func testLoweringTheBudgetBelowWhatIsSpentEndsTheSessionNow() throws {
        _ = try controller.start()
        clock.advance(10 * 60)
        try setBudget(minutes: 4)                   // already over

        let snap = try XCTUnwrap(try controller.applyConfigurationChange())
        XCTAssertEqual(snap.remainingSeconds, 0)
        XCTAssertEqual(snap.state, .finished, "no negative time, and no pretending there is time left")
    }

    func testTimeAlreadySpentStaysSpent() throws {
        _ = try controller.start()
        clock.advance(6 * 60)
        try setBudget(minutes: 15)                  // unchanged — a save with no budget edit

        let snap = try XCTUnwrap(try controller.applyConfigurationChange())
        XCTAssertEqual(snap.remainingSeconds, 9 * 60, "a no-op save must not hand back the used time")
        XCTAssertEqual(try storage.loadSessionWindow()?.startedAt, noon, "the start of the session is history")
    }

    /// §15 — an extension is a deliberate grant beyond the budget. Re-deriving the window from the
    /// budget must not quietly take it back.
    func testAParentExtensionSurvivesASettingsSave() throws {
        _ = try controller.start()                  // 15 minutes
        clock.advance(5 * 60)                       // 10 left
        _ = try controller.extend(bySeconds: 8 * 60)  // 18 left, 8 of them granted

        try setBudget(minutes: 20)
        let snap = try XCTUnwrap(try controller.applyConfigurationChange())
        // 20 budget − 5 spent = 15 of budget, plus the 8 the parent granted.
        XCTAssertEqual(snap.remainingSeconds, 23 * 60)
    }

    func testEarlierUsageTodayStillCounts() throws {
        _ = try controller.start()
        clock.advance(4 * 60)
        _ = try controller.endEarly()               // 4 minutes recorded
        _ = try controller.start()                  // 11 minutes left
        clock.advance(2 * 60)

        try setBudget(minutes: 30)
        let snap = try XCTUnwrap(try controller.applyConfigurationChange())
        XCTAssertEqual(snap.remainingSeconds, 24 * 60, "30 − 4 recorded − 2 in flight")
    }

    // MARK: State

    /// `WarningStateEngine.next` is monotonic, so without resetting the stage a session that had
    /// reached "one minute left" would stay red after the parent granted twenty more minutes.
    func testTheStageIsReDerivedAfterTheBudgetGrows() throws {
        _ = try controller.start()
        clock.advance(14 * 60 + 30)                 // 30 seconds left — final warning
        XCTAssertEqual(try controller.tick().state, .finalWarning)

        try setBudget(minutes: 45)
        let snap = try XCTUnwrap(try controller.applyConfigurationChange())
        XCTAssertEqual(snap.state, .active, "plenty of time again — the screen must go back to green")
    }

    // MARK: Reminders and activities

    func testChangedRemindersTakeEffectWithoutRestarting() throws {
        var config = try storage.loadConfiguration()
        config.warningOffsetsSeconds = [60]
        try storage.save(config)
        _ = try controller.start()
        clock.advance(10 * 60)                      // 5 minutes left
        XCTAssertEqual(try controller.tick().state, .active, "only a 1-minute reminder is set")

        config.warningOffsetsSeconds = [600, 300, 60]
        try storage.save(config)
        _ = try controller.applyConfigurationChange()
        XCTAssertTrue(try controller.tick().state.isWarning, "the new 5-minute reminder is already due")
    }

    func testChangedActivitiesAreVisibleImmediately() throws {
        _ = try controller.start()
        XCTAssertEqual(try controller.availableActivities(), TransitionActivity.allCases)

        var config = try storage.loadConfiguration()
        config.selectedActivities = [.cleanUp, .outside]
        try storage.save(config)
        XCTAssertEqual(try controller.availableActivities(), [.cleanUp, .outside])
    }

    // MARK: Nothing running

    func testNoSessionMeansNothingToApply() throws {
        XCTAssertNil(try controller.applyConfigurationChange())
    }

    // MARK: The window still decodes without the new field

    func testWindowsWrittenBeforeTheGrantFieldDecodeAsUnextended() throws {
        let json = #"{"startedAt":0,"endsAt":900}"#.data(using: .utf8)!
        let window = try JSONDecoder().decode(SessionWindow.self, from: json)
        XCTAssertEqual(window.totalSeconds, 900)
        XCTAssertEqual(window.budgetSecondsAtStart, 900)
        XCTAssertEqual(window.grantedSeconds, 0)
    }
}
