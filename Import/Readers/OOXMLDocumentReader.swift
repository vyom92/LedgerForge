// Import/Readers/OOXMLDocumentReader.swift
// Bounded, fail-closed OOXML worksheet reader for XLSX source snapshots.

import Foundation
import ZIPFoundation

/// Reads the deliberately narrow XLSX boundary approved for LedgerForge.
///
/// The reader consumes only the immutable snapshot. ZIPFoundation is used for
/// container access and Foundation XMLParser is used for the XML parts after
/// the ZIP entry and resource ceilings have been checked.
final class OOXMLDocumentReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["xlsx"]

    private static let limits = Limits()

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        guard supportedFileExtensions.contains(request.fileExtension) else {
            throw ImportError.unsupportedFile(extension: request.fileExtension)
        }
        guard password == nil else {
            throw ImportError.unsupportedStatement(
                message: "Password-protected OOXML workbooks are unsupported."
            )
        }

        do {
            let sheet = try snapshot.withBytes { bytes in
                try WorkbookParser(data: bytes, limits: Self.limits).parse()
            }
            return RawDocument(
                sourceURL: request.fileURL,
                fileName: request.fileName,
                fileExtension: request.fileExtension,
                content: .tabular(sheet)
            )
        } catch let error as ReaderFailure {
            switch error {
            case .unsupported(let message):
                throw ImportError.unsupportedStatement(message: message)
            case .invalid(let message):
                throw ImportError.invalidDocument(message: message)
            }
        } catch {
            throw ImportError.invalidDocument(message: "OOXML workbook is malformed or unsupported.")
        }
    }
}

private struct Limits {
    // The approved clean-room workbooks are 8 entries/75,215 uncompressed
    // bytes and 162 rows x 6 columns. These ceilings leave useful room for
    // the same bounded profile without admitting an unbounded ZIP/XML input.
    let maximumEntryCount = 32
    let maximumSourceBytes = 4 * 1024 * 1024
    let maximumTotalUncompressedBytes = 8 * 1024 * 1024
    let maximumPartBytes = 4 * 1024 * 1024
    let maximumRows = 10_000
    let maximumColumns = 256
    let maximumCells = 1_000_000
    let maximumStyles = 1_000
    let maximumSharedStrings = 100_000
    let maximumMergedRanges = 1_000
    let maximumXMLNodes = 250_000
    let maximumXMLDepth = 128
}

private enum ReaderFailure: Error {
    case invalid(String)
    case unsupported(String)
}

private final class XMLNode {
    let name: String
    let attributes: [String: String]
    var children: [XMLNode] = []
    var text = ""

    init(name: String, attributes: [String: String]) {
        self.name = Self.localName(name)
        self.attributes = attributes.reduce(into: [:]) { result, pair in
            result[Self.localName(pair.key)] = pair.value
        }
    }

    var allText: String {
        text + children.map(\.allText).joined()
    }

    func children(named name: String) -> [XMLNode] {
        children.filter { $0.name == name }
    }

    func child(named name: String) -> XMLNode? {
        children.first { $0.name == name }
    }

    func hasDescendant(named name: String) -> Bool {
        children.contains { $0.name == name || $0.hasDescendant(named: name) }
    }

    private static func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }
}

private final class XMLDocumentParser: NSObject, XMLParserDelegate {
    private let limits: Limits
    private var stack: [XMLNode] = []
    private(set) var root: XMLNode?
    private var nodeCount = 0
    private var failed = false

    init(limits: Limits) {
        self.limits = limits
    }

    func parse(_ data: Data) throws -> XMLNode {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), !failed, let root else {
            throw ReaderFailure.invalid("OOXML XML part is malformed.")
        }
        return root
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        guard !failed else { return }
        nodeCount += 1
        guard nodeCount <= limits.maximumXMLNodes,
              stack.count < limits.maximumXMLDepth else {
            failed = true
            parser.abortParsing()
            return
        }
        let node = XMLNode(name: elementName, attributes: attributeDict)
        if let parent = stack.last {
            parent.children.append(node)
        } else if root == nil {
            root = node
        } else {
            failed = true
            parser.abortParsing()
            return
        }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard !failed, !stack.isEmpty else { return }
        stack.removeLast()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text.append(string)
    }

    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespace: String) {
        stack.last?.text.append(whitespace)
    }

    func parser(_ parser: XMLParser, foundExternalEntityWithSystemID systemID: String?,
                publicID: String?) {
        failed = true
        parser.abortParsing()
    }

    func parser(_ parser: XMLParser, foundSkippedEntity name: String) {
        failed = true
        parser.abortParsing()
    }

    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String,
                value: String?) {
        failed = true
        parser.abortParsing()
    }
}

private struct PackageReader {
    let archive: Archive
    let entries: [String: Entry]
    let limits: Limits

    init(data: Data, limits: Limits) throws {
        self.limits = limits
        guard data.count <= limits.maximumSourceBytes else {
            throw ReaderFailure.invalid("OOXML source exceeds supported resource limits.")
        }

        do {
            archive = try Archive(data: data, accessMode: .read)
        } catch {
            throw ReaderFailure.invalid("OOXML ZIP container is malformed or unsupported.")
        }

        var mapped: [String: Entry] = [:]
        var totalUncompressed: UInt64 = 0
        var entryCount = 0
        for entry in archive {
            entryCount += 1
            guard entryCount <= limits.maximumEntryCount else {
                throw ReaderFailure.invalid("OOXML ZIP contains too many entries.")
            }

            let path = entry.path
            switch entry.type {
            case .directory:
                let directoryPath = path.hasSuffix("/") ? String(path.dropLast()) : path
                guard Self.isSafePath(directoryPath) else {
                    throw ReaderFailure.invalid("OOXML ZIP entry path is unsafe.")
                }
                continue

            case .symlink:
                throw ReaderFailure.invalid("OOXML ZIP symbolic links are unsupported.")

            case .file:
                guard Self.isSafePath(path) else {
                    throw ReaderFailure.invalid("OOXML ZIP entry path is unsafe.")
                }
            }

            guard mapped[path] == nil else {
                throw ReaderFailure.invalid("OOXML ZIP contains duplicate entries.")
            }
            guard entry.uncompressedSize <= UInt64(limits.maximumPartBytes) else {
                throw ReaderFailure.invalid("OOXML ZIP entry exceeds supported resource limits.")
            }
            mapped[path] = entry
            let (newTotal, overflow) = totalUncompressed.addingReportingOverflow(entry.uncompressedSize)
            guard !overflow, newTotal <= UInt64(limits.maximumTotalUncompressedBytes) else {
                throw ReaderFailure.invalid("OOXML ZIP exceeds supported resource limits.")
            }
            totalUncompressed = newTotal
        }
        entries = mapped
    }

    func data(for path: String) throws -> Data {
        guard let entry = entries[path] else {
            throw ReaderFailure.invalid("OOXML package is missing a required part.")
        }
        guard entry.uncompressedSize <= UInt64(limits.maximumPartBytes) else {
            throw ReaderFailure.invalid("OOXML part exceeds supported resource limits.")
        }
        var output = Data()
        output.reserveCapacity(Int(entry.uncompressedSize))
        do {
            _ = try archive.extract(entry, skipCRC32: false) { chunk in
                output.append(chunk)
                guard output.count <= limits.maximumPartBytes else {
                    throw ReaderFailure.invalid("OOXML part exceeds supported resource limits.")
                }
            }
        } catch let failure as ReaderFailure {
            throw failure
        } catch {
            throw ReaderFailure.invalid("OOXML ZIP entry could not be extracted.")
        }
        return output
    }

    private static func isSafePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasPrefix("\\"),
              !path.contains("\\"),
              !path.contains(":") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return !components.contains { $0.isEmpty || $0 == "." || $0 == ".." }
    }
}

private struct WorkbookParser {
    let data: Data
    let limits: Limits

    func parse() throws -> RawTabularSheet {
        let package = try PackageReader(data: data, limits: limits)
        try validateSupportedPackage(package)

        let contentTypes = try XMLDocumentParser(limits: limits).parse(
            package.data(for: "[Content_Types].xml")
        )
        let contentTypeMap = try parseContentTypes(contentTypes, package: package)
        let rootRelationships = try parseRelationships(
            XMLDocumentParser(limits: limits).parse(package.data(for: "_rels/.rels")),
            package: package,
            basePath: "",
            allowedKinds: ["officeDocument", "coreProperties", "extendedProperties"]
        )
        guard rootRelationships.byKind["officeDocument"] == "xl/workbook.xml" else {
            throw ReaderFailure.unsupported("OOXML package has no supported workbook relationship.")
        }

        if let corePropertiesPath = rootRelationships.byKind["coreProperties"] {
            guard corePropertiesPath == "docProps/core.xml",
                  contentTypeMap[corePropertiesPath] == .coreProperties else {
                throw ReaderFailure.unsupported(
                    "OOXML core-properties relationship is unsupported."
                )
            }
            try validateCoreProperties(
                XMLDocumentParser(limits: limits).parse(package.data(for: corePropertiesPath))
            )
        } else if package.entries["docProps/core.xml"] != nil {
            throw ReaderFailure.invalid(
                "OOXML core-properties part has no package relationship."
            )
        }

        // Excel emits this inert package-metadata part in the approved Axis
        // workbooks. Recognize its exact relationship/content-type surface,
        // but do not let it influence worksheet or financial semantics.
        if let extendedPropertiesPath = rootRelationships.byKind["extendedProperties"] {
            guard extendedPropertiesPath == "docProps/app.xml",
                  contentTypeMap[extendedPropertiesPath] == .extendedProperties else {
                throw ReaderFailure.unsupported(
                    "OOXML extended-properties relationship is unsupported."
                )
            }
            try validateExtendedProperties(
                XMLDocumentParser(limits: limits).parse(package.data(for: extendedPropertiesPath))
            )
        } else if package.entries["docProps/app.xml"] != nil {
            throw ReaderFailure.invalid(
                "OOXML extended-properties part has no package relationship."
            )
        }

        let workbook = try XMLDocumentParser(limits: limits).parse(
            package.data(for: "xl/workbook.xml")
        )
        guard workbook.name == "workbook" else {
            throw ReaderFailure.invalid("OOXML workbook part is malformed.")
        }
        let unsupportedWorkbookFeatures: Set<String> = [
            "definedNames", "externalReferences", "connections", "pivotCaches",
            "customWorkbookViews", "extLst"
        ]
        guard !workbook.children.contains(where: {
            unsupportedWorkbookFeatures.contains($0.name)
        }) else {
            throw ReaderFailure.unsupported("OOXML workbook feature is unsupported.")
        }
        let workbookRelationships = try parseRelationships(
            XMLDocumentParser(limits: limits).parse(package.data(for: "xl/_rels/workbook.xml.rels")),
            package: package,
            basePath: "xl",
            allowedKinds: ["worksheet", "styles", "sharedStrings", "theme"]
        )
        let sheets = try parseWorkbookSheet(workbook, relationships: workbookRelationships)
        guard sheets.count == 1 else {
            throw ReaderFailure.unsupported("OOXML workbooks must contain exactly one worksheet.")
        }
        let worksheetPath = sheets[0].path
        guard contentTypeMap[worksheetPath] == ContentType.worksheet else {
            throw ReaderFailure.unsupported("OOXML worksheet content type is unsupported.")
        }

        let styles: StyleTable
        if let stylesPath = workbookRelationships.byKind["styles"] {
            guard contentTypeMap[stylesPath] == ContentType.styles else {
                throw ReaderFailure.unsupported("OOXML styles content type is unsupported.")
            }
            styles = try parseStyles(
                XMLDocumentParser(limits: limits).parse(package.data(for: stylesPath))
            )
        } else {
            styles = StyleTable(formats: [])
        }

        let sharedStrings: [String]
        if let sharedStringsPath = workbookRelationships.byKind["sharedStrings"] {
            guard contentTypeMap[sharedStringsPath] == ContentType.sharedStrings else {
                throw ReaderFailure.unsupported("OOXML shared-strings content type is unsupported.")
            }
            sharedStrings = try parseSharedStrings(
                XMLDocumentParser(limits: limits).parse(package.data(for: sharedStringsPath))
            )
        } else {
            sharedStrings = []
        }

        let worksheet = try XMLDocumentParser(limits: limits).parse(
            package.data(for: worksheetPath)
        )
        try validateAncillaryPackage(
            package,
            contentTypeMap: contentTypeMap,
            worksheetPath: worksheetPath,
            worksheet: worksheet
        )

        return try parseWorksheet(
            worksheet,
            sheetName: sheets[0].name,
            styles: styles,
            sharedStrings: sharedStrings
        )
    }

    /// Metadata parts are authenticated by relationship/content type, then
    /// parsed and restricted to the inert property shapes emitted by Excel.
    /// Their values never influence worksheet or financial semantics.
    private func validateCoreProperties(_ root: XMLNode) throws {
        guard xmlLocalName(root.name) == "coreProperties",
              root.children.allSatisfy({ child in
                  Self.corePropertyNames.contains(xmlLocalName(child.name)) && child.children.isEmpty
              }) else {
            throw ReaderFailure.unsupported("OOXML core-properties part is unsupported.")
        }
    }

    private func validateExtendedProperties(_ root: XMLNode) throws {
        guard xmlLocalName(root.name) == "Properties" else {
            throw ReaderFailure.unsupported("OOXML extended-properties part is unsupported.")
        }
        for property in root.children {
            switch xmlLocalName(property.name) {
            case "Application", "AppVersion", "Company", "DocSecurity",
                 "HyperlinksChanged", "LinksUpToDate", "Manager",
                 "ScaleCrop", "SharedDoc":
                guard property.children.isEmpty else {
                    throw ReaderFailure.unsupported(
                        "OOXML extended-properties part is unsupported."
                    )
                }
            case "HeadingPairs", "TitlesOfParts":
                try validateExtendedPropertyVector(property)
            default:
                throw ReaderFailure.unsupported("OOXML extended-properties part is unsupported.")
            }
        }
    }

    private func validateExtendedPropertyVector(_ property: XMLNode) throws {
        guard property.children.count == 1,
              xmlLocalName(property.children[0].name) == "vector",
              !property.children[0].children.isEmpty else {
            throw ReaderFailure.unsupported("OOXML extended-properties part is unsupported.")
        }
        let vector = property.children[0]
        let baseType = xmlLocalName(vector.attributes["baseType"] ?? "")
        let declaredSize = vector.attributes["size"].flatMap(Int.init)
        guard Set(vector.attributes.keys) == ["baseType", "size"],
              declaredSize == vector.children.count else {
            throw ReaderFailure.unsupported("OOXML extended-properties part is unsupported.")
        }
        switch baseType {
        case "variant":
            for variant in vector.children {
                guard xmlLocalName(variant.name) == "variant",
                      !variant.children.isEmpty,
                  variant.children.allSatisfy({ item in
                      let name = xmlLocalName(item.name)
                      return (name == "lpstr" || name == "i4") && item.children.isEmpty
                  }) else {
                throw ReaderFailure.unsupported(
                    "OOXML extended-properties part is unsupported."
                )
            }
            }
        case "lpstr", "i4":
            guard vector.children.allSatisfy({ item in
                xmlLocalName(item.name) == baseType && item.children.isEmpty
            }) else {
                throw ReaderFailure.unsupported(
                    "OOXML extended-properties part is unsupported."
                )
            }
        default:
            throw ReaderFailure.unsupported("OOXML extended-properties part is unsupported.")
        }
    }

    private func xmlLocalName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    private func validateSupportedPackage(_ package: PackageReader) throws {
        let allowedExact: Set<String> = [
            "[Content_Types].xml",
            "_rels/.rels",
            "xl/workbook.xml",
            "xl/_rels/workbook.xml.rels"
        ]
        for path in package.entries.keys {
            let allowed = allowedExact.contains(path)
                || path == "xl/styles.xml"
                || path == "xl/sharedStrings.xml"
                || path == "docProps/core.xml"
                || path == "docProps/app.xml"
                || path.hasPrefix("xl/theme/")
                || (path.hasPrefix("xl/worksheets/") && path.hasSuffix(".xml"))
                || (path.hasPrefix("xl/worksheets/_rels/") && path.hasSuffix(".rels"))
                || (path.hasPrefix("xl/drawings/") && path.hasSuffix(".xml"))
                || (path.hasPrefix("xl/drawings/_rels/") && path.hasSuffix(".rels"))
                || (path.hasPrefix("xl/media/") && path.hasSuffix(".png"))
            guard allowed else {
                if path.contains("vba") || path.hasSuffix(".bin") {
                    throw ReaderFailure.unsupported("Macro-enabled OOXML workbooks are unsupported.")
                }
                if path.contains("external") {
                    throw ReaderFailure.unsupported("OOXML external links are unsupported.")
                }
                throw ReaderFailure.unsupported("OOXML package part is unsupported.")
            }
        }
    }

    private func validateAncillaryPackage(
        _ package: PackageReader,
        contentTypeMap: [String: ContentType],
        worksheetPath: String,
        worksheet: XMLNode
    ) throws {
        let drawingPaths = contentTypeMap.compactMap { path, type in
            type == .drawing ? path : nil
        }.sorted()

        let imagePaths = contentTypeMap.compactMap { path, type in
            type == .png ? path : nil
        }.sorted()

        let worksheetRelationshipPaths = Set(
            package.entries.keys.filter {
                $0.hasPrefix("xl/worksheets/_rels/") && $0.hasSuffix(".rels")
            }
        )

        let drawingRelationshipPaths = Set(
            package.entries.keys.filter {
                $0.hasPrefix("xl/drawings/_rels/") && $0.hasSuffix(".rels")
            }
        )

        let drawingNodes = worksheet.children(named: "drawing")

        let hasDrawingSurface =
            !drawingPaths.isEmpty
            || !imagePaths.isEmpty
            || !worksheetRelationshipPaths.isEmpty
            || !drawingRelationshipPaths.isEmpty
            || !drawingNodes.isEmpty

        guard hasDrawingSurface else {
            return
        }

        // Sprint 78's approved XLSX family proves exactly one embedded logo.
        // The image/drawing payload is inert: it never becomes tabular or
        // financial evidence.
        guard drawingPaths.count == 1,
              imagePaths.count == 1,
              drawingNodes.count == 1 else {
            throw ReaderFailure.unsupported(
                "OOXML ancillary drawing structure is unsupported."
            )
        }

        let worksheetRelationshipsPath = relationshipPartPath(for: worksheetPath)
        guard worksheetRelationshipPaths == Set([worksheetRelationshipsPath]),
              contentTypeMap[worksheetRelationshipsPath] == .relationships else {
            throw ReaderFailure.unsupported(
                "OOXML worksheet relationship structure is unsupported."
            )
        }

        let drawingPath = drawingPaths[0]
        let imagePath = imagePaths[0]

        guard contentTypeMap[drawingPath] == .drawing,
              contentTypeMap[imagePath] == .png else {
            throw ReaderFailure.unsupported(
                "OOXML ancillary content type is unsupported."
            )
        }

        let worksheetRelationships = try parseRelationships(
            XMLDocumentParser(limits: limits).parse(
                package.data(for: worksheetRelationshipsPath)
            ),
            package: package,
            basePath: directoryPath(of: worksheetPath),
            allowedKinds: ["drawing"]
        )

        guard let drawingRelationshipID = drawingNodes[0].attributes["id"],
              worksheetRelationships.byID[drawingRelationshipID] == drawingPath,
              worksheetRelationships.byKind["drawing"] == drawingPath else {
            throw ReaderFailure.invalid(
                "OOXML worksheet drawing relationship is inconsistent."
            )
        }

        let drawingRelationshipsPath = relationshipPartPath(for: drawingPath)
        guard drawingRelationshipPaths == Set([drawingRelationshipsPath]),
              contentTypeMap[drawingRelationshipsPath] == .relationships else {
            throw ReaderFailure.unsupported(
                "OOXML drawing relationship structure is unsupported."
            )
        }

        let drawingRelationships = try parseRelationships(
            XMLDocumentParser(limits: limits).parse(
                package.data(for: drawingRelationshipsPath)
            ),
            package: package,
            basePath: directoryPath(of: drawingPath),
            allowedKinds: ["image"]
        )

        guard drawingRelationships.byKind["image"] == imagePath else {
            throw ReaderFailure.invalid(
                "OOXML drawing image relationship is inconsistent."
            )
        }
    }

    private func parseContentTypes(_ root: XMLNode, package: PackageReader) throws -> [String: ContentType] {
        guard root.name == "Types" else {
            throw ReaderFailure.invalid("OOXML content-types part is malformed.")
        }
        var defaults: [String: ContentType] = [:]
        var overrides: [String: ContentType] = [:]
        for node in root.children {
            switch node.name {
            case "Default":
                guard let ext = node.attributes["Extension"],
                      let type = ContentType(rawValue: node.attributes["ContentType"] ?? "") else {
                    throw ReaderFailure.unsupported("OOXML content type is unsupported.")
                }
                guard defaults[ext] == nil else {
                    throw ReaderFailure.invalid("OOXML content types contain duplicates.")
                }
                defaults[ext] = type
            case "Override":
                guard let partName = node.attributes["PartName"],
                      let type = ContentType(rawValue: node.attributes["ContentType"] ?? ""),
                      let path = normalizePartName(partName) else {
                    throw ReaderFailure.unsupported("OOXML content type is unsupported.")
                }
                guard overrides[path] == nil else {
                    throw ReaderFailure.invalid("OOXML content types contain duplicates.")
                }
                overrides[path] = type
            default:
                throw ReaderFailure.unsupported("OOXML content type element is unsupported.")
            }
        }

        var result: [String: ContentType] = [:]
        for path in package.entries.keys {
            if path == "[Content_Types].xml" {
                continue
            }
            let extensionName = path.split(separator: ".").last.map(String.init) ?? ""
            guard let type = overrides[path] ?? defaults[extensionName] else {
                throw ReaderFailure.unsupported("OOXML package part has no supported content type.")
            }
            guard type.isAllowed(for: path) else {
                throw ReaderFailure.unsupported("OOXML package content type is unsupported.")
            }
            result[path] = type
        }
        return result
    }

    private func parseRelationships(
        _ root: XMLNode,
        package: PackageReader,
        basePath: String,
        allowedKinds: Set<String>
    ) throws -> RelationshipTable {
        guard root.name == "Relationships" else {
            throw ReaderFailure.invalid("OOXML relationships part is malformed.")
        }
        var byID: [String: String] = [:]
        var byKind: [String: String] = [:]
        for relationship in root.children {
            guard relationship.name == "Relationship",
                  let id = relationship.attributes["Id"],
                  let type = relationship.attributes["Type"],
                  let target = relationship.attributes["Target"],
                  relationship.attributes["TargetMode"] == nil else {
                throw ReaderFailure.unsupported("OOXML relationship is unsupported.")
            }
            guard byID[id] == nil else {
                throw ReaderFailure.invalid("OOXML relationships contain duplicate IDs.")
            }
            let kind: String
            if type.hasSuffix("/officeDocument") {
                kind = "officeDocument"
            } else if type.hasSuffix("/worksheet") {
                kind = "worksheet"
            } else if type.hasSuffix("/styles") {
                kind = "styles"
            } else if type.hasSuffix("/sharedStrings") {
                kind = "sharedStrings"
            } else if type.hasSuffix("/theme") {
                kind = "theme"
            } else if type.hasSuffix("/core-properties") {
                kind = "coreProperties"
            } else if type.hasSuffix("/extended-properties") {
                kind = "extendedProperties"
            } else if type.hasSuffix("/drawing") {
                kind = "drawing"
            } else if type.hasSuffix("/image") {
                kind = "image"
            } else if type.contains("externalLink") {
                throw ReaderFailure.unsupported("OOXML external links are unsupported.")
            } else {
                throw ReaderFailure.unsupported("OOXML relationship type is unsupported.")
            }

            guard allowedKinds.contains(kind) else {
                throw ReaderFailure.unsupported(
                    "OOXML relationship is unsupported in this package context."
                )
            }

            let resolved = try resolveTarget(target, relativeTo: basePath)
            guard package.entries[resolved] != nil else {
                throw ReaderFailure.invalid("OOXML relationship target is missing.")
            }
            guard byKind[kind] == nil else {
                throw ReaderFailure.invalid("OOXML relationships contain duplicate required parts.")
            }
            byID[id] = resolved
            byKind[kind] = resolved
        }
        return RelationshipTable(byID: byID, byKind: byKind)
    }

    private func parseWorkbookSheet(_ workbook: XMLNode,
                                    relationships: RelationshipTable) throws -> [SheetDescriptor] {
        guard let sheetsNode = workbook.child(named: "sheets") else {
            throw ReaderFailure.invalid("OOXML workbook has no sheets.")
        }
        let sheetNodes = sheetsNode.children(named: "sheet")
        guard !sheetNodes.isEmpty else {
            throw ReaderFailure.invalid("OOXML workbook has no sheets.")
        }
        var result: [SheetDescriptor] = []
        for sheet in sheetNodes {
            guard let name = sheet.attributes["name"], !name.isEmpty,
                  let relationshipID = sheet.attributes["id"],
                  relationshipID.isEmpty == false,
                  sheet.attributes["state"] == nil || sheet.attributes["state"] == "visible" else {
                throw ReaderFailure.unsupported("Hidden or malformed OOXML worksheets are unsupported.")
            }
            // The workbook relationship table is deliberately one-worksheet
            // only; the relationship ID is checked against its source XML.
            guard let path = relationships.byID[relationshipID] else {
                throw ReaderFailure.invalid("OOXML worksheet relationship is missing.")
            }
            result.append(SheetDescriptor(name: name, path: path))
        }
        return result
    }

    private func parseSharedStrings(_ root: XMLNode) throws -> [String] {
        guard root.name == "sst" else {
            throw ReaderFailure.invalid("OOXML shared-strings part is malformed.")
        }
        let strings = root.children(named: "si")
        guard strings.count <= limits.maximumSharedStrings else {
            throw ReaderFailure.invalid("OOXML shared strings exceed supported resource limits.")
        }
        if let declared = root.attributes["uniqueCount"].flatMap(Int.init), declared != strings.count {
            throw ReaderFailure.invalid("OOXML shared-strings count is inconsistent.")
        }
        return try strings.map { item in
            guard item.children.allSatisfy({ $0.name == "t" || $0.name == "r" }),
                  !item.hasDescendant(named: "phoneticPr") else {
                throw ReaderFailure.unsupported("OOXML shared-string feature is unsupported.")
            }
            let textNodes = item.children.flatMap { child -> [XMLNode] in
                child.name == "t" ? [child] : child.children(named: "t")
            }
            return textNodes.map(\.allText).joined()
        }
    }

    private func parseStyles(_ root: XMLNode) throws -> StyleTable {
        guard root.name == "styleSheet" else {
            throw ReaderFailure.invalid("OOXML styles part is malformed.")
        }
        var customFormats: [Int: String] = [:]
        if let numFmts = root.child(named: "numFmts") {
            for numFmt in numFmts.children {
                guard numFmt.name == "numFmt",
                      let id = numFmt.attributes["numFmtId"].flatMap(Int.init),
                      let code = numFmt.attributes["formatCode"], !code.isEmpty,
                      customFormats[id] == nil else {
                    throw ReaderFailure.invalid("OOXML number-format table is malformed.")
                }
                customFormats[id] = code
            }
        }
        guard customFormats.count <= limits.maximumStyles else {
            throw ReaderFailure.invalid("OOXML styles exceed supported resource limits.")
        }
        guard let cellXfs = root.child(named: "cellXfs") else {
            return StyleTable(formats: [])
        }
        let xfs = cellXfs.children(named: "xf")
        guard xfs.count <= limits.maximumStyles else {
            throw ReaderFailure.invalid("OOXML styles exceed supported resource limits.")
        }
        let formats = try xfs.map { xf -> String in
            let id: Int
            if let rawID = xf.attributes["numFmtId"] {
                guard let parsedID = Int(rawID), parsedID >= 0 else {
                    throw ReaderFailure.invalid("OOXML cell style is malformed.")
                }
                id = parsedID
            } else {
                id = 0
            }

            guard let code = customFormats[id] ?? Self.builtInNumberFormats[id] else {
                throw ReaderFailure.unsupported("OOXML number format is unsupported.")
            }
            return code
        }
        return StyleTable(formats: formats)
    }

    private func parseWorksheet(_ root: XMLNode, sheetName: String,
                                styles: StyleTable, sharedStrings: [String]) throws -> RawTabularSheet {
        guard root.name == "worksheet",
              let sheetData = root.child(named: "sheetData"),
              root.children.filter({ $0.name == "sheetData" }).count == 1 else {
            throw ReaderFailure.invalid("OOXML worksheet part is malformed.")
        }

        try validateColumns(root)
        let rows = try parseRows(sheetData, styles: styles, sharedStrings: sharedStrings)
        guard !rows.isEmpty else {
            throw ReaderFailure.invalid("OOXML worksheet is empty.")
        }
        let mergedRanges = try parseMergedRanges(root)
        let maximumColumn = max(
            rows.flatMap { $0.cells.map(\.sourceColumn) }.max() ?? 0,
            mergedRanges.map(\.endColumn).max() ?? 0
        )
        guard maximumColumn > 0 else {
            throw ReaderFailure.invalid("OOXML worksheet has no cells.")
        }
        return RawTabularSheet(
            name: sheetName,
            visibility: .visible,
            columnCount: maximumColumn,
            rows: rows,
            mergedRanges: mergedRanges
        )
    }

    private func validateColumns(_ root: XMLNode) throws {
        guard let cols = root.child(named: "cols") else { return }
        for col in cols.children {
            guard col.name == "col",
                  let min = col.attributes["min"].flatMap(Int.init),
                  let max = col.attributes["max"].flatMap(Int.init),
                  min > 0, max >= min, max <= limits.maximumColumns,
                  !isTrue(col.attributes["hidden"]) else {
                throw ReaderFailure.unsupported("Hidden or malformed OOXML columns are unsupported.")
            }
        }
    }

    private func parseRows(_ sheetData: XMLNode, styles: StyleTable,
                           sharedStrings: [String]) throws -> [RawTabularRow] {
        var rows: [RawTabularRow] = []
        var previousRow = 0
        var cellCount = 0
        for rowNode in sheetData.children {
            guard rowNode.name == "row",
                  let rowNumber = rowNode.attributes["r"].flatMap(Int.init),
                  rowNumber > previousRow, rowNumber <= limits.maximumRows,
                  !isTrue(rowNode.attributes["hidden"]) else {
                throw ReaderFailure.unsupported("Hidden or reordered OOXML rows are unsupported.")
            }
            previousRow = rowNumber
            var cells: [RawTabularCell] = []
            var previousColumn = 0
            for cellNode in rowNode.children {
                guard cellNode.name == "c",
                      let reference = cellNode.attributes["r"],
                      let coordinate = parseCellReference(reference),
                      coordinate.row == rowNumber,
                      coordinate.column > previousColumn,
                      coordinate.column <= limits.maximumColumns else {
                    throw ReaderFailure.unsupported("OOXML cells are missing, duplicated or reordered.")
                }
                previousColumn = coordinate.column
                cellCount += 1
                guard cellCount <= limits.maximumCells else {
                    throw ReaderFailure.invalid("OOXML worksheet exceeds supported resource limits.")
                }
                if cellNode.hasDescendant(named: "f") {
                    throw ReaderFailure.unsupported("Formula cells are unsupported in OOXML imports.")
                }
                let value = try parseCellValue(cellNode, sharedStrings: sharedStrings)
                let styleIndex: Int?
                if let rawStyle = cellNode.attributes["s"] {
                    guard let parsed = Int(rawStyle), parsed >= 0, parsed < styles.formats.count else {
                        throw ReaderFailure.invalid("OOXML cell style index is invalid.")
                    }
                    styleIndex = parsed
                } else if styles.formats.isEmpty {
                    styleIndex = nil
                } else {
                    styleIndex = 0
                }
                cells.append(RawTabularCell(
                    sourceRow: coordinate.row,
                    sourceColumn: coordinate.column,
                    value: value,
                    styleIndex: styleIndex,
                    numberFormatCode: styleIndex.map { styles.formats[$0] }
                ))
            }
            rows.append(RawTabularRow(sourceRow: rowNumber, cells: cells))
        }
        return rows
    }

    private func parseCellValue(_ cell: XMLNode, sharedStrings: [String]) throws -> RawTabularCellValue {
        let type = cell.attributes["t"]
        let values = cell.children(named: "v")
        let inlineStrings = cell.children(named: "is")
        guard values.count <= 1, inlineStrings.count <= 1 else {
            throw ReaderFailure.invalid("OOXML cell value is malformed.")
        }
        guard cell.children.allSatisfy({ $0.name == "v" || $0.name == "is" || $0.name == "f" }) else {
            throw ReaderFailure.unsupported("OOXML cell feature is unsupported.")
        }
        if type == "b" || type == "e" || type == "err" || type == "d" {
            throw ReaderFailure.unsupported("Boolean, error and date cells are unsupported in OOXML imports.")
        }
        if type == "inlineStr" {
            guard values.isEmpty, let inline = inlineStrings.first else {
                throw ReaderFailure.invalid("OOXML inline string cell is malformed.")
            }
            return .string(try parseInlineString(inline))
        }
        guard inlineStrings.isEmpty else {
            throw ReaderFailure.invalid("OOXML cell string representation is malformed.")
        }
        guard let valueNode = values.first else { return .blank }
        let value = valueNode.allText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type {
        case "s":
            guard let index = Int(value), index >= 0, index < sharedStrings.count else {
                throw ReaderFailure.invalid("OOXML shared-string index is invalid.")
            }
            return .string(sharedStrings[index])
        case nil, "n":
            guard let number = Double(value), number.isFinite, !value.isEmpty else {
                throw ReaderFailure.invalid("OOXML numeric cell is malformed.")
            }
            return .number(value)
        case "str":
            return .string(value)
        default:
            throw ReaderFailure.unsupported("Boolean, error and unsupported cells are unsupported in OOXML imports.")
        }
    }

    private func parseInlineString(_ node: XMLNode) throws -> String {
        guard node.children.allSatisfy({ $0.name == "t" || $0.name == "r" }) else {
            throw ReaderFailure.unsupported("OOXML inline-string feature is unsupported.")
        }
        let textNodes = node.children.flatMap { child -> [XMLNode] in
            child.name == "t" ? [child] : child.children(named: "t")
        }
        return textNodes.map(\.allText).joined()
    }

    private func parseMergedRanges(_ root: XMLNode) throws -> [RawTabularMergedRange] {
        guard let mergeCells = root.child(named: "mergeCells") else { return [] }
        let nodes = mergeCells.children(named: "mergeCell")
        guard nodes.count <= limits.maximumMergedRanges else {
            throw ReaderFailure.invalid("OOXML merged ranges exceed supported resource limits.")
        }
        var ranges: [RawTabularMergedRange] = []
        var seen: Set<String> = []
        for node in nodes {
            guard let reference = node.attributes["ref"],
                  let range = parseRange(reference),
                  range.startRow == range.endRow,
                  range.startColumn < range.endColumn,
                  range.endColumn <= limits.maximumColumns,
                  Self.approvedMergeShapes.contains("\(range.startColumn)-\(range.endColumn)"),
                  seen.insert(reference.uppercased()).inserted else {
                throw ReaderFailure.unsupported("OOXML merged range shape is unsupported.")
            }
            if ranges.contains(where: {
                $0.startRow == range.startRow
                    && range.startColumn <= $0.endColumn
                    && $0.startColumn <= range.endColumn
            }) {
                throw ReaderFailure.invalid("OOXML merged ranges overlap.")
            }
            ranges.append(RawTabularMergedRange(
                reference: reference,
                startRow: range.startRow,
                startColumn: range.startColumn,
                endRow: range.endRow,
                endColumn: range.endColumn
            ))
        }
        return ranges
    }

    private func parseCellReference(_ value: String) -> (row: Int, column: Int)? {
        guard let range = parseRange(value) else { return nil }
        guard range.startRow == range.endRow, range.startColumn == range.endColumn else { return nil }
        return (range.startRow, range.startColumn)
    }

    private func parseRange(_ value: String) -> (startRow: Int, startColumn: Int,
                                                   endRow: Int, endColumn: Int)? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2,
              let first = parseCell(parts[0]) else { return nil }
        let last = parts.count == 2 ? parseCell(parts[1]) : first
        guard let last, first.row > 0, first.column > 0,
              last.row >= first.row, last.column >= first.column else { return nil }
        return (first.row, first.column, last.row, last.column)
    }

    private func parseCell(_ value: Substring) -> (row: Int, column: Int)? {
        let scalars = Array(value.utf8)
        var index = 0
        var column = 0
        while index < scalars.count {
            let byte = scalars[index]
            guard byte >= 65 && byte <= 90 || byte >= 97 && byte <= 122 else { break }
            let upper = byte >= 97 ? byte - 32 : byte
            column = column.multipliedReportingOverflow(by: 26).partialValue
                + Int(upper - 64)
            guard column <= limits.maximumColumns else { return nil }
            index += 1
        }
        guard index > 0, index < scalars.count else { return nil }
        let rowText = String(decoding: scalars[index...], as: UTF8.self)
        guard rowText.allSatisfy(\.isNumber), let row = Int(rowText), row > 0 else { return nil }
        return (row, column)
    }

    private func resolveTarget(_ target: String, relativeTo basePath: String) throws -> String {
        let candidate: String
        if target.hasPrefix("/") {
            candidate = String(target.dropFirst())
        } else if basePath.isEmpty {
            candidate = target
        } else {
            candidate = basePath + "/" + target
        }

        guard let path = normalizeRelationshipTarget(candidate) else {
            throw ReaderFailure.invalid("OOXML relationship target is unsafe.")
        }
        return path
    }

    private func normalizeRelationshipTarget(_ value: String) -> String? {
        guard !value.isEmpty,
              !value.contains("\\"),
              !value.contains(":"),
              !value.contains("?"),
              !value.contains("#") else {
            return nil
        }

        var resolved: [Substring] = []
        for component in value.split(
            separator: "/",
            omittingEmptySubsequences: false
        ) {
            guard !component.isEmpty else {
                return nil
            }

            if component == "." {
                return nil
            }

            if component == ".." {
                guard !resolved.isEmpty else {
                    return nil
                }
                resolved.removeLast()
                continue
            }

            resolved.append(component)
        }

        guard !resolved.isEmpty else {
            return nil
        }

        return resolved.map(String.init).joined(separator: "/")
    }

    private func relationshipPartPath(for partPath: String) -> String {
        let components = partPath.split(separator: "/")
        precondition(!components.isEmpty)

        let fileName = String(components.last!)
        let directory = components.dropLast().map(String.init).joined(separator: "/")

        if directory.isEmpty {
            return "_rels/\(fileName).rels"
        }
        return "\(directory)/_rels/\(fileName).rels"
    }

    private func directoryPath(of partPath: String) -> String {
        partPath.split(separator: "/")
            .dropLast()
            .map(String.init)
            .joined(separator: "/")
    }

    private func normalizePartName(_ value: String) -> String? {
        let withoutSlash = value.hasPrefix("/") ? String(value.dropFirst()) : value
        let parts = withoutSlash.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty, !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            return nil
        }
        return parts.joined(separator: "/")
    }

    private func isTrue(_ value: String?) -> Bool {
        value == "1" || value?.lowercased() == "true"
    }

    private static let approvedMergeShapes: Set<String> = [
        "1-2", "1-3", "1-6", "2-3", "3-4", "4-6", "5-6"
    ]

    private static let corePropertyNames: Set<String> = [
        "category", "contentStatus", "created", "creator", "description",
        "identifier", "keywords", "language", "lastModifiedBy",
        "lastPrinted", "modified", "revision", "subject", "title", "version"
    ]

    private static let builtInNumberFormats: [Int: String] = [
        0: "General", 1: "0", 2: "0.00", 3: "#,##0", 4: "#,##0.00",
        9: "0%", 10: "0.00%", 11: "0.00E+00", 12: "# ?/?", 13: "# ??/??",
        14: "mm-dd-yy", 15: "d-mmm-yy", 16: "d-mmm", 17: "mmm-yy",
        18: "h:mm AM/PM", 19: "h:mm:ss AM/PM", 20: "h:mm", 21: "h:mm:ss",
        22: "m/d/yy h:mm", 37: "#,##0 ;(#,##0)", 38: "#,##0 ;[Red](#,##0)",
        39: "#,##0.00;(#,##0.00)", 40: "#,##0.00;[Red](#,##0.00)",
        45: "mm:ss", 46: "[h]:mm:ss", 47: "mmss.0", 48: "##0.0E+0", 49: "@"
    ]
}

private struct SheetDescriptor {
    let name: String
    let path: String
}

private struct RelationshipTable {
    let byID: [String: String]
    let byKind: [String: String]
}

private struct StyleTable {
    let formats: [String]
}

private enum ContentType: String {
    case workbook = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"
    case worksheet = "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"
    case styles = "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"
    case sharedStrings = "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"
    case theme = "application/vnd.openxmlformats-officedocument.theme+xml"
    case relationships = "application/vnd.openxmlformats-package.relationships+xml"
    case genericXML = "application/xml"
    case drawing = "application/vnd.openxmlformats-officedocument.drawing+xml"
    case coreProperties = "application/vnd.openxmlformats-package.core-properties+xml"
    case extendedProperties = "application/vnd.openxmlformats-officedocument.extended-properties+xml"
    // Ordinary Excel packages may declare this default even when they contain
    // no VML part. Recognition is declaration-only: an actual VML part remains
    // outside the supported package surface and fails closed.
    case vmlDrawing = "application/vnd.openxmlformats-officedocument.vmlDrawing"
    case png = "image/png"

    var isAllowed: Bool { true }

    func isAllowed(for path: String) -> Bool {
        switch self {
        case .workbook:
            return path == "xl/workbook.xml"
        case .worksheet:
            return path.hasPrefix("xl/worksheets/") && path.hasSuffix(".xml")
        case .styles:
            return path == "xl/styles.xml"
        case .sharedStrings:
            return path == "xl/sharedStrings.xml"
        case .theme:
            return path.hasPrefix("xl/theme/")
        case .relationships:
            return path.hasSuffix(".rels")
        case .drawing:
            return path.hasPrefix("xl/drawings/") && path.hasSuffix(".xml")
        case .coreProperties:
            return path == "docProps/core.xml"
        case .extendedProperties:
            return path == "docProps/app.xml"
        case .vmlDrawing:
            return false
        case .png:
            return path.hasPrefix("xl/media/") && path.hasSuffix(".png")
        case .genericXML:
            // Recognize the ordinary OOXML default declaration, but never
            // authorize an actual package part solely as generic XML.
            return false
        }
    }
}

private func normalizePartName(_ value: String) -> String? {
    let withoutSlash = value.hasPrefix("/") ? String(value.dropFirst()) : value
    let parts = withoutSlash.split(separator: "/", omittingEmptySubsequences: false)
    guard !parts.isEmpty, !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
        return nil
    }
    return parts.joined(separator: "/")
}
