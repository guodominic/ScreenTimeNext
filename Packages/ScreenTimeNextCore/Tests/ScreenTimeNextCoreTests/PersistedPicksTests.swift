//  PersistedPicksTests.swift
//  ScreenTimeNextCoreTests
//
//  D-021 / D-035 — what the parent made must survive a relaunch and a "Start over", a record
//  written by an older build must never fail to decode, and the Live Activity must not outlive the
//  session that owns it.

import XCTest
@testable import ScreenTimeNextCore

final class PersistedPicksTests: XCTestCase {

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private func snapshot(categories: Int = 0, apps: Int = 0, websites: Int = 0) -> SelectionSnapshot {
        .phase0Placeholder(summary: SelectionSummary(applicationCount: apps,
                                                     categoryCount: categories,
                                                     webDomainCount: websites))
    }

    // MARK: Old records still decode (D-035)

    /// The category tiles are gone. A configuration written by a build that had them carries a
    /// `selectedCategories` key this version knows nothing about — it must be IGNORED, never a
    /// decode failure, because a throw here resets the parent's entire setup.
    func testAConfigurationFromTheTileEraStillDecodes() throws {
        let json = #"{"dailyBudgetSeconds":1500,"warningOffsetsSeconds":[300,60],"selectedActivities":[],"selectedCategories":["games","browsers"]}"#
        let decoded = try JSONDecoder().decode(ScreenTimeConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.dailyBudgetSeconds, 1500)
        XCTAssertEqual(decoded.warningOffsetsSeconds, [300, 60])
    }

    /// Same for the parent's own record: `categoryOrder` / `favourites` / `favouritesAreCustom`
    /// are gone, and the websites and named sets sitting beside them must come back untouched.
    func testAPreferencesRecordFromTheTileEraKeepsWhatStillExists() throws {
        let json = #"{"categoryOrder":["education","browsers"],"favourites":["games"],"favouritesAreCustom":true,"blockedWebsites":["youtube.com"],"customActivities":[],"savedSelections":[],"activityOrder":[]}"#
        let decoded = try JSONDecoder().decode(ParentPickerPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.blockedWebsites, ["youtube.com"])
    }

    /// A configuration written before D-021 has no picks at all — also fine.
    func testAnOlderConfigurationDecodes() throws {
        let json = #"{"dailyBudgetSeconds":900,"warningOffsetsSeconds":[300,60],"selectedActivities":[]}"#
        let decoded = try JSONDecoder().decode(ScreenTimeConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.dailyBudgetSeconds, 900)
    }

    // MARK: What the parent made survives a relaunch

    func testWebsitesAndSavedSetsSurviveAStorageRoundTrip() throws {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(ParentPickerPreferences(
            savedSelections: [SavedSelection(name: "School nights", snapshot: snapshot(categories: 2, apps: 3))],
            blockedWebsites: ["youtube.com", "roblox.com"]))

        let prefs = try storage.loadPickerPreferences()
        XCTAssertEqual(prefs.blockedWebsites, ["youtube.com", "roblox.com"])
        XCTAssertEqual(prefs.savedSelections.map(\.name), ["School nights"])
        XCTAssertEqual(prefs.savedSelections.first?.snapshot.summary.categoryCount, 2)
    }

    // MARK: Start over (D-024)

    /// The whole point of the separate record: a reset erases the child's setup and keeps the
    /// parent's own work, so nobody retypes a list of sites to get back to where they were.
    func testStartOverKeepsTheParentsOwnWorkAndClearsTheChildsSetup() throws {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(ChildProfile(name: "Ivy"))
        try storage.save(ScreenTimeConfiguration(dailyBudgetSeconds: 25 * 60))
        try storage.save(ParentPickerPreferences(
            savedSelections: [SavedSelection(name: "Weekend", snapshot: snapshot(categories: 1))],
            blockedWebsites: ["youtube.com"],
            activityOrder: ["outside", "cleanUp"]))

        try storage.eraseAll()

        XCTAssertNil(try storage.loadChildProfile(), "the child's profile goes")
        XCTAssertFalse(try storage.hasStoredConfiguration(), "and so does the setup")

        let kept = try storage.loadPickerPreferences()
        XCTAssertEqual(kept.blockedWebsites, ["youtube.com"], "but the sites they typed stay")
        XCTAssertEqual(kept.savedSelections.map(\.name), ["Weekend"], "and the sets they named")
        XCTAssertEqual(kept.activityOrder, ["outside", "cleanUp"], "and the order they dragged")
    }

    // MARK: The Live Activity does not outlive its session


    func testTheActivityIsRetiredWhenTheWindowRunsOut() throws {
        let storage = InMemoryScreenTimeStorageService()
        let presence = MockSessionPresenter()
        let clock = Clock(Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600))
        let controller = SessionController(storage: storage, presence: presence, now: { clock.now })
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 300
        try storage.save(config)

        _ = try controller.start()
        XCTAssertEqual(presence.finishCount, 0)

        clock.advance(300)
        _ = try controller.tick()
        XCTAssertEqual(presence.finishCount, 1, "the end of the window retires the card")
    }

    /// `finish` restarts the dismissal timer, so firing it on every one-second tick would keep the
    /// card alive indefinitely — exactly the bug it is meant to fix.
    func testTheActivityIsRetiredOnceNotOnEveryTick() throws {
        let storage = InMemoryScreenTimeStorageService()
        let presence = MockSessionPresenter()
        let clock = Clock(Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600))
        let controller = SessionController(storage: storage, presence: presence, now: { clock.now })
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 120
        try storage.save(config)

        _ = try controller.start()
        clock.advance(120)
        for _ in 0..<10 {
            _ = try controller.tick()
            clock.advance(1)
        }
        XCTAssertEqual(presence.finishCount, 1)
    }

    /// The force-quit case: nothing was running to end the activity, so the next launch must.
    func testALaunchWithNoSessionClearsAStrandedActivity() throws {
        let storage = InMemoryScreenTimeStorageService()
        let presence = MockSessionPresenter()
        let controller = SessionController(storage: storage, presence: presence)

        _ = try controller.restore()
        XCTAssertGreaterThanOrEqual(presence.hideCount, 1)
    }

    func testALaunchDuringASessionLeavesTheActivityAlone() throws {
        let storage = InMemoryScreenTimeStorageService()
        let presence = MockSessionPresenter()
        let clock = Clock(Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600))
        let controller = SessionController(storage: storage, presence: presence, now: { clock.now })
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 600
        try storage.save(config)

        _ = try controller.start()
        let hidesAfterStart = presence.hideCount
        clock.advance(60)
        _ = try controller.restore()
        XCTAssertEqual(presence.hideCount, hidesAfterStart, "a live session's card must stay put")
    }
}
