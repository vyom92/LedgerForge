// Import/Protocols/ImportCoordinator.swift
// Coordinator contract for the Unified Import Framework

import Foundation

public extension ImportFramework {
    protocol ImportCoordinator: Sendable {
        func importDocument(
            _ request: ImportRequest,
            snapshot: SourceContentSnapshot
        ) async -> ImportResult
        func confirmSuccessfulPassword(for request: ImportRequest, institutionCode: String) async throws
        func discardStagedPassword(for request: ImportRequest) async
    }
}

public extension ImportFramework.ImportCoordinator {
    func confirmSuccessfulPassword(for request: ImportRequest, institutionCode: String) async throws {}
    func discardStagedPassword(for request: ImportRequest) async {}
}
