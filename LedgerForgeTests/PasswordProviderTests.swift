// LedgerForgeTests/PasswordProviderTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct PasswordProviderTests {

    @Test func defaultPasswordProviderCanBeConstructed() async throws {
        let provider = DefaultPasswordProvider()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.csv"))

        let password = try await provider.password(for: request)

        #expect(password == nil)
    }

    @Test func coordinatorPassesNilPasswordFromProviderToReader() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.csv"))
        let reader = RecordingPasswordReader(expectedPassword: nil)
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: reader),
            passwordProvider: StaticPasswordProvider(password: nil)
        )

        let result = await coordinator.importDocument(request)

        #expect(result.status == .succeeded)
        #expect(result.error == nil)
        #expect(result.rawDocument?.content == .text("password accepted"))
    }

    @Test func coordinatorPassesProvidedPasswordToReader() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))
        let reader = RecordingPasswordReader(expectedPassword: "secret")
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: reader),
            passwordProvider: StaticPasswordProvider(password: "secret")
        )

        let result = await coordinator.importDocument(request)

        #expect(result.status == .succeeded)
        #expect(result.error == nil)
        #expect(result.rawDocument?.content == .text("password accepted"))
    }

    @Test func coordinatorReturnsTypedFailureWhenProviderThrowsImportError() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: RecordingPasswordReader(expectedPassword: nil)),
            passwordProvider: ThrowingPasswordProvider(error: .passwordRequired)
        )

        let result = await coordinator.importDocument(request)

        #expect(result.status == .failed)
        #expect(result.rawDocument == nil)
        #expect(result.error == .passwordRequired)
    }

}

private struct StaticPasswordProvider: ImportFramework.PasswordProvider {
    let password: String?

    func password(for request: ImportRequest) async throws -> String? {
        password
    }
}

private struct ThrowingPasswordProvider: ImportFramework.PasswordProvider {
    let error: ImportError

    func password(for request: ImportRequest) async throws -> String? {
        throw error
    }
}

private struct PasswordTestReaderRegistry: ImportFramework.ReaderRegistry {
    let reader: any ImportFramework.DocumentReader

    func reader(for request: ImportRequest) async -> (any ImportFramework.DocumentReader)? {
        reader
    }
}

private struct RecordingPasswordReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["csv", "pdf"]
    let expectedPassword: String?

    func read(request: ImportRequest, password: String?) async throws -> RawDocument {
        guard password == expectedPassword else {
            throw ImportError.incorrectPassword
        }

        return RawDocument(
            sourceURL: request.fileURL,
            fileName: request.fileName,
            fileExtension: request.fileExtension,
            content: .text("password accepted")
        )
    }
}
