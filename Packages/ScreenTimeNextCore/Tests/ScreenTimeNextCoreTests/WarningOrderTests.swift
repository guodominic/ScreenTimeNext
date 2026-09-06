//  WarningOrderTests.swift
//  ScreenTimeNextCoreTests
//
//  D-019 — reminder 1 fires before reminder 2 fires before reminder 3, so their minutes-before-
//  the-end must strictly descend. Before this, three independent dials let a parent set 5 / 10 / 2
//  and the configuration silently re-sorted it behind their back.

import XCTest
@testable import ScreenTimeNextCore

final class WarningOrderTests: XCTestCase {

    private let cap = 15
    /// D-044 — two dials. Written as the constant so this file survives the next change to it,
    /// rather than as the literal 3 that took the whole test process down when it became 2.
    private let slots = ScreenTimeConfiguration.maxWarnings

    // MARK: The dial the parent moved keeps its value

    func testRaisingTheFirstDialPushesNothing() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([12, 5], capMinutes: cap, changedIndex: 0)
        XCTAssertEqual(out, [12, 5])
    }

    func testLoweringTheFirstDialDragsTheOthersDown() {
        // 10/5 → the parent drags reminder 1 down to 4. 5 cannot stay as it is.
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([4, 5], capMinutes: cap, changedIndex: 0)
        XCTAssertEqual(out, [4, 3])
    }

    func testAMiddleDialCannotPassTheOneBeforeIt() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([10, 12], capMinutes: cap, changedIndex: 1)
        XCTAssertEqual(out.count, slots)
        XCTAssertGreaterThan(out[0], out[1])
        XCTAssertEqual(out[1], 12, "the dial the parent moved keeps its value")
        XCTAssertEqual(out[0], 13, "the one before it gives way upward")
    }

    func testTheDialGivesWayWhenThereIsNoRoomAbove() {
        // Reminder 2 dragged to the cap: reminder 1 cannot go higher, so reminder 2 yields.
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([15, 15], capMinutes: cap, changedIndex: 1)
        XCTAssertEqual(out[0], 15)
        XCTAssertEqual(out[1], 14)
    }

    // MARK: Off means off from there on

    func testTurningOffAReminderTurnsOffTheLaterOnes() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([10, 0], capMinutes: cap, changedIndex: 1)
        XCTAssertEqual(out, [10, 0])
    }

    func testTurningOffTheFirstTurnsOffEverything() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([0, 5], capMinutes: cap, changedIndex: 0)
        XCTAssertEqual(out, [0, 0])
    }

    func testAOneMinuteReminderLeavesNoRoomForALaterOne() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([1, 5], capMinutes: cap, changedIndex: 0)
        XCTAssertEqual(out, [1, 0])
    }

    // MARK: The result is always legal, whatever goes in

    func testOutputIsAlwaysStrictlyDescendingWithTrailingZeros() {
        let inputs: [[Int]] = [[5, 10, 2], [1, 1, 1], [0, 0, 9], [15, 15, 15], [3, 3, 3], [7, 2, 9],
                               [-4, 99, 0], [2, 2, 2], [15, 1, 1], [9, 9, 1]]
        for input in inputs {
            for changed in 0..<slots {
                let out = ScreenTimeConfiguration.clampedDescendingMinutes(input, capMinutes: cap, changedIndex: changed)
                XCTAssertEqual(out.count, slots, "\(input)@\(changed)")
                let on = out.prefix { $0 > 0 }
                XCTAssertEqual(Array(out.drop { $0 > 0 }), Array(repeating: 0, count: slots - on.count),
                               "zeros must trail: \(input)@\(changed) → \(out)")
                // `stride`, not `1..<on.count`: with every reminder off, `on` is empty and the
                // range would be 1..<0 — which traps rather than failing, taking the whole test
                // process with it.
                for i in stride(from: 1, to: on.count, by: 1) {
                    XCTAssertGreaterThan(on[i - 1], on[i], "not descending: \(input)@\(changed) → \(out)")
                }
                for value in out {
                    XCTAssertTrue(value == 0 || (1...cap).contains(value), "out of range: \(out)")
                }
            }
        }
    }

    /// Regression: the backward pass used to lower a dial the forward pass had already sized
    /// against its old value, so 15/15/15 with dial 2 moved came out 15/14/14 — not descending.
    ///
    /// D-044 — written against three dials; the list is two long now, so it walks whatever
    /// `maxWarnings` is rather than hard-coding a count. Hard-coded `out[2]` is exactly what
    /// crashed the whole test run when the third dial went away.
    func testAStaleNeighbourCannotSurviveTheBackwardPass() {
        let identical = Array(repeating: 15, count: ScreenTimeConfiguration.maxWarnings)
        for changed in 0..<ScreenTimeConfiguration.maxWarnings {
            let out = ScreenTimeConfiguration.clampedDescendingMinutes(identical,
                                                                       capMinutes: cap,
                                                                       changedIndex: changed)
            XCTAssertEqual(out.count, ScreenTimeConfiguration.maxWarnings)
            XCTAssertEqual(Set(out).count, out.count, "every dial must differ: \(out)")
            for i in 1..<out.count {
                XCTAssertGreaterThan(out[i - 1], out[i], "\(out)")
            }
        }
    }

    func testShrinkingTheBudgetReClampsTheWholeSet() {
        // Budget drops so the cap is 3 minutes: 10/5 cannot survive as-is.
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([10, 5], capMinutes: 3)
        XCTAssertEqual(out, [3, 2])
    }

    func testACapOfZeroTurnsEverythingOff() {
        XCTAssertEqual(ScreenTimeConfiguration.clampedDescendingMinutes([10, 5], capMinutes: 0), [0, 0])
    }

    /// D-044 — the list is two long now. A saved set of three (or a caller that still passes three)
    /// must be truncated rather than quietly producing a third dial nothing renders.
    func testMoreThanTwoAreTruncated() {
        XCTAssertEqual(ScreenTimeConfiguration.clampedDescendingMinutes([10, 5, 1], capMinutes: 30).count,
                       ScreenTimeConfiguration.maxWarnings)
    }

    // MARK: The per-dial bounds the UI uses

    func testDialBoundsStopOneShortOfTheDialBefore() {
        let minutes = [10, 5]
        XCTAssertEqual(ScreenTimeConfiguration.warningDialUpperBound(index: 0, minutes: minutes, capMinutes: cap), cap)
        XCTAssertEqual(ScreenTimeConfiguration.warningDialUpperBound(index: 1, minutes: minutes, capMinutes: cap), 9)
    }

    func testADialIsUnusableWhenTheOneBeforeItLeavesNoRoom() {
        XCTAssertEqual(ScreenTimeConfiguration.warningDialUpperBound(index: 1, minutes: [1, 0, 0], capMinutes: cap), 0)
        XCTAssertEqual(ScreenTimeConfiguration.warningDialUpperBound(index: 1, minutes: [0, 0, 0], capMinutes: cap), 0)
    }

    /// The stored configuration must agree with what the dials produce.
    func testDialOutputSurvivesConfigurationNormalization() {
        let dialled = ScreenTimeConfiguration.clampedDescendingMinutes([4, 5], capMinutes: cap, changedIndex: 0)
        let config = ScreenTimeConfiguration(dailyBudgetSeconds: 20 * 60,
                                             warningOffsetsSeconds: dialled.map { $0 * 60 })
        XCTAssertEqual(config.warningOffsetsSeconds, [240, 180])
    }
}
