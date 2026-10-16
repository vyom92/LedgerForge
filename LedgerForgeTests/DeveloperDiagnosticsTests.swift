//
//  DeveloperDiagnosticsTests.swift
//  LedgerForge
//
//  Created by Vyom on 12/07/26.
//


// LedgerForgeTests/DeveloperDiagnosticsTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
@Suite("Developer Diagnostics & Logging")
struct DeveloperDiagnosticsTests {

    @Test("Structured entry fields are assigned and deterministic")
    func structuredEntryFields() async throws {
        let console = DeveloperConsole()

        console.debug(.parser, "Detected delimiter", metadata: ["delimiter": ","])

        #expect(console.entries.count == 1)
        #expect(console.entries.first != nil, "No entry recorded")
        guard let first = console.entries.first else { return }
        #expect(first.id == 1)
        #expect(first.sequence == 1)
        #expect(first.level == .debug)
        #expect(first.category == .parser)
        #expect(first.message == "Detected delimiter")
        #expect(first.metadata?["delimiter"] == nil)
        let now = Date()
        #expect(first.timestamp <= now)
    }

    @Test("Debug hidden by default; filters reveal debug when requested")
    func levelFilteringAndDebugDefaultHidden() async throws {
        let console = DeveloperConsole()

        console.debug(.parser, "Row count", metadata: ["rows": "10"]) // Debug
        console.info(.`import`, "Import started") // Info

        var filters = DeveloperConsole.Filters() // defaults: all levels, debug hidden
        let defaultVisible = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(defaultVisible.count == 1)
        #expect(defaultVisible.first?.level == .info)

        filters.level = .exact(.debug)
        let onlyDebug = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(onlyDebug.count == 1)
        #expect(onlyDebug.first?.level == .debug)

        filters.level = .all
        filters.includeDebugInAll = true
        let allWithDebug = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(allWithDebug.count == 2)
    }

    @Test("Category filtering returns only matching entries")
    func categoryFiltering() async throws {
        let console = DeveloperConsole()

        console.info(.runtime, "Runtime refresh completed")
        console.info(.database, "Repository persistence completed")
        console.info(.application, "Ready")

        var filters = DeveloperConsole.Filters()
        filters.category = .exact(.database)
        let onlyDatabase = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(onlyDatabase.count == 1)
        #expect(onlyDatabase.first?.category == .database)

        filters.category = .all
        let allAgain = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(allAgain.count == 3)
    }

    @Test("Search is case-insensitive and applies after filters")
    func searchCaseInsensitive() async throws {
        let console = DeveloperConsole()

        console.info(.`import`, "Import started", metadata: ["code": "import.started"])
        console.info(.`import`, "Import completed", metadata: ["code": "import.started"])
        console.warning(.validation, "Ignored rows", metadata: ["count": "2"])

        var filters = DeveloperConsole.Filters()
        filters.level = .all
        filters.includeDebugInAll = true
        filters.category = .exact(.`import`)
        filters.searchText = "import.started"

        let results = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(results.count == 2)

        filters.searchText = "IGNORED"
        let results2 = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(results2.isEmpty) // because category filter excludes validation

        filters.category = .all
        let results3 = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(results3.count == 1)
        #expect(results3.first?.level == .warning)
    }

    @Test("Combined filters and clearing filter values do not mutate stored history")
    func combinedFiltersAndClearingDoNotMutateHistory() async throws {
        let console = DeveloperConsole()

        console.debug(.parser, "Normalization details")
        console.info(.`import`, "Import started")
        console.warning(.validation, "Ignored rows")
        console.error(.database, "Repository persistence failed")

        #expect(console.entries.map(\.level) == [.debug, .info, .warning, .error])
        #expect(console.entries.map(\.category) == [.parser, .`import`, .validation, .database])
        let storedSequences = console.entries.map(\.sequence)

        var filters = DeveloperConsole.Filters()
        filters.level = .exact(.warning)
        filters.category = .exact(.validation)
        filters.searchText = "ignored"
        let combined = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(combined.map(\.message) == ["Ignored rows"])

        filters = DeveloperConsole.Filters()
        let defaultVisible = DeveloperConsole.filteredEntries(console.entries, using: filters)
        #expect(defaultVisible.map(\.message) == ["Import started", "Ignored rows", "Repository persistence failed"])
        #expect(console.entries.map(\.sequence) == storedSequences)
    }

    @Test("Copy All is independent of active filters and preserves chronological order")
    func copyAllIgnoresPresentationFilters() async throws {
        let console = DeveloperConsole()
        console.debug(.parser, "Detected delimiter", metadata: ["delimiter": ","])
        console.info(.`import`, "Import completed")
        let entries = console.entries

        var filters = DeveloperConsole.Filters()
        filters.level = .exact(.info)
        #expect(DeveloperConsole.filteredEntries(entries, using: filters).map(\.message) == ["Import completed"])

        let copied = console.completeLogText
        #expect(copied.contains("[Debug] [Parser] Detected delimiter"))
        #expect(copied.contains("[Info] [Import] Import completed"))
        #expect((copied as NSString).range(of: "Detected delimiter").location < (copied as NSString).range(of: "Import completed").location)
    }

    @Test("Bounded diagnostic presentation excludes hostile values from visible and copied output")
    func boundedDiagnosticPresentationExcludesHostileValues() {
        let hostileSentinels = [
            "PASSWORD__sprint68__secret",
            "ACCOUNT__sprint68__identifier",
            "/private/sprint68/statement.sqlite",
            "SELECT * FROM import_sessions",
            "RAW_SOURCE__sprint68__fragment",
            "PARSER_PROFILE__sprint68__normalized"
        ]
        let hostileError = HostileDiagnosticError(errorDescription: hostileSentinels.joined(separator: " | "))
        let preparation = ImportFailureSummary.from(hostileError)
        let categoryPresentation = CategoryManagementPresentation.message(for: hostileError)
        let entries = [
            DeveloperLogEntry(
                id: 1,
                sequence: 1,
                timestamp: Date(timeIntervalSince1970: 1_804_896_000),
                level: .error,
                category: .runtime,
                message: "Dashboard hydration failed",
                metadata: ["outcome": "Unavailable"]
            ),
            DeveloperLogEntry(
                id: 2,
                sequence: 2,
                timestamp: Date(timeIntervalSince1970: 1_804_896_001),
                level: .error,
                category: .runtime,
                message: "Runtime refresh failed",
                metadata: ["outcome": "Unavailable"]
            ),
            DeveloperLogEntry(
                id: 3,
                sequence: 3,
                timestamp: Date(timeIntervalSince1970: 1_804_896_002),
                level: .error,
                category: .`import`,
                message: "Import preparation failed",
                metadata: [
                    "stage": preparation.stage.rawValue,
                    "family": preparation.family.rawValue
                ]
            ),
            DeveloperLogEntry(
                id: 4,
                sequence: 4,
                timestamp: Date(timeIntervalSince1970: 1_804_896_003),
                level: .info,
                category: .database,
                message: "Provider-owned confirmed import committed",
                metadata: ["transactions": "4", "reason": "committed"]
            )
        ]

        let visibleText = entries.map {
            [$0.message, DeveloperConsole.metadataText(for: $0) ?? ""]
                .joined(separator: " ")
        }.joined(separator: "\n")
        let copiedText = DeveloperConsole.logText(from: entries)

        for sentinel in hostileSentinels {
            #expect(!preparation.displayText.contains(sentinel))
            #expect(!categoryPresentation.contains(sentinel))
            #expect(!visibleText.contains(sentinel))
            #expect(!copiedText.contains(sentinel))
        }
        #expect(categoryPresentation == "The category action could not be completed.")
        #expect(visibleText.contains("Unavailable"))
        #expect(visibleText.contains("stage: Preparation"))
        #expect(visibleText.contains("Unknown preparation failure"))
        #expect(visibleText.contains("transactions: 4"))
        #expect(visibleText.contains("reason: committed"))
    }

    @Test("Retained history is capped at 1,000 chronological entries")
    func retainedHistoryBound() {
        let console = DeveloperConsole()

        for index in 1...1_002 {
            console.info(.application, "Entry \(index)")
        }

        #expect(console.entries.count == 1_000)
        #expect(console.entries.first?.sequence == 3)
        #expect(console.entries.first?.message == "Entry 3")
        #expect(console.entries.last?.sequence == 1_002)
        #expect(console.entries.last?.message == "Entry 1002")
        #expect(console.entries.map(\.sequence) == Array(3...1_002))

        console.clear()
        #expect(console.entries.isEmpty)
        console.info(.application, "After clear")
        #expect(console.entries.first?.sequence == 1_003)
    }

    @Test("Clear removes diagnostics without mutating account metadata", .globalRuntimeStateIsolation)
    func clearLeavesRuntimeStoresUnchanged() async throws {
        let console = DeveloperConsole()
        resetDiagnosticRuntimeStores()
        defer {
            resetDiagnosticRuntimeStores()
            console._resetForTests()
        }

        AccountStore.shared.replaceAccounts([
            Account(
                institution: "Axis Bank",
                name: "Axis NRE",
                type: .bank,
                currencyCode: "INR",
                currentBalance: 100,
                includeInNetWorth: true
            )
        ])
        console.info(.application, "Before clear")
        console.clear()

        #expect(console.entries.isEmpty)
        #expect(AccountStore.shared.accounts.count == 1)
    }

    @Test("Newest-first presentation helper reverses without renumbering")
    func newestFirstPresentation() async throws {
        let console = DeveloperConsole()

        console.info(.application, "First")
        console.info(.application, "Second")

        let reversed = DeveloperConsole.newestFirst(console.entries)
        #expect(reversed.map { $0.sequence } == [2, 1])
        #expect(console.entries.map { $0.sequence } == [1, 2]) // stored order unchanged
    }

    @Test("Successful import emits concise lifecycle entries and bounded parser diagnostics", .globalRuntimeStateIsolation)
    func successfulImportLifecycleDiagnostics() async throws {
        let console = DeveloperConsole()
        resetDiagnosticRuntimeStores()
        defer {
            resetDiagnosticRuntimeStores()
            console._resetForTests()
        }

        let persistence = DiagnosticPersistenceCoordinator()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            developerConsole: console,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            forcedHydration: { RepositoryStoreHydrationResult(didHydrate: true, accountCount: 0, transactionCount: 0) }
        )
        let result = await engine.importFileAndReturnResult(
            from: try MechanicsTestSupport.axisBankCSV()
        )

        #expect(result.succeeded)
        let fingerprint = try #require(persistence.capturedFingerprint)
        #expect(fingerprint.algorithm == ExactStatementFingerprint.algorithm)
        #expect(fingerprint.digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil)

        let defaultVisible = DeveloperConsole.filteredEntries(console.entries, using: DeveloperConsole.Filters())
        #expect(defaultVisible.map(\.message) == [
            "Import started",
            "Institution detected",
            "Parser selected",
            "Validation completed",
            "Repository persistence completed",
            "Import completed"
        ])
        #expect(defaultVisible.allSatisfy { $0.level != .debug })

        var debugFilter = DeveloperConsole.Filters()
        debugFilter.level = .exact(.debug)
        let debugMessages = DeveloperConsole.filteredEntries(console.entries, using: debugFilter).map(\.message)
        #expect(debugMessages.contains("Document structure recognized"))
        #expect(debugMessages.contains("Normalization completed"))
        #expect(debugMessages.contains("Row count"))
        #expect(!debugMessages.contains("Detected document"))
        #expect(!debugMessages.contains("Normalization details"))

        let parserSelection = try #require(console.entries.first { $0.message == "Parser selected" })
        #expect(parserSelection.metadata?["selection"] == "Recognized")
        let parserMetadata = console.entries
            .filter { $0.category == .parser }
            .compactMap(\.metadata)
        #expect(parserMetadata.allSatisfy {
            $0["delimiter"] == nil && $0["encoding"] == nil && $0["normalizedRows"] == nil
        })

        let lifecycleSequences = defaultVisible.map(\.sequence)
        #expect(lifecycleSequences == lifecycleSequences.sorted())
    }

    @Test("Failed import emits started, failure detail and terminal failure", .globalRuntimeStateIsolation)
    func failedImportLifecycleDiagnostics() async throws {
        let console = DeveloperConsole()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForgeDiagnostics")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
            console._resetForTests()
        }

        let persistence = DiagnosticPersistenceCoordinator()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            developerConsole: console,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) }
        )
        let result = await engine.importFileAndReturnResult(from: url)

        #expect(!result.succeeded)
        let visible = DeveloperConsole.filteredEntries(console.entries, using: DeveloperConsole.Filters())
        #expect(visible.map(\.message) == [
            "Import started",
            "Imported document is empty.",
            "Import failed"
        ])
        #expect(visible.map(\.level) == [.info, .error, .error])
    }

}

private final class DiagnosticPersistenceCoordinator: ImportPersistenceCoordinating {
    private(set) var capturedFingerprint: ExactStatementFingerprint?

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        throw ImportPersistenceCoordinationError.fingerprintRequired
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        nil
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        capturedFingerprint = fingerprint
        return ImportPersistenceResult(
            persisted: validation.passed,
            workspaceId: validation.passed ? "workspace-diagnostics" : nil,
            accountId: validation.passed ? "account-diagnostics" : nil,
            importSessionId: validation.passed ? importSession.id.uuidString : nil,
            transactionCount: validation.passed ? financialDocument.transactions.count : 0
        )
    }
}

@MainActor
private func resetDiagnosticRuntimeStores() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
}

private struct HostileDiagnosticError: LocalizedError {
    let errorDescription: String?
}
