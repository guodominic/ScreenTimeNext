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

    // MARK: The dial the parent moved keeps its value

    func testRaisingTheFirstDialPushesNothing() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([12, 5, 1], capMinutes: cap, changedIndex: 0)
        XCTAssertEqual(out, [12, 5, 1])
    }

    func testLoweringTheFirstDialDragsTheOthersDown() {
        // 10/5/1 → the parent drags reminder 1 down to 4. 5 and 1 cannot stay as they are.
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([4, 5, 1], capMinutes: cap, changedIndex: 0)
        XCTAssertEqual(out, [4, 3, 1])
    }

    func testAMiddleDialCannotPassTheOneBeforeIt() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([10, 12, 1], capMinutes: cap, changedIndex: 1)
        XCTAssertEqual(out.count, 3)
        XCTAssertGreaterThan(out[0], out[1])
        XCTAssertEqual(out[1], 12, "the dial the parent moved keeps its value")
        XCTAssertEqual(out[0], 13, "the one before it gives way upward")
    }

    func testTheDialGivesWayWhenThereIsNoRoomAbove() {
        // Reminder 2 dragged to the cap: reminder 1 cannot go higher, so reminder 2 yields.
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([15, 15, 1], capMinutes: cap, changedIndex: 1)
        XCTAssertEqual(out[0], 15)
        XCTAssertEqual(out[1], 14)
    }

    // MARK: Off means off from there on

    func testTurningOffAReminderTurnsOffTheLaterOnes() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([10, 0, 3], capMinutes: cap, changedIndex: 1)
        XCTAssertEqual(out, [10, 0, 0])
    }

    func testTurningOffTheFirstTurnsOffEverything() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([0, 5, 1], capMinutes: cap, changedIndex: 0)
        XCTAssertEqual(out, [0, 0, 0])
    }

    func testAOneMinuteReminderLeavesNoRoomForALaterOne() {
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([1, 5, 2], capMinutes: cap, changedIndex: 0)
        XCTAssertEqual(out, [1, 0, 0])
    }

    // MARK: The result is always legal, whatever goes in

    func testOutputIsAlwaysStrictlyDescendingWithTrailingZeros() {
        let inputs: [[Int]] = [[5, 10, 2], [1, 1, 1], [0, 0, 9], [15, 15, 15], [3, 3, 3], [7, 2, 9],
                               [-4, 99, 0], [2, 2, 2], [15, 1, 1], [9, 9, 1]]
        for input in inputs {
            for changed in 0..<3 {
                let out = ScreenTimeConfiguration.clampedDescendingMinutes(input, capMinutes: cap, changedIndex: changed)
                XCTAssertEqual(out.count, 3, "\(input)@\(changed)")
                let on = out.prefix { $0 > 0 }
                XCTAssertEqual(Array(out.drop { $0 > 0 }), Array(repeating: 0, count: 3 - on.count),
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
    func testAStaleNeighbourCannotSurviveTheBackwardPass() {
        for changed in 0..<3 {
            let out = ScreenTimeConfiguration.clampedDescendingMinutes([15, 15, 15],
                                                                       capMinutes: cap,
                                                                       changedIndex: changed)
            XCTAssertEqual(Set(out).count, 3, "all three must differ: \(out)")
            XCTAssertGreaterThan(out[0], out[1], "\(out)")
            XCTAssertGreaterThan(out[1], out[2], "\(out)")
        }
    }

    func testShrinkingTheBudgetReClampsTheWholeSet() {
        // Budget drops so the cap is 3 minutes: 10/5/1 cannot survive as-is.
        let out = ScreenTimeConfiguration.clampedDescendingMinutes([10, 5, 1], capMinutes: 3)
        XCTAssertEqual(out, [3, 2, 1])
    }

    func testACapOfZeroTurnsEverythingOff() {
        XCTAssertEqual(ScreenTimeConfiguration.clampedDescendingMinutes([10, 5, 1], capMinutes: 0), [0, 0, 0])
    }

    // MARK: The per-dial bounds the UI uses

    func testDialBoundsStopOneShortOfTheDialBefore() {
        let minutes = [10, 5, 1]
        XCTAssertEqual(ScreenTimeConfiguration.warningDialUpperBound(index: 0, minutes: minutes, capMinutes: cap), cap)
        XCTAssertEqual(ScreenTimeConfiguration.warningDialUpperBound(index: 1, minutes: minutes, capMinutes: cap), 9)
        XCTAssertEqual(ScreenTimeConfiguration.warningDialUpperBound(index: 2, minutes: minutes, capMinutes: cap), 4)
    }

    func testADialIsUnusableWhenTheOneBeforeItLeavesNoRoom() {
        XCTAssertEqual(ScreenTimeConfiguration.warningDialUpperBound(index: 1, minutes: [1, 0, 0], capMinutes: cap), 0)
        XCTAssertEqual(ScreenTimeConfiguration.warningDialUpperBound(index: 1, minutes: [0, 0, 0], capMinutes: cap), 0)
    }

    /// The stored configuration must agree with what the dials produce.
    func testDialOutputSurvivesConfigurationNormalization() {
        let dialled = ScreenTimeConfiguration.clampedDescendingMinutes([4, 5, 1], capMinutes: cap, changedIndex: 0)
        let config = ScreenTimeConfiguration(dailyBudgetSeconds: 20 * 60,
                                             warningOffsetsSeconds: dialled.map { $0 * 60 })
        XCTAssertEqual(config.warningOffsetsSeconds, [240, 180, 60])
    }
}
