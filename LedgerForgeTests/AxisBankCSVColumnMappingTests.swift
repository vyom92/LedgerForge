import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisBankCSVColumnMappingTests {

    @Test func canonicalSwappedAndPermutedColumnsProduceIdenticalFinancialTruth() throws {
        let canonical = try parse(
            header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
            rows: [
                ["01-01-2026", "-", "UPI/P2A/000000000101/TEST CREDIT", "25.00", "", "125.00", "4437"],
                ["02-01-2026", "-", "UPI/P2M/000000000102/TEST PAYMENT", "", "10.00", "115.00", "4437"]
            ]
        )
        let swapped = try parse(
            header: ["Tran Date", "CHQNO", "PARTICULARS", "CR", "DR", "BAL", "SOL"],
            rows: [
                ["01-01-2026", "-", "UPI/P2A/000000000101/TEST CREDIT", "", "25.00", "125.00", "4437"],
                ["02-01-2026", "-", "UPI/P2M/000000000102/TEST PAYMENT", "10.00", "", "115.00", "4437"]
            ]
        )
        let permuted = try parse(
            header: ["SOL", "Credit", "PARTICULARS", "Transaction Date", "Balance", "Debit", "CHQNO"],
            rows: [
                ["4437", "", "UPI/P2A/000000000101/TEST CREDIT", "01-01-2026", "125.00", "25.00", "-"],
                ["4437", "10.00", "UPI/P2M/000000000102/TEST PAYMENT", "02-01-2026", "115.00", "", "-"]
            ]
        )

        #expect(projection(canonical) == projection(swapped))
        #expect(projection(canonical) == projection(permuted))
        #expect(canonical.transactions[0].credit == Decimal(25))
        #expect(canonical.transactions[0].money.amount == Decimal(25))
        #expect(canonical.transactions[1].debit == Decimal(10))
        #expect(canonical.transactions[1].money.amount == Decimal(-10))
    }

    @Test func closedAliasesNormalizeCaseAndWhitespace() throws {
        let mapping = try AxisBankCSVColumnMapping.resolve(
            headerCells: [
                "  tran   DATE  ", " chqno ", " Particulars ",
                " debit ", " CREDIT ", " balance ", " sol "
            ]
        )

        #expect(mapping.date == 0)
        #expect(mapping.chequeReference == 1)
        #expect(mapping.description == 2)
        #expect(mapping.sourceDR == 3)
        #expect(mapping.sourceCR == 4)
        #expect(mapping.balance == 5)
        #expect(mapping.sol == 6)
    }

    @Test func missingDebitHeaderFailsClosed() {
        #expect(throws: AxisBankCSVColumnMappingError.missingRole(.sourceDR)) {
            try AxisBankCSVColumnMapping.resolve(
                headerCells: ["Tran Date", "CHQNO", "PARTICULARS", "CR", "BAL", "SOL"]
            )
        }
    }

    @Test func missingCreditHeaderFailsClosed() {
        #expect(throws: AxisBankCSVColumnMappingError.missingRole(.sourceCR)) {
            try AxisBankCSVColumnMapping.resolve(
                headerCells: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "BAL", "SOL"]
            )
        }
    }

    @Test func duplicateDebitRolesFailClosed() {
        #expect(throws: AxisBankCSVColumnMappingError.duplicateRole(.sourceDR)) {
            try AxisBankCSVColumnMapping.resolve(
                headerCells: [
                    "Tran Date", "CHQNO", "PARTICULARS", "DR", "Debit", "CR", "BAL", "SOL"
                ]
            )
        }
    }

    @Test func duplicateCreditRolesFailClosed() {
        #expect(throws: AxisBankCSVColumnMappingError.duplicateRole(.sourceCR)) {
            try AxisBankCSVColumnMapping.resolve(
                headerCells: [
                    "Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "Credit", "BAL", "SOL"
                ]
            )
        }
    }

    @Test func combinedDirectionAliasFailsAsAmbiguous() {
        #expect(throws: AxisBankCSVColumnMappingError.ambiguousHeader(index: 3)) {
            try AxisBankCSVColumnMapping.resolve(
                headerCells: ["Tran Date", "CHQNO", "PARTICULARS", "DR/CR", "BAL", "SOL"]
            )
        }
    }

    @Test func unknownLayoutFailsClosed() {
        #expect(throws: AxisBankCSVColumnMappingError.unsupportedHeader(index: 3)) {
            try AxisBankCSVColumnMapping.resolve(
                headerCells: ["Tran Date", "CHQNO", "PARTICULARS", "Amount", "BAL", "SOL"]
            )
        }
    }

    @Test func sourceDRProducesCanonicalCreditAndSourceCRProducesCanonicalDebit() throws {
        let document = try parse(
            header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
            rows: [
                ["01-01-2026", "-", "UPI/P2A/000000000101/TEST CREDIT", "25.00", "", "125.00", "4437"],
                ["02-01-2026", "-", "UPI/P2M/000000000102/TEST PAYMENT", "", "10.00", "115.00", "4437"]
            ]
        )

        #expect(document.transactions[0].debit == nil)
        #expect(document.transactions[0].credit == Decimal(25))
        #expect(document.transactions[0].money.amount == Decimal(25))
        #expect(document.transactions[0].verifiedAxisUPIEventEvidence?.subtype == .creditAdjustment)
        #expect(document.transactions[1].debit == Decimal(10))
        #expect(document.transactions[1].credit == nil)
        #expect(document.transactions[1].money.amount == Decimal(-10))
        #expect(document.transactions[1].verifiedAxisUPIEventEvidence?.subtype == .posting)
        let validation = ImportValidator.validate(financialDocument: document)
        #expect(validation.passed)
        #expect(validation.debitTotal == Decimal(10))
        #expect(validation.creditTotal == Decimal(25))
        #expect(validation.openingBalance == Decimal(100))
        #expect(validation.closingBalance == Decimal(115))
    }

    @Test func futureConventionalSemanticsFailValidationWithoutAutomaticSwitching() throws {
        let document = try parse(
            header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
            rows: [
                ["01-01-2026", "-", "UPI/P2M/000000000101/FUTURE PAYMENT", "25.00", "", "75.00", "4437"],
                ["02-01-2026", "-", "UPI/P2A/000000000102/FUTURE CREDIT", "", "10.00", "85.00", "4437"]
            ]
        )

        #expect(document.transactions[0].credit == Decimal(25))
        #expect(document.transactions[1].debit == Decimal(10))
        #expect(!ImportValidator.validate(financialDocument: document).passed)
    }

    @Test func mixedSourceSemanticsFailValidation() throws {
        let document = try parse(
            header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
            rows: [
                ["01-01-2026", "-", "UPI/P2A/000000000101/V1 CREDIT", "25.00", "", "125.00", "4437"],
                ["02-01-2026", "-", "UPI/P2M/000000000102/V1 PAYMENT", "", "10.00", "115.00", "4437"],
                ["03-01-2026", "-", "UPI/P2M/000000000103/FUTURE PAYMENT", "5.00", "", "110.00", "4437"]
            ]
        )

        #expect(!ImportValidator.validate(financialDocument: document).passed)
    }

    @Test func malformedSourceDecimalFailsClosed() {
        #expect(
            throws: AxisBankAccountParserError.invalidMonetaryValue(
                role: .sourceDR,
                rowNumber: 2
            )
        ) {
            try parse(
                header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
                rows: [["01-01-2026", "-", "UPI/P2A/000000000101/TEST", "not-money", "", "100.00", "4437"]]
            )
        }
    }

    @Test func excessINRPrecisionFailsClosed() {
        #expect(throws: MoneyError.excessPrecision(currency: "INR")) {
            try parse(
                header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
                rows: [["01-01-2026", "-", "UPI/P2A/000000000101/TEST", "1.001", "", "101.001", "4437"]]
            )
        }
    }

    @Test func populatedDebitAndCreditFailsBeforeEventEvidenceCanBeProduced() {
        #expect(throws: AxisBankAccountParserError.ambiguousDirection(rowNumber: 2)) {
            try parse(
                header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
                rows: [["01-01-2026", "-", "UPI/P2M/000000000101/TEST", "25.00", "10.00", "85.00", "4437"]]
            )
        }
    }

    @Test func emptyDebitAndCreditFailsBeforeEventEvidenceCanBeProduced() {
        #expect(throws: AxisBankAccountParserError.missingDirection(rowNumber: 2)) {
            try parse(
                header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
                rows: [["01-01-2026", "-", "UPI/P2M/000000000101/TEST", "", "", "100.00", "4437"]]
            )
        }
    }

    private func parse(
        header: [String],
        rows: [[String]]
    ) throws -> FinancialDocument {
        let sourceDocument = Document(
            filename: "axis-header-semantic-test.csv",
            url: URL(fileURLWithPath: "/tmp/axis-header-semantic-test.csv"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 0)
        )
        let normalizedDocument = NormalizedDocument(
            document: sourceDocument,
            metadata: DocumentMetadata(
                institution: .axis,
                documentType: .bankAccount,
                fileFormat: .csv,
                confidence: 1
            ),
            rows: rows.enumerated().map { index, values in
                NormalizedRow(rowNumber: index + 2, values: values)
            },
            header: NormalizedRow(rowNumber: 1, values: header),
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: [
                    NormalizedDocument.SourceFragment(
                        sourceOrdinal: 1,
                        text: "Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)"
                    )
                ]
            )
        )

        return try AxisBankAccountParser().parse(document: normalizedDocument)
    }

    private func projection(
        _ document: FinancialDocument
    ) -> [AxisTransactionProjection] {
        document.transactions.map {
            AxisTransactionProjection(
                statementDate: $0.statementDate,
                description: $0.description,
                debit: $0.debit,
                credit: $0.credit,
                balance: $0.balance,
                eventEvidence: $0.verifiedAxisUPIEventEvidence
            )
        }
    }
}

private struct AxisTransactionProjection: Equatable {
    let statementDate: StatementDate?
    let description: String
    let debit: Decimal?
    let credit: Decimal?
    let balance: Decimal?
    let eventEvidence: AxisUPITransactionEventEvidence?
}
