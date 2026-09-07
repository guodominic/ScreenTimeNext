//  FileStorageService.swift
//  ScreenTimeNextCore
//
//  Task 006. The real ScreenTimeStorageService: one JSON file per record in a directory.
//
//  Phase 0 (D-007): the directory is the app's own Application Support folder.
//  Phase 1: the directory is the App Group container, so the DeviceActivityMonitor extension
//  reads and writes the same files (PRD §13, §14). Same class, different `directory` —
//  that switch is `ServiceContainer`'s job, nobody else's.
//
//  Guarantees:
//  - writes are atomic (a crash mid-write never leaves a half file)
//  - a missing or corrupt file degrades to defaults / nil, never a crash (Task 006 DoD)
//  - a schema manifest is kept so a future model change can migrate instead of silently
//    destroying a parent's configuration
//  - concurrent access is serialized; the extension and the app may both open the directory

import Foundation

public final class FileStorageService: ScreenTimeStorageService, @unchecked Sendable {

    // MARK: Construction

    public let directory: URL
    private let lock = NSLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Opens (creating if needed) a storage directory and brings its schema manifest up to date.
    public init(directory: URL) throws {
        self.directory = directory
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw ScreenTimeStorageError.containerUnavailable
        }
        try migrateIfNeeded()
    }

    /// Phase 0: the app's own sandbox. Not visible to any extension.
    public static func appContainer(fileManager: FileManager = .default) throws -> FileStorageService {
        guard let base = try? fileManager.url(for: .applicationSupportDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: true) else {
            throw ScreenTimeStorageError.containerUnavailable
        }
        return try FileStorageService(directory: base.appendingPathComponent("ScreenTimeNext", isDirectory: true))
    }

    /// Phase 1: the App Group container shared with the extension. Returns nil when the
    /// App Groups capability is absent (free account, D-007 / B-002) — callers fall back.
    public static func appGroup(identifier: String = AppGroup.identifier,
                                fileManager: FileManager = .default) -> FileStorageService? {
        guard let base = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            return nil
        }
        return try? FileStorageService(directory: base.appendingPathComponent("ScreenTimeNext", isDirectory: true))
    }

    /// D-023 — the container the app actually runs on, now that the paid membership exists.
    ///
    /// Prefers the App Group, because that is the only directory the DeviceActivityMonitor and
    /// Shield extensions can read. Falls back to the app's own container when the group cannot be
    /// resolved — a build without the entitlement, or a device where provisioning has not caught
    /// up — so a signing problem degrades to "the extensions see nothing" rather than a crash on
    /// launch.
    ///
    /// It also MIGRATES: a parent who has been using the Phase 0 build has their configuration in
    /// the app container, and switching directories without moving it would look exactly like a
    /// factory reset. The copy happens once, only into an empty group container, and never deletes
    /// the originals — if anything goes wrong the old data is still there.
    public static func shared(fileManager: FileManager = .default) throws -> FileStorageService {
        let local = try appContainer(fileManager: fileManager)
        guard let group = appGroup(fileManager: fileManager) else { return local }
        group.adoptRecords(from: local, fileManager: fileManager)
        return group
    }

    /// Copy every record from `other` into this (empty) directory. No-op if anything is already
    /// here, so a later launch can never overwrite newer shared data with a stale local copy.
    func adoptRecords(from other: FileStorageService, fileManager: FileManager) {
        lock.withLock {
            let alreadyPopulated = File.allCases.contains { file in
                file != .manifest && fileManager.fileExists(atPath: url(file).path)
            }
            guard !alreadyPopulated else { return }
            for file in File.allCases where file != .manifest {
                let source = other.directory.appendingPathComponent(file.rawValue)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                try? fileManager.copyItem(at: source, to: url(file))
            }
        }
    }

    // MARK: Files

    private enum File: String, CaseIterable {
        case manifest = "manifest.json"
        case childProfile = "childProfile.json"
        case configuration = "configuration.json"
        case dailyUsage = "dailyUsage.json"
        case sessionWindow = "sessionWindow.json"
        case protectionState = "protectionState.json"
        case pickerPreferences = "pickerPreferences.json"
        case parentPIN = "parentPIN.json"
    }

    private struct Manifest: Codable {
        var schemaVersion: Int
    }

    /// Keep this many days of usage; older days are pruned on write.
    static let usageRetentionDays = 14

    private func url(_ file: File) -> URL {
        directory.appendingPathComponent(file.rawValue)
    }

    // MARK: Read / write primitives (call with the lock held)

    private func read<T: Decodable>(_ type: T.Type, from file: File) -> T? {
        guard let data = try? Data(contentsOf: url(file)) else { return nil }
        // A file we cannot decode is treated as absent (PRD: never crash, never invent data).
        return try? decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to file: File) throws {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw ScreenTimeStorageError.encodingFailed
        }
        do {
            try data.write(to: url(file), options: [.atomic])
        } catch {
            throw ScreenTimeStorageError.containerUnavailable
        }
    }

    private func remove(_ file: File) {
        try? FileManager.default.removeItem(at: url(file))
    }

    // MARK: Schema

    private func migrateIfNeeded() throws {
        try lock.withLock {
            let current = AppGroup.currentSchemaVersion
            let stored = read(Manifest.self, from: .manifest)?.schemaVersion
            switch stored {
            case nil:
                // Fresh store (or manifest lost): stamp it.
                try write(Manifest(schemaVersion: current), to: .manifest)
            case let v? where v < current:
                // Future migrations go here, in order, each bumping the manifest.
                try write(Manifest(schemaVersion: current), to: .manifest)
            case let v? where v > current:
                // Written by a newer build. Read best-effort (JSON ignores unknown keys);
                // do not rewrite the manifest downward.
                break
            default:
                break
            }
        }
    }

    public var schemaVersion: Int {
        lock.withLock { read(Manifest.self, from: .manifest)?.schemaVersion ?? 0 }
    }

    // MARK: ScreenTimeStorageService

    public func loadChildProfile() throws -> ChildProfile? {
        lock.withLock { read(ChildProfile.self, from: .childProfile) }
    }

    public func save(_ profile: ChildProfile) throws {
        try lock.withLock { try write(profile, to: .childProfile) }
    }

    public func loadConfiguration() throws -> ScreenTimeConfiguration {
        lock.withLock { read(ScreenTimeConfiguration.self, from: .configuration) ?? .default }
    }

    public func save(_ configuration: ScreenTimeConfiguration) throws {
        try lock.withLock { try write(configuration, to: .configuration) }
    }

    public func hasStoredConfiguration() throws -> Bool {
        lock.withLock { read(ScreenTimeConfiguration.self, from: .configuration) != nil }
    }

    public func loadDailyUsage(for date: Date) throws -> DailyUsage? {
        lock.withLock {
            let table = read([String: DailyUsage].self, from: .dailyUsage) ?? [:]
            return table[Self.dayKey(date)]
        }
    }

    public func save(_ usage: DailyUsage) throws {
        try lock.withLock {
            var table = read([String: DailyUsage].self, from: .dailyUsage) ?? [:]
            table[Self.dayKey(usage.date)] = usage
            // Prune anything older than the retention window (keys sort lexically = chronologically).
            let cutoff = Self.dayKey(Calendar.current.date(byAdding: .day, value: -Self.usageRetentionDays, to: usage.date) ?? usage.date)
            table = table.filter { $0.key >= cutoff }
            try write(table, to: .dailyUsage)
        }
    }

    public func loadSessionWindow() throws -> SessionWindow? {
        lock.withLock { read(SessionWindow.self, from: .sessionWindow) }
    }

    public func save(_ window: SessionWindow) throws {
        try lock.withLock { try write(window, to: .sessionWindow) }
    }

    public func clearSessionWindow() throws {
        lock.withLock { remove(.sessionWindow) }
    }

    public func loadProtectionState() throws -> ProtectionState {
        lock.withLock { read(ProtectionState.self, from: .protectionState) ?? .unshielded }
    }

    public func save(_ state: ProtectionState) throws {
        try lock.withLock { try write(state, to: .protectionState) }
    }

    /// D-024 / D-054 — `pickerPreferences` AND `parentPIN` are absent from this list on purpose.
    /// "Start over" erases the child's setup, not the parent's own things.
    ///
    /// The PIN used to be erased here (D-031, "start over means start over"). That was wrong, and
    /// it showed up as a real complaint: D-036 demands a PIN before the timer opens, so every Start
    /// over made a parent set one again. A PIN is not part of a child's configuration — it is the
    /// parent's own credential, the same kind of thing as the picker arrangement beside it, and
    /// changing it is one row in Settings for anyone who actually wants to.
    public func eraseAll() throws {
        lock.withLock {
            for file in [File.childProfile, .configuration, .dailyUsage, .sessionWindow, .protectionState] {
                remove(file)
            }
        }
    }

    public func loadParentPIN() throws -> ParentPIN? {
        lock.withLock { read(ParentPIN.self, from: .parentPIN) }
    }

    public func save(_ pin: ParentPIN?) throws {
        try lock.withLock {
            if let pin { try write(pin, to: .parentPIN) } else { remove(.parentPIN) }
        }
    }

    public func loadPickerPreferences() throws -> ParentPickerPreferences {
        lock.withLock { read(ParentPickerPreferences.self, from: .pickerPreferences) ?? .default }
    }

    public func save(_ preferences: ParentPickerPreferences) throws {
        try lock.withLock { try write(preferences, to: .pickerPreferences) }
    }

    // MARK: Helpers

    /// Local-calendar day key, e.g. "2026-09-05". Lexical order == chronological order.
    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
