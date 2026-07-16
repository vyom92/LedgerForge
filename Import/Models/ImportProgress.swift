// Import/Models/ImportProgress.swift
// Typed, privacy-safe preparation progress for import orchestration

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
    case openingSource
    case detectingInstitution
    case classifyingStatement
    case selectingParser
    case parsingFinancialContent
    case validatingPreparedContent
    case preparingConfirmationPreview

    public var userFacingTitle: String {
        switch self {
        case .openingSource:
            return "Opening statement"
        case .detectingInstitution:
            return "Detecting institution"
        case .classifyingStatement:
            return "Classifying statement"
        case .selectingParser:
            return "Selecting parser"
        case .parsingFinancialContent:
            return "Parsing financial content"
        case .validatingPreparedContent:
            return "Validating prepared content"
        case .preparingConfirmationPreview:
            return "Preparing confirmation preview"
        }
    }
}

@MainActor
final class ImportPreparationTaskOwner {
    private(set) var activeOperationID: UUID?
    private var activeTask: Task<Void, Never>?

    func start(operation: @escaping @MainActor (UUID) async -> Void) -> UUID {
        cancel()

        let operationID = UUID()
        activeOperationID = operationID
        activeTask = Task {
            await operation(operationID)
        }
        return operationID
    }

    func isCurrent(_ operationID: UUID) -> Bool {
        activeOperationID == operationID
    }

    func finish(_ operationID: UUID) {
        guard activeOperationID == operationID else {
            return
        }
        activeOperationID = nil
        activeTask = nil
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        activeOperationID = nil
    }
}
