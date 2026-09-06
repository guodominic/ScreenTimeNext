//  FavouritesPersistenceTests.swift
//  ScreenTimeNextCoreTests
//
//  D-022 — "Save as my usual" must reach storage when it is pressed, not when some later screen is
//  saved. These pin the storage contract the picker relies on; the picker itself lives in the app
//  target, so what is testable here is that the configuration carries the values faithfully and
//  that a partial save cannot wipe the rest.

import XCTest
@testable import ScreenTimeNextCore

final class FavouritesPersistenceTests: XCTestCase {

    private var storage: InMemoryScreenTimeStorageService!

    override func setUp() {
        super.setUp()
        storage = InMemoryScreenTimeStorageService()
    }

    /// The autosave path: read the config, change only the arrangement, write it back. Everything
    /// the parent set elsewhere must survive that round trip.
    func testSavingTheArrangementLeavesTheRestOfTheConfigurationAlone() throws {
        var config = ScreenTimeConfiguration(dailyBudgetSeconds: 25 * 60,
                                             warningOffsetsSeconds: [480, 120],
                                             selectedActivities: [.lego, .outside])
        config.selectedCategories = [.games]
        try storage.save(config)

        // What the picker does when "Save as my usual" is pressed: it writes its OWN record and
        // never rewrites the configuration, so it cannot disturb anything set elsewhere.
        try storage.save(ParentPickerPreferences(categoryOrder: [.education, .browsers],
                                                 favourites: [.education, .browsers],
                                                 favouritesAreCustom: true))

        let prefs = try storage.loadPickerPreferences()
        XCTAssertEqual(prefs.favourites, [.education, .browsers])
        XCTAssertEqual(prefs.categoryOrder.prefix(2).map { $0 }, [.education, .browsers])

        let after = try storage.loadConfiguration()
        XCTAssertEqual(after.dailyBudgetSeconds, 25 * 60, "budget untouched")
        XCTAssertEqual(after.selectedActivities, [.lego, .outside], "activities untouched")
        XCTAssertEqual(after.selectedCategories, [.games], "the ticks belong to the surrounding screen")
        XCTAssertEqual(after.warningOffsetsSeconds, [480, 120], "reminders untouched")
    }

    func testFavouritesSurviveARelaunch() throws {
        try storage.save(ParentPickerPreferences(favourites: [.browsers, .education], favouritesAreCustom: true))
        // A fresh read is what the next launch does.
        XCTAssertEqual(try storage.loadPickerPreferences().favourites, [.browsers, .education])
    }

    /// The parent replaces the starting set entirely — including with one that is smaller.
    func testASmallerUsualSetReplacesTheDefaultRatherThanMerging() throws {
        XCTAssertEqual(ParentPickerPreferences.default.favourites, ContentCategory.defaultFavourites)
        try storage.save(ParentPickerPreferences(favourites: [.education], favouritesAreCustom: true))
        XCTAssertEqual(try storage.loadPickerPreferences().favourites, [.education])
    }

    /// Nothing stored yet must read as the defaults, never as an empty list of rows.
    func testNothingStoredReadsAsTheDefaults() throws {
        let prefs = try storage.loadPickerPreferences()
        XCTAssertEqual(prefs.categoryOrder, ContentCategory.defaultOrder)
        XCTAssertFalse(prefs.favouritesAreCustom)
    }

    /// `loadConfiguration` returns defaults rather than throwing when nothing is stored, so an
    /// autosave during first-run setup would CREATE a configuration — and a stored configuration is
    /// what marks the app as set up (D-016). Onboarding therefore passes no autosave target; this
    /// pins the storage behaviour that makes that necessary.
    func testLoadingWithNothingStoredReturnsDefaultsWithoutCreatingAnything() throws {
        XCTAssertFalse(try storage.hasStoredConfiguration())
        _ = try storage.loadConfiguration()
        XCTAssertFalse(try storage.hasStoredConfiguration(), "a read must never mark the app as set up")

        try storage.save(ScreenTimeConfiguration.default)
        XCTAssertTrue(try storage.hasStoredConfiguration(), "but a write does")
    }
}
