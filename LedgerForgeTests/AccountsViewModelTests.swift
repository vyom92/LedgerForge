import Foundation
import Testing
@testable import LedgerForge

@Suite("AccountsViewModel", .serialized)
@MainActor
struct AccountsViewModelTests {

    @Test func exposesEveryHydratedAccountAndScopesSelectionByRepositoryID() {
        let coordinator = RecordingMetadataCoordinator()
        let stores = PresentationStores()
        stores.accounts.replaceAccounts([
            runtimeAccount(repositoryID: "account-b", name: "Beta"),
            runtimeAccount(repositoryID: "account-a", name: "Alpha"),
            runtimeAccount(repositoryID: "account-c", name: "Gamma"),
            runtimeAccount(repositoryID: "account-d", name: "Delta")
        ])

        let viewModel = makeViewModel(coordinator: coordinator, stores: stores)

        #expect(viewModel.accounts.map(\.id) == ["account-a", "account-b", "account-d", "account-c"])
        #expect(viewModel.selectedRepositoryAccountID == "account-a")
        #expect(viewModel.recentActivity.isEmpty)

        viewModel.selectAccount(repositoryAccountID: "account-b")
        #expect(viewModel.selectedRepositoryAccountID == "account-b")
        #expect(viewModel.selectedAccount?.displayName == "Beta")
        #expect(viewModel.recentActivity.isEmpty)
    }

    @Test func editBlocksSelectionAndRejectsBlankOrUnchangedDraftWithoutRepositoryWrite() {
        let coordinator = RecordingMetadataCoordinator()
        let stores = PresentationStores()
        stores.accounts.replaceAccounts([
            runtimeAccount(repositoryID: "account-a", name: "Alpha"),
            runtimeAccount(repositoryID: "account-b", name: "Beta")
        ])
        let viewModel = makeViewModel(coordinator: coordinator, stores: stores)

        viewModel.beginDisplayNameEdit()
        viewModel.selectAccount(repositoryAccountID: "account-b")
        #expect(viewModel.selectedRepositoryAccountID == "account-a")
        #expect(viewModel.presentationState == .selectionBlockedWhileEditing)

        viewModel.displayNameDraft = "   "
        viewModel.saveDisplayName()
        #expect(viewModel.presentationState == .validationFailed)
        #expect(coordinator.callCount == 0)

        viewModel.displayNameDraft = " Alpha "
        viewModel.saveDisplayName()
        #expect(coordinator.callCount == 0)
        #expect(!viewModel.isEditingDisplayName)
    }

    @Test func selectionSurvivesHydratedMetadataRefreshByRepositoryID() async {
        let stores = PresentationStores()
        stores.accounts.replaceAccounts([
            runtimeAccount(repositoryID: "account-a", name: "Alpha"),
            runtimeAccount(repositoryID: "account-b", name: "Beta")
        ])
        let viewModel = makeViewModel(coordinator: RecordingMetadataCoordinator(), stores: stores)
        viewModel.selectAccount(repositoryAccountID: "account-b")

        stores.accounts.replaceAccounts([
            runtimeAccount(repositoryID: "account-a", name: "Alpha"),
            runtimeAccount(repositoryID: "account-b", name: "Renamed Beta")
        ])

        await Task.yield()

        #expect(viewModel.selectedRepositoryAccountID == "account-b")
        #expect(viewModel.selectedAccount?.displayName == "Renamed Beta")
    }

#if DEBUG
    @Test func cancellationAndStaleGenerationCauseZeroDisplayNameMutation() {
        let coordinator = RecordingMetadataCoordinator()
        let stores = PresentationStores()
        stores.accounts.replaceAccounts([
            runtimeAccount(repositoryID: "account-a", name: "Alpha")
        ])
        let firstGeneration = ProviderGenerationToken()
        var state = DevelopmentProfileAcknowledgementState(
            providerGeneration: firstGeneration,
            profileKind: .temporarySession
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        let viewModel = makeViewModel(
            coordinator: coordinator,
            stores: stores,
            acknowledgementGate: gate
        )

        viewModel.beginDisplayNameEdit()
        viewModel.displayNameDraft = "Renamed"
        viewModel.saveDisplayName()
        #expect(viewModel.requiresDevelopmentProfileAcknowledgement)
        #expect(coordinator.callCount == 0)

        viewModel.cancelDevelopmentProfileAcknowledgement()
        #expect(!viewModel.requiresDevelopmentProfileAcknowledgement)
        #expect(coordinator.callCount == 0)

        viewModel.saveDisplayName()
        state = DevelopmentProfileAcknowledgementState(
            providerGeneration: ProviderGenerationToken(),
            profileKind: .temporarySession
        )
        viewModel.approveDevelopmentProfileAcknowledgement()
        #expect(viewModel.presentationState == .developmentProfileChanged)
        #expect(coordinator.callCount == 0)
    }

    @Test func approvalExecutesRetainedDisplayNameMutationOnce() {
        let coordinator = RecordingMetadataCoordinator()
        let stores = PresentationStores()
        stores.accounts.replaceAccounts([
            runtimeAccount(repositoryID: "account-a", name: "Alpha")
        ])
        let generation = ProviderGenerationToken()
        let state = DevelopmentProfileAcknowledgementState(
            providerGeneration: generation,
            profileKind: .persistentDebug
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        let viewModel = makeViewModel(
            coordinator: coordinator,
            stores: stores,
            acknowledgementGate: gate
        )

        viewModel.beginDisplayNameEdit()
        viewModel.displayNameDraft = "Approved"
        viewModel.saveDisplayName()
        viewModel.approveDevelopmentProfileAcknowledgement()

        #expect(coordinator.callCount == 1)
        #expect(!viewModel.requiresDevelopmentProfileAcknowledgement)
    }
#endif
}

@MainActor
private final class RecordingMetadataCoordinator: AccountMetadataCoordinating {
    private(set) var callCount = 0

    func updateDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
        callCount += 1
        return true
    }
}

@MainActor
private struct PresentationStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let importSessions = ImportSessionStore()
}

@MainActor
private func makeViewModel(
    coordinator: AccountMetadataCoordinating,
    stores: PresentationStores,
    acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
) -> AccountsViewModel {
    AccountsViewModel(
        accountStore: stores.accounts,
        transactionStore: stores.transactions,
        importSessionStore: stores.importSessions,
        metadataCoordinator: coordinator,
        cardStore: CardStore(),
        acknowledgementGate: acknowledgementGate ?? .shared
    )
}

@MainActor
private func runtimeAccount(repositoryID: String, name: String) -> Account {
    Account(
        repositoryAccountId: repositoryID,
        workspaceId: "workspace",
        institution: "Axis",
        name: name,
        type: .bank,
        currencyCode: "INR",
        currentBalance: .zero
    )
}
