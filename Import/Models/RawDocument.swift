// Import/Models/RawDocument.swift
// Raw document output produced by document readers

import Foundation

public struct RawDocument: Equatable, Sendable {
    public let id: UUID
    public let sourceURL: URL
    public let fileName: String
    public let fileExtension: String
    public let content: RawDocumentContent
    public let extractedAt: Date

    public init(id: UUID = UUID(), sourceURL: URL, fileName: String, fileExtension: String, content: RawDocumentContent, extractedAt: Date = Date()) {
        self.id = id
        self.sourceURL = sourceURL
        self.fileName = fileName
        self.fileExtension = fileExtension.lowercased()
        self.content = content
        self.extractedAt = extractedAt
    }
}

public enum RawDocumentContent: Equatable, Sendable {
    case text(String)
    case data(Data)
}
