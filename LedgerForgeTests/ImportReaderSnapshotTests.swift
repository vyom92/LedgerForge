import AppKit
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

@MainActor
struct ImportReaderSnapshotTests {
    @Test func csvReaderUsesOriginalSnapshotAfterSourceChangesAndIsRemoved() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("statement.csv")
        let original = "header,value\noriginal,1\n"
        try Data(original.utf8).write(to: sourceURL)
        let snapshot = SourceContentSnapshot(bytes: try Data(contentsOf: sourceURL))

        try Data("header,value\nchanged,2\n".utf8).write(to: sourceURL)
        try FileManager.default.removeItem(at: sourceURL)

        let rawDocument = try await CSVDocumentReaderAdapter().read(
            request: ImportRequest(fileURL: sourceURL),
            snapshot: snapshot,
            password: nil
        )
        #expect(rawDocument.content == .text(original))
    }

    @Test func csvDataOverloadPreservesCurrentUTF8DecodingAndFailureSemantics() throws {
        let text = "Tran Date,PARTICULARS\n01-01-2026,Café ₹\n"
        let bytes = Data(text.utf8)

        #expect(try CSVReader().read(data: bytes) == text)
        #expect(throws: CocoaError.self) {
            try CSVReader().read(data: Data([0xFF, 0xFE, 0xFD]))
        }
    }

    @Test func pdfReaderUsesSnapshotAfterSourceURLIsRemoved() async throws {
        let sourceBytes = try Data(contentsOf: FixtureLocator.axisPDF("axis_bank_nre_account_statement_baseline.pdf"))
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("statement.pdf")
        try sourceBytes.write(to: sourceURL)
        let snapshot = SourceContentSnapshot(bytes: sourceBytes)
        try FileManager.default.removeItem(at: sourceURL)

        let rawDocument = try await PDFDocumentReader().read(
            request: ImportRequest(fileURL: sourceURL),
            snapshot: snapshot,
            password: nil
        )

        guard case .text(let text) = rawDocument.content else {
            Issue.record("Expected PDF snapshot extraction to produce text.")
            return
        }
        #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func pdfPasswordOutcomesRemainTypedForSnapshotData() async throws {
        let sourceBytes = try Data(contentsOf: FixtureLocator.axisPDF("axis_bank_nre_account_statement_baseline.pdf"))
        let sourceDocument = try #require(PDFDocument(data: sourceBytes))
        let writeOptions: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: "correct-password",
            .ownerPasswordOption: "owner-password"
        ]
        let encryptedBytes = try #require(sourceDocument.dataRepresentation(options: writeOptions))
        let snapshot = SourceContentSnapshot(bytes: encryptedBytes)
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/snapshot-only/statement.pdf"))
        let reader = PDFDocumentReader()

        await #expect(throws: ImportError.passwordRequired) {
            try await reader.read(request: request, snapshot: snapshot, password: nil)
        }
        await #expect(throws: ImportError.incorrectPassword) {
            try await reader.read(request: request, snapshot: snapshot, password: "incorrect-password")
        }
        let unlocked = try await reader.read(
            request: request,
            snapshot: snapshot,
            password: "correct-password"
        )
        guard case .text(let text) = unlocked.content else {
            Issue.record("Expected unlocked PDF snapshot extraction to produce text.")
            return
        }
        #expect(!text.isEmpty)
    }

    @Test func pdfNoExtractableTextOutcomeRemainsTypedForSnapshotData() async throws {
        let document = PDFDocument()
        let image = NSImage(size: NSSize(width: 20, height: 20))
        let representation = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 20,
            pixelsHigh: 20,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        image.addRepresentation(representation)
        document.insert(try #require(PDFPage(image: image)), at: 0)
        let bytes = try #require(document.dataRepresentation())
        let snapshot = SourceContentSnapshot(bytes: bytes)
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/snapshot-only/image-only.pdf"))

        do {
            _ = try await PDFDocumentReader().read(
                request: request,
                snapshot: snapshot,
                password: nil
            )
            Issue.record("Expected image-only PDF data to have no extractable text.")
        } catch let error as ImportError {
            #expect(error == .invalidDocument(message: "PDF document contains no extractable text."))
        }
    }

    @Test func coordinatorPassesTheExactSnapshotInstanceToSelectedReader() async throws {
        let snapshot = SourceContentSnapshot(bytes: Data("coordinator snapshot".utf8))
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/snapshot-only/statement.csv"))
        let reader = SnapshotIdentityReader()
        let coordinator = DefaultImportCoordinator(
            readerRegistry: SnapshotIdentityReaderRegistry(reader: reader)
        )

        let result = await coordinator.importDocument(request, snapshot: snapshot)

        #expect(result.status == .succeeded)
        #expect(reader.received(snapshot))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private struct SnapshotIdentityReaderRegistry: ImportFramework.ReaderRegistry {
    let reader: SnapshotIdentityReader

    func reader(for request: ImportRequest) async -> (any ImportFramework.DocumentReader)? {
        reader
    }
}

private final class SnapshotIdentityReader: ImportFramework.DocumentReader, @unchecked Sendable {
    let supportedFileExtensions: Set<String> = ["csv"]

    private let lock = NSLock()
    private var receivedSnapshot: SourceContentSnapshot?

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        lock.lock()
        receivedSnapshot = snapshot
        lock.unlock()
        return RawDocument(
            sourceURL: request.fileURL,
            fileName: request.fileName,
            fileExtension: request.fileExtension,
            content: .text("snapshot received")
        )
    }

    func received(_ expected: SourceContentSnapshot) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return receivedSnapshot === expected
    }
}
