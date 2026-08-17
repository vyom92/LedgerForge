import CryptoKit
import Foundation

enum CBQCreditCardPDFParserError: Error, Equatable, LocalizedError {
    case unsupportedDocument
    case changedHeader
    case malformedSourceEvidence
    case malformedRow(sourceOrdinal: Int)
    case unsupportedCurrency(String)
    case excessCurrencyPrecision(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument: return "The CBQ credit-card parser received an unsupported document."
        case .changedHeader: return "The normalized CBQ credit-card columns changed."
        case .malformedSourceEvidence: return "CBQ credit-card source evidence is malformed or contradictory."
        case .malformedRow(let ordinal): return "CBQ credit-card row " + String(ordinal) + " is malformed."
        case .unsupportedCurrency(let currency): return "CBQ credit-card original currency " + currency + " is unsupported."
        case .excessCurrencyPrecision(let currency): return "CBQ credit-card original currency " + currency + " has excess precision."
        }
    }
}

final class CBQCreditCardPDFParser: StatementParser {
    static let profileID = "cbq.credit-card.pdf"
    static let profileVersion = "1"
    static let v1ProfileID = "cbq.credit-card.pdf.v1"
    static let v2ProfileID = "cbq.credit-card.pdf.v2"

    var name: String { "CBQ Credit Card PDF" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .cbq && metadata.documentType == .creditCard &&
            metadata.fileFormat == .pdf && document.fileType.caseInsensitiveCompare(FileFormat.pdf.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        guard canParse(document: document.document, metadata: document.metadata) else {
            throw CBQCreditCardPDFParserError.unsupportedDocument
        }
        guard document.header?.values == CBQCreditCardPDFNormalizer.logicalHeader,
              !document.rows.isEmpty else { throw CBQCreditCardPDFParserError.changedHeader }

        let fragments = document.sourceContext.preTransactionFragments
        let profileValues = fragments.filter { $0.text.hasPrefix("PROFILE_VERSION\t") }
        guard profileValues.count == 1,
              let version = profileValues.first?.text.split(separator: "\t", omittingEmptySubsequences: false).dropFirst().first,
              (version == "v1" || version == "v2") else {
            throw CBQCreditCardPDFParserError.malformedSourceEvidence
        }
        let fields = Dictionary(grouping: fragments.compactMap(Self.fields), by: { $0[0] })
        guard let accountField = fields["CARD_ACCOUNT_REFERENCE"], accountField.count == 1,
              accountField[0].count == 2,
              let statementField = fields["STATEMENT_DATE"], statementField.count == 1,
              let periodField = fields["PERIOD"], periodField.count == 1, periodField[0].count == 3,
              let dueField = fields["DUE_DATE"], dueField.count == 1 else {
            throw CBQCreditCardPDFParserError.malformedSourceEvidence
        }

        do {
            let currency = try CurrencyCode("QAR")
            let accountReference = accountField[0][1]
            let accountObservation = try CardSourceIdentityObservation(
                kind: .cbqLiabilityAccountReference,
                subject: .liabilityAccount,
                value: accountReference
            )
            let identifier = try FinancialIdentifier(
                kind: .institutionIssuedIdentifier,
                rawValue: accountReference,
                verificationState: .verified,
                provenance: .institutionStructuredField
            )
            let statementDate = try Self.date(statementField[0][1])
            let period = try DeclaredStatementPeriod(
                start: Self.date(periodField[0][1]),
                end: Self.date(periodField[0][2])
            )
            let dueDate = try Self.date(dueField[0][1])

            let sectionFields = fields["INSTRUMENT_SECTION"] ?? []
            guard sectionFields.count == 2,
                  sectionFields.allSatisfy({ $0.count == 7 }) else {
                throw CBQCreditCardPDFParserError.malformedSourceEvidence
            }
            let sections = try sectionFields.enumerated().map { index, values -> CardInstrumentSectionEvidence in
                guard values[1] == "instrument-section-\(index + 1)",
                      values[6].isEmpty || values[6] == "CR" else {
                    throw CBQCreditCardPDFParserError.malformedSourceEvidence
                }
                let observation = try CardSourceIdentityObservation(
                    kind: .cbqInstrumentMaskedCardNumber,
                    subject: .instrument,
                    value: values[3]
                )
                let magnitude = try Self.money(values[5], currency: currency)
                let signed = try Money(amount: values[6] == "CR" ? -magnitude.amount : magnitude.amount, currency: currency)
                return CardInstrumentSectionEvidence(
                    documentScopedSectionID: values[1],
                    sourceOrdinal: index + 1,
                    holderLabel: values[4].isEmpty ? nil : values[4],
                    sourceIdentityObservations: [observation],
                    signedNetTotal: signed,
                    reconciliationRuleIdentifier: CardInstrumentSectionEvidence.cbqSignedSourceMembershipRule
                )
            }
            let sectionIDs = Set(sections.map(\.documentScopedSectionID))
            let summary = try Self.summary(fields: fields, version: String(version), currency: currency)
            var transactions: [Transaction] = []
            var annotations: [CardTransactionAnnotation] = []
            var rowVersion: String?
            for row in document.rows {
                guard row.values.count == CBQCreditCardPDFNormalizer.logicalHeader.count else {
                    throw CBQCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber)
                }
                let values = row.values
                guard let sourcePage = Int(values[10]), (1...3).contains(sourcePage),
                      values[11] == version else {
                    throw CBQCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber)
                }
                if let rowVersion, rowVersion != values[11] { throw CBQCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
                rowVersion = values[11]
                let postingDate = try Self.date(values[0])
                let purchaseDate = try Self.date(values[1])
                guard !values[2].isEmpty,
                      let effect = CardLiabilityEffect(rawValue: values[7]),
                      sectionIDs.contains(values[9]) else {
                    throw CBQCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber)
                }
                let postedMagnitude = try Self.money(values[6], currency: currency)
                guard postedMagnitude.amount > .zero else { throw CBQCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
                let signedPosted = try Money(amount: effect == .increasesAmountOwed ? postedMagnitude.amount : -postedMagnitude.amount, currency: currency)

                let original: Money?
                if values[4].isEmpty && values[5].isEmpty {
                    original = nil
                } else {
                    guard !values[4].isEmpty, !values[5].isEmpty else { throw CBQCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
                    let originalCurrency = try CurrencyCode(values[5])
                    let magnitude = try Self.money(values[4], currency: originalCurrency)
                    original = try Money(amount: effect == .increasesAmountOwed ? magnitude.amount : -magnitude.amount, currency: originalCurrency)
                }

                let expectedScope = values[2].hasPrefix("Paid using bankDirect") ? "account_level" : "instrument_level"
                guard values[8] == expectedScope else { throw CBQCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
                let scope: CardTransactionScope = values[8] == "account_level" ? .accountLevel : .instrument
                let membership: CardTransactionSummaryMembership?
                if String(version) == "v1" {
                    membership = scope == .accountLevel ? .cbqV1PaymentReceived : .cbqV1AmountBilled
                } else if effect == .decreasesAmountOwed {
                    membership = scope == .accountLevel ? .cbqV2TotalPayment : .cbqV2CreditReversal
                } else if Self.isFee(values[2]) {
                    membership = .cbqV2FeesCharges
                } else if Self.isBilledInstallment(values[2]) {
                    membership = .cbqV2BilledInstallment
                } else {
                    membership = .cbqV2Purchases
                }

                let transaction = Transaction(
                    statementDate: postingDate,
                    valueDate: nil,
                    description: values[2],
                    reference: values[3].isEmpty ? nil : values[3],
                    debitMoney: nil,
                    creditMoney: nil,
                    money: signedPosted,
                    runningBalanceMoney: nil,
                    cardLiabilityEffect: effect,
                    account: "CBQ Credit Card",
                    sourceBank: Institution.cbq.rawValue,
                    sourceFile: document.document.filename,
                    financialDateRole: .postingDate,
                    statementTimezoneEvidence: .iana("Asia/Qatar"),
                    sourceProvenance: [TransactionSourceProvenance(
                        normalizedDocumentID: document.document.id.uuidString,
                        normalizedRowID: row.id.uuidString,
                        sourceOrdinal: row.rowNumber,
                        normalizedRecordDigest: String.normalizedRecordDigest(values: values),
                        parserProfileID: Self.profileID,
                        parserProfileVersion: Self.profileVersion,
                        sourceTransactionDate: purchaseDate,
                        structuredReferenceDigest: Self.referenceDigest(values[3])
                    )]
                )
                transactions.append(transaction)
                annotations.append(CardTransactionAnnotation(
                    parserTransactionID: transaction.id,
                    financialScope: scope,
                    documentScopedSectionID: values[9],
                    liabilityEffect: effect,
                    sourceTransactionDate: purchaseDate,
                    originalMerchantMoney: original,
                    summaryMembership: membership
                ))
            }

            let sectionNet = try Money.aggregate(sections.map(\.signedNetTotal))
            var components = summary
            components.append(.dueDate(dueDate))
            components.append(.sourceSectionNetTotal(sectionNet))
            let rule = String(version) == "v1" ? CardStatementEvidence.cbqV1QARReconciliationRule : CardStatementEvidence.cbqV2QARReconciliationRule
            let evidence = try CardStatementEvidence(
                statementDate: statementDate,
                declaredStatementPeriod: period,
                nativeCurrency: currency,
                accountSourceIdentityObservations: [accountObservation],
                instrumentSections: sections,
                transactionAnnotations: annotations,
                summaryComponents: components,
                reconciliationRuleIdentifier: rule
            )
            return FinancialDocument(
                sourceDocument: document.document,
                metadata: document.metadata,
                parserName: name,
                bookedCurrency: currency,
                declaredStatementPeriod: period,
                transactions: transactions,
                financialIdentifiers: [identifier],
                cardStatementEvidence: evidence
            )
        } catch let error as CBQCreditCardPDFParserError {
            throw error
        } catch MoneyError.unsupportedCurrency(let currency) {
            throw CBQCreditCardPDFParserError.unsupportedCurrency(currency)
        } catch MoneyError.excessPrecision(let currency) {
            throw CBQCreditCardPDFParserError.excessCurrencyPrecision(currency)
        } catch {
            throw CBQCreditCardPDFParserError.malformedSourceEvidence
        }
    }

    nonisolated private static func fields(_ fragment: NormalizedDocument.SourceFragment) -> [String]? {
        let values = fragment.text.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        return values.isEmpty ? nil : values
    }

    private static func summary(
        fields: [String: [[String]]],
        version: String,
        currency: CurrencyCode
    ) throws -> [CardStatementSummaryComponent] {
        let summaries = fields["SUMMARY"] ?? []
        guard summaries.allSatisfy({ $0.count == 3 }), Set(summaries.map { $0[1] }).count == summaries.count else {
            throw CBQCreditCardPDFParserError.malformedSourceEvidence
        }
        var byCode: [String: Money] = [:]
        for item in summaries { byCode[item[1]] = try signedSummaryMoney(item[2], currency: currency) }
        func required(_ code: String) throws -> Money {
            guard let value = byCode[code] else { throw CBQCreditCardPDFParserError.malformedSourceEvidence }
            return value
        }
        if version == "v1" {
            return [
                .previousBalance(try required("PREVIOUS_BALANCE")),
                .amountBilled(try required("AMOUNT_BILLED")),
                .paymentReceived(try positive(try required("PAYMENT_RECEIVED"), currency: currency)),
                .newBalance(try required("NEW_BALANCE"))
            ]
        }
        return [
            .purchases(try positive(try required("PURCHASES"), currency: currency)),
            .billedInstallment(try positive(try required("BILLED_INSTALLMENT"), currency: currency)),
            .feesCharges(try positive(try required("FEES_CHARGES"), currency: currency)),
            .previousBalance(try required("PREVIOUS_BALANCE")),
            .totalPayment(try positive(try required("TOTAL_PAYMENT"), currency: currency)),
            .creditReversal(try positive(try required("CREDIT_REVERSAL"), currency: currency)),
            .newBalance(try required("NEW_BALANCE"))
        ]
    }

    private static func date(_ value: String) throws -> StatementDate {
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 2, parts[1].count == 2, parts[2].count == 2,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else {
            throw CBQCreditCardPDFParserError.malformedSourceEvidence
        }
        return try StatementDate(year: 2000 + year, month: month, day: day)
    }

    private static func money(_ value: String, currency: CurrencyCode) throws -> Money {
        guard let decimal = Decimal(string: value.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) else {
            throw CBQCreditCardPDFParserError.malformedSourceEvidence
        }
        return try Money(amount: decimal, currency: currency)
    }

    private static func signedSummaryMoney(_ raw: String, currency: CurrencyCode) throws -> Money {
        let normalized = raw.replacingOccurrences(of: ")", with: "-").replacingOccurrences(of: "(", with: "")
        let credit = normalized.uppercased().hasPrefix("CR ")
        let token = normalized.uppercased().hasPrefix("CR ") ? String(normalized.dropFirst(3)) : normalized
        let magnitude = try money(token, currency: currency)
        return try Money(amount: credit ? -magnitude.amount : magnitude.amount, currency: currency)
    }

    private static func positive(_ value: Money, currency: CurrencyCode) throws -> Money {
        try Money(amount: value.amount < .zero ? -value.amount : value.amount, currency: currency)
    }

    private static func isFee(_ description: String) -> Bool {
        let value = description.uppercased()
        return value == "CASH ADVANCE FEE" || value == "LATE PAYMENT FEE" ||
            value == "REMAINING BALANCE SERVICE CHARGES" || value == "REMAINING BALANCE SERVICE CHARGE" ||
            value == "CREDIT SHIELD INSURANCE FEE" ||
            ((value.contains("PROTECTION") || value.contains("INSURANCE")) &&
             (value.contains("FEE") || value.contains("CHARGE")))
    }

    private static func isBilledInstallment(_ description: String) -> Bool {
        let value = description.uppercased()
        return value.contains("BILLED INSTALLMENT") || value.hasPrefix("INSTALLMENT")
    }

    private static func referenceDigest(_ value: String) -> String? {
        guard !value.isEmpty else { return nil }
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
