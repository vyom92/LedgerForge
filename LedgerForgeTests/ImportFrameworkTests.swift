// LedgerForgeTests/ImportFrameworkTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ImportFrameworkTests {

    @Test func importRequestCreationPreservesTypedFileInformation() async throws {
        let url = URL(fileURLWithPath: "/tmp/statement.csv")
        let requestedAt = Date(timeIntervalSince1970: 1_783_344_000)
        let request = ImportRequest(fileURL: url, requestedAt: requestedAt, source: .userSelectedFile)

        #expect(request.fileURL == url)
        #expect(request.requestedAt == requestedAt)
        #expect(request.source == .userSelectedFile)
        #expect(request.fileName == "statement.csv")
        #expect(request.fileExtension == "csv")
    }

    @Test func importCoordinatorWiresRegistryPasswordProviderAndReader() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))
        let rawDocument = RawDocument(
            sourceURL: request.fileURL,
            fileName: request.fileName,
            fileExtension: request.fileExtension,
            content: .text("Generic reader payload")
        )
        let coordinator = DefaultImportCoordinator(
            readerRegistry: SingleReaderRegistry(reader: PasswordCheckingReader(expectedPassword: "secret", rawDocument: rawDocument)),
            passwordProvider: StaticPasswordProvider(password: "secret")
        )

        let result = await coordinator.importDocument(request)

        #expect(result.status == .succeeded)
        #expect(result.rawDocument == rawDocument)
        #expect(result.error == nil)
    }

}

private struct SingleReaderRegistry: ImportFramework.ReaderRegistry {
    let reader: any ImportFramework.DocumentReader

    func reader(for request: ImportRequest) async -> (any ImportFramework.DocumentReader)? {
        reader
    }
}

private struct StaticPasswordProvider: ImportFramework.PasswordProvider {
    let password: String?

    func password(for request: ImportRequest) async throws -> String? {
        password
    }
}

private struct PasswordCheckingReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["pdf"]
    let expectedPassword: String
    let rawDocument: RawDocument

    func read(request: ImportRequest, password: String?) async throws -> RawDocument {
        guard password != nil else {
            throw ImportError.passwordRequired
        }
        guard password == expectedPassword else {
            throw ImportError.incorrectPassword
        }
        return rawDocument
    }
}
