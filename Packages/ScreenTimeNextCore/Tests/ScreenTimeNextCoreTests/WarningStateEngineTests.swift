//  WarningStateEngineTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 008 / D-013 — configurable warning offsets. Default offsets 600/300/60.

import XCTest
@testable import ScreenTimeNextCore

final class WarningStateEngineTests: XCTestCase {

    private let d = ScreenTimeConfiguration.defaultWarningOffsets   // [600, 300, 60]

    func testStageAboveFirstWarningIsActive() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 601, warningOffsets: d), .active)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 3600, warningOffsets: d), .active)
    }

    func testExactBoundariesAreInclusive() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 600, warningOffsets: d), .firstWarning)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 300, warningOffsets: d), .secondWarning)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 60, warningOffsets: d), .finalWarning)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 0, warningOffsets: d), .finished)
    }

    func testOneSecondAboveEachBoundaryStaysInPreviousStage() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 301, warningOffsets: d), .firstWarning)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 61, warningOffsets: d), .secondWarning)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 1, warningOffsets: d), .finalWarning)
    }

    func testNegativeRemainingIsFinished() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: -1, warningOffsets: d), .finished)
    }

    // MARK: Roles with fewer warnings (D-013)

    func testTwoWarningsSkipTheMiddleRole() {
        let two = [600, 60]
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 400, warningOffsets: two), .firstWarning)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 30, warningOffsets: two), .finalWarning)
    }

    func testOneWarningIsTheFirstWarning() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 200, warningOffsets: [300]), .firstWarning)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 2, warningOffsets: [300]), .firstWarning)
    }

    func testNoWarningsGoesStraightToFinished() {
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 1, warningOffsets: []), .active)
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 0, warningOffsets: []), .finished)
    }

    func testUnsortedOrDuplicateOffsetsAreNormalized() {
        let messy = [60, 600, 600, 300, 0, -5, 5000]   // 5000 clamps to 900
        XCTAssertEqual(ScreenTimeConfiguration.normalizedOffsets(messy), [900, 600, 300])
        XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 700, warningOffsets: messy), .firstWarning)
    }

    func testActiveWarningOffsetForCopy() {
        XCTAssertEqual(WarningStateEngine.activeWarningOffset(remainingSeconds: 250, warningOffsets: d), 300)
        XCTAssertNil(WarningStateEngine.activeWarningOffset(remainingSeconds: 700, warningOffsets: d))
    }

    // MARK: Monotonic progression

    func testSessionNeverStepsBackwardOnJitter() {
        XCTAssertEqual(WarningStateEngine.next(current: .secondWarning, remainingSeconds: 305, warningOffsets: d), .secondWarning)
    }

    func testIdleStaysIdleUntilExplicitlyStarted() {
        XCTAssertEqual(WarningStateEngine.next(current: .idle, remainingSeconds: 3600, warningOffsets: d), .idle)
        XCTAssertEqual(WarningStateEngine.start(remainingSeconds: 3600, warningOffsets: d), .active)
    }

    func testStartingLateEntersTheCorrectStage() {
        XCTAssertEqual(WarningStateEngine.start(remainingSeconds: 100, warningOffsets: d), .secondWarning)
        XCTAssertEqual(WarningStateEngine.start(remainingSeconds: 30, warningOffsets: d), .finalWarning)
    }

    func testExtendedResumesIntoNaturalStage() {
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 1200, warningOffsets: d), .active)
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 400, warningOffsets: d), .firstWarning)
    }

    func testFinishedStaysFinishedWithoutAnExtension() {
        XCTAssertEqual(WarningStateEngine.next(current: .finished, remainingSeconds: 0, warningOffsets: d), .finished)
    }

    func testDayRolloverReturnsToIdle() {
        XCTAssertEqual(WarningStateEngine.dayRollover(), .idle)
    }
}

final class SessionWindowTests: XCTestCase {

    func testRemainingIsDerivedFromTimestamps() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let window = SessionWindow(startedAt: start, budgetSeconds: 3600)
        XCTAssertEqual(window.remainingSeconds(at: start), 3600)
        XCTAssertEqual(window.remainingSeconds(at: start.addingTimeInterval(600)), 3000)
        XCTAssertEqual(window.remainingSeconds(at: start.addingTimeInterval(3600)), 0)
    }

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
