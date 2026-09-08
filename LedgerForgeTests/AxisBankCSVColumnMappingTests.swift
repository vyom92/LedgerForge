import Testing
@testable import LedgerForge

@MainActor
struct AxisBankCSVColumnMappingTests {

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
}
