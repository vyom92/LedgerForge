import CryptoKit
import Foundation

enum AmericanExpressCreditCardPDFParserError: Error, Equatable, LocalizedError {
    case unsupportedDocument
    case changedHeader
    case malformedSourceEvidence
    case malformedRow(sourceOrdinal: Int)
    case unsupportedCurrency(String)
    case excessCurrencyPrecision(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument: return "The Amex parser received an unsupported document."
        case .changedHeader: return "The normalized Amex columns changed."
        case .malformedSourceEvidence: return "Amex card statement evidence is malformed."
        case .malformedRow(let ordinal): return "Amex row \(ordinal) is malformed."
        case .unsupportedCurrency: return "Amex original Money uses an unsupported currency."
        case .excessCurrencyPrecision: return "Amex original Money exceeds the currency scale."
        }
    }
}

final class AmericanExpressCreditCardPDFParser: StatementParser {
    static let profileID = "amex.credit-card.pdf"
    static let profileVersion = "1"
    var name: String { "American Express Credit Card PDF" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .amex && metadata.documentType == .creditCard &&
            metadata.fileFormat == .pdf && document.fileType.caseInsensitiveCompare(FileFormat.pdf.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        guard canParse(document: document.document, metadata: document.metadata) else {
            throw AmericanExpressCreditCardPDFParserError.unsupportedDocument
        }
        guard document.header?.values == AmericanExpressCreditCardPDFNormalizer.logicalHeader,
              !document.rows.isEmpty else {
            throw AmericanExpressCreditCardPDFParserError.changedHeader
        }
        let parsedFragments = document.sourceContext.preTransactionFragments.compactMap { fragment -> [String]? in
            let fields = fragment.text.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return [String(fields[0]), String(fields[1])]
        }
        let commonPairs = parsedFragments.filter { $0[0] != "INSTRUMENT_SECTION" }.map { ($0[0], $0[1]) }
        guard Set(commonPairs.map(\.0)).count == commonPairs.count else {
            throw AmericanExpressCreditCardPDFParserError.malformedSourceEvidence
        }
        let fragments = Dictionary(uniqueKeysWithValues: commonPairs)
        let sectionFragments = document.sourceContext.preTransactionFragments.compactMap { fragment -> [String]? in
            let fields = fragment.text.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            return fields.first == "INSTRUMENT_SECTION" ? fields : nil
        }
        guard let membership = fragments["MEMBERSHIP_NUMBER"],
              let statementDateText = fragments["STATEMENT_DATE"],
              let periodText = fragments["PERIOD"],
              let previousText = fragments["PREVIOUS_BALANCE"],
              let creditsText = fragments["NEW_CREDITS"],
              let debitsText = fragments["NEW_DEBITS"],
              let newBalanceText = fragments["NEW_BALANCE"],
              let dueDateText = fragments["DUE_DATE"],
              !sectionFragments.isEmpty else {
            throw AmericanExpressCreditCardPDFParserError.malformedSourceEvidence
        }
        do {
            let currency = try CurrencyCode("QAR")
            let statementDate = try Self.shortDate(statementDateText)
            let periodParts = periodText.components(separatedBy: " to ")
            guard periodParts.count == 2 else { throw AmericanExpressCreditCardPDFParserError.malformedSourceEvidence }
            let period = try DeclaredStatementPeriod(start: Self.shortDate(periodParts[0]), end: Self.shortDate(periodParts[1]))
            let accountObservation = try CardSourceIdentityObservation(
                kind: .liabilityMembershipNumber,
                subject: .liabilityAccount,
                value: membership
            )
            let instrumentSections = try sectionFragments.enumerated().map { index, fields -> CardInstrumentSectionEvidence in
                guard fields.count == 6,
                      fields[1] == AmericanExpressCreditCardPDFNormalizer.instrumentSectionID(ordinal: index + 1),
                      fields[5].isEmpty || fields[5] == "CR" else {
                    throw AmericanExpressCreditCardPDFParserError.malformedSourceEvidence
                }
                let observation = try CardSourceIdentityObservation(
                    kind: .instrumentCardAccountNumber,
                    subject: .instrument,
                    value: fields[2]
                )
                let magnitude = try Self.money(fields[4], currency: currency)
                let signedTotal = try Money(
                    amount: fields[5] == "CR" ? -magnitude.amount : magnitude.amount,
                    currency: currency
                )
                return CardInstrumentSectionEvidence(
                    documentScopedSectionID: fields[1],
                    sourceOrdinal: index + 1,
                    holderLabel: fields[3],
                    sourceIdentityObservations: [observation],
                    signedNetTotal: signedTotal
                )
            }
            let sectionIDs = Set(instrumentSections.map(\.documentScopedSectionID))
            var transactions: [Transaction] = []
            var annotations: [CardTransactionAnnotation] = []
            for row in document.rows {
                guard row.values.count == AmericanExpressCreditCardPDFNormalizer.logicalHeader.count,
                      let effect = CardLiabilityEffect(rawValue: row.values[7]) else {
                    throw AmericanExpressCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber)
                }
                let transactionDate = try Self.longDate(row.values[0])
                let postingDate = try Self.longDate(row.values[1])
                let postedMagnitude = try Self.money(row.values[6], currency: currency)
                guard postedMagnitude.amount > .zero else {
                    throw AmericanExpressCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber)
                }
                let signedPosted = try Money(
                    amount: effect == .increasesAmountOwed ? postedMagnitude.amount : -postedMagnitude.amount,
                    currency: currency
                )
                let originalMoney: Money?
                if row.values[4].isEmpty && row.values[5].isEmpty {
                    originalMoney = nil
                } else {
                    guard !row.values[4].isEmpty, !row.values[5].isEmpty else {
                        throw AmericanExpressCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber)
                    }
                    let originalCurrency = try CurrencyCode(row.values[5])
                    let originalMagnitude = try Self.money(row.values[4], currency: originalCurrency)
                    originalMoney = try Money(
                        amount: effect == .increasesAmountOwed ? originalMagnitude.amount : -originalMagnitude.amount,
                        currency: originalCurrency
                    )
                }
                let scope: CardTransactionScope
                let sectionID: String?
                if row.values[8] == "account_level" && row.values[9].isEmpty {
                    scope = .accountLevel
                    sectionID = nil
                } else if row.values[8] == "instrument_level" && sectionIDs.contains(row.values[9]) {
                    scope = .instrument
                    sectionID = row.values[9]
                } else {
                    throw AmericanExpressCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber)
                }
                let transaction = Transaction(
                    statementDate: postingDate,
                    description: row.values[2],
                    reference: row.values[3],
                    debitMoney: nil,
                    creditMoney: nil,
                    money: signedPosted,
                    runningBalanceMoney: nil,
                    cardLiabilityEffect: effect,
                    account: "The Platinum Card (QAR)",
                    sourceBank: Institution.amex.rawValue,
                    sourceFile: document.document.filename,
                    financialDateRole: .postingDate,
                    statementTimezoneEvidence: .iana("Asia/Qatar"),
                    sourceProvenance: [TransactionSourceProvenance(
                        normalizedDocumentID: document.document.id.uuidString,
                        normalizedRowID: row.id.uuidString,
                        sourceOrdinal: row.rowNumber,
                        normalizedRecordDigest: String.normalizedRecordDigest(values: row.values),
                        parserProfileID: Self.profileID,
                        parserProfileVersion: Self.profileVersion,
                        sourceTransactionDate: transactionDate,
                        structuredReferenceDigest: Self.referenceDigest(row.values[3])
                    )]
                )
                transactions.append(transaction)
                annotations.append(CardTransactionAnnotation(
                    parserTransactionID: transaction.id,
                    financialScope: scope,
                    documentScopedSectionID: sectionID,
                    liabilityEffect: effect,
                    sourceTransactionDate: transactionDate,
                    originalMerchantMoney: originalMoney
                ))
            }
            let evidence = try CardStatementEvidence(
                statementDate: statementDate,
                declaredStatementPeriod: period,
                nativeCurrency: currency,
                accountSourceIdentityObservations: [accountObservation],
                instrumentSections: instrumentSections,
                transactionAnnotations: annotations,
                summaryComponents: [
                    .previousBalance(try Self.money(previousText, currency: currency)),
                    .newCredits(try Self.money(creditsText, currency: currency)),
                    .newDebits(try Self.money(debitsText, currency: currency)),
                    .newBalance(try Self.money(newBalanceText, currency: currency)),
                    .dueDate(try Self.shortDate(dueDateText)),
                    .instrumentNetTotal(try Money.aggregate(instrumentSections.map(\.signedNetTotal)))
                ],
                reconciliationRuleIdentifier: CardStatementEvidence.amexQARReconciliationRule
            )
            return FinancialDocument(
                sourceDocument: document.document,
                metadata: document.metadata,
                parserName: name,
                bookedCurrency: currency,
                declaredStatementPeriod: period,
                transactions: transactions,
                financialIdentifiers: [],
                sourceStatementEvidence: nil,
                cardStatementEvidence: evidence
            )
        } catch let error as AmericanExpressCreditCardPDFParserError {
            throw error
        } catch MoneyError.unsupportedCurrency(let currency) {
            throw AmericanExpressCreditCardPDFParserError.unsupportedCurrency(currency)
        } catch MoneyError.excessPrecision(let currency) {
            throw AmericanExpressCreditCardPDFParserError.excessCurrencyPrecision(currency)
        } catch {
            throw AmericanExpressCreditCardPDFParserError.malformedSourceEvidence
        }
    }

    private static func money(_ value: String, currency: CurrencyCode) throws -> Money {
        guard let decimal = Decimal(string: value.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) else {
            throw AmericanExpressCreditCardPDFParserError.malformedSourceEvidence
        }
        return try Money(amount: decimal, currency: currency)
    }

    private static func shortDate(_ value: String) throws -> StatementDate {
        let parts = value.split(separator: "/")
        guard parts.count == 3, let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else {
            throw AmericanExpressCreditCardPDFParserError.malformedSourceEvidence
        }
        return try StatementDate(year: 2000 + year, month: month, day: day)
    }

    private static func longDate(_ value: String) throws -> StatementDate {
        let parts = value.split(separator: "-")
        guard parts.count == 3, let day = Int(parts[0]),
              let month = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                .firstIndex(where: { $0.caseInsensitiveCompare(String(parts[1])) == .orderedSame }),
              let year = Int(parts[2]) else {
            throw AmericanExpressCreditCardPDFParserError.malformedSourceEvidence
        }
        return try StatementDate(year: year, month: month + 1, day: day)
    }

    private static func referenceDigest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
