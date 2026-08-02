import Foundation
@testable import LedgerForge

enum HDFCXLSFixtureTestSupport {
    static let annualFixture = "hdfc_bank_account_xls_v1_nre_synthetic.xls"
    static let recentFixture = "hdfc_bank_account_xls_v1_nro_synthetic.xls"

    static func read(_ fileName: String = annualFixture) async throws -> RawDocument {
        let url = FixtureLocator.hdfcSyntheticXLS(fileName)
        let snapshot = SourceContentSnapshot(bytes: try Data(contentsOf: url))
        defer { snapshot.invalidate() }
        return try await LegacyXLSDocumentReader().read(
            request: ImportRequest(fileURL: url),
            snapshot: snapshot,
            password: nil
        )
    }

    static func normalized(
        _ fileName: String = annualFixture
    ) async throws -> NormalizedDocument {
        try normalized(from: await read(fileName))
    }

    static func normalized(from raw: RawDocument) throws -> NormalizedDocument {
        let result = try HDFCBankAccountXLSNormalizer().normalize(rawDocument: raw)
        return NormalizedDocument(
            document: result.document,
            metadata: DocumentMetadata(
                institution: .hdfc,
                documentType: .bankAccount,
                fileFormat: .xls,
                confidence: 0.99
            ),
            rows: result.rows,
            header: result.header,
            sourceContext: result.sourceContext
        )
    }

    static func replacingCell(
        in raw: RawDocument,
        sourceRow: Int,
        sourceColumn: Int,
        with text: String
    ) -> RawDocument {
        guard case .tabular(let sheet) = raw.content else { return raw }
        var rows = sheet.rows
        var cells = rows[sourceRow - 1].cells
        cells[sourceColumn - 1] = RawTabularCell(
            sourceRow: sourceRow,
            sourceColumn: sourceColumn,
            value: text.isEmpty ? .blank : .string(text)
        )
        rows[sourceRow - 1] = RawTabularRow(sourceRow: sourceRow, cells: cells)
        return replacingSheet(in: raw, sheet: RawTabularSheet(
            name: sheet.name,
            visibility: sheet.visibility,
            columnCount: sheet.columnCount,
            rows: rows
        ))
    }

    static func replacingRow(
        in raw: RawDocument,
        sourceRow: Int,
        with values: [String]
    ) -> RawDocument {
        guard case .tabular(let sheet) = raw.content else { return raw }
        var rows = sheet.rows
        rows[sourceRow - 1] = RawTabularRow(
            sourceRow: sourceRow,
            cells: (0..<sheet.columnCount).map { index in
                let text = values.indices.contains(index) ? values[index] : ""
                return RawTabularCell(
                    sourceRow: sourceRow,
                    sourceColumn: index + 1,
                    value: text.isEmpty ? .blank : .string(text)
                )
            }
        )
        return replacingSheet(in: raw, sheet: RawTabularSheet(
            name: sheet.name,
            visibility: sheet.visibility,
            columnCount: sheet.columnCount,
            rows: rows
        ))
    }

    static func replacingSheet(
        in raw: RawDocument,
        name: String? = nil,
        visibility: RawTabularSheetVisibility? = nil,
        columnCount: Int? = nil
    ) -> RawDocument {
        guard case .tabular(let sheet) = raw.content else { return raw }
        return replacingSheet(in: raw, sheet: RawTabularSheet(
            name: name ?? sheet.name,
            visibility: visibility ?? sheet.visibility,
            columnCount: columnCount ?? sheet.columnCount,
            rows: sheet.rows
        ))
    }

    static func replacingNormalizedRow(
        in document: NormalizedDocument,
        sourceRow: Int,
        transform: ([String]) -> [String]
    ) -> NormalizedDocument {
        let rows = document.rows.map { row in
            row.rowNumber == sourceRow
                ? NormalizedRow(rowNumber: row.rowNumber, values: transform(row.values))
                : row
        }
        return copy(document, rows: rows)
    }

    static func replacingFragment(
        in document: NormalizedDocument,
        sourceRow: Int,
        postTransaction: Bool = false,
        transform: ([String]) -> [String]
    ) -> NormalizedDocument {
        func changed(
            _ fragments: [NormalizedDocument.SourceFragment]
        ) -> [NormalizedDocument.SourceFragment] {
            fragments.map { fragment in
                guard fragment.sourceOrdinal == sourceRow else { return fragment }
                let values = fragment.text.split(
                    separator: "\t",
                    omittingEmptySubsequences: false
                ).map(String.init)
                return NormalizedDocument.SourceFragment(
                    sourceOrdinal: fragment.sourceOrdinal,
                    text: transform(values).joined(separator: "\t")
                )
            }
        }
        let context = NormalizedDocument.SourceContext(
            preTransactionFragments: postTransaction
                ? document.sourceContext.preTransactionFragments
                : changed(document.sourceContext.preTransactionFragments),
            postTransactionFragments: postTransaction
                ? changed(document.sourceContext.postTransactionFragments)
                : document.sourceContext.postTransactionFragments
        )
        return copy(document, sourceContext: context)
    }

    private static func replacingSheet(
        in raw: RawDocument,
        sheet: RawTabularSheet
    ) -> RawDocument {
        RawDocument(
            id: raw.id,
            sourceURL: raw.sourceURL,
            fileName: raw.fileName,
            fileExtension: raw.fileExtension,
            content: .tabular(sheet),
            extractedAt: raw.extractedAt
        )
    }

    private static func copy(
        _ document: NormalizedDocument,
        rows: [NormalizedRow]? = nil,
        sourceContext: NormalizedDocument.SourceContext? = nil
    ) -> NormalizedDocument {
        NormalizedDocument(
            document: document.document,
            metadata: document.metadata,
            rows: rows ?? document.rows,
            header: document.header,
            sourceContext: sourceContext ?? document.sourceContext
        )
    }
}
