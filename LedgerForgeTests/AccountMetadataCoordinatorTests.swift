import Foundation
import Testing
@testable import LedgerForge

@Suite("AccountMetadataCoordinator", .serialized)
@MainActor
struct AccountMetadataCoordinatorTests {

    @Test func renameUsesTargetedMutationThenCanonicalHydration() throws {
        let provider = InMemoryRepositoryProvider()
        let accountStore = AccountStore()
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let workspace = WorkspaceDTO(id: "workspace-metadata", name: "Metadata", createdAtISO: "2026-07-13T00:00:00Z")
        let account = AccountDTO(id: "account-metadata", workspaceId: workspace.id, name: "Original", institutionId: "Axis", accountType: "bank", nativeCurrency: "INR", description: "Imported from source", createdAtISO: "2026-07-13T00:00:00Z")
        _ = try provider.workspaceRepo.upsertWorkspace(workspace)
        _ = try provider.accountRepo.upsertAccount(account)
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: importSessionStore,
            workspaceId: workspace.id
        )
        _ = try hydrator.hydrateIfNeeded()
        let coordinator = AccountMetadataCoordinator(
            accountRepository: provider.accountRepo,
            hydrator: hydrator,
            developerConsole: nil
        )

        #expect(try coordinator.updateDisplayName(
            accountId: account.id,
            workspaceId: workspace.id,
            displayName: "  Renamed  "
        ))
        #expect(try provider.accountRepo.account(id: account.id)?.name == "Renamed")
        #expect(try provider.accountRepo.account(id: account.id)?.description == "Imported from source")
        #expect(accountStore.account(repositoryAccountId: account.id)?.name == "Renamed")
    }
}
