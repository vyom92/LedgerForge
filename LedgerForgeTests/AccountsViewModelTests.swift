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
            runtimeAccount(repositoryID: "account-b", name: "Beta", balance: 200),
            runtimeAccount(repositoryID: "account-a", name: "Alpha", balance: 100),
            runtimeAccount(repositoryID: "account-c", name: "Gamma", balance: 300),
            runtimeAccount(repositoryID: "account-d", name: "Delta", balance: 400)
        ])
        stores.transactions.replaceTransactions([
            runtimeTransaction(accountID: "account-a", sessionID: "session-a", description: "Alpha activity"),
            runtimeTransaction(accountID: "account-b", sessionID: "session-b", description: "Beta activity")
        ])

        let viewModel = makeViewModel(coordinator: coordinator, stores: stores)

        #expect(viewModel.accounts.map(\.id) == ["account-a", "account-b", "account-d", "account-c"])
        #expect(viewModel.selectedRepositoryAccountID == "account-a")
        #expect(viewModel.recentActivity.map(\.description) == ["Alpha activity"])

        viewModel.selectAccount(repositoryAccountID: "account-b")
        #expect(viewModel.selectedRepositoryAccountID == "account-b")
        #expect(viewModel.selectedAccount?.displayName == "Beta")
        #expect(viewModel.recentActivity.map(\.description) == ["Beta activity"])
    }

    @Test func editBlocksSelectionAndRejectsBlankOrUnchangedDraftWithoutRepositoryWrite() {
        let coordinator = RecordingMetadataCoordinator()
        let stores = PresentationStores()
        stores.accounts.replaceAccounts([
            runtimeAccount(repositoryID: "account-a", name: "Alpha", balance: 100),
            runtimeAccount(repositoryID: "account-b", name: "Beta", balance: 200)
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
            runtimeAccount(repositoryID: "account-a", name: "Alpha", balance: 100),
            runtimeAccount(repositoryID: "account-b", name: "Beta", balance: 200)
        ])
        let viewModel = makeViewModel(coordinator: RecordingMetadataCoordinator(), stores: stores)
        viewModel.selectAccount(repositoryAccountID: "account-b")

        stores.accounts.replaceAccounts([
            runtimeAccount(repositoryID: "account-a", name: "Alpha", balance: 100),
            runtimeAccount(repositoryID: "account-b", name: "Renamed Beta", balance: 200)
        ])

        await Task.yield()

        #expect(viewModel.selectedRepositoryAccountID == "account-b")
        #expect(viewModel.selectedAccount?.displayName == "Renamed Beta")
    }

    @Test func historyUsesTrustedRuntimeRelationshipsAndDrivesInlineDetail() {
        let stores = PresentationStores()
        stores.accounts.replaceAccounts([runtimeAccount(repositoryID: "account-a", name: "Alpha", balance: 100)])
        stores.transactions.replaceTransactions([
            runtimeTransaction(accountID: "account-a", sessionID: "session-old", description: "Old", date: date("2026-07-01")),
            runtimeTransaction(accountID: "account-a", sessionID: "session-new", description: "New", date: date("2026-07-03")),
            runtimeTransaction(accountID: "account-b", sessionID: "session-other", description: "Other", date: date("2026-07-04"))
        ])
        stores.importSessions.replaceImportSessions([
            RepositoryImportSession(id: "session-old", workspaceId: "workspace", sourceDocumentName: "old.csv", startedAtISO: "2026-07-01T00:00:00Z", completedAtISO: nil, validationStatus: "passed", parserVersion: "Parser A"),
            RepositoryImportSession(id: "session-new", workspaceId: "workspace", sourceDocumentName: "new.csv", startedAtISO: "2026-07-03T00:00:00Z", completedAtISO: "2026-07-03T01:00:00Z", validationStatus: "passed", parserVersion: "Parser A"),
            RepositoryImportSession(id: "session-other", workspaceId: "workspace", sourceDocumentName: "other.csv", startedAtISO: "2026-07-04T00:00:00Z", completedAtISO: nil, validationStatus: "passed", parserVersion: "Parser A")
        ])
        let viewModel = makeViewModel(coordinator: RecordingMetadataCoordinator(), stores: stores)

        #expect(viewModel.importHistory.map(\.id) == ["session-new", "session-old"])
        viewModel.selectImportSession(id: "session-old")
        #expect(viewModel.selectedImportSession?.sourceDocumentName == "old.csv")
        #expect(viewModel.selectedImportSession?.transactionCount == 1)
    }
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
    stores: PresentationStores
) -> AccountsViewModel {
    AccountsViewModel(
        accountStore: stores.accounts,
        transactionStore: stores.transactions,
        importSessionStore: stores.importSessions,
        metadataCoordinator: coordinator
    )
}

private func runtimeAccount(repositoryID: String, name: String, balance: Decimal) -> Account {
    Account(
        repositoryAccountId: repositoryID,
        workspaceId: "workspace",
        institution: "Axis",
        name: name,
        type: .bank,
        currencyCode: "INR",
        currentBalance: balance
    )
}

private func runtimeTransaction(accountID: String, sessionID: String, description: String, date: Date = date("2026-07-02")) -> Transaction {
    Transaction(
        date: date,
        description: description,
        debit: nil,
        credit: 100,
        amount: 100,
        balance: 100,
        currency: "INR",
        account: "Presentation only",
        sourceBank: "Axis",
        sourceFile: "Presentation only",
        repositoryAccountId: accountID,
        repositoryImportSessionId: sessionID
    )
}

private func date(_ value: String) -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: value)!
}
