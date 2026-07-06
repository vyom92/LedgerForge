// Import/Protocols/PasswordProvider.swift
// Password resolution contract for encrypted financial documents

import Foundation

public extension ImportFramework {
    protocol PasswordProvider: Sendable {
        func password(for request: ImportRequest) async throws -> String?
    }
}
