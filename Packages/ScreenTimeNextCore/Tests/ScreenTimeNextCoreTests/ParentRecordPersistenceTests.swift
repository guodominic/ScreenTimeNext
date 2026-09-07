//  ParentRecordPersistenceTests.swift
//  ScreenTimeNextCoreTests
//
//  D-022 / D-035 — the parent's own record must reach storage when they press the thing, not when
//  some later screen is saved, and writing it must never disturb the child's setup sitting beside
//  it. (Was FavouritesPersistenceTests: the "my usual" set of category tiles it guarded is gone
//  with D-035, but the storage contract it pinned still holds every website and named set.)

import XCTest
@testable import ScreenTimeNextCore

final class ParentRecordPersistenceTests: XCTestCase {

    private var storage: InMemoryScreenTimeStorageService!

    override func setUp() {
        super.setUp()
        storage = InMemoryScreenTimeStorageService()
    }

    private func snapshot(categories: Int = 0, apps: Int = 0) -> SelectionSnapshot {
        .phase0Placeholder(summary: SelectionSummary(applicationCount: apps,
                                                     categoryCount: categories,
                                                     webDomainCount: 0))
    }

    /// The autosave path: the picker writes its OWN record and never rewrites the configuration,
    /// so typing a website cannot cost the parent the budget they set two screens ago.
    func testSavingTheParentsRecordLeavesTheConfigurationAlone() throws {
        let config = ScreenTimeConfiguration(dailyBudgetSeconds: 25 * 60,
                                             warningOffsetsSeconds: [480, 120],
                                             selectedActivities: [.cleanUp, .outside])
        try storage.save(config)

        try storage.save(ParentPickerPreferences(blockedWebsites: ["youtube.com"]))

        XCTAssertEqual(try storage.loadPickerPreferences().blockedWebsites, ["youtube.com"])

        let after = try storage.loadConfiguration()
        XCTAssertEqual(after.dailyBudgetSeconds, 25 * 60, "budget untouched")
        XCTAssertEqual(after.selectedActivities, [.cleanUp, .outside], "activities untouched")
        XCTAssertEqual(after.warningOffsetsSeconds, [480, 120], "reminders untouched")
    }

    func testWebsitesSurviveARelaunch() throws {
        try storage.save(ParentPickerPreferences(blockedWebsites: ["youtube.com", "roblox.com"]))
        // A fresh read is what the next launch does.
        XCTAssertEqual(try storage.loadPickerPreferences().blockedWebsites, ["youtube.com", "roblox.com"])
    }

    /// A saved set carries the opaque snapshot through storage intact — that is the whole point of
    /// D-030, since a website can only be created inside Apple's picker and retyping it is not an
    /// option. The payload must come back byte-for-byte, not just the counts.
    func testASavedSetCarriesItsSnapshotThroughStorageIntact() throws {
        let original = snapshot(categories: 2, apps: 3)
        try storage.save(ParentPickerPreferences(
            savedSelections: [SavedSelection(name: "Weekend", snapshot: original)]))

        let saved = try storage.loadPickerPreferences().savedSelections
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.snapshot, original)
        XCTAssertEqual(saved.first?.subtitle, "2 categories · 3 apps")
    }

    /// The name is trimmed on the way in, so "Weekend " and "Weekend" cannot become two rows the
    /// parent has to tell apart by their trailing space.
    func testASavedSetsNameIsTrimmed() {
        XCTAssertEqual(SavedSelection(name: "  Weekend  ", snapshot: snapshot()).name, "Weekend")
    }

    /// Nothing stored yet must read as an empty record, never as a decode failure.
    func testNothingStoredReadsAsTheDefaults() throws {
        let prefs = try storage.loadPickerPreferences()
        XCTAssertTrue(prefs.blockedWebsites.isEmpty)
        XCTAssertTrue(prefs.savedSelections.isEmpty)
        XCTAssertTrue(prefs.customActivities.isEmpty)
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
