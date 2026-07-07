// LedgerForgeTests/FinancialDocumentTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct FinancialDocumentTests {

    @Test func builderCreatesFinancialDocumentFromApprovedAxisCSVParserOutput() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()
        let financialDocument = try FinancialDocumentBuilder.build(
            normalizedDocument: parsedFixture.normalizedDocument,
            parserSelection: parsedFixture.selection,
            transactions: parsedFixture.transactions,
            createdAt: parsedFixture.createdAt
        )

        #expect(financialDocument.sourceDocument.filename == parsedFixture.normalizedDocument.document.filename)
        #expect(financialDocument.metadata == parsedFixture.normalizedDocument.metadata)
        #expect(financialDocument.parserName == "Axis Bank Account")
        #expect(financialDocument.transactions.count == parsedFixture.expected.transactionCount)
        #expect(financialDocument.transactions.count == parsedFixture.transactions.count)
        #expect(financialDocument.selectionReasons == parsedFixture.selection.reasons)
        #expect(financialDocument.createdAt == parsedFixture.createdAt)
    }

    @Test func financialDocumentValidationDelegatesToExistingTransactionValidation() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()
        let financialDocument = try FinancialDocumentBuilder.build(
            normalizedDocument: parsedFixture.normalizedDocument,
            parserSelection: parsedFixture.selection,
            transactions: parsedFixture.transactions
        )

        let documentValidation = ImportValidator.validate(financialDocument: financialDocument)
        let transactionValidation = ImportValidator.validate(transactions: parsedFixture.transactions)

        #expect(documentValidation.rowsRead == transactionValidation.rowsRead)
        #expect(documentValidation.transactionsParsed == transactionValidation.transactionsParsed)
        #expect(documentValidation.debitTotal == transactionValidation.debitTotal)
        #expect(documentValidation.creditTotal == transactionValidation.creditTotal)
        #expect(documentValidation.openingBalance == transactionValidation.openingBalance)
        #expect(documentValidation.closingBalance == transactionValidation.closingBalance)
        #expect(documentValidation.passed == transactionValidation.passed)
        #expect(documentValidation.issues.count == transactionValidation.issues.count)
        #expect(documentValidation.debitTotal == parsedFixture.expected.debitTotalDecimal)
        #expect(documentValidation.creditTotal == parsedFixture.expected.creditTotalDecimal)
        #expect(documentValidation.openingBalance == parsedFixture.expected.openingBalanceDecimal)
        #expect(documentValidation.closingBalance == parsedFixture.expected.closingBalanceDecimal)
        #expect(documentValidation.passed == parsedFixture.expected.validationPassed)
    }

    @Test func directBuilderPreservesParserOutputWithoutSelectionDependency() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()
        let financialDocument = FinancialDocumentBuilder.build(
            normalizedDocument: parsedFixture.normalizedDocument,
            parserName: parsedFixture.parser.name,
            transactions: parsedFixture.transactions,
            selectionReasons: ["Selected parser: Axis Bank Account."],
            createdAt: parsedFixture.createdAt
        )

        #expect(financialDocument.parserName == parsedFixture.parser.name)
        #expect(financialDocument.transactions.count == parsedFixture.transactions.count)
        #expect(financialDocument.metadata == parsedFixture.normalizedDocument.metadata)
        #expect(financialDocument.selectionReasons == ["Selected parser: Axis Bank Account."])
        #expect(financialDocument.createdAt == parsedFixture.createdAt)
    }

    @Test func builderRejectsUnmatchedParserSelection() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()
        let unmatchedSelection = ParserSelection(
            parser: nil,
            parserName: nil,
            matched: false,
            confidence: 0.0,
            reasons: ["No parser selected."],
            legacyMetadata: parsedFixture.normalizedDocument.metadata
        )

        do {
            _ = try FinancialDocumentBuilder.build(
                normalizedDocument: parsedFixture.normalizedDocument,
                parserSelection: unmatchedSelection,
                transactions: parsedFixture.transactions
            )

            Issue.record("Expected FinancialDocumentBuilder to reject unmatched parser selection.")
        } catch let error as FinancialDocumentBuilderError {
            #expect(error == .parserNotSelected)
        } catch {
            Issue.record("Expected FinancialDocumentBuilderError.parserNotSelected, got \(error).")
        }
    }

    private func parseApprovedAxisCSVFixture() async throws -> ParsedAxisFixture {
        let csvURL = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let text = try CSVReader().read(from: csvURL)
        let rawDocument = RawDocument(
            sourceURL: csvURL,
            fileName: csvURL.lastPathComponent,
            fileExtension: csvURL.pathExtension,
            content: .text(text)
        )
        let document = CSVAnalyzer().analyze(text: text, fileURL: csvURL)
        let institution = try await SignatureInstitutionDetector().detectInstitution(in: rawDocument)
        let classification = try await StatementClassificationDetector().classify(
            document: rawDocument,
            institution: institution
        )
        let selection = StatementParserSelector().selectParser(
            for: document,
            institution: institution,
            classification: classification
        )
        let parser = try #require(selection.parser)
        let rows = CSVNormalizer().normalize(text: text, document: document)
        let normalizedDocument = NormalizedDocument(
            document: document,
            metadata: selection.legacyMetadata,
            rows: rows
        )
        let transactions = try parser.parse(document: normalizedDocument)
        let expected = try ExpectedFinancialDocumentBaseline.axisBankNREBaseline()

        return ParsedAxisFixture(
            normalizedDocument: normalizedDocument,
            selection: selection,
            parser: parser,
            transactions: transactions,
            expected: expected,
            createdAt: Date(timeIntervalSince1970: 1_804_896_000)
        )
    }

}

private struct ParsedAxisFixture {
    let normalizedDocument: NormalizedDocument
    let selection: ParserSelection
    let parser: StatementParser
    let transactions: [Transaction]
    let expected: ExpectedFinancialDocumentBaseline
    let createdAt: Date
}

private struct ExpectedFinancialDocumentBaseline: Decodable {
    let expectedParser: String
    let transactionCount: Int
    let debitTotalDecimal: Decimal
    let creditTotalDecimal: Decimal
    let openingBalanceDecimal: Decimal
    let closingBalanceDecimal: Decimal
    let validationResult: String

    var validationPassed: Bool {
        validationResult == "expected valid"
    }

    static func axisBankNREBaseline() throws -> ExpectedFinancialDocumentBaseline {
        let url = FixtureLocator.axisExpected("axis_bank_nre_account_statement_baseline.expected.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ExpectedFinancialDocumentBaseline.self, from: data)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        expectedParser = try container.decode(String.self, forKey: .expectedParser)
        transactionCount = try container.decode(Int.self, forKey: .transactionCount)
        debitTotalDecimal = try Self.decimal(from: container, key: .debitTotal)
        creditTotalDecimal = try Self.decimal(from: container, key: .creditTotal)
        openingBalanceDecimal = try Self.decimal(from: container, key: .openingBalance)
        closingBalanceDecimal = try Self.decimal(from: container, key: .closingBalance)
        validationResult = try container.decode(String.self, forKey: .validationResult)
    }

    private enum CodingKeys: String, CodingKey {
        case expectedParser = "expected_parser"
        case transactionCount = "transaction_count"
        case debitTotal = "debit_total"
        case creditTotal = "credit_total"
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
        case validationResult = "validation_result"
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
