// Import/Protocols/ReaderRegistry.swift
// Reader lookup contract for the Unified Import Framework

import Foundation

public extension ImportFramework {
    protocol ReaderRegistry: Sendable {
        func reader(for request: ImportRequest) async -> (any ImportFramework.DocumentReader)?
    }
}
