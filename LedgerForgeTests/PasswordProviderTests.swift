// LedgerForgeTests/PasswordProviderTests.swift

import Foundation
import Security
import Testing
@testable import LedgerForge

@MainActor
struct PasswordProviderTests {

    @Test func defaultPasswordProviderCanBeConstructed() async throws {
        let provider = DefaultPasswordProvider(challenge: { _ in nil })
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.csv"))

        let password = try await provider.password(for: request)

        #expect(password == nil)
    }

    @Test func coordinatorDoesNotConsultPasswordProviderForNonPDFDocument() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.csv"))
        let reader = RecordingPasswordReader(expectedPassword: nil)
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: reader),
            passwordProvider: ThrowingPasswordProvider(error: .passwordRequired)
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
            readerRegistry: PasswordTestReaderRegistry(
                reader: RecordingPasswordReader(expectedPassword: "fictional-never-used-password")
            ),
            passwordProvider: ThrowingPasswordProvider(error: .passwordRequired)
        )

        let result = await coordinator.importDocument(request)

        #expect(result.status == .failed)
        #expect(result.rawDocument == nil)
        #expect(result.error == .passwordRequired)
    }

    @Test func coordinatorReusesRememberedPasswordWithoutChallenging() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))
        let store = InMemoryStatementPasswordCredentialStore(
            passwords: ["american-express": "fictional-remembered-password"]
        )
        let challenge = PasswordChallengeSpy()
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: ["american-express"],
            challenge: { _ in
                await challenge.recordCall()
                return "fictional-manual-password"
            }
        )
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(
                reader: RecordingPasswordReader(expectedPassword: "fictional-remembered-password")
            ),
            passwordProvider: provider
        )

        let result = await coordinator.importDocument(
            request,
            snapshot: SourceContentSnapshot(bytes: Data("encrypted fixture bytes".utf8))
        )

        #expect(result.status == .succeeded)
        #expect(await challenge.callCount() == 0)
        #expect(await store.password(institutionCode: "american-express") == "fictional-remembered-password")
    }

    @Test func staleRememberedPasswordIsReplacedOnlyAfterSupportedConfirmation() async throws {
        let store = InMemoryStatementPasswordCredentialStore(
            passwords: ["american-express": "fictional-stale-password"]
        )
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: ["american-express"]
        )
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))

        await provider.stageSuccessfulPassword("fictional-new-password", for: request)
        #expect(await store.password(institutionCode: "american-express") == "fictional-stale-password")

        try await provider.confirmSuccessfulPassword(for: request, institutionCode: "american-express")

        #expect(await store.password(institutionCode: "american-express") == "fictional-new-password")
    }

    @Test func stagedPasswordIsDiscardedAfterRejectionOrCancellationAndNeverSaved() async throws {
        let store = InMemoryStatementPasswordCredentialStore(
            passwords: ["american-express": "fictional-existing-password"]
        )
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: ["american-express"]
        )
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))

        await provider.stageSuccessfulPassword("fictional-staged-password", for: request)
        try await provider.confirmSuccessfulPassword(for: request, institutionCode: "unsupported-test-institution")
        #expect(await store.password(institutionCode: "american-express") == "fictional-existing-password")

        await provider.discardStagedPassword(for: request)
        try await provider.confirmSuccessfulPassword(for: request, institutionCode: "american-express")
        #expect(await store.password(institutionCode: "american-express") == "fictional-existing-password")
    }

    @Test func coordinatorAttemptsEachRememberedPasswordAtMostOnce() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))
        let store = InMemoryStatementPasswordCredentialStore(
            passwords: [
                "first-scope": "fictional-first-password",
                "second-scope": "fictional-second-password",
                "duplicate-scope": "fictional-first-password"
            ]
        )
        let challenge = PasswordChallengeSpy()
        let reader = AttemptRecordingReader()
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: ["first-scope", "second-scope", "duplicate-scope"],
            challenge: { _ in
                await challenge.recordCall()
                return nil
            }
        )
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: reader),
            passwordProvider: provider
        )

        let result = await coordinator.importDocument(
            request,
            snapshot: SourceContentSnapshot(bytes: Data("encrypted fixture bytes".utf8))
        )

        #expect(result.status == .failed)
        #expect(result.error == .passwordRequired)
        #expect(await reader.attempts() == [nil, "fictional-first-password", "fictional-second-password"])
        #expect(await challenge.callCount() == 1)
    }

    @Test func keychainCredentialStoreSmokeUsesOnlyOneUniqueTestItem() async throws {
        let service = "com.ledgerforge.tests.password-\(UUID().uuidString)"
        let account = "test-account-\(UUID().uuidString)"
        let secret = "fictional-keychain-secret-\(UUID().uuidString)"
        let store = KeychainStatementPasswordCredentialStore(service: service)
        defer {
            Task { try? await store.delete(institutionCode: account) }
        }

        try await store.delete(institutionCode: account)
        try await store.save(secret, institutionCode: account)
        let saved = try await store.password(institutionCode: account)
        #expect(saved == secret)

        try await store.delete(institutionCode: account)
        let deleted = try await store.password(institutionCode: account)
        #expect(deleted == nil)
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

private actor PasswordChallengeSpy {
    private var calls = 0

    func recordCall() {
        calls += 1
    }

    func callCount() -> Int {
        calls
    }
}

private actor AttemptRecordingReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["pdf"]
    private var recordedAttempts = [String?]()

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        recordedAttempts.append(password)
        throw password == nil ? ImportError.passwordRequired : ImportError.incorrectPassword
    }

    func attempts() -> [String?] {
        recordedAttempts
    }
}
