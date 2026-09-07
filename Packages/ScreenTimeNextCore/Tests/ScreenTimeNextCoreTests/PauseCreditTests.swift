//  PauseCreditTests.swift
//  ScreenTimeNextCoreTests
//
//  D-059 — the transition screen pauses the clock, and the pause must measure READING, not waiting.
//
//  D-050 credited "time since the shield was armed", on the premise that a child cannot use the
//  device while a shield is up. That premise is false: our shield covers the apps the parent picked
//  and nothing else, so a child can press Home and play elsewhere for ten minutes. Crediting that
//  back moved the session's end, which moved every alarm, which is what left transition screens
//  arriving at times that matched no reminder and countdowns changing when a screen was dismissed.

import XCTest
@testable import ScreenTimeNextCore

final class PauseCreditTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var journal: MonitorJournal!

    override func setUpWithError() throws {
        suiteName = "PauseCreditTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
        journal = MonitorJournal(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: What is owed

    func testTheCreditIsTheTimeSpentReadingTheScreen() {
        journal.markShieldShown(at: start)
        XCTAssertEqual(journal.claimPausedSeconds(at: start.addingTimeInterval(6)), 6)
    }

    /// D-071 — the reported bug. iOS repaints the shield while the child is still looking at it
    /// (opening the submenu is a repaint), and D-059 restarted the clock on every repaint. Forty
    /// seconds of reading credited the two since the last one.
    func testARepaintDoesNotRestartTheClock() {
        journal.markShieldShown(at: start)
        journal.markShieldShown(at: start.addingTimeInterval(20))   // submenu opened — a repaint
        journal.markShieldShown(at: start.addingTimeInterval(38))   // and another
        XCTAssertEqual(journal.claimPausedSeconds(at: start.addingTimeInterval(40)), 40,
                       "the whole visit is owed, not the moment since the last repaint")
    }

    /// A child who left and came back much later starts a new visit. The cap is what makes this
    /// safe, not the repaint.
    func testAVisitOlderThanTheCapStartsOver() {
        journal.markShieldShown(at: start)
        journal.markShieldShown(at: start.addingTimeInterval(600))  // ten minutes later
        XCTAssertEqual(journal.claimPausedSeconds(at: start.addingTimeInterval(604)), 4)
    }

    func testTheCreditIsCapped() {
        journal.markShieldShown(at: start)
        XCTAssertEqual(journal.claimPausedSeconds(at: start.addingTimeInterval(3600)),
                       MonitorJournal.maximumPauseSeconds)
    }

    func testTheCapIsShortEnoughToBeWrongAbout() {
        XCTAssertLessThanOrEqual(MonitorJournal.maximumPauseSeconds, 120,
                                 "a bounded mistake, not a session that outlives bedtime")
    }

    func testClaimingTwiceGivesNothingBack() {
        journal.markShieldShown(at: start)
        XCTAssertEqual(journal.claimPausedSeconds(at: start.addingTimeInterval(5)), 5)
        XCTAssertEqual(journal.claimPausedSeconds(at: start.addingTimeInterval(9)), 0,
                       "the mark is spent")
    }

    func testNothingIsOwedWhenNoScreenWasShown() {
        XCTAssertEqual(journal.claimPausedSeconds(at: start), 0)
    }

    // MARK: What reaches the window

    func testTheWindowGrowsByExactlyWhatWasRead() throws {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(SessionWindow(startedAt: start, budgetSeconds: 120))
        journal.markShieldShown(at: start.addingTimeInterval(60))

        let credited = journal.creditPause(to: storage, at: start.addingTimeInterval(68))

        XCTAssertEqual(credited, 8)
        let window = try XCTUnwrap(try storage.loadSessionWindow())
        XCTAssertEqual(window.endsAt, start.addingTimeInterval(128))
        XCTAssertEqual(window.pausedSeconds, 8)
    }

    /// A finished session gets nothing back: the pause exists so a child is not charged for our
    /// interruption, not as a way to reopen a session that is over.
    func testAFinishedSessionIsNotReopened() throws {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(SessionWindow(startedAt: start, budgetSeconds: 120))
        journal.markShieldShown(at: start.addingTimeInterval(200))

        XCTAssertEqual(journal.creditPause(to: storage, at: start.addingTimeInterval(205)), 0)
        let window = try XCTUnwrap(try storage.loadSessionWindow())
        XCTAssertEqual(window.endsAt, start.addingTimeInterval(120), "untouched")
    }

    // MARK: The log stops drowning itself

    func testABurstOfTheSameEventIsRecordedOnce() {
        journal.record(.staleAlarmIgnored, activity: "a", at: start)
        journal.record(.staleAlarmIgnored, activity: "a", at: start.addingTimeInterval(1))
        journal.record(.staleAlarmIgnored, activity: "a", at: start.addingTimeInterval(3))
        XCTAssertEqual(journal.entries().count, 1)
    }

    func testADifferentEventAlwaysLands() {
        journal.record(.staleAlarmIgnored, activity: "a", at: start)
        journal.record(.shieldExtensionEntered, activity: "a", at: start.addingTimeInterval(1))
        journal.record(.staleAlarmIgnored, activity: "b", at: start.addingTimeInterval(2))
        XCTAssertEqual(journal.entries().count, 3, "collapsing must never hide something new")
    }

    func testTheSameEventLaterIsANewFact() {
        journal.record(.staleAlarmIgnored, activity: "a", at: start)
        journal.record(.staleAlarmIgnored, activity: "a", at: start.addingTimeInterval(30))
        XCTAssertEqual(journal.entries().count, 2)
    }
}
