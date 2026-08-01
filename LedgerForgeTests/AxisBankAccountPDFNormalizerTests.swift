import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisBankAccountPDFNormalizerTests {

    @Test func approvedPDFFixturesNormalizeDeterministically() async throws {
        let fixtures = [
            (
                name: "axis_bank_nro_account_statement_baseline.pdf",
                transactionCount: 16
            ),
            (
                name: "axis_bank_nro_account_statement_extended.pdf",
                transactionCount: 20
            )
        ]

        for fixture in fixtures {
            let source = try await extractedFixture(fixture.name)
            let normalizer = AxisBankAccountPDFNormalizer(
                now: { Date(timeIntervalSince1970: 1_767_225_600) }
            )
            let first = try normalizer.normalize(
                text: source.text,
                fileURL: source.url
            )
            let second = try normalizer.normalize(
                text: source.text,
                fileURL: source.url
            )

            #expect(first.document.fileType == "PDF")
            #expect(first.rows.count == fixture.transactionCount)
            #expect(first.rows.map(\.rowNumber) == second.rows.map(\.rowNumber))
            #expect(first.rows.map(\.values) == second.rows.map(\.values))
            #expect(first.header?.values == second.header?.values)
            #expect(
                first.sourceContext.preTransactionFragments.map(\.text) ==
                    second.sourceContext.preTransactionFragments.map(\.text)
            )
            #expect(
                first.rows.map(\.rowNumber) ==
                    first.rows.map(\.rowNumber).sorted()
            )
            #expect(first.rows.allSatisfy {
                !$0.values[value: .balance].isEmpty &&
                    !$0.values[value: .branchCode].isEmpty
            })
            let title = try #require(
                first.sourceContext.preTransactionFragments.first
            )
            #expect(title.text.hasPrefix("Statement of Axis Account No"))
            #expect(!title.text.contains("TEST R"))
        }
    }

    @Test func exactGrammarGroupsMultilineRowsAndPreservesTerminalEvidence() throws {
        let result = try normalize(validStatement())

        #expect(result.document.fileType == "PDF")
        #expect(result.document.filename == "axis-bank-account.pdf")
        #expect(result.document.headerRow == 4)
        #expect(result.document.firstTransactionRow == 7)
        #expect(result.document.columnCount == AxisBankAccountPDFColumn.allCases.count)
        #expect(result.header?.values == AxisBankAccountPDFColumn.normalizedHeader)
        #expect(result.rows.count == 2)
        #expect(result.rows.map(\.rowNumber) == [7, 8])

        let first = result.rows[0].values
        #expect(first[value: .date] == "01-04-2026")
        #expect(first[value: .chequeReference] == "-")
        #expect(first[value: .particulars] == "UPI/P2M/000000000101/TEST PAYMENT")
        #expect(first[value: .collapsedAmount] == "25.00")
        #expect(first[value: .balance] == "75.00")
        #expect(first[value: .branchCode] == "4437")
        #expect(first[value: .openingBalance] == "100.00")
        #expect(first[value: .printedDebitTotal].isEmpty)

        let second = result.rows[1].values
        #expect(second[value: .particulars] == "UPI/P2A/000000000102/TEST CREDIT")
        #expect(second[value: .collapsedAmount] == "10.00")
        #expect(second[value: .balance] == "85.00")
        #expect(second[value: .printedDebitTotal] == "25.00")
        #expect(second[value: .printedCreditTotal] == "10.00")
        #expect(second[value: .closingBalance] == "85.00")

        let sourceFragment = try #require(
            result.sourceContext.preTransactionFragments.first
        )
        #expect(sourceFragment.sourceOrdinal == 3)
        #expect(sourceFragment.text.contains("Statement of Axis Account No"))
        #expect(sourceFragment.text.contains("From : 01-04-2026"))
        #expect(sourceFragment.text.contains("To : 30-06-2026"))
    }

    @Test func substantivePrintedChequeReferenceIsPreservedExactly() throws {
        let text = validStatement().replacingOccurrences(
            of: "01-04-2026 - UPI/P2M/000000000101/TEST PAYMENT",
            with: "01-04-2026 123456789012 UPI/P2M/000000000101/TEST PAYMENT"
        )

        let result = try normalize(text)
        let first = try #require(result.rows.first?.values)

        #expect(first[value: .chequeReference] == "123456789012")
        #expect(first[value: .particulars] == "UPI/P2M/000000000101/TEST PAYMENT")
    }

    @Test func repeatedNormalizationIsDeterministicForFinancialProjection() throws {
        let normalizer = AxisBankAccountPDFNormalizer(
            now: { Date(timeIntervalSince1970: 1_767_225_600) }
        )
        let first = try normalizer.normalize(
            text: validStatement(),
            fileURL: fixtureURL
        )
        let second = try normalizer.normalize(
            text: validStatement(),
            fileURL: fixtureURL
        )

        #expect(first.document.importedAt == second.document.importedAt)
        #expect(first.document.rowCount == second.document.rowCount)
        #expect(first.header?.values == second.header?.values)
        #expect(first.rows.map(\.rowNumber) == second.rows.map(\.rowNumber))
        #expect(first.rows.map(\.values) == second.rows.map(\.values))
        #expect(
            first.sourceContext.preTransactionFragments.map(\.text) ==
                second.sourceContext.preTransactionFragments.map(\.text)
        )
    }

    @Test func exactRepeatedHeaderIsSuppressedWithoutChangingTransactionOrder() throws {
        let repeatedHeader = """
        Tran Date Chq No Particulars Debit Credit Balance Init.
        Br
        """
        let text = validStatement().replacingOccurrences(
            of: "02-04-2026\n",
            with: repeatedHeader + "\n02-04-2026\n"
        )

        let result = try normalize(text)

        #expect(result.rows.count == 2)
        #expect(result.rows.map(\.rowNumber) == [7, 10])
        #expect(result.rows.map { $0.values[value: .date] } == [
            "01-04-2026", "02-04-2026"
        ])
    }

    @Test func boundedLegendBlockAtPageBoundaryIsIgnored() throws {
        let pageBoundary = """
        Legend:
        UPI = Unified Payments Interface
        Page 1 of 2
        Tran Date Chq No Particulars Debit Credit Balance Init.
        Br
        """
        let text = validStatement().replacingOccurrences(
            of: "02-04-2026\n",
            with: pageBoundary + "\n02-04-2026\n"
        )

        let result = try normalize(text)

        #expect(result.rows.count == 2)
        #expect(
            result.rows[0].values[value: .particulars] ==
                "UPI/P2M/000000000101/TEST PAYMENT"
        )
        #expect(
            result.rows[1].values[value: .particulars] ==
                "UPI/P2A/000000000102/TEST CREDIT"
        )
    }

    @Test func financialContentInsideBoundedLegendBlockFailsClosed() {
        let pageBoundary = """
        Legend:
        2026-03-31 INCOMPLETE FUTURE ROW 1.00 4437
        """
        let text = validStatement().replacingOccurrences(
            of: "02-04-2026\n",
            with: pageBoundary + "\n02-04-2026\n"
        )

        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 9)
        ) {
            try normalize(text)
        }

        let amountOnlyBlock = validStatement().replacingOccurrences(
            of: "02-04-2026\n",
            with: """
            Legend:
            INCOMPLETE FINANCIAL AMOUNT 1.00
            02-04-2026
            """
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 9)
        ) {
            try normalize(amountOnlyBlock)
        }

        let financialLegendOpener = validStatement().replacingOccurrences(
            of: "02-04-2026\n",
            with: """
            Legend: 2026-03-31 INCOMPLETE FUTURE ROW 1.00 4437
            02-04-2026
            """
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 8)
        ) {
            try normalize(financialLegendOpener)
        }
    }

    @Test func changedTableColumnOrderFailsClosed() {
        let changed = validStatement().replacingOccurrences(
            of: "Tran Date Chq No Particulars Debit Credit Balance Init.",
            with: "Tran Date Chq No Particulars Credit Debit Balance Init."
        )

        #expect(
            throws: AxisBankAccountPDFNormalizationError.changedColumnOrder(
                sourceOrdinal: 4
            )
        ) {
            try normalize(changed)
        }
    }

    @Test func repeatedHeaderOutsideTransactionRegionFailsClosed() {
        let text = validStatement() + """

        Tran Date Chq No Particulars Debit Credit Balance Init.
        Br
        """

        #expect(throws: AxisBankAccountPDFNormalizationError.invalidSectionOrder) {
            try normalize(text)
        }
    }

    @Test func missingRequiredTitleAndTerminalsFailClosed() {
        let cases: [
            (
                text: String,
                expected: AxisBankAccountPDFNormalizationError
            )
        ] = [
            (
                validStatement().replacingOccurrences(
                    of: "Statement of Axis Account No",
                    with: "Axis Account Summary No"
                ),
                .missingTitle
            ),
            (
                validStatement().replacingOccurrences(
                    of: " for the period (From : 01-04-2026 To : 30-06-2026)",
                    with: ""
                ),
                .malformedDeclaredPeriod(sourceOrdinal: 3)
            ),
            (
                validStatement().replacingOccurrences(
                    of: "Tran Date Chq No Particulars Debit Credit Balance Init.",
                    with: "Tran Date Chq No Particulars Debit Credit Init."
                ),
                .changedColumnOrder(sourceOrdinal: 4)
            ),
            (
                validStatement().replacingOccurrences(
                    of: "OPENING BALANCE 100.00\n",
                    with: ""
                ),
                .missingOpeningBalance
            ),
            (
                validStatement().replacingOccurrences(
                    of: "TRANSACTION TOTAL 25.00 10.00\n",
                    with: ""
                ),
                .missingTransactionTotal
            ),
            (
                validStatement().replacingOccurrences(
                    of: "CLOSING BALANCE 85.00",
                    with: ""
                ),
                .missingClosingBalance
            )
        ]

        for testCase in cases {
            #expect(throws: testCase.expected) {
                try normalize(testCase.text)
            }
        }
    }

    @Test func malformedDateMissingBalanceAndMissingBranchFailClosed() {
        #expect(
            throws: AxisBankAccountPDFNormalizationError.malformedDate(
                sourceOrdinal: 7
            )
        ) {
            try normalize(
                validStatement().replacingOccurrences(
                    of: "01-04-2026 -",
                    with: "32-04-2026 -"
                )
            )
        }

        #expect(
            throws: AxisBankAccountPDFNormalizationError.missingBalance(
                sourceOrdinal: 7
            )
        ) {
            try normalize(
                validStatement().replacingOccurrences(
                    of: "25.00 75.00 4437",
                    with: "25.00 not-a-balance 4437"
                )
            )
        }

        #expect(
            throws: AxisBankAccountPDFNormalizationError.missingBranch(
                sourceOrdinal: 7
            )
        ) {
            try normalize(
                validStatement().replacingOccurrences(
                    of: "25.00 75.00 4437",
                    with: "25.00 75.00"
                )
            )
        }
    }

    @Test func duplicateTerminalAndFutureFinancialContentFailClosed() {
        let duplicate = validStatement().replacingOccurrences(
            of: "CLOSING BALANCE 85.00",
            with: "TRANSACTION TOTAL 25.00 11.00\nCLOSING BALANCE 85.00"
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError.duplicateTerminalSection
        ) {
            try normalize(duplicate)
        }

        let futureLayout = validStatement() +
            "\n03/04/2026 FUTURE ROW 5.00 90.00 4437"
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 14)
        ) {
            try normalize(futureLayout)
        }

        let incompleteFutureLayout = validStatement() +
            "\n2026-04-03 INCOMPLETE FUTURE ROW 5.00 4437"
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 14)
        ) {
            try normalize(incompleteFutureLayout)
        }

        let incompleteFutureRowInsideTable = validStatement()
            .replacingOccurrences(
                of: "02-04-2026\n",
                with: "2026-04-03 INCOMPLETE FUTURE ROW\n02-04-2026\n"
            )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 8)
        ) {
            try normalize(incompleteFutureRowInsideTable)
        }

        for dateCandidate in ["03-Apr-2026", "3 Apr, 2026"] {
            let textualDateInsideMultilineRow = validStatement()
                .replacingOccurrences(
                    of: "02-04-2026\nUPI/P2A",
                    with: "02-04-2026\n\(dateCandidate) INCOMPLETE FUTURE ROW\nUPI/P2A"
                )
            #expect(
                throws: AxisBankAccountPDFNormalizationError
                    .unconsumedFinancialContent(sourceOrdinal: 9)
            ) {
                try normalize(textualDateInsideMultilineRow)
            }
        }

        for dateCandidate in ["3-4-2026", "3/4/2026,"] {
            let numericDateInsideMultilineRow = validStatement()
                .replacingOccurrences(
                    of: "02-04-2026\nUPI/P2A",
                    with: "02-04-2026\n\(dateCandidate) INCOMPLETE FUTURE ROW\nUPI/P2A"
                )
            #expect(
                throws: AxisBankAccountPDFNormalizationError
                    .unconsumedFinancialContent(sourceOrdinal: 9)
            ) {
                try normalize(numericDateInsideMultilineRow)
            }
        }
    }

    @Test func unconsumedFinancialContentInStructuralGapsAndRowsFailsClosed() {
        let beforeTitle = validStatement().replacingOccurrences(
            of: "Axis Bank\nScheme:",
            with: "Axis Bank\n31/03/2026 FUTURE ROW 1.00 99.00 4437\nScheme:"
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 2)
        ) {
            try normalize(beforeTitle)
        }

        let beforeHeader = validStatement().replacingOccurrences(
            of: "To : 30-06-2026)\nTran Date",
            with: """
            To : 30-06-2026)
            31/03/2026 FUTURE ROW 1.00 99.00 4437
            Tran Date
            """
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 4)
        ) {
            try normalize(beforeHeader)
        }

        let beforeOpening = validStatement().replacingOccurrences(
            of: "Br\nOPENING BALANCE",
            with: "Br\n01/04/2026 FUTURE ROW 5.00 95.00 4437\nOPENING BALANCE"
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 6)
        ) {
            try normalize(beforeOpening)
        }

        let beforeClosing = validStatement().replacingOccurrences(
            of: "TRANSACTION TOTAL 25.00 10.00\nCLOSING BALANCE",
            with: """
            TRANSACTION TOTAL 25.00 10.00
            FUTURE TOTAL 1.00 2.00 4437
            CLOSING BALANCE
            """
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 12)
        ) {
            try normalize(beforeClosing)
        }

        let extraRowAmount = validStatement().replacingOccurrences(
            of: "UPI/P2M/000000000101/TEST PAYMENT 25.00 75.00 4437",
            with: "UPI/P2M/000000000101/TEST 999.00 PAYMENT 25.00 75.00 4437"
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 7)
        ) {
            try normalize(extraRowAmount)
        }

        let amountOnlyBeforeTitle = validStatement().replacingOccurrences(
            of: "Axis Bank\nScheme:",
            with: "Axis Bank\nUNCONSUMED TOTAL 1.00\nScheme:"
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 2)
        ) {
            try normalize(amountOnlyBeforeTitle)
        }

        let amountOnlyBeforeHeader = validStatement().replacingOccurrences(
            of: "To : 30-06-2026)\nTran Date",
            with: "To : 30-06-2026)\nUNCONSUMED TOTAL 1.00\nTran Date"
        )
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 4)
        ) {
            try normalize(amountOnlyBeforeHeader)
        }

        let amountOnlyAfterClosing = validStatement() +
            "\nUNCONSUMED TOTAL 1.00"
        #expect(
            throws: AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: 14)
        ) {
                try normalize(amountOnlyAfterClosing)
            }

        for decoratedAmount in ["₹1.00", "1.00,"] {
            let decoratedAmountAfterClosing = validStatement() +
                "\nUNCONSUMED TOTAL \(decoratedAmount)"
            #expect(
                throws: AxisBankAccountPDFNormalizationError
                    .unconsumedFinancialContent(sourceOrdinal: 14)
            ) {
                try normalize(decoratedAmountAfterClosing)
            }
        }
    }

    @Test func truncatedAndMaskedAccountIdentifiersFailClosed() {
        let unsupportedIdentifiers = ["1", "XXXXX1234"]

        for identifier in unsupportedIdentifiers {
            let text = validStatement().replacingOccurrences(
                of: "Statement of Axis Account No : 123456789012345",
                with: "Statement of Axis Account No : \(identifier)"
            )
            #expect(
                throws: AxisBankAccountPDFNormalizationError
                    .malformedAccountIdentifier(sourceOrdinal: 3)
            ) {
                try normalize(text)
            }
        }
    }

    @Test func unsupportedSimilarDocumentsDoNotNormalize() {
        let unsupportedDocuments = [
            validStatement().replacingOccurrences(
                of: "Statement of Axis Account No",
                with: "Axis Bank Account Summary No"
            ),
            validStatement().replacingOccurrences(
                of: "Statement of Axis Account No : 123456789012345",
                with: "Axis Bank Credit Card Statement : 123456789012345"
            ),
            validStatement().replacingOccurrences(
                of: "Statement of Axis Account No",
                with: "Statement of Other Bank Account No"
            ),
            validStatement().replacingOccurrences(
                of: "Statement of Axis Account No",
                with: "31-03-2026 FUTURE ROW 1.00 99.00 4437 Statement of Axis Account No"
            )
        ]

        for sourceText in unsupportedDocuments {
            if sourceText.contains("FUTURE ROW") {
                #expect(
                    throws: AxisBankAccountPDFNormalizationError
                        .unconsumedFinancialContent(sourceOrdinal: 3)
                ) {
                    try normalize(sourceText)
                }
            } else {
                #expect(throws: AxisBankAccountPDFNormalizationError.missingTitle) {
                    try normalize(sourceText)
                }
            }
        }
    }

    private var fixtureURL: URL {
        URL(fileURLWithPath: "/tmp/axis-bank-account.pdf")
    }

    private func normalize(
        _ text: String
    ) throws -> AxisBankAccountPDFNormalizationResult {
        try AxisBankAccountPDFNormalizer(
            now: { Date(timeIntervalSince1970: 1_767_225_600) }
        ).normalize(
            text: text,
            fileURL: fixtureURL
        )
    }

    private func extractedFixture(
        _ name: String
    ) async throws -> (url: URL, text: String) {
        let url = FixtureLocator.axisPDF(name)
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
            return (url, "")
        }
        return (url, text)
    }

    private func validStatement(
        scheme: String = "NRO"
    ) -> String {
        """
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
        Legend: this non-financial footer is ignored.
        """
    }
}

private extension Array where Element == String {
    subscript(value column: AxisBankAccountPDFColumn) -> String {
        self[column.rawValue]
    }
}
