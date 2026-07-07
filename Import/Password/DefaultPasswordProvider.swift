// Import/Password/DefaultPasswordProvider.swift
// Production default password provider for the Unified Import Framework.

import Foundation

struct DefaultPasswordProvider: ImportFramework.PasswordProvider {
    func password(for request: ImportRequest) async throws -> String? {
        nil
    }
}
