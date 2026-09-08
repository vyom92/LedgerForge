//
// ZeroActivityStatementEvidence.swift
//
// Source-proven controls for a recurring statement with no transaction rows.
// This type is intentionally separate from presentation/reader models: an
// empty normalized row list is accepted only when the parser has retained
// coherent source identity, period, currency, and zero-activity controls (or
// an explicitly exhausted financial region).
//

import CryptoKit
import Foundation

/// The kind of source evidence which proves that a statement is intentionally
/// empty.  The parser, not the generic reader, chooses this value.
nonisolated enum ZeroActivityEvidenceKind: String, CaseIterable, Equatable, Sendable {
    /// The source prints opening/closing balances and debit/credit totals. All
    /// movement totals must be exactly zero and opening must equal closing.
    case printedControls = "printed_controls"
    /// The parser consumed a source-defined financial region and found no
    /// transaction rows, while retaining a non-empty marker/region descriptor.
    /// This is not a generic "nothing was found" fallback.
    case exhaustedFinancialRegion = "exhausted_financial_region"
}

/// The source-owned ordinal used to bound a completely scanned financial
/// region. The descriptor gives the carrier-specific meaning of the bound;
/// this enum prevents a line number, worksheet row, page, or tagged-table row
/// from being silently reinterpreted as another unit.
nonisolated enum FinancialRegionSourceUnit: String, CaseIterable, Equatable, Sendable {
    case line
    case row
    case page
    case taggedTableRow = "tagged_table_row"
}

nonisolated enum ZeroActivityStatementEvidenceError: Error, Equatable, LocalizedError {
    case emptyProfile
    case malformedProfileVersion
    case unsupportedProfileFormat
    case unsupportedProfileBinding
    case malformedInstitutionOrFamily
    case missingPeriod
    case conflictingTemporalEvidence
    case reversedPeriod
    case missingCurrency
    case currencyMismatch
    case missingPrintedControl
    case nonZeroMovement
    case openingClosingMismatch
    case missingExhaustedRegion
    case invalidDigest

    var errorDescription: String? {
        switch self {
        case .emptyProfile: return "Zero-activity evidence is missing its parser profile."
        case .malformedProfileVersion: return "Zero-activity evidence has a malformed parser profile version."
        case .unsupportedProfileFormat: return "Zero-activity evidence has an unsupported source format."
        case .unsupportedProfileBinding: return "The parser profile/source format is not a registered zero-activity binding."
        case .malformedInstitutionOrFamily: return "Zero-activity evidence is missing a source institution or family."
        case .missingPeriod: return "Zero-activity evidence requires an exact statement period."
        case .conflictingTemporalEvidence: return "Zero-activity evidence contains conflicting temporal authorities."
        case .reversedPeriod: return "Zero-activity evidence has a reversed statement period."
        case .missingCurrency: return "Zero-activity evidence requires a native currency."
        case .currencyMismatch: return "Zero-activity controls use conflicting currencies."
        case .missingPrintedControl: return "Printed zero-activity controls are incomplete."
        case .nonZeroMovement: return "A zero-activity statement contains a non-zero movement control."
        case .openingClosingMismatch: return "Opening and closing controls do not reconcile for zero activity."
        case .missingExhaustedRegion: return "The exhausted financial region evidence is empty."
        case .invalidDigest: return "Zero-activity semantic evidence has an invalid digest."
        }
    }
}

/// Exact source-family binding for a zero-activity candidate.  The binding is
/// deliberately data-driven and does not infer institution or format from
/// incidental text.  The list mirrors the parser profiles registered in the
/// ordinary production selector.
nonisolated struct ZeroActivityProfileBinding: Equatable, Sendable, Hashable {
    nonisolated enum TemporalEvidenceKind: String, Equatable, Sendable {
        case period
        case statementDate = "statement_date"
        case selectedStatementMonth = "selected_statement_month"
        case periodOrSelectedStatementMonth = "period_or_selected_statement_month"
    }

    let profileID: String
    let profileVersion: String
    let sourceFormatCode: String
    let institutionCode: String
    let statementFamilyCode: String
    let expectedNativeCurrencyCode: String
    let temporalEvidenceKind: TemporalEvidenceKind

    /// Persistence-facing identity constraints are part of the registered
    /// parser binding. They deliberately remain String values so this source
    /// can also compile in the narrow subprocess target without importing the
    /// app's account/domain graph.
    var accountTypeCode: String {
        statementFamilyCode.hasSuffix(".credit-card") ? "credit_card" : "bank"
    }

    var institutionPersistenceID: String {
        switch institutionCode {
        case "axis": return "Axis Bank"
        case "hdfc": return "HDFC Bank"
        case "cbq": return "Commercial Bank of Qatar"
        case "amex": return "American Express"
        default: return ""
        }
    }

    static let all: [ZeroActivityProfileBinding] = [
        // Axis bank account profiles
        .init(profileID: "axis.bank-account.csv", profileVersion: "3", sourceFormatCode: "csv", institutionCode: "axis", statementFamilyCode: "axis.bank-account", expectedNativeCurrencyCode: "INR", temporalEvidenceKind: .period),
        .init(profileID: "axis.bank-account.pdf", profileVersion: "1", sourceFormatCode: "pdf", institutionCode: "axis", statementFamilyCode: "axis.bank-account", expectedNativeCurrencyCode: "INR", temporalEvidenceKind: .period),
        .init(profileID: "axis.bank-account.xls", profileVersion: "1", sourceFormatCode: "xls", institutionCode: "axis", statementFamilyCode: "axis.bank-account", expectedNativeCurrencyCode: "INR", temporalEvidenceKind: .period),
        // HDFC bank account profiles
        .init(profileID: "hdfc.bank-account.pdf", profileVersion: "1", sourceFormatCode: "pdf", institutionCode: "hdfc", statementFamilyCode: "hdfc.bank-account", expectedNativeCurrencyCode: "INR", temporalEvidenceKind: .period),
        .init(profileID: "hdfc.bank-account.xls", profileVersion: "1", sourceFormatCode: "xls", institutionCode: "hdfc", statementFamilyCode: "hdfc.bank-account", expectedNativeCurrencyCode: "INR", temporalEvidenceKind: .period),
        // CBQ current-account profiles
        .init(profileID: "cbq.current-account.history.pdf", profileVersion: "1", sourceFormatCode: "pdf", institutionCode: "cbq", statementFamilyCode: "cbq.current-account", expectedNativeCurrencyCode: "QAR", temporalEvidenceKind: .statementDate),
        .init(profileID: "cbq.current-account.monthly.pdf", profileVersion: "1", sourceFormatCode: "pdf", institutionCode: "cbq", statementFamilyCode: "cbq.current-account", expectedNativeCurrencyCode: "QAR", temporalEvidenceKind: .period),
        .init(profileID: "cbq.current-account.xls", profileVersion: "1", sourceFormatCode: "xls", institutionCode: "cbq", statementFamilyCode: "cbq.current-account", expectedNativeCurrencyCode: "QAR", temporalEvidenceKind: .period),
        // Credit-card statement profiles
        .init(profileID: "amex.credit-card.pdf", profileVersion: "1", sourceFormatCode: "pdf", institutionCode: "amex", statementFamilyCode: "amex.credit-card", expectedNativeCurrencyCode: "QAR", temporalEvidenceKind: .period),
        .init(profileID: "cbq.credit-card.pdf", profileVersion: "1", sourceFormatCode: "pdf", institutionCode: "cbq", statementFamilyCode: "cbq.credit-card", expectedNativeCurrencyCode: "QAR", temporalEvidenceKind: .period),
        .init(profileID: "axis.credit-card.pdf", profileVersion: "1", sourceFormatCode: "pdf", institutionCode: "axis", statementFamilyCode: "axis.credit-card", expectedNativeCurrencyCode: "INR", temporalEvidenceKind: .periodOrSelectedStatementMonth),
        .init(profileID: "axis.credit-card.xlsx", profileVersion: "1", sourceFormatCode: "xlsx", institutionCode: "axis", statementFamilyCode: "axis.credit-card", expectedNativeCurrencyCode: "INR", temporalEvidenceKind: .selectedStatementMonth)
    ]

    static func resolve(profileID: String, profileVersion: String, sourceFormatCode: String) -> Self? {
        all.first {
            $0.profileID == profileID &&
            $0.profileVersion == profileVersion &&
            $0.sourceFormatCode == sourceFormatCode
        }
    }
}

/// Parser-owned, source-proven evidence for one empty statement.  Source
/// packaging (carrier, profile, evidence kind, document/session and raw
/// fingerprint) remains provenance; the semantic digest intentionally omits
/// all of those dimensions so equivalent cross-format representations can be
/// compared by their financial meaning.
nonisolated struct ZeroActivityStatementEvidence: Equatable, Sendable {
    static let semanticDigestAlgorithm = "ledgerforge.zero-activity-semantic.sha256.v1"

    let institutionCode: String
    let statementFamilyCode: String
    let profileID: String
    let profileVersion: String
    let sourceFormatCode: String
    let evidenceKind: ZeroActivityEvidenceKind
    let financialRegionDescriptor: String?
    let financialRegionSourceUnit: FinancialRegionSourceUnit?
    /// Inclusive source-unit bounds for an exhausted financial region. They
    /// are parser-owned provenance, not part of semantic identity.
    let financialRegionStartOrdinal: Int?
    let financialRegionEndOrdinal: Int?
    /// Digest of the complete normalized financial region (including inert
    /// labels which the family grammar consumed).  The parser computes this
    /// over source evidence; it is not a user-entered marker.
    let financialRegionSignature: String?
    let statementDate: StatementDate?
    let statementPeriod: DeclaredStatementPeriod?
    let selectedStatementMonth: SelectedStatementMonth?
    let nativeCurrency: CurrencyCode
    let openingBalance: Money?
    let closingBalance: Money?
    let debitTotal: Money?
    let creditTotal: Money?
    /// Card controls retain their printed liability roles. They must never be
    /// re-labelled as bank opening/closing or debit/credit controls merely to
    /// fit the shared zero-activity envelope.
    let cardPreviousBalance: Money?
    let cardTotalPaymentDue: Money?
    let cardPaymentDueDate: StatementDate?
    let semanticDigest: String

    init(
        profileID: String,
        profileVersion: String,
        sourceFormatCode: String,
        evidenceKind: ZeroActivityEvidenceKind,
        financialRegionDescriptor: String? = nil,
        financialRegionSourceUnit: FinancialRegionSourceUnit? = nil,
        financialRegionStartOrdinal: Int? = nil,
        financialRegionEndOrdinal: Int? = nil,
        financialRegionSignature: String? = nil,
        statementDate: StatementDate? = nil,
        statementPeriod: DeclaredStatementPeriod? = nil,
        selectedStatementMonth: SelectedStatementMonth? = nil,
        nativeCurrency: CurrencyCode,
        openingBalance: Money? = nil,
        closingBalance: Money? = nil,
        debitTotal: Money? = nil,
        creditTotal: Money? = nil,
        cardPreviousBalance: Money? = nil,
        cardTotalPaymentDue: Money? = nil,
        cardPaymentDueDate: StatementDate? = nil,
        semanticDigest: String? = nil
    ) throws {
        guard !profileID.isEmpty, profileID == profileID.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ZeroActivityStatementEvidenceError.emptyProfile
        }
        guard !profileVersion.isEmpty, profileVersion == profileVersion.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ZeroActivityStatementEvidenceError.malformedProfileVersion
        }
        guard ["pdf", "xls", "xlsx", "csv"].contains(sourceFormatCode) else {
            throw ZeroActivityStatementEvidenceError.unsupportedProfileFormat
        }
        guard let binding = ZeroActivityProfileBinding.resolve(
            profileID: profileID,
            profileVersion: profileVersion,
            sourceFormatCode: sourceFormatCode
        ) else {
            throw ZeroActivityStatementEvidenceError.unsupportedProfileBinding
        }
        guard !binding.institutionCode.isEmpty, !binding.statementFamilyCode.isEmpty else {
            throw ZeroActivityStatementEvidenceError.malformedInstitutionOrFamily
        }
        guard (try? CurrencyCatalog.shared.definition(for: nativeCurrency)) != nil else {
            throw ZeroActivityStatementEvidenceError.missingCurrency
        }
        guard nativeCurrency.code == binding.expectedNativeCurrencyCode else {
            throw ZeroActivityStatementEvidenceError.currencyMismatch
        }
        if let statementPeriod {
            guard statementPeriod.start <= statementPeriod.end else {
                throw ZeroActivityStatementEvidenceError.reversedPeriod
            }
        }
        switch binding.temporalEvidenceKind {
        case .period:
            guard statementPeriod != nil, selectedStatementMonth == nil else {
                throw statementPeriod == nil
                    ? ZeroActivityStatementEvidenceError.missingPeriod
                    : ZeroActivityStatementEvidenceError.conflictingTemporalEvidence
            }
        case .statementDate:
            guard statementPeriod == nil, statementDate != nil, selectedStatementMonth == nil else {
                throw statementDate == nil
                    ? ZeroActivityStatementEvidenceError.missingPeriod
                    : ZeroActivityStatementEvidenceError.conflictingTemporalEvidence
            }
        case .selectedStatementMonth:
            guard statementPeriod == nil, statementDate == nil, selectedStatementMonth != nil else {
                throw selectedStatementMonth == nil
                    ? ZeroActivityStatementEvidenceError.missingPeriod
                    : ZeroActivityStatementEvidenceError.conflictingTemporalEvidence
            }
        case .periodOrSelectedStatementMonth:
            let hasPeriod = statementPeriod != nil
            let hasSelectedMonth = selectedStatementMonth != nil
            guard hasPeriod != hasSelectedMonth,
                  !(hasSelectedMonth && statementDate != nil) else {
                throw !hasPeriod && !hasSelectedMonth
                    ? ZeroActivityStatementEvidenceError.missingPeriod
                    : ZeroActivityStatementEvidenceError.conflictingTemporalEvidence
            }
        }

        let controls = [openingBalance, closingBalance, debitTotal, creditTotal].compactMap { $0 }
        let cardControls = [cardPreviousBalance, cardTotalPaymentDue].compactMap { $0 }
        guard !controls.isEmpty || evidenceKind == .exhaustedFinancialRegion else {
            throw ZeroActivityStatementEvidenceError.missingPrintedControl
        }
        guard (controls + cardControls).allSatisfy({ $0.currency == nativeCurrency }) else {
            throw ZeroActivityStatementEvidenceError.currencyMismatch
        }
        if evidenceKind == .printedControls {
            guard openingBalance != nil, closingBalance != nil,
                  debitTotal != nil, creditTotal != nil else {
                throw ZeroActivityStatementEvidenceError.missingPrintedControl
            }
        }
        if let debitTotal,
           (try? debitTotal.minorUnits()) != 0,
           debitTotal.currency == nativeCurrency {
            throw ZeroActivityStatementEvidenceError.nonZeroMovement
        }
        if let creditTotal,
           (try? creditTotal.minorUnits()) != 0,
           creditTotal.currency == nativeCurrency {
            throw ZeroActivityStatementEvidenceError.nonZeroMovement
        }
        if let openingBalance, let closingBalance, openingBalance != closingBalance {
            throw ZeroActivityStatementEvidenceError.openingClosingMismatch
        }
        if binding.statementFamilyCode == "axis.credit-card" {
            guard evidenceKind == .exhaustedFinancialRegion,
                  controls.isEmpty,
                  let cardPreviousBalance,
                  let cardTotalPaymentDue,
                  cardPreviousBalance == cardTotalPaymentDue,
                  cardPaymentDueDate != nil else {
                throw ZeroActivityStatementEvidenceError.missingPrintedControl
            }
        } else if !cardControls.isEmpty || cardPaymentDueDate != nil {
            throw ZeroActivityStatementEvidenceError.unsupportedProfileBinding
        }
        let hasAnyRegionEvidence = financialRegionDescriptor != nil ||
            financialRegionSourceUnit != nil || financialRegionStartOrdinal != nil ||
            financialRegionEndOrdinal != nil || financialRegionSignature != nil
        if evidenceKind == .exhaustedFinancialRegion || hasAnyRegionEvidence {
            let region = financialRegionDescriptor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !region.isEmpty,
                  let start = financialRegionStartOrdinal,
                  let end = financialRegionEndOrdinal,
                  start > 0, end >= start,
                  let signature = financialRegionSignature,
                  signature.utf8.count == 64,
                  signature.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdef").contains($0) })
            else { throw ZeroActivityStatementEvidenceError.missingExhaustedRegion }
        }
        if binding.institutionCode == "axis", financialRegionSourceUnit == nil {
            throw ZeroActivityStatementEvidenceError.missingExhaustedRegion
        }

        self.institutionCode = binding.institutionCode
        self.statementFamilyCode = binding.statementFamilyCode
        self.profileID = profileID
        self.profileVersion = profileVersion
        self.sourceFormatCode = sourceFormatCode
        self.evidenceKind = evidenceKind
        self.financialRegionDescriptor = financialRegionDescriptor?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.financialRegionSourceUnit = financialRegionSourceUnit
        self.financialRegionStartOrdinal = financialRegionStartOrdinal
        self.financialRegionEndOrdinal = financialRegionEndOrdinal
        self.financialRegionSignature = financialRegionSignature
        self.statementDate = statementDate
        self.statementPeriod = statementPeriod
        self.selectedStatementMonth = selectedStatementMonth
        self.nativeCurrency = nativeCurrency
        self.openingBalance = openingBalance
        self.closingBalance = closingBalance
        self.debitTotal = debitTotal
        self.creditTotal = creditTotal
        self.cardPreviousBalance = cardPreviousBalance
        self.cardTotalPaymentDue = cardTotalPaymentDue
        self.cardPaymentDueDate = cardPaymentDueDate

        let calculated = Self.semanticDigest(
            institutionCode: binding.institutionCode,
            statementFamilyCode: binding.statementFamilyCode,
            statementDate: statementDate,
            statementPeriod: statementPeriod,
            selectedStatementMonth: selectedStatementMonth,
            nativeCurrency: nativeCurrency,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            cardPreviousBalance: cardPreviousBalance,
            cardTotalPaymentDue: cardTotalPaymentDue,
            cardPaymentDueDate: cardPaymentDueDate
        )
        if let semanticDigest, semanticDigest != calculated {
            throw ZeroActivityStatementEvidenceError.invalidDigest
        }
        self.semanticDigest = calculated
    }

    /// A stable semantic identity containing only financial/source meaning.
    /// Profile, source format, evidence kind, region text, carrier, document,
    /// session and fingerprint are intentionally excluded.
    /// Canonical financial cycle key used by durable uniqueness scopes.  A
    /// source-boundary date is a first-class key only for profiles whose
    /// grammar has no declared period; an optional printed date on a period
    /// profile is provenance and deliberately cannot split semantic identity.
    var semanticCycleKey: String {
        statementPeriod.map { "period:\($0.start.canonical):\($0.end.canonical)" }
            ?? selectedStatementMonth.map { "month:\($0.canonical)" }
            ?? "date:\(statementDate?.canonical ?? "")"
    }

    /// Recompute the digest at provider/hydrator boundaries.  SQLite does
    /// not have a trusted SHA-256 function, so durable code must call this
    /// value-semantic routine and compare the persisted digest explicitly.
    static func semanticDigest(
        institutionCode: String,
        statementFamilyCode: String,
        statementDate: StatementDate?,
        statementPeriod: DeclaredStatementPeriod?,
        selectedStatementMonth: SelectedStatementMonth?,
        nativeCurrency: CurrencyCode,
        openingBalance: Money?,
        closingBalance: Money?,
        debitTotal: Money?,
        creditTotal: Money?,
        cardPreviousBalance: Money?,
        cardTotalPaymentDue: Money?,
        cardPaymentDueDate: StatementDate?
    ) -> String {
        let cycleKey: String
        if let statementPeriod {
            cycleKey = "period:\(statementPeriod.start.canonical):\(statementPeriod.end.canonical)"
        } else if let selectedStatementMonth {
            cycleKey = "month:\(selectedStatementMonth.canonical)"
        } else {
            cycleKey = "date:\(statementDate?.canonical ?? "")"
        }
        let openingValue = openingBalance.flatMap { try? $0.canonicalDecimalString() } ?? ""
        let closingValue = closingBalance.flatMap { try? $0.canonicalDecimalString() } ?? ""
        let cardPreviousValue = cardPreviousBalance.flatMap { try? $0.canonicalDecimalString() } ?? ""
        let cardTotalDueValue = cardTotalPaymentDue.flatMap { try? $0.canonicalDecimalString() } ?? ""
        let fields: [String] = [
            semanticDigestAlgorithm,
            institutionCode,
            statementFamilyCode,
            cycleKey,
            nativeCurrency.code,
            openingValue,
            closingValue,
            // A parser may establish that no movement occurred either by
            // printing an explicit zero or by exhausting the complete
            // financial region.  Once that proof exists, the two accepted
            // representations have the same semantic identity.  Opening and
            // closing controls remain strict: absence there is not silently
            // promoted to a balance of zero.
            zeroMovementDigestValue(debitTotal),
            zeroMovementDigestValue(creditTotal),
            cardPreviousValue,
            cardTotalDueValue,
            cardPaymentDueDate?.canonical ?? ""
        ]
        let payload = fields.map { "\($0.utf8.count):\($0)" }.joined()
        return SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func zeroMovementDigestValue(_ money: Money?) -> String {
        guard let money else { return "0" }
        guard (try? money.minorUnits()) == 0 else { return "!invalid-zero-control" }
        return "0"
    }

    func hasValidDigest() -> Bool {
        guard let rebuilt = try? Self(
            profileID: profileID,
            profileVersion: profileVersion,
            sourceFormatCode: sourceFormatCode,
            evidenceKind: evidenceKind,
            financialRegionDescriptor: financialRegionDescriptor,
            financialRegionSourceUnit: financialRegionSourceUnit,
            financialRegionStartOrdinal: financialRegionStartOrdinal,
            financialRegionEndOrdinal: financialRegionEndOrdinal,
            financialRegionSignature: financialRegionSignature,
            statementDate: statementDate,
            statementPeriod: statementPeriod,
            selectedStatementMonth: selectedStatementMonth,
            nativeCurrency: nativeCurrency,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            cardPreviousBalance: cardPreviousBalance,
            cardTotalPaymentDue: cardTotalPaymentDue,
            cardPaymentDueDate: cardPaymentDueDate
        ) else { return false }
        return rebuilt.semanticDigest == semanticDigest
    }
}

#if !SUBPROCESS_PROBE
enum ZeroActivityStatementValidator {
    /// Validation at the parser/validator boundary. A zero evidence payload is
    /// never accepted solely because `rows` is empty: the parser must attach a
    /// typed evidence object, and no normalized financial row may remain.
    static func validate(
        financialDocument: FinancialDocument,
        rowsRead: Int = 0
    ) -> ImportValidationResult {
        guard financialDocument.transactions.isEmpty,
              let evidence = financialDocument.zeroActivityEvidence,
              let binding = ZeroActivityProfileBinding.resolve(
                  profileID: evidence.profileID,
                  profileVersion: evidence.profileVersion,
                  sourceFormatCode: evidence.sourceFormatCode
              ),
              evidence.hasValidDigest(),
              financialDocument.bookedCurrency == evidence.nativeCurrency,
              financialDocument.declaredStatementPeriod == evidence.statementPeriod,
              actualSourceFormatCode(for: financialDocument.metadata.fileFormat) == evidence.sourceFormatCode,
              institutionCode(for: financialDocument.metadata.institution) == evidence.institutionCode,
              accountTypeCode(for: financialDocument.metadata.documentType) == binding.accountTypeCode,
              financialDocument.parserProfileID == evidence.profileID,
              financialDocument.parserProfileVersion == evidence.profileVersion,
              sourceEvidenceMatches(financialDocument: financialDocument, evidence: evidence) else {
            return ImportValidationResult(
                rowsRead: rowsRead,
                transactionsParsed: 0,
                statementCurrency: financialDocument.bookedCurrency,
                debitTotalMoney: nil,
                creditTotalMoney: nil,
                openingBalanceMoney: nil,
                closingBalanceMoney: nil,
                passed: false,
                issues: [ValidationIssue(
                    severity: .error,
                    rowNumber: nil,
                    message: "Zero-activity source evidence is missing, contradictory, or not owned by the parser profile."
                )]
            )
        }
        return ImportValidationResult(
            rowsRead: rowsRead,
            transactionsParsed: 0,
            statementCurrency: evidence.nativeCurrency,
            debitTotalMoney: evidence.debitTotal,
            creditTotalMoney: evidence.creditTotal,
            openingBalanceMoney: evidence.openingBalance,
            closingBalanceMoney: evidence.closingBalance,
            passed: true,
            issues: []
        )
    }

    private static func institutionCode(for institution: Institution) -> String? {
        switch institution {
        case .axis: return "axis"
        case .hdfc: return "hdfc"
        case .cbq: return "cbq"
        case .amex: return "amex"
        case .unknown: return nil
        }
    }

    private static func actualSourceFormatCode(for format: FileFormat) -> String? {
        switch format {
        case .pdf: return "pdf"
        case .xls: return "xls"
        case .csv: return "csv"
        case .xlsx: return "xlsx"
        case .unknown: return nil
        }
    }

    private static func accountTypeCode(for documentType: DocumentType) -> String? {
        switch documentType {
        case .bankAccount: return "bank"
        case .creditCard: return "credit_card"
        case .salarySlip, .investment, .tax, .unknown: return nil
        }
    }

    private static func sourceEvidenceMatches(
        financialDocument: FinancialDocument,
        evidence: ZeroActivityStatementEvidence
    ) -> Bool {
        if let sourceEvidence = financialDocument.sourceStatementEvidence {
            return evidence.selectedStatementMonth == nil &&
                actualSourceFormatCode(for: sourceEvidence.sourceFormatCode) == evidence.sourceFormatCode &&
                sourceEvidence.period == evidence.statementPeriod &&
                sourceEvidence.statementBoundaryDate == evidence.statementDate &&
                sourceEvidence.openingBalance == evidence.openingBalance &&
                sourceEvidence.closingBalance == evidence.closingBalance
        }
        // Card profiles carry the same parser-owned temporal controls in their
        // typed card evidence rather than SourceStatementEvidence.  Keep this
        // branch exact; it is not a fallback based on a filename or parser
        // display name.
        if let cardEvidence = financialDocument.cardStatementEvidence {
            let temporalEvidenceMatches =
                cardEvidence.declaredStatementPeriod == evidence.statementPeriod &&
                cardEvidence.statementDate == evidence.statementDate &&
                cardEvidence.selectedStatementMonth == evidence.selectedStatementMonth
            guard temporalEvidenceMatches else { return false }
            if evidence.statementFamilyCode == "axis.credit-card" {
                return cardEvidence.summary(code: "previous_balance")?.money == evidence.cardPreviousBalance &&
                    cardEvidence.summary(code: "axis_total_payment_due")?.money == evidence.cardTotalPaymentDue &&
                    cardEvidence.summary(code: "due_date")?.date == evidence.cardPaymentDueDate
            }
            return evidence.cardPreviousBalance == nil &&
                evidence.cardTotalPaymentDue == nil && evidence.cardPaymentDueDate == nil
        }
        return false
    }

    /// Existing CBQ source evidence used profile-derived labels before the
    /// zero-activity contract made actual format codes durable.  Accept those
    /// labels only as a compatibility read; newly persisted controls always
    /// carry the actual `pdf`/`xls` code.
    private static func actualSourceFormatCode(for sourceFormatCode: String) -> String? {
        switch sourceFormatCode.lowercased() {
        case "pdf", "monthly-pdf", "history-pdf": return "pdf"
        case "xls", "history-xls": return "xls"
        case "csv": return "csv"
        case "xlsx": return "xlsx"
        default: return nil
        }
    }
}
#endif
