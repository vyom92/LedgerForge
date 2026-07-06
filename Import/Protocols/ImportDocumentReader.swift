// Import/Protocols/DocumentReader.swift
// Reader contract for the Unified Import Framework

import Foundation

public extension ImportFramework {
    protocol DocumentReader: Sendable {
        var supportedFileExtensions: Set<String> { get }

        func read(request: ImportRequest, password: String?) async throws -> RawDocument
    }
}
