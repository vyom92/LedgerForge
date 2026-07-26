// LedgerForge
// ImportFailureSummary.swift
// Bounded, privacy-safe preparation failure presentation.

import Foundation

struct ImportFailureSummary: Equatable {
    enum Stage: String, Equatable {
        case sourceReading = "Source reading"
        case documentPreparation = "Document preparation"
        case persistenceAvailability = "Persistence availability"
        case cancellation = "Cancellation"
        case unavailable = "Preparation"
    }

    enum Family: String, Equatable {
        case unsupportedInput = "Unsupported input"
        case credentials = "Credentials"
        case sourceRead = "Source read"
        case invalidDocument = "Invalid document"
        case unsupportedStatement = "Unsupported statement"
        case persistenceUnavailable = "Persistence unavailable"
        case cancelled = "Cancelled"
        case unknown = "Unknown preparation failure"
    }

    let stage: Stage
    let family: Family
    let explanation: String
    let guidance: String

    var displayText: String {
        "\(explanation) \(guidance)"
    }

    static func from(_ error: Error) -> Self {
        if error is CancellationError {
            return Self(
                stage: .cancellation,
                family: .cancelled,
                explanation: "Preparation was cancelled.",
                guidance: "No data was written."
            )
        }

        if let error = error as? PersistenceWorkflowError, error == .unavailable {
            return Self(
                stage: .persistenceAvailability,
                family: .persistenceUnavailable,
                explanation: "Durable persistence is unavailable.",
                guidance: "Verify persistence before preparing a statement again."
            )
        }

        guard let error = error as? ImportError else {
            return Self(
                stage: .unavailable,
                family: .unknown,
                explanation: "The statement could not be prepared.",
                guidance: "Retry preparation or choose another supported statement."
            )
        }

        switch error {
        case .unsupportedFile, .readerUnavailable:
            return Self(
                stage: .sourceReading,
                family: .unsupportedInput,
                explanation: "This document type is not supported by the import workflow.",
                guidance: "Choose a supported statement file."
            )
        case .passwordRequired, .incorrectPassword:
            return Self(
                stage: .sourceReading,
                family: .credentials,
                explanation: "The statement could not be opened with the available credentials.",
                guidance: "Provide the required document password and retry."
            )
        case .readerFailure:
            return Self(
                stage: .sourceReading,
                family: .sourceRead,
                explanation: "The statement could not be read.",
                guidance: "Retry preparation or choose another supported statement."
            )
        case .invalidDocument:
            return Self(
                stage: .documentPreparation,
                family: .invalidDocument,
                explanation: "The document could not be prepared for review.",
                guidance: "Verify the supported statement format and retry."
            )
        case .unsupportedStatement:
            return Self(
                stage: .documentPreparation,
                family: .unsupportedStatement,
                explanation: "This statement is outside the supported import boundary.",
                guidance: "Choose a supported statement family."
            )
        case .cancelled:
            return Self(
                stage: .cancellation,
                family: .cancelled,
                explanation: "Preparation was cancelled.",
                guidance: "No data was written."
            )
        case .unknown:
            return Self(
                stage: .unavailable,
                family: .unknown,
                explanation: "The statement could not be prepared.",
                guidance: "Retry preparation or choose another supported statement."
            )
        }
    }
}
