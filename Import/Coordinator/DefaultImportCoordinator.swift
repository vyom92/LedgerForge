// Import/Coordinator/DefaultImportCoordinator.swift
// Coordinator skeleton for the Unified Import Framework foundation

import Foundation

public final class DefaultImportCoordinator: ImportFramework.ImportCoordinator {
    private let readerRegistry: any ImportFramework.ReaderRegistry
    private let passwordProvider: (any ImportFramework.PasswordProvider)?

    public init(readerRegistry: any ImportFramework.ReaderRegistry, passwordProvider: (any ImportFramework.PasswordProvider)? = nil) {
        self.readerRegistry = readerRegistry
        self.passwordProvider = passwordProvider
    }

    public func importDocument(
        _ request: ImportRequest,
        snapshot: SourceContentSnapshot
    ) async -> ImportResult {
        guard let reader = await readerRegistry.reader(for: request) else {
            return .failure(request: request, error: .readerUnavailable(extension: request.fileExtension))
        }

        do {
            let rawDocument: RawDocument
            if request.fileExtension == "pdf" {
                rawDocument = try await readPasswordProtectedPDF(request: request) { password in
                    try await reader.read(request: request, snapshot: snapshot, password: password)
                }
            } else {
                rawDocument = try await reader.read(request: request, snapshot: snapshot, password: nil)
            }
            return .success(request: request, rawDocument: rawDocument)
        } catch let error as ImportError {
            return .failure(request: request, error: error)
        } catch {
            return .failure(request: request, error: .readerFailure(message: error.localizedDescription))
        }
    }

    // Compatibility for adjacent tests outside Packet 1's edit boundary. ImportEngine
    // uses only the snapshot-taking overload above.
    public func importDocument(_ request: ImportRequest) async -> ImportResult {
        guard let reader = await readerRegistry.reader(for: request) else {
            return .failure(request: request, error: .readerUnavailable(extension: request.fileExtension))
        }

        do {
            let rawDocument: RawDocument
            if request.fileExtension == "pdf" {
                rawDocument = try await readPasswordProtectedPDF(request: request) { password in
                    try await reader.read(request: request, password: password)
                }
            } else {
                rawDocument = try await reader.read(request: request, password: nil)
            }
            return .success(request: request, rawDocument: rawDocument)
        } catch let error as ImportError {
            return .failure(request: request, error: error)
        } catch {
            return .failure(request: request, error: .readerFailure(message: error.localizedDescription))
        }
    }

    public func confirmSuccessfulPassword(for request: ImportRequest, institutionCode: String) async throws {
        try await passwordProvider?.confirmSuccessfulPassword(
            for: request,
            institutionCode: institutionCode
        )
    }

    public func confirmSuccessfulPassword(
        for request: ImportRequest,
        target: ImportFramework.StatementPasswordCredentialTarget
    ) async throws {
        try await passwordProvider?.confirmSuccessfulPassword(
            for: request,
            target: target
        )
    }

    public func discardStagedPassword(for request: ImportRequest) async {
        await passwordProvider?.discardStagedPassword(for: request)
    }

    private func readPasswordProtectedPDF(
        request: ImportRequest,
        read: @Sendable (String?) async throws -> RawDocument
    ) async throws -> RawDocument {
        do {
            return try await read(nil)
        } catch let error as ImportError where error == .passwordRequired || error == .incorrectPassword {
            // The immutable source has proved that a credential is required.
        }

        guard let passwordProvider else { throw ImportError.passwordRequired }
        for candidate in try await passwordProvider.rememberedPasswordCandidates(for: request) {
            do {
                let document = try await read(candidate.value)
                await passwordProvider.stageSuccessfulPassword(candidate, for: request)
                return document
            } catch let error as ImportError where error == .incorrectPassword || error == .passwordRequired {
                continue
            }
        }

        guard let supplied = try await passwordProvider.password(for: request), !supplied.isEmpty else {
            throw ImportError.passwordRequired
        }
        let document = try await read(supplied)
        await passwordProvider.stageSuccessfulPassword(
            .init(value: supplied, origin: .challenge),
            for: request
        )
        return document
    }
}
