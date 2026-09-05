//  WarningStateTransitionTableTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 008 — every row of the PRD §11 transition table, every enabled/disabled warning
//  combination, and the engine's import discipline. Complements WarningStateEngineTests.

import XCTest
@testable import ScreenTimeNextCore

final class WarningStateTransitionTableTests: XCTestCase {

    // MARK: §11 rows, time-driven

    func testRow_idle_startsSession_active() {
        XCTAssertEqual(WarningStateEngine.next(current: .idle, remainingSeconds: 3600), .idle, "time alone never starts a session")
        XCTAssertEqual(WarningStateEngine.start(remainingSeconds: 3600), .active)
    }

    func testRow_active_to_warning10_at600() {
        XCTAssertEqual(WarningStateEngine.next(current: .active, remainingSeconds: 601), .active)
        XCTAssertEqual(WarningStateEngine.next(current: .active, remainingSeconds: 600), .warning10)
    }

    func testRow_warning10_to_warning5_at300() {
        XCTAssertEqual(WarningStateEngine.next(current: .warning10, remainingSeconds: 301), .warning10)
        XCTAssertEqual(WarningStateEngine.next(current: .warning10, remainingSeconds: 300), .warning5)
    }

    func testRow_warning5_to_warning1_at60() {
        XCTAssertEqual(WarningStateEngine.next(current: .warning5, remainingSeconds: 61), .warning5)
        XCTAssertEqual(WarningStateEngine.next(current: .warning5, remainingSeconds: 60), .warning1)
    }

    func testRow_warning1_to_finished_at0() {
        XCTAssertEqual(WarningStateEngine.next(current: .warning1, remainingSeconds: 1), .warning1)
        XCTAssertEqual(WarningStateEngine.next(current: .warning1, remainingSeconds: 0), .finished)
        XCTAssertEqual(WarningStateEngine.next(current: .warning1, remainingSeconds: -5), .finished)
    }

    /// A big jump (device asleep for 20 minutes) skips intermediate warnings correctly.
    func testLargeJumpSkipsIntermediateStates() {
        XCTAssertEqual(WarningStateEngine.next(current: .active, remainingSeconds: 45), .warning1)
        XCTAssertEqual(WarningStateEngine.next(current: .active, remainingSeconds: 0), .finished)
    }

    // MARK: §11 override path

    func testRow_finished_grantExtension_extended_then_active() {
        XCTAssertEqual(WarningStateEngine.grantExtension(), .extended)
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 600 + 1), .active)
    }

    func testRow_extended_resumesIntoWarningIfAllowanceIsSmall() {
        // +1 minute granted at zero: resumes straight into warning1.
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 60), .warning1)
    }

    func testRow_extended_expires_finished() {
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 0), .finished)
    }

    func testRow_any_dayRollover_idle() {
        XCTAssertEqual(WarningStateEngine.dayRollover(), .idle)
    }

    // MARK: Monotonicity from every state

    func testNoTimeDrivenTransitionMovesBackward() {
        let ordered: [ScreenTimeState] = [.active, .warning10, .warning5, .warning1, .finished]
        for (i, state) in ordered.enumerated() {
            // Give it a "remaining" that would naturally map to every EARLIER stage.
            for earlier in ordered[..<i] {
                let remaining: Int
                switch earlier {
                case .active: remaining = 5000
                case .warning10: remaining = 450
                case .warning5: remaining = 200
                case .warning1: remaining = 30
                default: remaining = 0
                }
                XCTAssertEqual(WarningStateEngine.next(current: state, remainingSeconds: remaining), state,
                               "\(state) must not step back toward \(earlier)")
            }
        }
    }

    // MARK: Presentation toggles — all 8 combinations, state machine untouched

    func testEveryToggleCombinationLeavesTransitionsUnchanged() {
        for mask in 0..<8 {
            var config = ScreenTimeConfiguration.default
            config.warning10Enabled = mask & 1 != 0
            config.warning5Enabled  = mask & 2 != 0
            config.warning1Enabled  = mask & 4 != 0

            XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 600), .warning10)
            XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 300), .warning5)
            XCTAssertEqual(WarningStateEngine.stage(remainingSeconds: 60), .warning1)

            XCTAssertEqual(WarningStateEngine.shouldPresent(.warning10, configuration: config), config.warning10Enabled)
            XCTAssertEqual(WarningStateEngine.shouldPresent(.warning5, configuration: config), config.warning5Enabled)
            XCTAssertEqual(WarningStateEngine.shouldPresent(.warning1, configuration: config), config.warning1Enabled)
            XCTAssertTrue(WarningStateEngine.shouldPresent(.active, configuration: config))
            XCTAssertTrue(WarningStateEngine.shouldPresent(.finished, configuration: config))
        }
    }

    // MARK: Import discipline (DoD: the engine imports nothing but Foundation)

    func testEngineSourceImportsOnlyFoundation() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/ScreenTimeNextCore/State/WarningStateEngine.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let imports = source.split(separator: "\n").filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation"])
    }
}
