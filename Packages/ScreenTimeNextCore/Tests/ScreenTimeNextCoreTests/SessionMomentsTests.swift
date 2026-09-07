//  SessionMomentsTests.swift
//  ScreenTimeNextCoreTests
//
//  D-056 — an alarm that arrives before its moment must not act.
//
//  From a device log: three alarms firing in the same second, over and over, each burst dragging
//  the session's end further out and putting transition screens on screen at times that matched
//  nothing. The cause was a reminder alarm made early by a paused clock (D-050), acting anyway.

import XCTest
@testable import ScreenTimeNextCore

final class SessionMomentsTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private var configuration: ScreenTimeConfiguration {
        ScreenTimeConfiguration(dailyBudgetSeconds: 900, warningOffsetsSeconds: [300, 60])
    }
    private var window: SessionWindow { SessionWindow(startedAt: start, budgetSeconds: 900) }

    // MARK: Where each moment falls

    func testTheEndIsTheWindowsEnd() {
        XCTAssertEqual(SessionMoments.due(for: MonitoringName.sessionEnd,
                                          window: window, configuration: configuration),
                       window.endsAt)
    }

    func testEachReminderIsItsOffsetBeforeTheEnd() {
        let first = SessionMoments.due(for: MonitoringName.sessionWarning(index: 0),
                                       window: window, configuration: configuration)
        let last = SessionMoments.due(for: MonitoringName.sessionWarning(index: 1),
                                      window: window, configuration: configuration)
        XCTAssertEqual(first, window.endsAt.addingTimeInterval(-300))
        XCTAssertEqual(last, window.endsAt.addingTimeInterval(-60))
    }

    func testAnUnknownNameHasNoMoment() {
        XCTAssertNil(SessionMoments.due(for: "screentimenext.daily",
                                        window: window, configuration: configuration))
        XCTAssertNil(SessionMoments.due(for: MonitoringName.sessionWarning(index: 7),
                                        window: window, configuration: configuration),
                     "a reminder the configuration no longer has")
    }

    func testWarningIndexIsRecoverableFromTheName() {
        XCTAssertEqual(MonitoringName.warningIndex(of: MonitoringName.sessionWarning(index: 0)), 0)
        XCTAssertEqual(MonitoringName.warningIndex(of: MonitoringName.sessionWarning(index: 3)), 3)
        XCTAssertNil(MonitoringName.warningIndex(of: MonitoringName.sessionEnd))
        XCTAssertNil(MonitoringName.warningIndex(of: MonitoringName.dailyActivity))
    }

    // MARK: Early vs due

    func testAnAlarmAtItsMomentIsNotEarly() {
        let name = MonitoringName.sessionWarning(index: 1)
        let due = try! XCTUnwrap(SessionMoments.due(for: name, window: window, configuration: configuration))
        XCTAssertFalse(SessionMoments.isEarly(name, window: window, configuration: configuration, now: due))
    }

    func testALateAlarmIsStillDue() {
        let name = MonitoringName.sessionWarning(index: 1)
        let due = try! XCTUnwrap(SessionMoments.due(for: name, window: window, configuration: configuration))
        XCTAssertFalse(SessionMoments.isEarly(name, window: window, configuration: configuration,
                                              now: due.addingTimeInterval(120)),
                       "late is not a reason to skip it — the child still needs telling")
    }

    func testJitterInsideToleranceIsNotEarly() {
        let name = MonitoringName.sessionEnd
        let due = window.endsAt
        XCTAssertFalse(SessionMoments.isEarly(name, window: window, configuration: configuration,
                                              now: due.addingTimeInterval(-10)))
    }

    /// The reported bug: a transition screen paused the clock, so the alarm set for the old end
    /// arrives while the new end is still minutes away.
    func testAPausedClockMakesTheAlarmEarly() {
        let paused = window.paused(bySeconds: 120)
        let name = MonitoringName.sessionWarning(index: 1)
        // The alarm was set for the ORIGINAL moment and fires there.
        let firedAt = window.endsAt.addingTimeInterval(-60)
        XCTAssertTrue(SessionMoments.isEarly(name, window: paused, configuration: configuration, now: firedAt),
                      "two minutes were given back, so this reminder is two minutes early")
    }

    /// A parent taking minutes off moves the end the other way, which makes an alarm LATE, not
    /// early — and a late alarm still has something true to say.
    func testTakingTimeOffDoesNotMakeAnAlarmEarly() {
        let shorter = SessionWindow(startedAt: start, endsAt: window.endsAt.addingTimeInterval(-180),
                                    budgetSecondsAtStart: 900)
        let name = MonitoringName.sessionWarning(index: 1)
        let firedAt = window.endsAt.addingTimeInterval(-60)
        XCTAssertFalse(SessionMoments.isEarly(name, window: shorter, configuration: configuration, now: firedAt))
    }

    // MARK: The rate limit that closes the loop

    func testARearmCannotHappenTwiceInQuickSuccession() {
        let defaults = UserDefaults(suiteName: "SessionMomentsTests.rearm")!
        defaults.removePersistentDomain(forName: "SessionMomentsTests.rearm")
        let journal = MonitorJournal(defaults: defaults)

        XCTAssertTrue(journal.mayRearm(at: start))
        XCTAssertFalse(journal.mayRearm(at: start.addingTimeInterval(1)), "this is the loop")
        XCTAssertFalse(journal.mayRearm(at: start.addingTimeInterval(29)))
        XCTAssertTrue(journal.mayRearm(at: start.addingTimeInterval(31)))
    }

    func testANewSessionStartsWithACleanRearmClock() {
        let defaults = UserDefaults(suiteName: "SessionMomentsTests.rearm2")!
        defaults.removePersistentDomain(forName: "SessionMomentsTests.rearm2")
        let journal = MonitorJournal(defaults: defaults)

        XCTAssertTrue(journal.mayRearm(at: start))
        journal.forgetRearm()
        XCTAssertTrue(journal.mayRearm(at: start.addingTimeInterval(1)))
    }
}
