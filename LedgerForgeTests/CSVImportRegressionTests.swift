// LedgerForgeTests/CSVImportRegressionTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct CSVImportRegressionTests {

    @Test func axisBankNRECSVFixtureMatchesCurrentImportBaseline() async throws {
        let fixture = try CSVBaselineFixture.load(
            csvFileName: "axis_bank_nre_account_statement_baseline.csv",
            expectedFileName: "axis_bank_nre_account_statement_baseline.expected.json"
        )

        let text = try CSVReader().read(from: fixture.csvURL)
        let document = CSVAnalyzer().analyze(text: text, fileURL: fixture.csvURL)
        let metadata = InstitutionDetector().detect(from: text)
        let rows = CSVNormalizer().normalize(text: text, document: document)
        let parser = try #require(
            StatementParserRegistry.shared.parser(for: document, metadata: metadata),
            "Expected the current CSV path to select a parser for the approved Axis Bank fixture."
        )

        let normalizedDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: rows
        )
        let transactions = try parser.parse(document: normalizedDocument)
        let validation = ImportValidator.validate(transactions: transactions)

        #expect(String(describing: type(of: parser)) == fixture.expected.expectedParser)
        #expect(transactions.count == fixture.expected.transactionCount)
        #expect(validation.debitTotal == fixture.expected.debitTotalDecimal)
        #expect(validation.creditTotal == fixture.expected.creditTotalDecimal)
        #expect(validation.openingBalance == fixture.expected.openingBalanceDecimal)
        #expect(validation.closingBalance == fixture.expected.closingBalanceDecimal)
        #expect(validation.passed == fixture.expected.validationPassed)
    }

}

private struct CSVBaselineFixture {
    let csvURL: URL
    let expected: ExpectedCSVBaseline

    static func load(csvFileName: String, expectedFileName: String) throws -> CSVBaselineFixture {
        let csvURL = FixtureLocator.axisCSV(csvFileName)
        let expectedURL = FixtureLocator.axisExpected(expectedFileName)
        let expectedData = try Data(contentsOf: expectedURL)
        let expected = try JSONDecoder().decode(ExpectedCSVBaseline.self, from: expectedData)

        return CSVBaselineFixture(csvURL: csvURL, expected: expected)
    }
}

private struct ExpectedCSVBaseline: Decodable {
    let institution: String
    let accountType: String
    let currency: String
    let expectedParser: String
    let transactionCount: Int
    let debitTotalDecimal: Decimal
    let creditTotalDecimal: Decimal
    let rawDRColumnTotalDecimal: Decimal
    let rawCRColumnTotalDecimal: Decimal
    let openingBalanceDecimal: Decimal
    let closingBalanceDecimal: Decimal
    let firstTransactionDate: String
    let lastTransactionDate: String
    let validationResult: String
    let notes: [String]

    var validationPassed: Bool {
        validationResult == "expected valid"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        institution = try container.decode(String.self, forKey: .institution)
        accountType = try container.decode(String.self, forKey: .accountType)
        currency = try container.decode(String.self, forKey: .currency)
        expectedParser = try container.decode(String.self, forKey: .expectedParser)
        transactionCount = try container.decode(Int.self, forKey: .transactionCount)
        debitTotalDecimal = try Self.decimal(from: container, key: .debitTotal)
        creditTotalDecimal = try Self.decimal(from: container, key: .creditTotal)
        rawDRColumnTotalDecimal = try Self.decimal(from: container, key: .rawDRColumnTotal)
        rawCRColumnTotalDecimal = try Self.decimal(from: container, key: .rawCRColumnTotal)
        openingBalanceDecimal = try Self.decimal(from: container, key: .openingBalance)
        closingBalanceDecimal = try Self.decimal(from: container, key: .closingBalance)
        firstTransactionDate = try container.decode(String.self, forKey: .firstTransactionDate)
        lastTransactionDate = try container.decode(String.self, forKey: .lastTransactionDate)
        validationResult = try container.decode(String.self, forKey: .validationResult)
        notes = try container.decode([String].self, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case institution
        case accountType = "account_type"
        case currency
        case expectedParser = "expected_parser"
        case transactionCount = "transaction_count"
        case debitTotal = "debit_total"
        case creditTotal = "credit_total"
        case rawDRColumnTotal = "raw_dr_column_total"
        case rawCRColumnTotal = "raw_cr_column_total"
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
        case firstTransactionDate = "first_transaction_date"
        case lastTransactionDate = "last_transaction_date"
        case validationResult = "validation_result"
        case notes
    }

    private static func decimal(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> Decimal {
        let value = try container.decode(String.self, forKey: key)

        guard let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Expected a decimal string for \(key.rawValue)."
            )
        }

        return decimal
    }
}
