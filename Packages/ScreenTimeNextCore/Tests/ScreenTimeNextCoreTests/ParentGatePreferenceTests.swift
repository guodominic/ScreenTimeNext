//  ParentGatePreferenceTests.swift
//  ScreenTimeNextCoreTests
//
//  D-045 — the Face ID shortcut. The default is the security decision, so it is the thing tested
//  hardest: this app is usually installed on the CHILD's iPad, where the enrolled face is theirs.

import XCTest
@testable import ScreenTimeNextCore

final class ParentGatePreferenceTests: XCTestCase {

    /// The one that matters. If this ever goes green with `true`, the gate has been handed to
    /// whoever's face is enrolled on the device — which on a child's iPad is the child.
    func testBiometricsAreOffUnlessTheParentTurnsThemOn() {
        XCTAssertFalse(ParentGatePreference.default.usesBiometrics)
        XCTAssertFalse(ParentGatePreference().usesBiometrics)
        XCTAssertFalse(ParentPickerPreferences.default.gate.usesBiometrics)
    }

    func testTheChoiceSurvivesAStorageRoundTrip() throws {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(ParentPickerPreferences(gate: ParentGatePreference(usesBiometrics: true)))
        XCTAssertTrue(try storage.loadPickerPreferences().gate.usesBiometrics)
    }

    /// D-024 — the parent's own settings outlive a reset. Being asked to re-enable this after
    /// every "Start over" would train a parent to turn it on without reading why they should not.
    func testTheChoiceSurvivesStartOver() throws {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(ScreenTimeConfiguration.default)
        try storage.save(ParentPIN.make("1111"))
        try storage.save(ParentPickerPreferences(gate: ParentGatePreference(usesBiometrics: true)))

        try storage.eraseAll()

        XCTAssertTrue(try storage.loadPickerPreferences().gate.usesBiometrics)
        XCTAssertNotNil(try storage.loadParentPIN(), "D-054 — and so does the PIN it is a shortcut past")
    }

    /// A record written before D-045 has no gate at all, and must read as OFF rather than as a
    /// decode failure — and certainly not as ON.
    func testARecordFromBeforeTheShortcutExistedReadsAsOff() throws {
        let json = #"{"customActivities":[],"savedSelections":[],"blockedWebsites":[],"activityOrder":[],"hiddenActivityIDs":[]}"#
        let decoded = try JSONDecoder().decode(ParentPickerPreferences.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.gate.usesBiometrics)
    }

    // MARK: The service contract

    func testADeviceWithNothingEnrolledOffersNothing() async {
        let unlock = MockParentUnlockService()
        let kind = await unlock.available
        XCTAssertEqual(kind, .none, "so the Settings switch is not even shown")
    }

    func testCancellingIsNotAFailure() async {
        let unlock = MockParentUnlockService(available: .faceID, result: .failure(.cancelled))
        do {
            try await unlock.authenticate(reason: "test")
            XCTFail("should have thrown")
        } catch {
            // The distinction the UI depends on: a cancel returns the parent to the keypad in
            // silence, a mismatch says so, and unavailable hides the button.
            XCTAssertEqual(error as? ParentUnlockError, .cancelled)
        }
    }

    func testEachBiometricKindNamesItselfTheWayApplePutsIt() {
        XCTAssertEqual(BiometricKind.faceID.displayName, "Face ID")
        XCTAssertEqual(BiometricKind.touchID.displayName, "Touch ID")
        XCTAssertEqual(BiometricKind.opticID.displayName, "Optic ID")
    }
}
