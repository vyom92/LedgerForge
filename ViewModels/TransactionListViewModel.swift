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

final class TransactionListViewModel: ObservableObject {

    @Published private(set) var transactions: [Transaction] = []

    @Published var searchText: String = ""
    @Published var showOnlyCredits: Bool = false
    @Published var showOnlyDebits: Bool = false

    private let transactionStore: TransactionStore
    private let importSessionStore: ImportSessionStore
    private var importSessions: [RepositoryImportSession] = []
    private var cancellables = Set<AnyCancellable>()

    init(
        transactionStore: TransactionStore = .shared,
        importSessionStore: ImportSessionStore = .shared
    ) {
        self.transactionStore = transactionStore
        self.importSessionStore = importSessionStore
        transactions = transactionStore.transactions
        importSessions = importSessionStore.importSessions

        transactionStore.$transactions
            .receive(on: RunLoop.main)
            .sink { [weak self] tx in
                self?.transactions = tx
            }
            .store(in: &cancellables)

        importSessionStore.$importSessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.importSessions = sessions
            }
            .store(in: &cancellables)
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
        if transaction.creditMoney != nil, transaction.debitMoney == nil {
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
        let signedAmount = transaction.signedAmountDisplay
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

    var currencySummaries: [TransactionCurrencySummary] {
        let grouped = Dictionary(grouping: transactions, by: { $0.money.currency })
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
        guard Set(transactions.map(\.money.currency)).count <= 1 else { return nil }
        let dated = transactions.compactMap { transaction -> (transaction: Transaction, date: StatementDate, balance: Decimal)? in
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
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filterCredits = showOnlyCredits && !showOnlyDebits
        let filterDebits = showOnlyDebits && !showOnlyCredits

        return transactions.filter { transaction in
            let matchesSearch = trimmedSearch.isEmpty ||
                transaction.description.localizedCaseInsensitiveContains(trimmedSearch) ||
                transaction.account.localizedCaseInsensitiveContains(trimmedSearch) ||
                transaction.sourceBank.localizedCaseInsensitiveContains(trimmedSearch)

            let matchesType: Bool
            if filterCredits {
                matchesType = transaction.credit != nil
            } else if filterDebits {
                matchesType = transaction.debit != nil
            } else {
                matchesType = true
            }

            return matchesSearch && matchesType
        }
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
