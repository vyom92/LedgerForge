//
//  TransactionListViewModel.swift
//  LedgerForge
//
//  Created by Copilot on 06/07/26.
//

import Foundation
import Combine

struct TransactionCurrencySummary: Identifiable, Equatable {
    let currency: CurrencyCode
    let inflow: Money
    let outflow: Money

    var id: String { currency.code }
    var net: Money { try! inflow - outflow }
}

struct TransactionValidationPresentation: Equatable {
    let validationStatus: String

    var title: String { validationStatus.localizedCapitalized }
    var isPassed: Bool { validationStatus == "passed" }
    var detail: String {
        switch validationStatus {
        case "pending": "Validation is pending for this imported transaction."
        case "passed": "This imported transaction passed validation."
        case "warning": "This imported transaction was imported with validation warnings."
        case "failed": "This imported transaction did not pass validation."
        default: "Validation is unavailable for this imported transaction."
        }
    }

    init?(validationStatus: String) {
        guard ["pending", "passed", "warning", "failed"].contains(validationStatus) else {
            return nil
        }
        self.validationStatus = validationStatus
    }
}

enum TransactionProvenanceAvailability: Equatable {
    case complete
    case partial
    case unavailable

    var title: String {
        switch self {
        case .complete: "Available"
        case .partial: "Partially available"
        case .unavailable: "Unavailable"
        }
    }
}

struct TransactionDetailPresentation: Equatable {
    let description: String
    let signedAmount: String
    let nativeCurrency: String
    let direction: String
    let statementDate: String
    let statementDateRole: String
    let accountDisplayName: String
    let institution: String
    let sourceDocumentName: String
    let importedAt: Date?
    let importedAtText: String
    let validation: TransactionValidationPresentation?
    let runningBalance: String
    let provenanceAvailability: TransactionProvenanceAvailability
    let accessibilityText: String
}

nonisolated enum TransactionPresentationDomain: String, CaseIterable, Hashable, Sendable {
    case bank
    case card
    case unknown
}

nonisolated enum TransactionPresentationEffect: String, CaseIterable, Hashable, Sendable {
    case credit
    case debit
    case increasesAmountOwed
    case decreasesAmountOwed
    case unknown
}

nonisolated enum TransactionPresentationCategoryChoice: Hashable, Sendable {
    case uncategorized
    case categoryID(String)
}

nonisolated struct TransactionPresentationAmountRange: Equatable, Sendable {
    let lowerBound: Decimal?
    let upperBound: Decimal?

    var isValid: Bool {
        let bounds = [lowerBound, upperBound].compactMap { $0 }
        guard bounds.allSatisfy({ !$0.isNaN }) else { return false }
        guard let lowerBound, let upperBound else { return true }
        return lowerBound <= upperBound
    }

    func contains(_ amount: Decimal) -> Bool {
        (lowerBound.map { amount >= $0 } ?? true) && (upperBound.map { amount <= $0 } ?? true)
    }
}

nonisolated struct TransactionPresentationStatementDateRange: Equatable, Sendable {
    let start: StatementDate?
    let end: StatementDate?

    var isValid: Bool {
        guard let start, let end else { return true }
        return start <= end
    }

    func contains(_ date: StatementDate) -> Bool {
        (start.map { date >= $0 } ?? true) && (end.map { date <= $0 } ?? true)
    }
}

nonisolated struct TransactionPresentationFilterSpec: Equatable, Sendable {
    var searchText: String = ""
    var accountIDs: Set<String> = []
    var currencies: Set<CurrencyCode> = []
    var categories: Set<TransactionPresentationCategoryChoice> = []
    var domains: Set<TransactionPresentationDomain> = []
    var effects: Set<TransactionPresentationEffect> = []
    /// Values are privacy-safe institution display strings normalized by
    /// TransactionPresentationText. Identity continues to use account IDs.
    var institutionDisplayNames: Set<String> = []
    var amountRange: TransactionPresentationAmountRange?
    /// A set of source-declared statement months, applied inclusively.
    var statementMonths: Set<SelectedStatementMonth> = []
    var statementDateRange: TransactionPresentationStatementDateRange?

    static let empty = TransactionPresentationFilterSpec()

    mutating func clearCriteria() {
        self = .empty
    }
}

nonisolated enum TransactionPresentationSortKey: CaseIterable, Hashable, Sendable {
    case statementDate
    case description
    case account
    case category
    case nativeAmount
}

nonisolated enum TransactionPresentationSortDirection: Hashable, Sendable {
    case ascending
    case descending
}

nonisolated struct TransactionPresentationSortSpec: Equatable, Sendable {
    var key: TransactionPresentationSortKey = .statementDate
    var direction: TransactionPresentationSortDirection = .descending
}

nonisolated enum TransactionPresentationAvailability: Equatable, Sendable {
    case loading
    case available
    case unavailable
}

nonisolated enum TransactionPresentationResultState: Equatable, Sendable {
    case ready
    case validEmpty
    case invalidAmountCurrencySelection
    case invalidAmountRange
    case invalidStatementDateRange
    case invalidSelection
    case invalidUnknownDomainOrEffectRestriction
    case unavailable
}

nonisolated struct TransactionPresentationExclusionCounts: Equatable, Sendable {
    var search = 0
    var account = 0
    var currency = 0
    var category = 0
    var domain = 0
    var effect = 0
    var institution = 0
    var amount = 0
    var period = 0

    var total: Int {
        search + account + currency + category + domain + effect + institution + amount + period
    }
}

nonisolated struct TransactionPresentationTotalKey: Hashable, Sendable {
    let currency: CurrencyCode
    let domain: TransactionPresentationDomain
    let effect: TransactionPresentationEffect
}

nonisolated struct TransactionPresentationTotals: Equatable {
    let partitions: [TransactionPresentationTotalKey: Money]
    let withheldUnknownDomainCount: Int
    let withheldUnknownEffectCount: Int

    static let empty = TransactionPresentationTotals(
        partitions: [:],
        withheldUnknownDomainCount: 0,
        withheldUnknownEffectCount: 0
    )
}

nonisolated struct TransactionPresentationRow: Identifiable {
    let transaction: Transaction
    let stableID: String
    let accountID: String?
    let accountDisplayName: String
    let accountIdentityDisplay: String
    let institutionDisplayName: String
    let currentCategory: TransactionPresentationCategoryChoice
    let currentCategoryDisplayName: String
    let domain: TransactionPresentationDomain
    let effect: TransactionPresentationEffect
    let sourceCivilDate: StatementDate?

    var id: String { stableID }
}

nonisolated struct TransactionPresentationResult {
    let state: TransactionPresentationResultState
    let rows: [TransactionPresentationRow]
    let totals: TransactionPresentationTotals
    let exclusions: TransactionPresentationExclusionCounts

    static let unavailable = TransactionPresentationResult(
        state: .unavailable,
        rows: [],
        totals: .empty,
        exclusions: .init()
    )
}

nonisolated enum TransactionPresentationText {
    private static let locale = Locale(identifier: "en_US_POSIX")

    static func normalized(_ value: String) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

nonisolated enum TransactionPresentationEngine {
    static func row(
        for transaction: Transaction,
        accountsByID: [String: Account],
        categoriesByID: [String: Category],
        assignments: [String: String]
    ) -> TransactionPresentationRow {
        let account = transaction.repositoryAccountId.flatMap { accountsByID[$0] }
        let accountDisplayName = account?.name ?? "Unavailable"
        let institutionDisplayName = account?.institution ?? "Unavailable"
        let categoryID = transaction.repositoryTransactionId.flatMap { assignments[$0] }
        let category = categoryID.flatMap { categoriesByID[$0] }
        let categoryChoice = categoryID.map(TransactionPresentationCategoryChoice.categoryID) ?? .uncategorized
        let categoryDisplayName: String
        if categoryID == nil {
            categoryDisplayName = "Uncategorized"
        } else {
            categoryDisplayName = category?.name ?? "Unavailable"
        }

        let domain: TransactionPresentationDomain
        if transaction.cardLiabilityEffect != nil || account?.type == .creditCard {
            domain = .card
        } else if account?.type == .bank {
            domain = .bank
        } else {
            domain = .unknown
        }

        let effect: TransactionPresentationEffect
        switch domain {
        case .card:
            switch transaction.cardLiabilityEffect {
            case .increasesAmountOwed: effect = .increasesAmountOwed
            case .decreasesAmountOwed: effect = .decreasesAmountOwed
            case nil: effect = .unknown
            }
        case .bank:
            if transaction.creditMoney != nil, transaction.debitMoney == nil { effect = .credit }
            else if transaction.debitMoney != nil, transaction.creditMoney == nil { effect = .debit }
            else { effect = .unknown }
        case .unknown:
            effect = .unknown
        }
        let stableID: String
        if let durable = transaction.repositoryTransactionId, !durable.isEmpty {
            stableID = "durable:" + durable
        } else {
            stableID = "runtime:" + transaction.id.uuidString.lowercased()
        }
        return TransactionPresentationRow(
            transaction: transaction,
            stableID: stableID,
            accountID: transaction.repositoryAccountId,
            accountDisplayName: accountDisplayName,
            accountIdentityDisplay: account?.identitySummaries.map(\.redactedValue).sorted().joined(separator: ", ") ?? "",
            institutionDisplayName: institutionDisplayName,
            currentCategory: categoryChoice,
            currentCategoryDisplayName: categoryDisplayName,
            domain: domain,
            effect: effect,
            sourceCivilDate: transaction.statementDate
        )
    }

    static func rows(
        transactions: [Transaction],
        accounts: [Account],
        categories: [Category],
        assignments: [String: String]
    ) -> [TransactionPresentationRow] {
        let accountsByID = Dictionary(uniqueKeysWithValues: accounts.compactMap { account in
            account.repositoryAccountId.map { ($0, account) }
        })
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        return transactions.map {
            row(for: $0, accountsByID: accountsByID, categoriesByID: categoriesByID, assignments: assignments)
        }
    }

    static func evaluate(
        transactions: [Transaction],
        accounts: [Account],
        categories: [Category],
        assignments: [String: String],
        filter: TransactionPresentationFilterSpec,
        sort: TransactionPresentationSortSpec,
        availability: TransactionPresentationAvailability
    ) -> TransactionPresentationResult {
        guard availability == .available else { return .unavailable }
        guard filter.amountRange?.isValid ?? true else {
            return invalid(.invalidAmountRange)
        }
        guard filter.amountRange == nil || filter.currencies.count == 1 else {
            return invalid(.invalidAmountCurrencySelection)
        }
        guard filter.statementDateRange?.isValid ?? true else {
            return invalid(.invalidStatementDateRange)
        }
        guard !filter.domains.contains(.unknown), !filter.effects.contains(.unknown) else {
            return invalid(.invalidUnknownDomainOrEffectRestriction)
        }

        let allRows = rows(
            transactions: transactions,
            accounts: accounts,
            categories: categories,
            assignments: assignments
        )
        guard selectionIsKnown(filter: filter, rows: allRows, accounts: accounts, categories: categories) else {
            return invalid(.invalidSelection)
        }

        let searchTokens = TransactionPresentationText.normalized(filter.searchText)
            .split(separator: " ")
            .map(String.init)
        let normalizedInstitutions = Set(filter.institutionDisplayNames.map(TransactionPresentationText.normalized))
        var exclusions = TransactionPresentationExclusionCounts()
        var matching = [TransactionPresentationRow]()

        for row in allRows {
            let searchable = [
                row.transaction.description,
                row.accountDisplayName,
                row.institutionDisplayName,
                row.currentCategoryDisplayName
            ]
            .map(TransactionPresentationText.normalized)
            .joined(separator: " ")
            guard searchTokens.allSatisfy({ searchable.contains($0) }) else {
                exclusions.search += 1; continue
            }
            guard filter.accountIDs.isEmpty || row.accountID.map(filter.accountIDs.contains) == true else {
                exclusions.account += 1; continue
            }
            guard filter.currencies.isEmpty || filter.currencies.contains(row.transaction.money.currency) else {
                exclusions.currency += 1; continue
            }
            guard filter.categories.isEmpty || filter.categories.contains(row.currentCategory) else {
                exclusions.category += 1; continue
            }
            guard filter.domains.isEmpty || filter.domains.contains(row.domain) else {
                exclusions.domain += 1; continue
            }
            guard filter.effects.isEmpty || filter.effects.contains(row.effect) else {
                exclusions.effect += 1; continue
            }
            guard normalizedInstitutions.isEmpty || normalizedInstitutions.contains(TransactionPresentationText.normalized(row.institutionDisplayName)) else {
                exclusions.institution += 1; continue
            }
            guard filter.amountRange?.contains(row.transaction.money.amount) ?? true else {
                exclusions.amount += 1; continue
            }

            let matchesMonth: Bool
            if filter.statementMonths.isEmpty {
                matchesMonth = true
            } else if let date = row.sourceCivilDate,
                      let month = try? SelectedStatementMonth(year: date.year, month: date.month) {
                matchesMonth = filter.statementMonths.contains(month)
            } else {
                matchesMonth = false
            }
            let matchesDateRange: Bool
            if let range = filter.statementDateRange {
                matchesDateRange = row.sourceCivilDate.map(range.contains) ?? false
            } else {
                matchesDateRange = true
            }
            guard matchesMonth && matchesDateRange else {
                exclusions.period += 1; continue
            }
            matching.append(row)
        }

        matching.sort { comparison($0, $1, sort: sort) == .orderedAscending }
        let totals = totals(for: matching)
        return TransactionPresentationResult(
            state: matching.isEmpty ? .validEmpty : .ready,
            rows: matching,
            totals: totals,
            exclusions: exclusions
        )
    }

    /// This is the canonical table comparator. Equal stable identities are equal;
    /// all other ties resolve through source order and durable opaque identity.
    static func comparison(
        _ lhs: TransactionPresentationRow,
        _ rhs: TransactionPresentationRow,
        sort: TransactionPresentationSortSpec
    ) -> ComparisonResult {
        guard lhs.stableID != rhs.stableID else { return .orderedSame }

        let ordered: ComparisonResult
        let keepsUnknownLast: Bool
        switch sort.key {
        case .statementDate:
            ordered = compareOptionalDate(lhs.sourceCivilDate, rhs.sourceCivilDate)
            keepsUnknownLast = lhs.sourceCivilDate == nil || rhs.sourceCivilDate == nil
        case .description:
            ordered = compareOptionalText(lhs.transaction.description, rhs.transaction.description)
            keepsUnknownLast = isUnknownText(lhs.transaction.description) || isUnknownText(rhs.transaction.description)
        case .account:
            ordered = compareOptionalText(lhs.accountDisplayName, rhs.accountDisplayName)
            keepsUnknownLast = isUnknownText(lhs.accountDisplayName) || isUnknownText(rhs.accountDisplayName)
        case .category:
            ordered = compareOptionalText(lhs.currentCategoryDisplayName, rhs.currentCategoryDisplayName)
            keepsUnknownLast = isUnknownText(lhs.currentCategoryDisplayName) || isUnknownText(rhs.currentCategoryDisplayName)
        case .nativeAmount:
            let currencyOrder = lhs.transaction.money.currency.code.compare(rhs.transaction.money.currency.code)
            ordered = currencyOrder == .orderedSame
                ? compareDecimal(lhs.transaction.money.amount, rhs.transaction.money.amount)
                : currencyOrder
            keepsUnknownLast = false
        }

        if ordered != .orderedSame {
            if keepsUnknownLast ||
                (sort.key == .nativeAmount && lhs.transaction.money.currency.code != rhs.transaction.money.currency.code) {
                return ordered
            }
            return sort.direction == .ascending ? ordered : reverse(ordered)
        }
        return sourceAndDurableTieBreak(lhs, rhs) ? .orderedAscending : .orderedDescending
    }

    private static func invalid(_ state: TransactionPresentationResultState) -> TransactionPresentationResult {
        TransactionPresentationResult(state: state, rows: [], totals: .empty, exclusions: .init())
    }

    private static func selectionIsKnown(
        filter: TransactionPresentationFilterSpec,
        rows: [TransactionPresentationRow],
        accounts: [Account],
        categories: [Category]
    ) -> Bool {
        let accountIDs = Set(accounts.compactMap(\.repositoryAccountId))
        guard filter.accountIDs.isSubset(of: accountIDs) else { return false }

        let categoryIDs = Set(categories.map(\.id))
        for choice in filter.categories {
            if case let .categoryID(id) = choice, !categoryIDs.contains(id) {
                return false
            }
        }

        let currencies = Set(rows.map { $0.transaction.money.currency })
        guard filter.currencies.isSubset(of: currencies) else { return false }

        let institutions = Set(rows.compactMap { row -> String? in
            guard row.accountID != nil else { return nil }
            let normalized = TransactionPresentationText.normalized(row.institutionDisplayName)
            return normalized.isEmpty || normalized == "unavailable" ? nil : normalized
        })
        let selectedInstitutions = Set(filter.institutionDisplayNames.map(TransactionPresentationText.normalized))
        return !selectedInstitutions.contains(where: { $0.isEmpty || !institutions.contains($0) })
    }

    private static func totals(for rows: [TransactionPresentationRow]) -> TransactionPresentationTotals {
        var buckets = [TransactionPresentationTotalKey: [Money]]()
        var withheldUnknownDomainCount = 0
        var withheldUnknownEffectCount = 0
        for row in rows {
            guard row.domain != .unknown else {
                withheldUnknownDomainCount += 1
                continue
            }
            guard row.effect != .unknown else {
                withheldUnknownEffectCount += 1
                continue
            }
            let key = TransactionPresentationTotalKey(
                currency: row.transaction.money.currency,
                domain: row.domain,
                effect: row.effect
            )
            buckets[key, default: []].append(row.transaction.money)
        }
        let partitions = Dictionary(uniqueKeysWithValues: buckets.map { key, monies in
            let zero = try! Money(amount: .zero, currency: key.currency)
            return (key, try! Money.aggregate(monies + [zero]))
        })
        return TransactionPresentationTotals(
            partitions: partitions,
            withheldUnknownDomainCount: withheldUnknownDomainCount,
            withheldUnknownEffectCount: withheldUnknownEffectCount
        )
    }

    private static func compareOptionalDate(_ lhs: StatementDate?, _ rhs: StatementDate?) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil): return .orderedSame
        case (nil, .some): return .orderedDescending
        case (.some, nil): return .orderedAscending
        case let (.some(lhs), .some(rhs)):
            if lhs == rhs { return .orderedSame }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        }
    }

    private static func compareOptionalText(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let normalizedLeft = TransactionPresentationText.normalized(lhs)
        let normalizedRight = TransactionPresentationText.normalized(rhs)
        let left = isUnknownText(lhs) ? nil : normalizedLeft
        let right = isUnknownText(rhs) ? nil : normalizedRight
        switch (left, right) {
        case (nil, nil): return .orderedSame
        case (nil, .some): return .orderedDescending
        case (.some, nil): return .orderedAscending
        case let (.some(left), .some(right)):
            return left.compare(right, options: [], range: nil, locale: Locale(identifier: "en_US_POSIX"))
        }
    }

    private static func isUnknownText(_ value: String) -> Bool {
        let normalized = TransactionPresentationText.normalized(value)
        return normalized.isEmpty || normalized == "unavailable"
    }

    private static func reverse(_ result: ComparisonResult) -> ComparisonResult {
        switch result {
        case .orderedAscending: return .orderedDescending
        case .orderedDescending: return .orderedAscending
        case .orderedSame: return .orderedSame
        @unknown default: return .orderedSame
        }
    }

    private static func compareDecimal(_ lhs: Decimal, _ rhs: Decimal) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private static func sourceAndDurableTieBreak(_ lhs: TransactionPresentationRow, _ rhs: TransactionPresentationRow) -> Bool {
        let leftSource = lhs.transaction.documentScopedSourceOrder
        let rightSource = rhs.transaction.documentScopedSourceOrder
        if let leftSource, let rightSource, leftSource.documentID == rightSource.documentID,
           leftSource.ordinal != rightSource.ordinal {
            return leftSource.ordinal < rightSource.ordinal
        }
        let leftDocument = lhs.transaction.repositoryDocumentId ?? leftSource?.documentID ?? ""
        let rightDocument = rhs.transaction.repositoryDocumentId ?? rightSource?.documentID ?? ""
        let documentOrder = leftDocument.compare(rightDocument)
        if documentOrder != .orderedSame { return documentOrder == .orderedAscending }
        return lhs.stableID < rhs.stableID
    }
}

final class TransactionListViewModel: ObservableObject {

    @Published private(set) var transactions: [Transaction] = []

    @Published var searchText: String = ""
    @Published var showOnlyCredits: Bool = false
    @Published var showOnlyDebits: Bool = false

    private let transactionStore: TransactionStore
    private let importSessionStore: ImportSessionStore
    private let accountStore: AccountStore
    private let categoryStore: CategoryStore
    private var importSessions: [RepositoryImportSession] = []
    private var accounts: [Account] = []
    private var categorySnapshot: CategorySnapshot = .empty
    private var synchronizedGeneration: ProviderGenerationToken?
    private var presentationAvailability: TransactionPresentationAvailability = .unavailable
    private var cancellables = Set<AnyCancellable>()

    /// Transient criteria, owned by presentation rather than a repository.
    @Published var presentationFilter = TransactionPresentationFilterSpec.empty {
        didSet { reconcilePresentationSelection() }
    }
    @Published var presentationSort = TransactionPresentationSortSpec() {
        didSet { reconcilePresentationSelection() }
    }
    @Published private(set) var selectedPresentationRowID: String?

    init(
        transactionStore: TransactionStore = .shared,
        importSessionStore: ImportSessionStore = .shared,
        accountStore: AccountStore = .shared,
        categoryStore: CategoryStore = .shared
    ) {
        self.transactionStore = transactionStore
        self.importSessionStore = importSessionStore
        self.accountStore = accountStore
        self.categoryStore = categoryStore
        transactions = transactionStore.transactions
        importSessions = importSessionStore.importSessions
        accounts = accountStore.accounts
        categorySnapshot = categoryStore.snapshot

        transactionStore.$transactions
            .receive(on: RunLoop.main)
            .sink { [weak self] tx in
                self?.transactions = tx
                self?.reconcilePresentationSelection()
            }
            .store(in: &cancellables)

        importSessionStore.$importSessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.importSessions = sessions
            }
            .store(in: &cancellables)

        accountStore.$accounts
            .receive(on: RunLoop.main)
            .sink { [weak self] accounts in
                guard let self else { return }
                self.objectWillChange.send()
                self.accounts = accounts
                self.reconcilePresentationSelection()
            }
            .store(in: &cancellables)

        categoryStore.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.objectWillChange.send()
                self.categorySnapshot = snapshot
                self.reconcilePresentationSelection()
            }
            .store(in: &cancellables)
    }

    /// Root-owned application availability is passed in after canonical
    /// publication. This model does not observe providers or repositories.
    func synchronizePresentation(
        generation: ProviderGenerationToken?,
        availabilityState: ApplicationDataState
    ) {
        let availability: TransactionPresentationAvailability = (availabilityState == .current || availabilityState == .empty) && generation != nil
            ? .available
            : .unavailable
        guard synchronizedGeneration != generation || presentationAvailability != availability else {
            return
        }

        objectWillChange.send()
        if synchronizedGeneration != nil, synchronizedGeneration != generation {
            selectedPresentationRowID = nil
        }
        synchronizedGeneration = generation
        presentationAvailability = availability
        reconcilePresentationSelection()
    }

    func clearPresentationCriteria() {
        presentationFilter.clearCriteria()
        reconcilePresentationSelection()
    }

    func selectPresentationRow(id: String?) {
        guard let id else {
            selectedPresentationRowID = nil
            return
        }
        selectedPresentationRowID = transactionPresentationResult.rows.contains(where: { $0.stableID == id })
            ? id
            : nil
    }

    /// The immutable, unfiltered rows for the currently available provider generation.
    /// Menu construction may use these rows without changing matching or totals.
    var allPresentationRows: [TransactionPresentationRow] {
        guard presentationAvailability == .available else { return [] }
        return TransactionPresentationEngine.rows(
            transactions: transactions,
            accounts: accounts,
            categories: categorySnapshot.categories,
            assignments: categorySnapshot.assignments
        )
    }

    var transactionPresentationResult: TransactionPresentationResult {
        TransactionPresentationEngine.evaluate(
            transactions: transactions,
            accounts: accounts,
            categories: categorySnapshot.categories,
            assignments: categorySnapshot.assignments,
            filter: presentationFilter,
            sort: presentationSort,
            availability: presentationAvailability
        )
    }

    var selectedPresentationRow: TransactionPresentationRow? {
        guard let selectedPresentationRowID else { return nil }
        return transactionPresentationResult.rows.first { $0.stableID == selectedPresentationRowID }
    }

    private func reconcilePresentationSelection() {
        guard let selectedPresentationRowID,
              transactionPresentationResult.rows.contains(where: { $0.stableID == selectedPresentationRowID }) else {
            self.selectedPresentationRowID = nil
            return
        }
    }

    private var legacyPresentationResult: TransactionPresentationResult {
        var filter = TransactionPresentationFilterSpec.empty
        filter.searchText = searchText
        if showOnlyCredits != showOnlyDebits {
            filter.effects = [showOnlyCredits ? .credit : .debit]
        }
        return TransactionPresentationEngine.evaluate(
            transactions: transactions,
            accounts: accounts,
            categories: categorySnapshot.categories,
            assignments: categorySnapshot.assignments,
            filter: filter,
            sort: .init(),
            availability: .available
        )
    }

    func validationPresentation(for transaction: Transaction) -> TransactionValidationPresentation? {
        guard let sessionID = transaction.repositoryImportSessionId,
              let session = importSessions.first(where: { $0.id == sessionID }) else {
            return nil
        }
        return TransactionValidationPresentation(validationStatus: session.validationStatus)
    }

    func detailPresentation(for transaction: Transaction) -> TransactionDetailPresentation {
        let unavailable = "Unavailable"
        let hasAccountRelationship = transaction.repositoryAccountId != nil
        let accountName = hasAccountRelationship
            ? nonempty(transaction.account) ?? unavailable
            : unavailable
        let institution = hasAccountRelationship
            ? nonempty(transaction.sourceBank) ?? unavailable
            : unavailable

        let matchingSession = transaction.repositoryImportSessionId.flatMap { sessionID -> RepositoryImportSession? in
            let matches = importSessions.filter { $0.id == sessionID }
            guard matches.count == 1 else { return nil }
            return matches[0]
        }
        let sourceDocumentName = nonempty(transaction.repositoryPreferredSourceDocumentName)
            ?? nonempty(transaction.repositorySourceDocumentName)
            ?? unavailable

        let importedAt = matchingSession.flatMap { session in
            strictISO8601Date(session.completedAtISO ?? session.startedAtISO)
        }
        let importedAtText = importedAt?.formatted(date: .abbreviated, time: .shortened) ?? unavailable
        let validation = matchingSession.flatMap {
            TransactionValidationPresentation(validationStatus: $0.validationStatus)
        }
        let statementDate = transaction.statementDate?.presentation ?? unavailable
        let statementDateRole = transaction.statementDate == nil
            ? unavailable
            : Self.dateRoleTitle(transaction.financialDateRole)
        let direction: String
        if transaction.cardLiabilityEffect == .increasesAmountOwed {
            direction = "Charge / increase owed"
        } else if transaction.cardLiabilityEffect == .decreasesAmountOwed {
            direction = "Payment or credit / decrease owed"
        } else if transaction.creditMoney != nil, transaction.debitMoney == nil {
            direction = "Credit"
        } else if transaction.debitMoney != nil, transaction.creditMoney == nil {
            direction = "Debit"
        } else {
            direction = unavailable
        }
        let runningBalance = transaction.runningBalanceMoney.map { MoneyFormatting.display($0) } ?? unavailable
        let availabilityInputs = [
            accountName != unavailable,
            institution != unavailable,
            sourceDocumentName != unavailable,
            importedAt != nil,
            validation != nil
        ]
        let availability: TransactionProvenanceAvailability
        if availabilityInputs.allSatisfy({ $0 }) {
            availability = .complete
        } else if availabilityInputs.contains(true) {
            availability = .partial
        } else {
            availability = .unavailable
        }
        let signedAmount = MoneyFormatting.display(transaction.money)
        let accessibilityText = [
            "Transaction \(transaction.description).",
            "Amount \(signedAmount).",
            "Native currency \(transaction.money.currency.code).",
            "Direction \(direction).",
            "\(statementDateRole) \(statementDate).",
            "Account \(accountName).",
            "Institution \(institution).",
            "Source document \(sourceDocumentName).",
            "Imported \(importedAtText).",
            validation?.detail ?? "Validation unavailable for this imported transaction.",
            "Balance after \(runningBalance).",
            "Import provenance \(availability.title)."
        ].joined(separator: " ")

        return TransactionDetailPresentation(
            description: transaction.description,
            signedAmount: signedAmount,
            nativeCurrency: transaction.money.currency.code,
            direction: direction,
            statementDate: statementDate,
            statementDateRole: statementDateRole,
            accountDisplayName: accountName,
            institution: institution,
            sourceDocumentName: sourceDocumentName,
            importedAt: importedAt,
            importedAtText: importedAtText,
            validation: validation,
            runningBalance: runningBalance,
            provenanceAvailability: availability,
            accessibilityText: accessibilityText
        )
    }

    private func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func strictISO8601Date(_ value: String) -> Date? {
        let formatters = [
            ISO8601DateFormatter.ledgerForgeInternetDateTime,
            ISO8601DateFormatter.ledgerForgeInternetDateTimeWithFractionalSeconds
        ]
        return formatters.lazy.compactMap { formatter -> Date? in
            guard let date = formatter.date(from: value),
                  formatter.string(from: date) == value else { return nil }
            return date
        }.first
    }

    private static func dateRoleTitle(_ role: FinancialDateRole) -> String {
        switch role {
        case .transactionDate: "Transaction date"
        case .postingDate: "Posting date"
        case .valueDate: "Value date"
        case .settlementDate: "Settlement date"
        case .tradeDate: "Trade date"
        case .statementDate: "Statement date"
        }
    }

    /// Compatibility summary for the old list. Its values now use the same
    /// matching scope as the legacy search/effect controls.
    var currencySummaries: [TransactionCurrencySummary] {
        let matchingTransactions = legacyPresentationResult.rows.map(\.transaction)
        let grouped = Dictionary(grouping: matchingTransactions, by: { $0.money.currency })
        return grouped.keys.sorted().map { currency in
            let values = grouped[currency] ?? []
            let inflow = try! Money.aggregate(values.compactMap(\.creditMoney) + [try! Money(amount: .zero, currency: currency)])
            let outflow = try! Money.aggregate(values.compactMap(\.debitMoney) + [try! Money(amount: .zero, currency: currency)])
            return TransactionCurrencySummary(currency: currency, inflow: inflow, outflow: outflow)
        }
    }

    /// Compatibility accessors for single-currency consumers. Mixed values never combine.
    var totalDebits: Decimal { currencySummaries.count == 1 ? currencySummaries[0].outflow.amount : .zero }
    var totalCredits: Decimal { currencySummaries.count == 1 ? currencySummaries[0].inflow.amount : .zero }
    var closingBalance: Decimal? {
        let matchingTransactions = legacyPresentationResult.rows.map(\.transaction)
        guard Set(matchingTransactions.map(\.money.currency)).count <= 1 else { return nil }
        let dated = matchingTransactions.compactMap { transaction -> (transaction: Transaction, date: StatementDate, balance: Decimal)? in
            guard let date = transaction.statementDate,
                  let balance = transaction.runningBalanceMoney?.amount else { return nil }
            return (transaction, date, balance)
        }
        guard let latestDate = dated.map(\.date).max() else { return nil }
        let candidates = dated.filter { $0.date == latestDate }
        guard let documentID = candidates.first?.transaction.documentScopedSourceOrder?.documentID,
              candidates.allSatisfy({ $0.transaction.documentScopedSourceOrder?.documentID == documentID }) else {
            return candidates.count == 1 ? candidates.first?.balance : nil
        }
        return candidates.max(by: {
            ($0.transaction.documentScopedSourceOrder?.ordinal ?? 0) <
            ($1.transaction.documentScopedSourceOrder?.ordinal ?? 0)
        })?.balance
    }

    var filteredTransactions: [Transaction] {
        legacyPresentationResult.rows.map(\.transaction)
    }
}

private extension ISO8601DateFormatter {
    static let ledgerForgeInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let ledgerForgeInternetDateTimeWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
