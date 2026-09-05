//  InMemoryScreenTimeStorageService.swift
//  ScreenTimeNextCore
//
//  Task 002. Volatile storage for previews, tests and the Task 003 onboarding walkthrough.
//  Task 006 adds LocalStorageService (app container, Phase 0) and, in Phase 1, the App Group
//  implementation — all behind the same protocol.

import Foundation

public final class InMemoryScreenTimeStorageService: ScreenTimeStorageService, @unchecked Sendable {

    private let lock = NSLock()
    private var profile: ChildProfile?
    private var configuration: ScreenTimeConfiguration?
    private var usageByDay: [Date: DailyUsage] = [:]
    private var window: SessionWindow?
    private var protection: ProtectionState = .unshielded
    private var _failing = false

    public init() {}

    private func check() throws {
        if _failing { throw ScreenTimeStorageError.containerUnavailable }
    }

    // MARK: ScreenTimeStorageService

    public func loadChildProfile() throws -> ChildProfile? {
        try lock.withLock { try check(); return profile }
    }
    public func save(_ profile: ChildProfile) throws {
        try lock.withLock { try check(); self.profile = profile }
    }

    public func loadConfiguration() throws -> ScreenTimeConfiguration {
        try lock.withLock { try check(); return configuration ?? .default }
    }
    public func save(_ configuration: ScreenTimeConfiguration) throws {
        try lock.withLock { try check(); self.configuration = configuration }
    }

    public func hasStoredConfiguration() throws -> Bool {
        try lock.withLock { try check(); return configuration != nil }
    }

    public func loadDailyUsage(for date: Date) throws -> DailyUsage? {
        try lock.withLock { try check(); return usageByDay[Self.dayKey(date)] }
    }
    public func save(_ usage: DailyUsage) throws {
        try lock.withLock { try check(); usageByDay[Self.dayKey(usage.date)] = usage }
    }

    public func loadSessionWindow() throws -> SessionWindow? {
        try lock.withLock { try check(); return window }
    }
    public func save(_ window: SessionWindow) throws {
        try lock.withLock { try check(); self.window = window }
    }
    public func clearSessionWindow() throws {
        try lock.withLock { try check(); window = nil }
    }

    public func loadProtectionState() throws -> ProtectionState {
        try lock.withLock { try check(); return protection }
    }
    public func save(_ state: ProtectionState) throws {
        try lock.withLock { try check(); protection = state }
    }

    public func eraseAll() throws {
        try lock.withLock {
            try check()
            profile = nil; configuration = nil; usageByDay = [:]; window = nil; protection = .unshielded
        }
    }

    // MARK: Test controls

    /// Simulate the shared container being unreachable (docs/BLOCKERS.md B-002).
    public func setFailing(_ failing: Bool) { lock.withLock { _failing = failing } }

    /// Calendar-day bucket so "today's usage" survives sub-day timestamps.
    static func dayKey(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
