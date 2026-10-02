// LedgerForge
// AccountsViewModel.swift

import Foundation
import Combine

@MainActor
final class ImportHistoryViewModel: ObservableObject {
    @Published private(set) var attempts: [RepositoryImportAttempt] = []
    @Published private(set) var selectedAttempt: RepositoryImportAttempt?
    @Published private(set) var latestDurableAttempt: RepositoryImportAttempt?
    private var cancellable: AnyCancellable?

    convenience init() { self.init(store: .shared) }

    init(store: ImportAttemptStore) {
        installAttempts(store.attempts)
        cancellable = store.$attempts.dropFirst().receive(on: RunLoop.main).sink { [weak self] in
            self?.installAttempts($0)
        }
    }
    private func installAttempts(_ attempts: [RepositoryImportAttempt]) {
        latestDurableAttempt = ImportActivityPresentation.latestDurableAttempt(from: attempts)
        self.attempts = attempts
        if let selectedAttempt { self.selectedAttempt = attempts.first { $0.id == selectedAttempt.id } }
    }
    func select(id: String) { selectedAttempt = attempts.first { $0.id == id } }
    func clearSelection() { selectedAttempt = nil }
}

struct AccountsAccountPresentation: Identifiable, Equatable {
    let id: String
    let displayName: String
    let accountNumberLabel: String?
    let institution: String
    let canonicalInstitutionID: String
    let accountType: AccountType
    let accountTypeLabel: String
    let currencyCode: String
    let currentBalance: Decimal?
    let identitySummaries: [AccountIdentitySummary]
    let currentBalanceLabel: String
    let latestStatementPeriod: String?
    let dueDate: String?
    let cardInstrumentCount: Int?
    let isHistoryOnly: Bool
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
    let isPartialImport: Bool
    let sourceRowCount: Int?
    let recognizedExistingRowCount: Int?
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
    case historyOnlySaveFailed
    case historyOnlySavedButRefreshFailed
#if DEBUG
    case acknowledgementRequired
    case developmentProfileChanged
#endif

    var message: String? {
        switch self {
        case .ready:
            return nil
        case .selectionBlockedWhileEditing:
            return "Save or cancel the display-name edit before selecting another account."
        case .validationFailed:
            return "Enter a non-empty display name before saving."
        case .saveFailed:
            return "The name could not be saved. Your saved name is unchanged."
        case .savedButRefreshFailed:
            return "The name was saved but could not be displayed yet. Retry or reopen the app."
        case .historyOnlySaveFailed:
            return "The account status could not be changed. Try again."
        case .historyOnlySavedButRefreshFailed:
            return "The account status was saved but could not be refreshed. Retry or reopen the app."
#if DEBUG
        case .acknowledgementRequired:
            return "Acknowledge the active development database profile before saving the account change."
        case .developmentProfileChanged:
            return "The active development database changed. Start the account change again."
#endif
        }
    }
}

private struct PendingAccountDisplayNameMutation {
    let accountID: String
    let workspaceID: String
    let displayName: String
}

private struct PendingAccountHistoryOnlyMutation {
    let accountID: String
    let workspaceID: String
    let historyOnly: Bool
}

/// Recent activity uses one total presentation key. Document identity breaks
/// equal-date ties across sources; it does not imply cross-document chronology.
nonisolated struct AccountRecentActivityOrderKey: Comparable {
    let statementDate: StatementDate?
    let documentID: String
    let sourceOrdinal: Int
    let transactionID: String

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.statementDate?.canonical ?? "", lhs.documentID, lhs.sourceOrdinal, lhs.transactionID)
            < (rhs.statementDate?.canonical ?? "", rhs.documentID, rhs.sourceOrdinal, rhs.transactionID)
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
    @Published private(set) var nativeBalanceSummaries: [DashboardCurrencyPosition] = []
    private var explicitlySelectedHistoryAccountID: String?
    var visibleAccounts: [AccountsAccountPresentation] {
        accounts.filter { !$0.isHistoryOnly || $0.id == explicitlySelectedHistoryAccountID }
    }
    @Published private(set) var selectedImportSession: AccountImportHistoryPresentation?
    @Published var displayNameDraft = ""
    @Published private(set) var editState: AccountDisplayNameEditState = .idle
    @Published private(set) var presentationState: AccountDetailPresentationState = .ready
#if DEBUG
    @Published private(set) var acknowledgementChallenge: DevelopmentProfileAcknowledgementChallenge?
#endif

    private let accountStore: AccountStore
    private let transactionStore: TransactionStore
    private let importSessionStore: ImportSessionStore
    private let cardStore: CardStore
    private let metadataCoordinator: AccountMetadataCoordinating
#if DEBUG
    private let acknowledgementGate: DevelopmentProfileAcknowledgementGate
    private var pendingDisplayNameMutation: PendingAccountDisplayNameMutation?
    private var pendingHistoryOnlyMutation: PendingAccountHistoryOnlyMutation?
#endif
    private var cancellables = Set<AnyCancellable>()
    private var pendingPresentationRefreshID: UUID?
#if DEBUG
    private(set) var presentationRefreshCount = 0
#endif

    convenience init() {
        self.init(
            accountStore: .shared,
            transactionStore: .shared,
            importSessionStore: .shared,
            metadataCoordinator: AccountMetadataCoordinator(),
            cardStore: .shared
        )
    }

#if DEBUG
    init(
        accountStore: AccountStore,
        transactionStore: TransactionStore,
        importSessionStore: ImportSessionStore,
        metadataCoordinator: AccountMetadataCoordinating,
        cardStore: CardStore,
        acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
    ) {
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.importSessionStore = importSessionStore
        self.metadataCoordinator = metadataCoordinator
        self.cardStore = cardStore
        self.acknowledgementGate = acknowledgementGate ?? .shared

        observeCanonicalStores()
        refreshPresentation()
    }
#else
    init(
        accountStore: AccountStore,
        transactionStore: TransactionStore,
        importSessionStore: ImportSessionStore,
        metadataCoordinator: AccountMetadataCoordinating,
        cardStore: CardStore
    ) {
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.importSessionStore = importSessionStore
        self.metadataCoordinator = metadataCoordinator
        self.cardStore = cardStore

        observeCanonicalStores()
        refreshPresentation()
    }
#endif

    private func observeCanonicalStores() {
        // Hydration installs the complete snapshot before publishing its stores.
        // Consume that synchronous publication batch once on the next main turn.
        Publishers.MergeMany([
            accountStore.$accounts.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            transactionStore.$transactions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            importSessionStore.$importSessions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            cardStore.$snapshot.dropFirst().map { _ in () }.eraseToAnyPublisher()
        ])
        .sink { [weak self] in self?.requestPresentationRefresh() }
        .store(in: &cancellables)
    }

    private func requestPresentationRefresh() {
        guard pendingPresentationRefreshID == nil else { return }
        let requestID = UUID()
        pendingPresentationRefreshID = requestID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingPresentationRefreshID == requestID else { return }
            self.refreshPresentation()
        }
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
        explicitlySelectedHistoryAccountID = accounts.first { $0.id == repositoryAccountID }?.isHistoryOnly == true ? repositoryAccountID : nil
        selectedRepositoryAccountID = repositoryAccountID
        selectedImportSession = nil
        presentationState = .ready
        refreshPresentation()
    }

    func selectCurrentAccounts() {
        guard editState == .idle else { presentationState = .selectionBlockedWhileEditing; return }
        explicitlySelectedHistoryAccountID = nil
        selectedRepositoryAccountID = accounts.first { !$0.isHistoryOnly }?.id
        selectedImportSession = nil
        refreshPresentation()
    }

    func beginDisplayNameEdit() {
        guard let selectedRuntimeAccount else { return }
        displayNameDraft = selectedRuntimeAccount.name
        editState = .editing
        presentationState = .ready
    }

    func cancelDisplayNameEdit() {
#if DEBUG
        discardPendingAcknowledgement()
#endif
        editState = .idle
        displayNameDraft = selectedRuntimeAccount?.name ?? ""
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

        let mutation = PendingAccountDisplayNameMutation(
            accountID: repositoryAccountID,
            workspaceID: workspaceID,
            displayName: trimmedDraft
        )
#if DEBUG
        switch acknowledgementGate.authorization(for: .accountDisplayNameMutation) {
        case .allowed:
            performDisplayNameMutation(mutation)
        case .acknowledgementRequired(let challenge):
            pendingDisplayNameMutation = mutation
            acknowledgementChallenge = challenge
            presentationState = .acknowledgementRequired
        case .developmentDatabaseUnavailable:
            presentationState = .saveFailed
        }
#else
        performDisplayNameMutation(mutation)
#endif
    }

#if DEBUG
    var requiresDevelopmentProfileAcknowledgement: Bool {
        acknowledgementChallenge != nil && (pendingDisplayNameMutation != nil || pendingHistoryOnlyMutation != nil)
    }

    func approveDevelopmentProfileAcknowledgement() {
        guard let challenge = acknowledgementChallenge else { return }
        let displayNameMutation = pendingDisplayNameMutation
        let historyOnlyMutation = pendingHistoryOnlyMutation
        guard displayNameMutation != nil || historyOnlyMutation != nil else { return }
        switch acknowledgementGate.acknowledge(challenge) {
        case .granted, .noAcknowledgementRequired:
            discardPendingAcknowledgement()
            if let historyOnlyMutation { performHistoryOnlyMutation(historyOnlyMutation) }
            else if let displayNameMutation { performDisplayNameMutation(displayNameMutation) }
        case .staleGeneration, .developmentDatabaseUnavailable:
            discardPendingAcknowledgement()
            presentationState = .developmentProfileChanged
        }
    }

    func cancelDevelopmentProfileAcknowledgement() {
        discardPendingAcknowledgement()
        presentationState = .ready
    }

    private func discardPendingAcknowledgement() {
        acknowledgementChallenge = nil
        pendingDisplayNameMutation = nil
        pendingHistoryOnlyMutation = nil
    }
#endif

    /// Called after the owner confirms history-only treatment for this account.
    /// Historical imports remain eligible for this same account.
    func markAccountHistoryOnly(accountID: String) {
        setHistoryOnly(true, accountID: accountID)
    }

    func markAccountCurrent(accountID: String) {
        setHistoryOnly(false, accountID: accountID)
    }

    private func setHistoryOnly(_ historyOnly: Bool, accountID: String) {
        guard editState == .idle, selectedRepositoryAccountID == accountID,
              let account = selectedRuntimeAccount,
              account.isHistoryOnly != historyOnly, let workspaceID = account.workspaceId else { return }
        let mutation = PendingAccountHistoryOnlyMutation(accountID: accountID, workspaceID: workspaceID, historyOnly: historyOnly)
#if DEBUG
        discardPendingAcknowledgement()
        switch acknowledgementGate.authorization(for: .accountHistoryOnlyMutation) {
        case .allowed:
            performHistoryOnlyMutation(mutation)
        case .acknowledgementRequired(let challenge):
            pendingHistoryOnlyMutation = mutation
            acknowledgementChallenge = challenge
            presentationState = .acknowledgementRequired
        case .developmentDatabaseUnavailable:
            presentationState = .historyOnlySaveFailed
        }
#else
        performHistoryOnlyMutation(mutation)
#endif
    }

    private func performHistoryOnlyMutation(_ mutation: PendingAccountHistoryOnlyMutation) {
        do {
            _ = mutation.historyOnly ? try metadataCoordinator.markAccountHistoryOnly(
                accountId: mutation.accountID, workspaceId: mutation.workspaceID
            ) : try metadataCoordinator.markAccountCurrent(accountId: mutation.accountID, workspaceId: mutation.workspaceID)
            presentationState = .ready
            refreshPresentation()
        } catch {
#if DEBUG
            if let coordinatorError = error as? AccountMetadataCoordinatorError {
                switch coordinatorError {
                case .acknowledgementRequired(let challenge):
                    pendingHistoryOnlyMutation = mutation
                    acknowledgementChallenge = challenge
                    presentationState = .acknowledgementRequired
                    return
                case .staleDevelopmentProfile:
                    discardPendingAcknowledgement()
                    presentationState = .developmentProfileChanged
                    return
                default: break
                }
            }
#endif
            presentationState = (error as? AccountMetadataCoordinatorError) == .savedButRefreshFailed
                ? .historyOnlySavedButRefreshFailed : .historyOnlySaveFailed
        }
    }

    private func performDisplayNameMutation(_ mutation: PendingAccountDisplayNameMutation) {
        do {
            _ = try metadataCoordinator.updateDisplayName(
                accountId: mutation.accountID,
                workspaceId: mutation.workspaceID,
                displayName: mutation.displayName
            )
            editState = .idle
            displayNameDraft = ""
            presentationState = .ready
            refreshPresentation()
        } catch {
#if DEBUG
            if let coordinatorError = error as? AccountMetadataCoordinatorError {
                switch coordinatorError {
                case .acknowledgementRequired(let challenge):
                    pendingDisplayNameMutation = mutation
                    acknowledgementChallenge = challenge
                    presentationState = .acknowledgementRequired
                    return
                case .staleDevelopmentProfile:
                    discardPendingAcknowledgement()
                    presentationState = .developmentProfileChanged
                    return
                default:
                    break
                }
            }
#endif
            if let coordinatorError = error as? AccountMetadataCoordinatorError,
               coordinatorError == .savedButRefreshFailed {
                editState = .idle
                displayNameDraft = ""
                presentationState = .savedButRefreshFailed
            } else {
                presentationState = .saveFailed
            }
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
        // An explicit selection/metadata refresh also consumes queued publication.
        pendingPresentationRefreshID = nil
#if DEBUG
        presentationRefreshCount += 1
#endif
        let runtimeAccounts = accountStore.accounts
            .compactMap { account -> (Account, String)? in
                guard let repositoryAccountID = account.repositoryAccountId else { return nil }
                return (account, repositoryAccountID)
            }
            .sorted { lhs, rhs in
                if lhs.0.name == rhs.0.name { return lhs.1 < rhs.1 }
                return lhs.0.name < rhs.0.name
            }

        // Compute calendar sort keys while still on the view model's actor.
        // `sorted` receives a synchronous nonisolated closure, so calling the
        // actor-isolated `SelectedStatementMonth.canonical` property from
        // inside that closure is not a meaningful isolation hop. The keys are
        // immutable strings and are safe to capture for the comparison.
        var statementCycleKeys: [String: String] = [:]
        for statement in cardStore.snapshot.statements {
            if let selected = statement.selectedStatementMonth {
                statementCycleKeys[statement.id] = selected.canonical
            } else if let end = statement.period?.end {
                statementCycleKeys[statement.id] = String(format: "%04d-%02d", end.year, end.month)
            } else if let date = statement.statementDate {
                statementCycleKeys[statement.id] = String(format: "%04d-%02d", date.year, date.month)
            } else {
                statementCycleKeys[statement.id] = ""
            }
        }

        nativeBalanceSummaries = DashboardPositionProjection.make(accounts: runtimeAccounts.map(\.0),
            transactions: transactionStore.transactions, cardSnapshot: cardStore.snapshot)
        let positions = Dictionary(uniqueKeysWithValues: nativeBalanceSummaries.flatMap { $0.banks + $0.cards }.map { ($0.id, $0) })
        accounts = runtimeAccounts.map { account, repositoryAccountID in
            let latestCardStatement = cardStore.snapshot.statements
                .filter { $0.liabilityAccountID == repositoryAccountID }
                .sorted { lhs, rhs in
                    let lhsCycle = statementCycleKeys[lhs.id] ?? ""
                    let rhsCycle = statementCycleKeys[rhs.id] ?? ""
                    if lhsCycle != rhsCycle { return lhsCycle > rhsCycle }
                    let lhsExact = lhs.statementDate?.canonical ?? lhs.period?.end.canonical
                    let rhsExact = rhs.statementDate?.canonical ?? rhs.period?.end.canonical
                    switch (lhsExact, rhsExact) {
                    case let (left?, right?) where left != right: return left > right
                    case (_?, nil): return true
                    case (nil, _?): return false
                    default: return false
                    }
                }.first
            let instrumentCount = cardStore.snapshot.continuingCardGroups(accountID: repositoryAccountID).count
            let latestStatementPeriod = latestCardStatement.flatMap { statement -> String? in
                if let period = statement.period {
                    return "\(period.start.presentation) – \(period.end.presentation)"
                }
                return statement.selectedStatementMonth.map { AppDateDisplay.month($0.canonical) }
            }
            let currentInstrumentIDs = Set(latestCardStatement?.instrumentIDs ?? [])
            let instrumentNumbers = Set(cardStore.snapshot.instruments
                .filter { currentInstrumentIDs.contains($0.id) }
                .flatMap(\.sourceObservations)
                .compactMap { AccountDisplayText.maskedNumber($0.value) }).sorted()
            return AccountsAccountPresentation(
                id: repositoryAccountID,
                displayName: account.preferredDisplayName,
                accountNumberLabel: account.sourceAccountNumberLabel
                    ?? (instrumentNumbers.isEmpty ? nil : instrumentNumbers.joined(separator: " · ")),
                institution: account.institutionDisplayName,
                canonicalInstitutionID: account.institution,
                accountType: account.type,
                accountTypeLabel: Self.accountTypeLabel(account.type),
                currencyCode: account.currencyCode,
                currentBalance: account.isHistoryOnly
                    ? (account.type == .creditCard ? latestCardStatement?.newBalance?.amount
                       : (account.currentBalanceAsOfISO == nil ? nil : account.currentBalance))
                    : positions[repositoryAccountID]?.amount?.amount,
                identitySummaries: account.identitySummaries,
                currentBalanceLabel: account.isHistoryOnly ? "Historical Statement Balance"
                    : account.type == .creditCard ? "Current Liability" : "Current Balance",
                latestStatementPeriod: latestStatementPeriod,
                dueDate: latestCardStatement?.dueDate?.presentation,
                cardInstrumentCount: account.type == .creditCard ? instrumentCount : nil,
                isHistoryOnly: account.isHistoryOnly
            )
        }

        if let selectedRepositoryAccountID,
           accounts.contains(where: { $0.id == selectedRepositoryAccountID && (!$0.isHistoryOnly || $0.id == explicitlySelectedHistoryAccountID) }) {
            self.selectedRepositoryAccountID = selectedRepositoryAccountID
        } else if editState == .editing {
            // A refresh must not silently retarget an active display-name draft.
            self.selectedRepositoryAccountID = selectedRepositoryAccountID
        } else {
            self.selectedRepositoryAccountID = accounts.first { !$0.isHistoryOnly }?.id
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
            accountID: selectedRepositoryAccountID,
            transactions: selectedTransactions,
            sessions: importSessionStore.importSessions,
            cardSnapshot: cardStore.snapshot
        )
        importHistory = history
        if let selectedImportSession,
           let refreshedSelection = history.first(where: { $0.id == selectedImportSession.id }) {
            self.selectedImportSession = refreshedSelection
        } else {
            selectedImportSession = nil
        }
    }

    static func importHistory(
        accountID: String,
        transactions: [Transaction],
        sessions: [RepositoryImportSession],
        cardSnapshot: CardStoreSnapshot = .empty
    ) -> [AccountImportHistoryPresentation] {
        let transactionsBySessionID = Dictionary(grouping: transactions.compactMap { transaction -> (String, Transaction)? in
            guard transaction.repositoryAccountId == accountID,
                  let sessionID = transaction.repositoryImportSessionId else { return nil }
            return (sessionID, transaction)
        }, by: { $0.0 })

        return sessions.compactMap { session in
            let sessionTransactions = transactionsBySessionID[session.id]?.map(\.1) ?? []
            let bank = session.bankAccountHistory[accountID]
            let card = cardSnapshot.statements.first {
                $0.liabilityAccountID == accountID && $0.importSessionID == session.id
            }
            guard !sessionTransactions.isEmpty || bank != nil || card != nil else { return nil }
            let sortedDates = sessionTransactions.compactMap(\.statementDate).sorted()
            let currencies = Set(sessionTransactions.map(\.currency))
            return AccountImportHistoryPresentation(
                id: session.id,
                sourceDocumentName: session.sourceDocumentName,
                startedAtISO: session.startedAtISO,
                completedAtISO: session.completedAtISO,
                validationStatus: session.validationStatus,
                parserVersion: session.parserVersion,
                transactionCount: bank?.importedTransactionCount ?? session.partialImportSummary?.importedTransactionCount ?? sessionTransactions.count,
                firstTransactionDate: session.partialImportSummary?.statementStartDate ?? sortedDates.first,
                lastTransactionDate: session.partialImportSummary?.statementEndDate ?? sortedDates.last,
                currencyCode: bank?.nativeCurrency ?? card?.currency.code ?? session.partialImportSummary?.nativeCurrency ?? (currencies.count == 1 ? currencies.first : nil),
                isPartialImport: bank.map { $0.importedTransactionCount > 0 && $0.recognizedExistingRowCount > 0 } ?? (session.partialImportSummary != nil),
                sourceRowCount: bank?.sourceRowCount ?? card?.sourceRowCount ?? session.partialImportSummary?.sourceRowCount,
                recognizedExistingRowCount: bank?.recognizedExistingRowCount ?? session.partialImportSummary?.recognizedExistingRowCount
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
        recentActivityOrderKey(for: lhs) > recentActivityOrderKey(for: rhs)
    }

    private static func recentActivityOrderKey(for transaction: Transaction) -> AccountRecentActivityOrderKey {
        let sourceOrder = transaction.documentScopedSourceOrder
        return AccountRecentActivityOrderKey(
            statementDate: transaction.statementDate,
            documentID: sourceOrder?.documentID ?? transaction.repositoryDocumentId ?? "",
            sourceOrdinal: sourceOrder?.ordinal ?? 0,
            transactionID: transaction.repositoryTransactionId ?? transaction.id.uuidString
        )
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
