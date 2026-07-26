import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisNREFixtureFidelityTests {

    @Test func sanitizedFixturesMatchIndependentHeaderSemanticFinancialOracle() throws {
        for fixture in Self.fixtures {
            let expected = try AxisNREFidelityExpectation.load(fileName: fixture.expected)
            let oracle = try IndependentAxisCSVOracle.load(
                csvFileName: fixture.csv,
                independentOpeningBalance: expected.openingBalance
            )

            #expect(oracle.headerDRIndex < oracle.headerCRIndex)
            #expect(oracle.directionFailureRows.isEmpty)
            #expect(oracle.reconciliationFailureRows.isEmpty)
            #expect(oracle.transactions.count == expected.transactionCount)
            #expect(oracle.debitTotal == expected.debitTotal)
            #expect(oracle.creditTotal == expected.creditTotal)
            #expect(oracle.rawDRColumnTotal == expected.rawDRColumnTotal)
            #expect(oracle.rawCRColumnTotal == expected.rawCRColumnTotal)
            #expect(oracle.openingBalance == expected.openingBalance)
            #expect(oracle.closingBalance == expected.closingBalance)
        }
    }

    @Test func productionParserMatchesIndependentFixtureOracle() throws {
        for fixture in Self.fixtures {
            let expected = try AxisNREFidelityExpectation.load(fileName: fixture.expected)
            let oracle = try IndependentAxisCSVOracle.load(
                csvFileName: fixture.csv,
                independentOpeningBalance: expected.openingBalance
            )
            let parsed = try parseProductionFixture(fileName: fixture.csv)
            let parserProjection = try parsed.financialDocument.transactions.map {
                let date = try #require($0.statementDate)
                return IndependentAxisTransaction(
                    date: "\(String(format: "%02d", date.day))-\(String(format: "%02d", date.month))-\(String(format: "%04d", date.year))",
                    physicalRowNumber: $0.sourceProvenance.first?.sourceOrdinal,
                    debit: $0.debit,
                    credit: $0.credit,
                    balance: $0.balance,
                    eventEvidence: $0.verifiedAxisUPIEventEvidence
                )
            }

            #expect(parserProjection == oracle.transactions)
            #expect(parsed.validation.passed)
            #expect(parsed.validation.debitTotal == oracle.debitTotal)
            #expect(parsed.validation.creditTotal == oracle.creditTotal)
            #expect(parsed.validation.openingBalance == oracle.openingBalance)
            #expect(parsed.validation.closingBalance == oracle.closingBalance)
        }
    }

    @Test func sameDayAxisRowsRetainIndependentPhysicalOrder() throws {
        let fixture = "axis_bank_nre_private_source_semantics.csv"
        let expected = try AxisNREFidelityExpectation.load(
            fileName: "axis_bank_nre_private_source_semantics.expected.json"
        )
        let oracle = try IndependentAxisCSVOracle.load(
            csvFileName: fixture,
            independentOpeningBalance: expected.openingBalance
        )
        let parsed = try parseProductionFixture(fileName: fixture).financialDocument.transactions
        let sameDay = try #require(oracle.transactions.first { candidate in
            oracle.transactions.filter { $0.date == candidate.date }.count > 1
        }?.date)
        let expectedOrdinals = oracle.transactions.filter { $0.date == sameDay }.compactMap(\.physicalRowNumber)
        let actualOrdinals = parsed.filter {
            $0.statementDate.map { "\(String(format: "%02d", $0.day))-\(String(format: "%02d", $0.month))-\(String(format: "%04d", $0.year))" } == sameDay
        }.compactMap { $0.sourceProvenance.first?.sourceOrdinal }
        #expect(actualOrdinals == expectedOrdinals)
    }

    @Test func privacySafeRealLayoutRegressionPreservesUPIDirectionSubtypes() throws {
        let parsed = try parseProductionFixture(
            fileName: "axis_bank_nre_private_source_semantics.csv"
        )

        #expect(parsed.financialDocument.transactions.count == 4)
        #expect(parsed.financialDocument.transactions[1].verifiedAxisUPIEventEvidence?.subtype == .posting)
        #expect(parsed.financialDocument.transactions[2].verifiedAxisUPIEventEvidence?.subtype == .creditAdjustment)
        #expect(parsed.financialDocument.transactions[3].verifiedAxisUPIEventEvidence?.subtype == .posting)
        #expect(parsed.validation.passed)
    }

    @Test(arguments: AxisSemanticFalsificationCase.allCases)
    func balanceDeltaOracleRejectsContradictorySourceEvidence(
        _ testCase: AxisSemanticFalsificationCase
    ) {
        #expect(throws: AxisSourceSemanticOracleError.self) {
            _ = try IndependentAxisCSVOracle.resolveDirection(
                sourceDR: testCase.sourceDR,
                sourceCR: testCase.sourceCR,
                priorBalance: 100,
                currentBalance: testCase.currentBalance
            )
        }
    }

    @Test func onlyLineageBackedFixtureCanAuthorizeNRESourceTruth() throws {
        #expect(try sourceTruthEligibility(
            manifest: "axis_bank_nre_private_source_semantics.manifest.json"
        ))
        #expect(!(try sourceTruthEligibility(
            manifest: "axis_bank_nre_legacy_fixture_quarantine.manifest.json"
        )))
        #expect(!(try sourceTruthEligibility(
            manifest: "axis_bank_partial_overlap.manifest.json"
        )))
    }

    private static let fixtures = [
        (
            csv: "axis_bank_nre_private_source_semantics.csv",
            expected: "axis_bank_nre_private_source_semantics.expected.json"
        )
    ]

    private func parseProductionFixture(
        fileName: String
    ) throws -> ParsedAxisNREFixture {
        let url = FixtureLocator.axisCSV(fileName)
        let text = try CSVReader().read(from: url)
        let document = CSVAnalyzer().analyze(text: text, fileURL: url)
        let metadata = InstitutionDetector().detect(from: text)
        let normalization = CSVNormalizer().normalizeWithSourceContext(
            text: text,
            document: document
        )
        let parser = try #require(
            StatementParserRegistry.shared.parser(for: document, metadata: metadata)
        )
        let financialDocument = try parser.parse(
            document: NormalizedDocument(
                document: document,
                metadata: metadata,
                rows: normalization.rows,
                header: normalization.header,
                sourceContext: normalization.sourceContext
            )
        )

        return ParsedAxisNREFixture(
            financialDocument: financialDocument,
            validation: ImportValidator.validate(financialDocument: financialDocument)
        )
    }

    private func sourceTruthEligibility(manifest: String) throws -> Bool {
        let data = try Data(contentsOf: FixtureLocator.axisManifest(manifest))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return object["source_truth_acceptance_eligible"] as? Bool ?? false
    }
}

private struct ParsedAxisNREFixture {
    let financialDocument: FinancialDocument
    let validation: ImportValidationResult
}

private struct IndependentAxisTransaction: Equatable {
    let date: String
    let physicalRowNumber: Int?
    let debit: Decimal?
    let credit: Decimal?
    let balance: Decimal?
    let eventEvidence: AxisUPITransactionEventEvidence?
}

private struct IndependentAxisCSVOracle {
    let headerDRIndex: Int
    let headerCRIndex: Int
    let transactions: [IndependentAxisTransaction]
    let directionFailureRows: [Int]
    let reconciliationFailureRows: [Int]
    let debitTotal: Decimal
    let creditTotal: Decimal
    let rawDRColumnTotal: Decimal
    let rawCRColumnTotal: Decimal
    let openingBalance: Decimal?
    let closingBalance: Decimal?

    static func load(
        csvFileName: String,
        independentOpeningBalance: Decimal
    ) throws -> IndependentAxisCSVOracle {
        let text = try CSVReader().read(from: FixtureLocator.axisCSV(csvFileName))
        let lines = text.components(separatedBy: .newlines)
        let headerOffset = try #require(
            lines.firstIndex {
                let normalized = $0.lowercased()
                return normalized.contains("tran date") && normalized.contains("particulars")
            }
        )
        let header = cells(in: lines[headerOffset]).map(normalizeHeader)
        let drMatches = header.indices.filter { header[$0] == "dr" }
        let crMatches = header.indices.filter { header[$0] == "cr" }
        let dateMatches = header.indices.filter { header[$0] == "tran date" }
        let descriptionMatches = header.indices.filter { header[$0] == "particulars" }
        let balanceMatches = header.indices.filter { header[$0] == "bal" }
        let dr = try #require(drMatches.count == 1 ? drMatches[0] : nil)
        let cr = try #require(crMatches.count == 1 ? crMatches[0] : nil)
        let date = try #require(dateMatches.count == 1 ? dateMatches[0] : nil)
        let description = try #require(descriptionMatches.count == 1 ? descriptionMatches[0] : nil)
        let balance = try #require(balanceMatches.count == 1 ? balanceMatches[0] : nil)
        let mandatoryMaximum = [dr, cr, date, description, balance].max()!
        struct PhysicalRow {
            let date: String
            let rowNumber: Int
            let description: String
            let sourceDR: Decimal?
            let sourceCR: Decimal?
            let balance: Decimal?
        }
        var physicalRows: [PhysicalRow] = []
        var directionFailures: [Int] = []

        for (offset, line) in lines.dropFirst(headerOffset + 1).enumerated() {
            let rowNumber = headerOffset + offset + 2
            let values = cells(in: line)
            guard values.indices.contains(date), Self.isAxisDate(values[date]) else {
                continue
            }
            guard values.count > mandatoryMaximum else {
                directionFailures.append(rowNumber)
                continue
            }
            let sourceDR = decimal(values[dr])
            let sourceCR = decimal(values[cr])
            let runningBalance = decimal(values[balance])
            guard (sourceDR == nil) != (sourceCR == nil) else {
                throw AxisSourceSemanticOracleError.invalidDirectionOccupancy
            }
            physicalRows.append(
                PhysicalRow(
                    date: values[date],
                    rowNumber: rowNumber,
                    description: values[description],
                    sourceDR: sourceDR,
                    sourceCR: sourceCR,
                    balance: runningBalance
                )
            )
        }

        var transactions: [IndependentAxisTransaction] = []
        var reconciliationFailures: [Int] = []
        var priorBalance = independentOpeningBalance
        for row in physicalRows {
            guard let currentBalance = row.balance else {
                reconciliationFailures.append(row.rowNumber)
                continue
            }
            let direction = try resolveDirection(
                sourceDR: row.sourceDR,
                sourceCR: row.sourceCR,
                priorBalance: priorBalance,
                currentBalance: currentBalance
            )
            transactions.append(
                IndependentAxisTransaction(
                    date: row.date,
                    physicalRowNumber: row.rowNumber,
                    debit: direction.debit,
                    credit: direction.credit,
                    balance: currentBalance,
                    eventEvidence: eventEvidence(
                        narration: row.description,
                        debit: direction.debit,
                        credit: direction.credit
                    )
                )
            )
            priorBalance = currentBalance
        }

        let debitTotal = transactions.compactMap(\.debit).reduce(0, +)
        let creditTotal = transactions.compactMap(\.credit).reduce(0, +)
        return IndependentAxisCSVOracle(
            headerDRIndex: dr,
            headerCRIndex: cr,
            transactions: transactions,
            directionFailureRows: directionFailures,
            reconciliationFailureRows: reconciliationFailures,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            rawDRColumnTotal: physicalRows.compactMap(\.sourceDR).reduce(0, +),
            rawCRColumnTotal: physicalRows.compactMap(\.sourceCR).reduce(0, +),
            openingBalance: independentOpeningBalance,
            closingBalance: transactions.last?.balance
        )
    }

    static func resolveDirection(
        sourceDR: Decimal?,
        sourceCR: Decimal?,
        priorBalance: Decimal,
        currentBalance: Decimal
    ) throws -> (debit: Decimal?, credit: Decimal?) {
        guard (sourceDR == nil) != (sourceCR == nil) else {
            throw AxisSourceSemanticOracleError.invalidDirectionOccupancy
        }
        let delta = currentBalance - priorBalance
        if let sourceDR, sourceCR == nil, delta == -sourceDR {
            return (sourceDR, nil)
        }
        if let sourceCR, sourceDR == nil, delta == sourceCR {
            return (nil, sourceCR)
        }
        throw AxisSourceSemanticOracleError.amountOrDirectionContradictsBalanceDelta
    }

    private static func cells(in line: String) -> [String] {
        line.split(separator: ",", omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func isAxisDate(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 2, parts[1].count == 2, parts[2].count == 4,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]),
              year >= 1, (1...12).contains(month) else { return false }
        let leapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        let monthLengths = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return (1...monthLengths[month - 1]).contains(day)
    }

    private static func normalizeHeader(_ value: String) -> String {
        value
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func decimal(_ value: String) -> Decimal? {
        guard !value.isEmpty else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func eventEvidence(
        narration: String,
        debit: Decimal?,
        credit: Decimal?
    ) -> AxisUPITransactionEventEvidence? {
        let components = narration.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count >= 4, components[0] == "UPI" else { return nil }
        let operation: AxisUPITransactionEventEvidence.Operation
        switch components[1] {
        case "P2A": operation = .p2a
        case "P2M": operation = .p2m
        default: return nil
        }
        let reference = String(components[2])
        guard reference.count == 12,
              reference.unicodeScalars.allSatisfy({ $0.value >= 48 && $0.value <= 57 }) else {
            return nil
        }
        let subtype: AxisUPITransactionEventEvidence.LedgerSubtype
        switch (debit != nil, credit != nil) {
        case (true, false): subtype = .posting
        case (false, true): subtype = .creditAdjustment
        default: return nil
        }
        return AxisUPITransactionEventEvidence(
            operation: operation,
            reference: reference,
            subtype: subtype
        )
    }

}

private enum AxisSourceSemanticOracleError: Error {
    case invalidDirectionOccupancy
    case amountOrDirectionContradictsBalanceDelta
}

enum AxisSemanticFalsificationCase: CaseIterable {
    case drWhileBalanceRises
    case crWhileBalanceFalls
    case bothPopulated
    case neitherPopulated
    case drAmountMismatch
    case crAmountMismatch

    var sourceDR: Decimal? {
        switch self {
        case .drWhileBalanceRises, .drAmountMismatch: return 10
        case .bothPopulated: return 10
        case .crWhileBalanceFalls, .crAmountMismatch, .neitherPopulated: return nil
        }
    }

    var sourceCR: Decimal? {
        switch self {
        case .crWhileBalanceFalls, .crAmountMismatch: return 10
        case .bothPopulated: return 10
        case .drWhileBalanceRises, .drAmountMismatch, .neitherPopulated: return nil
        }
    }

    var currentBalance: Decimal {
        switch self {
        case .drWhileBalanceRises: return 110
        case .crWhileBalanceFalls: return 90
        case .bothPopulated, .neitherPopulated: return 100
        case .drAmountMismatch: return 95
        case .crAmountMismatch: return 105
        }
    }
}

private struct AxisNREFidelityExpectation: Decodable {
    let transactionCount: Int
    let debitTotal: Decimal
    let creditTotal: Decimal
    let rawDRColumnTotal: Decimal
    let rawCRColumnTotal: Decimal
    let openingBalance: Decimal
    let closingBalance: Decimal

    static func load(fileName: String) throws -> AxisNREFidelityExpectation {
        let data = try Data(contentsOf: FixtureLocator.axisExpected(fileName))
        return try JSONDecoder().decode(Self.self, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case transactionCount = "transaction_count"
        case debitTotal = "debit_total"
        case creditTotal = "credit_total"
        case rawDRColumnTotal = "raw_dr_column_total"
        case rawCRColumnTotal = "raw_cr_column_total"
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactionCount = try container.decode(Int.self, forKey: .transactionCount)
        debitTotal = try Self.decimal(container, key: .debitTotal)
        creditTotal = try Self.decimal(container, key: .creditTotal)
        rawDRColumnTotal = try Self.decimal(container, key: .rawDRColumnTotal)
        rawCRColumnTotal = try Self.decimal(container, key: .rawCRColumnTotal)
        openingBalance = try Self.decimal(container, key: .openingBalance)
        closingBalance = try Self.decimal(container, key: .closingBalance)
    }

    private static func decimal(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> Decimal {
        let value = try container.decode(String.self, forKey: key)
        return try #require(
            Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
        )
    }
}
