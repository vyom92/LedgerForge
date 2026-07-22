import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisBankCSVColumnMappingTests {

    @Test func canonicalSwappedAndPermutedColumnsProduceIdenticalFinancialTruth() throws {
        let canonical = try parse(
            header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
            rows: [
                ["01-01-2026", "-", "UPI/P2M/000000000101/TEST MERCHANT", "25.00", "", "75.00", "4437"],
                ["02-01-2026", "-", "UPI/P2A/000000000102/TEST CREDIT ADJUSTMENT", "", "10.00", "85.00", "4437"]
            ]
        )
        let swapped = try parse(
            header: ["Tran Date", "CHQNO", "PARTICULARS", "CR", "DR", "BAL", "SOL"],
            rows: [
                ["01-01-2026", "-", "UPI/P2M/000000000101/TEST MERCHANT", "", "25.00", "75.00", "4437"],
                ["02-01-2026", "-", "UPI/P2A/000000000102/TEST CREDIT ADJUSTMENT", "10.00", "", "85.00", "4437"]
            ]
        )
        let permuted = try parse(
            header: ["SOL", "Credit", "PARTICULARS", "Transaction Date", "Balance", "Debit", "CHQNO"],
            rows: [
                ["4437", "", "UPI/P2M/000000000101/TEST MERCHANT", "01-01-2026", "75.00", "25.00", "-"],
                ["4437", "10.00", "UPI/P2A/000000000102/TEST CREDIT ADJUSTMENT", "02-01-2026", "85.00", "", "-"]
            ]
        )

        #expect(projection(canonical) == projection(swapped))
        #expect(projection(canonical) == projection(permuted))
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
        #expect(mapping.debit == 3)
        #expect(mapping.credit == 4)
        #expect(mapping.balance == 5)
        #expect(mapping.sol == 6)
    }

    @Test func missingDebitHeaderFailsClosed() {
        #expect(throws: AxisBankCSVColumnMappingError.missingRole(.debit)) {
            try AxisBankCSVColumnMapping.resolve(
                headerCells: ["Tran Date", "CHQNO", "PARTICULARS", "CR", "BAL", "SOL"]
            )
        }
    }

    @Test func missingCreditHeaderFailsClosed() {
        #expect(throws: AxisBankCSVColumnMappingError.missingRole(.credit)) {
            try AxisBankCSVColumnMapping.resolve(
                headerCells: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "BAL", "SOL"]
            )
        }
    }

    @Test func duplicateDebitRolesFailClosed() {
        #expect(throws: AxisBankCSVColumnMappingError.duplicateRole(.debit)) {
            try AxisBankCSVColumnMapping.resolve(
                headerCells: [
                    "Tran Date", "CHQNO", "PARTICULARS", "DR", "Debit", "CR", "BAL", "SOL"
                ]
            )
        }
    }

    @Test func duplicateCreditRolesFailClosed() {
        #expect(throws: AxisBankCSVColumnMappingError.duplicateRole(.credit)) {
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

    @Test func semanticDebitProducesPostingAndSemanticCreditProducesCreditAdjustment() throws {
        let document = try parse(
            header: ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"],
            rows: [
                ["01-01-2026", "-", "UPI/P2M/000000000101/TEST MERCHANT", "25.00", "", "75.00", "4437"],
                ["02-01-2026", "-", "UPI/P2A/000000000102/TEST CREDIT ADJUSTMENT", "", "10.00", "85.00", "4437"]
            ]
        )

        #expect(document.transactions[0].verifiedAxisUPIEventEvidence?.subtype == .posting)
        #expect(document.transactions[1].verifiedAxisUPIEventEvidence?.subtype == .creditAdjustment)
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
            header: NormalizedRow(rowNumber: 1, values: header)
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
