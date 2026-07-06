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
