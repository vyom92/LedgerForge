// LedgerForgeTests/FinancialDocumentTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct FinancialDocumentTests {

    @Test func axisParserReturnsFinancialDocumentForApprovedCSVFixture() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()

        #expect(parsedFixture.financialDocument.sourceDocument.filename == parsedFixture.normalizedDocument.document.filename)
        #expect(parsedFixture.financialDocument.metadata == parsedFixture.normalizedDocument.metadata)
        #expect(parsedFixture.financialDocument.parserName == "Axis Bank Account")
        #expect(parsedFixture.financialDocument.transactions.count == parsedFixture.expected.transactionCount)
        #expect(parsedFixture.financialDocument.financialIdentifiers.count == 1)
        #expect(String(describing: type(of: parsedFixture.parser)) == parsedFixture.expected.expectedParser)
    }

    @Test func axisParserProducesVerifiedAccountIdentifierFromApprovedCSVFixture() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()
        let identifier = try #require(parsedFixture.financialDocument.financialIdentifiers.first)
        let expectedValue = try expectedStatementAccountValue(
            from: parsedFixture.normalizedDocument.sourceContext
        )

        #expect(parsedFixture.financialDocument.financialIdentifiers.count == 1)
        #expect(identifier.kind == .institutionAccountId)
        #expect(identifier.strength == .strong)
        #expect(identifier.verificationState == .verified)
        #expect(identifier.provenance == .institutionStructuredField)
        #expect(identifier.normalizedValue == expectedValue)
    }

    @Test func axisParserWithoutSourceContextPreservesTransactionsAndProducesNoIdentifier() throws {
        let financialDocument = try parseSyntheticAxisDocument(sourceFragments: [])

        #expect(financialDocument.transactions.count == 1)
        #expect(financialDocument.financialIdentifiers.isEmpty)
    }

    @Test func axisParserRejectsMaskedAndSuffixOnlyAccountEvidence() throws {
        let evidenceCases = [
            "Statement of Account No - XXXXX1234 for the period (From : 01-01-2026 To : 31-01-2026)",
            "Account suffix - 1234"
        ]

        for evidence in evidenceCases {
            let financialDocument = try parseSyntheticAxisDocument(sourceFragments: [evidence])

            #expect(financialDocument.transactions.count == 1)
            #expect(financialDocument.financialIdentifiers.isEmpty)
        }
    }

    @Test func axisParserIgnoresUnrelatedStructuredHeaderValues() throws {
        let financialDocument = try parseSyntheticAxisDocument(
            sourceFragments: [
                "Customer ID - 123456789",
                "IFSC - UTIB0000001",
                "MICR - 123456789",
                "Mobile - 1234567890"
            ]
        )

        #expect(financialDocument.transactions.count == 1)
        #expect(financialDocument.financialIdentifiers.isEmpty)
    }

    @Test func axisParserDeduplicatesRepeatedFullAccountEvidence() throws {
        let evidence = "Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)"
        let financialDocument = try parseSyntheticAxisDocument(
            sourceFragments: [evidence, evidence]
        )

        #expect(financialDocument.transactions.count == 1)
        #expect(financialDocument.financialIdentifiers.count == 1)
    }

    @Test func axisParserRejectsConflictingFullAccountEvidenceWithoutAffectingTransactions() throws {
        let financialDocument = try parseSyntheticAxisDocument(
            sourceFragments: [
                "Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)",
                "Statement of Account No - 987654321098765 for the period (From : 01-01-2026 To : 31-01-2026)"
            ]
        )

        #expect(financialDocument.transactions.count == 1)
        #expect(financialDocument.financialIdentifiers.isEmpty)
    }

    @Test func axisParserRejectsMalformedAccountEvidenceWithoutAffectingTransactions() throws {
        let evidenceCases = [
            "Statement of Account No - ABC123 for the period (From : 01-01-2026 To : 31-01-2026)",
            "Statement of Account No - 123456789012345"
        ]

        for evidence in evidenceCases {
            let financialDocument = try parseSyntheticAxisDocument(sourceFragments: [evidence])

            #expect(financialDocument.transactions.count == 1)
            #expect(financialDocument.financialIdentifiers.isEmpty)
        }
    }

    @Test func axisParserExtractsIdentifierWhenTransactionRowsAreEmpty() throws {
        let financialDocument = try parseSyntheticAxisDocument(
            sourceFragments: [
                "Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)"
            ],
            includeTransaction: false
        )

        #expect(financialDocument.transactions.isEmpty)
        #expect(financialDocument.financialIdentifiers.count == 1)
    }

    @Test func axisParserFinancialDocumentValidationMatchesApprovedBaseline() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()
        let validation = ImportValidator.validate(financialDocument: parsedFixture.financialDocument)
        let transactionValidation = ImportValidator.validate(transactions: parsedFixture.financialDocument.transactions)

        #expect(validation.rowsRead == transactionValidation.rowsRead)
        #expect(validation.transactionsParsed == transactionValidation.transactionsParsed)
        #expect(validation.debitTotal == transactionValidation.debitTotal)
        #expect(validation.creditTotal == transactionValidation.creditTotal)
        #expect(validation.openingBalance == transactionValidation.openingBalance)
        #expect(validation.closingBalance == transactionValidation.closingBalance)
        #expect(validation.passed == transactionValidation.passed)
        #expect(validation.issues.count == transactionValidation.issues.count)
        #expect(validation.debitTotal == parsedFixture.expected.debitTotalDecimal)
        #expect(validation.creditTotal == parsedFixture.expected.creditTotalDecimal)
        #expect(validation.openingBalance == parsedFixture.expected.openingBalanceDecimal)
        #expect(validation.closingBalance == parsedFixture.expected.closingBalanceDecimal)
        #expect(validation.passed == parsedFixture.expected.validationPassed)
    }

    @Test func axisParserFinancialDocumentPreservesTransactionOrderingAndValues() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()
        let transactions = parsedFixture.financialDocument.transactions

        #expect(transactions.count == parsedFixture.expected.transactionCount)
        #expect(Self.dayMonthYearFormatter.string(from: try #require(transactions.first?.date)) == parsedFixture.expected.firstTransactionDate)
        #expect(Self.dayMonthYearFormatter.string(from: try #require(transactions.last?.date)) == parsedFixture.expected.lastTransactionDate)
        #expect(transactions.allSatisfy { $0.sourceFile == parsedFixture.normalizedDocument.document.filename })
    }

    @Test func financialDocumentModelStoresParserOutputWithoutCalculations() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()
        let createdAt = Date(timeIntervalSince1970: 1_804_896_000)
        let financialDocument = FinancialDocument(
            sourceDocument: parsedFixture.normalizedDocument.document,
            metadata: parsedFixture.normalizedDocument.metadata,
            parserName: parsedFixture.parser.name,
            transactions: parsedFixture.financialDocument.transactions,
            selectionReasons: ["Parser produced FinancialDocument directly."],
            createdAt: createdAt
        )

        #expect(financialDocument.sourceDocument.filename == parsedFixture.normalizedDocument.document.filename)
        #expect(financialDocument.metadata == parsedFixture.normalizedDocument.metadata)
        #expect(financialDocument.parserName == parsedFixture.parser.name)
        #expect(financialDocument.transactions.count == parsedFixture.expected.transactionCount)
        #expect(financialDocument.financialIdentifiers.isEmpty)
        #expect(financialDocument.selectionReasons == ["Parser produced FinancialDocument directly."])
        #expect(financialDocument.createdAt == createdAt)
    }

    @Test func financialDocumentPreservesParserProducedFinancialIdentifiers() async throws {
        let parsedFixture = try await parseApprovedAxisCSVFixture()
        let identifier = try FinancialIdentifier(
            kind: .institutionAccountId,
            rawValue: "axis.account:1234",
            verificationState: .verified,
            provenance: .institutionStructuredField
        )
        let financialDocument = FinancialDocument(
            sourceDocument: parsedFixture.normalizedDocument.document,
            metadata: parsedFixture.normalizedDocument.metadata,
            parserName: parsedFixture.parser.name,
            transactions: parsedFixture.financialDocument.transactions,
            financialIdentifiers: [identifier]
        )

        let preservedIdentifier = try #require(financialDocument.financialIdentifiers.first)

        #expect(financialDocument.financialIdentifiers == [identifier])
        #expect(preservedIdentifier.kind == .institutionAccountId)
        #expect(preservedIdentifier.normalizedValue == "AXIS.ACCOUNT:1234")
        #expect(preservedIdentifier.strength == .strong)
        #expect(preservedIdentifier.verificationState == .verified)
        #expect(preservedIdentifier.provenance == .institutionStructuredField)
    }

    private static let dayMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private func expectedStatementAccountValue(
        from sourceContext: NormalizedDocument.SourceContext
    ) throws -> String {
        let prefix = "Statement of Account No - "
        let periodMarker = " for the period ("
        let sourceText = try #require(
            sourceContext.preTransactionFragments
                .map(\.text)
                .first { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(prefix) }
        )
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let remainder = text.dropFirst(prefix.count)
        let periodRange = try #require(remainder.range(of: periodMarker))
        let value = String(remainder[..<periodRange.lowerBound])

        #expect(!value.isEmpty)
        #expect(value.allSatisfy { $0.isASCII && $0.isNumber })

        return value
    }

    private func parseSyntheticAxisDocument(
        sourceFragments: [String],
        includeTransaction: Bool = true
    ) throws -> FinancialDocument {
        let importedAt = Date(timeIntervalSince1970: 1_767_225_600)
        let document = Document(
            filename: "axis-parser-test.csv",
            url: URL(fileURLWithPath: "/tmp/axis-parser-test.csv"),
            fileType: "CSV",
            importedAt: importedAt
        )
        let metadata = DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: .csv,
            confidence: 1
        )
        let rows = includeTransaction
            ? [
                NormalizedRow(
                    rowNumber: 1,
                    values: ["01-01-2026", "", "Opening credit", "100", "", "1100"]
                )
            ]
            : []
        let sourceContext = NormalizedDocument.SourceContext(
            preTransactionFragments: sourceFragments.enumerated().map { index, text in
                NormalizedDocument.SourceFragment(
                    sourceOrdinal: index + 1,
                    text: text
                )
            }
        )
        let normalizedDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: rows,
            sourceContext: sourceContext
        )

        return try AxisBankAccountParser().parse(document: normalizedDocument)
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
        let normalization = CSVNormalizer().normalizeWithSourceContext(
            text: text,
            document: document
        )
        let normalizedDocument = NormalizedDocument(
            document: document,
            metadata: selection.legacyMetadata,
            rows: normalization.rows,
            sourceContext: normalization.sourceContext
        )
        let financialDocument = try parser.parse(document: normalizedDocument)
        let expected = try ExpectedFinancialDocumentBaseline.axisBankNREBaseline()

        return ParsedAxisFixture(
            normalizedDocument: normalizedDocument,
            selection: selection,
            parser: parser,
            financialDocument: financialDocument,
            expected: expected
        )
    }

}

private struct ParsedAxisFixture {
    let normalizedDocument: NormalizedDocument
    let selection: ParserSelection
    let parser: StatementParser
    let financialDocument: FinancialDocument
    let expected: ExpectedFinancialDocumentBaseline
}

private struct ExpectedFinancialDocumentBaseline: Decodable {
    let expectedParser: String
    let transactionCount: Int
    let debitTotalDecimal: Decimal
    let creditTotalDecimal: Decimal
    let openingBalanceDecimal: Decimal
    let closingBalanceDecimal: Decimal
    let firstTransactionDate: String
    let lastTransactionDate: String
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
        firstTransactionDate = try container.decode(String.self, forKey: .firstTransactionDate)
        lastTransactionDate = try container.decode(String.self, forKey: .lastTransactionDate)
        validationResult = try container.decode(String.self, forKey: .validationResult)
    }

    private enum CodingKeys: String, CodingKey {
        case expectedParser = "expected_parser"
        case transactionCount = "transaction_count"
        case debitTotal = "debit_total"
        case creditTotal = "credit_total"
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
        case firstTransactionDate = "first_transaction_date"
        case lastTransactionDate = "last_transaction_date"
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
