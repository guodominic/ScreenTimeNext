//  ParentPIN.swift
//  ScreenTimeNextCore
//
//  D-031 — the parent gate is a PIN, not a press-and-hold.
//
//  WHAT THIS IS AND IS NOT. The threat model is a child on the family's own device: no file access,
//  no debugger, no jailbreak. Against that, a stored PIN verifier is enough. It is NOT protection
//  against anyone who can read the container — a four-digit PIN has ten thousand possibilities and
//  no amount of hashing changes that. The iteration count below buys time against a casual offline
//  guess; it is not a claim of strength, and nothing in this app should ever be described to a
//  parent as unbreakable (§17).
//
//  The PIN itself is never stored. What is stored is a salted, iterated SHA-256 verifier.

import Foundation
import CryptoKit

public struct ParentPIN: Codable, Equatable, Sendable {

    /// Four digits: long enough to stop a child guessing over a parent's shoulder, short enough to
    /// enter one-handed while that child is asking why it is taking so long.
    public static let length = 4

    /// Deliberately slow. 120k rounds is imperceptible for one entry and turns an offline sweep of
    /// all 10,000 PINs from instant into merely tedious.
    private static let rounds = 120_000

    public let salt: Data
    public let verifier: Data

    private init(salt: Data, verifier: Data) {
        self.salt = salt
        self.verifier = verifier
    }

    /// nil when the digits are not a valid PIN, so a caller cannot accidentally store a weak one.
    public static func make(_ pin: String) -> ParentPIN? {
        guard isValid(pin) else { return nil }
        var salt = Data(count: 16)
        for i in salt.indices { salt[i] = UInt8.random(in: .min ... .max) }
        return ParentPIN(salt: salt, verifier: derive(pin: pin, salt: salt))
    }

    public func matches(_ pin: String) -> Bool {
        guard Self.isValid(pin) else { return false }
        let candidate = Self.derive(pin: pin, salt: salt)
        // Constant-time compare. Overkill for a local PIN, but the alternative is a habit of
        // writing `==` on secrets, and that habit is what eventually leaks something that matters.
        guard candidate.count == verifier.count else { return false }
        var difference: UInt8 = 0
        for (a, b) in zip(candidate, verifier) { difference |= a ^ b }
        return difference == 0
    }

    public static func isValid(_ pin: String) -> Bool {
        pin.count == length && pin.allSatisfy(\.isNumber)
    }

    private static func derive(pin: String, salt: Data) -> Data {
        var digest = Data(SHA256.hash(data: salt + Data(pin.utf8)))
        for _ in 1..<rounds {
            digest = Data(SHA256.hash(data: salt + digest))
        }
        return digest
    }
}

/// D-031 — how long to make someone wait after wrong guesses.
///
/// Kept as pure data so the policy is testable without a clock or a UI: a child with a device and
/// an afternoon is exactly the attacker this is for, and "how many tries before it slows down" is
/// the only real defence a four-digit PIN has.
public struct ParentPINLockout: Equatable, Sendable {

    public private(set) var failedAttempts: Int = 0

    public init() {}

    /// Free guesses before any delay. Three is enough for a parent mistyping in a hurry.
    public static let freeAttempts = 3

    public mutating func recordFailure() { failedAttempts += 1 }
    public mutating func reset() { failedAttempts = 0 }

    /// Seconds to wait before the next attempt is allowed. Doubles, capped at five minutes —
    /// long enough to end a guessing session, short enough that a parent who genuinely forgot is
    /// inconvenienced rather than locked out of their own device.
    public var delaySeconds: Int {
        let excess = failedAttempts - Self.freeAttempts
        guard excess > 0 else { return 0 }
        return min(300, Int(pow(2.0, Double(min(excess, 9)))) * 5)
    }

    public var isLocked: Bool { delaySeconds > 0 }
}
