import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct OOXMLDocumentReaderTests {
    @Test func readerSupportsOnlyXLSXAndPreservesFictionalTabularMechanics() async throws {
        let document = try await read(Self.fictionalWorkbookData())

        #expect(OOXMLDocumentReader().supportedFileExtensions == ["xlsx"])
        #expect(document.fileExtension == "xlsx")
        guard case .tabular(let sheet) = document.content else {
            Issue.record("Expected tabular OOXML content.")
            return
        }
        #expect(sheet.name == "Synthetic Mechanics")
        #expect(sheet.visibility == .visible)
        #expect(sheet.rows.count == 3)
        #expect(sheet.columnCount == 3)
        #expect(sheet.rows[0].sourceRow == 1)
        #expect(sheet.rows[0].cells[0].sourceColumn == 1)
        #expect(sheet.rows[0].cells[0].value == .string("Alpha"))
        #expect(sheet.rows[0].cells[1].value == .string("Widget"))
        #expect(sheet.rows[0].cells[2].value == .number("12.50"))
        #expect(sheet.rows[0].cells[2].styleIndex == 1)
        #expect(sheet.rows[0].cells[2].numberFormatCode == "0.00")
        #expect(sheet.rows[1].cells[1].value == .number("50000"))
        #expect(sheet.rows[1].cells[1].styleIndex == 2)
        #expect(sheet.rows[1].cells[1].numberFormatCode == "mm-dd-yy")
        #expect(sheet.mergedRanges == [RawTabularMergedRange(
            reference: "A3:B3", startRow: 3, startColumn: 1, endRow: 3, endColumn: 2
        )])
        #expect(document.searchableText.contains("Alpha"))
        #expect(document.searchableText.contains("Widget"))
    }

    @Test func readerUsesOnlySnapshotAndRetainsNoWorkbookBytes() async throws {
        let snapshot = SourceContentSnapshot(bytes: Self.fictionalWorkbookData())
        let document = try await OOXMLDocumentReader().read(
            request: ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/fictional-mechanics.xlsx")),
            snapshot: snapshot,
            password: nil
        )
        snapshot.invalidate()

        #expect(!document.searchableText.isEmpty)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try snapshot.withBytes { $0.count }
        }
        guard case .tabular = document.content else {
            Issue.record("Expected tabular content after snapshot invalidation.")
            return
        }
    }

    @Test func readerRejectsUnsupportedFormulaAndExplicitDateCells() async throws {
        let formulaRows = """
        <row r="1"><c r="A1"><f>1+1</f><v>2</v></c></row>
        """
        let explicitDateRows = """
        <row r="1"><c r="A1" t="d"><v>2031-02-03</v></c></row>
        """

        for data in [
            Self.fictionalWorkbookData(rowsXML: formulaRows, mergeXML: ""),
            Self.fictionalWorkbookData(rowsXML: explicitDateRows, mergeXML: "")
        ] {
            do {
                _ = try await read(data)
                Issue.record("Expected unsupported OOXML cell mechanics to fail closed.")
            } catch let error as ImportError {
                guard case .unsupportedStatement = error else {
                    Issue.record("Expected unsupportedStatement, got \(error).")
                    continue
                }
            }
        }
    }

    @Test func readerPreservesSparsePhysicalSourceColumnsWithoutCompaction() async throws {
        let rows="""
        <row r="1"><c r="A1" t="s"><v>0</v></c><c r="D1" t="n" s="1"><v>12.50</v></c></row>
        """
        let document=try await read(Self.fictionalWorkbookData(rowsXML:rows,mergeXML:""))
        guard case .tabular(let sheet)=document.content else { Issue.record("Expected sparse tabular content"); return }
        #expect(sheet.rows[0].cells.map(\.sourceColumn) == [1,4])
        #expect(sheet.rows[0].cells.map(\.value) == [.string("Alpha"),.number("12.50")])
    }

    @Test func readerRejectsNonXLSXBeforeOpeningSnapshot() async throws {
        let snapshot = SourceContentSnapshot(bytes: Data([0]))
        do {
            _ = try await OOXMLDocumentReader().read(
                request: ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/source.xls")),
                snapshot: snapshot,
                password: nil
            )
            Issue.record("Expected OOXML reader to reject XLS.")
        } catch let error as ImportError {
            #expect(error == .unsupportedFile(extension: "xls"))
        } catch {
            Issue.record("Expected ImportError.unsupportedFile, got \(error).")
        }
    }

    @Test func registryResolvesOOXMLReaderWithoutChangingLegacyXLSResolution() async throws {
        let registry = DefaultReaderRegistry()
        let xlsx = await registry.reader(for: ImportRequest(
            fileURL: URL(fileURLWithPath: "/tmp/statement.xlsx")
        ))
        let xls = await registry.reader(for: ImportRequest(
            fileURL: URL(fileURLWithPath: "/tmp/statement.xls")
        ))

        #expect(xlsx is OOXMLDocumentReader)
        #expect(xls is LegacyXLSDocumentReader)
    }

    @Test func readerAcceptsExactInertExcelMetadataAndUnusedVMLDeclaration() async throws {
        let appProperties = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <Application>Microsoft Excel</Application>
        </Properties>
        """
        let data = Self.fictionalWorkbookData(
            additionalContentTypes: """
              <Default Extension="vml" ContentType="application/vnd.openxmlformats-officedocument.vmlDrawing"/>
              <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
            """,
            additionalRootRelationships: """
              <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
            """,
            additionalEntries: [("docProps/app.xml", Data(appProperties.utf8))]
        )

        let document = try await read(data)
        guard case .tabular(let sheet) = document.content else {
            Issue.record("Expected inert package metadata to preserve tabular content.")
            return
        }
        #expect(sheet.rows.count == 3)
        #expect(sheet.rows[0].cells[0].value == .string("Alpha"))
    }

    @Test func readerParsesConventionalInertCoreAndExtendedProperties() async throws {
        let coreProperties = """
        <?xml version="1.0" encoding="UTF-8"?>
        <coreProperties xmlns="http://schemas.openxmlformats.org/package/2006/metadata/core-properties">
          <title>Fictional workbook</title><subject>Mechanics</subject><creator>Test</creator>
          <keywords>synthetic</keywords><description>Inert</description><lastModifiedBy>Test</lastModifiedBy>
          <created>2026-01-01T00:00:00Z</created><modified>2026-01-02T00:00:00Z</modified>
        </coreProperties>
        """
        let appProperties = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <Application>Microsoft Excel</Application><AppVersion>16.0400</AppVersion>
          <Company></Company><DocSecurity>0</DocSecurity><ScaleCrop>false</ScaleCrop>
          <HeadingPairs><vt:vector xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes" size="2" baseType="variant">
            <vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant><vt:variant><vt:i4>1</vt:i4></vt:variant>
          </vt:vector></HeadingPairs>
          <TitlesOfParts><vt:vector xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes" size="1" baseType="lpstr">
            <vt:lpstr>Synthetic Mechanics</vt:lpstr>
          </vt:vector></TitlesOfParts>
          <LinksUpToDate>false</LinksUpToDate><SharedDoc>false</SharedDoc><HyperlinksChanged>false</HyperlinksChanged>
        </Properties>
        """
        let data = Self.fictionalWorkbookData(
            additionalContentTypes: """
              <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
              <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
            """,
            additionalRootRelationships: """
              <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
              <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
            """,
            additionalEntries: [
                ("docProps/core.xml", Data(coreProperties.utf8)),
                ("docProps/app.xml", Data(appProperties.utf8))
            ]
        )

        let document = try await read(data)
        guard case .tabular(let sheet) = document.content else {
            Issue.record("Expected inert package metadata to preserve tabular content.")
            return
        }
        #expect(sheet.rows.count == 3)
    }

    @Test func readerRejectsMalformedOrUnknownMetadataParts() async throws {
        func metadataPackage(_ appXML: String) -> Data {
            Self.fictionalWorkbookData(
                additionalContentTypes: """
                  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
                """,
                additionalRootRelationships: """
                  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
                """,
                additionalEntries: [("docProps/app.xml", Data(appXML.utf8))]
            )
        }

        await expectInvalid(metadataPackage("not xml"))
        await expectUnsupported(metadataPackage("""
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <UnexpectedEvidence>reject</UnexpectedEvidence>
        </Properties>
        """))
        await expectUnsupported(metadataPackage("""
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <HeadingPairs><vt:vector xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes" size="2" baseType="variant"><vt:variant/></vt:vector></HeadingPairs>
        </Properties>
        """))
        await expectUnsupported(metadataPackage("""
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <HeadingPairs><vt:vector xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes" size="1" baseType="variant"><vt:variant/></vt:vector></HeadingPairs>
        </Properties>
        """))
        await expectUnsupported(metadataPackage("""
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <TitlesOfParts><vt:vector xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes" size="1" baseType="lpstr" unexpected="evidence"><vt:lpstr>Synthetic Mechanics</vt:lpstr></vt:vector></TitlesOfParts>
        </Properties>
        """))
    }

    @Test func readerRejectsUnrelatedExtendedPropertiesPartWithoutRootRelationship() async throws {
        let data = Self.fictionalWorkbookData(
            additionalContentTypes: """
              <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
            """,
            additionalEntries: [("docProps/app.xml", Data("<Properties/>".utf8))]
        )

        await expectInvalid(data)
    }

    @Test func readerStillRejectsActualVMLPartsAndUnsupportedRelationships() async throws {
        let actualVML = Self.fictionalWorkbookData(
            additionalContentTypes: """
              <Default Extension="vml" ContentType="application/vnd.openxmlformats-officedocument.vmlDrawing"/>
            """,
            additionalEntries: [("xl/drawings/vmlDrawing1.vml", Data("<xml/>".utf8))]
        )
        let unsupportedRelationship = Self.fictionalWorkbookData(
            additionalRootRelationships: """
              <Relationship Id="rId9" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties" Target="docProps/custom.xml"/>
            """,
            additionalEntries: [("docProps/custom.xml", Data("<Properties/>".utf8))]
        )

        await expectUnsupported(actualVML)
        await expectUnsupported(unsupportedRelationship)
    }

    private func read(_ data: Data) async throws -> RawDocument {
        let snapshot = SourceContentSnapshot(bytes: data)
        defer { snapshot.invalidate() }
        return try await OOXMLDocumentReader().read(
            request: ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/fictional-mechanics.xlsx")),
            snapshot: snapshot,
            password: nil
        )
    }

    private func expectInvalid(_ data: Data) async {
        do {
            _ = try await read(data)
            Issue.record("Expected malformed OOXML package evidence to fail closed.")
        } catch let error as ImportError {
            guard case .invalidDocument = error else {
                Issue.record("Expected invalidDocument, got \(error).")
                return
            }
        } catch {
            Issue.record("Expected ImportError.invalidDocument, got \(error).")
        }
    }

    private func expectUnsupported(_ data: Data) async {
        do {
            _ = try await read(data)
            Issue.record("Expected unsupported OOXML package evidence to fail closed.")
        } catch let error as ImportError {
            guard case .unsupportedStatement = error else {
                Issue.record("Expected unsupportedStatement, got \(error).")
                return
            }
        } catch {
            Issue.record("Expected ImportError.unsupportedStatement, got \(error).")
        }
    }

    private static func fictionalWorkbookData(
        rowsXML: String = Self.defaultRowsXML,
        mergeXML: String = Self.defaultMergeXML,
        additionalContentTypes: String = "",
        additionalRootRelationships: String = "",
        additionalEntries: [(String, Data)] = []
    ) -> Data {
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
          \(additionalContentTypes)
        </Types>
        """
        let rootRelationships = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
          \(additionalRootRelationships)
        </Relationships>
        """
        let workbook = """
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets><sheet name="Synthetic Mechanics" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """
        let workbookRelationships = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """
        let styles = """
        <?xml version="1.0" encoding="UTF-8"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <cellXfs count="3"><xf numFmtId="0"/><xf numFmtId="2"/><xf numFmtId="14"/></cellXfs>
        </styleSheet>
        """
        let sharedStrings = """
        <?xml version="1.0" encoding="UTF-8"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="3" uniqueCount="3">
          <si><t>Alpha</t></si><si><t>Widget</t></si><si><t>Note</t></si>
        </sst>
        """
        let worksheet = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>\(rowsXML)</sheetData>
          \(mergeXML)
        </worksheet>
        """

        return StoredZIP.archive([
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rootRelationships.utf8)),
            ("xl/workbook.xml", Data(workbook.utf8)),
            ("xl/_rels/workbook.xml.rels", Data(workbookRelationships.utf8)),
            ("xl/styles.xml", Data(styles.utf8)),
            ("xl/sharedStrings.xml", Data(sharedStrings.utf8)),
            ("xl/worksheets/sheet1.xml", Data(worksheet.utf8))
        ] + additionalEntries)
    }

    private static let defaultRowsXML = """
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="inlineStr"><is><t>Widget</t></is></c>
      <c r="C1" t="n" s="1"><v>12.50</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>2</v></c>
      <c r="B2" t="n" s="2"><v>50000</v></c>
    </row>
    <row r="3"><c r="A3" t="str"><v>Footer</v></c></row>
    """

    private static let defaultMergeXML = """
    <mergeCells count="1"><mergeCell ref="A3:B3"/></mergeCells>
    """
}

private enum StoredZIP {
    static func archive(_ entries: [(String, Data)]) -> Data {
        var output = Data()
        var central = Data()

        for (name, payload) in entries {
            let nameBytes = Array(name.utf8)
            let crc = crc32(payload)
            let offset = UInt32(output.count)

            appendUInt32(0x04034b50, to: &output)
            appendUInt16(20, to: &output)
            appendUInt16(0, to: &output)
            appendUInt16(0, to: &output)
            appendUInt16(0, to: &output)
            appendUInt16(0, to: &output)
            appendUInt32(crc, to: &output)
            appendUInt32(UInt32(payload.count), to: &output)
            appendUInt32(UInt32(payload.count), to: &output)
            appendUInt16(UInt16(nameBytes.count), to: &output)
            appendUInt16(0, to: &output)
            output.append(contentsOf: nameBytes)
            output.append(payload)

            appendUInt32(0x02014b50, to: &central)
            appendUInt16(20, to: &central)
            appendUInt16(20, to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt32(crc, to: &central)
            appendUInt32(UInt32(payload.count), to: &central)
            appendUInt32(UInt32(payload.count), to: &central)
            appendUInt16(UInt16(nameBytes.count), to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt32(0, to: &central)
            appendUInt32(offset, to: &central)
            central.append(contentsOf: nameBytes)
        }

        let centralOffset = UInt32(output.count)
        output.append(central)
        appendUInt32(0x06054b50, to: &output)
        appendUInt16(0, to: &output)
        appendUInt16(0, to: &output)
        appendUInt16(UInt16(entries.count), to: &output)
        appendUInt16(UInt16(entries.count), to: &output)
        appendUInt32(UInt32(central.count), to: &output)
        appendUInt32(centralOffset, to: &output)
        appendUInt16(0, to: &output)
        return output
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = UInt32(0) &- (crc & 1)
                crc = (crc >> 1) ^ (0xEDB88320 & mask)
            }
        }
        return ~crc
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
}
