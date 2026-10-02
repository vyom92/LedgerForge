import Foundation
import Testing
@testable import LedgerForge

@Suite("AccountsViewModel", .serialized)
@MainActor
struct AccountsViewModelTests {

    @Test func recentActivityKeyIsTotalAndRetainsSameDocumentSourceOrder() throws {
        // Nonfinancial sort keys exercise the former a > c > b > a cycle.
        // No transaction, statement or financial DTO is constructed.
        let today = try StatementDate(year: 2026, month: 10, day: 2)
        let prior = try StatementDate(year: 2026, month: 10, day: 1)
        let a = AccountRecentActivityOrderKey(statementDate: today, documentID: "document-a", sourceOrdinal: 2, transactionID: "a")
        let c = AccountRecentActivityOrderKey(statementDate: today, documentID: "document-a", sourceOrdinal: 1, transactionID: "c")
        let b = AccountRecentActivityOrderKey(statementDate: today, documentID: "document-b", sourceOrdinal: 1, transactionID: "b")
        let previousDay = AccountRecentActivityOrderKey(statementDate: prior, documentID: "document-z", sourceOrdinal: 99, transactionID: "prior")
        let undated = AccountRecentActivityOrderKey(statementDate: nil, documentID: "document-z", sourceOrdinal: 99, transactionID: "undated")
        let keys = [a, b, c, previousDay, undated]

        #expect(keys.sorted(by: >).map(\.transactionID) == ["b", "a", "c", "prior", "undated"])
        for permutation in [[a, b, c], [a, c, b], [b, a, c], [b, c, a], [c, a, b], [c, b, a]] {
            #expect(permutation.sorted(by: >).map(\.transactionID) == ["b", "a", "c"])
        }
        for left in keys {
            #expect(!(left > left))
            for right in keys {
                #expect((left > right) == (right < left))
                #expect((left == right) || (left > right) || (right > left))
                if left > right { #expect(!(right > left)) }
                for last in keys where left > right && right > last {
                    #expect(left > last)
                }
            }
        }
        let tie = AccountRecentActivityOrderKey(statementDate: today, documentID: "document-a", sourceOrdinal: 2, transactionID: "z")
        #expect(tie > a)
        let missingOrdinal = AccountRecentActivityOrderKey(statementDate: today, documentID: "document-a", sourceOrdinal: 0, transactionID: "z")
        #expect(c > missingOrdinal)
    }

#if DEBUG
    @Test func canonicalStorePublicationRefreshesAccountsOnceAndExplicitRefreshConsumesPendingWork() async {
        // Empty installed snapshots test publication ownership without financial fixtures.
        let stores = PresentationStores()
        let viewModel = makeViewModel(coordinator: RecordingMetadataCoordinator(), stores: stores)
        #expect(viewModel.presentationRefreshCount == 1)

        stores.accounts.notifyAccountsOfInstalledValue()
        stores.transactions.notifyTransactionsOfInstalledValues()
        stores.importSessions.notifyImportSessionsOfInstalledValue()
        stores.cards.notifySnapshotOfInstalledValue()
        #expect(viewModel.presentationRefreshCount == 1)
        await drainMainQueue()
        #expect(viewModel.presentationRefreshCount == 2)

        stores.importSessions.notifyImportSessionsOfInstalledValue()
        await drainMainQueue()
        #expect(viewModel.presentationRefreshCount == 3)

        stores.cards.notifySnapshotOfInstalledValue()
        viewModel.selectCurrentAccounts()
        #expect(viewModel.presentationRefreshCount == 4)
        await drainMainQueue()
        #expect(viewModel.presentationRefreshCount == 4)
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
#endif

    @Test func accountNumberPresentationShowsOnlyKnownLastFourDigits() {
        #expect(AccountDisplayText.maskedNumber("123456789012") == "xxx9012")
        #expect(AccountDisplayText.maskedNumber("XXXX XXXX 1234") == "xxx1234")
        #expect(AccountDisplayText.maskedNumber("****-5678") == "xxx5678")
        #expect(AccountDisplayText.maskedNumber("12XX") == nil)
        #expect(AccountDisplayText.maskedNumber("123") == nil)
        #expect(AccountDisplayText.maskedNumber("") == nil)
    }

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

    func markAccountHistoryOnly(accountId: String, workspaceId: String) throws -> Bool {
        callCount += 1
        return true
    }

    func markAccountCurrent(accountId: String, workspaceId: String) throws -> Bool {
        callCount += 1
        return true
    }
}

@MainActor
private struct PresentationStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let importSessions = ImportSessionStore()
    let cards = CardStore()
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
        cardStore: stores.cards,
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
