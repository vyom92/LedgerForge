// Import/Models/RawDocument.swift
// Raw document output produced by document readers

import Foundation

/// Source-agnostic horizontal rectangle evidence for one extracted PDF text
/// fragment. `baselineY` is retained in the reader's canonical page space so
/// downstream consumers can reconstruct source rows without knowing how the
/// text was segmented.
nonisolated public struct RawPDFTextGeometry: Equatable, Sendable {
    public let minX: Double
    public let maxX: Double
    public let baselineY: Double

    public nonisolated init(minX: Double, maxX: Double, baselineY: Double) {
        self.minX = minX
        self.maxX = maxX
        self.baselineY = baselineY
    }

    public nonisolated var isCanonical: Bool {
        minX.isFinite && maxX.isFinite && baselineY.isFinite && maxX >= minX
    }
}

/// One reader-extracted PDF text fragment with rectangle-backed source
/// position. Financial interpretation belongs to downstream normalizers and
/// parsers.
nonisolated public struct RawPDFTextFragment: Equatable, Sendable {
    public let text: String
    public let x: Double
    public let y: Double
    public let geometry: RawPDFTextGeometry?
    /// Complete selectable-text rectangle in the original page coordinate space.
    public let bounds: CGRect?
    /// Optional left-to-right glyph projection for an ASCII numeric/punctuation
    /// fragment. Native PDF text order remains in `text`; a table-owning
    /// normalizer decides whether its source uses this visual direction.
    public let positionOrderedText: String?

    public nonisolated init(text: String, geometry: RawPDFTextGeometry, bounds: CGRect? = nil,
                            positionOrderedText: String? = nil) {
        self.text = text
        self.x = geometry.minX
        self.y = geometry.baselineY
        self.geometry = geometry
        self.bounds = bounds
        self.positionOrderedText = positionOrderedText
    }
}

/// Transient PDF resource evidence retained only long enough for a profile to
/// distinguish source-semantic image pages from an inert repeated masthead.
/// This is structural metadata only; no source image bytes are retained.
nonisolated public struct RawPDFPageResourceEvidence: Equatable, Sendable {
    public let imageResourceCount: Int
    public let largestImageWidth: Int
    public let largestImageHeight: Int

    public nonisolated init(
        imageResourceCount: Int,
        largestImageWidth: Int = 0,
        largestImageHeight: Int = 0
    ) {
        self.imageResourceCount = max(0, imageResourceCount)
        self.largestImageWidth = max(0, largestImageWidth)
        self.largestImageHeight = max(0, largestImageHeight)
    }
}

/// Positioned text evidence for one PDF page, in source extraction order.
nonisolated public struct RawPDFLineSegment: Equatable, Sendable {
    public let start: CGPoint
    public let end: CGPoint
    public init(start: CGPoint, end: CGPoint) { self.start = start; self.end = end }
}

/// Source-drawn rules and rectangles. These are transient page geometry;
/// readers assign no table, account, or financial meaning to them.
nonisolated public struct RawPDFDrawingEvidence: Equatable, Sendable {
    public let segments: [RawPDFLineSegment]
    public let rectangles: [CGRect]
    public init(segments: [RawPDFLineSegment], rectangles: [CGRect]) {
        self.segments = segments; self.rectangles = rectangles
    }
}

nonisolated public struct RawPDFPageEvidence: Equatable, Sendable {
    public let fragments: [RawPDFTextFragment]
    public let resourceEvidence: RawPDFPageResourceEvidence?
    public let bounds: CGRect?
    public let drawings: RawPDFDrawingEvidence?

    public nonisolated init(
        fragments: [RawPDFTextFragment],
        resourceEvidence: RawPDFPageResourceEvidence? = nil,
        bounds: CGRect? = nil,
        drawings: RawPDFDrawingEvidence? = nil
    ) {
        self.fragments = fragments
        self.resourceEvidence = resourceEvidence
        self.bounds = bounds
        self.drawings = drawings
    }
}

/// Generic tagged-PDF cell role retained from the source structure tree.
nonisolated public enum RawPDFTaggedCellRole: String, Equatable, Sendable {
    case header = "TH"
    case data = "TD"
}

/// One marked-content reference resolved on its source page.
/// Text blocks retain source text-block order within the marked-content segment.
nonisolated public struct RawPDFTaggedMarkedContentEvidence: Equatable, Sendable {
    public let pageNumber: Int
    public let mcid: Int
    public let textBlocks: [String]
    public let rectangleCount: Int

    public nonisolated init(pageNumber: Int, mcid: Int, textBlocks: [String], rectangleCount: Int) {
        self.pageNumber = pageNumber
        self.mcid = mcid
        self.textBlocks = textBlocks
        self.rectangleCount = rectangleCount
    }
}

/// One structure child beneath a tagged logical cell, preserving its source role
/// and ordered marked-content descendants.
nonisolated public struct RawPDFTaggedStructureChildEvidence: Equatable, Sendable {
    public let role: String
    public let markedContent: [RawPDFTaggedMarkedContentEvidence]

    public nonisolated init(role: String, markedContent: [RawPDFTaggedMarkedContentEvidence]) {
        self.role = role
        self.markedContent = markedContent
    }
}

/// Ordered `/K` child evidence for a tagged logical cell.
nonisolated public enum RawPDFTaggedCellChildEvidence: Equatable, Sendable {
    case markedContent(RawPDFTaggedMarkedContentEvidence)
    case structure(RawPDFTaggedStructureChildEvidence)
}

nonisolated public struct RawPDFTaggedCellEvidence: Equatable, Sendable {
    public let role: RawPDFTaggedCellRole
    public let children: [RawPDFTaggedCellChildEvidence]

    public nonisolated init(role: RawPDFTaggedCellRole, children: [RawPDFTaggedCellChildEvidence]) {
        self.role = role
        self.children = children
    }
}

nonisolated public struct RawPDFTaggedRowEvidence: Equatable, Sendable {
    public let cells: [RawPDFTaggedCellEvidence]

    public nonisolated init(cells: [RawPDFTaggedCellEvidence]) {
        self.cells = cells
    }
}

nonisolated public struct RawPDFTaggedTableEvidence: Equatable, Sendable {
    public let rows: [RawPDFTaggedRowEvidence]

    public nonisolated init(rows: [RawPDFTaggedRowEvidence]) {
        self.rows = rows
    }
}

nonisolated public struct RawDocument: Equatable, Sendable {
    public let id: UUID
    public let sourceURL: URL
    public let fileName: String
    public let fileExtension: String
    public let content: RawDocumentContent
    /// Reader-owned, in-memory-only native PDF text preserving page boundaries.
    /// Source identity and persistence continue to use the immutable original
    /// snapshot bytes; decrypted or reconstructed PDF bytes are never emitted.
    public let pdfPageTexts: [String]?
    /// Reader-owned, in-memory-only positioned PDF text evidence.
    /// Array order is source page order. Financial semantics are deliberately
    /// not interpreted at the reader boundary.
    public let pdfPageEvidence: [RawPDFPageEvidence]?
    /// Reader-owned, in-memory-only PDF page resource evidence. This carrier is
    /// intentionally independent from positioned text extraction: a page may
    /// have useful image/resource metadata even when one positioned text range
    /// cannot be resolved. Array order is source page order and, when present,
    /// always matches the native PDF page count.
    public let pdfPageResourceEvidence: [RawPDFPageResourceEvidence]?
    /// Reader-owned, in-memory-only tagged logical table evidence. Absence is
    /// ordinary for untagged PDFs and does not change existing reader behavior.
    public let pdfTaggedTables: [RawPDFTaggedTableEvidence]?
    public let extractedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        sourceURL: URL,
        fileName: String,
        fileExtension: String,
        content: RawDocumentContent,
        pdfPageTexts: [String]? = nil,
        pdfPageEvidence: [RawPDFPageEvidence]? = nil,
        pdfPageResourceEvidence: [RawPDFPageResourceEvidence]? = nil,
        pdfTaggedTables: [RawPDFTaggedTableEvidence]? = nil,
        extractedAt: Date = Date()
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.fileName = fileName
        self.fileExtension = fileExtension.lowercased()
        self.content = content
        self.pdfPageTexts = pdfPageTexts
        self.pdfPageEvidence = pdfPageEvidence
        self.pdfPageResourceEvidence = pdfPageResourceEvidence
        self.pdfTaggedTables = pdfTaggedTables
        self.extractedAt = extractedAt
    }
}

nonisolated public enum RawDocumentContent: Equatable, Sendable {
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

nonisolated public enum RawTabularSheetVisibility: String, Equatable, Sendable {
    case visible
    case hidden
}

nonisolated public enum RawTabularCellValue: Equatable, Sendable {
    case blank
    case string(String)
    case number(String)

    nonisolated var canonicalText: String {
        switch self {
        case .blank:
            return ""
        case .string(let value), .number(let value):
            return value
        }
    }
}

nonisolated public struct RawTabularCell: Equatable, Sendable {
    public let sourceRow: Int
    public let sourceColumn: Int
    public let value: RawTabularCellValue
    /// OOXML cell style index. Legacy XLS readers leave this nil.
    public let styleIndex: Int?
    /// OOXML number-format code resolved from the workbook style table.
    /// Legacy XLS readers leave this nil.
    public let numberFormatCode: String?

    public init(
        sourceRow: Int,
        sourceColumn: Int,
        value: RawTabularCellValue,
        styleIndex: Int? = nil,
        numberFormatCode: String? = nil
    ) {
        self.sourceRow = sourceRow
        self.sourceColumn = sourceColumn
        self.value = value
        self.styleIndex = styleIndex
        self.numberFormatCode = numberFormatCode
    }
}

nonisolated public struct RawTabularRow: Equatable, Sendable {
    public let sourceRow: Int
    public let cells: [RawTabularCell]

    public init(sourceRow: Int, cells: [RawTabularCell]) {
        self.sourceRow = sourceRow
        self.cells = cells
    }
}

/// A merged range declared by a tabular source, expressed in one-based cell
/// coordinates. The OOXML reader retains the original A1 reference as well as
/// its decoded bounds so callers do not need to reinterpret workbook syntax.
nonisolated public struct RawTabularMergedRange: Equatable, Sendable {
    public let reference: String
    public let startRow: Int
    public let startColumn: Int
    public let endRow: Int
    public let endColumn: Int

    public init(
        reference: String,
        startRow: Int,
        startColumn: Int,
        endRow: Int,
        endColumn: Int
    ) {
        self.reference = reference
        self.startRow = startRow
        self.startColumn = startColumn
        self.endRow = endRow
        self.endColumn = endColumn
    }
}

/// Compatibility spelling for clients that refer to a range as a merge range.
public typealias RawTabularMergeRange = RawTabularMergedRange

nonisolated public struct RawTabularSheet: Equatable, Sendable {
    public let name: String
    public let visibility: RawTabularSheetVisibility
    public let columnCount: Int
    public let rows: [RawTabularRow]
    public let mergedRanges: [RawTabularMergedRange]

    public init(
        name: String,
        visibility: RawTabularSheetVisibility,
        columnCount: Int,
        rows: [RawTabularRow],
        mergedRanges: [RawTabularMergedRange] = []
    ) {
        self.name = name
        self.visibility = visibility
        self.columnCount = columnCount
        self.rows = rows
        self.mergedRanges = mergedRanges
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
    nonisolated var searchableText: String { content.searchableText }
}
