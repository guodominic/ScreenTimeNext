//  ShieldUrgencyTests.swift
//  ScreenTimeNextCoreTests
//
//  D-018 — the interstitial's colour must say how close the end is, and nothing else. Before this,
//  it was tinted by the activity the child had chosen, so every reminder came up an arbitrary
//  colour. These tests pin the ramp: green → orange → red, celebration only at the finish.

import XCTest
@testable import ScreenTimeNextCore

final class ShieldUrgencyTests: XCTestCase {

    // MARK: The ramp across a sequence of reminders

    func testThreeRemindersRampCalmSoonLast() {
        XCTAssertEqual(ShieldUrgency.forWarning(index: 0, count: 3), .calm)
        XCTAssertEqual(ShieldUrgency.forWarning(index: 1, count: 3), .soon)
        XCTAssertEqual(ShieldUrgency.forWarning(index: 2, count: 3), .last)
    }

    func testTwoRemindersSkipTheMiddle() {
        XCTAssertEqual(ShieldUrgency.forWarning(index: 0, count: 2), .calm)
        XCTAssertEqual(ShieldUrgency.forWarning(index: 1, count: 2), .last)
    }

    /// A lone reminder is the LAST one, not the first — a single "1 minute left" must be red.
    /// `WarningStateEngine.role(ofWarningAt:count:)` calls index 0 `.firstWarning` for its own
    /// state-machine reasons; the colour must not inherit that.
    func testSingleReminderIsTheLastOne() {
        XCTAssertEqual(ShieldUrgency.forWarning(index: 0, count: 1), .last)
    }

    func testEveryReminderInASequenceLooksDifferent() {
        for count in 2...3 {
            let ramp = (0..<count).map { ShieldUrgency.forWarning(index: $0, count: count) }
            XCTAssertEqual(Set(ramp).count, count, "reminders in a run of \(count) must not repeat a colour")
        }
    }

    // MARK: Derived from state

    func testStateMapsOntoTheRamp() {
        XCTAssertEqual(ShieldUrgency.from(state: .active), .calm)
        XCTAssertEqual(ShieldUrgency.from(state: .extended), .calm)
        XCTAssertEqual(ShieldUrgency.from(state: .firstWarning), .calm)
        XCTAssertEqual(ShieldUrgency.from(state: .secondWarning), .soon)
        XCTAssertEqual(ShieldUrgency.from(state: .finalWarning), .last)
        XCTAssertEqual(ShieldUrgency.from(state: .finished), .finished)
    }

    func testClockFallbackWhenNoIndexIsKnown() {
        XCTAssertEqual(ShieldUrgency.fromMinutesLeft(10), .calm)
        XCTAssertEqual(ShieldUrgency.fromMinutesLeft(5), .soon)
        XCTAssertEqual(ShieldUrgency.fromMinutesLeft(2), .soon)
        XCTAssertEqual(ShieldUrgency.fromMinutesLeft(1), .last)
    }

    // MARK: What the presentation actually carries

    func testFinishIsTheOnlyCelebration() {
        XCTAssertEqual(ShieldPresentation.make(for: .finished(activity: .outside), childName: "Ivy").urgency, .finished)
        XCTAssertEqual(ShieldPresentation.make(for: .finished(activity: nil), childName: "Ivy").urgency, .finished)
        XCTAssertEqual(ShieldPresentation.make(for: .spentForToday, childName: "Ivy").urgency, .spent)
    }

    func testExplicitUrgencyBeatsTheClock() {
        // 10 minutes left would read .calm on its own; the caller knows this is the last reminder.
        let p = ShieldPresentation.make(for: .reminder(minutesLeft: 10, activity: .lego),
                                        childName: "Ivy", urgency: .last)
        XCTAssertEqual(p.urgency, .last)
    }

    /// The activity still shapes the words and the badge — it just no longer picks the colour.
    func testActivityDoesNotChangeUrgency() {
        for activity in TransitionActivity.allCases {
            let p = ShieldPresentation.make(for: .reminder(minutesLeft: 5, activity: activity),
                                            childName: "Ivy", urgency: .soon)
            XCTAssertEqual(p.urgency, .soon)
            XCTAssertEqual(p.activity, activity)
        }
    }
}
