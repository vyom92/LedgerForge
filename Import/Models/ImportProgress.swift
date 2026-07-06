// Import/Models/ImportProgress.swift
// Typed progress state for future import orchestration

import Foundation

public struct ImportProgress: Equatable, Sendable {
    public let requestId: UUID
    public let phase: ImportProgressPhase
    public let completedUnitCount: Int
    public let totalUnitCount: Int

    public init(requestId: UUID, phase: ImportProgressPhase, completedUnitCount: Int, totalUnitCount: Int) {
        self.requestId = requestId
        self.phase = phase
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
    }
}

public enum ImportProgressPhase: String, Equatable, Sendable {
    case queued
    case selectingReader
    case resolvingPassword
    case readingDocument
    case completed
    case failed
}
