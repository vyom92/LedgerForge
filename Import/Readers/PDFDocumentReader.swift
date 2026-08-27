import Foundation
import PDFKit
import CoreGraphics

final class PDFDocumentReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["pdf"]

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        guard supportedFileExtensions.contains(request.fileExtension) else {
            throw ImportError.unsupportedFile(extension: request.fileExtension)
        }

        let extracted = try snapshot.withBytes { bytes -> (
            text: String,
            pages: [String],
            pageEvidence: [RawPDFPageEvidence]?,
            taggedTables: [RawPDFTaggedTableEvidence]?
        ) in
            guard let document = PDFDocument(data: bytes) else {
                throw ImportError.invalidDocument(message: "Unable to open PDF document.")
            }

            if document.isLocked {
                guard let password else {
                    throw ImportError.passwordRequired
                }

                guard document.unlock(withPassword: password), !document.isLocked else {
                    throw ImportError.incorrectPassword
                }
            }

            let pdfKitText = document.string
            let pages = (0..<document.pageCount).compactMap { pageIndex -> String? in
                guard let pageText = document.page(at: pageIndex)?.string,
                      !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return pageText
            }
            guard let pdfKitText,
                  !pdfKitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  pages.count == document.pageCount else {
                throw ImportError.invalidDocument(message: "PDF document contains no extractable text.")
            }
            let pageEvidence = PDFKitPositionedTextExtractor.extractPages(document: document)
            let text = pages.joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ImportError.invalidDocument(message: "PDF document contains no extractable text.")
            }
            let taggedTables = TaggedPDFTableExtractor.extractTables(
                bytes: bytes,
                password: password,
                expectedPageCount: document.pageCount
            )
            return (text, pages, pageEvidence, taggedTables)
        }

        return RawDocument(
            sourceURL: request.fileURL,
            fileName: request.fileName,
            fileExtension: request.fileExtension,
            content: .text(extracted.text),
            pdfPageTexts: extracted.pages,
            pdfPageEvidence: extracted.pageEvidence,
            pdfTaggedTables: extracted.taggedTables
        )
    }
}

/// Generic finite-grained range evidence derived from PDFKit's selectable
/// text. Segmentation is driven only by source whitespace and retains each
/// range's horizontal rectangle plus canonical page-space row coordinate.
private enum PDFKitPositionedTextExtractor {
    static func extractPages(document: PDFDocument) -> [RawPDFPageEvidence]? {
        guard document.pageCount > 0 else { return nil }
        var result: [RawPDFPageEvidence] = []
        result.reserveCapacity(document.pageCount)
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let pageText = page.string,
                  !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let tokenRegex = try? NSRegularExpression(pattern: #"\S+"#) else {
                return nil
            }
            let pageRange = NSRange(pageText.startIndex..., in: pageText)
            let matches = tokenRegex.matches(in: pageText, range: pageRange)
            guard !matches.isEmpty else { return nil }
            var fragments: [RawPDFTextFragment] = []
            fragments.reserveCapacity(matches.count)
            for match in matches {
                guard let textRange = Range(match.range, in: pageText),
                      let selection = page.selection(for: match.range) else {
                    return nil
                }
                let text = String(pageText[textRange])
                let bounds = selection.bounds(for: page)
                let geometry = RawPDFTextGeometry(
                    minX: Double(bounds.minX),
                    maxX: Double(bounds.maxX),
                    baselineY: Double(bounds.midY)
                )
                guard !text.isEmpty, geometry.isCanonical, geometry.maxX > geometry.minX else {
                    return nil
                }
                fragments.append(RawPDFTextFragment(text: text, geometry: geometry))
            }
            guard !fragments.isEmpty else { return nil }
            result.append(RawPDFPageEvidence(fragments: fragments))
        }
        return result
    }
}

/// Bounded extraction of source-tagged table structure. This evidence is
/// independent of PDFKit's visual range geometry and is used only when a
/// profile explicitly requires a tagged logical table.
private enum TaggedPDFTableExtractor {
    private struct MarkedSegment {
        var textBlocks: [String] = []
        var rectangleCount = 0
    }

    private final class ScanState {
        let fontMaps: [String: [UInt8: String]]
        let propertyMCIDs: [String: Int]
        var fontName: String?
        var markedStack: [Int?] = []
        var segments: [Int: MarkedSegment] = [:]
        var invalid = false
        var decodedCharacterCount = 0

        init(fontMaps: [String: [UInt8: String]], propertyMCIDs: [String: Int]) {
            self.fontMaps = fontMaps
            self.propertyMCIDs = propertyMCIDs
        }

        var activeMCID: Int? {
            for value in markedStack.reversed() {
                if let value { return value }
            }
            return nil
        }

        func beginMarkedContent(_ mcid: Int?) {
            markedStack.append(mcid)
        }

        func endMarkedContent() {
            guard !markedStack.isEmpty else {
                invalid = true
                return
            }
            markedStack.removeLast()
        }

        func beginTextBlock() {
            guard let activeMCID else { return }
            var segment = segments[activeMCID, default: MarkedSegment()]
            segment.textBlocks.append("")
            segments[activeMCID] = segment
        }

        func noteRectangle() {
            guard let activeMCID else { return }
            var segment = segments[activeMCID, default: MarkedSegment()]
            segment.rectangleCount += 1
            segments[activeMCID] = segment
        }

        func append(_ string: CGPDFStringRef) {
            guard let activeMCID else { return }
            guard let fontName,
                  let map = fontMaps[fontName],
                  let pointer = CGPDFStringGetBytePtr(string) else {
                invalid = true
                return
            }
            let length = CGPDFStringGetLength(string)
            guard length > 0, length <= 512 else {
                invalid = true
                return
            }
            var decoded = ""
            for index in 0..<length {
                guard let value = map[pointer[index]] else {
                    invalid = true
                    return
                }
                decoded.append(value)
                decodedCharacterCount += value.count
                guard decodedCharacterCount <= 200_000 else {
                    invalid = true
                    return
                }
            }
            guard !decoded.isEmpty else { return }
            var segment = segments[activeMCID, default: MarkedSegment()]
            if segment.textBlocks.isEmpty { segment.textBlocks.append("") }
            segment.textBlocks[segment.textBlocks.count - 1] += decoded
            segments[activeMCID] = segment
        }

        func appendSpace() {
            guard let activeMCID else { return }
            var segment = segments[activeMCID, default: MarkedSegment()]
            if segment.textBlocks.isEmpty { segment.textBlocks.append("") }
            let index = segment.textBlocks.count - 1
            if !segment.textBlocks[index].isEmpty, !segment.textBlocks[index].hasSuffix(" ") {
                segment.textBlocks[index].append(" ")
            }
            segments[activeMCID] = segment
        }
    }

    static func extractTables(
        bytes: Data,
        password: String?,
        expectedPageCount: Int
    ) -> [RawPDFTaggedTableEvidence]? {
        guard expectedPageCount > 0,
              let provider = CGDataProvider(data: bytes as CFData),
              let document = CGPDFDocument(provider) else { return nil }
        if document.isEncrypted, !document.isUnlocked {
            guard let password,
                  password.utf8.count <= 256,
                  document.unlockWithPassword(password) else { return nil }
        }
        guard document.isUnlocked,
              document.numberOfPages == expectedPageCount,
              let catalog = document.catalog else { return nil }

        var markInfo: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(catalog, "MarkInfo", &markInfo), let markInfo else { return nil }
        var marked: CGPDFBoolean = 0
        guard CGPDFDictionaryGetBoolean(markInfo, "Marked", &marked), marked != 0 else { return nil }
        var structTreeRoot: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(catalog, "StructTreeRoot", &structTreeRoot),
              let structTreeRoot else { return nil }

        let tableElements = tables(in: structTreeRoot)
        guard !tableElements.isEmpty else { return nil }

        var scans: [Int: ScanState] = [:]
        for pageNumber in 1...document.numberOfPages {
            guard let page = document.page(at: pageNumber),
                  let scan = scan(page: page) else { return nil }
            scans[pageNumber] = scan
        }

        var result: [RawPDFTaggedTableEvidence] = []
        result.reserveCapacity(tableElements.count)
        for table in tableElements {
            guard let extracted = extractTable(table, document: document, scans: scans) else { return nil }
            result.append(extracted)
        }
        return result
    }

    private static func extractTable(
        _ table: CGPDFDictionaryRef,
        document: CGPDFDocument,
        scans: [Int: ScanState]
    ) -> RawPDFTaggedTableEvidence? {
        let children = immediateStructureChildren(table)
        guard !children.isEmpty,
              children.allSatisfy({ role($0) == "TR" }) else { return nil }
        var rows: [RawPDFTaggedRowEvidence] = []
        rows.reserveCapacity(children.count)
        for row in children {
            guard let extracted = extractRow(row, document: document, scans: scans) else { return nil }
            rows.append(extracted)
        }
        return RawPDFTaggedTableEvidence(rows: rows)
    }

    private static func extractRow(
        _ row: CGPDFDictionaryRef,
        document: CGPDFDocument,
        scans: [Int: ScanState]
    ) -> RawPDFTaggedRowEvidence? {
        let children = immediateStructureChildren(row)
        guard !children.isEmpty,
              children.allSatisfy({ role($0) == "TH" || role($0) == "TD" }) else { return nil }
        var cells: [RawPDFTaggedCellEvidence] = []
        cells.reserveCapacity(children.count)
        for cell in children {
            guard let extracted = extractCell(cell, document: document, scans: scans) else { return nil }
            cells.append(extracted)
        }
        return RawPDFTaggedRowEvidence(cells: cells)
    }

    private static func extractCell(
        _ cell: CGPDFDictionaryRef,
        document: CGPDFDocument,
        scans: [Int: ScanState]
    ) -> RawPDFTaggedCellEvidence? {
        let cellRole: RawPDFTaggedCellRole
        switch role(cell) {
        case "TH": cellRole = .header
        case "TD": cellRole = .data
        default: return nil
        }
        guard let kObject = object(cell, key: "K"),
              let ordered = orderedObjects(kObject),
              !ordered.isEmpty else { return nil }
        var children: [RawPDFTaggedCellChildEvidence] = []
        for item in ordered {
            switch CGPDFObjectGetType(item) {
            case .integer:
                guard let evidence = markedContent(
                    item,
                    owner: cell,
                    document: document,
                    scans: scans
                ) else { return nil }
                children.append(.markedContent(evidence))
            case .dictionary:
                var dictionary: CGPDFDictionaryRef?
                guard CGPDFObjectGetValue(item, .dictionary, &dictionary), let dictionary else { return nil }
                if let childRole = role(dictionary) {
                    guard let marked = structureMarkedContent(
                        dictionary,
                        document: document,
                        scans: scans
                    ) else { return nil }
                    children.append(.structure(.init(role: childRole, markedContent: marked)))
                } else {
                    guard let evidence = markedContent(
                        item,
                        owner: cell,
                        document: document,
                        scans: scans
                    ) else { return nil }
                    children.append(.markedContent(evidence))
                }
            default:
                return nil
            }
        }
        return RawPDFTaggedCellEvidence(role: cellRole, children: children)
    }

    private static func structureMarkedContent(
        _ structure: CGPDFDictionaryRef,
        document: CGPDFDocument,
        scans: [Int: ScanState]
    ) -> [RawPDFTaggedMarkedContentEvidence]? {
        guard let kObject = object(structure, key: "K"),
              let ordered = orderedObjects(kObject),
              !ordered.isEmpty else { return nil }
        var result: [RawPDFTaggedMarkedContentEvidence] = []
        for item in ordered {
            guard let evidence = markedContent(
                item,
                owner: structure,
                document: document,
                scans: scans
            ) else { return nil }
            result.append(evidence)
        }
        return result
    }

    private static func markedContent(
        _ object: CGPDFObjectRef,
        owner: CGPDFDictionaryRef,
        document: CGPDFDocument,
        scans: [Int: ScanState]
    ) -> RawPDFTaggedMarkedContentEvidence? {
        let mcid: Int
        let pageNumber: Int
        switch CGPDFObjectGetType(object) {
        case .integer:
            var value: CGPDFInteger = 0
            guard CGPDFObjectGetValue(object, .integer, &value),
                  let inherited = inheritedPage(owner, document: document) else { return nil }
            mcid = Int(value)
            pageNumber = inherited
        case .dictionary:
            var dictionary: CGPDFDictionaryRef?
            guard CGPDFObjectGetValue(object, .dictionary, &dictionary), let dictionary else { return nil }
            var value: CGPDFInteger = 0
            guard CGPDFDictionaryGetInteger(dictionary, "MCID", &value) else { return nil }
            mcid = Int(value)
            if var page: CGPDFDictionaryRef? = nil,
               CGPDFDictionaryGetDictionary(dictionary, "Pg", &page), let page,
               let explicit = Self.pageNumber(page, document: document) {
                pageNumber = explicit
            } else {
                guard let inherited = inheritedPage(owner, document: document) else { return nil }
                pageNumber = inherited
            }
        default:
            return nil
        }
        guard let segment = scans[pageNumber]?.segments[mcid] else { return nil }
        let blocks = segment.textBlocks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return RawPDFTaggedMarkedContentEvidence(
            pageNumber: pageNumber,
            mcid: mcid,
            textBlocks: blocks,
            rectangleCount: segment.rectangleCount
        )
    }

    private static func tables(in root: CGPDFDictionaryRef) -> [CGPDFDictionaryRef] {
        var result: [CGPDFDictionaryRef] = []
        func visit(_ element: CGPDFDictionaryRef) {
            for child in immediateStructureChildren(element) {
                if role(child) == "Table" { result.append(child) }
                visit(child)
            }
        }
        visit(root)
        return result
    }

    private static func immediateStructureChildren(_ dictionary: CGPDFDictionaryRef) -> [CGPDFDictionaryRef] {
        guard let kObject = object(dictionary, key: "K") else { return [] }
        var result: [CGPDFDictionaryRef] = []
        func visit(_ object: CGPDFObjectRef) {
            switch CGPDFObjectGetType(object) {
            case .array:
                var array: CGPDFArrayRef?
                guard CGPDFObjectGetValue(object, .array, &array), let array else { return }
                for index in 0..<CGPDFArrayGetCount(array) {
                    var child: CGPDFObjectRef?
                    if CGPDFArrayGetObject(array, index, &child), let child { visit(child) }
                }
            case .dictionary:
                var child: CGPDFDictionaryRef?
                guard CGPDFObjectGetValue(object, .dictionary, &child), let child else { return }
                if role(child) != nil {
                    result.append(child)
                } else if let nested = TaggedPDFTableExtractor.object(child, key: "K") {
                    visit(nested)
                }
            default:
                break
            }
        }
        visit(kObject)
        return result
    }

    private static func orderedObjects(_ object: CGPDFObjectRef) -> [CGPDFObjectRef]? {
        if CGPDFObjectGetType(object) != .array { return [object] }
        var array: CGPDFArrayRef?
        guard CGPDFObjectGetValue(object, .array, &array), let array else { return nil }
        var result: [CGPDFObjectRef] = []
        for index in 0..<CGPDFArrayGetCount(array) {
            var child: CGPDFObjectRef?
            guard CGPDFArrayGetObject(array, index, &child), let child else { return nil }
            result.append(child)
        }
        return result
    }

    private static func role(_ dictionary: CGPDFDictionaryRef) -> String? {
        var pointer: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dictionary, "S", &pointer), let pointer else { return nil }
        return String(cString: pointer)
    }

    private static func object(_ dictionary: CGPDFDictionaryRef, key: String) -> CGPDFObjectRef? {
        var result: CGPDFObjectRef?
        let found = key.withCString { CGPDFDictionaryGetObject(dictionary, $0, &result) }
        return found ? result : nil
    }

    private static func inheritedPage(_ element: CGPDFDictionaryRef, document: CGPDFDocument) -> Int? {
        var current: CGPDFDictionaryRef? = element
        var depth = 0
        while let dictionary = current, depth < 32 {
            var page: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(dictionary, "Pg", &page), let page,
               let number = pageNumber(page, document: document) { return number }
            var parent: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(dictionary, "P", &parent), let parent else { break }
            current = parent
            depth += 1
        }
        return nil
    }

    private static func pageNumber(_ dictionary: CGPDFDictionaryRef, document: CGPDFDocument) -> Int? {
        for pageNumber in 1...document.numberOfPages {
            if let page = document.page(at: pageNumber),
               let pageDictionary = page.dictionary,
               pageDictionary == dictionary {
                return pageNumber
            }
        }
        return nil
    }

    private static func propertyMCIDs(on page: CGPDFPage) -> [String: Int] {
        guard let pageDictionary = page.dictionary else { return [:] }
        var resources: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageDictionary, "Resources", &resources), let resources else { return [:] }
        var properties: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "Properties", &properties), let properties else { return [:] }
        var result: [String: Int] = [:]
        CGPDFDictionaryApplyBlock(properties, { key, object, _ in
            var dictionary: CGPDFDictionaryRef?
            guard CGPDFObjectGetValue(object, .dictionary, &dictionary), let dictionary else { return true }
            var mcid: CGPDFInteger = 0
            if CGPDFDictionaryGetInteger(dictionary, "MCID", &mcid) {
                result[String(cString: key)] = Int(mcid)
            }
            return true
        }, nil)
        return result
    }

    private static func scan(page: CGPDFPage) -> ScanState? {
        let state = ScanState(
            fontMaps: TaggedPDFFontMapExtractor.fontMaps(for: page),
            propertyMCIDs: propertyMCIDs(on: page)
        )
        let stream = CGPDFContentStreamCreateWithPage(page)
        guard let table = CGPDFOperatorTableCreate() else { return nil }
        let info = Unmanaged.passUnretained(state).toOpaque()

        CGPDFOperatorTableSetCallback(table, "BDC") { scanner, info in
            guard let info else { return }
            let state = Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
            var mcid: Int?
            var properties: CGPDFDictionaryRef?
            if CGPDFScannerPopDictionary(scanner, &properties), let properties {
                var value: CGPDFInteger = 0
                if CGPDFDictionaryGetInteger(properties, "MCID", &value) { mcid = Int(value) }
            } else {
                var propertyName: UnsafePointer<CChar>?
                if CGPDFScannerPopName(scanner, &propertyName), let propertyName {
                    mcid = state.propertyMCIDs[String(cString: propertyName)]
                }
            }
            var tag: UnsafePointer<CChar>?
            _ = CGPDFScannerPopName(scanner, &tag)
            state.beginMarkedContent(mcid)
        }
        CGPDFOperatorTableSetCallback(table, "BMC") { scanner, info in
            guard let info else { return }
            let state = Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
            var tag: UnsafePointer<CChar>?
            _ = CGPDFScannerPopName(scanner, &tag)
            state.beginMarkedContent(nil)
        }
        CGPDFOperatorTableSetCallback(table, "EMC") { _, info in
            guard let info else { return }
            Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue().endMarkedContent()
        }
        CGPDFOperatorTableSetCallback(table, "Tf") { scanner, info in
            guard let info else { return }
            let state = Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
            var size: CGPDFReal = 0
            var name: UnsafePointer<CChar>?
            guard CGPDFScannerPopNumber(scanner, &size),
                  CGPDFScannerPopName(scanner, &name), let name else {
                state.invalid = true
                return
            }
            state.fontName = String(cString: name)
        }
        CGPDFOperatorTableSetCallback(table, "BT") { _, info in
            guard let info else { return }
            Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue().beginTextBlock()
        }
        CGPDFOperatorTableSetCallback(table, "re") { scanner, info in
            guard let info else { return }
            let state = Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
            for _ in 0..<4 {
                var value: CGPDFReal = 0
                guard CGPDFScannerPopNumber(scanner, &value) else {
                    state.invalid = true
                    return
                }
            }
            state.noteRectangle()
        }
        CGPDFOperatorTableSetCallback(table, "Tj") { scanner, info in
            guard let info else { return }
            let state = Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
            var string: CGPDFStringRef?
            guard CGPDFScannerPopString(scanner, &string), let string else {
                state.invalid = true
                return
            }
            state.append(string)
        }
        CGPDFOperatorTableSetCallback(table, "TJ") { scanner, info in
            guard let info else { return }
            let state = Unmanaged<ScanState>.fromOpaque(info).takeUnretainedValue()
            var array: CGPDFArrayRef?
            guard CGPDFScannerPopArray(scanner, &array), let array else {
                state.invalid = true
                return
            }
            for index in 0..<CGPDFArrayGetCount(array) {
                var item: CGPDFObjectRef?
                guard CGPDFArrayGetObject(array, index, &item), let item else {
                    state.invalid = true
                    return
                }
                var string: CGPDFStringRef?
                if CGPDFObjectGetValue(item, .string, &string), let string {
                    state.append(string)
                    continue
                }
                var real: CGPDFReal = 0
                if CGPDFObjectGetValue(item, .real, &real) {
                    if real < -80 { state.appendSpace() }
                    continue
                }
                var integer: CGPDFInteger = 0
                if CGPDFObjectGetValue(item, .integer, &integer), integer < -80 {
                    state.appendSpace()
                }
            }
        }
        let scanner = CGPDFScannerCreate(stream, table, info)
        guard CGPDFScannerScan(scanner), !state.invalid, state.markedStack.isEmpty else { return nil }
        return state
    }
}

/// Minimal Type-3 font decoding used only while scanning an explicitly tagged
/// PDF table. It is not a competing full-page text representation and cannot
/// replace PDFKit page text or geometry.
private enum TaggedPDFFontMapExtractor {
    private static let maximumFontsPerPage = 128
    private static let maximumMappingsPerFont = 4096
    private static let maximumCMapBytes = 32 * 1024

    fileprivate static func fontMaps(for page: CGPDFPage) -> [String: [UInt8: String]] {
        guard let pageDictionary = page.dictionary else { return [:] }
        var resources: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageDictionary, "Resources", &resources),
              let resources else { return [:] }
        var fonts: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "Font", &fonts),
              let fonts else { return [:] }

        var maps: [String: [UInt8: String]] = [:]
        CGPDFDictionaryApplyBlock(fonts, { key, object, _ in
            guard maps.count < maximumFontsPerPage else { return false }
            var dictionary: CGPDFDictionaryRef?
            guard CGPDFObjectGetValue(object, .dictionary, &dictionary),
                  let dictionary else { return true }
            var stream: CGPDFStreamRef?
            guard CGPDFDictionaryGetStream(dictionary, "ToUnicode", &stream),
                  let stream else { return true }
            var format = CGPDFDataFormat.raw
            guard let data = CGPDFStreamCopyData(stream, &format),
                  CFDataGetLength(data) <= maximumCMapBytes else { return true }
            let map = CMapParser.parse(Data(data as Data))
            guard !map.isEmpty, map.count <= maximumMappingsPerFont else { return true }
            maps[String(cString: key)] = map
            return true
        }, nil)
        return maps.filter { !$0.value.isEmpty }
    }

    private enum CMapParser {
        static func parse(_ data: Data) -> [UInt8: String] {
            let source = String(decoding: data, as: UTF8.self)
            var result: [UInt8: String] = [:]
            var mode: Mode?
            for rawLine in source.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
                let line = rawLine.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false)[0]
                let tokens = tokens(in: line)
                if tokens.contains("beginbfchar") {
                    mode = .character
                    continue
                }
                if tokens.contains("beginbfrange") {
                    mode = .range
                    continue
                }
                if tokens.contains("endbfchar") || tokens.contains("endbfrange") {
                    mode = nil
                    continue
                }
                guard let mode else { continue }
                switch mode {
                case .character:
                    guard tokens.count >= 2,
                          let sourceCode = hex(tokens[0]),
                          let destination = unicode(tokens[1]),
                          let byte = sourceCode.first,
                          sourceCode.count == 1 else { continue }
                    result[byte] = destination
                case .range:
                    guard tokens.count >= 3,
                          let start = hex(tokens[0]),
                          let end = hex(tokens[1]),
                          start.count == 1, end.count == 1,
                          let firstDestination = unicode(tokens[2]),
                          let startByte = start.first,
                          let endByte = end.first,
                          startByte <= endByte else { continue }
                    for offset in 0...Int(endByte - startByte) {
                        let code = startByte + UInt8(offset)
                        if tokens.count > 3 {
                            guard tokens.count > 3 + offset,
                                  let destination = unicode(tokens[3 + offset]) else { continue }
                            result[code] = destination
                        } else if let scalar = firstDestination.unicodeScalars.first,
                                  let next = UnicodeScalar(scalar.value + UInt32(offset)) {
                            result[code] = String(next)
                        }
                    }
                }
            }
            return result
        }

        private enum Mode { case character, range }

        private static func tokens(in line: Substring) -> [Substring] {
            line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                .filter { $0 != "<" && $0 != ">" }
                .flatMap { token in
                    guard token.first == "<", token.last == ">" else { return [token] }
                    return [token.dropFirst().dropLast()]
                }
        }

        private static func hex(_ token: Substring) -> [UInt8]? {
            guard !token.isEmpty, token.count <= 2,
                  let value = UInt8(token, radix: 16) else { return nil }
            return [value]
        }

        private static func unicode(_ token: Substring) -> String? {
            guard !token.isEmpty, token.count.isMultiple(of: 4), token.count <= 8 else { return nil }
            var bytes: [UInt8] = []
            var index = token.startIndex
            while index < token.endIndex {
                let next = token.index(index, offsetBy: 2)
                guard let value = UInt8(token[index..<next], radix: 16) else { return nil }
                bytes.append(value)
                index = next
            }
            return String(data: Data(bytes), encoding: .utf16BigEndian)
        }
    }
}
