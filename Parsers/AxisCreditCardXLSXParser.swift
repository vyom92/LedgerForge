import CryptoKit
import Foundation

enum AxisCreditCardXLSXParserError: Error, Equatable, LocalizedError {
    case unsupportedDocument
    case changedHeader
    case malformedSourceEvidence
    case malformedRow(sourceOrdinal: Int)
    case dateOutsideBoundary(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument: return "The Axis credit-card parser received an unsupported XLSX document."
        case .changedHeader: return "The normalized Axis credit-card XLSX columns changed."
        case .malformedSourceEvidence: return "Axis credit-card XLSX source evidence is malformed."
        case .malformedRow(let ordinal): return "Axis credit-card XLSX row \(ordinal) is malformed."
        case .dateOutsideBoundary(let ordinal): return "Axis credit-card XLSX row \(ordinal) is after the supported statement boundary."
        }
    }
}

final class AxisCreditCardXLSXParser: StatementParser {
    static let profileID = "axis.credit-card.xlsx"
    static let profileVersion = "1"
    var name: String { "Axis Credit Card XLSX" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .axis && metadata.documentType == .creditCard && metadata.fileFormat == .xlsx &&
            document.fileType.caseInsensitiveCompare(FileFormat.xlsx.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        guard canParse(document: document.document, metadata: document.metadata),
              document.header?.values == AxisCreditCardXLSXNormalizer.logicalHeader,
              !document.rows.isEmpty else { throw AxisCreditCardXLSXParserError.unsupportedDocument }
        do {
            let fragments = try AxisCreditCardParserSupport.validatedFragments(document)
            let period = (try? AxisCreditCardParserSupport.period(fragments)) ?? nil
            let currency = AxisCreditCardParserSupport.currency
            var transactions: [Transaction] = []
            var annotations: [CardTransactionAnnotation] = []
            for row in document.rows {
                guard row.values.count == AxisCreditCardXLSXNormalizer.logicalHeader.count,
                      let effect = CardLiabilityEffect(rawValue: row.values[3]),
                      row.values[4] == "account_level", row.values[5].isEmpty else {
                    throw AxisCreditCardXLSXParserError.malformedRow(sourceOrdinal: row.rowNumber)
                }
                let date = try AxisCreditCardParserSupport.date(row.values[0])
                let magnitude = try AxisCreditCardParserSupport.money(row.values[2])
                guard magnitude.amount > .zero else { throw AxisCreditCardXLSXParserError.malformedRow(sourceOrdinal: row.rowNumber) }
                let signed = try Money(amount: effect == .increasesAmountOwed ? magnitude.amount : -magnitude.amount, currency: currency)
                let tx = Transaction(statementDate: date, description: row.values[1], reference: row.values[6].isEmpty ? nil : row.values[6], debitMoney: nil, creditMoney: nil, money: signed, runningBalanceMoney: nil, cardLiabilityEffect: effect, account: "Axis Credit Card", sourceBank: Institution.axis.rawValue, sourceFile: document.document.filename, financialDateRole: .transactionDate, statementTimezoneEvidence: .iana("Asia/Kolkata"), sourceProvenance: [TransactionSourceProvenance(normalizedDocumentID: document.document.id.uuidString, normalizedRowID: row.id.uuidString, sourceOrdinal: row.rowNumber, normalizedRecordDigest: String.normalizedRecordDigest(values: row.values), parserProfileID: Self.profileID, parserProfileVersion: Self.profileVersion, sourceTransactionDate: date, structuredReferenceDigest: Self.referenceDigest(row.values[6]))])
                transactions.append(tx)
                annotations.append(CardTransactionAnnotation(parserTransactionID: tx.id, financialScope: .accountLevel, documentScopedSectionID: nil, liabilityEffect: effect, sourceTransactionDate: date, originalMerchantMoney: nil))
            }
            let evidence = try AxisCreditCardParserSupport.baseEvidence(
                document: document,
                annotations: annotations
            )
            return FinancialDocument(sourceDocument: document.document, metadata: document.metadata, parserName: name, bookedCurrency: currency, declaredStatementPeriod: period, transactions: transactions, financialIdentifiers: [], sourceStatementEvidence: nil, cardStatementEvidence: evidence)
        } catch let error as AxisCreditCardXLSXParserError { throw error }
        catch { throw AxisCreditCardXLSXParserError.malformedSourceEvidence }
    }

    private static func referenceDigest(_ value: String) -> String? {
        guard !value.isEmpty else { return nil }
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
