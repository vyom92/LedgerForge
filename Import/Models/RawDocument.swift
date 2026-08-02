// Import/Models/RawDocument.swift
// Raw document output produced by document readers

import Foundation

public struct RawDocument: Equatable, Sendable {
    public let id: UUID
    public let sourceURL: URL
    public let fileName: String
    public let fileExtension: String
    public let content: RawDocumentContent
    public let extractedAt: Date

    public init(id: UUID = UUID(), sourceURL: URL, fileName: String, fileExtension: String, content: RawDocumentContent, extractedAt: Date = Date()) {
        self.id = id
        self.sourceURL = sourceURL
        self.fileName = fileName
        self.fileExtension = fileExtension.lowercased()
        self.content = content
        self.extractedAt = extractedAt
    }
}

public enum RawDocumentContent: Equatable, Sendable {
    case text(String)
    case data(Data)
    case tabular(RawTabularSheet)

    var searchableText: String {
        switch self {
        case .text(let text):
            return text
        case .data:
            return ""
        case .tabular(let sheet):
            return sheet.searchableText
        }
    }
}

public enum RawTabularSheetVisibility: String, Equatable, Sendable {
    case visible
    case hidden
}

public enum RawTabularCellValue: Equatable, Sendable {
    case blank
    case string(String)
    case number(String)

    var canonicalText: String {
        switch self {
        case .blank:
            return ""
        case .string(let value), .number(let value):
            return value
        }
    }
}

public struct RawTabularCell: Equatable, Sendable {
    public let sourceRow: Int
    public let sourceColumn: Int
    public let value: RawTabularCellValue

    public init(sourceRow: Int, sourceColumn: Int, value: RawTabularCellValue) {
        self.sourceRow = sourceRow
        self.sourceColumn = sourceColumn
        self.value = value
    }
}

public struct RawTabularRow: Equatable, Sendable {
    public let sourceRow: Int
    public let cells: [RawTabularCell]

    public init(sourceRow: Int, cells: [RawTabularCell]) {
        self.sourceRow = sourceRow
        self.cells = cells
    }
}

public struct RawTabularSheet: Equatable, Sendable {
    public let name: String
    public let visibility: RawTabularSheetVisibility
    public let columnCount: Int
    public let rows: [RawTabularRow]

    public init(
        name: String,
        visibility: RawTabularSheetVisibility,
        columnCount: Int,
        rows: [RawTabularRow]
    ) {
        self.name = name
        self.visibility = visibility
        self.columnCount = columnCount
        self.rows = rows
    }

    public var searchableText: String {
        let sheetLine = ["SHEET", projectionText(name)].joined(separator: "\t")
        let rowLines = rows.map { row in
            (["ROW", String(row.sourceRow)] + row.cells.map {
                projectionText($0.value.canonicalText)
            }).joined(separator: "\t")
        }
        return ([sheetLine] + rowLines).joined(separator: "\n")
    }

    private func projectionText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }
}

public extension RawDocument {
    var searchableText: String { content.searchableText }
}
