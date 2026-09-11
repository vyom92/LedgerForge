//
//  LedgerForgeTests.swift
//  LedgerForgeTests
//
//  Created by Vyom on 03/07/26.
//

import Testing
import Foundation
import SwiftUI
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
        let contentViewSource = try workspaceSource("ContentView.swift")
        let shellSource = try workspaceSource("AppShellPresentation.swift")

        let sidebar = try sourceSection(
            shellSource,
            startingAt: "struct AppShellSidebar: View",
            endingBefore: "struct AppShellToolbar: View"
        )
        #expect(!sidebar.contains("chevron.down"))
        #expect(!sidebar.contains("Menu("))

        let dashboardAccounts = try sourceSection(
            contentViewSource,
            startingAt: "private var dashboardAccountsCard: some View",
            endingBefore: "private var importActivityCard: some View"
        )
        #expect(!dashboardAccounts.contains("Image(systemName: \"chevron.right\")"))
        #expect(dashboardAccounts.contains("linkButton(\"View all\")"))

        let accountDetail = try sourceSection(
            contentViewSource,
            startingAt: "private var accountDetailPanel: some View",
            endingBefore: "private var importStepper: some View"
        )
        #expect(!accountDetail.contains("Image(systemName: \"star\")"))
        #expect(accountDetail.contains("Edit display name"))

        let footer = try workspaceSource("ImportCentreFooterRenderer.swift")
        #expect(footer.contains("ImportFooterPresentation.presentation(for: importState)"))
        #expect(footer.contains("Retry Preparation"))
        #expect(footer.contains("View Transactions"))
        #expect(!footer.contains("Awaiting confirmation"))
        #expect(!footer.contains("importFooterPendingAction"))

        let validationReview = try sourceSection(
            contentViewSource,
            startingAt: "private var validationReviewPanel: some View",
            endingBefore: "private func settingsToggleRow"
        )
        #expect(validationReview.contains("No statement prepared"))
        #expect(validationReview.contains("Choose a statement file to see validation results."))
        for removedRow in ["File Password", "Date Format", "Duplicate Handling", "Create / Link Accounts", "Pending"] {
            #expect(!validationReview.contains(removedRow))
        }

        #expect(contentViewSource.components(separatedBy: "@State private var importCentrePresentationOwnerID = UUID()").count == 2)
        #expect(contentViewSource.components(separatedBy: "importCentre.attachPresentationOwner(importCentrePresentationOwnerID)").count == 2)
        #expect(contentViewSource.components(separatedBy: "importCentre.detachPresentationOwner(importCentrePresentationOwnerID)").count == 2)
    }

    @Test func destinationContainerConstructsOnlyTheSelectedDestination() {
        let sections: [AppShellSection] = [
            .dashboard, .accounts, .transactions, .imports, .salary, .settings, .developer
        ]

        for selected in sections {
            let probe = ViewConstructionProbe()
            let container = emptyDestinationContainer(selected: selected, probe: probe)

            #expect(probe.total == 0)

            let body = container.body
            _ = body

            #expect(probe.count(for: selected.rawValue) == 1)
            for section in sections where section.rawValue != selected.rawValue {
                #expect(probe.count(for: section.rawValue) == 0)
            }
        }
    }

    @Test func shellDestinationConstructionFollowsAvailabilityAndSafeDestinationGates() {
        let scenarios: [(ApplicationDataState, AppShellSection, Bool, Bool)] = [
            (.loading, .accounts, false, false),
            (.unavailable, .accounts, false, false),
            (.empty, .accounts, true, true),
            (.current, .accounts, true, true),
            (.retainedNonCurrent, .accounts, false, true),
            (.unavailable, .settings, false, true),
            (.unavailable, .developer, false, true)
        ]

        for (state, selectedSection, permitsMutation, shouldConstructDestination) in scenarios {
            let probe = ViewConstructionProbe()
            let shell = AppShellView(
                selectedSection: selectedSection,
                availabilityState: state,
                permitsMutation: permitsMutation,
                sidebar: { probe.make("sidebar") },
                toolbar: { probe.make("toolbar") },
                profileWarning: { probe.make("profile-warning") },
                availabilityBanner: { probe.make("availability-banner") },
                destination: { probe.make("destination") }
            )

            #expect(probe.total == 0)

            let body = shell.body
            _ = body

            #expect(probe.count(for: "destination") == (shouldConstructDestination ? 1 : 0))
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

        let dashboardViewModel = DashboardViewModel()
        ApplicationHydrationWorkflow(
            dashboardViewModel: dashboardViewModel,
            availability: ApplicationAvailability.shared
        ).hydrateDashboard(force: true)

        #expect(dashboardViewModel.presentationState == .loaded("Loaded 1 account(s), \(plan.transactionTemplates.count) transaction(s)"))
        #expect(ApplicationAvailability.shared.state == .current)
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

private func workspaceSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private func sourceSection(
    _ source: String,
    startingAt startMarker: String,
    endingBefore endMarker: String
) throws -> String {
    let start = try #require(source.range(of: startMarker))
    let trailing = source[start.lowerBound...]
    let end = try #require(trailing.range(of: endMarker))
    return String(trailing[..<end.lowerBound])
}

@MainActor
private final class ViewConstructionProbe {
    private(set) var counts: [String: Int] = [:]

    var total: Int { counts.values.reduce(0, +) }

    func make(_ key: String) -> EmptyView {
        counts[key, default: 0] += 1
        return EmptyView()
    }

    func count(for key: String) -> Int {
        counts[key, default: 0]
    }
}

private typealias EmptyDestinationContainer = AppDestinationContainer<
    EmptyView,
    EmptyView,
    EmptyView,
    EmptyView,
    EmptyView,
    EmptyView,
    EmptyView
>

@MainActor
private func emptyDestinationContainer(
    selected: AppShellSection,
    probe: ViewConstructionProbe
) -> EmptyDestinationContainer {
    AppDestinationContainer(
        selectedSection: selected,
        dashboard: { probe.make(AppShellSection.dashboard.rawValue) },
        accounts: { probe.make(AppShellSection.accounts.rawValue) },
        transactions: { probe.make(AppShellSection.transactions.rawValue) },
        imports: { probe.make(AppShellSection.imports.rawValue) },
        salary: { probe.make(AppShellSection.salary.rawValue) },
        settings: { probe.make(AppShellSection.settings.rawValue) },
        developer: { probe.make(AppShellSection.developer.rawValue) }
    )
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
