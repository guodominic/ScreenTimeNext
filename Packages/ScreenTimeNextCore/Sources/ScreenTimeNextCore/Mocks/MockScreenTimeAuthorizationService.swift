//  MockScreenTimeAuthorizationService.swift
//  ScreenTimeNextCore
//
//  Task 002. Scriptable stand-in for the real FamilyControls adapter (Task 004).
//  Used by the whole app in Phase 0 (D-007) and by tests. Framework-free.

import Foundation

public final class MockScreenTimeAuthorizationService: ScreenTimeAuthorizationService, @unchecked Sendable {

    /// What `requestAuthorization()` will produce. Defaults to `.approved`.
    public enum Script: Sendable {
        case approve
        case deny
        /// Simulates the entitlement being unavailable (docs/BLOCKERS.md B-001).
        case entitlementUnavailable
    }

    private let lock = NSLock()
    private var _status: ScreenTimeAuthorizationStatus
    private var _script: Script
    private var _requestCount = 0

    public init(initialStatus: ScreenTimeAuthorizationStatus = .notDetermined, script: Script = .approve) {
        _status = initialStatus
        _script = script
    }

    // MARK: ScreenTimeAuthorizationService

    public var status: ScreenTimeAuthorizationStatus {
        get async { lock.withLock { _status } }
    }

    @discardableResult
    public func requestAuthorization() async throws -> ScreenTimeAuthorizationStatus {
        try lock.withLock {
            _requestCount += 1
            switch _script {
            case .approve:
                _status = .approved
                return _status
            case .deny:
                _status = .denied
                throw ScreenTimeAuthorizationError.denied
            case .entitlementUnavailable:
                throw ScreenTimeAuthorizationError.entitlementUnavailable
            }
        }
    }

    // MARK: Test controls

    public var requestCount: Int { lock.withLock { _requestCount } }

    public func setScript(_ script: Script) { lock.withLock { _script = script } }

    /// Simulate the parent revoking authorization in Settings while the app is running (Task 017, QA-14).
    public func revoke() { lock.withLock { _status = .revoked } }
}
