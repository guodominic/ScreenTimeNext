//  MonitorJournalTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 010 — the extension's only way to report back. These pin the parts that are testable
//  without a device: the log trims, survives a re-open of the same suite, and answers "has this
//  fired today?" without confusing today with yesterday.
//
//  The callbacks themselves cannot be tested here. The simulator accrues no real usage, so whether
//  `eventDidReachThreshold` actually arrives is a device test (see the task's completion report).

import XCTest
@testable import ScreenTimeNextCore

final class MonitorJournalTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // A suite of our own: a test must never write into the real App Group container.
        suiteName = "screentimenext.tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func journal() -> MonitorJournal { MonitorJournal(defaults: defaults) }

    func testNothingRecordedReadsAsEmpty() {
        XCTAssertTrue(journal().entries().isEmpty)
        XCTAssertNil(journal().latest(.thresholdReached))
    }

    func testAnEntrySurvivesReopeningTheSuite() {
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        journal().record(.thresholdReached, activity: MonitoringName.dailyActivity, at: when)

        // A fresh value reading the same suite is what the APP does after the EXTENSION wrote.
        let reopened = MonitorJournal(defaults: defaults)
        XCTAssertEqual(reopened.entries().count, 1)
        XCTAssertEqual(reopened.latest(.thresholdReached)?.at, when)
        XCTAssertEqual(reopened.latest(.thresholdReached)?.activity, MonitoringName.dailyActivity)
    }

    /// D-059 — the activity name varies per entry on purpose. Recording the SAME event against the
    /// SAME activity within five seconds is now collapsed to one line (that is what stopped an
    /// alarm storm evicting every useful entry), so writing thirty identical rows a second apart
    /// would test the collapse rule rather than the capacity trim. These are thirty distinct facts.
    func testTheLogTrimsToItsCapacityKeepingTheNewest() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<(MonitorJournal.capacity + 7) {
            journal().record(.intervalDidStart,
                             activity: MonitoringName.sessionWarning(index: i),
                             at: start.addingTimeInterval(Double(i)))
        }
        let entries = journal().entries()
        XCTAssertEqual(entries.count, MonitorJournal.capacity)
        XCTAssertEqual(entries.last?.at, start.addingTimeInterval(Double(MonitorJournal.capacity + 6)),
                       "the newest entry is the one that must survive")
        XCTAssertEqual(entries.first?.at, start.addingTimeInterval(7), "the oldest are the ones dropped")
    }

    /// And the collapse itself, stated where someone reading this file will find it.
    func testARepeatedEventIsCollapsedButNeverHidesSomethingNew() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let j = journal()
        j.record(.staleAlarmIgnored, activity: MonitoringName.sessionEnd, at: start)
        j.record(.staleAlarmIgnored, activity: MonitoringName.sessionEnd, at: start.addingTimeInterval(2))
        XCTAssertEqual(j.entries().count, 1, "one burst is one fact")

        j.record(.shieldExtensionEntered, activity: MonitoringName.sessionEnd, at: start.addingTimeInterval(3))
        XCTAssertEqual(j.entries().count, 2, "a different event always lands")

        j.record(.staleAlarmIgnored, activity: MonitoringName.sessionEnd, at: start.addingTimeInterval(30))
        XCTAssertEqual(j.entries().count, 3, "and the same event later is a new fact")
    }

    func testLatestPicksTheRightKind() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let j = journal()
        j.record(.thresholdReached, activity: "a", at: start)
        j.record(.intervalDidEnd, activity: "a", at: start.addingTimeInterval(60))
        j.record(.intervalDidStart, activity: "a", at: start.addingTimeInterval(120))

        XCTAssertEqual(j.latest(.thresholdReached)?.at, start)
        XCTAssertEqual(j.latest(.intervalDidStart)?.at, start.addingTimeInterval(120))
        XCTAssertNil(j.latest(.warningBeforeThreshold))
    }

    /// The question the app actually asks. A threshold that fired yesterday says nothing about
    /// today's budget, and treating it as today's would shield a child who has used nothing.
    func testYesterdaysThresholdDoesNotCountAsTodays() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterdayEvening = today.addingTimeInterval(-3 * 3600)
        journal().record(.thresholdReached, activity: "a", at: yesterdayEvening)

        XCTAssertFalse(journal().hasFired(.thresholdReached, since: today))

        journal().record(.thresholdReached, activity: "a", at: today.addingTimeInterval(3600))
        XCTAssertTrue(journal().hasFired(.thresholdReached, since: today))
    }

    func testClearEmptiesTheLog() {
        journal().record(.intervalDidStart, activity: "a")
        XCTAssertFalse(journal().entries().isEmpty)
        journal().clear()
        XCTAssertTrue(journal().entries().isEmpty)
    }

    /// §16 — an entry may carry a callback name, our own activity name and a time. Nothing else.
    /// If a future change adds a field, this fails and the privacy question gets asked out loud.
    func testAnEntryCarriesNothingButACallbackNameAnActivityAndATime() throws {
        journal().record(.thresholdReached, activity: MonitoringName.dailyActivity,
                         at: Date(timeIntervalSince1970: 0))
        let data = try XCTUnwrap(defaults.data(forKey: "screentimenext.monitorJournal"))
        let raw = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(Set(try XCTUnwrap(raw.first).keys), ["event", "activity", "at"])
    }
}
