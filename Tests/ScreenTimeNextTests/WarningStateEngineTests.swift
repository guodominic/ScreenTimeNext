//  WarningStateEngineTests.swift
//  ScreenTimeNextTests
//
//  Starting tests for the pure state logic. Task 008 must extend these to cover
//  every transition in the PRD §11 table and every enabled/disabled warning combination.

import XCTest
@testable import ScreenTimeNext

final class WarningStateEngineTests: XCTestCase {

    // MARK: - Natural stage from remaining time

    func testStageAboveTenMinutesIsActive() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 601), .active)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 3600), .active)
    }

    /// Boundaries are inclusive. This is the decision Task 008 must not silently change.
    func testExactBoundariesAreInclusive() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 600), .warning10)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 300), .warning5)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 60), .warning1)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 0), .finished)
    }

    func testOneSecondAboveEachBoundaryStaysInPreviousStage() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 601), .active)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 301), .warning10)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 61), .warning5)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 1), .warning1)
    }

    func testNegativeRemainingIsFinished() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: -1), .finished)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: -99_999), .finished)
    }

    // MARK: - Monotonic progression

    func testSessionNeverStepsBackwardOnJitter() {
        // A one-second clock jitter must not move warning5 back to warning10.
        let result = WarningStateEngine.next(current: .warning5, remainingSeconds: 305)
        XCTAssertEqual(result, .warning5)
    }

    func testIdleStaysIdleUntilExplicitlyStarted() {
        XCTAssertEqual(WarningStateEngine.next(current: .idle, remainingSeconds: 3600), .idle)
        XCTAssertEqual(WarningStateEngine.start(remainingSeconds: 3600), .active)
    }

    /// Starting a session that is already inside a warning window enters that window directly.
    func testStartingLateEntersTheCorrectStage() {
        XCTAssertEqual(WarningStateEngine.start(remainingSeconds: 100), .warning5)
        XCTAssertEqual(WarningStateEngine.start(remainingSeconds: 30), .warning1)
    }

    func testExtendedResumesIntoNaturalStage() {
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 1200), .active)
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 400), .warning10)
    }

    func testFinishedStaysFinishedWithoutAnExtension() {
        XCTAssertEqual(WarningStateEngine.next(current: .finished, remainingSeconds: 0), .finished)
    }

    func testDayRolloverReturnsToIdle() {
        XCTAssertEqual(WarningStateEngine.dayRollover(), .idle)
    }

    // MARK: - Presentation toggles do not affect the state machine

    func testDisabledWarningIsEnteredButNotPresented() {
        var config = ScreenTimeConfiguration.default
        config.warning5Enabled = false

        let state = WarningStateEngine.stage(remainingSeconds: 300)
        XCTAssertEqual(state, .warning5, "The state machine must be config-independent")
        XCTAssertFalse(WarningStateEngine.shouldPresent(state, configuration: config))
    }

    func testEnabledWarningIsPresented() {
        let config = ScreenTimeConfiguration.default
        XCTAssertTrue(WarningStateEngine.shouldPresent(.warning10, configuration: config))
        XCTAssertTrue(WarningStateEngine.shouldPresent(.warning1, configuration: config))
    }
}

final class SessionWindowTests: XCTestCase {

    /// Rule 4 — remaining time is derived from absolute timestamps, never from a Timer.
    func testRemainingIsDerivedFromTimestamps() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let window = SessionWindow(startedAt: start, budgetSeconds: 3600)

        XCTAssertEqual(window.remainingSeconds(at: start), 3600)
        XCTAssertEqual(window.remainingSeconds(at: start.addingTimeInterval(600)), 3000)
        XCTAssertEqual(window.remainingSeconds(at: start.addingTimeInterval(3600)), 0)
    }

    /// Backgrounding for 20 minutes and returning must show correct time immediately (QA-06).
    func testLongGapComputesCorrectlyWithNoCatchUp() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let window = SessionWindow(startedAt: start, budgetSeconds: 3600)
        XCTAssertEqual(window.remainingSeconds(at: start.addingTimeInterval(1200)), 2400)
    }

    func testRemainingNeverGoesNegative() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let window = SessionWindow(startedAt: start, budgetSeconds: 60)
        XCTAssertEqual(window.remainingSeconds(at: start.addingTimeInterval(9_999)), 0)
        XCTAssertTrue(window.hasExpired(at: start.addingTimeInterval(9_999)))
    }

    func testExtensionMovesEndForward() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let window = SessionWindow(startedAt: start, budgetSeconds: 60).extended(bySeconds: 600)
        XCTAssertEqual(window.remainingSeconds(at: start), 660)
    }
}
