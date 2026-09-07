//  MockScreenTimeMonitoringService.swift
//  ScreenTimeNextCore
//
//  Task 002. Records calls instead of talking to DeviceActivity (Task 010).
//  Rule 3 — even the mock never pretends to be a per-second timer.

import Foundation

public final class MockScreenTimeMonitoringService: ScreenTimeMonitoringService, @unchecked Sendable {

    public struct Registration: Equatable, Sendable {
        public let budgetSeconds: Int
        public let warningOffsetsSeconds: [Int]
        public let selection: SelectionSnapshot
    }

    private let lock = NSLock()
    private var _isMonitoring = false
    private var _registrations: [Registration] = []
    private var _stopCount = 0
    private var _failNext: ScreenTimeMonitoringError?

    public init() {}

    // MARK: ScreenTimeMonitoringService

    public var isMonitoring: Bool {
        get async { lock.withLock { _isMonitoring } }
    }

    public func startMonitoring(budgetSeconds: Int,
                                warningOffsetsSeconds: [Int] = [],
                                selection: SelectionSnapshot) async throws {
        try lock.withLock {
            if let e = _failNext { _failNext = nil; throw e }
            _registrations.append(Registration(budgetSeconds: budgetSeconds,
                                               warningOffsetsSeconds: warningOffsetsSeconds,
                                               selection: selection))
            _isMonitoring = true
        }
    }

    public func stopMonitoring() async throws {
        lock.withLock {
            _stopCount += 1
            _isMonitoring = false
        }
    }

    public func restartMonitoring(budgetSeconds: Int,
                                  warningOffsetsSeconds: [Int] = [],
                                  selection: SelectionSnapshot) async throws {
        try await stopMonitoring()
        try await startMonitoring(budgetSeconds: budgetSeconds,
                                  warningOffsetsSeconds: warningOffsetsSeconds,
                                  selection: selection)
    }

    // MARK: D-047 — session alarms

    public struct SessionAlarms: Equatable, Sendable {
        public let endsAt: Date
        public let warningOffsetsSeconds: [Int]
    }

    private var _alarms: SessionAlarms?
    private var _alarmClearCount = 0

    public func scheduleSessionAlarms(endsAt: Date, warningOffsetsSeconds: [Int]) async throws {
        lock.withLock {
            _alarms = SessionAlarms(endsAt: endsAt, warningOffsetsSeconds: warningOffsetsSeconds)
        }
    }

    public func clearSessionAlarms() async {
        lock.withLock {
            _alarms = nil
            _alarmClearCount += 1
        }
    }

    // MARK: Test controls

    public var sessionAlarms: SessionAlarms? { lock.withLock { _alarms } }
    public var alarmClearCount: Int { lock.withLock { _alarmClearCount } }
    public var registrations: [Registration] { lock.withLock { _registrations } }
    public var stopCount: Int { lock.withLock { _stopCount } }
    public func failNextStart(with error: ScreenTimeMonitoringError) { lock.withLock { _failNext = error } }
}

/// D-045 — a face that is whatever the test says it is.
public final class MockParentUnlockService: ParentUnlockService, @unchecked Sendable {
    private let lock = NSLock()
    private var _available: BiometricKind
    private var _result: Result<Void, ParentUnlockError>
    private var _attempts = 0

    public init(available: BiometricKind = .none, result: Result<Void, ParentUnlockError> = .success(())) {
        _available = available
        _result = result
    }

    public var available: BiometricKind {
        get async { lock.withLock { _available } }
    }

    public func authenticate(reason: String) async throws {
        try lock.withLock {
            _attempts += 1
            if case .failure(let error) = _result { throw error }
        }
    }

    // MARK: Test controls
    public var attempts: Int { lock.withLock { _attempts } }
    public func set(available: BiometricKind) { lock.withLock { _available = available } }
    public func set(result: Result<Void, ParentUnlockError>) { lock.withLock { _result = result } }
}
