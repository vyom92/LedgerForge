// LedgerForge
// FinancialDocument.swift
// Version: 0.1.0

import CryptoKit
import Foundation

enum CBQSourceIdentityObservationKind: String, CaseIterable, Equatable, Sendable {
    case maskedAccountNumber = "cbq_masked_account_number"
    case maskedIBAN = "cbq_masked_iban"
}

/// Typed, partial identity printed by an approved CBQ monthly statement. It is
/// source evidence only: callers must never promote its pattern to a strong
/// `FinancialIdentifier` or persist it in `account_identifiers`.
struct CBQSourceIdentityObservation: Equatable, Sendable {
    enum ValidationError: Error, Equatable {
        case unsupportedKind
        case malformedPattern
        case noUnknownPosition
    }

    let kind: CBQSourceIdentityObservationKind
    let pattern: String

    init(kind: CBQSourceIdentityObservationKind, rawPattern: String) throws {
        let normalized = Self.normalize(rawPattern)
        let expectedLength = kind == .maskedAccountNumber ? 13 : 29
        let validCharacters = kind == .maskedAccountNumber
            ? normalized.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "X") })
            : normalized.allSatisfy({ $0.isASCII && ($0.isNumber || $0.isLetter) })
        guard normalized.count == expectedLength, validCharacters else {
            throw ValidationError.malformedPattern
        }
        guard normalized.contains("X") else { throw ValidationError.noUnknownPosition }
        if kind == .maskedIBAN {
            guard normalized.hasPrefix("QA"),
                  normalized.dropFirst(2).prefix(2).allSatisfy(\.isNumber),
                  normalized.dropFirst(4).prefix(4) == "CBQA" else {
                throw ValidationError.malformedPattern
            }
        }
        self.kind = kind
        self.pattern = normalized
    }

    static func validatePair(_ observations: [CBQSourceIdentityObservation]) -> Bool {
        let accounts = observations.filter { $0.kind == .maskedAccountNumber }
        let ibans = observations.filter { $0.kind == .maskedIBAN }
        guard accounts.count == 1, ibans.count == 1 else { return false }
        return String(ibans[0].pattern.suffix(13)) == accounts[0].pattern
    }

    func isCompatible(withFullAccountNumber candidate: String) -> Bool {
        let full = Self.normalize(candidate)
        let comparedPattern: String
        switch kind {
        case .maskedAccountNumber:
            guard full.count == 13, full.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
            comparedPattern = pattern
        case .maskedIBAN:
            guard full.count == 13, full.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
            comparedPattern = String(pattern.suffix(13))
        }
        return zip(comparedPattern, full).allSatisfy { mask, digit in
            mask == "X" || mask == digit
        }
    }

    private static func normalize(_ value: String) -> String {
        value.uppercased().filter { character in
            if character == "X" || character == "*" { return true }
            return character.isNumber || character.isLetter
        }.map { $0 == "*" ? "X" : $0 }.reduce(into: "") { $0.append($1) }
    }
}

struct SourceStatementEvidence: Equatable, Sendable {
    let sourceFormatCode: String
    let statementBoundaryDate: StatementDate?
    let period: DeclaredStatementPeriod?
    let openingBalance: Money?
    let closingBalance: Money?
}

struct DeclaredStatementPeriod: Equatable, Sendable {
    let start: StatementDate
    let end: StatementDate

    enum Error: Swift.Error, Equatable {
        case reversed
    }

    init(start: StatementDate, end: StatementDate) throws {
        guard start <= end else { throw Error.reversed }
        self.start = start
        self.end = end
    }
}

enum CardSourceIdentityObservationKind: String, CaseIterable, Equatable, Sendable, Codable {
    case liabilityMembershipNumber = "amex_membership_number"
    case instrumentCardAccountNumber = "amex_card_account_number"
    case cbqLiabilityAccountReference = "cbq_card_account_reference"
    case cbqInstrumentMaskedCardNumber = "cbq_masked_card_number"
}

enum CardSourceIdentitySubject: String, CaseIterable, Equatable, Sendable, Codable {
    case liabilityAccount = "liability_account"
    case instrument
}

/// Exact parser-produced source observation. A masked value remains weak
/// evidence and is never promoted to a `FinancialIdentifier`.
struct CardSourceIdentityObservation: Equatable, Sendable {
    let kind: CardSourceIdentityObservationKind
    let subject: CardSourceIdentitySubject
    let value: String

    init(kind: CardSourceIdentityObservationKind, subject: CardSourceIdentitySubject, value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedSubject: CardSourceIdentitySubject
        let isValidValue: Bool
        switch kind {
        case .liabilityMembershipNumber:
            expectedSubject = .liabilityAccount
            isValidValue = trimmed.range(of: #"^[0-9X-]+$"#, options: .regularExpression) != nil && trimmed.contains("X")
        case .instrumentCardAccountNumber:
            expectedSubject = .instrument
            isValidValue = trimmed.range(of: #"^[0-9X-]+$"#, options: .regularExpression) != nil && trimmed.contains("X")
        case .cbqLiabilityAccountReference:
            expectedSubject = .liabilityAccount
            isValidValue = trimmed.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil
        case .cbqInstrumentMaskedCardNumber:
            expectedSubject = .instrument
            isValidValue = trimmed.range(of: #"^[0-9X]+$"#, options: .regularExpression) != nil &&
                trimmed.contains("X") && trimmed.contains(where: \.isNumber)
        }
        guard subject == expectedSubject, !trimmed.isEmpty, isValidValue else {
            throw CardStatementEvidenceError.malformedIdentityObservation
        }
        self.kind = kind
        self.subject = subject
        self.value = trimmed
    }
}

enum CardTransactionScope: Equatable, Sendable {
    case accountLevel
    case instrument

    var persistenceCode: String {
        switch self {
        case .accountLevel: return "account_level"
        case .instrument: return "instrument_level"
        }
    }
}

struct CardInstrumentSectionEvidence: Equatable, Sendable {
    let documentScopedSectionID: String
    let sourceOrdinal: Int
    let holderLabel: String?
    let sourceIdentityObservations: [CardSourceIdentityObservation]
    let signedNetTotal: Money
    let reconciliationRuleIdentifier: String

    static let amexSignedNetRule = "amex.section.signed-increases-minus-decreases.v1"
    static let cbqSignedSourceMembershipRule = "cbq.section.signed-source-membership.v1"

    init(
        documentScopedSectionID: String,
        sourceOrdinal: Int,
        holderLabel: String?,
        sourceIdentityObservations: [CardSourceIdentityObservation],
        signedNetTotal: Money,
        reconciliationRuleIdentifier: String = Self.amexSignedNetRule
    ) {
        self.documentScopedSectionID = documentScopedSectionID
        self.sourceOrdinal = sourceOrdinal
        let trimmedHolderLabel = holderLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.holderLabel = trimmedHolderLabel?.isEmpty == false ? trimmedHolderLabel : nil
        self.sourceIdentityObservations = sourceIdentityObservations
        self.signedNetTotal = signedNetTotal
        self.reconciliationRuleIdentifier = reconciliationRuleIdentifier
    }
}

struct CardTransactionAnnotation: Equatable, Sendable {
    let parserTransactionID: UUID
    let financialScope: CardTransactionScope
    let documentScopedSectionID: String?
    let liabilityEffect: CardLiabilityEffect
    let sourceTransactionDate: StatementDate
    let originalMerchantMoney: Money?
    let summaryMembership: CardTransactionSummaryMembership?

    init(
        parserTransactionID: UUID,
        financialScope: CardTransactionScope,
        documentScopedSectionID: String?,
        liabilityEffect: CardLiabilityEffect,
        sourceTransactionDate: StatementDate,
        originalMerchantMoney: Money?,
        summaryMembership: CardTransactionSummaryMembership? = nil
    ) {
        self.parserTransactionID = parserTransactionID
        self.financialScope = financialScope
        self.documentScopedSectionID = documentScopedSectionID
        self.liabilityEffect = liabilityEffect
        self.sourceTransactionDate = sourceTransactionDate
        self.originalMerchantMoney = originalMerchantMoney
        self.summaryMembership = summaryMembership
    }
}

enum CardStatementSummaryComponent: Equatable, Sendable {
    case previousBalance(Money)
    case newCredits(Money)
    case newDebits(Money)
    case amountBilled(Money)
    case paymentReceived(Money)
    case totalPayment(Money)
    case creditReversal(Money)
    case purchases(Money)
    case billedInstallment(Money)
    case feesCharges(Money)
    case newBalance(Money)
    case dueDate(StatementDate)
    case instrumentNetTotal(Money)
    case sourceSectionNetTotal(Money)
    case axisTotalPaymentDue(Money)

    var persistenceCode: String {
        switch self {
        case .previousBalance: return "previous_balance"
        case .newCredits: return "new_credits"
        case .newDebits: return "new_debits"
        case .amountBilled: return "amount_billed"
        case .paymentReceived: return "payment_received"
        case .totalPayment: return "total_payment"
        case .creditReversal: return "credit_reversal"
        case .purchases: return "purchases"
        case .billedInstallment: return "billed_installment"
        case .feesCharges: return "fees_charges"
        case .newBalance: return "new_balance"
        case .dueDate: return "due_date"
        case .instrumentNetTotal: return "instrument_net_total"
        case .sourceSectionNetTotal: return "source_section_net_total"
        case .axisTotalPaymentDue: return "axis_total_payment_due"
        }
    }

    var money: Money? {
        switch self {
        case .previousBalance(let value), .newCredits(let value), .newDebits(let value),
                .amountBilled(let value), .paymentReceived(let value), .totalPayment(let value),
                .creditReversal(let value), .purchases(let value), .billedInstallment(let value),
                .feesCharges(let value), .newBalance(let value), .instrumentNetTotal(let value),
                .sourceSectionNetTotal(let value), .axisTotalPaymentDue(let value): return value
        case .dueDate: return nil
        }
    }

    var date: StatementDate? {
        switch self {
        case .dueDate(let value): return value
        default: return nil
        }
    }
}

enum CardStatementEvidenceError: Error, Equatable, LocalizedError {
    case malformedIdentityObservation
    case duplicateTransactionAnnotation
    case duplicateSummaryComponent
    case invalidInstrumentSection

    var errorDescription: String? {
        switch self {
        case .malformedIdentityObservation: return "Card source identity evidence is malformed."
        case .duplicateTransactionAnnotation: return "Card transaction evidence is duplicated."
        case .duplicateSummaryComponent: return "Card statement summary evidence is duplicated."
        case .invalidInstrumentSection: return "Card instrument-section evidence is malformed."
        }
    }
}

struct CardStatementEvidence: Equatable, Sendable {
    static let amexQARReconciliationRule = "amex.qar.previous-minus-credits-plus-debits.v1"
    static let cbqV1QARReconciliationRule = "cbq.qar.v1.previous-plus-billed-minus-payment.v1"
    static let cbqV2QARReconciliationRule = "cbq.qar.v2.previous-minus-payment-minus-credit-plus-components.v1"
    static let axisINRRowLedgerReconciliationRule = "axis.inr.previous-plus-row-ledger-equals-total-due.v1"
    static let axisINRAppRowLedgerReconciliationRule = "axis.inr.app.previous-plus-row-ledger-equals-total-due.v1"

    let statementDate: StatementDate?
    let declaredStatementPeriod: DeclaredStatementPeriod?
    let selectedStatementMonth: SelectedStatementMonth?
    let nativeCurrency: CurrencyCode
    let accountSourceIdentityObservations: [CardSourceIdentityObservation]
    let instrumentSections: [CardInstrumentSectionEvidence]
    let transactionAnnotations: [CardTransactionAnnotation]
    let summaryComponents: [CardStatementSummaryComponent]
    let reconciliationRuleIdentifier: String

    init(
        statementDate: StatementDate?,
        declaredStatementPeriod: DeclaredStatementPeriod?,
        selectedStatementMonth: SelectedStatementMonth? = nil,
        nativeCurrency: CurrencyCode,
        accountSourceIdentityObservations: [CardSourceIdentityObservation],
        instrumentSections: [CardInstrumentSectionEvidence],
        transactionAnnotations: [CardTransactionAnnotation],
        summaryComponents: [CardStatementSummaryComponent],
        reconciliationRuleIdentifier: String
    ) throws {
        guard Set(transactionAnnotations.map(\.parserTransactionID)).count == transactionAnnotations.count else {
            throw CardStatementEvidenceError.duplicateTransactionAnnotation
        }
        guard Set(summaryComponents.map(\.persistenceCode)).count == summaryComponents.count else {
            throw CardStatementEvidenceError.duplicateSummaryComponent
        }
        let sectionIDs = instrumentSections.map(\.documentScopedSectionID)
        let sectionIDSet = Set(sectionIDs)
        let sectionOrdinals = instrumentSections.map(\.sourceOrdinal)
        guard !sectionIDs.contains(where: \.isEmpty), sectionIDSet.count == sectionIDs.count,
              sectionOrdinals == instrumentSections.indices.map({ $0 + 1 }),
              instrumentSections.allSatisfy({
                  $0.signedNetTotal.currency == nativeCurrency &&
                  !$0.reconciliationRuleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              }),
              instrumentSections.allSatisfy({ section in
                  !section.sourceIdentityObservations.isEmpty && section.sourceIdentityObservations.allSatisfy {
                      $0.subject == .instrument
                  }
              }),
              transactionAnnotations.allSatisfy({ annotation in
                  switch annotation.financialScope {
                  case .accountLevel:
                      return annotation.documentScopedSectionID.map(sectionIDSet.contains) ?? true
                  case .instrument:
                      return annotation.documentScopedSectionID.map(sectionIDSet.contains) == true
                  }
              }) else {
            throw CardStatementEvidenceError.invalidInstrumentSection
        }
        self.statementDate = statementDate
        self.declaredStatementPeriod = declaredStatementPeriod
        self.selectedStatementMonth = selectedStatementMonth
        self.nativeCurrency = nativeCurrency
        self.accountSourceIdentityObservations = accountSourceIdentityObservations
        self.instrumentSections = instrumentSections
        self.transactionAnnotations = transactionAnnotations
        self.summaryComponents = summaryComponents
        self.reconciliationRuleIdentifier = reconciliationRuleIdentifier
    }

    func annotation(for transaction: Transaction) -> CardTransactionAnnotation? {
        transactionAnnotations.first { $0.parserTransactionID == transaction.id }
    }

    func summary(code: String) -> CardStatementSummaryComponent? {
        summaryComponents.first { $0.persistenceCode == code }
    }
}

struct FinancialDocument: Identifiable {

    let id: UUID
    let sourceDocument: Document
    let metadata: DocumentMetadata
    let parserName: String
    /// Parser-owned booked currency; never inferred from only one transaction.
    let bookedCurrency: CurrencyCode?
    /// Exact parser-owned source period. It is never reconstructed from the
    /// first and last transaction dates.
    let declaredStatementPeriod: DeclaredStatementPeriod?
    let transactions: [Transaction]
    let financialIdentifiers: [FinancialIdentifier]
    let cbqSourceIdentityObservations: [CBQSourceIdentityObservation]
    let sourceStatementEvidence: SourceStatementEvidence?
    let cardStatementEvidence: CardStatementEvidence?
    /// Exact typed salary payload. Salary documents deliberately contain no
    /// fabricated bank transactions or Account identity.
    let salaryStatementEvidence: SalaryStatementEvidence?
    let selectionReasons: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceDocument: Document,
        metadata: DocumentMetadata,
        parserName: String,
        bookedCurrency: CurrencyCode? = nil,
        declaredStatementPeriod: DeclaredStatementPeriod? = nil,
        transactions: [Transaction],
        financialIdentifiers: [FinancialIdentifier] = [],
        cbqSourceIdentityObservations: [CBQSourceIdentityObservation] = [],
        sourceStatementEvidence: SourceStatementEvidence? = nil,
        cardStatementEvidence: CardStatementEvidence? = nil,
        salaryStatementEvidence: SalaryStatementEvidence? = nil,
        selectionReasons: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceDocument = sourceDocument
        self.metadata = metadata
        self.parserName = parserName
        self.bookedCurrency = bookedCurrency
        self.declaredStatementPeriod = declaredStatementPeriod
        self.transactions = transactions
        self.financialIdentifiers = financialIdentifiers
        self.cbqSourceIdentityObservations = cbqSourceIdentityObservations
        self.sourceStatementEvidence = sourceStatementEvidence
        self.cardStatementEvidence = cardStatementEvidence
        self.salaryStatementEvidence = salaryStatementEvidence
        self.selectionReasons = selectionReasons
        self.createdAt = createdAt
    }

}

enum StatementFinancialProjectionError: Error, Equatable, LocalizedError {
    case unsupportedDocument
    case missingStatementPeriod
    case missingCurrency
    case noEvents
    case missingStatementDate(ordinal: Int)
    case missingValueDate(ordinal: Int)
    case missingDirection(ordinal: Int)
    case ambiguousDirection(ordinal: Int)
    case missingRunningBalance(ordinal: Int)
    case currencyMismatch(ordinal: Int)
    case nonPositiveAmount(ordinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument:
            return "The statement family does not support an exact financial projection."
        case .missingStatementPeriod:
            return "An exact statement projection requires a declared statement period."
        case .missingCurrency:
            return "An exact statement projection requires a native currency."
        case .noEvents:
            return "An exact statement projection requires at least one event."
        case .missingStatementDate:
            return "An exact statement projection event is missing its statement date."
        case .missingValueDate:
            return "An exact statement projection event is missing its value date."
        case .missingDirection:
            return "An exact statement projection event is missing its direction."
        case .ambiguousDirection:
            return "An exact statement projection event has two amount directions."
        case .missingRunningBalance:
            return "An exact statement projection event is missing its running balance."
        case .currencyMismatch:
            return "An exact statement projection event has conflicting currency evidence."
        case .nonPositiveAmount:
            return "An exact statement projection event has a non-positive movement."
        }
    }
}

/// Format-neutral, account-independent financial truth for one explicitly
/// supported whole statement. The digest excludes presentation and source
/// container evidence by construction.
struct StatementFinancialProjection: Equatable, Sendable {
    static let algorithm = "ledgerforge.statement-financial-projection.sha256.v1"
    static let hdfcInstitutionCode = "hdfc"
    static let hdfcBankAccountFamilyCode = "hdfc.bank-account"

    enum Direction: String, Equatable, Sendable {
        case debit
        case credit
    }

    struct Event: Equatable, Sendable {
        let ordinal: Int
        let statementDate: StatementDate
        let valueDate: StatementDate
        let direction: Direction
        let signedAmount: Money
        let runningBalance: Money
        let reference: String?
    }

    let algorithmIdentifier: String
    let institutionCode: String
    let statementFamilyCode: String
    let statementPeriod: DeclaredStatementPeriod
    let nativeCurrency: CurrencyCode
    let eventCount: Int
    let openingBalance: Money
    let debitCount: Int
    let creditCount: Int
    let debitTotal: Money
    let creditTotal: Money
    let closingBalance: Money
    let events: [Event]
    let digest: String

    static func make(from document: FinancialDocument) throws -> StatementFinancialProjection {
        guard document.metadata.institution == .hdfc,
              document.metadata.documentType == .bankAccount,
              [.pdf, .xls].contains(document.metadata.fileFormat) else {
            throw StatementFinancialProjectionError.unsupportedDocument
        }
        guard let period = document.declaredStatementPeriod else {
            throw StatementFinancialProjectionError.missingStatementPeriod
        }
        guard let currency = document.bookedCurrency else {
            throw StatementFinancialProjectionError.missingCurrency
        }
        guard !document.transactions.isEmpty else {
            throw StatementFinancialProjectionError.noEvents
        }

        var events: [Event] = []
        var debitCount = 0
        var creditCount = 0
        var debitMinor: Int64 = 0
        var creditMinor: Int64 = 0

        for (index, transaction) in document.transactions.enumerated() {
            let ordinal = index + 1
            guard let statementDate = transaction.statementDate else {
                throw StatementFinancialProjectionError.missingStatementDate(ordinal: ordinal)
            }
            guard let valueDate = transaction.valueDate else {
                throw StatementFinancialProjectionError.missingValueDate(ordinal: ordinal)
            }
            guard let runningBalance = transaction.runningBalanceMoney else {
                throw StatementFinancialProjectionError.missingRunningBalance(ordinal: ordinal)
            }
            guard transaction.money.currency == currency,
                  runningBalance.currency == currency,
                  transaction.debitMoney.map({ $0.currency == currency }) ?? true,
                  transaction.creditMoney.map({ $0.currency == currency }) ?? true else {
                throw StatementFinancialProjectionError.currencyMismatch(ordinal: ordinal)
            }

            let direction: Direction
            let magnitude: Money
            switch (transaction.debitMoney, transaction.creditMoney) {
            case (.some(let debit), nil):
                direction = .debit
                magnitude = debit
                debitCount += 1
            case (nil, .some(let credit)):
                direction = .credit
                magnitude = credit
                creditCount += 1
            case (nil, nil):
                throw StatementFinancialProjectionError.missingDirection(ordinal: ordinal)
            case (.some, .some):
                throw StatementFinancialProjectionError.ambiguousDirection(ordinal: ordinal)
            }
            let magnitudeMinor = try magnitude.minorUnits()
            let signedMinor = try transaction.money.minorUnits()
            guard magnitudeMinor > 0 else {
                throw StatementFinancialProjectionError.nonPositiveAmount(ordinal: ordinal)
            }
            guard (direction == .debit && signedMinor == -magnitudeMinor) ||
                    (direction == .credit && signedMinor == magnitudeMinor) else {
                throw StatementFinancialProjectionError.ambiguousDirection(ordinal: ordinal)
            }
            if direction == .debit {
                let addition = debitMinor.addingReportingOverflow(magnitudeMinor)
                guard !addition.overflow else { throw MoneyError.minorUnitOverflow(currency: currency.code) }
                debitMinor = addition.partialValue
            } else {
                let addition = creditMinor.addingReportingOverflow(magnitudeMinor)
                guard !addition.overflow else { throw MoneyError.minorUnitOverflow(currency: currency.code) }
                creditMinor = addition.partialValue
            }
            events.append(
                Event(
                    ordinal: ordinal,
                    statementDate: statementDate,
                    valueDate: valueDate,
                    direction: direction,
                    signedAmount: transaction.money,
                    runningBalance: runningBalance,
                    reference: transaction.reference
                )
            )
        }

        guard let first = events.first, let last = events.last else {
            throw StatementFinancialProjectionError.noEvents
        }
        let openingBalance = try first.runningBalance - first.signedAmount
        let debitTotal = try Money.fromMinorUnits(debitMinor, currency: currency.code)
        let creditTotal = try Money.fromMinorUnits(creditMinor, currency: currency.code)
        let digest = try makeDigest(
            institutionCode: hdfcInstitutionCode,
            statementFamilyCode: hdfcBankAccountFamilyCode,
            statementPeriod: period,
            nativeCurrency: currency,
            eventCount: events.count,
            openingBalance: openingBalance,
            debitCount: debitCount,
            creditCount: creditCount,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            closingBalance: last.runningBalance,
            events: events
        )
        return StatementFinancialProjection(
            algorithmIdentifier: algorithm,
            institutionCode: hdfcInstitutionCode,
            statementFamilyCode: hdfcBankAccountFamilyCode,
            statementPeriod: period,
            nativeCurrency: currency,
            eventCount: events.count,
            openingBalance: openingBalance,
            debitCount: debitCount,
            creditCount: creditCount,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            closingBalance: last.runningBalance,
            events: events,
            digest: digest
        )
    }

    func hasValidDigest() -> Bool {
        guard algorithmIdentifier == Self.algorithm,
              eventCount == events.count,
              eventCount == debitCount + creditCount else { return false }
        return (try? Self.makeDigest(
            institutionCode: institutionCode,
            statementFamilyCode: statementFamilyCode,
            statementPeriod: statementPeriod,
            nativeCurrency: nativeCurrency,
            eventCount: eventCount,
            openingBalance: openingBalance,
            debitCount: debitCount,
            creditCount: creditCount,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            closingBalance: closingBalance,
            events: events
        )) == digest
    }

    private static func makeDigest(
        institutionCode: String,
        statementFamilyCode: String,
        statementPeriod: DeclaredStatementPeriod,
        nativeCurrency: CurrencyCode,
        eventCount: Int,
        openingBalance: Money,
        debitCount: Int,
        creditCount: Int,
        debitTotal: Money,
        creditTotal: Money,
        closingBalance: Money,
        events: [Event]
    ) throws -> String {
        var fields = [
            algorithm,
            institutionCode,
            statementFamilyCode,
            statementPeriod.start.canonical,
            statementPeriod.end.canonical,
            nativeCurrency.code,
            String(eventCount),
            try openingBalance.canonicalDecimalString(),
            String(debitCount),
            String(creditCount),
            try debitTotal.canonicalDecimalString(),
            try creditTotal.canonicalDecimalString(),
            try closingBalance.canonicalDecimalString()
        ]
        for event in events {
            fields.append(contentsOf: [
                String(event.ordinal),
                event.statementDate.canonical,
                event.valueDate.canonical,
                event.direction.rawValue,
                event.signedAmount.currency.code,
                try event.signedAmount.canonicalDecimalString(),
                event.runningBalance.currency.code,
                try event.runningBalance.canonicalDecimalString(),
                event.reference == nil ? "0" : "1",
                event.reference ?? ""
            ])
        }
        let payload = fields.map { "\($0.utf8.count):\($0)" }.joined()
        return SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
