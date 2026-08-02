import CLegacyXLS
import Foundation

final class LegacyXLSDocumentReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["xls"]

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        guard supportedFileExtensions.contains(request.fileExtension) else {
            throw ImportError.unsupportedFile(extension: request.fileExtension)
        }

        let sheet = try snapshot.withBytes { bytes in
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
                    throw Self.importError(for: error)
                }
                defer { lf_xls_close(document) }

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

                var rows: [RawTabularRow] = []
                rows.reserveCapacity(rowCount)
                for rowIndex in 0..<rowCount {
                    var cells: [RawTabularCell] = []
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
                        cells.append(
                            RawTabularCell(
                                sourceRow: rowIndex + 1,
                                sourceColumn: columnIndex + 1,
                                value: value
                            )
                        )
                    }
                    rows.append(RawTabularRow(sourceRow: rowIndex + 1, cells: cells))
                }

                return RawTabularSheet(
                    name: sheetName,
                    visibility: .visible,
                    columnCount: columnCount,
                    rows: rows
                )
            }
        }

        return RawDocument(
            sourceURL: request.fileURL,
            fileName: request.fileName,
            fileExtension: request.fileExtension,
            content: .tabular(sheet)
        )
    }

    private static func importError(for error: LF_XLS_ERROR) -> ImportError {
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
