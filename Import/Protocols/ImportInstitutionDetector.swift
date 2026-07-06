// Import/Protocols/InstitutionDetector.swift
// Institution detection contract for the Unified Import Framework

import Foundation

public extension ImportFramework {
    protocol InstitutionDetector: Sendable {
        func detectInstitution(in document: RawDocument) async throws -> ImportInstitutionCandidate
    }
}

public struct ImportInstitutionCandidate: Equatable, Sendable {
    public let institutionCode: String?
    public let confidence: Double

    public init(institutionCode: String?, confidence: Double) {
        self.institutionCode = institutionCode
        self.confidence = confidence
    }
}
