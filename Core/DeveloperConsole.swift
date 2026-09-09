// LedgerForge
// DeveloperConsole.swift
// Version: 1.0.0 - Sprint 31 Structured Diagnostics

import Foundation
import Combine

// MARK: - Diagnostic Types

enum DeveloperLogLevel: String, CaseIterable, Codable, Equatable {
    case debug = "Debug"
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
}

enum DeveloperLogCategory: String, CaseIterable, Codable, Equatable {
    case application = "Application"
    case `import` = "Import"
    case parser = "Parser"
    case validation = "Validation"
    case database = "Database"
    case runtime = "Runtime"
}

struct DeveloperLogEntry: Identifiable, Equatable, Codable {
    // Stable unique identity equals sequence number to preserve ordering semantics
    let id: Int
    let sequence: Int
    let timestamp: Date
    let level: DeveloperLogLevel
    let category: DeveloperLogCategory
    let message: String
    let metadata: [String: String]?
}

struct DeveloperConsoleSnapshot: Equatable {
    let persistenceState: PersistenceState
    let hydrationStatus: String
    let latestRefreshResult: String
    let accountCount: Int
    let transactionCount: Int
}

// MARK: - Console

final class DeveloperConsole: ObservableObject {

    static let shared = DeveloperConsole()

    // Stored in chronological order (oldest first) to preserve historical integrity
    @Published private(set) var entries: [DeveloperLogEntry] = []

    // Sequence counter is monotonically increasing for deterministic history.
    private var nextSequence: Int = 1

    init() {}

    // MARK: - Logging API

    func log(level: DeveloperLogLevel, category: DeveloperLogCategory, message: String, metadata: [String: String]? = nil) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.appendEntry(level: level, category: category, message: message, metadata: metadata)
            }
        } else {
            DispatchQueue.main.async { @MainActor in
                self.appendEntry(level: level, category: category, message: message, metadata: metadata)
            }
        }
    }

    @MainActor
    private func appendEntry(
        level: DeveloperLogLevel,
        category: DeveloperLogCategory,
        message: String,
        metadata: [String: String]?
    ) {
        let sequence = nextSequence
        nextSequence += 1
        let entry = DeveloperLogEntry(
            id: sequence,
            sequence: sequence,
            timestamp: Date(),
            level: level,
            category: category,
            message: DiagnosticPrivacy.text(message),
            metadata: DiagnosticPrivacy.metadata(metadata)
        )
        entries.append(entry)
        if entries.count > 1000 { entries.removeFirst(entries.count - 1000) }
    }

    // Convenience helpers
    func debug(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]? = nil) {
        log(level: .debug, category: category, message: message, metadata: metadata)
    }

    func info(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]? = nil) {
        log(level: .info, category: category, message: message, metadata: metadata)
    }

    func warning(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]? = nil) {
        log(level: .warning, category: category, message: message, metadata: metadata)
    }

    func error(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]? = nil) {
        log(level: .error, category: category, message: message, metadata: metadata)
    }

    // Legacy compatibility – treat as Info/Application
    func log(_ message: String) {
        info(.application, message)
    }

    // MARK: - Utilities

    func clear() {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.clearEntries()
            }
        } else {
            DispatchQueue.main.async { @MainActor in
                self.clearEntries()
            }
        }
    }

    @MainActor
    private func clearEntries() {
        entries.removeAll()
    }

    // Copy All – complete chronological history, independent of filters
    var completeLogText: String {
        Self.logText(from: entries)
    }

    static func logText(from entries: [DeveloperLogEntry]) -> String {
        entries.sorted { $0.sequence < $1.sequence }.map { formatForCopy($0) }.joined(separator: "\n")
    }

    static func formatForCopy(_ entry: DeveloperLogEntry) -> String {
        "#\(entry.sequence) \(timestampFormatter.string(from: entry.timestamp)) [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(DiagnosticPrivacy.text(entry.message))" + (metadataText(for: entry).map { "\n" + $0 } ?? "")
    }

    static func metadataText(for entry: DeveloperLogEntry) -> String? {
        guard let metadata = DiagnosticPrivacy.metadata(entry.metadata), !metadata.isEmpty else {
            return nil
        }
        return metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    // Presentation helpers
    struct Filters: Equatable {
        var level: LevelOption = .all // UI may additionally toggle includeDebug
        var includeDebugInAll: Bool = false // Debug hidden by default
        var category: CategoryOption = .all
        var searchText: String = ""

        enum LevelOption: Equatable {
            case all
            case exact(DeveloperLogLevel)
        }
        enum CategoryOption: Equatable {
            case all
            case exact(DeveloperLogCategory)
        }
    }

    func filteredEntries(using filters: Filters) -> [DeveloperLogEntry] {
        Self.filteredEntries(entries, using: filters)
    }

    static func filteredEntries(_ entries: [DeveloperLogEntry], using filters: Filters) -> [DeveloperLogEntry] {
        // Apply level filter
        let levelFiltered: [DeveloperLogEntry] = entries.filter { entry in
            switch filters.level {
            case .all:
                return filters.includeDebugInAll ? true : (entry.level != .debug)
            case .exact(let level):
                return entry.level == level
            }
        }

        // Apply category filter
        let categoryFiltered = levelFiltered.filter { entry in
            switch filters.category {
            case .all:
                return true
            case .exact(let category):
                return entry.category == category
            }
        }

        // Apply search to message and visible metadata only.
        let query = filters.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return categoryFiltered }
        return categoryFiltered.filter { entry in
            let haystacks: [String] = [
                entry.message
            ] + [metadataText(for: entry)].compactMap { $0 }
            return haystacks.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    // Reverse chronological for display – do not mutate stored order
    static func newestFirst(_ entries: [DeveloperLogEntry]) -> [DeveloperLogEntry] {
        Array(entries.reversed())
    }

    // MARK: - Runtime Snapshot

    static func runtimeSnapshot(
        persistenceState: PersistenceState,
        hydrationStatus: String,
        latestRefreshResult: String,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared
    ) -> DeveloperConsoleSnapshot {
        DeveloperConsoleSnapshot(
            persistenceState: persistenceState,
            hydrationStatus: hydrationStatus,
            latestRefreshResult: latestRefreshResult,
            accountCount: accountStore.accounts.count,
            transactionCount: transactionStore.transactions.count
        )
    }

#if DEBUG
    @MainActor
    private func resetForTests() {
        entries.removeAll()
        nextSequence = 1
    }
#endif
}

// MARK: - Formatters

private let timestampFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'UTC'"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

#if DEBUG
extension DeveloperConsole {
    // Testing helper to reset deterministic state within tests
    @MainActor
    func _resetForTests() {
        resetForTests()
    }
}
#endif
