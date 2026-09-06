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

    // MARK: Test controls

    public var registrations: [Registration] { lock.withLock { _registrations } }
    public var stopCount: Int { lock.withLock { _stopCount } }
    public func failNextStart(with error: ScreenTimeMonitoringError) { lock.withLock { _failNext = error } }
}
