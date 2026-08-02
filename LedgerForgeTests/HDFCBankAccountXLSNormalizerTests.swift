import Testing
@testable import LedgerForge

@MainActor
struct HDFCBankAccountXLSNormalizerTests {
    @Test func retainedSyntheticGrammarNormalizesBothAccountSourcesInPhysicalOrder() async throws {
        for fixture in [
            HDFCXLSFixtureTestSupport.annualFixture,
            HDFCXLSFixtureTestSupport.recentFixture
        ] {
            let raw = try await HDFCXLSFixtureTestSupport.read(fixture)
            let result = try HDFCBankAccountXLSNormalizer().normalize(rawDocument: raw)

            #expect(result.header.rowNumber == 21)
            #expect(result.header.values == HDFCBankAccountXLSNormalizer.logicalHeader)
            #expect(result.rows.map(\.rowNumber) == [23, 24, 25, 26])
            #expect(result.rows.allSatisfy { $0.values.count == 7 })
            #expect(result.rows.contains { $0.values[4].isEmpty })
            #expect(result.rows.contains { $0.values[5].isEmpty })
            #expect(result.rows.allSatisfy {
                $0.values[1] == $0.values[1]
                    .split(whereSeparator: { $0.isWhitespace })
                    .joined(separator: " ")
            })
            #expect(result.sourceContext.preTransactionFragments.contains {
                $0.sourceOrdinal == 15
            })
            #expect(result.sourceContext.postTransactionFragments.contains {
                $0.text.contains("STATEMENT SUMMARY  :-")
            })
        }
    }

    @Test func missingDuplicateReorderedAndNearMatchHeadersFailClosed() async throws {
        let raw = try await HDFCXLSFixtureTestSupport.read()
        let missing = HDFCXLSFixtureTestSupport.replacingRow(
            in: raw,
            sourceRow: 21,
            with: []
        )
        #expect(throws: HDFCBankAccountXLSNormalizationError.missingHeader) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: missing)
        }

        let duplicate = HDFCXLSFixtureTestSupport.replacingRow(
            in: raw,
            sourceRow: 22,
            with: HDFCBankAccountXLSNormalizer.logicalHeader
        )
        #expect(throws: HDFCBankAccountXLSNormalizationError.duplicateHeader) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: duplicate)
        }

        var reorderedHeader = HDFCBankAccountXLSNormalizer.logicalHeader
        reorderedHeader.swapAt(0, 3)
        let reordered = HDFCXLSFixtureTestSupport.replacingRow(
            in: raw,
            sourceRow: 21,
            with: reorderedHeader
        )
        #expect(
            throws: HDFCBankAccountXLSNormalizationError.changedHeader(sourceOrdinal: 21)
        ) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: reordered)
        }

        var nearHeader = HDFCBankAccountXLSNormalizer.logicalHeader
        nearHeader[2] = "Reference"
        let nearMatch = HDFCXLSFixtureTestSupport.replacingRow(
            in: raw,
            sourceRow: 21,
            with: nearHeader
        )
        #expect(
            throws: HDFCBankAccountXLSNormalizationError.changedHeader(sourceOrdinal: 21)
        ) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: nearMatch)
        }
    }

    @Test func unsupportedSheetColumnsPreambleTransactionAndSummaryFailClosed() async throws {
        let raw = try await HDFCXLSFixtureTestSupport.read()
        let wrongSheet = HDFCXLSFixtureTestSupport.replacingSheet(
            in: raw,
            name: "Other"
        )
        #expect(throws: HDFCBankAccountXLSNormalizationError.unsupportedWorksheet) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: wrongSheet)
        }

        let hiddenSheet = HDFCXLSFixtureTestSupport.replacingSheet(
            in: raw,
            visibility: .hidden
        )
        #expect(throws: HDFCBankAccountXLSNormalizationError.unsupportedWorksheet) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: hiddenSheet)
        }

        let extraColumn = HDFCXLSFixtureTestSupport.replacingSheet(
            in: raw,
            columnCount: 8
        )
        #expect(throws: HDFCBankAccountXLSNormalizationError.unexpectedColumnCount(8)) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: extraColumn)
        }

        let malformedPreamble = HDFCXLSFixtureTestSupport.replacingCell(
            in: raw,
            sourceRow: 1,
            sourceColumn: 1,
            with: "Other Bank"
        )
        #expect(
            throws: HDFCBankAccountXLSNormalizationError.malformedPreamble(sourceOrdinal: 1)
        ) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: malformedPreamble)
        }

        let malformedTransaction = HDFCXLSFixtureTestSupport.replacingCell(
            in: raw,
            sourceRow: 23,
            sourceColumn: 4,
            with: ""
        )
        #expect(
            throws: HDFCBankAccountXLSNormalizationError.malformedTransaction(sourceOrdinal: 23)
        ) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: malformedTransaction)
        }

        let malformedSummary = HDFCXLSFixtureTestSupport.replacingCell(
            in: raw,
            sourceRow: 31,
            sourceColumn: 1,
            with: "Summary"
        )
        #expect(
            throws: HDFCBankAccountXLSNormalizationError.malformedSummary(sourceOrdinal: 31)
        ) {
            try HDFCBankAccountXLSNormalizer().normalize(rawDocument: malformedSummary)
        }
    }
}
