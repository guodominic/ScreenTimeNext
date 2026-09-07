//  ConfigurationTests.swift
//  ScreenTimeNextCoreTests
//
//  D-013 — configurable warnings and the dial ranges; legacy-JSON compatibility.
//  D-034 — the budget range is now 1–90 minutes in 1-minute steps, default 15.

import XCTest
@testable import ScreenTimeNextCore

final class ConfigurationTests: XCTestCase {

    func testDefaults() {
        let c = ScreenTimeConfiguration.default
        // D-034 — fifteen minutes: the length of the request a parent is usually answering when
        // they open this app, not a number they then have to dial down from.
        XCTAssertEqual(c.dailyBudgetSeconds, 900)
        XCTAssertEqual(c.warningOffsetsSeconds, [300, 60], "D-044 — two reminders, not three")
        XCTAssertTrue(c.selectedActivities.isEmpty)
    }

    func testInitNormalizes() {
        let c = ScreenTimeConfiguration(dailyBudgetSeconds: 99_999, warningOffsetsSeconds: [0, 120, 120, 4000, 60])
        XCTAssertEqual(c.dailyBudgetSeconds, 5400, "D-034 — 90 minutes is the ceiling")
        XCTAssertEqual(c.warningOffsetsSeconds, [900, 120], "D-044 — the list is two long")
    }

    func testAtMostTwoWarningsEarliestFirst() {
        let c = ScreenTimeConfiguration(warningOffsetsSeconds: [60, 120, 180, 240, 300])
        XCTAssertEqual(c.warningOffsetsSeconds, [300, 240])
    }

    func testRoundTrip() throws {
        var c = ScreenTimeConfiguration.default
        c.warningOffsetsSeconds = [420, 60]
        c.selectedActivities = [.cleanUp]
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(ScreenTimeConfiguration.self, from: data), c)
    }

    /// A store written before D-013 (toggle shape) still decodes.
    func testLegacyTogglesDecodeToOffsets() throws {
        let legacy = """
        {"dailyBudgetSeconds":1800,"warning10Enabled":true,"warning5Enabled":false,"warning1Enabled":true,"selectedActivities":["mealTime"]}
        """
        let c = try JSONDecoder().decode(ScreenTimeConfiguration.self, from: Data(legacy.utf8))
        XCTAssertEqual(c.dailyBudgetSeconds, 1800)
        XCTAssertEqual(c.warningOffsetsSeconds, [600, 60])
        XCTAssertEqual(c.selectedActivities, [.mealTime])
    }

    func testEffectiveOffsetsAreStrictlyShorterThanTheWindow() {
        // D-044 — a third offset is dropped on the way in, so the stored list is [600, 300].
        let c = ScreenTimeConfiguration(warningOffsetsSeconds: [600, 300, 60])
        XCTAssertEqual(c.warningOffsetsSeconds, [600, 300])
        XCTAssertEqual(c.effectiveWarningOffsets(forWindowSeconds: 480), [300])
        XCTAssertEqual(c.effectiveWarningOffsets(forWindowSeconds: 300), [], "equal is not shorter")
        XCTAssertEqual(c.effectiveWarningOffsets(forWindowSeconds: 3600), [600, 300])
        XCTAssertEqual(c.effectiveWarningOffsets(forWindowSeconds: 30), [])
    }

    func testMaxWarningOffsetForBudget() {
        XCTAssertEqual(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: 480), 420, "8-minute budget → reminders up to 7")
        XCTAssertEqual(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: 7200), 900, "capped at 15")
        XCTAssertEqual(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: 120), 60)
    }

    /// The invariant holds however the value is set — this is what the notification test caught.
    func testDirectAssignmentIsNormalizedToo() {
        var c = ScreenTimeConfiguration.default
        c.warningOffsetsSeconds = [60, 60, 900, 5000, 0, -3, 120]
        XCTAssertEqual(c.warningOffsetsSeconds, [900, 120])
        c.dailyBudgetSeconds = 99_999
        XCTAssertEqual(c.dailyBudgetSeconds, 5400)
        c.dailyBudgetSeconds = 1
        XCTAssertEqual(c.dailyBudgetSeconds, 60)
    }

    func testDefaultOffsetsForBudget() {
        XCTAssertEqual(ScreenTimeConfiguration.defaultWarningOffsets(forBudgetSeconds: 60 * 60), [300, 60])
        XCTAssertEqual(ScreenTimeConfiguration.defaultWarningOffsets(forBudgetSeconds: 12 * 60), [300, 60])
        XCTAssertEqual(ScreenTimeConfiguration.defaultWarningOffsets(forBudgetSeconds: 11 * 60), [300, 60])
        XCTAssertEqual(ScreenTimeConfiguration.defaultWarningOffsets(forBudgetSeconds: 4 * 60), [120, 60])
        XCTAssertEqual(ScreenTimeConfiguration.defaultWarningOffsets(forBudgetSeconds: 2 * 60), [60])
        // Every default fits its budget.
        for m in stride(from: 2, through: 120, by: 2) {
            let c = ScreenTimeConfiguration(dailyBudgetSeconds: m * 60, warningOffsetsSeconds: ScreenTimeConfiguration.defaultWarningOffsets(forBudgetSeconds: m * 60))
            XCTAssertEqual(c.effectiveWarningOffsets(forWindowSeconds: m * 60), c.warningOffsetsSeconds, "budget \(m)")
        }
    }

    func testDialRangesAreConsistent() {
        XCTAssertEqual(ScreenTimeConfiguration.budgetRangeSeconds.lowerBound, 60)
        XCTAssertEqual(ScreenTimeConfiguration.budgetRangeSeconds.upperBound, 90 * 60)
        XCTAssertEqual(ScreenTimeConfiguration.warningOffsetRange.upperBound, 15 * 60)
    }

    /// Short budgets are the common case, so the dial gets finer under 15 minutes.
    func testBudgetStepIsFinerBelowFifteenMinutes() {
        // D-034 — one step for the whole range, so no screen can round a parent's number.
        XCTAssertEqual(ScreenTimeConfiguration.budgetStepSeconds, 60)
        XCTAssertEqual(ScreenTimeConfiguration.defaultBudgetSeconds, 15 * 60)
    }
}
