// Import/Protocols/ImportCoordinator.swift
// Coordinator contract for the Unified Import Framework

import Foundation

public extension ImportFramework {
    protocol ImportCoordinator: Sendable {
        func importDocument(_ request: ImportRequest) async -> ImportResult
    }
}
