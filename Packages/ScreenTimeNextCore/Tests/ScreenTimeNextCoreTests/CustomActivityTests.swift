//  CustomActivityTests.swift
//  ScreenTimeNextCoreTests
//
//  D-029 / D-030 — `TransitionActivity` stopped being a fixed enum, and that change reaches every
//  record that ever stored one. These pin the compatibility, not the feature.

import XCTest
@testable import ScreenTimeNextCore

final class CustomActivityTests: XCTestCase {

    // MARK: Decoding what earlier versions wrote

    /// Everything written while this was an enum encoded as a bare string. Sessions, windows and
    /// configurations on real devices are full of them.
    func testABareStringStillDecodesToTheBuiltIn() throws {
        let decoded = try JSONDecoder().decode(TransitionActivity.self, from: Data("\"lego\"".utf8))
        XCTAssertEqual(decoded, TransitionActivity.lego)
        XCTAssertEqual(decoded.displayName, "LEGO")
        XCTAssertFalse(decoded.isCustom)
    }

    /// An id nobody recognises — a custom activity the parent later deleted, say — must not throw.
    /// A child's choice on a running session is theirs; a readable placeholder beats losing it.
    func testAnUnknownIdSurvivesAsAPlaceholder() throws {
        let decoded = try JSONDecoder().decode(TransitionActivity.self, from: Data("\"piano\"".utf8))
        XCTAssertEqual(decoded.id, "piano")
        XCTAssertEqual(decoded.displayName, "Piano")
        XCTAssertTrue(decoded.isCustom)
    }

    func testAConfigurationOfBareStringsStillDecodes() throws {
        let json = #"{"dailyBudgetSeconds":900,"warningOffsetsSeconds":[60],"selectedActivities":["lego","outside"]}"#
        let config = try JSONDecoder().decode(ScreenTimeConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(config.selectedActivities, [.lego, .outside])
    }

    func testASessionWindowOfBareStringsStillDecodes() throws {
        let json = #"{"startedAt":0,"endsAt":900,"chosenActivity":"reading"}"#
        let window = try JSONDecoder().decode(SessionWindow.self, from: Data(json.utf8))
        XCTAssertEqual(window.chosenActivity, TransitionActivity.reading)
    }

    // MARK: Round trips

    func testACustomActivityRoundTrips() throws {
        let piano = TransitionActivity.custom(displayName: "Piano", symbolName: "music.note")
        let decoded = try JSONDecoder().decode(TransitionActivity.self, from: try JSONEncoder().encode(piano))
        XCTAssertEqual(decoded, piano)
        XCTAssertEqual(decoded.displayName, "Piano")
        XCTAssertEqual(decoded.symbolName, "music.note")
        XCTAssertTrue(decoded.isCustom)
    }

    /// A built-in is re-resolved from its id rather than trusted from disk, so improving its copy
    /// in a later version reaches families who already have it saved.
    func testABuiltInIsReResolvedRatherThanRestoredFromDisk() throws {
        let stale = #"{"id":"lego","displayName":"Old Name","invitation":"Old!","symbolName":"star.fill","isCustom":false}"#
        let decoded = try JSONDecoder().decode(TransitionActivity.self, from: Data(stale.utf8))
        XCTAssertEqual(decoded.displayName, "LEGO", "the shipped copy wins")
        XCTAssertEqual(decoded.symbolName, TransitionActivity.lego.symbolName)
    }

    // MARK: Identity

    /// Identity is the id alone, so renaming cannot orphan a choice already stored on a running
    /// session — the child picked THAT activity, whatever it is called now.
    func testRenamingKeepsIdentity() {
        let piano = TransitionActivity.custom(displayName: "Piano", symbolName: "music.note")
        let renamed = piano.renamed(to: "Keyboard", symbolName: "pianokeys")
        XCTAssertEqual(piano, renamed)
        XCTAssertEqual(renamed.displayName, "Keyboard")
        XCTAssertEqual(Set([piano, renamed]).count, 1)
    }

    func testTwoFamiliesPianosNeverCollide() {
        let a = TransitionActivity.custom(displayName: "Piano", symbolName: "music.note")
        let b = TransitionActivity.custom(displayName: "Piano", symbolName: "music.note")
        XCTAssertNotEqual(a, b)
    }

    func testTheInvitationIsWrittenForTheParent() {
        // §7 — a parent typing "dog walk" should not also have to write a cheerful sentence.
        XCTAssertEqual(TransitionActivity.custom(displayName: "Dog walk", symbolName: "pawprint.fill").invitation,
                       "Time for dog walk!")
    }

    func testBuiltInLookupReplacesTheOldRawValueInit() {
        XCTAssertEqual(TransitionActivity.builtIn(id: "outside"), TransitionActivity.outside)
        XCTAssertNil(TransitionActivity.builtIn(id: "custom.whatever"))
        XCTAssertEqual(TransitionActivity.allCases.count, 8)
    }

    // MARK: The parent's own list

    func testCustomActivitiesAndSavedSetsSurviveInPreferences() throws {
        let piano = TransitionActivity.custom(displayName: "Piano", symbolName: "music.note")
        let set = SavedSelection(name: "School nights",
                                 snapshot: .phase0Placeholder(summary: SelectionSummary(applicationCount: 2,
                                                                                        categoryCount: 3,
                                                                                        webDomainCount: 1)))
        let prefs = ParentPickerPreferences(customActivities: [piano], savedSelections: [set])
        let decoded = try JSONDecoder().decode(ParentPickerPreferences.self,
                                               from: try JSONEncoder().encode(prefs))
        XCTAssertEqual(decoded.customActivities, [piano])
        XCTAssertEqual(decoded.savedSelections.first?.name, "School nights")
        XCTAssertEqual(decoded.allActivities.count, 9)
        XCTAssertEqual(decoded.allActivities.last, piano)
    }

    /// D-024 — the parent's own creations are exactly the kind of thing "Start over" must keep.
    func testCustomActivitiesSurviveStartOver() throws {
        let storage = InMemoryScreenTimeStorageService()
        let piano = TransitionActivity.custom(displayName: "Piano", symbolName: "music.note")
        try storage.save(ParentPickerPreferences(customActivities: [piano]))
        try storage.save(ScreenTimeConfiguration(selectedActivities: [piano]))

        try storage.eraseAll()

        XCTAssertEqual(try storage.loadPickerPreferences().customActivities, [piano])
        XCTAssertEqual(try storage.loadConfiguration().selectedActivities, [], "the child's setup goes")
    }

    func testSavedSelectionSubtitleCountsOnly() {
        let set = SavedSelection(name: "Weekend",
                                 snapshot: .phase0Placeholder(summary: SelectionSummary(applicationCount: 1,
                                                                                        categoryCount: 2,
                                                                                        webDomainCount: 0)))
        XCTAssertEqual(set.subtitle, "2 categories · 1 app")
    }
}
