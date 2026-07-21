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
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            developerConsole: console,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) }
        )
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

    @Test("Selected source filename is absent from successful and parser-failure diagnostics")
    func selectedSourceFilenameIsPrivateAcrossPreparationOutcomes() async throws {
        let sensitiveFileName = "Fictional_Person_000000000_Private_Statement.csv"

        let successfulURL = try copiedAxisFixture(named: sensitiveFileName)
        defer { try? FileManager.default.removeItem(at: successfulURL.deletingLastPathComponent()) }
        let successConsole = DeveloperConsole()
        let successEngine = diagnosticEngine(
            persistence: DiagnosticPersistenceCoordinator(),
            console: successConsole
        )

        let successfulResult = await successEngine.importFileAndReturnResult(from: successfulURL)

        #expect(successfulResult.succeeded)
        #expect(successfulResult.fileName == sensitiveFileName)
        expectSelectedSourceNameAbsent(
            sensitiveFileName,
            from: successConsole
        )

        let parserFailureURL = try writeDiagnosticCSV(
            named: sensitiveFileName,
            text: """
            AXIS BANK
            Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)
            Tran Date,CHQNO,PARTICULARS,DR,CR,BAL,SOL
            invalid-date,-,Recognized debit,10.00,,90.00,4437
            """
        )
        defer { try? FileManager.default.removeItem(at: parserFailureURL.deletingLastPathComponent()) }
        let failureConsole = DeveloperConsole()
        let failureEngine = diagnosticEngine(
            persistence: DiagnosticPersistenceCoordinator(),
            console: failureConsole
        )

        let failedResult = await failureEngine.importFileAndReturnResult(from: parserFailureURL)

        #expect(!failedResult.succeeded)
        #expect(failedResult.fileName == sensitiveFileName)
        expectSelectedSourceNameAbsent(
            sensitiveFileName,
            from: failureConsole
        )
    }

    @Test("Selected source filename is absent from validation, duplicate, event and persistence diagnostics")
    func selectedSourceFilenameIsPrivateAcrossCommitOutcomes() async throws {
        let sensitiveFileName = "Fictional_Person_000000000_Private_Statement.csv"

        let validationConsole = DeveloperConsole()
        let validationEngine = diagnosticEngine(
            persistence: DiagnosticPersistenceCoordinator(),
            console: validationConsole
        )
        let validationResult = await validationEngine.commitPreparedImport(
            diagnosticPreparedImport(fileName: sensitiveFileName, transactions: [])
        )
        #expect(!validationResult.validationPassed)
        expectSelectedSourceNameAbsent(sensitiveFileName, from: validationConsole)

        let scenarios: [(name: String, coordinator: DiagnosticPersistenceCoordinator)] = [
            (
                "duplicate",
                DiagnosticPersistenceCoordinator(
                    resultOverride: ImportPersistenceResult(
                        persisted: false,
                        workspaceId: nil,
                        accountId: "fictional-account",
                        importSessionId: "fictional-prior-session",
                        transactionCount: 81,
                        previousImport: PreviouslyImportedStatement(
                            importSessionId: "fictional-prior-session",
                            completedAtISO: "2026-07-21T00:00:00Z",
                            transactionCount: 81,
                            accountId: "fictional-account",
                            accountDisplayName: "Fictional Axis Account"
                        )
                    )
                )
            ),
            (
                "event",
                DiagnosticPersistenceCoordinator(
                    resultOverride: ImportPersistenceResult(
                        persisted: false,
                        workspaceId: nil,
                        accountId: nil,
                        importSessionId: nil,
                        transactionCount: 81,
                        transactionEventBlock: .existing(count: 1)
                    )
                )
            ),
            (
                "persistence",
                DiagnosticPersistenceCoordinator(
                    errorToThrow: DiagnosticPersistenceError.writeFailed(
                        fileName: sensitiveFileName
                    )
                )
            )
        ]

        for scenario in scenarios {
            let url = try copiedAxisFixture(named: sensitiveFileName)
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let console = DeveloperConsole()
            let engine = diagnosticEngine(persistence: scenario.coordinator, console: console)

            let result = await engine.importFileAndReturnResult(from: url)

            #expect(!result.succeeded, "Expected the \(scenario.name) diagnostic path.")
            #expect(result.fileName == sensitiveFileName)
            expectSelectedSourceNameAbsent(sensitiveFileName, from: console)
        }
    }
}

private final class DiagnosticPersistenceCoordinator: ImportPersistenceCoordinating {
    private(set) var capturedFingerprint: ExactStatementFingerprint?
    private let resultOverride: ImportPersistenceResult?
    private let errorToThrow: Error?

    init(
        resultOverride: ImportPersistenceResult? = nil,
        errorToThrow: Error? = nil
    ) {
        self.resultOverride = resultOverride
        self.errorToThrow = errorToThrow
    }

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
        if let errorToThrow {
            throw errorToThrow
        }
        if let resultOverride {
            return resultOverride
        }
        return ImportPersistenceResult(
            persisted: validation.passed,
            workspaceId: validation.passed ? "workspace-diagnostics" : nil,
            accountId: validation.passed ? "account-diagnostics" : nil,
            importSessionId: validation.passed ? importSession.id.uuidString : nil,
            transactionCount: validation.passed ? financialDocument.transactions.count : 0
        )
    }
}

private enum DiagnosticPersistenceError: Error, LocalizedError {
    case writeFailed(fileName: String)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let fileName):
            return "Fictional repository write failed for \(fileName)."
        }
    }
}

@MainActor
private func diagnosticEngine(
    persistence: ImportPersistenceCoordinating,
    console: DeveloperConsole
) -> ImportEngine {
    ImportEngine(
        importPersistenceCoordinator: persistence,
        developerConsole: console,
        persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
        forcedHydration: {
            RepositoryStoreHydrationResult(
                didHydrate: true,
                accountCount: 0,
                transactionCount: 0,
                importSessionCount: 0,
                importAttemptCount: 0
            )
        },
        rejectedAttemptHydration: {}
    )
}

private func copiedAxisFixture(named fileName: String) throws -> URL {
    let source = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
    return try writeDiagnosticCSV(
        named: fileName,
        data: Data(contentsOf: source)
    )
}

private func writeDiagnosticCSV(named fileName: String, text: String) throws -> URL {
    try writeDiagnosticCSV(named: fileName, data: Data(text.utf8))
}

private func writeDiagnosticCSV(named fileName: String, data: Data) throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForge-Diagnostic-Privacy-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent(fileName)
    try data.write(to: url)
    return url
}

private func expectSelectedSourceNameAbsent(
    _ fileName: String,
    from console: DeveloperConsole
) {
    for entry in console.entries {
        #expect(!entry.message.localizedCaseInsensitiveContains(fileName))
        for (key, value) in entry.metadata ?? [:] {
            #expect(!key.localizedCaseInsensitiveContains(fileName))
            #expect(!value.localizedCaseInsensitiveContains(fileName))
        }
        if let metadataPresentation = DeveloperConsole.metadataText(for: entry) {
            #expect(!metadataPresentation.localizedCaseInsensitiveContains(fileName))
        }
        #expect(!DeveloperConsole.formatForCopy(entry).localizedCaseInsensitiveContains(fileName))
    }

    var search = DeveloperConsole.Filters()
    search.includeDebugInAll = true
    search.searchText = fileName
    #expect(DeveloperConsole.filteredEntries(console.entries, using: search).isEmpty)
    #expect(!console.completeLogText.localizedCaseInsensitiveContains(fileName))
    #expect(!DeveloperConsole.logText(from: console.entries).localizedCaseInsensitiveContains(fileName))
}

private func diagnosticPreparedImport(
    fileName: String,
    transactions: [Transaction]
) -> PreparedImport {
    let sourceURL = URL(fileURLWithPath: "/tmp").appendingPathComponent(fileName)
    let financialDocument = FinancialDocument(
        sourceDocument: Document(
            filename: fileName,
            url: sourceURL,
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 1_805_587_200)
        ),
        metadata: DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: .csv,
            confidence: 1
        ),
        parserName: "Axis Bank Account",
        bookedCurrency: try! CurrencyCode("INR"),
        transactions: transactions
    )
    let validation = ImportValidator.validate(financialDocument: financialDocument)
    let session = ImportSession(
        importedAt: Date(timeIntervalSince1970: 1_805_587_200),
        fileName: fileName,
        institution: .axis,
        documentType: .bankAccount,
        parserName: financialDocument.parserName,
        transactionCount: transactions.count,
        validation: validation
    )
    return PreparedImport(
        sourceURL: sourceURL,
        rawContents: "fictional diagnostic source",
        fileName: fileName,
        detectedInstitution: .axis,
        detectedDocumentType: .bankAccount,
        parserName: financialDocument.parserName,
        financialDocument: financialDocument,
        validation: validation,
        importSession: session
    )
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
