import CLegacyXLS
import Foundation

nonisolated final class LegacyXLSDocumentReader: ImportFramework.DocumentReader, Sendable {
    enum Event: Equatable, Sendable {
        case waitingForOwner, enteredOwner, openedDocument, closedDocument, finishedRead
    }

    /// Test-only observation. Callbacks receive no source bytes or C pointers
    /// and must not synchronously re-enter a reader, snapshot, or this owner.
    typealias EventObserver = @Sendable (Event) -> Void
    let supportedFileExtensions: Set<String> = ["xls"]
    private let eventObserver: EventObserver?

    init(eventObserver: EventObserver? = nil) {
        self.eventObserver = eventObserver
    }

    nonisolated func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        let metadata = await MainActor.run { (request.fileName, request.fileExtension) }
        guard supportedFileExtensions.contains(metadata.1) else {
            throw ImportError.unsupportedFile(extension: metadata.1)
        }

        try Task.checkCancellation()
        let result = LegacyXLSProcessOwner.read(
            snapshot: snapshot,
            eventObserver: eventObserver
        )
        try Task.checkCancellation()
        let copied = try result.get()

        // Existing raw-document initializers are MainActor-owned. Materialize
        // them only after the C owner has closed and released its snapshot.
        let document = await MainActor.run {
            let rows = copied.rows.enumerated().map { rowIndex, values in
                RawTabularRow(
                    sourceRow: rowIndex + 1,
                    cells: values.enumerated().map { columnIndex, value in
                        RawTabularCell(
                            sourceRow: rowIndex + 1,
                            sourceColumn: columnIndex + 1,
                            value: value
                        )
                    }
                )
            }
            let sheet = RawTabularSheet(
                name: copied.name,
                visibility: .visible,
                columnCount: copied.columnCount,
                rows: rows
            )
            return RawDocument(
                sourceURL: request.fileURL,
                fileName: metadata.0,
                fileExtension: metadata.1,
                content: .tabular(sheet)
            )
        }
        try Task.checkCancellation()
        return document
    }

    fileprivate static func importError(for error: LF_XLS_ERROR) -> ImportError {
        switch error {
        case LF_XLS_ERROR_UNSUPPORTED_ENCRYPTION:
            return .unsupportedStatement(message: "Encrypted XLS workbooks are unsupported.")
        case LF_XLS_ERROR_MULTIPLE_SHEETS:
            return .unsupportedStatement(message: "XLS workbooks must contain exactly one worksheet.")
        case LF_XLS_ERROR_HIDDEN_SHEET:
            return .unsupportedStatement(message: "Hidden XLS worksheets are unsupported.")
        case LF_XLS_ERROR_UNSUPPORTED_SHEET_KIND:
            return .unsupportedStatement(message: "Only ordinary XLS worksheets are supported.")
        case LF_XLS_ERROR_FORMULA_CELL:
            return .unsupportedStatement(message: "Formula cells are unsupported in XLS imports.")
        case LF_XLS_ERROR_BOOLEAN_OR_ERROR_CELL:
            return .unsupportedStatement(message: "Boolean and error cells are unsupported in XLS imports.")
        case LF_XLS_ERROR_HIDDEN_CELL:
            return .unsupportedStatement(message: "Hidden XLS cells are unsupported.")
        case LF_XLS_ERROR_SOURCE_TOO_LARGE,
             LF_XLS_ERROR_DIMENSIONS_EXCEEDED,
             LF_XLS_ERROR_STRING_ALLOCATION_EXCEEDED,
             LF_XLS_ERROR_ALLOCATION:
            return .invalidDocument(message: "XLS workbook exceeds supported resource limits.")
        case LF_XLS_ERROR_TRUNCATED:
            return .invalidDocument(message: "XLS workbook is truncated.")
        case LF_XLS_ERROR_INVALID_ARGUMENT,
             LF_XLS_ERROR_INVALID_CONTAINER,
             LF_XLS_ERROR_MALFORMED,
             LF_XLS_ERROR_OK:
            return .invalidDocument(message: "XLS workbook is malformed or unsupported.")
        default:
            return .invalidDocument(message: "XLS workbook is malformed or unsupported.")
        }
    }
}

/// libxls has mutable process-global debug and formula-handler state. This
/// vendored call path has no affirmative reentrancy guarantee. This concrete
/// owner serializes every LedgerForge open/read/close without claiming libxls
/// is thread-safe. The lock order is process owner, then source snapshot; only
/// copied Swift values leave the non-suspending C section.
nonisolated private enum LegacyXLSProcessOwner {
    struct CopiedSheet: Sendable {
        let name: String
        let columnCount: Int
        let rows: [[RawTabularCellValue]]
    }

    private static let lock = NSLock()
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    static func read(
        snapshot: SourceContentSnapshot,
        eventObserver: LegacyXLSDocumentReader.EventObserver?
    ) -> Result<CopiedSheet, Error> {
        eventObserver?(.waitingForOwner)
        lock.lock()
        defer { lock.unlock() }

        do {
            try Task.checkCancellation()
        } catch {
            return .failure(error)
        }
        eventObserver?(.enteredOwner)

        let result = Result<CopiedSheet, Error> {
            try snapshot.withBytes { bytes in
                try bytes.withUnsafeBytes { rawBuffer in
                    guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                        throw ImportError.invalidDocument(message: "XLS source data is empty.")
                    }

                    var error = LF_XLS_ERROR_OK
                    guard let document = lf_xls_open_buffer(
                        baseAddress,
                        rawBuffer.count,
                        &error
                    ) else {
                        throw LegacyXLSDocumentReader.importError(for: error)
                    }
                    eventObserver?(.openedDocument)
                    defer {
                        lf_xls_close(document)
                        eventObserver?(.closedDocument)
                    }

                    guard let sheetNamePointer = lf_xls_sheet_name(document),
                          let sheetName = String(validatingCString: sheetNamePointer) else {
                        throw ImportError.invalidDocument(
                            message: "XLS worksheet name is not valid UTF-8."
                        )
                    }

                    let rowCount = Int(lf_xls_row_count(document))
                    let columnCount = Int(lf_xls_column_count(document))
                    guard rowCount > 0, columnCount > 0 else {
                        throw ImportError.invalidDocument(message: "XLS worksheet is empty.")
                    }

                    var rows: [[RawTabularCellValue]] = []
                    rows.reserveCapacity(rowCount)
                    for rowIndex in 0..<rowCount {
                        var cells: [RawTabularCellValue] = []
                        cells.reserveCapacity(columnCount)
                        for columnIndex in 0..<columnCount {
                            let kind = lf_xls_cell_kind(
                                document,
                                UInt32(rowIndex),
                                UInt32(columnIndex)
                            )
                            let value: RawTabularCellValue
                            switch kind {
                            case LF_XLS_CELL_BLANK:
                                value = .blank
                            case LF_XLS_CELL_STRING:
                                guard let pointer = lf_xls_cell_string(
                                    document,
                                    UInt32(rowIndex),
                                    UInt32(columnIndex)
                                ), let string = String(validatingCString: pointer) else {
                                    throw ImportError.invalidDocument(
                                        message: "XLS cell text is not valid UTF-8."
                                    )
                                }
                                value = .string(string)
                            case LF_XLS_CELL_NUMBER:
                                let number = lf_xls_cell_number(
                                    document,
                                    UInt32(rowIndex),
                                    UInt32(columnIndex)
                                )
                                guard number.isFinite else {
                                    throw ImportError.invalidDocument(
                                        message: "XLS numeric cell is not finite."
                                    )
                                }
                                value = .number(
                                    String(
                                        format: "%.15g",
                                        locale: Self.posixLocale,
                                        number
                                    )
                                )
                            default:
                                throw ImportError.invalidDocument(
                                    message: "XLS cell type is unsupported."
                                )
                            }
                            cells.append(value)
                        }
                        rows.append(cells)
                    }

                    return CopiedSheet(
                        name: sheetName,
                        columnCount: columnCount,
                        rows: rows
                    )
                }
            }
        }
        // The C document and borrowed snapshot have ended before this event,
        // which still occurs while the process owner is held.
        eventObserver?(.finishedRead)
        return result
    }
}
