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
        XCTAssertEqual(draft.warningMinutes, [10, 5, 1])
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

    /// Defaults follow the budget until the parent touches the dials.
    func testReminderDefaultsFollowTheBudget() {
        var draft = OnboardingDraft()
        XCTAssertEqual(draft.warningMinutes, [10, 5, 1])
        draft.dailyBudgetSeconds = 4 * 60
        XCTAssertEqual(draft.warningMinutes, [2, 1, 0])
        draft.dailyBudgetSeconds = 8 * 60
        XCTAssertEqual(draft.warningMinutes, [4, 1, 0])
        draft.dailyBudgetSeconds = 3 * 60
        XCTAssertEqual(draft.warningMinutes, [1, 0, 0])
        draft.dailyBudgetSeconds = 12 * 60
        XCTAssertEqual(draft.warningMinutes, [10, 5, 1])
        XCTAssertFalse(draft.hasCustomizedWarnings)
        // Once customized, they stick.
        draft.warningMinutes = [6, 0, 0]
        draft.dailyBudgetSeconds = 60 * 60
        XCTAssertEqual(draft.warningMinutes, [6, 0, 0])
        XCTAssertTrue(draft.hasCustomizedWarnings)
    }

    /// Budget lowered after reminders were set: reminders are clamped to budget − 1 minute.
    func testRemindersAreClampedToTheBudget() {
        var draft = OnboardingDraft()
        draft.warningMinutes = [10, 5, 1]
        draft.dailyBudgetSeconds = 8 * 60
        XCTAssertEqual(draft.configuration.warningOffsetsSeconds, [420, 300, 60], "10 → 7")
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
        draft.warningMinutes = [10, 0, 1]   // middle reminder off
        draft.selectedActivities = [.drawing]
        draft.selection = MockScreenTimeSelectionService.sampleSnapshot()

        try draft.commit(using: services)

        XCTAssertEqual(try storage.loadChildProfile()?.name, "Athan")
        let config = try storage.loadConfiguration()
        XCTAssertEqual(config.dailyBudgetSeconds, 1800)
        XCTAssertEqual(config.warningOffsetsSeconds, [600, 60])
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
