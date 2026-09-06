//  PersistedPicksTests.swift
//  ScreenTimeNextCoreTests
//
//  D-021 — what the parent picked, arranged and saved as "my usual" must all survive a relaunch,
//  and the Live Activity must not outlive the session that owns it.

import XCTest
@testable import ScreenTimeNextCore

final class PersistedPicksTests: XCTestCase {

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    // MARK: Picks survive a relaunch

    func testSelectedCategoriesRoundTrip() throws {
        var config = ScreenTimeConfiguration.default
        config.selectedCategories = [.browsers, .games, .social]
        let decoded = try JSONDecoder().decode(ScreenTimeConfiguration.self,
                                               from: try JSONEncoder().encode(config))
        XCTAssertEqual(decoded.selectedCategories, [.browsers, .games, .social])
    }

    func testTicksAndArrangementSurviveTogetherInTheirOwnRecords() throws {
        let storage = InMemoryScreenTimeStorageService()
        var config = ScreenTimeConfiguration.default
        config.selectedCategories = [.education, .games]
        try storage.save(config)
        try storage.save(ParentPickerPreferences(categoryOrder: [.education, .browsers, .games],
                                                 favourites: [.education],
                                                 favouritesAreCustom: true))

        XCTAssertEqual(try storage.loadConfiguration().selectedCategories, [.education, .games])
        let prefs = try storage.loadPickerPreferences()
        XCTAssertEqual(prefs.categoryOrder.prefix(3).map { $0 }, [.education, .browsers, .games])
        XCTAssertEqual(prefs.favourites, [.education])
    }

    /// A configuration written before D-021 has no picks — it must decode as "nothing ticked yet",
    /// never as a decode failure that would reset the parent's whole setup.
    func testAnOlderConfigurationDecodesWithNoPicks() throws {
        let json = #"{"dailyBudgetSeconds":900,"warningOffsetsSeconds":[300,60],"selectedActivities":[]}"#
        let decoded = try JSONDecoder().decode(ScreenTimeConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.selectedCategories, [])
        XCTAssertEqual(decoded.dailyBudgetSeconds, 900)
    }

    func testPicksSurviveAStorageRoundTrip() throws {
        let storage = InMemoryScreenTimeStorageService()
        var config = ScreenTimeConfiguration.default
        config.selectedCategories = [.browsers, .games]
        try storage.save(config)
        try storage.save(ParentPickerPreferences(favourites: [.browsers, .games], favouritesAreCustom: true))

        XCTAssertEqual(try storage.loadConfiguration().selectedCategories, [.browsers, .games])
        XCTAssertEqual(try storage.loadPickerPreferences().favourites, [.browsers, .games])
    }

    // MARK: Start over (D-024)

    /// The whole point of the separate record: a reset erases the child's setup and keeps the
    /// parent's arrangement, so nobody re-drags thirteen rows to get back to where they were.
    func testStartOverKeepsTheParentsArrangementAndClearsTheChildsSetup() throws {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(ChildProfile(name: "Ivy"))
        var config = ScreenTimeConfiguration(dailyBudgetSeconds: 25 * 60)
        config.selectedCategories = [.games, .browsers]
        try storage.save(config)
        try storage.save(ParentPickerPreferences(categoryOrder: [.education, .browsers],
                                                 favourites: [.education, .browsers],
                                                 favouritesAreCustom: true))

        try storage.eraseAll()

        XCTAssertNil(try storage.loadChildProfile(), "the child's profile goes")
        XCTAssertFalse(try storage.hasStoredConfiguration(), "and so does the setup")
        XCTAssertEqual(try storage.loadConfiguration().selectedCategories, [], "including the ticks")

        let kept = try storage.loadPickerPreferences()
        XCTAssertEqual(kept.favourites, [.education, .browsers], "but 'my usual' stays")
        XCTAssertEqual(kept.categoryOrder.prefix(2).map { $0 }, [.education, .browsers], "and the order")
        XCTAssertEqual(kept.initialSelection, [.education, .browsers],
                       "so the fresh picker opens on the parent's own set")
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
