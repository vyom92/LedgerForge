import Foundation
import Testing
@testable import LedgerForge

@Suite("AccountMetadataCoordinator", .serialized)
@MainActor
struct AccountMetadataCoordinatorTests {

    @Test(.globalRuntimeStateIsolation)
    func sameNameRetryRefreshesAfterAnEarlierHydrationFailure() throws {
        let provider = InMemoryRepositoryProvider()
        let runtime = generationProtectedProvider(provider)
        let workspace = WorkspaceDTO(id: "metadata-retry", name: "Metadata", createdAtISO: "2026-09-30T00:00:00Z")
        _ = try provider.workspaceRepo.upsertWorkspace(workspace)
        let account = AccountDTO(id: "metadata-retry-account", workspaceId: workspace.id,
            name: "Original", accountType: "bank", nativeCurrency: "INR", createdAtISO: workspace.createdAtISO)
        _ = try provider.accountRepo.upsertAccount(account)
        let names = AccountStore()
        let hydrator = RepositoryStoreHydrator(databaseProvider: runtime, accountStore: names,
            transactionStore: TransactionStore(), importSessionStore: ImportSessionStore(),
            workspaceId: workspace.id, participatesInLifecycleGate: false)
        _ = try hydrator.hydrateIfNeeded()
        var shouldFail = true
        let coordinator = AccountMetadataCoordinator(provider: { runtime }, developerConsole: nil,
            forcedHydration: { _, _ in
                if shouldFail { throw AccountMetadataCoordinatorError.savedButRefreshFailed }
                return try hydrator.hydrateIfNeeded(forceRefresh: true)
            })
        let savedName = "Commercial Bank of Qatar / mY Account!"
        #expect(throws: AccountMetadataCoordinatorError.savedButRefreshFailed) {
            _ = try coordinator.updateDisplayName(accountId: account.id, workspaceId: workspace.id, displayName: savedName)
        }
        #expect(names.accounts.first?.preferredDisplayName == "Original")
        shouldFail = false
        #expect(try !coordinator.updateDisplayName(accountId: account.id, workspaceId: workspace.id, displayName: savedName))
        #expect(names.accounts.first?.preferredDisplayName == savedName)
        #expect(try provider.accountRepo.account(id: account.id)?.name == savedName)
    }

    @Test(.globalRuntimeStateIsolation)
    func historyOnlyHasNoAccountTypeRestriction() throws {
        // Metadata-only mechanics, with no statement or financial fixture.
        for durable in [false, true] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Account-Metadata-\(UUID())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: directory) }
            let sqlite = durable ? try SQLiteRepositoryProvider(path: directory.appendingPathComponent("metadata.sqlite").path) : nil
            defer { sqlite?.database.close() }
            let runtime = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
            let workspace = WorkspaceDTO(id: "metadata-types", name: "Metadata", createdAtISO: "2026-09-30T00:00:00Z")
            _ = try runtime.workspaceRepo.upsertWorkspace(workspace)
            for type in ["bank", "credit_card", "investment", "cash", "loan", "future_account_type"] {
                let account = AccountDTO(id: "metadata-" + type, workspaceId: workspace.id,
                    name: "0001 / My Account!", accountType: type, nativeCurrency: "INR", createdAtISO: workspace.createdAtISO)
                _ = try runtime.accountRepo.upsertAccount(account)
                #expect(try runtime.accountRepo.markAccountHistoryOnly(accountId: account.id,
                    workspaceId: workspace.id, markedAtISO: workspace.createdAtISO))
                #expect(try !runtime.accountRepo.markAccountHistoryOnly(accountId: account.id,
                    workspaceId: workspace.id, markedAtISO: workspace.createdAtISO))
                _ = try runtime.accountRepo.upsertAccount(account)
                #expect(try runtime.accountRepo.account(id: account.id)?.closedAtISO == workspace.createdAtISO)
            }
            let restored = try RepositoryStoreHydrator(databaseProvider: runtime,
                workspaceId: workspace.id, participatesInLifecycleGate: false).stageHydration()
            #expect(restored.accounts.count == 6)
            #expect(restored.accounts.allSatisfy { $0.isHistoryOnly && !$0.includeInNetWorth && $0.preferredDisplayName == "0001 / My Account!" })
            for historical in try runtime.accountRepo.accounts(workspaceId: workspace.id) {
                #expect(try runtime.accountRepo.markAccountCurrent(accountId: historical.id, workspaceId: workspace.id))
                #expect(try !runtime.accountRepo.markAccountCurrent(accountId: historical.id, workspaceId: workspace.id))
                // An in-flight import carrying older owner metadata must not
                // undo the explicit restoration to current status.
                _ = try runtime.accountRepo.upsertAccount(historical)
                #expect(try runtime.accountRepo.account(id: historical.id)?.closedAtISO == nil)
            }
            let current = try RepositoryStoreHydrator(databaseProvider: runtime,
                workspaceId: workspace.id, participatesInLifecycleGate: false).stageHydration()
            #expect(current.accounts.count == 6)
            #expect(current.accounts.allSatisfy { !$0.isHistoryOnly && $0.preferredDisplayName == "0001 / My Account!" })
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func renameUsesOneLifecycleLeaseThenCanonicalHydration() throws {
        let provider = InMemoryRepositoryProvider()
        let databaseProvider = generationProtectedProvider(provider)
        let accountStore = AccountStore()
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let workspace = WorkspaceDTO(id: "workspace-metadata", name: "Metadata", createdAtISO: "2026-07-13T00:00:00Z")
        let account = AccountDTO(id: "account-metadata", workspaceId: workspace.id, name: "Original", institutionId: "Axis", accountType: "bank", nativeCurrency: "INR", description: "Imported from source", createdAtISO: "2026-07-13T00:00:00Z")
        _ = try provider.workspaceRepo.upsertWorkspace(workspace)
        _ = try provider.accountRepo.upsertAccount(account)
        let hydrator = RepositoryStoreHydrator(
            databaseProvider: databaseProvider,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: importSessionStore,
            workspaceId: workspace.id,
            participatesInLifecycleGate: false
        )
        _ = try hydrator.hydrateIfNeeded()
        var providerResolvedWhileLeaseHeld = false
        var hydratedWhileLeaseHeld = false
        let coordinator = AccountMetadataCoordinator(
            provider: {
                providerResolvedWhileLeaseHeld = DevelopmentDatabaseActivityGate.shared.hasActiveOperations
                return databaseProvider
            },
            developerConsole: nil,
            forcedHydration: { _, _ in
                hydratedWhileLeaseHeld = DevelopmentDatabaseActivityGate.shared.hasActiveOperations
                return try hydrator.hydrateIfNeeded(forceRefresh: true)
            }
        )

        #expect(try coordinator.updateDisplayName(
            accountId: account.id,
            workspaceId: workspace.id,
            displayName: "  Renamed  "
        ))
        #expect(try provider.accountRepo.account(id: account.id)?.name == "Renamed")
        #expect(try provider.accountRepo.account(id: account.id)?.description == "Imported from source")
        #expect(accountStore.account(repositoryAccountId: account.id)?.name == "Renamed")
        #expect(providerResolvedWhileLeaseHeld)
        #expect(hydratedWhileLeaseHeld)
        #expect(!DevelopmentDatabaseActivityGate.shared.hasActiveOperations)
    }

    @Test(.globalRuntimeStateIsolation)
    func providerIsResolvedPerCallAndNeverRetainedAcrossGenerations() throws {
        let first = InMemoryRepositoryProvider()
        let second = InMemoryRepositoryProvider()
        let workspace = WorkspaceDTO(
            id: "workspace-metadata-generation",
            name: "Metadata",
            createdAtISO: "2026-07-29T00:00:00Z"
        )
        let account = AccountDTO(
            id: "account-metadata-generation",
            workspaceId: workspace.id,
            name: "Original",
            institutionId: nil,
            accountType: "bank",
            nativeCurrency: "USD",
            description: nil,
            createdAtISO: "2026-07-29T00:00:00Z"
        )
        for provider in [first, second] {
            _ = try provider.workspaceRepo.upsertWorkspace(workspace)
            _ = try provider.accountRepo.upsertAccount(account)
        }
        let firstRuntime = generationProtectedProvider(first)
        let secondRuntime = generationProtectedProvider(second)
        var current = firstRuntime
        var resolutions = 0
        let coordinator = AccountMetadataCoordinator(
            provider: {
                resolutions += 1
                return current
            },
            developerConsole: nil,
            forcedHydration: { _, _ in
                RepositoryStoreHydrationResult(didHydrate: true, accountCount: 1, transactionCount: 0)
            }
        )

        #expect(try coordinator.updateDisplayName(
            accountId: account.id,
            workspaceId: workspace.id,
            displayName: "First generation"
        ))
        firstRuntime.invalidateGeneration()
        current = secondRuntime
        #expect(try coordinator.updateDisplayName(
            accountId: account.id,
            workspaceId: workspace.id,
            displayName: "Second generation"
        ))

        #expect(resolutions == 2)
        #expect(try first.accountRepo.account(id: account.id)?.name == "First generation")
        #expect(try second.accountRepo.account(id: account.id)?.name == "Second generation")
    }

    @Test(.globalRuntimeStateIsolation)
    func exclusiveLifecycleOwnershipBlocksMetadataWriteBeforeProviderResolution() throws {
        var providerResolutionCount = 0
        let coordinator = AccountMetadataCoordinator(
            provider: {
                providerResolutionCount += 1
                return .intentionalNonDurable(.testMemory)
            },
            developerConsole: nil
        )
        #expect(DevelopmentDatabaseActivityGate.shared.beginExclusive())
        defer { DevelopmentDatabaseActivityGate.shared.finishExclusive(providerChanged: false) }

        #expect(throws: AccountMetadataCoordinatorError.saveFailed) {
            _ = try coordinator.updateDisplayName(
                accountId: "account",
                workspaceId: "workspace",
                displayName: "Blocked"
            )
        }
        #expect(providerResolutionCount == 0)
    }

#if DEBUG
    @Test(.globalRuntimeStateIsolation)
    func nonCurrentDirectCallRequiresAcknowledgementBeforeMutation() throws {
        let concrete = InMemoryRepositoryProvider()
        let databaseProvider = generationProtectedProvider(concrete)
        let workspace = WorkspaceDTO(
            id: "workspace-acknowledgement",
            name: "Acknowledgement",
            createdAtISO: "2026-07-29T00:00:00Z"
        )
        let account = AccountDTO(
            id: "account-acknowledgement",
            workspaceId: workspace.id,
            name: "Original",
            institutionId: nil,
            accountType: "bank",
            nativeCurrency: "INR",
            description: nil,
            createdAtISO: "2026-07-29T00:00:00Z"
        )
        _ = try concrete.workspaceRepo.upsertWorkspace(workspace)
        _ = try concrete.accountRepo.upsertAccount(account)
        let state = DevelopmentProfileAcknowledgementState(
            providerGeneration: databaseProvider.generationToken,
            profileKind: .persistentDebug
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        var hydrationCount = 0
        let coordinator = AccountMetadataCoordinator(
            provider: { databaseProvider },
            developerConsole: nil,
            forcedHydration: { _, _ in
                hydrationCount += 1
                return RepositoryStoreHydrationResult(didHydrate: true, accountCount: 1, transactionCount: 0)
            },
            acknowledgementGate: gate
        )

        let challenge: DevelopmentProfileAcknowledgementChallenge
        do {
            _ = try coordinator.updateDisplayName(
                accountId: account.id,
                workspaceId: workspace.id,
                displayName: "Blocked"
            )
            Issue.record("Expected acknowledgement requirement")
            return
        } catch AccountMetadataCoordinatorError.acknowledgementRequired(let value) {
            challenge = value
        }

        #expect(try concrete.accountRepo.account(id: account.id)?.name == "Original")
        #expect(hydrationCount == 0)
        #expect(gate.acknowledge(challenge) == .granted)
        #expect(try coordinator.updateDisplayName(
            accountId: account.id,
            workspaceId: workspace.id,
            displayName: "Approved"
        ))
        #expect(try concrete.accountRepo.account(id: account.id)?.name == "Approved")
        #expect(hydrationCount == 1)
    }
#endif

    private func generationProtectedProvider(
        _ provider: InMemoryRepositoryProvider
    ) -> DatabaseProvider {
        DatabaseProvider(
            workspaceRepo: provider.workspaceRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            accountRepo: provider.accountRepo,
            cardRepo: provider.cardRepo,
            importSessionRepo: provider.importSessionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            generationToken: provider.generationToken,
            persistenceState: .intentionalNonDurable(.testMemory),
            protectsGeneration: true
        )
    }
}
