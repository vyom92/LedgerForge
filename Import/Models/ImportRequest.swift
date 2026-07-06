// Import/Models/ImportRequest.swift
// Strongly typed import request model

import Foundation

public struct ImportRequest: Equatable, Sendable {
    public let id: UUID
    public let fileURL: URL
    public let requestedAt: Date
    public let source: ImportSource

    public init(id: UUID = UUID(), fileURL: URL, requestedAt: Date = Date(), source: ImportSource = .userSelectedFile) {
        self.id = id
        self.fileURL = fileURL
        self.requestedAt = requestedAt
        self.source = source
    }

    public var fileName: String {
        fileURL.lastPathComponent
    }

    public var fileExtension: String {
        fileURL.pathExtension.lowercased()
    }
}

public enum ImportSource: String, Equatable, Sendable {
    case userSelectedFile
    case automation
    case retry
}
