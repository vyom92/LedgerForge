// Import/Models/ImportResult.swift
// Typed result returned by the import coordinator foundation

import Foundation

public struct ImportResult: Equatable, Sendable {
    public let request: ImportRequest
    public let status: ImportResultStatus
    public let rawDocument: RawDocument?
    public let error: ImportError?

    public init(request: ImportRequest, status: ImportResultStatus, rawDocument: RawDocument? = nil, error: ImportError? = nil) {
        self.request = request
        self.status = status
        self.rawDocument = rawDocument
        self.error = error
    }

    public static func success(request: ImportRequest, rawDocument: RawDocument) -> ImportResult {
        ImportResult(request: request, status: .succeeded, rawDocument: rawDocument)
    }

    public static func failure(request: ImportRequest, error: ImportError) -> ImportResult {
        ImportResult(request: request, status: .failed, error: error)
    }
}

public enum ImportResultStatus: String, Equatable, Sendable {
    case succeeded
    case failed
    case cancelled
}
