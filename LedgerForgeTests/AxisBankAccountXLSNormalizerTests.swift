import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisBankAccountXLSNormalizerTests {
    @Test func committedFixturesPreserveExactHeaderLogicalBlanksAndPhysicalOrdinals() async throws {
        for (name, count, rowCount) in [
            ("axis_bank_nro_account_statement_baseline.xls", 16, 62),
            ("axis_bank_nro_account_statement_extended.xls", 20, 66)
        ] {
            let raw = try await XLSFixtureTestSupport.read(name)
            let normalized = try AxisBankAccountXLSNormalizer().normalize(rawDocument: raw)
            #expect(normalized.header.values == AxisBankAccountXLSNormalizer.logicalHeader)
            #expect(normalized.header.rowNumber == 17)
            #expect(normalized.rows.count == count)
            #expect(normalized.rows.first?.rowNumber == 18)
            #expect(normalized.rows.last?.rowNumber == 17 + count)
            #expect(normalized.rows.allSatisfy { $0.values.count == 7 })
            #expect(normalized.rows[0].values[3].isEmpty)
            #expect(normalized.rows[0].values[4] == "4221")
            #expect(normalized.document.rowCount == rowCount)
            #expect(normalized.document.columnCount == 8)
            #expect(normalized.sourceContext.preTransactionFragments.contains {
                $0.sourceOrdinal == 15 && $0.text.contains("921234567890123")
            })
        }
    }

    @Test func baselineAndExtendedXLSRetainSixteenSharedRowsAndFourExtendedOnlyRows() async throws {
        let baseline = try AxisBankAccountXLSNormalizer().normalize(
            rawDocument: try await XLSFixtureTestSupport.read(
                "axis_bank_nro_account_statement_baseline.xls"
            )
        )
        let extended = try AxisBankAccountXLSNormalizer().normalize(
            rawDocument: try await XLSFixtureTestSupport.read(
                "axis_bank_nro_account_statement_extended.xls"
            )
        )
        let baselineProjection = baseline.rows.map(Self.financialProjection)
        let extendedProjection = extended.rows.map(Self.financialProjection)
        #expect(Array(extendedProjection.prefix(16)) == baselineProjection)
        #expect(extendedProjection.count - baselineProjection.count == 4)
    }

    @Test func normalizerRejectsMissingDuplicateReorderedAndNearMatchHeaders() throws {
        let cases: [(RawDocument, AxisBankAccountXLSNormalizationError)] = [
            (XLSFixtureTestSupport.syntheticRaw(header: nil), .missingHeader),
            (XLSFixtureTestSupport.syntheticRaw(duplicateHeader: true), .duplicateHeader),
            (XLSFixtureTestSupport.syntheticRaw(header: ["SRL NO", "CHQNO", "Tran Date", "PARTICULARS", "DR", "CR", "BAL", "SOL"]), .changedHeader(sourceOrdinal: 3)),
            (XLSFixtureTestSupport.syntheticRaw(header: ["SRL NO", "Tran Date", "CHQNO", "PARTICULARS", "DEBIT", "CREDIT", "BAL", "SOL"]), .changedHeader(sourceOrdinal: 3))
        ]
        for (raw, expected) in cases {
            #expect(throws: expected) {
                try AxisBankAccountXLSNormalizer().normalize(rawDocument: raw)
            }
        }
    }

    @Test func normalizerRejectsUnsupportedTrailingFinancialShape() throws {
        let raw = XLSFixtureTestSupport.syntheticRaw(
            trailingRows: [["footer", "unexpected"]]
        )
        #expect(throws: AxisBankAccountXLSNormalizationError.unsupportedTrailingRow(sourceOrdinal: 6)) {
            try AxisBankAccountXLSNormalizer().normalize(rawDocument: raw)
        }
    }

    private static func financialProjection(_ row: NormalizedRow) -> [String] {
        [row.values[0], row.values[3], row.values[4], row.values[5], row.values[6]]
    }
}
