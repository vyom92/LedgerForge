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
        let normalization = CSVNormalizer().normalizeWithSourceContext(
            text: text,
            document: document
        )
        let parser = try #require(
            StatementParserRegistry.shared.parser(for: document, metadata: metadata),
            "Expected the current CSV path to select a parser for the approved Axis Bank fixture."
        )

        let normalizedDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: normalization.rows,
            sourceContext: normalization.sourceContext
        )
        let financialDocument = try parser.parse(document: normalizedDocument)
        let validation = ImportValidator.validate(financialDocument: financialDocument)

        #expect(String(describing: type(of: parser)) == fixture.expected.expectedParser)
        #expect(metadata.institution.rawValue == fixture.expected.institution)
        #expect(financialDocument.transactions.count == fixture.expected.transactionCount)
        #expect(financialDocument.transactions.first?.currency == fixture.expected.currency)
        #expect(validation.debitTotal == fixture.expected.debitTotalDecimal)
        #expect(validation.creditTotal == fixture.expected.creditTotalDecimal)
        #expect(validation.openingBalance == fixture.expected.openingBalanceDecimal)
        #expect(validation.closingBalance == fixture.expected.closingBalanceDecimal)
        #expect(validation.passed == fixture.expected.validationPassed)
        #expect(financialDocument.financialIdentifiers.isEmpty)
    }

    @Test func sourceContextPreservesExactPreTransactionFragmentsAndBoundary() {
        let text = "  Account Number,001  \n\nTran Date,Particulars,Debit,Credit,Balance\n01-01-2026,First,100,,900\n02-01-2026,Second,,25,925"
        let document = Self.makeDocument(firstTransactionRow: 4, delimiter: ",")

        let result = CSVNormalizer().normalizeWithSourceContext(
            text: text,
            document: document
        )

        let fragments = result.sourceContext.preTransactionFragments

        #expect(fragments.count == 3)
        #expect(fragments.map { $0.sourceOrdinal } == [1, 2, 3])
        #expect(fragments.map { $0.text } == [
            "  Account Number,001  ",
            "",
            "Tran Date,Particulars,Debit,Credit,Balance"
        ])
        #expect(!fragments.map { $0.text }.contains("01-01-2026,First,100,,900"))
        #expect(!fragments.map { $0.text }.contains("02-01-2026,Second,,25,925"))
    }

    @Test func invalidOrMissingNormalizationPrerequisitesReturnEmptyRowsAndContext() {
        let text = "Header,Value\nTransaction,1"
        let documents = [
            Self.makeDocument(firstTransactionRow: 2, delimiter: nil),
            Self.makeDocument(firstTransactionRow: nil, delimiter: ","),
            Self.makeDocument(firstTransactionRow: 0, delimiter: ","),
            Self.makeDocument(firstTransactionRow: 3, delimiter: ",")
        ]

        for document in documents {
            let result = CSVNormalizer().normalizeWithSourceContext(
                text: text,
                document: document
            )
            let compatibilityRows = CSVNormalizer().normalize(
                text: text,
                document: document
            )

            #expect(result.rows.isEmpty)
            #expect(result.sourceContext.preTransactionFragments.isEmpty)
            #expect(compatibilityRows.isEmpty)
        }
    }

    @Test func rowOnlyNormalizationMatchesCompositeNormalizationRows() {
        let text = "Header,Value\n01-01-2026, Description ,, 10 \n\n"
        let document = Self.makeDocument(firstTransactionRow: 2, delimiter: ",")
        let normalizer = CSVNormalizer()

        let result = normalizer.normalizeWithSourceContext(
            text: text,
            document: document
        )
        let compatibilityRows = normalizer.normalize(
            text: text,
            document: document
        )

        #expect(compatibilityRows.map { $0.rowNumber } == result.rows.map { $0.rowNumber })
        #expect(compatibilityRows.map { $0.values } == result.rows.map { $0.values })
        #expect(result.rows.map { $0.rowNumber } == [2])
        #expect(result.rows.map { $0.values } == [["01-01-2026", "Description", "", "10"]])
    }

    @Test func normalizedDocumentDefaultsAndRetainsSourceContext() {
        let document = Self.makeDocument(firstTransactionRow: 2, delimiter: ",")
        let metadata = DocumentMetadata(
            institution: .unknown,
            documentType: .unknown,
            fileFormat: .csv,
            confidence: 0
        )
        let defaultDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: []
        )
        let sourceContext = NormalizedDocument.SourceContext(
            preTransactionFragments: [
                NormalizedDocument.SourceFragment(
                    sourceOrdinal: 1,
                    text: "  exact source  "
                ),
                NormalizedDocument.SourceFragment(
                    sourceOrdinal: 2,
                    text: ""
                )
            ]
        )
        let explicitDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: [],
            sourceContext: sourceContext
        )

        #expect(defaultDocument.sourceContext.preTransactionFragments.isEmpty)
        #expect(explicitDocument.sourceContext.preTransactionFragments.map { $0.sourceOrdinal } == [1, 2])
        #expect(explicitDocument.sourceContext.preTransactionFragments.map { $0.text } == [
            "  exact source  ",
            ""
        ])
    }

    private static func makeDocument(
        firstTransactionRow: Int?,
        delimiter: Character?
    ) -> Document {
        var document = Document(
            filename: "sprint-34.csv",
            url: URL(fileURLWithPath: "/tmp/sprint-34.csv"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 0)
        )
        document.firstTransactionRow = firstTransactionRow
        document.delimiter = delimiter
        return document
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
