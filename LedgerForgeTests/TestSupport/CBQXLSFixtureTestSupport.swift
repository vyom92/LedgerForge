import Foundation
@testable import LedgerForge

enum CBQXLSFixtureTestSupport {
    static let fixture = "cbq_current_account_xls_v1_synthetic.xls"

    static func read() async throws -> RawDocument {
        let url = FixtureLocator.cbqSyntheticXLS(fixture)
        let snapshot = SourceContentSnapshot(bytes: try Data(contentsOf: url))
        defer { snapshot.invalidate() }
        return try await LegacyXLSDocumentReader().read(
            request: ImportRequest(fileURL: url),
            snapshot: snapshot,
            password: nil
        )
    }

    static func normalized(from raw: RawDocument? = nil) async throws -> NormalizedDocument {
        let source: RawDocument
        if let raw {
            source = raw
        } else {
            source = try await read()
        }
        let result = try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: source)
        return NormalizedDocument(
            document: result.document,
            metadata: DocumentMetadata(
                institution: .cbq,
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
        rows[sourceRow - 1] = makeRow(sourceRow: sourceRow, values: values)
        return replacingSheet(in: raw, sheet: RawTabularSheet(
            name: sheet.name,
            visibility: sheet.visibility,
            columnCount: sheet.columnCount,
            rows: rows
        ))
    }

    static func appendingRow(in raw: RawDocument, values: [String]) -> RawDocument {
        guard case .tabular(let sheet) = raw.content else { return raw }
        var rows = sheet.rows
        rows.append(makeRow(sourceRow: rows.count + 1, values: values))
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
        copy(document, rows: document.rows.map { row in
            row.rowNumber == sourceRow
                ? NormalizedRow(rowNumber: row.rowNumber, values: transform(row.values))
                : row
        })
    }

    static func replacingFragment(
        in document: NormalizedDocument,
        sourceRow: Int,
        with text: String
    ) -> NormalizedDocument {
        let fragments = document.sourceContext.preTransactionFragments.map { fragment in
            fragment.sourceOrdinal == sourceRow
                ? NormalizedDocument.SourceFragment(
                    sourceOrdinal: sourceRow,
                    text: text
                )
                : fragment
        }
        return copy(
            document,
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: fragments,
                postTransactionFragments: document.sourceContext.postTransactionFragments
            )
        )
    }

    private static func makeRow(sourceRow: Int, values: [String]) -> RawTabularRow {
        RawTabularRow(
            sourceRow: sourceRow,
            cells: (0..<7).map { index in
                let text = values.indices.contains(index) ? values[index] : ""
                return RawTabularCell(
                    sourceRow: sourceRow,
                    sourceColumn: index + 1,
                    value: text.isEmpty ? .blank : .string(text)
                )
            }
        )
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
