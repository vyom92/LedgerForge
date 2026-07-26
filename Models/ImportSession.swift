//
//  ImportSession.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import Foundation

/// Represents a single import performed by LedgerForge.
///
/// This model stores metadata about an import rather than the imported
/// transactions themselves. Transactions remain the single source of truth
/// in the database.
struct ImportSession: Identifiable {

    let id: UUID
    let importedAt: Date

    let fileName: String

    let institution: Institution?
    let documentType: DocumentType?

    let parserName: String

    let transactionCount: Int

    let validation: ImportValidationResult?

    init(
        id: UUID = UUID(),
        importedAt: Date = Date(),
        fileName: String,
        institution: Institution? = nil,
        documentType: DocumentType? = nil,
        parserName: String,
        transactionCount: Int,
        validation: ImportValidationResult? = nil
    ) {
        self.id = id
        self.importedAt = importedAt
        self.fileName = fileName
        self.institution = institution
        self.documentType = documentType
        self.parserName = parserName
        self.transactionCount = transactionCount
        self.validation = validation
    }
}

/// Runtime-safe representation of an import session. It is populated only by
/// RepositoryStoreHydrator and deliberately does not expose repository DTOs.
struct RepositoryImportSession: Identifiable, Equatable {
    let id: String
    let workspaceId: String
    let sourceDocumentName: String?
    let startedAtISO: String
    let completedAtISO: String?
    let validationStatus: String
    let parserVersion: String?
    let partialImportSummary: RepositoryPartialImportSummary?
    let incomingRowDispositions: [RepositoryIncomingRowDisposition]

    init(
        id: String,
        workspaceId: String,
        sourceDocumentName: String?,
        startedAtISO: String,
        completedAtISO: String?,
        validationStatus: String,
        parserVersion: String?,
        partialImportSummary: RepositoryPartialImportSummary? = nil,
        incomingRowDispositions: [RepositoryIncomingRowDisposition] = []
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.sourceDocumentName = sourceDocumentName
        self.startedAtISO = startedAtISO
        self.completedAtISO = completedAtISO
        self.validationStatus = validationStatus
        self.parserVersion = parserVersion
        self.partialImportSummary = partialImportSummary
        self.incomingRowDispositions = incomingRowDispositions
    }
}

struct RepositoryPartialImportSummary: Equatable {
    let documentId: String
    let statementStartDate: StatementDate
    let statementEndDate: StatementDate
    let nativeCurrency: String
    let sourceRowCount: Int
    let importedTransactionCount: Int
    let recognizedExistingRowCount: Int
    let blockedRowCount: Int
    let openingBalance: Money
    let closingBalance: Money
}

enum RepositoryIncomingRowDispositionCode: String, Equatable {
    case importedUnique = "imported_unique"
    case recognizedExisting = "recognized_existing"
}

struct RepositoryIncomingRowDisposition: Identifiable, Equatable {
    let id: String
    let documentId: String
    let normalizedRowId: String
    let sourceOrdinal: Int
    let code: RepositoryIncomingRowDispositionCode
    let transactionId: String
    let transactionEventIdentityId: String
    let statementDate: StatementDate
    let financialDateRole: String
    let timezoneEvidence: String
    let nativeCurrency: String
    let amount: Money
    let direction: String
    let runningBalance: Money
}
