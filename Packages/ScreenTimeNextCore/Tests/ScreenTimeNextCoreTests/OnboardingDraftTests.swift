//  OnboardingDraftTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 003 — QA-01 support: the data half of onboarding.

import XCTest
@testable import ScreenTimeNextCore

final class OnboardingDraftTests: XCTestCase {

    /// PRD §6.5 / §6.6 defaults.
    func testDefaultsMatchThePRD() {
        let draft = OnboardingDraft()
        XCTAssertEqual(draft.dailyBudgetSeconds, 3600)
        XCTAssertTrue(draft.warning10Enabled && draft.warning5Enabled && draft.warning1Enabled)
        XCTAssertTrue(draft.selectedActivities.isEmpty)
        XCTAssertNil(draft.selection)
        XCTAssertFalse(draft.isChildNameValid)
        XCTAssertFalse(draft.hasSelection)
    }

    func testChildNameIsTrimmedAndValidated() {
        var draft = OnboardingDraft()
        draft.childName = "   "
        XCTAssertFalse(draft.isChildNameValid)
        draft.childName = "  Ivy \n"
        XCTAssertTrue(draft.isChildNameValid)
        XCTAssertEqual(draft.childProfile.name, "Ivy")
    }

    func testActivitiesAreStoredInCanonicalOrder() {
        var draft = OnboardingDraft()
        draft.selectedActivities = [.familyTime, .lego, .reading]
        XCTAssertEqual(draft.configuration.selectedActivities, [.lego, .reading, .familyTime])
    }

    func testCommitWritesProfileConfigurationAndSelection() throws {
        let storage = InMemoryScreenTimeStorageService()
        let selection = MockScreenTimeSelectionService()
        let services = ServiceContainer.mocks(selection: selection, storage: storage)

        var draft = OnboardingDraft()
        draft.childName = "Athan"
        draft.dailyBudgetSeconds = 1800
        draft.warning5Enabled = false
        draft.selectedActivities = [.drawing]
        draft.selection = MockScreenTimeSelectionService.sampleSnapshot()

        try draft.commit(using: services)

        XCTAssertEqual(try storage.loadChildProfile()?.name, "Athan")
        let config = try storage.loadConfiguration()
        XCTAssertEqual(config.dailyBudgetSeconds, 1800)
        XCTAssertFalse(config.warning5Enabled)
        XCTAssertEqual(config.selectedActivities, [.drawing])
        XCTAssertEqual(try selection.loadSelection(), draft.selection)
    }

    func testCommitWithoutNameThrowsAndWritesNothing() {
        let storage = InMemoryScreenTimeStorageService()
        let services = ServiceContainer.mocks(storage: storage)
        let draft = OnboardingDraft()
        XCTAssertThrowsError(try draft.commit(using: services)) { error in
            XCTAssertEqual(error as? OnboardingError, .missingChildName)
        }
        XCTAssertNil(try? storage.loadChildProfile())
    }

    func testCommitWithoutSelectionSkipsSelectionSave() throws {
        let selection = MockScreenTimeSelectionService()
        let services = ServiceContainer.mocks(selection: selection)
        var draft = OnboardingDraft()
        draft.childName = "Ivy"
        try draft.commit(using: services)
        XCTAssertNil(try selection.loadSelection())
    }
}
