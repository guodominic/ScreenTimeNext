//  ConfigurationTests.swift
//  ScreenTimeNextCoreTests
//
//  D-013 — configurable warnings and the dial ranges; legacy-JSON compatibility.

import XCTest
@testable import ScreenTimeNextCore

final class ConfigurationTests: XCTestCase {

    func testDefaults() {
        let c = ScreenTimeConfiguration.default
        XCTAssertEqual(c.dailyBudgetSeconds, 3600)
        XCTAssertEqual(c.warningOffsetsSeconds, [600, 300, 60])
        XCTAssertTrue(c.selectedActivities.isEmpty)
    }

    func testInitNormalizes() {
        let c = ScreenTimeConfiguration(dailyBudgetSeconds: 99_999, warningOffsetsSeconds: [0, 120, 120, 4000, 60])
        XCTAssertEqual(c.dailyBudgetSeconds, 7200)
        XCTAssertEqual(c.warningOffsetsSeconds, [900, 120, 60])
    }

    func testAtMostThreeWarningsEarliestFirst() {
        let c = ScreenTimeConfiguration(warningOffsetsSeconds: [60, 120, 180, 240, 300])
        XCTAssertEqual(c.warningOffsetsSeconds, [300, 240, 180])
    }

    func testRoundTrip() throws {
        var c = ScreenTimeConfiguration.default
        c.warningOffsetsSeconds = [420, 60]
        c.selectedActivities = [.lego]
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(ScreenTimeConfiguration.self, from: data), c)
    }

    /// A store written before D-013 (toggle shape) still decodes.
    func testLegacyTogglesDecodeToOffsets() throws {
        let legacy = """
        {"dailyBudgetSeconds":1800,"warning10Enabled":true,"warning5Enabled":false,"warning1Enabled":true,"selectedActivities":["reading"]}
        """
        let c = try JSONDecoder().decode(ScreenTimeConfiguration.self, from: Data(legacy.utf8))
        XCTAssertEqual(c.dailyBudgetSeconds, 1800)
        XCTAssertEqual(c.warningOffsetsSeconds, [600, 60])
        XCTAssertEqual(c.selectedActivities, [.reading])
    }

    func testEffectiveOffsetsAreStrictlyShorterThanTheWindow() {
        let c = ScreenTimeConfiguration(warningOffsetsSeconds: [600, 300, 60])
        XCTAssertEqual(c.effectiveWarningOffsets(forWindowSeconds: 480), [300, 60])
        XCTAssertEqual(c.effectiveWarningOffsets(forWindowSeconds: 300), [60], "equal is not shorter")
        XCTAssertEqual(c.effectiveWarningOffsets(forWindowSeconds: 3600), [600, 300, 60])
        XCTAssertEqual(c.effectiveWarningOffsets(forWindowSeconds: 30), [])
    }

    func testMaxWarningOffsetForBudget() {
        XCTAssertEqual(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: 480), 420, "8-minute budget → reminders up to 7")
        XCTAssertEqual(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: 7200), 900, "capped at 15")
        XCTAssertEqual(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: 120), 60)
    }

    func testDialRangesAreConsistent() {
        XCTAssertEqual(ScreenTimeConfiguration.budgetRangeSeconds.lowerBound % ScreenTimeConfiguration.budgetStepSeconds, 0)
        XCTAssertEqual(ScreenTimeConfiguration.budgetRangeSeconds.upperBound, 120 * 60)
        XCTAssertEqual(ScreenTimeConfiguration.warningOffsetRange.upperBound, 15 * 60)
    }
}
