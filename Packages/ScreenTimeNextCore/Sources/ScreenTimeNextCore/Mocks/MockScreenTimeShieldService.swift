//  MockScreenTimeShieldService.swift
//  ScreenTimeNextCore
//
//  Task 002. Tracks protection state instead of touching ManagedSettings (Task 011).
//  Counts calls so tests can prove idempotency (Rule 6, QA-10).

import Foundation

public final class MockScreenTimeShieldService: ScreenTimeShieldService, @unchecked Sendable {

    private let lock = NSLock()
    private var _state: ProtectionState
    private var _applyCount = 0
    private var _removeCount = 0
    private var _lastShielded: SelectionSnapshot?

    public init(initialState: ProtectionState = .unshielded) {
        _state = initialState
    }

    // MARK: ScreenTimeShieldService

    public var currentProtectionState: ProtectionState {
        lock.withLock { _state }
    }

    public func applyShield(for selection: SelectionSnapshot) throws {
        try lock.withLock {
            if selection.summary.isEmpty { throw ScreenTimeShieldError.noSelection }
            _applyCount += 1
            _lastShielded = selection
            _state = .shielded
        }
    }

    public func removeShield() throws {
        lock.withLock {
            _removeCount += 1
            _lastShielded = nil
            _state = .unshielded
        }
    }

    // MARK: Test controls

    public var applyCount: Int { lock.withLock { _applyCount } }
    public var removeCount: Int { lock.withLock { _removeCount } }
    public var lastShielded: SelectionSnapshot? { lock.withLock { _lastShielded } }

    /// Simulate the extension having written a state while the app was closed (PRD §14).
    public func setState(_ state: ProtectionState) { lock.withLock { _state = state } }
}
