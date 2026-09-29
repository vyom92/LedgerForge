import CryptoKit
import Foundation

/// Parser-owned identities and transactions for the ordered bank sections of
/// one relationship original. Printed summaries remain source observations.
nonisolated enum BankRelationshipPDFParser {
    static func parse(_ document: NormalizedDocument) throws -> FinancialDocument {
        let family: BankRelationshipFamily
        switch document.metadata.institution {
        case .axis: family = .axis
        case .hdfc: family = .hdfc
        default: throw BankRelationshipPDFError.unsupportedSource
        }
        let sources = document.sourceContext.bankAccountSections
        guard document.metadata.fileFormat == .pdf, document.metadata.documentType == .bankAccount,
              document.header?.values == BankRelationshipPDFNormalizer.logicalHeader, !sources.isEmpty,
              sources.map(\.ordinal) == Array(1...sources.count),
              sources.flatMap(\.rows).map(\.id) == document.rows.map(\.id) else {
            throw BankRelationshipPDFError.incompleteSection
        }
        let currency = try CurrencyCode("INR")
        var transactions: [Transaction] = []
        var sections: [BankAccountSectionEvidence] = []
        for source in sources {
            guard source.currencyLiteral == currency.code,
                  source.exhaustedRegion.matches(normalizedFinancialRowCount: source.rows.count),
                  source.firstSourceOrdinal <= source.lastSourceOrdinal else {
                throw BankRelationshipPDFError.incompleteSection
            }
            let identity: BankAccountSourceIdentity
            let identifiers: [FinancialIdentifier]
            switch family {
            case .axis:
                guard source.accountLiteral.range(of: #"^[0-9X]{15}$"#, options: .regularExpression) != nil,
                      source.accountLiteral.contains("X") else { throw BankRelationshipPDFError.ambiguousIdentity }
                identity = .maskedAccountNumber(source.accountLiteral)
                identifiers = []
            case .hdfc:
                guard source.accountLiteral.range(of: #"^[0-9]{14}$"#, options: .regularExpression) != nil else {
                    throw BankRelationshipPDFError.ambiguousIdentity
                }
                identity = .fullAccountNumber(source.accountLiteral)
                identifiers = [try FinancialIdentifier(kind: .institutionAccountId, rawValue: source.accountLiteral,
                    verificationState: .verified, provenance: .institutionStructuredField)]
            }
            let period = try DeclaredStatementPeriod(start: date(source.periodStartLiteral), end: date(source.periodEndLiteral))
            var sectionTransactions: [Transaction] = []
            for row in source.rows {
                guard row.values.count == BankRelationshipPDFNormalizer.logicalHeader.count else {
                    throw BankRelationshipPDFError.malformedOccurrence(row.rowNumber)
                }
                let values = row.values
                let debit = values[4].isEmpty ? nil : try money(values[4], currency: currency)
                let credit = values[5].isEmpty ? nil : try money(values[5], currency: currency)
                let debitAmount = debit?.amount ?? .zero
                let creditAmount = credit?.amount ?? .zero
                guard debitAmount >= .zero, creditAmount >= .zero,
                      (debitAmount > .zero) != (creditAmount > .zero), !values[1].isEmpty,
                      (family == .axis ? values[2].isEmpty : !values[2].isEmpty) else {
                    throw BankRelationshipPDFError.malformedOccurrence(row.rowNumber)
                }
                let reference = values[3].isEmpty ? nil : values[3]
                let referenceDigest = reference.map { value in
                    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
                }
                sectionTransactions.append(Transaction(statementDate: try date(values[0]),
                    valueDate: family == .hdfc ? try date(values[2]) : nil, description: values[1], reference: reference,
                    debitMoney: debitAmount > .zero ? debit : nil, creditMoney: creditAmount > .zero ? credit : nil,
                    money: try Money(amount: creditAmount - debitAmount, currency: currency),
                    runningBalanceMoney: try money(values[6], currency: currency), account: family.institution.rawValue,
                    sourceBank: family.institution.rawValue, sourceFile: document.document.filename,
                    financialDateRole: .transactionDate, statementTimezoneEvidence: .iana("Asia/Kolkata"),
                    sourceProvenance: [.init(normalizedDocumentID: document.document.id.uuidString,
                        normalizedRowID: row.id.uuidString, sourceOrdinal: row.rowNumber, sourcePage: row.sourcePage,
                        normalizedRecordDigest: String.normalizedRecordDigest(values: values),
                        parserProfileID: family.profileID, parserProfileVersion: "1",
                        structuredReferenceDigest: referenceDigest, literalRunningBalance: values[6])]))
            }
            let controls = source.controls.map { control -> BankSectionControlObservation in
                let isCount = control.kind == .debitCount || control.kind == .creditCount
                return .init(kind: control.kind, label: control.label, literal: control.literal,
                    money: isCount ? nil : try? money(control.literal, currency: currency),
                    count: isCount ? Int(control.literal) : nil,
                    sourceOrdinal: control.sourceOrdinal, sourcePage: control.sourcePage)
            }
            if sectionTransactions.isEmpty {
                let zeroEstablished: Bool
                if family == .axis {
                    zeroEstablished = controls.last(where: { $0.kind == .debitTotal })?.money?.amount == Decimal.zero &&
                        controls.last(where: { $0.kind == .creditTotal })?.money?.amount == Decimal.zero &&
                        controls.contains(where: { $0.kind == .openingBalance && $0.money != nil }) &&
                        controls.contains(where: { $0.kind == .closingBalance && $0.money != nil })
                } else {
                    zeroEstablished = controls.last(where: { $0.kind == .debitCount })?.count == 0 &&
                        controls.last(where: { $0.kind == .creditCount })?.count == 0
                }
                guard zeroEstablished else { throw BankRelationshipPDFError.incompleteSection }
            }
            sections.append(.init(id: source.id, ordinal: source.ordinal, sourceIdentity: identity,
                financialIdentifiers: identifiers, productLabel: source.productLiteral, nativeCurrency: currency,
                period: period, firstSourceOrdinal: source.firstSourceOrdinal, lastSourceOrdinal: source.lastSourceOrdinal,
                firstPage: source.firstPage, lastPage: source.lastPage,
                transactionIDs: sectionTransactions.map(\.id), controls: controls, exhaustedRegion: source.exhaustedRegion))
            transactions += sectionTransactions
        }
        let commonPeriod = sections.allSatisfy { $0.period == sections.first?.period } ? sections.first?.period : nil
        return FinancialDocument(sourceDocument: document.document, metadata: document.metadata,
            parserName: family.parserName, parserProfileID: family.profileID, parserProfileVersion: "1",
            bookedCurrency: currency, declaredStatementPeriod: commonPeriod, transactions: transactions,
            bankStatementEvidence: .init(isAccountRelationshipStatement: true, sections: sections))
    }

    private static func date(_ value: String) throws -> StatementDate {
        try StatementDate.axisNRE(value.replacingOccurrences(of: "/", with: "-"))
    }

    private static func money(_ value: String, currency: CurrencyCode) throws -> Money {
        guard value.range(of: "^" + BankRelationshipPDFNormalizer.moneyPattern + "$", options: .regularExpression) != nil,
              let amount = Decimal(string: value.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) else {
            throw BankRelationshipPDFError.incompleteSection
        }
        return try Money(amount: amount, currency: currency)
    }
}
