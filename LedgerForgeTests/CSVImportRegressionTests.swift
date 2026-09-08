// LedgerForgeTests/CSVImportRegressionTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct CSVImportRegressionTests {

    @Test func sourceContextPreservesExactPreTransactionFragmentsAndBoundary() {
        let text = "  Record Label,001  \n\nLabel,Category,Left,Right,Value\nAlpha,First,100,,900\nBeta,Second,,25,925"
        let document = Self.makeDocument(
            headerRow: 3,
            firstTransactionRow: 4,
            delimiter: ","
        )

        let result = CSVNormalizer().normalizeWithSourceContext(
            text: text,
            document: document
        )

        let fragments = result.sourceContext.preTransactionFragments

        #expect(fragments.count == 3)
        #expect(fragments.map { $0.sourceOrdinal } == [1, 2, 3])
        #expect(fragments.map { $0.text } == [
            "  Record Label,001  ",
            "",
            "Label,Category,Left,Right,Value"
        ])
        #expect(!fragments.map { $0.text }.contains("Alpha,First,100,,900"))
        #expect(!fragments.map { $0.text }.contains("Beta,Second,,25,925"))
        #expect(result.header?.rowNumber == 3)
        #expect(result.header?.values == [
            "Label", "Category", "Left", "Right", "Value"
        ])
    }

    @Test func invalidOrMissingNormalizationPrerequisitesReturnEmptyRowsAndContext() {
        let text = "Header,Value\nAlpha,1"
        let documents = [
            Self.makeDocument(firstTransactionRow: 2, delimiter: nil),
            Self.makeDocument(firstTransactionRow: nil, delimiter: ","),
            Self.makeDocument(firstTransactionRow: 0, delimiter: ","),
            Self.makeDocument(firstTransactionRow: 4, delimiter: ",")
        ]

        for document in documents {
            let result = CSVNormalizer().normalizeWithSourceContext(
                text: text,
                document: document
            )
            let compatibilityRows = CSVNormalizer().normalize(
                text: text,
                document: document
            )

            #expect(result.rows.isEmpty)
            #expect(result.sourceContext.preTransactionFragments.isEmpty)
            #expect(result.header == nil)
            #expect(compatibilityRows.isEmpty)
        }
    }

    @Test func startImmediatelyAfterEOFPreservesNonfinancialHeaderAndContext() {
        let text = "Name,Category"
        let document = Self.makeDocument(headerRow: 1, firstTransactionRow: 2, delimiter: ",")
        let normalizer = CSVNormalizer()
        let result = normalizer.normalizeWithSourceContext(text: text, document: document)

        #expect(result.rows.isEmpty)
        #expect(result.header?.rowNumber == 1)
        #expect(result.header?.values == ["Name", "Category"])
        #expect(result.sourceContext.preTransactionFragments.map(\.sourceOrdinal) == [1])
        #expect(result.sourceContext.preTransactionFragments.map(\.text) == [text])
        #expect(normalizer.normalize(text: text, document: document).isEmpty)
    }

    @Test func rowOnlyNormalizationMatchesCompositeNormalizationRows() {
        let text = "Header,Value\nAlpha, Description ,, 10 \n\n"
        let document = Self.makeDocument(
            headerRow: 1,
            firstTransactionRow: 2,
            delimiter: ","
        )
        let normalizer = CSVNormalizer()

        let result = normalizer.normalizeWithSourceContext(
            text: text,
            document: document
        )
        let compatibilityRows = normalizer.normalize(
            text: text,
            document: document
        )

        #expect(compatibilityRows.map { $0.rowNumber } == result.rows.map { $0.rowNumber })
        #expect(compatibilityRows.map { $0.values } == result.rows.map { $0.values })
        #expect(result.rows.map { $0.rowNumber } == [2])
        #expect(result.rows.map { $0.values } == [["Alpha", "Description", "", "10"]])
        #expect(result.header?.values == ["Header", "Value"])
    }

    @Test func normalizedDocumentDefaultsAndRetainsSourceContext() {
        let document = Self.makeDocument(firstTransactionRow: 2, delimiter: ",")
        let metadata = DocumentMetadata(
            institution: .unknown,
            documentType: .unknown,
            fileFormat: .csv,
            confidence: 0
        )
        let defaultDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: []
        )
        let sourceContext = NormalizedDocument.SourceContext(
            preTransactionFragments: [
                NormalizedDocument.SourceFragment(
                    sourceOrdinal: 1,
                    text: "  exact source  "
                ),
                NormalizedDocument.SourceFragment(
                    sourceOrdinal: 2,
                    text: ""
                )
            ]
        )
        let explicitDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: [],
            header: NormalizedRow(
                rowNumber: 1,
                values: ["Header", "Value"]
            ),
            sourceContext: sourceContext
        )

        #expect(defaultDocument.header == nil)
        #expect(defaultDocument.sourceContext.preTransactionFragments.isEmpty)
        #expect(explicitDocument.header?.values == ["Header", "Value"])
        #expect(explicitDocument.sourceContext.preTransactionFragments.map { $0.sourceOrdinal } == [1, 2])
        #expect(explicitDocument.sourceContext.preTransactionFragments.map { $0.text } == [
            "  exact source  ",
            ""
        ])
    }

    private static func makeDocument(
        headerRow: Int? = nil,
        firstTransactionRow: Int?,
        delimiter: Character?
    ) -> Document {
        var document = Document(
            filename: "sprint-34.csv",
            url: URL(fileURLWithPath: "/tmp/sprint-34.csv"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 0)
        )
        document.headerRow = headerRow
        document.firstTransactionRow = firstTransactionRow
        document.delimiter = delimiter
        return document
    }
}
