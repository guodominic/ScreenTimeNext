//  WarningStateTransitionTableTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 008 — every row of the PRD §11 transition table with the default offsets, monotonicity
//  from every state, and the engine's import discipline.

import XCTest
@testable import ScreenTimeNextCore

final class WarningStateTransitionTableTests: XCTestCase {

    private let d = ScreenTimeConfiguration.defaultWarningOffsets

    func testRows_timeDriven() {
        XCTAssertEqual(WarningStateEngine.next(current: .active, remainingSeconds: 601, warningOffsets: d), .active)
        XCTAssertEqual(WarningStateEngine.next(current: .active, remainingSeconds: 600, warningOffsets: d), .firstWarning)
        XCTAssertEqual(WarningStateEngine.next(current: .firstWarning, remainingSeconds: 301, warningOffsets: d), .firstWarning)
        XCTAssertEqual(WarningStateEngine.next(current: .firstWarning, remainingSeconds: 300, warningOffsets: d), .secondWarning)
        XCTAssertEqual(WarningStateEngine.next(current: .secondWarning, remainingSeconds: 61, warningOffsets: d), .secondWarning)
        XCTAssertEqual(WarningStateEngine.next(current: .secondWarning, remainingSeconds: 60, warningOffsets: d), .finalWarning)
        XCTAssertEqual(WarningStateEngine.next(current: .finalWarning, remainingSeconds: 1, warningOffsets: d), .finalWarning)
        XCTAssertEqual(WarningStateEngine.next(current: .finalWarning, remainingSeconds: 0, warningOffsets: d), .finished)
    }

    func testLargeJumpSkipsIntermediateStates() {
        XCTAssertEqual(WarningStateEngine.next(current: .active, remainingSeconds: 45, warningOffsets: d), .finalWarning)
        XCTAssertEqual(WarningStateEngine.next(current: .active, remainingSeconds: 0, warningOffsets: d), .finished)
    }

    func testOverridePath() {
        XCTAssertEqual(WarningStateEngine.grantExtension(), .extended)
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 601, warningOffsets: d), .active)
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 60, warningOffsets: d), .finalWarning)
        XCTAssertEqual(WarningStateEngine.next(current: .extended, remainingSeconds: 0, warningOffsets: d), .finished)
        XCTAssertEqual(WarningStateEngine.dayRollover(), .idle)
    }

    func testNoTimeDrivenTransitionMovesBackward() {
        let ordered: [ScreenTimeState] = [.active, .firstWarning, .secondWarning, .finalWarning, .finished]
        let remainingFor: [ScreenTimeState: Int] = [.active: 5000, .firstWarning: 450, .secondWarning: 200, .finalWarning: 30, .finished: 0]
        for (i, state) in ordered.enumerated() {
            for earlier in ordered[..<i] {
                XCTAssertEqual(WarningStateEngine.next(current: state, remainingSeconds: remainingFor[earlier]!, warningOffsets: d), state,
                               "\(state) must not step back toward \(earlier)")
            }
        }
    }

    /// Roles are positional: for every count 1…3 the first is `firstWarning`, the last is `finalWarning`.
    func testRoleMappingForEveryCount() {
        XCTAssertEqual(WarningStateEngine.role(ofWarningAt: 0, count: 1), .firstWarning)
        XCTAssertEqual(WarningStateEngine.role(ofWarningAt: 0, count: 2), .firstWarning)
        XCTAssertEqual(WarningStateEngine.role(ofWarningAt: 1, count: 2), .finalWarning)
        XCTAssertEqual(WarningStateEngine.role(ofWarningAt: 0, count: 3), .firstWarning)
        XCTAssertEqual(WarningStateEngine.role(ofWarningAt: 1, count: 3), .secondWarning)
        XCTAssertEqual(WarningStateEngine.role(ofWarningAt: 2, count: 3), .finalWarning)
    }

    func testEngineSourceImportsOnlyFoundation() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/ScreenTimeNextCore/State/WarningStateEngine.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let imports = source.split(separator: "\n").filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation"])
    }
}
