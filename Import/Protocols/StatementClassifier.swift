// Import/Protocols/StatementClassifier.swift
// Statement classification contract for the Unified Import Framework

import Foundation

public extension ImportFramework {
    protocol StatementClassifier: Sendable {
        func classify(document: RawDocument, institution: ImportInstitutionCandidate?) async throws -> StatementClassification
    }
}

public struct StatementClassification: Equatable, Sendable {
    public let documentType: StatementDocumentType
    public let confidence: Double

    public init(documentType: StatementDocumentType, confidence: Double) {
        self.documentType = documentType
        self.confidence = confidence
    }
}

public enum StatementDocumentType: String, Equatable, Sendable {
    case bankStatement
    case creditCardStatement
    case brokerageStatement
    case insuranceStatement
    case salaryStatement
    case taxDocument
    case unknown
}
