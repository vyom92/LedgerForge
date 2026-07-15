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
        #expect(first.metadata?["delimiter"] == ",")
        let now = Date()
        #expect(first.timestamp <= now)
    }

    @Test("Sequence numbers are unique and preserve chronological order")
    func sequenceUniquenessAndOrdering() async throws {
        let console = DeveloperConsole()

        console.info(.application, "App started")
        console.warning(.validation, "Missing optional metadata")
        console.error(.database, "Persistence failed", metadata: ["code": "SQLITE_BUSY"])

        let sequences = console.entries.map { $0.sequence }
        #expect(sequences == [1, 2, 3])
    }

    @Test("All approved levels and categories can be assigned")
    func allApprovedLevelsAndCategories() async throws {
        let console = DeveloperConsole()

        console.debug(.application, "Application debug")
        console.info(.`import`, "Import info")
        console.warning(.parser, "Parser warning")
        console.error(.validation, "Validation error")
        console.info(.database, "Database info")
        console.info(.runtime, "Runtime info")

        #expect(console.entries.map(\.level) == [.debug, .info, .warning, .error, .info, .info])
        #expect(console.entries.map(\.category) == [.application, .`import`, .parser, .validation, .database, .runtime])
        #expect(Set(DeveloperLogLevel.allCases) == Set([.debug, .info, .warning, .error]))
        #expect(Set(DeveloperLogCategory.allCases) == Set([.application, .`import`, .parser, .validation, .database, .runtime]))
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

        console.info(.`import`, "Import started", metadata: ["file": "Axis.csv"])
        console.info(.`import`, "Import completed", metadata: ["file": "Axis.csv"])
        console.warning(.validation, "Ignored rows", metadata: ["count": "2"])

        var filters = DeveloperConsole.Filters()
        filters.level = .all
        filters.includeDebugInAll = true
        filters.category = .exact(.`import`)
        filters.searchText = "axis"

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

    @Test("Copy All uses chronological order and includes essential fields")
    func copyAllChronological() async throws {
        let console = DeveloperConsole()

        console.info(.application, "First")
        console.error(.application, "Second")

        let text = console.completeLogText
        // Expect lines in chronological order "First" then "Second"
        let idxFirst = (text as NSString).range(of: "First").location
        let idxSecond = (text as NSString).range(of: "Second").location
        #expect(idxFirst != NSNotFound && idxSecond != NSNotFound && idxFirst < idxSecond)
        #expect(text.contains("[Info]"))
        #expect(text.contains("[Error]"))
        #expect(text.contains("[Application]"))
    }

    @Test("Copy All is independent of active filters")
    func copyAllIgnoresPresentationFilters() async throws {
        let entries = [
            DeveloperLogEntry(
                id: 1,
                sequence: 1,
                timestamp: Date(timeIntervalSince1970: 1_804_896_000),
                level: .debug,
                category: .parser,
                message: "Detected delimiter",
                metadata: ["delimiter": ","]
            ),
            DeveloperLogEntry(
                id: 2,
                sequence: 2,
                timestamp: Date(timeIntervalSince1970: 1_804_896_001),
                level: .info,
                category: .`import`,
                message: "Import completed",
                metadata: nil
            )
        ]

        var filters = DeveloperConsole.Filters()
        filters.level = .exact(.info)
        #expect(DeveloperConsole.filteredEntries(entries, using: filters).map(\.message) == ["Import completed"])

        let copied = DeveloperConsole.logText(from: entries)
        #expect(copied.contains("[Debug] [Parser] Detected delimiter"))
        #expect(copied.contains("[Info] [Import] Import completed"))
        #expect((copied as NSString).range(of: "Detected delimiter").location < (copied as NSString).range(of: "Import completed").location)
    }

    @Test("Clear removes all entries and resets sequence numbers")
    func clearResets() async throws {
        let console = DeveloperConsole()

        console.info(.application, "Before clear")
        #expect(console.entries.count == 1)

        console.clear()
        // Allow main-thread bounce
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(console.entries.isEmpty)

        console.info(.application, "After clear")
        #expect(console.entries.first?.sequence == 1)
    }

    @Test("Clear removes diagnostics without mutating runtime stores")
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
        TransactionStore.shared.replaceTransactions([
            diagnosticTransaction()
        ])

        console.info(.application, "Before clear")
        console.clear()

        #expect(console.entries.isEmpty)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == 1)
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

    @Test("Successful import emits concise lifecycle entries and debug parser internals")
    func successfulImportLifecycleDiagnostics() async throws {
        let console = DeveloperConsole()
        resetDiagnosticRuntimeStores()
        defer {
            resetDiagnosticRuntimeStores()
            console._resetForTests()
        }

        let persistence = DiagnosticPersistenceCoordinator()
        let engine = ImportEngine(importPersistenceCoordinator: persistence, developerConsole: console)
        let result = await engine.importFileAndReturnResult(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
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
        #expect(debugMessages.contains("Detected document"))
        #expect(debugMessages.contains("Normalization details"))
        #expect(debugMessages.contains("Row count"))

        let lifecycleSequences = defaultVisible.map(\.sequence)
        #expect(lifecycleSequences == lifecycleSequences.sorted())
    }

    @Test("Failed import emits started, failure detail and terminal failure")
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
        let engine = ImportEngine(importPersistenceCoordinator: persistence, developerConsole: console)
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

private func resetDiagnosticRuntimeStores() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
}

private func diagnosticTransaction() -> Transaction {
    Transaction(
        date: Date(timeIntervalSince1970: 1_804_896_000),
        description: "Runtime credit",
        debit: nil,
        credit: 100,
        amount: 100,
        balance: 100,
        currency: "INR",
        account: "Axis NRE",
        sourceBank: "Axis Bank",
        sourceFile: "diagnostics.csv"
    )
}
