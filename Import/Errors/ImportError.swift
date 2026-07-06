// Import/Errors/ImportError.swift
// Strongly typed import framework errors

import Foundation

public enum ImportError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedFile(extension: String)
    case passwordRequired
    case incorrectPassword
    case readerUnavailable(extension: String)
    case readerFailure(message: String)
    case invalidDocument(message: String)
    case unsupportedStatement(message: String)
    case cancelled
    case unknown(message: String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile(let fileExtension):
            return "Unsupported file type: \(fileExtension)."
        case .passwordRequired:
            return "A password is required to read this document."
        case .incorrectPassword:
            return "The supplied document password is incorrect."
        case .readerUnavailable(let fileExtension):
            return "No document reader is available for file type: \(fileExtension)."
        case .readerFailure(let message):
            return "Document reader failed: \(message)"
        case .invalidDocument(let message):
            return "Invalid document: \(message)"
        case .unsupportedStatement(let message):
            return "Unsupported statement: \(message)"
        case .cancelled:
            return "Import was cancelled."
        case .unknown(let message):
            return "Unknown import error: \(message)"
        }
    }
}
