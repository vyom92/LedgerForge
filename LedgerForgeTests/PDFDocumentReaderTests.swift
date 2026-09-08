// LedgerForgeTests/PDFDocumentReaderTests.swift

import Foundation
import CoreGraphics
import CoreText
import PDFKit
import Testing
@testable import LedgerForge

@MainActor
struct PDFDocumentReaderTests {

    @Test func readerCanBeConstructedAndSupportsOnlyPDF() async throws {
        let reader = PDFDocumentReader()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))

        #expect(reader.supportedFileExtensions == ["pdf"])
        #expect(reader.supportedFileExtensions.contains(request.fileExtension))
    }

    @Test func readerRejectsUnsupportedFileTypes() async throws {
        let reader = PDFDocumentReader()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/nonfinancial-reader-input.csv"))

        do {
            _ = try await reader.read(request: request, password: nil)
            Issue.record("Expected PDFDocumentReader to reject non-PDF input.")
        } catch let error as ImportError {
            #expect(error == .unsupportedFile(extension: "csv"))
        } catch {
            Issue.record("Expected ImportError.unsupportedFile, got \(error).")
        }
    }

    @Test func readerReturnsTypedInvalidDocumentForUnreadablePDF() async throws {
        let reader = PDFDocumentReader()
        let fileURL = try temporaryFileURL(extension: "pdf", contents: Data("not a pdf".utf8))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let request = ImportRequest(fileURL: fileURL)

        do {
            _ = try await reader.read(request: request, password: nil)
            Issue.record("Expected PDFDocumentReader to reject unreadable PDF data.")
        } catch let error as ImportError {
            guard case .invalidDocument = error else {
                Issue.record("Expected ImportError.invalidDocument, got \(error).")
                return
            }
        } catch {
            Issue.record("Expected ImportError.invalidDocument, got \(error).")
        }
    }

    @Test func readerPreservesDeterministicGenericRangeRectangles() async throws {
        let sourceText = "Alpha  Beta\nGamma"
        let fileURL = try temporaryFileURL(
            extension: "pdf",
            contents: try selectablePDFData(lines: ["Alpha  Beta", "Gamma"])
        )
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let reader = PDFDocumentReader()
        let raw = try await reader.read(
            request: ImportRequest(fileURL: fileURL),
            password: nil
        )
        let pages = try #require(raw.pdfPageEvidence)
        let fragments = try #require(pages.first?.fragments)

        #expect(fragments.map(\.text) == sourceText.split(whereSeparator: \.isWhitespace).map(String.init))
        #expect(fragments.allSatisfy { fragment in
            guard let geometry = fragment.geometry else { return false }
            return geometry.isCanonical && geometry.maxX > geometry.minX
                && fragment.x == geometry.minX
                && fragment.y == geometry.baselineY
        })
        #expect(fragments[0].y == fragments[1].y)
        #expect(fragments[2].y < fragments[0].y)
    }

    @Test func readerRetainsPageResourceEvidenceWhenPositionedExtractionFallsBack() async throws {
        let fileURL = try temporaryFileURL(
            extension: "pdf",
            contents: try selectablePDFData(lines: ["resource fallback"])
        )
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        // Simulate the production positioned extractor's fail-closed geometry
        // result. Resource metadata is an independent page-level contract and
        // must still be retained for downstream content classification.
        let reader = PDFDocumentReader(positionedEvidenceExtractor: { _ in nil })
        let raw = try await reader.read(
            request: ImportRequest(fileURL: fileURL),
            password: nil
        )

        #expect(raw.pdfPageEvidence == nil)
        let resources = try #require(raw.pdfPageResourceEvidence)
        #expect(resources.count == 1)
        #expect(resources.first?.imageResourceCount ?? -1 >= 0)
        #expect(resources.first?.largestImageWidth ?? -1 >= 0)
        #expect(resources.first?.largestImageHeight ?? -1 >= 0)
    }

    @Test func readerPreservesTextlessPhysicalPagesInSourceOrder() async throws {
        let fileURL = try temporaryFileURL(
            extension: "pdf",
            contents: try selectablePDFData(pages: [["generic text"], []])
        )
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let raw = try await PDFDocumentReader().read(
            request: ImportRequest(fileURL: fileURL),
            password: nil
        )

        let pageTexts = try #require(raw.pdfPageTexts)
        #expect(pageTexts.count == 2)
        #expect(pageTexts[0].contains("generic text"))
        #expect(pageTexts[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let pageEvidence = try #require(raw.pdfPageEvidence)
        #expect(pageEvidence.count == 2)
        #expect(!pageEvidence[0].fragments.isEmpty)
        #expect(pageEvidence[1].fragments.isEmpty)

        let resources = try #require(raw.pdfPageResourceEvidence)
        #expect(resources.count == 2)
    }

    @Test func readerPreservesGenericTextAndSourceMetadata() async throws {
        let fixtureURL = try temporaryFileURL(
            extension: "pdf", contents: try selectablePDFData(lines: ["Alpha", "Beta"])
        )
        defer { try? FileManager.default.removeItem(at: fixtureURL.deletingLastPathComponent()) }
        let raw = try await PDFDocumentReader().read(request: ImportRequest(fileURL: fixtureURL), password: nil)
        #expect(raw.sourceURL == fixtureURL)
        #expect(raw.fileName == fixtureURL.lastPathComponent)
        #expect(raw.fileExtension == "pdf")
        guard case .text(let text) = raw.content else {
            Issue.record("Expected generic native PDF text.")
            return
        }
        #expect(text.split(whereSeparator: \.isWhitespace).map(String.init) == ["Alpha", "Beta"])
    }

    @Test func genericEncryptedPDFRequiresPasswordRejectsWrongPasswordAndPreservesPages() async throws {
        // This is a source-agnostic transport/encryption test, not a financial
        // statement or evidence of any institution parser's support.
        let pdf = try #require(PDFDocument(data: selectablePDFData(pages: [["Alpha"], [], ["Beta"]])))
        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: "reader-test-password",
            .ownerPasswordOption: "reader-test-owner"
        ]
        let sourceBytes = try #require(pdf.dataRepresentation(options: options))
        let fixtureURL = try temporaryFileURL(extension: "pdf", contents: sourceBytes)
        defer { try? FileManager.default.removeItem(at: fixtureURL.deletingLastPathComponent()) }
        let snapshot = SourceContentSnapshot(bytes: sourceBytes)
        defer { snapshot.invalidate() }
        let request = ImportRequest(fileURL: fixtureURL)
        let reader = PDFDocumentReader()
        await #expect(throws: ImportError.passwordRequired) {
            try await reader.read(request: request, snapshot: snapshot, password: nil)
        }
        await #expect(throws: ImportError.incorrectPassword) {
            try await reader.read(request: request, snapshot: snapshot, password: "wrong-password")
        }
        let unlocked = try await reader.read(
            request: request, snapshot: snapshot, password: "reader-test-password"
        )
        guard case .text(let text) = unlocked.content else {
            Issue.record("Expected unlocked generic PDF text.")
            return
        }
        let pages = try #require(unlocked.pdfPageTexts)
        #expect(pages.count == 3)
        #expect(pages[0].contains("Alpha"))
        #expect(pages[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(pages[2].contains("Beta"))
        #expect(pages.joined(separator: "\n") == text)
    }

    @Test func rawDocumentTaggedEvidenceIsOptionalGenericAndEquatable() {
        let direct = RawPDFTaggedMarkedContentEvidence(
            pageNumber: 1, mcid: 10, textBlocks: [], rectangleCount: 1
        )
        let nested = RawPDFTaggedMarkedContentEvidence(
            pageNumber: 1, mcid: 11, textBlocks: ["logical cell text"], rectangleCount: 0
        )
        let table = RawPDFTaggedTableEvidence(rows: [
            RawPDFTaggedRowEvidence(cells: [
                RawPDFTaggedCellEvidence(
                    role: .data,
                    children: [
                        .markedContent(direct),
                        .structure(.init(role: "NonStruct", markedContent: [nested]))
                    ]
                )
            ])
        ])
        let url = URL(fileURLWithPath: "/tmp/tagged.pdf")
        let plain = RawDocument(
            sourceURL: url, fileName: "tagged.pdf", fileExtension: "pdf", content: .text("text")
        )
        let tagged = RawDocument(
            sourceURL: url, fileName: "tagged.pdf", fileExtension: "pdf", content: .text("text"),
            pdfTaggedTables: [table]
        )
        #expect(plain.pdfTaggedTables == nil)
        #expect(tagged.pdfTaggedTables == [table])
        #expect(table == tagged.pdfTaggedTables?.first)
    }

    private func temporaryFileURL(extension fileExtension: String, contents: Data) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("fixture.\(fileExtension)")
        try contents.write(to: fileURL)
        return fileURL
    }

    private func selectablePDFData(lines: [String]) throws -> Data {
        try selectablePDFData(pages: [lines])
    }

    private func selectablePDFData(pages: [[String]]) throws -> Data {
        let buffer = NSMutableData()
        guard let consumer = CGDataConsumer(data: buffer as CFMutableData) else {
            throw PDFReaderFixtureError.creationFailed
        }
        var mediaBox = CGRect(x: 0, y: 0, width: 300, height: 200)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PDFReaderFixtureError.creationFailed
        }
        let font = CTFontCreateWithName("Courier" as CFString, 12, nil)
        let attributes = [kCTFontAttributeName: font] as CFDictionary
        for lines in pages {
            context.beginPDFPage(nil)
            context.textMatrix = .identity
            for (offset, line) in lines.enumerated() {
                guard let attributed = CFAttributedStringCreate(nil, line as CFString, attributes) else {
                    throw PDFReaderFixtureError.creationFailed
                }
                context.textPosition = CGPoint(x: 20, y: 150 - CGFloat(offset * 24))
                CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return buffer as Data
    }
}

private enum PDFReaderFixtureError: Error {
    case creationFailed
}
