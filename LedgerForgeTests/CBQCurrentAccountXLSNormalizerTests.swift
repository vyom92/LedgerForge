import Testing
@testable import LedgerForge

@MainActor
struct CBQCurrentAccountXLSNormalizerTests {
    @Test func exactSyntheticGrammarNormalizesInPhysicalSourceOrder() async throws {
        let raw = try await CBQXLSFixtureTestSupport.read()
        let result = try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: raw)

        #expect(result.header.rowNumber == 7)
        #expect(result.header.values == CBQCurrentAccountXLSNormalizer.logicalHeader)
        #expect(result.rows.map(\.rowNumber) == [8, 9, 10, 11])
        #expect(result.rows.allSatisfy { $0.values.count == 7 })
        #expect(result.rows.allSatisfy { $0.values[3...5].allSatisfy(\.isEmpty) })
        #expect(result.rows.map { $0.values[0] } == [
            "17/08/2026", "17/08/2026", "16/08/2026", "15/08/2026"
        ])
        #expect(result.sourceContext.preTransactionFragments.map(\.sourceOrdinal) == [2, 4, 5])
        #expect(result.sourceContext.postTransactionFragments.isEmpty)
    }

    @Test func wrongOrHiddenSheetAndWrongColumnsFailClosed() async throws {
        let raw = try await CBQXLSFixtureTestSupport.read()
        let wrong = CBQXLSFixtureTestSupport.replacingSheet(in: raw, name: "Other")
        #expect(throws: CBQCurrentAccountXLSNormalizationError.unsupportedWorksheet) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: wrong)
        }
        let hidden = CBQXLSFixtureTestSupport.replacingSheet(in: raw, visibility: .hidden)
        #expect(throws: CBQCurrentAccountXLSNormalizationError.unsupportedWorksheet) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: hidden)
        }
        let columns = CBQXLSFixtureTestSupport.replacingSheet(in: raw, columnCount: 8)
        #expect(throws: CBQCurrentAccountXLSNormalizationError.unexpectedColumnCount(8)) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: columns)
        }
    }

    @Test func missingDuplicateAndChangedHeadersFailClosed() async throws {
        let raw = try await CBQXLSFixtureTestSupport.read()
        let missing = CBQXLSFixtureTestSupport.replacingRow(in: raw, sourceRow: 7, with: [])
        #expect(throws: CBQCurrentAccountXLSNormalizationError.missingHeader) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: missing)
        }
        let duplicate = CBQXLSFixtureTestSupport.replacingRow(
            in: raw,
            sourceRow: 6,
            with: CBQCurrentAccountXLSNormalizer.logicalHeader
        )
        #expect(throws: CBQCurrentAccountXLSNormalizationError.duplicateHeader) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: duplicate)
        }
        var changedHeader = CBQCurrentAccountXLSNormalizer.logicalHeader
        changedHeader[1] = "Description"
        let changed = CBQXLSFixtureTestSupport.replacingRow(
            in: raw,
            sourceRow: 7,
            with: changedHeader
        )
        #expect(
            throws: CBQCurrentAccountXLSNormalizationError.changedHeader(sourceOrdinal: 7)
        ) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: changed)
        }
    }

    @Test func preambleTransactionFieldsAndTrailingContentFailClosed() async throws {
        let raw = try await CBQXLSFixtureTestSupport.read()
        let preamble = CBQXLSFixtureTestSupport.replacingCell(
            in: raw, sourceRow: 2, sourceColumn: 1, with: "Account History"
        )
        #expect(
            throws: CBQCurrentAccountXLSNormalizationError.malformedPreamble(sourceOrdinal: 2)
        ) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: preamble)
        }
        let transaction = CBQXLSFixtureTestSupport.replacingCell(
            in: raw, sourceRow: 8, sourceColumn: 2, with: ""
        )
        #expect(
            throws: CBQCurrentAccountXLSNormalizationError.malformedTransaction(sourceOrdinal: 8)
        ) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: transaction)
        }
        let date = CBQXLSFixtureTestSupport.replacingCell(
            in: raw, sourceRow: 8, sourceColumn: 1, with: "2026-08-17"
        )
        #expect(throws: CBQCurrentAccountXLSNormalizationError.malformedDate(sourceOrdinal: 8)) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: date)
        }
        let amount = CBQXLSFixtureTestSupport.replacingCell(
            in: raw, sourceRow: 8, sourceColumn: 3, with: "QAR 10"
        )
        #expect(throws: CBQCurrentAccountXLSNormalizationError.malformedAmount(sourceOrdinal: 8)) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: amount)
        }
        let missingBalance = CBQXLSFixtureTestSupport.replacingCell(
            in: raw, sourceRow: 8, sourceColumn: 7, with: ""
        )
        #expect(throws: CBQCurrentAccountXLSNormalizationError.missingBalance(sourceOrdinal: 8)) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: missingBalance)
        }
        let malformedBalance = CBQXLSFixtureTestSupport.replacingCell(
            in: raw, sourceRow: 8, sourceColumn: 7, with: "unknown"
        )
        #expect(throws: CBQCurrentAccountXLSNormalizationError.malformedBalance(sourceOrdinal: 8)) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: malformedBalance)
        }
        let trailing = CBQXLSFixtureTestSupport.appendingRow(in: raw, values: ["Footer"])
        #expect(
            throws: CBQCurrentAccountXLSNormalizationError.unsupportedTrailingRow(sourceOrdinal: 12)
        ) {
            try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: trailing)
        }
    }
}
