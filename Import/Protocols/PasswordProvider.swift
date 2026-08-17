// Import/Protocols/PasswordProvider.swift
// Password resolution contract for encrypted financial documents

import Foundation

public extension ImportFramework {
    protocol PasswordProvider: Sendable {
        func password(for request: ImportRequest) async throws -> String?
        func rememberedPasswords(for request: ImportRequest) async throws -> [String]
        func stageSuccessfulPassword(_ password: String, for request: ImportRequest) async
        func confirmSuccessfulPassword(for request: ImportRequest, institutionCode: String) async throws
        func discardStagedPassword(for request: ImportRequest) async
    }
}

public extension ImportFramework.PasswordProvider {
    func rememberedPasswords(for request: ImportRequest) async throws -> [String] { [] }
    func stageSuccessfulPassword(_ password: String, for request: ImportRequest) async {}
    func confirmSuccessfulPassword(for request: ImportRequest, institutionCode: String) async throws {}
    func discardStagedPassword(for request: ImportRequest) async {}
}
