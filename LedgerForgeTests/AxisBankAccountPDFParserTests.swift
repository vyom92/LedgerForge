import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisBankAccountPDFParserTests {

    @Test func baselineApprovedPDFMatchesIndependentRowOracle() async throws {
        try await verifyApprovedFixture(
            pdfName: "axis_bank_nro_account_statement_baseline.pdf",
            expectedName:
                "axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.expected.json",
            settledTransactionCount: 16
        )
    }

    @Test func extendedApprovedPDFMatchesIndependentRowOracle() async throws {
        try await verifyApprovedFixture(
            pdfName: "axis_bank_nro_account_statement_extended.pdf",
            expectedName: "axis_bank_nro_account_statement_extended.expected.json",
            settledTransactionCount: 20
        )
    }

    @Test func exactBalanceArithmeticProducesCanonicalFinancialDocument() throws {
        let prepared = try normalizedDocument()
        let financialDocument = try AxisBankAccountPDFParser().parse(
            document: prepared
        )

        #expect(financialDocument.parserName == "Axis Bank Account PDF")
        #expect(financialDocument.bookedCurrency?.code == "INR")
        #expect(financialDocument.transactions.count == 2)
        #expect(financialDocument.declaredStatementPeriod?.start.canonical == "2026-04-01")
        #expect(financialDocument.declaredStatementPeriod?.end.canonical == "2026-06-30")

        let identifier = try #require(
            financialDocument.financialIdentifiers.first
        )
        #expect(financialDocument.financialIdentifiers.count == 1)
        #expect(identifier.kind == .institutionAccountId)
        #expect(identifier.verificationState == .verified)
        #expect(identifier.provenance == .institutionStructuredField)
        #expect(identifier.normalizedValue == "123456789012345")

        let debit = financialDocument.transactions[0]
        #expect(debit.statementDate?.canonical == "2026-04-01")
        #expect(debit.debit == Decimal(25))
        #expect(debit.credit == nil)
        #expect(debit.amount == Decimal(-25))
        #expect(debit.balance == Decimal(75))
        #expect(debit.statementTimezoneEvidence == .iana("Asia/Kolkata"))
        #expect(debit.verifiedAxisUPIEventEvidence?.subtype == .posting)

        let credit = financialDocument.transactions[1]
        #expect(credit.statementDate?.canonical == "2026-04-02")
        #expect(credit.debit == nil)
        #expect(credit.credit == Decimal(10))
        #expect(credit.amount == Decimal(10))
        #expect(credit.balance == Decimal(85))
        #expect(credit.verifiedAxisUPIEventEvidence?.subtype == .creditAdjustment)

        #expect(debit.sourceProvenance.first?.sourceOrdinal == 7)
        #expect(credit.sourceProvenance.first?.sourceOrdinal == 8)
        #expect(debit.sourceProvenance.first?.parserProfileID == "axis.bank-account.pdf")
        #expect(debit.sourceProvenance.first?.parserProfileVersion == "1")
        #expect(
            debit.sourceProvenance.first?.normalizedRecordDigest ==
                String.normalizedRecordDigest(values: prepared.rows[0].values)
        )
        #expect(prepared.rows[0].values[AxisBankAccountPDFColumn.branchCode.rawValue] == "4437")

        let validation = ImportValidator.validate(
            financialDocument: financialDocument
        )
        #expect(validation.passed)
        #expect(validation.openingBalance == Decimal(100))
        #expect(validation.debitTotal == Decimal(25))
        #expect(validation.creditTotal == Decimal(10))
        #expect(validation.closingBalance == Decimal(85))
    }

    @Test func NREAndNROLabelsDoNotSelectProfileOrIdentity() throws {
        let nro = try AxisBankAccountPDFParser().parse(
            document: normalizedDocument(scheme: "NRO")
        )
        let nre = try AxisBankAccountPDFParser().parse(
            document: normalizedDocument(scheme: "NRE")
        )

        #expect(nro.financialIdentifiers == nre.financialIdentifiers)
        #expect(nro.financialIdentifiers.count == 1)
        #expect(nro.transactions[0].sourceProvenance[0].parserProfileID == "axis.bank-account.pdf")
        #expect(nre.transactions[0].sourceProvenance[0].parserProfileID == "axis.bank-account.pdf")
        #expect(nro.transactions[0].sourceProvenance[0].parserProfileVersion == "1")
        #expect(nre.transactions[0].sourceProvenance[0].parserProfileVersion == "1")
    }

    @Test func parserSelectionIsStrictlyFormatSpecific() {
        let csvDocument = Document(
            filename: "statement.csv",
            url: URL(fileURLWithPath: "/tmp/statement.csv"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 0)
        )
        let pdfDocument = Document(
            filename: "statement.pdf",
            url: URL(fileURLWithPath: "/tmp/statement.pdf"),
            fileType: "PDF",
            importedAt: Date(timeIntervalSince1970: 0)
        )
        let csvMetadata = DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: .csv,
            confidence: 1
        )
        let pdfMetadata = DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: .pdf,
            confidence: 1
        )
        let legacyCSVMetadata = DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: .unknown,
            confidence: 1
        )

        #expect(AxisBankAccountParser().canParse(
            document: csvDocument,
            metadata: csvMetadata
        ))
        #expect(AxisBankAccountParser().canParse(
            document: csvDocument,
            metadata: legacyCSVMetadata
        ))
        #expect(!AxisBankAccountParser().canParse(
            document: csvDocument,
            metadata: pdfMetadata
        ))
        #expect(!AxisBankAccountParser().canParse(
            document: pdfDocument,
            metadata: pdfMetadata
        ))
        #expect(AxisBankAccountPDFParser().canParse(
            document: pdfDocument,
            metadata: pdfMetadata
        ))
        #expect(!AxisBankAccountPDFParser().canParse(
            document: csvDocument,
            metadata: csvMetadata
        ))
    }

    @Test func impossibleAndAmbiguousBalanceArithmeticFailClosed() throws {
        let impossible = try replacingRow(
            in: normalizedDocument(),
            at: 0,
            column: .balance,
            with: "80.00"
        )
        #expect(
            throws: AxisBankAccountPDFParserError
                .impossibleBalanceTransition(sourceOrdinal: 7)
        ) {
            try AxisBankAccountPDFParser().parse(document: impossible)
        }

        var ambiguous = try normalizedDocument()
        ambiguous = try replacingRow(
            in: ambiguous,
            at: 0,
            column: .collapsedAmount,
            with: "0.00"
        )
        ambiguous = try replacingRow(
            in: ambiguous,
            at: 0,
            column: .balance,
            with: "100.00"
        )
        #expect(
            throws: AxisBankAccountPDFParserError
                .ambiguousDirection(sourceOrdinal: 7)
        ) {
            try AxisBankAccountPDFParser().parse(document: ambiguous)
        }
    }

    @Test func explicitSourceSideMustMatchExactBalanceTransition() throws {
        var contradicted = try normalizedDocument()
        contradicted = try replacingRow(
            in: contradicted,
            at: 0,
            column: .collapsedAmount,
            with: ""
        )
        contradicted = try replacingRow(
            in: contradicted,
            at: 0,
            column: .sourceCredit,
            with: "25.00"
        )

        #expect(
            throws: AxisBankAccountPDFParserError
                .sourceDirectionContradictsBalance(sourceOrdinal: 7)
        ) {
            try AxisBankAccountPDFParser().parse(document: contradicted)
        }
    }

    @Test func bothPhysicalAmountSidesFailAsAmbiguous() throws {
        var ambiguous = try normalizedDocument()
        ambiguous = try replacingRow(
            in: ambiguous,
            at: 0,
            column: .collapsedAmount,
            with: ""
        )
        ambiguous = try replacingRow(
            in: ambiguous,
            at: 0,
            column: .sourceDebit,
            with: "25.00"
        )
        ambiguous = try replacingRow(
            in: ambiguous,
            at: 0,
            column: .sourceCredit,
            with: "25.00"
        )

        #expect(
            throws: AxisBankAccountPDFParserError
                .ambiguousDirection(sourceOrdinal: 7)
        ) {
            try AxisBankAccountPDFParser().parse(document: ambiguous)
        }
    }

    @Test func malformedDecimalAndMissingDirectionFailClosed() throws {
        let malformed = try replacingRow(
            in: normalizedDocument(),
            at: 0,
            column: .collapsedAmount,
            with: "25"
        )
        #expect(
            throws: AxisBankAccountPDFParserError
                .malformedDecimal(sourceOrdinal: 7)
        ) {
            try AxisBankAccountPDFParser().parse(document: malformed)
        }

        let missing = try replacingRow(
            in: normalizedDocument(),
            at: 0,
            column: .collapsedAmount,
            with: ""
        )
        #expect(
            throws: AxisBankAccountPDFParserError
                .missingDirection(sourceOrdinal: 7)
        ) {
            try AxisBankAccountPDFParser().parse(document: missing)
        }
    }

    @Test func printedTotalsAndClosingBalanceMustMatchExactly() throws {
        let debitMismatch = try replacingRow(
            in: normalizedDocument(),
            at: 1,
            column: .printedDebitTotal,
            with: "24.99"
        )
        #expect(
            throws: AxisBankAccountPDFParserError.printedDebitTotalMismatch
        ) {
            try AxisBankAccountPDFParser().parse(document: debitMismatch)
        }

        let closingMismatch = try replacingRow(
            in: normalizedDocument(),
            at: 1,
            column: .closingBalance,
            with: "84.99"
        )
        #expect(
            throws: AxisBankAccountPDFParserError.closingBalanceMismatch
        ) {
            try AxisBankAccountPDFParser().parse(document: closingMismatch)
        }

        let creditMismatch = try replacingRow(
            in: normalizedDocument(),
            at: 1,
            column: .printedCreditTotal,
            with: "9.99"
        )
        #expect(
            throws: AxisBankAccountPDFParserError.printedCreditTotalMismatch
        ) {
            try AxisBankAccountPDFParser().parse(document: creditMismatch)
        }
    }

    @Test func malformedOrConflictingTitleEvidenceFailsClosed() throws {
        let malformed = try replacingSourceFragments(
            in: normalizedDocument(),
            with: [
                "Statement of Axis Account No : XXXXX1234 for the period (From : 01-04-2026 To : 30-06-2026)"
            ]
        )
        #expect(
            throws: AxisBankAccountPDFParserError
                .malformedAccountIdentifier(sourceOrdinal: 1)
        ) {
            try AxisBankAccountPDFParser().parse(document: malformed)
        }

        let truncated = try replacingSourceFragments(
            in: normalizedDocument(),
            with: [
                "Statement of Axis Account No : 1 for the period (From : 01-04-2026 To : 30-06-2026)"
            ]
        )
        #expect(
            throws: AxisBankAccountPDFParserError
                .malformedAccountIdentifier(sourceOrdinal: 1)
        ) {
            try AxisBankAccountPDFParser().parse(document: truncated)
        }

        let title = "Statement of Axis Account No : 123456789012345 for the period (From : 01-04-2026 To : 30-06-2026)"
        let conflicting = try replacingSourceFragments(
            in: normalizedDocument(),
            with: [
                title,
                "Statement of Axis Account No : 123456789012346 for the period (From : 01-04-2026 To : 30-06-2026)"
            ]
        )
        #expect(
            throws: AxisBankAccountPDFParserError.conflictingTitleEvidence
        ) {
            try AxisBankAccountPDFParser().parse(document: conflicting)
        }
    }

    private func normalizedDocument(
        scheme: String = "NRO"
    ) throws -> NormalizedDocument {
        let text = """
        Axis Bank
        Scheme: \(scheme)
        Statement of Axis Account No : 123456789012345 for the period (From : 01-04-2026 To : 30-06-2026)
        Tran Date Chq No Particulars Debit Credit Balance Init.
        Br
        OPENING BALANCE 100.00
        01-04-2026 - UPI/P2M/000000000101/TEST PAYMENT 25.00 75.00 4437
        02-04-2026
        UPI/P2A/000000000102/TEST
        CREDIT 10.00 85.00 4437
        TRANSACTION TOTAL 25.00 10.00
        CLOSING BALANCE 85.00
        """
        let result = try AxisBankAccountPDFNormalizer(
            now: { Date(timeIntervalSince1970: 1_767_225_600) }
        ).normalize(
            text: text,
            fileURL: URL(fileURLWithPath: "/tmp/axis-bank-account.pdf")
        )

        return NormalizedDocument(
            document: result.document,
            metadata: DocumentMetadata(
                institution: .axis,
                documentType: .bankAccount,
                fileFormat: .pdf,
                confidence: 1
            ),
            rows: result.rows,
            header: result.header,
            sourceContext: result.sourceContext
        )
    }

    private func verifyApprovedFixture(
        pdfName: String,
        expectedName: String,
        settledTransactionCount: Int
    ) async throws {
        let expected = try JSONDecoder().decode(
            AxisBankAccountPDFExpected.self,
            from: Data(contentsOf: FixtureLocator.axisExpected(expectedName))
        )
        #expect(expected.transactionCount == settledTransactionCount)
        #expect(expected.transactions.count == settledTransactionCount)

        let url = FixtureLocator.axisPDF(pdfName)
        let snapshot = SourceContentSnapshot(
            bytes: try Data(contentsOf: url)
        )
        defer { snapshot.invalidate() }
        let rawDocument = try await PDFDocumentReader().read(
            request: ImportRequest(fileURL: url),
            snapshot: snapshot,
            password: nil
        )
        guard case .text(let text) = rawDocument.content else {
            Issue.record("Expected selectable text from approved PDF fixture.")
            return
        }

        let normalization = try AxisBankAccountPDFNormalizer(
            now: { rawDocument.extractedAt }
        ).normalize(
            text: text,
            fileURL: url
        )
        let normalized = NormalizedDocument(
            document: normalization.document,
            metadata: DocumentMetadata(
                institution: .axis,
                documentType: .bankAccount,
                fileFormat: .pdf,
                confidence: 1
            ),
            rows: normalization.rows,
            header: normalization.header,
            sourceContext: normalization.sourceContext
        )
        let financialDocument = try AxisBankAccountPDFParser().parse(
            document: normalized
        )
        let expectedStartDate = try StatementDate.axisNRE(
            expected.statementStartDate
        )
        let expectedEndDate = try StatementDate.axisNRE(
            expected.statementEndDate
        )

        #expect(financialDocument.transactions.count == settledTransactionCount)
        #expect(financialDocument.bookedCurrency?.code == expected.currency)
        #expect(
            financialDocument.declaredStatementPeriod?.start ==
                expectedStartDate
        )
        #expect(
            financialDocument.declaredStatementPeriod?.end ==
                expectedEndDate
        )
        let identifier = try #require(
            financialDocument.financialIdentifiers.first
        )
        #expect(financialDocument.financialIdentifiers.count == 1)
        #expect(
            identifier.normalizedValue ==
                expected.verifiedAccountIdentifier.value
        )
        #expect(identifier.kind == .institutionAccountId)
        #expect(identifier.verificationState == .verified)

        for index in expected.transactions.indices {
            let oracle = expected.transactions[index]
            let transaction = financialDocument.transactions[index]
            let normalizedRow = normalized.rows[index]
            let expectedDebit = try decimal(oracle.debit)
            let expectedCredit = try decimal(oracle.credit)
            let expectedBalance = try decimal(oracle.runningBalance)
            let expectedDate = try StatementDate.axisNRE(
                oracle.transactionDate
            )

            #expect(oracle.ordinal == index + 1)
            #expect(transaction.statementDate == expectedDate)
            #expect(
                transaction.debit ==
                    (expectedDebit == .zero ? nil : expectedDebit)
            )
            #expect(
                transaction.credit ==
                    (expectedCredit == .zero ? nil : expectedCredit)
            )
            #expect(
                transaction.amount ==
                    (expectedDebit == .zero ? expectedCredit : -expectedDebit)
            )
            #expect(transaction.balance == expectedBalance)
            #expect(transaction.description == oracle.description)
            #expect(
                normalizedRow.values[
                    AxisBankAccountPDFColumn.particulars.rawValue
                ] == oracle.description
            )
            #expect(
                normalizedRow.values[
                    AxisBankAccountPDFColumn.chequeReference.rawValue
                ].isEmpty
            )

            let provenance = try #require(
                transaction.sourceProvenance.first
            )
            #expect(transaction.sourceProvenance.count == 1)
            #expect(provenance.sourceOrdinal == normalizedRow.rowNumber)
            #expect(provenance.parserProfileID == "axis.bank-account.pdf")
            #expect(provenance.parserProfileVersion == "1")
            #expect(
                provenance.normalizedRecordDigest ==
                    String.normalizedRecordDigest(values: normalizedRow.values)
            )
            #expect(
                !normalizedRow.values[
                    AxisBankAccountPDFColumn.branchCode.rawValue
                ].isEmpty
            )
        }

        let validation = ImportValidator.validate(
            financialDocument: financialDocument
        )
        let expectedOpeningBalance = try decimal(expected.openingBalance)
        let expectedDebitTotal = try decimal(expected.debitTotal)
        let expectedCreditTotal = try decimal(expected.creditTotal)
        let expectedClosingBalance = try decimal(expected.closingBalance)
        #expect(validation.passed)
        #expect(validation.rowsRead == settledTransactionCount)
        #expect(validation.transactionsParsed == settledTransactionCount)
        #expect(validation.openingBalance == expectedOpeningBalance)
        #expect(validation.debitTotal == expectedDebitTotal)
        #expect(validation.creditTotal == expectedCreditTotal)
        #expect(validation.closingBalance == expectedClosingBalance)
    }

    private func decimal(
        _ source: String
    ) throws -> Decimal {
        try #require(
            Decimal(
                string: source,
                locale: Locale(identifier: "en_US_POSIX")
            )
        )
    }

    private func replacingRow(
        in document: NormalizedDocument,
        at rowIndex: Int,
        column: AxisBankAccountPDFColumn,
        with replacement: String
    ) throws -> NormalizedDocument {
        var rows = document.rows
        let original = rows[rowIndex]
        var values = original.values
        values[column.rawValue] = replacement
        rows[rowIndex] = NormalizedRow(
            rowNumber: original.rowNumber,
            values: values
        )

        return NormalizedDocument(
            document: document.document,
            metadata: document.metadata,
            rows: rows,
            header: document.header,
            sourceContext: document.sourceContext
        )
    }

    private func replacingSourceFragments(
        in document: NormalizedDocument,
        with sourceTexts: [String]
    ) throws -> NormalizedDocument {
        NormalizedDocument(
            document: document.document,
            metadata: document.metadata,
            rows: document.rows,
            header: document.header,
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: sourceTexts.enumerated().map {
                    NormalizedDocument.SourceFragment(
                        sourceOrdinal: $0.offset + 1,
                        text: $0.element
                    )
                }
            )
        )
    }
}

private struct AxisBankAccountPDFExpected: Decodable {
    let transactionCount: Int
    let openingBalance: String
    let closingBalance: String
    let debitTotal: String
    let creditTotal: String
    let transactions: [AxisBankAccountPDFExpectedTransaction]
    let statementStartDate: String
    let statementEndDate: String
    let currency: String
    let verifiedAccountIdentifier: AxisBankAccountPDFExpectedIdentifier

    private enum CodingKeys: String, CodingKey {
        case transactionCount = "transaction_count"
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
        case debitTotal = "debit_total"
        case creditTotal = "credit_total"
        case transactions = "canonical_ordered_transactions"
        case statementStartDate = "statement_start_date"
        case statementEndDate = "statement_end_date"
        case currency
        case verifiedAccountIdentifier = "verified_account_identifier"
    }
}

private struct AxisBankAccountPDFExpectedTransaction: Decodable {
    let ordinal: Int
    let transactionDate: String
    let description: String
    let debit: String
    let credit: String
    let runningBalance: String

    private enum CodingKeys: String, CodingKey {
        case ordinal
        case transactionDate = "transaction_date"
        case description
        case debit
        case credit
        case runningBalance = "running_balance"
    }
}

private struct AxisBankAccountPDFExpectedIdentifier: Decodable {
    let value: String
}
