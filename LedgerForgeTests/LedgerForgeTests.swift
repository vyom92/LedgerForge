//
//  LedgerForgeTests.swift
//  LedgerForgeTests
//
//  Created by Vyom on 03/07/26.
//

import Testing
import Foundation
@testable import LedgerForge

@MainActor
struct LedgerForgeTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    @Test func ordinaryNavigationContainsOnlyCurrentV1Destinations() {
        #expect(AppShellSection.ordinaryNavigation == [
            .dashboard,
            .accounts,
            .transactions,
            .imports,
            .salary,
            .settings
        ])
        #expect(AppShellSection.ordinaryNavigation.map(\.rawValue) == [
            "Dashboard",
            "Accounts",
            "Transactions",
            "Import",
            "Salary",
            "Settings"
        ])
        #expect(!AppShellSection.ordinaryNavigation.contains(.developer))
        #expect(!AppShellSection.developerConsoleVisible(developerModeEnabled: false))
#if DEBUG
        #expect(AppShellSection.developerConsoleVisible(developerModeEnabled: true))
#else
        #expect(!AppShellSection.developerConsoleVisible(developerModeEnabled: true))
#endif
    }

    @Test func importPresentationMappingsKeepValidationAndFooterTruthful() throws {
        let prepared = try sprint68APreparedImport(fileName: "prepared.csv", validationPassed: true)
        let validationFailed = try sprint68APreparedImport(fileName: "invalid.csv", validationPassed: false)
        let successfulOutcome = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "completed.csv",
                transactionCount: 1,
                validationPassed: true,
                persisted: true,
                errorMessage: nil
            )
        )
        let unavailableOutcome = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "unavailable.csv",
                transactionCount: 0,
                validationPassed: false,
                persisted: false,
                errorMessage: "Import validation failed."
            )
        )

        #expect(ValidationReviewPresentation.presentation(for: .idle).kind == .noStatementPrepared)
        #expect(ValidationReviewPresentation.presentation(for: .preparing(fileName: "opening.csv", phase: .openingSource)).kind == .noStatementPrepared)
        #expect(ValidationReviewPresentation.presentation(for: .previewReady(prepared)).kind == .validationResults)
        #expect(ValidationReviewPresentation.presentation(for: .validationFailed(validationFailed)).kind == .validationResults)
        #expect(ValidationReviewPresentation.presentation(for: .committing(prepared)).kind == .validationResults)
        #expect(ValidationReviewPresentation.presentation(for: .completed(successfulOutcome)).kind == .noStatementPrepared)

        #expect(ImportFooterPresentation.presentation(for: .previewReady(prepared)).kind == .confirmation)
        #expect(ImportFooterPresentation.presentation(for: .validationFailed(validationFailed)).kind == .none)
        #expect(ImportFooterPresentation.presentation(for: .committing(prepared)).kind == .importing)
        #expect(ImportFooterPresentation.presentation(for: .failed(fileName: "retry.csv", message: "Read failed", retrySourceURL: URL(fileURLWithPath: "/tmp/retry.csv"))).kind == .retryPreparation)
        #expect(ImportFooterPresentation.presentation(for: .failed(fileName: "not-retryable.csv", message: "Unsupported", retrySourceURL: nil)).kind == .none)
        #expect(ImportFooterPresentation.presentation(for: .completed(successfulOutcome)).kind == .viewTransactions)
        #expect(ImportFooterPresentation.presentation(for: .completed(unavailableOutcome)).kind == .none)
        #expect(ImportFooterPresentation.presentation(for: .cancelled(fileName: "cancelled.csv")).kind == .none)
    }

    @Test func residualContentViewAffordancesAreAbsentFromTheirLocalPresentationSections() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("ContentView.swift"),
            encoding: .utf8
        )

        let sidebar = try sprint68AContentViewSection(
            source,
            startingAt: "private var sidebar: some View",
            endingBefore: "private var contextualToolbar: some View"
        )
        #expect(!sidebar.contains("chevron.down"))
        #expect(!sidebar.contains("Menu("))

        let dashboardAccounts = try sprint68AContentViewSection(
            source,
            startingAt: "private var dashboardAccountsCard: some View",
            endingBefore: "private var importActivityCard: some View"
        )
        #expect(!dashboardAccounts.contains("Image(systemName: \"chevron.right\")"))
        #expect(dashboardAccounts.contains("linkButton(\"View all\")"))

        let accountDetail = try sprint68AContentViewSection(
            source,
            startingAt: "private var accountDetailPanel: some View",
            endingBefore: "private var importStepper: some View"
        )
        #expect(!accountDetail.contains("Image(systemName: \"star\")"))
        #expect(accountDetail.contains("Edit display name"))

        let footer = try sprint68AContentViewSection(
            source,
            startingAt: "private var importFooterAction: some View",
            endingBefore: "private var validationReviewPanel: some View"
        )
        #expect(footer.contains("ImportFooterPresentation.presentation(for: importState)"))
        #expect(footer.contains("Retry Preparation"))
        #expect(footer.contains("View Transactions"))
        #expect(!footer.contains("Awaiting confirmation"))
        #expect(!footer.contains("importFooterPendingAction"))

        let validationReview = try sprint68AContentViewSection(
            source,
            startingAt: "private var validationReviewPanel: some View",
            endingBefore: "private func settingsToggleRow"
        )
        #expect(validationReview.contains("No statement prepared"))
        #expect(validationReview.contains("Choose a statement file to see validation results."))
        for removedRow in ["File Password", "Date Format", "Duplicate Handling", "Create / Link Accounts", "Pending"] {
            #expect(!validationReview.contains(removedRow))
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func developmentDatabaseResetSwapsToFreshProviderAndHydratesEmptyRuntimeState() throws {
        resetSprint30RuntimeState()
        defer {
            resetSprint30RuntimeState()
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            UserDefaults.standard.removeObject(forKey: "Sprint30PreferencePreservation")
        }

        let folder = try sprint30TemporaryFolder(named: "Reset")
        defer {
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            try? FileManager.default.removeItem(at: folder)
        }

        let originalPath = folder.appendingPathComponent("original.sqlite").path
        #expect(LedgerForgeApp.configurePersistence(path: originalPath))
        try seedSprint30Repository(DatabaseProvider.shared)

        let initialHydration = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
        #expect(initialHydration.accountCount == 1)
        #expect(initialHydration.transactionCount == 1)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == 1)

        UserDefaults.standard.set("preserved", forKey: "Sprint30PreferencePreservation")
        let lifecycleResult = LedgerForgeApp.startTemporaryEmptySession()
        guard case .temporarySessionStarted(let resetHydration) = lifecycleResult else {
            Issue.record("Expected a temporary empty session, received \(lifecycleResult)")
            return
        }

        #expect(resetHydration.didHydrate)
        #expect(resetHydration.accountCount == 0)
        #expect(resetHydration.transactionCount == 0)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: sprint30WorkspaceId).isEmpty)
        #expect(try DatabaseProvider.shared.transactionRepo.trustedTransactions(workspaceId: sprint30WorkspaceId).isEmpty)
        #expect(FileManager.default.fileExists(atPath: originalPath))
        #expect(UserDefaults.standard.string(forKey: "Sprint30PreferencePreservation") == "preserved")

        let reloadAfterReset = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
        #expect(reloadAfterReset.accountCount == 0)
        #expect(reloadAfterReset.transactionCount == 0)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
    }

    @Test(.globalRuntimeStateIsolation)
    func canonicalReloadDataRefreshesRuntimeCountsFromRepositoryState() throws {
        resetSprint30RuntimeState()
        defer {
            resetSprint30RuntimeState()
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
        }

        let folder = try sprint30TemporaryFolder(named: "Reload")
        defer {
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            try? FileManager.default.removeItem(at: folder)
        }

        #expect(LedgerForgeApp.configurePersistence(path: folder.appendingPathComponent("reload.sqlite").path))
        try seedSprint30Repository(DatabaseProvider.shared)

        let result = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)

        #expect(result.accountCount == 1)
        #expect(result.transactionCount == 1)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func runtimeInspectorAndRepositorySummaryUseRuntimeStoreCounts() {
        resetSprint30RuntimeState()
        defer {
            resetSprint30RuntimeState()
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
            Transaction(
                statementDate: try! StatementDate(canonical: "2027-03-13"),
                description: "Runtime credit",
                debit: nil,
                credit: 100,
                amount: 100,
                balance: 100,
                currency: "INR",
                account: "Axis NRE",
                sourceBank: "Axis Bank",
                sourceFile: "fixture.csv"
            )
        ])

        let snapshot = DeveloperConsole.runtimeSnapshot(
            persistenceState: .verifiedSQLite,
            hydrationStatus: "Forced refresh completed",
            latestRefreshResult: "1 account(s), 1 transaction(s)"
        )

        #expect(snapshot.accountCount == 1)
        #expect(snapshot.transactionCount == 1)
        #expect(snapshot.persistenceState == .verifiedSQLite)
        #expect(snapshot.persistenceState.displayName == "Verified SQLite")
        #expect(snapshot.persistenceState.recoveryGuidance == nil)
    }

    @Test func logSearchCopyAndClearUseStructuredDiagnosticEntries() async {
        let baseDate = Date(timeIntervalSince1970: 1_804_896_000)
        let entries = [
            DeveloperLogEntry(
                id: 1,
                sequence: 1,
                timestamp: baseDate,
                level: .info,
                category: .`import`,
                message: "Import completed",
                metadata: nil
            ),
            DeveloperLogEntry(
                id: 2,
                sequence: 2,
                timestamp: baseDate.addingTimeInterval(1),
                level: .error,
                category: .runtime,
                message: "Hydration failed",
                metadata: nil
            ),
            DeveloperLogEntry(
                id: 3,
                sequence: 3,
                timestamp: baseDate.addingTimeInterval(2),
                level: .info,
                category: .runtime,
                message: "Reload Data",
                metadata: ["result": "1 account(s), 1 transaction(s)"]
            )
        ]

        var filters = DeveloperConsole.Filters()
        filters.searchText = "hydration"
        #expect(DeveloperConsole.filteredEntries(entries, using: filters).map(\.message) == ["Hydration failed"])

        filters.searchText = "data"
        #expect(DeveloperConsole.filteredEntries(entries, using: filters).count == 1)

        let text = DeveloperConsole.logText(from: entries)
        #expect(text.contains("[Info] [Import] Import completed"))
        #expect(text.contains("[Error] [Runtime] Hydration failed"))
        #expect(text.contains("[Info] [Runtime] Reload Data"))

        let console = DeveloperConsole()
        console.log("Sprint 30 clear check")
        console.clear()
        #expect(console.entries.isEmpty)
    }
}

private func sprint68APreparedImport(fileName: String, validationPassed: Bool) throws -> PreparedImport {
    let currency = try CurrencyCode("INR")
    let transaction = Transaction(
        statementDate: try StatementDate(canonical: "2026-08-01"),
        description: "Sprint 68A presentation fixture",
        debit: nil,
        credit: 1,
        amount: 1,
        balance: 1,
        currency: currency.code,
        account: "Axis",
        sourceBank: "Axis",
        sourceFile: fileName
    )
    let document = FinancialDocument(
        sourceDocument: Document(
            filename: fileName,
            url: URL(fileURLWithPath: "/tmp/\(fileName)"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 1_704_067_200)
        ),
        metadata: DocumentMetadata(institution: .axis, documentType: .bankAccount, fileFormat: .csv, confidence: 1),
        parserName: "Sprint 68A Presentation Parser",
        bookedCurrency: currency,
        transactions: [transaction]
    )
    let validation = ImportValidationResult(
        rowsRead: 1,
        transactionsParsed: 1,
        statementCurrency: currency,
        debitTotalMoney: nil,
        creditTotalMoney: try Money(amount: 1, currency: currency),
        openingBalanceMoney: nil,
        closingBalanceMoney: nil,
        passed: validationPassed,
        issues: []
    )
    return PreparedImport(
        sourceURL: document.sourceDocument.url,
        rawContents: "date,amount",
        fileName: fileName,
        detectedInstitution: .axis,
        detectedDocumentType: .bankAccount,
        parserName: document.parserName,
        financialDocument: document,
        validation: validation,
        importSession: ImportSession(fileName: fileName, parserName: document.parserName, transactionCount: 1, validation: validation)
    )
}

private func sprint68AContentViewSection(
    _ source: String,
    startingAt startMarker: String,
    endingBefore endMarker: String
) throws -> String {
    let start = try #require(source.range(of: startMarker))
    let trailing = source[start.lowerBound...]
    let end = try #require(trailing.range(of: endMarker))
    return String(trailing[..<end.lowerBound])
}

private let sprint30WorkspaceId = "default-workspace"

@MainActor
private func resetSprint30RuntimeState() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
    DevelopmentDatabaseActivityGate.shared.resetForTesting()
}

private func sprint30TemporaryFolder(named name: String) throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForgeSprint30Tests")
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

private func seedSprint30Repository(_ provider: DatabaseProvider) throws {
    let workspace = WorkspaceDTO(
        id: sprint30WorkspaceId,
        name: "Sprint 30 Workspace",
        createdAtISO: "2026-07-12T00:00:00Z"
    )
    let account = AccountDTO(
        id: "account-sprint-30",
        workspaceId: workspace.id,
        name: "Axis NRE",
        institutionId: "Axis Bank",
        accountType: "bank",
        nativeCurrency: "INR",
        description: "Sprint 30 account",
        createdAtISO: "2026-07-12T00:01:00Z"
    )
    let session = ImportSessionDTO(
        id: "import-sprint-30",
        workspaceId: workspace.id,
        userVisibleName: "Sprint 30 Import",
        startedAtISO: "2026-07-12T00:02:00Z",
        validationStatus: "passed",
        readerVersion: nil,
        parserVersion: "Axis Bank Account",
        layoutVersion: nil
    )
    let transaction = TransactionDTO(
        id: "transaction-sprint-30",
        workspaceId: workspace.id,
        accountId: nil,
        importSessionId: nil,
        postedDateISO: "2026-07-12",
        description: "Sprint 30 credit",
        nativeCurrency: "INR",
        amountMinor: 100_00,
        amountDecimal: "100.00",
        direction: "credit",
        runningBalanceMinor: 100_00,
        isTrusted: true,
        trustedAtISO: "2026-07-12T00:04:00Z",
        createdAtISO: "2026-07-12T00:03:00Z",
        rawRows: [
            TransactionRawRowDTO(
                id: "transaction-raw-sprint-30",
                normalizedRowId: "normalized-row-sprint-30",
                contributionType: "transaction"
            )
        ]
    )
    let sprint30FingerprintDigest = "462be1cd5a1e7d6cd8386ca159cbd844a4f4c0047dd35f0b0df4c4a2750c42c2"
    let document = ImportedDocumentDTO(
        id: "document-sprint-30",
        workspaceId: workspace.id,
        importSessionId: session.id,
        filename: "sprint-30.csv",
        mimeType: nil,
        sizeBytes: nil,
        sha256: sprint30FingerprintDigest,
        createdAtISO: "2026-07-12T00:03:00Z"
    )
    let fingerprint = DocumentFingerprintDTO(
        id: "fingerprint-sprint-30",
        documentId: document.id,
        importSessionId: session.id,
        algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm,
        fingerprint: sprint30FingerprintDigest,
        fingerprintData: nil,
        isDuplicateAuthority: true,
        createdAtISO: "2026-07-12T00:03:00Z"
    )
    let normalizedDocument = NormalizedDocumentDTO(
        id: "normalized-document-sprint-30",
        importSessionId: session.id,
        documentId: document.id,
        profileId: "test.sprint30",
        profileVersion: "1"
    )
    let normalizedRow = NormalizedRowDTO(
        id: "normalized-row-sprint-30",
        normalizedDocumentId: normalizedDocument.id,
        sourceOrdinal: 1,
        digest: String.normalizedRecordDigest(values: ["sprint-30"])
    )
    let attempt = ImportAttemptDTO(
        id: "attempt-sprint-30",
        workspaceId: workspace.id,
        createdAtISO: "2026-07-12T00:04:00Z",
        outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
        coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
        accountDecisionCode: ImportAttemptAccountDecision.resolvedOrCreated.rawValue,
        guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
        persistenceCode: ImportAttemptPersistence.committed.rawValue,
        transactionCount: 1,
        accountId: account.id,
        importSessionId: session.id,
        documentId: document.id
    )
    let plan = ConfirmedImportPlanDTO(
        providerGeneration: provider.generationToken,
        workspace: workspace,
        proposedAccount: account,
        accountChoice: .createProposedAccount,
        advisoryIdentity: .noMatch,
        identifiers: [],
        historyTemplate: ConfirmedImportHistoryTemplateDTO(
            document: document,
            fingerprint: fingerprint,
            importSession: session,
            completedAtISO: "2026-07-12T00:04:00Z",
            successfulAttempt: attempt,
            normalizedDocument: normalizedDocument,
            normalizedRows: [normalizedRow]
        ),
        transactionTemplates: [ConfirmedImportTransactionTemplateDTO(transaction: transaction)]
    )
    guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
        Issue.record("Sprint 30 test fixture failed to create its confirmed trusted graph.")
        return
    }
}
