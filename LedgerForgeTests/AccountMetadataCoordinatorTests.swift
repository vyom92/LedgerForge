import Foundation
import Testing
@testable import LedgerForge

@Suite("AccountMetadataCoordinator", .serialized)
@MainActor
struct AccountMetadataCoordinatorTests {

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
