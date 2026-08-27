import CryptoKit
import Foundation

enum AxisCreditCardPDFParserError: Error, Equatable, LocalizedError {
    case unsupportedDocument
    case changedHeader
    case malformedSourceEvidence
    case malformedRow(sourceOrdinal: Int)
    case dateOutsideBoundary(sourceOrdinal: Int)
    case unsupportedCurrency(String)
    case excessCurrencyPrecision(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument: return "The Axis credit-card parser received an unsupported document."
        case .changedHeader: return "The normalized Axis credit-card columns changed."
        case .malformedSourceEvidence: return "Axis credit-card source evidence is malformed."
        case .malformedRow(let ordinal): return "Axis credit-card row \(ordinal) is malformed."
        case .dateOutsideBoundary(let ordinal): return "Axis credit-card row \(ordinal) is after the supported statement boundary."
        case .unsupportedCurrency(let value): return "Axis credit-card currency \(value) is unsupported."
        case .excessCurrencyPrecision(let value): return "Axis credit-card currency \(value) has excess precision."
        }
    }
}

enum AxisCreditCardParserSupport {
    static let currency = try! CurrencyCode("INR")

    private static let fragmentConflictMarker = "__AXIS_FRAGMENT_CONFLICTS__"
    static func fragments(_ document: NormalizedDocument) -> [String: String] {
        var result: [String: String] = [:]
        var conflicts: Set<String> = []
        for fragment in document.sourceContext.preTransactionFragments {
            let fields = fragment.text.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 2 else { continue }
            let key = fields[0]
            let value = fields.dropFirst().joined(separator: "\t")
            guard !conflicts.contains(key) else { continue }
            if let existing = result[key] {
                if existing != value {
                    result.removeValue(forKey: key)
                    conflicts.insert(key)
                }
            } else {
                result[key] = value
            }
        }
        if !conflicts.isEmpty {
            result[fragmentConflictMarker] = conflicts.sorted().joined(separator: ",")
        }
        return result
    }

    static func validatedFragments(_ document: NormalizedDocument) throws -> [String: String] {
        let result = fragments(document)
        guard result[fragmentConflictMarker] == nil else {
            throw AxisCreditCardPDFParserError.malformedSourceEvidence
        }
        return result
    }

    static func money(_ text: String, currency: CurrencyCode? = nil) throws -> Money {
        let normalized = text.replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: "INR", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            throw AxisCreditCardPDFParserError.malformedSourceEvidence
        }
        return try Money(amount: value, currency: currency ?? Self.currency)
    }

    static func date(_ value: String) throws -> StatementDate {
        let clean = value.replacingOccurrences(of: "’", with: "'").trimmingCharacters(in: .whitespacesAndNewlines)
        if let canonical = try? StatementDate(canonical: clean) { return canonical }
        let parts = clean.split(separator: " ", omittingEmptySubsequences: true)
        if parts.count == 3, let day = Int(parts[0]),
           let month = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].firstIndex(where: { $0.caseInsensitiveCompare(String(parts[1])) == .orderedSame }),
           let yearRaw = Int(parts[2].replacingOccurrences(of: "'", with: "")) {
            return try StatementDate(year: yearRaw < 100 ? 2000 + yearRaw : yearRaw, month: month + 1, day: day)
        }
        let numeric = clean.split(whereSeparator: { $0 == "/" || $0 == "-" })
        guard numeric.count == 3, let day = Int(numeric[0]), let month = Int(numeric[1]), let yearRaw = Int(numeric[2]) else {
            throw AxisCreditCardPDFParserError.malformedSourceEvidence
        }
        return try StatementDate(year: yearRaw < 100 ? 2000 + yearRaw : yearRaw, month: month, day: day)
    }

    static func period(_ fragments: [String: String]) throws -> DeclaredStatementPeriod? {
        guard let value = fragments["PERIOD"] else { return nil }
        let pieces = value.split(separator: "\t").map(String.init)
        guard pieces.count == 2 else { throw AxisCreditCardPDFParserError.malformedSourceEvidence }
        return try DeclaredStatementPeriod(start: date(pieces[0]), end: date(pieces[1]))
    }

    static func selectedStatementMonth(_ fragments: [String: String]) throws -> SelectedStatementMonth? {
        guard let selected = fragments["SELECTED_STATEMENT_MONTH"] else { return nil }
        return try SelectedStatementMonth(canonical: selected)
    }

    static func optionalSummaryMoney(_ fragments: [String: String], _ key: String) throws -> Money? {
        guard let text = fragments[key] else { return nil }
        return try money(text)
    }

    static func baseEvidence(
        document: NormalizedDocument,
        annotations: [CardTransactionAnnotation]
    ) throws -> CardStatementEvidence {
        let fragments = try validatedFragments(document)
        let period = (try? period(fragments)) ?? nil
        let selectedMonth = (try? selectedStatementMonth(fragments)) ?? nil
        let statementDate = fragments["STATEMENT_DATE"].flatMap { try? date($0) }
        var summary: [CardStatementSummaryComponent] = []
        if let opening = (try? optionalSummaryMoney(fragments, "OPENING_BALANCE")) ?? nil {
            summary.append(.previousBalance(opening))
        }
        if let value = (try? optionalSummaryMoney(fragments, "TOTAL_PAYMENT_DUE")) ?? nil { summary.append(.axisTotalPaymentDue(value)) }
        if let rawDueDate = fragments["PAYMENT_DUE_DATE"], let dueDate = try? date(rawDueDate) {
            summary.append(.dueDate(dueDate))
        }
        return try CardStatementEvidence(
            statementDate: statementDate,
            declaredStatementPeriod: period,
            selectedStatementMonth: selectedMonth,
            nativeCurrency: currency,
            accountSourceIdentityObservations: [],
            instrumentSections: [],
            transactionAnnotations: annotations,
            summaryComponents: summary,
            reconciliationRuleIdentifier: CardStatementEvidence.axisINRRowLedgerReconciliationRule
        )
    }
}

final class AxisCreditCardPDFParser: StatementParser {
    static let profileID = "axis.credit-card.pdf"
    static let profileVersion = "1"
    var name: String { "Axis Credit Card PDF" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .axis && metadata.documentType == .creditCard && metadata.fileFormat == .pdf &&
            document.fileType.caseInsensitiveCompare(FileFormat.pdf.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        guard canParse(document: document.document, metadata: document.metadata),
              document.header?.values == AxisCreditCardPDFNormalizer.logicalHeader,
              !document.rows.isEmpty else { throw AxisCreditCardPDFParserError.unsupportedDocument }
        do {
            let fragments = try AxisCreditCardParserSupport.validatedFragments(document)
            let period = (try? AxisCreditCardParserSupport.period(fragments)) ?? nil
            let currency = AxisCreditCardParserSupport.currency
            var transactions: [Transaction] = []
            var annotations: [CardTransactionAnnotation] = []
            for row in document.rows {
                guard row.values.count == AxisCreditCardPDFNormalizer.logicalHeader.count,
                      let effect = CardLiabilityEffect(rawValue: row.values[3]),
                      row.values[4] == "account_level", row.values[5].isEmpty else {
                    throw AxisCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber)
                }
                let date = try AxisCreditCardParserSupport.date(row.values[0])
                let magnitude = try AxisCreditCardParserSupport.money(row.values[2])
                guard magnitude.amount > .zero else { throw AxisCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
                let signed = try Money(amount: effect == .increasesAmountOwed ? magnitude.amount : -magnitude.amount, currency: currency)
                let original: Money?
                if row.values[7].isEmpty && row.values[8].isEmpty { original = nil }
                else {
                    guard !row.values[7].isEmpty, !row.values[8].isEmpty else { throw AxisCreditCardPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
                    let originalCurrency = try CurrencyCode(row.values[8])
                    let originalMagnitude = try AxisCreditCardParserSupport.money(row.values[7], currency: originalCurrency)
                    original = try Money(amount: effect == .increasesAmountOwed ? originalMagnitude.amount : -originalMagnitude.amount, currency: originalCurrency)
                }
                let tx = Transaction(statementDate: date, description: row.values[1], reference: row.values[6].isEmpty ? nil : row.values[6], debitMoney: nil, creditMoney: nil, money: signed, runningBalanceMoney: nil, cardLiabilityEffect: effect, account: "Axis Credit Card", sourceBank: Institution.axis.rawValue, sourceFile: document.document.filename, financialDateRole: .transactionDate, statementTimezoneEvidence: .iana("Asia/Kolkata"), sourceProvenance: [TransactionSourceProvenance(normalizedDocumentID: document.document.id.uuidString, normalizedRowID: row.id.uuidString, sourceOrdinal: row.rowNumber, normalizedRecordDigest: String.normalizedRecordDigest(values: row.values), parserProfileID: Self.profileID, parserProfileVersion: Self.profileVersion, sourceTransactionDate: date, structuredReferenceDigest: Self.referenceDigest(row.values[6]) )])
                transactions.append(tx)
                annotations.append(CardTransactionAnnotation(parserTransactionID: tx.id, financialScope: .accountLevel, documentScopedSectionID: nil, liabilityEffect: effect, sourceTransactionDate: date, originalMerchantMoney: original))
            }
            let evidence = try AxisCreditCardParserSupport.baseEvidence(
                document: document,
                annotations: annotations
            )
            return FinancialDocument(sourceDocument: document.document, metadata: document.metadata, parserName: name, bookedCurrency: currency, declaredStatementPeriod: period, transactions: transactions, financialIdentifiers: [], sourceStatementEvidence: nil, cardStatementEvidence: evidence)
        } catch let error as AxisCreditCardPDFParserError { throw error }
        catch MoneyError.unsupportedCurrency(let currency) { throw AxisCreditCardPDFParserError.unsupportedCurrency(currency) }
        catch MoneyError.excessPrecision(let currency) { throw AxisCreditCardPDFParserError.excessCurrencyPrecision(currency) }
        catch { throw AxisCreditCardPDFParserError.malformedSourceEvidence }
    }

    private static func referenceDigest(_ value: String) -> String? {
        guard !value.isEmpty else { return nil }
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
