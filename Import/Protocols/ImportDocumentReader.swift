// Import/Protocols/ImportDocumentReader.swift
// Reader contract for the Unified Import Framework

import Foundation

public extension ImportFramework {
    protocol DocumentReader: Sendable {
        var supportedFileExtensions: Set<String> { get }

        func read(
            request: ImportRequest,
            snapshot: SourceContentSnapshot,
            password: String?
        ) async throws -> RawDocument

        // Retained temporarily so excluded adjacent test doubles using the pre-snapshot
        // contract continue to compile while production readers use the snapshot contract.
        func read(request: ImportRequest, password: String?) async throws -> RawDocument
    }
}

extension ImportFramework.DocumentReader {
    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        try await read(request: request, password: password)
    }

    func read(request: ImportRequest, password: String?) async throws -> RawDocument {
        guard supportedFileExtensions.contains(request.fileExtension) else {
            throw ImportError.unsupportedFile(extension: request.fileExtension)
        }

        let didAccess = request.fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                request.fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let bytes: Data
        do {
            bytes = try Data(contentsOf: request.fileURL)
        } catch {
            throw ImportError.readerFailure(message: "Unable to read source document.")
        }

        let snapshot = SourceContentSnapshot(bytes: bytes)
        defer { snapshot.invalidate() }
        return try await read(request: request, snapshot: snapshot, password: password)
    }
}
