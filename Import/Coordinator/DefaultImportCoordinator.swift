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

    public func importDocument(_ request: ImportRequest) async -> ImportResult {
        guard let reader = await readerRegistry.reader(for: request) else {
            return .failure(request: request, error: .readerUnavailable(extension: request.fileExtension))
        }

        do {
            let password = try await passwordProvider?.password(for: request)
            let rawDocument = try await reader.read(request: request, password: password)
            return .success(request: request, rawDocument: rawDocument)
        } catch let error as ImportError {
            return .failure(request: request, error: error)
        } catch {
            return .failure(request: request, error: .readerFailure(message: error.localizedDescription))
        }
    }
}
