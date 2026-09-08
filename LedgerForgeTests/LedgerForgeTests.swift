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

    @Test(.globalRuntimeStateIsolation)
    func importPresentationMappingsKeepValidationAndFooterTruthful() async throws {
        let preparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { preparedOwner.cancel() }
        let prepared = preparedOwner.preparedImport
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
        #expect(ValidationReviewPresentation.presentation(for: .validationFailed(prepared)).kind == .validationResults)
        #expect(ValidationReviewPresentation.presentation(for: .committing(prepared)).kind == .validationResults)
        #expect(ValidationReviewPresentation.presentation(for: .completed(successfulOutcome)).kind == .noStatementPrepared)

        #expect(ImportFooterPresentation.presentation(for: .previewReady(prepared)).kind == .confirmation)
        #expect(ImportFooterPresentation.presentation(for: .validationFailed(prepared)).kind == .none)
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
    func developmentDatabaseResetSwapsToFreshProviderAndHydratesEmptyRuntimeState() async throws {
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
        let plan = try await seedSprint30Repository(DatabaseProvider.shared)

        let initialHydration = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
        #expect(initialHydration.accountCount == 1)
        #expect(initialHydration.transactionCount == plan.transactionTemplates.count)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == plan.transactionTemplates.count)

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
    func canonicalReloadDataRefreshesRuntimeCountsFromRepositoryState() async throws {
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
        let plan = try await seedSprint30Repository(DatabaseProvider.shared)

        let result = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)

        #expect(result.accountCount == 1)
        #expect(result.transactionCount == plan.transactionTemplates.count)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == plan.transactionTemplates.count)
    }

    @Test(.globalRuntimeStateIsolation)
    func runtimeInspectorAndRepositorySummaryUseRuntimeStoreCounts() async throws {
        resetSprint30RuntimeState()
        defer {
            resetSprint30RuntimeState()
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
        }

        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let plan = try await seedSprint30Repository(DatabaseProvider.shared)
        _ = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)

        let snapshot = DeveloperConsole.runtimeSnapshot(
            persistenceState: .verifiedSQLite,
            hydrationStatus: "Forced refresh completed",
            latestRefreshResult: "1 account(s), \(plan.transactionTemplates.count) transaction(s)"
        )

        #expect(snapshot.accountCount == 1)
        #expect(snapshot.transactionCount == plan.transactionTemplates.count)
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

@MainActor
private func seedSprint30Repository(_ provider: DatabaseProvider) async throws -> ConfirmedImportPlanDTO {
    let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
    guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
        Issue.record("Authentic confirmed import failed to create the runtime graph.")
        throw RepositoryError.persistenceUnavailable
    }
    return plan
}
