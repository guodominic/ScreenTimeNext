//  ShieldPresentationTests.swift
//  ScreenTimeNextCoreTests
//
//  D-012 — the interstitial copy, checked against the §7 rules. This copy ships unchanged into
//  the Phase 1 ShieldConfiguration extension, so it is worth pinning here.

import XCTest
@testable import ScreenTimeNextCore

final class ShieldPresentationTests: XCTestCase {

    func testReminderWithActivityNamesWhatComesNext() {
        let p = ShieldPresentation.make(for: .reminder(minutesLeft: 5, activity: .cleanUp), childName: "Ivy")
        XCTAssertEqual(p.title, "5 minutes left, Ivy")
        XCTAssertEqual(p.subtitle, "You picked Clean up for after. Finish up, then let's tidy up!")
        XCTAssertEqual(p.primaryButtonLabel, "OK, 5 more minutes")
        XCTAssertTrue(p.primaryButtonContinues)
        XCTAssertEqual(p.symbolName, TransitionActivity.cleanUp.symbolName)
    }

    func testReminderWithoutActivity() {
        let p = ShieldPresentation.make(for: .reminder(minutesLeft: 1, activity: nil), childName: "Athan")
        XCTAssertEqual(p.title, "1 minute left, Athan")
        XCTAssertEqual(p.primaryButtonLabel, "OK, one more minute")
        XCTAssertTrue(p.primaryButtonContinues)
    }

    /// §17 — the ending must never offer a way to keep going.
    func testFinishedAndSpentNeverContinue() {
        for moment in [ShieldMoment.finished(activity: .mealTime), .finished(activity: nil), .spentForToday] {
            let p = ShieldPresentation.make(for: moment, childName: "Ivy")
            XCTAssertFalse(p.primaryButtonContinues, "\(moment) must not offer a bypass")
        }
    }

    func testFinishedNamesTheChoice() {
        let p = ShieldPresentation.make(for: .finished(activity: .outside), childName: "Ivy")
        XCTAssertEqual(p.subtitle, "You chose Outside, Ivy. Let's head outside!")
        XCTAssertEqual(p.primaryButtonLabel, "Let's go!")
    }

    func testEmptyNameReadsNaturally() {
        let p = ShieldPresentation.make(for: .reminder(minutesLeft: 5, activity: nil), childName: "  ")
        XCTAssertEqual(p.title, "5 minutes left")
        XCTAssertFalse(p.subtitle.contains(","))
    }

    /// §7 copy checklist, mechanically: no threat framing, no technical terms, always warm.
    func testEveryMomentPassesTheCopyChecklist() {
        let banned = ["time's up", "blocked", "denied", "locked", "restricted", "shield",
                      "authorization", "entitlement", "threshold", "expired", "violation"]
        var moments: [ShieldMoment] = [.spentForToday, .finished(activity: nil)]
        for a in TransitionActivity.allCases {
            moments.append(.reminder(minutesLeft: 5, activity: a))
            moments.append(.finished(activity: a))
        }
        for moment in moments {
            let p = ShieldPresentation.make(for: moment, childName: "Ivy")
            let text = (p.title + " " + p.subtitle + " " + p.primaryButtonLabel).lowercased()
            for word in banned {
                XCTAssertFalse(text.contains(word), "\(moment) says \(word)")
            }
            XCTAssertFalse(p.title.isEmpty)
            XCTAssertFalse(p.subtitle.isEmpty)
            XCTAssertFalse(p.primaryButtonLabel.isEmpty)
            XCTAssertFalse(p.symbolName.isEmpty)
        }
    }

    func testLowercasedFirstLeavesTheRestAlone() {
        XCTAssertEqual("Let's go build!".lowercasedFirst, "let's go build!")
        XCTAssertEqual("".lowercasedFirst, "")
    }
}
