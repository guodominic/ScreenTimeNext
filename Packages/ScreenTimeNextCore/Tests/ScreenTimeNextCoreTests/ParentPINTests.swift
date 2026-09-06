//  ParentPINTests.swift
//  ScreenTimeNextCoreTests
//
//  D-031 — the parent gate. The PIN is the only thing standing between a child and the screen that
//  grants more screen time, so the properties below are the feature, not decoration.

import XCTest
@testable import ScreenTimeNextCore

final class ParentPINTests: XCTestCase {

    func testTheRightPINMatchesAndOthersDoNot() throws {
        let pin = try XCTUnwrap(ParentPIN.make("2468"))
        XCTAssertTrue(pin.matches("2468"))
        XCTAssertFalse(pin.matches("2469"))
        XCTAssertFalse(pin.matches("8642"))
        XCTAssertFalse(pin.matches(""))
    }

    /// The PIN itself must never be recoverable from what we store — not because a child could
    /// read the container, but because storing a secret in the clear is a habit, and habits spread.
    func testThePINItselfIsNeverStored() throws {
        let pin = try XCTUnwrap(ParentPIN.make("1234"))
        let encoded = try JSONEncoder().encode(pin)
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(text.contains("1234"))
        XCTAssertFalse(pin.verifier.contains(where: { $0 == 0x31 }) && text.contains("\"1234\""))
    }

    /// Two parents choosing the same PIN must not produce the same stored bytes, or one leaked
    /// record would tell you about every family that picked 1234.
    func testTheSamePINStoresDifferentlyEachTime() throws {
        let a = try XCTUnwrap(ParentPIN.make("1234"))
        let b = try XCTUnwrap(ParentPIN.make("1234"))
        XCTAssertNotEqual(a.salt, b.salt)
        XCTAssertNotEqual(a.verifier, b.verifier)
        XCTAssertTrue(a.matches("1234"))
        XCTAssertTrue(b.matches("1234"))
    }

    func testOnlyFourDigitsAreAccepted() {
        XCTAssertNil(ParentPIN.make("123"))
        XCTAssertNil(ParentPIN.make("12345"))
        XCTAssertNil(ParentPIN.make("12a4"))
        XCTAssertNil(ParentPIN.make(""))
        XCTAssertNotNil(ParentPIN.make("0000"))
    }

    func testItSurvivesAStorageRoundTrip() throws {
        let storage = InMemoryScreenTimeStorageService()
        XCTAssertNil(try storage.loadParentPIN())
        try storage.save(ParentPIN.make("7391"))
        XCTAssertTrue(try XCTUnwrap(storage.loadParentPIN()).matches("7391"))
        try storage.save(nil)
        XCTAssertNil(try storage.loadParentPIN(), "turning it off must actually remove it")
    }

    /// D-031 — unlike the parent's own preferences, the PIN goes. A forgotten PIN that survived a
    /// reset would lock a parent out of their own device with no way back.
    func testStartOverClearsThePIN() throws {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(ParentPIN.make("1111"))
        try storage.save(ParentPickerPreferences(blockedWebsites: ["youtube.com"]))

        try storage.eraseAll()

        XCTAssertNil(try storage.loadParentPIN())
        XCTAssertEqual(try storage.loadPickerPreferences().blockedWebsites, ["youtube.com"], "preferences still stay")
    }

    // MARK: Lockout

    func testTheFirstFewMistakesCostNothing() {
        var lockout = ParentPINLockout()
        for _ in 0..<ParentPINLockout.freeAttempts {
            lockout.recordFailure()
            XCTAssertFalse(lockout.isLocked)
            XCTAssertEqual(lockout.delaySeconds, 0)
        }
    }

    func testTheDelayGrowsAndThenStops() {
        var lockout = ParentPINLockout()
        for _ in 0..<(ParentPINLockout.freeAttempts + 1) { lockout.recordFailure() }
        let first = lockout.delaySeconds
        XCTAssertGreaterThan(first, 0)

        lockout.recordFailure()
        XCTAssertGreaterThan(lockout.delaySeconds, first, "each further guess costs more")

        for _ in 0..<40 { lockout.recordFailure() }
        XCTAssertEqual(lockout.delaySeconds, 300,
                       "capped: a parent who genuinely forgot must not be locked out for hours")
    }

    /// Only a correct PIN clears it. If sitting out one wait reset the counter, a child with an
    /// afternoon would get unlimited guesses in batches of three.
    func testOnlySuccessClearsTheCounter() {
        var lockout = ParentPINLockout()
        for _ in 0..<6 { lockout.recordFailure() }
        XCTAssertTrue(lockout.isLocked)
        lockout.reset()
        XCTAssertFalse(lockout.isLocked)
        XCTAssertEqual(lockout.delaySeconds, 0)
    }
}
