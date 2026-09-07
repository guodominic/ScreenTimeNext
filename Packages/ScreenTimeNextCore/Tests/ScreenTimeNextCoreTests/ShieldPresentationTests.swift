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
            XCTAssertFalse(p.primaryButtonLabel.isEmpty, "every moment must name its button (D-065)")
            XCTAssertFalse(p.symbolName.isEmpty)
        }
    }

    /// D-065 — the ask ALWAYS has both buttons, whichever ask it is.
    ///
    /// D-056 removed the primary button on the last ask. That handed iOS a `ShieldConfiguration`
    /// with a primary button colour and no primary button, and iOS answered with its own grey
    /// "Restricted" screen — silently, on the moment that mattered most. A field left unfilled in a
    /// process we cannot see costs the whole screen, so every field is filled.
    func testEveryAskOffersBothButtons() {
        let options = Array(TransitionActivity.allCases.prefix(3))
        for minutes in [1, 5] {
            let p = ShieldPresentation.make(for: .chooseNext(minutesLeft: minutes, options: options),
                                            childName: "Ivy")
            XCTAssertEqual(p.primaryButtonLabel, "Close the app",
                           "D-067 — it insists, and D-065 — it still names its button")
            XCTAssertFalse(p.primaryButtonContinues, "the only way back INTO the app is to choose")
            XCTAssertEqual(p.secondaryButtonLabel, "What's next?")
            XCTAssertEqual(p.submenuItems, options.map(\.displayName))
        }
    }

    /// What the child sees is decided by whether they have chosen, and nothing else:
    /// not chosen → the minutes AND the list; chosen → just the minutes.
    func testTheChooserAppearsOnlyWhileNothingIsChosen() {
        let options = Array(TransitionActivity.allCases.prefix(3))
        let asking = ShieldPresentation.make(for: .chooseNext(minutesLeft: 2, options: options),
                                             childName: "Ivy")
        XCTAssertFalse(asking.submenuItems.isEmpty)
        XCTAssertTrue(asking.title.contains("2 minutes left"))

        let told = ShieldPresentation.make(for: .reminder(minutesLeft: 2, activity: .outside), childName: "Ivy")
        XCTAssertTrue(told.submenuItems.isEmpty, "chosen already — re-asking reads as \"that wasn\'t good enough\"")
        XCTAssertNil(told.secondaryButtonLabel)
        XCTAssertTrue(told.title.contains("2 minutes left"))
    }

    func testLowercasedFirstLeavesTheRestAlone() {
        XCTAssertEqual("Let's go build!".lowercasedFirst, "let's go build!")
        XCTAssertEqual("".lowercasedFirst, "")
    }
}
