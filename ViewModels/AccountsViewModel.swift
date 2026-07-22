// LedgerForge
// AccountsViewModel.swift

import Foundation
import Combine

@MainActor
final class ImportHistoryViewModel: ObservableObject {
    @Published private(set) var attempts: [RepositoryImportAttempt] = []
    @Published private(set) var selectedAttempt: RepositoryImportAttempt?
    private var cancellable: AnyCancellable?

    convenience init() { self.init(store: .shared) }

    init(store: ImportAttemptStore) {
        attempts = store.attempts
        cancellable = store.$attempts.receive(on: RunLoop.main).sink { [weak self] attempts in
            self?.attempts = attempts
            if let selected = self?.selectedAttempt { self?.selectedAttempt = attempts.first { $0.id == selected.id } }
        }
    }
    func select(id: String) { selectedAttempt = attempts.first { $0.id == id } }
    func clearSelection() { selectedAttempt = nil }
}

struct AccountsAccountPresentation: Identifiable, Equatable {
    let id: String
    let displayName: String
    let institution: String
    let accountTypeLabel: String
    let currencyCode: String
    let currentBalance: Decimal
    let identitySummaries: [AccountIdentitySummary]
}

struct NativeAccountBalanceSummary: Identifiable, Equatable {
    let money: Money
    var id: String { money.currency.code }
}

struct AccountImportHistoryPresentation: Identifiable, Equatable {
    let id: String
    let sourceDocumentName: String?
    let startedAtISO: String
    let completedAtISO: String?
    let validationStatus: String
    let parserVersion: String?
    let transactionCount: Int
    let firstTransactionDate: StatementDate?
    let lastTransactionDate: StatementDate?
    let currencyCode: String?
}

enum AccountDisplayNameEditState: Equatable {
    case idle
    case editing
}

enum AccountDetailPresentationState: Equatable {
    case ready
    case selectionBlockedWhileEditing
    case validationFailed
    case saveFailed
    case savedButRefreshFailed

    var message: String? {
        switch self {
        case .ready:
            return nil
        case .selectionBlockedWhileEditing:
            return "Save or cancel the display-name edit before selecting another account."
        case .validationFailed:
            return "Enter a non-empty display name before saving."
        case .saveFailed:
            return "The display name could not be saved. Runtime data was not changed."
        case .savedButRefreshFailed:
            return "The display name was saved, but the account detail could not refresh. Retry or relaunch to load persisted data."
        }
    }
}

@MainActor
final class AccountsViewModel: ObservableObject {

    @Published private(set) var accounts: [AccountsAccountPresentation] = []
    @Published private(set) var selectedRepositoryAccountID: String?
    @Published private(set) var selectedAccount: AccountsAccountPresentation?
    @Published private(set) var recentActivity: [Transaction] = []
    @Published private(set) var transactionCount = 0
    @Published private(set) var importHistory: [AccountImportHistoryPresentation] = []
    @Published private(set) var nativeBalanceSummaries: [NativeAccountBalanceSummary] = []
    @Published private(set) var selectedImportSession: AccountImportHistoryPresentation?
    @Published var displayNameDraft = ""
    @Published private(set) var editState: AccountDisplayNameEditState = .idle
    @Published private(set) var presentationState: AccountDetailPresentationState = .ready

    private let accountStore: AccountStore
    private let transactionStore: TransactionStore
    private let importSessionStore: ImportSessionStore
    private let metadataCoordinator: AccountMetadataCoordinating
    private var cancellables = Set<AnyCancellable>()

    convenience init() {
        self.init(
            accountStore: .shared,
            transactionStore: .shared,
            importSessionStore: .shared,
            metadataCoordinator: AccountMetadataCoordinator()
        )
    }

    init(
        accountStore: AccountStore,
        transactionStore: TransactionStore,
        importSessionStore: ImportSessionStore,
        metadataCoordinator: AccountMetadataCoordinating
    ) {
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.importSessionStore = importSessionStore
        self.metadataCoordinator = metadataCoordinator

        accountStore.$accounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshPresentation() }
            .store(in: &cancellables)
        transactionStore.$transactions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshPresentation() }
            .store(in: &cancellables)
        importSessionStore.$importSessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshPresentation() }
            .store(in: &cancellables)

        refreshPresentation()
    }

    var isEditingDisplayName: Bool {
        editState == .editing
    }

    func selectAccount(repositoryAccountID: String) {
        guard editState == .idle else {
            presentationState = .selectionBlockedWhileEditing
            return
        }
        guard accounts.contains(where: { $0.id == repositoryAccountID }) else { return }
        selectedRepositoryAccountID = repositoryAccountID
        selectedImportSession = nil
        presentationState = .ready
        refreshPresentation()
    }

    func beginDisplayNameEdit() {
        guard let selectedAccount else { return }
        displayNameDraft = selectedAccount.displayName
        editState = .editing
        presentationState = .ready
    }

    func cancelDisplayNameEdit() {
        editState = .idle
        displayNameDraft = selectedAccount?.displayName ?? ""
        presentationState = .ready
    }

    func saveDisplayName() {
        guard let runtimeAccount = selectedRuntimeAccount,
              let repositoryAccountID = runtimeAccount.repositoryAccountId,
              let workspaceID = runtimeAccount.workspaceId else {
            presentationState = .saveFailed
            return
        }

        let trimmedDraft = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else {
            presentationState = .validationFailed
            return
        }

        guard trimmedDraft != runtimeAccount.name else {
            editState = .idle
            displayNameDraft = runtimeAccount.name
            presentationState = .ready
            return
        }

        do {
            _ = try metadataCoordinator.updateDisplayName(
                accountId: repositoryAccountID,
                workspaceId: workspaceID,
                displayName: trimmedDraft
            )
            editState = .idle
            displayNameDraft = ""
            presentationState = .ready
            refreshPresentation()
        } catch AccountMetadataCoordinatorError.savedButRefreshFailed {
            editState = .idle
            displayNameDraft = ""
            presentationState = .savedButRefreshFailed
        } catch {
            presentationState = .saveFailed
        }
    }

    func selectImportSession(id: String) {
        selectedImportSession = importHistory.first { $0.id == id }
    }

    func clearSelectedImportSession() {
        selectedImportSession = nil
    }

    private var selectedRuntimeAccount: Account? {
        guard let selectedRepositoryAccountID else { return nil }
        return accountStore.account(repositoryAccountId: selectedRepositoryAccountID)
    }

    private func refreshPresentation() {
        let runtimeAccounts = accountStore.accounts
            .compactMap { account -> (Account, String)? in
                guard let repositoryAccountID = account.repositoryAccountId else { return nil }
                return (account, repositoryAccountID)
            }
            .sorted { lhs, rhs in
                if lhs.0.name == rhs.0.name { return lhs.1 < rhs.1 }
                return lhs.0.name < rhs.0.name
            }

        accounts = runtimeAccounts.map { account, repositoryAccountID in
            AccountsAccountPresentation(
                id: repositoryAccountID,
                displayName: account.nickname ?? account.name,
                institution: account.institution,
                accountTypeLabel: Self.accountTypeLabel(account.type),
                currencyCode: account.currencyCode,
                currentBalance: account.currentBalance,
                identitySummaries: account.identitySummaries
            )
        }

        let balancesByCurrency = Dictionary(grouping: runtimeAccounts.map(\.0), by: { $0.nativeCurrency })
        nativeBalanceSummaries = balancesByCurrency.keys.sorted().map { currency in
            let balances = (balancesByCurrency[currency] ?? []).map(\.currentBalanceMoney)
            return NativeAccountBalanceSummary(money: try! Money.aggregate(balances))
        }

        if let selectedRepositoryAccountID,
           accounts.contains(where: { $0.id == selectedRepositoryAccountID }) {
            self.selectedRepositoryAccountID = selectedRepositoryAccountID
        } else if editState == .editing {
            // A refresh must not silently retarget an active display-name draft.
            self.selectedRepositoryAccountID = selectedRepositoryAccountID
        } else {
            self.selectedRepositoryAccountID = accounts.first?.id
        }

        selectedAccount = accounts.first { $0.id == selectedRepositoryAccountID }
        refreshSelectedAccountDetails()
    }

    private func refreshSelectedAccountDetails() {
        guard let selectedRepositoryAccountID else {
            recentActivity = []
            transactionCount = 0
            importHistory = []
            selectedImportSession = nil
            return
        }

        let selectedTransactions = transactionStore.transactions
            .filter { $0.repositoryAccountId == selectedRepositoryAccountID }
        transactionCount = selectedTransactions.count
        recentActivity = selectedTransactions.sorted(by: Self.isNewer).prefix(3).map { $0 }

        let history = Self.importHistory(
            transactions: selectedTransactions,
            sessions: importSessionStore.importSessions
        )
        importHistory = history
        if let selectedImportSession,
           let refreshedSelection = history.first(where: { $0.id == selectedImportSession.id }) {
            self.selectedImportSession = refreshedSelection
        } else {
            selectedImportSession = nil
        }
    }

    private static func importHistory(
        transactions: [Transaction],
        sessions: [RepositoryImportSession]
    ) -> [AccountImportHistoryPresentation] {
        let transactionsBySessionID = Dictionary(grouping: transactions.compactMap { transaction -> (String, Transaction)? in
            guard let sessionID = transaction.repositoryImportSessionId else { return nil }
            return (sessionID, transaction)
        }, by: { $0.0 })

        return sessions.compactMap { session in
            guard let sessionTransactions = transactionsBySessionID[session.id]?.map(\.1), !sessionTransactions.isEmpty else {
                return nil
            }
            let sortedDates = sessionTransactions.compactMap(\.statementDate).sorted()
            let currencies = Set(sessionTransactions.map(\.currency))
            return AccountImportHistoryPresentation(
                id: session.id,
                sourceDocumentName: session.sourceDocumentName,
                startedAtISO: session.startedAtISO,
                completedAtISO: session.completedAtISO,
                validationStatus: session.validationStatus,
                parserVersion: session.parserVersion,
                transactionCount: sessionTransactions.count,
                firstTransactionDate: sortedDates.first,
                lastTransactionDate: sortedDates.last,
                currencyCode: currencies.count == 1 ? currencies.first : nil
            )
        }
        .sorted { lhs, rhs in
            let leftDate = lhs.completedAtISO ?? lhs.startedAtISO
            let rightDate = rhs.completedAtISO ?? rhs.startedAtISO
            if leftDate == rightDate { return lhs.id < rhs.id }
            return leftDate > rightDate
        }
    }

    private static func isNewer(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        switch (lhs.statementDate, rhs.statementDate) {
        case let (left?, right?) where left != right:
            return left > right
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return Self.displayOrder(lhs, rhs)
        }
    }

    private static func displayOrder(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        if lhs.documentScopedSourceOrder?.documentID == rhs.documentScopedSourceOrder?.documentID,
           let left = lhs.documentScopedSourceOrder?.ordinal,
           let right = rhs.documentScopedSourceOrder?.ordinal,
           left != right {
            return left > right
        }
        return (lhs.repositoryTransactionId ?? lhs.id.uuidString) > (rhs.repositoryTransactionId ?? rhs.id.uuidString)
    }

    private static func accountTypeLabel(_ type: AccountType) -> String {
        switch type {
        case .bank: return "Bank Account"
        case .creditCard: return "Credit Card"
        case .investment: return "Investment Account"
        case .cash: return "Cash Account"
        case .loan: return "Loan Account"
        }
    }
}
