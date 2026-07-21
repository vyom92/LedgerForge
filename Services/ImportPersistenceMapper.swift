// LedgerForge
// ImportPersistenceMapper.swift

import Foundation

enum ImportPersistenceError: Error, LocalizedError, Equatable {
    case validationFailed
    case missingDocumentCurrency
    case currencyRelationshipInvalid
    case missingTransactionDate(UUID)
    case missingTransactionDirection(UUID)

    var errorDescription: String? {
        switch self {
        case .validationFailed:
            return "Import persistence requires a passed validation result."
        case .missingDocumentCurrency:
            return "Import persistence requires an explicit statement currency."
        case .currencyRelationshipInvalid:
            return "Import persistence requires matching validated monetary currencies."
        case .missingTransactionDate(let id):
            return "Transaction \(id) is missing a posted date."
        case .missingTransactionDirection(let id):
            return "Transaction \(id) is missing a debit or credit direction."
        }
    }
}

struct ImportPersistencePayload {
    let workspace: WorkspaceDTO
    let account: AccountDTO
    let document: ImportedDocumentDTO
    let fingerprint: DocumentFingerprintDTO
    let importSession: ImportSessionDTO
    let completedAtISO: String
    let transactions: [TransactionDTO]
    let transactionEventIdentities: [TransactionEventIdentityDTO]
}

struct ImportPersistenceMapper {

    let workspaceId: String
    private let workspaceName: String
    private let dateFormatter: ISO8601DateFormatter

    init(
        workspaceId: String = "default-workspace",
        workspaceName: String = "Default Workspace",
        dateFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
    ) {
        self.workspaceId = workspaceId
        self.workspaceName = workspaceName
        self.dateFormatter = dateFormatter
    }

    func workspace(createdAt: Date) -> WorkspaceDTO {
        WorkspaceDTO(
            id: workspaceId,
            name: workspaceName,
            createdAtISO: dateFormatter.string(from: createdAt)
        )
    }

    func payload(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountId: String,
        fingerprint: ExactStatementFingerprint
    ) throws -> ImportPersistencePayload {
        guard validation.passed else {
            throw ImportPersistenceError.validationFailed
        }

        let importedAtISO = dateFormatter.string(from: importSession.importedAt)
        let documentCurrency = try requiredCurrency(financialDocument)
        let account = try accountDTO(
            financialDocument: financialDocument,
            importSession: importSession,
            accountId: accountId,
            createdAtISO: importedAtISO
        )
        let importSessionId = importSession.id.uuidString
        let documentId = "document-\(importSession.id.uuidString.lowercased())"
        let document = ImportedDocumentDTO(
            id: documentId,
            workspaceId: workspaceId,
            importSessionId: importSessionId,
            filename: importSession.fileName,
            mimeType: "text/csv",
            sizeBytes: fingerprint.byteCount,
            sha256: fingerprint.digest,
            createdAtISO: importedAtISO
        )

        let transactions = try financialDocument.transactions.map {
            try transactionDTO(
                from: $0,
                createdAtISO: importedAtISO,
                documentCurrency: documentCurrency
            )
        }
        return ImportPersistencePayload(
            workspace: workspace(createdAt: importSession.importedAt),
            account: account,
            document: document,
            fingerprint: DocumentFingerprintDTO(
                id: "fingerprint-\(importSession.id.uuidString.lowercased())",
                documentId: documentId,
                importSessionId: importSessionId,
                algorithm: fingerprint.algorithm,
                fingerprint: fingerprint.digest,
                fingerprintData: nil,
                createdAtISO: importedAtISO
            ),
            importSession: ImportSessionDTO(
                id: importSessionId,
                workspaceId: workspaceId,
                userVisibleName: importSession.fileName,
                startedAtISO: importedAtISO,
                validationStatus: "pending",
                readerVersion: nil,
                parserVersion: importSession.parserName,
                layoutVersion: nil
            ),
            completedAtISO: importedAtISO,
            transactions: transactions,
            transactionEventIdentities: []
        )
    }

    func confirmedImportPlan(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        providerGeneration: ProviderGenerationToken,
        advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO,
        accountChoice: ConfirmedImportAccountChoiceDTO,
        selectedAccountId: String
    ) throws -> ConfirmedImportPlanDTO {
        let payload = try payload(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            accountId: selectedAccountId,
            fingerprint: fingerprint
        )
        let successfulAttempt = ImportAttemptDTO(
            workspaceId: workspaceId,
            createdAtISO: payload.completedAtISO,
            outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
            coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
            accountDecisionCode: {
                if case .useExistingAccount = accountChoice { return ImportAttemptAccountDecision.selectedExisting.rawValue }
                return ImportAttemptAccountDecision.resolvedOrCreated.rawValue
            }(),
            guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
            persistenceCode: ImportAttemptPersistence.committed.rawValue,
            transactionCount: payload.transactions.count,
            accountId: selectedAccountId,
            importSessionId: payload.importSession.id,
            documentId: payload.document.id
        )
        let identifiers = FinancialIdentityResolver.strongVerifiedIdentifiers(from: financialDocument.financialIdentifiers).map {
            ConfirmedImportIdentifierCandidateDTO(
                scheme: $0.kind.rawValue,
                normalizedValue: $0.normalizedValue,
                provenanceCode: $0.provenance.rawValue
            )
        }
        let templates = zip(payload.transactions, financialDocument.transactions).map { transaction, source in
            ConfirmedImportTransactionTemplateDTO(
                transaction: transaction,
                eventEvidence: source.verifiedAxisUPIEventEvidence.map(Self.confirmedEventEvidence(from:))
            )
        }
        return ConfirmedImportPlanDTO(
            providerGeneration: providerGeneration,
            workspace: payload.workspace,
            proposedAccount: payload.account,
            accountChoice: accountChoice,
            advisoryIdentity: advisoryIdentity,
            identifiers: identifiers,
            historyTemplate: ConfirmedImportHistoryTemplateDTO(
                document: payload.document,
                fingerprint: payload.fingerprint,
                importSession: payload.importSession,
                completedAtISO: payload.completedAtISO,
                successfulAttempt: successfulAttempt
            ),
            transactionTemplates: templates
        )
    }

    private func accountDTO(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        accountId: String,
        createdAtISO: String
    ) throws -> AccountDTO {
        let institutionName = importSession.institution?.rawValue ?? "Unknown"
        let institutionId = Self.institutionId(for: importSession.institution)
        let accountName = Self.displayAccountName(
            institutionName: institutionName,
            documentType: importSession.documentType,
            currency: financialDocument.bookedCurrency?.code,
            fallbackFileName: importSession.fileName
        )
        let accountType: String? = {
            switch importSession.documentType {
            case .bankAccount:
                return "bank"
            case .creditCard:
                return "credit_card"
            default:
                return nil
            }
        }()

        return AccountDTO(
            id: accountId,
            workspaceId: workspaceId,
            name: accountName,
            institutionId: institutionId,
            accountType: accountType,
            nativeCurrency: try requiredCurrency(financialDocument),
            description: "Imported from \(importSession.fileName)",
            createdAtISO: createdAtISO
        )
    }

    private static func institutionId(for institution: Institution?) -> String? {
        guard let institution, institution != .unknown else {
            return nil
        }

        return institution.rawValue
    }

    static func displayAccountName(
        institutionName: String,
        documentType: DocumentType?,
        currency: String?,
        fallbackFileName: String
    ) -> String {
        let trimmedInstitution = institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstitution.isEmpty && trimmedInstitution != "Unknown" {
            switch documentType {
            case .bankAccount?:
                return [trimmedInstitution, currency].compactMap { value in
                    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed?.isEmpty == false ? trimmed : nil
                }.joined(separator: " ")
            case .creditCard?:
                return "\(trimmedInstitution) Credit Card"
            default:
                return trimmedInstitution
            }
        }

        let baseName = (fallbackFileName as NSString).deletingPathExtension
        let separators = CharacterSet(charactersIn: "_-")
        let cleaned = baseName
            .components(separatedBy: separators)
            .filter { component in
                let lowercased = component.lowercased()
                return !["csv", "statement", "statements", "export", "baseline"].contains(lowercased)
            }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "Imported Account" : cleaned.capitalized
    }

    private func transactionDTO(
        from transaction: Transaction,
        createdAtISO: String,
        documentCurrency: String
    ) throws -> TransactionDTO {
        guard let postedDate = transaction.date else {
            throw ImportPersistenceError.missingTransactionDate(transaction.id)
        }

        let direction: String
        if transaction.debitMoney != nil {
            direction = "debit"
        } else if transaction.creditMoney != nil {
            direction = "credit"
        } else {
            throw ImportPersistenceError.missingTransactionDirection(transaction.id)
        }

        guard transaction.money.currency.code == documentCurrency,
              transaction.debitMoney?.currency == nil || transaction.debitMoney?.currency.code == documentCurrency,
              transaction.creditMoney?.currency == nil || transaction.creditMoney?.currency.code == documentCurrency,
              transaction.runningBalanceMoney?.currency == nil || transaction.runningBalanceMoney?.currency.code == documentCurrency else {
            throw ImportPersistenceError.currencyRelationshipInvalid
        }

        return TransactionDTO(
            id: transaction.id.uuidString,
            workspaceId: workspaceId,
            accountId: nil,
            importSessionId: nil,
            documentId: nil,
            originalRowId: nil,
            postedDateISO: Self.dayFormatter.string(from: postedDate),
            valueDateISO: nil,
            description: transaction.description,
            payee: nil,
            reference: nil,
            nativeCurrency: transaction.money.currency.code,
            amountMinor: try transaction.money.minorUnits(),
            amountDecimal: try transaction.money.canonicalDecimalString(),
            direction: direction,
            runningBalanceMinor: try transaction.runningBalanceMoney.map { try $0.minorUnits() },
            isReconciled: false,
            isTrusted: true,
            trustedAtISO: createdAtISO,
            createdAtISO: createdAtISO,
            updatedAtISO: nil,
            rawRows: []
        )
    }

    nonisolated private static func confirmedEventEvidence(
        from evidence: AxisUPITransactionEventEvidence
    ) -> ConfirmedImportTransactionEventEvidenceDTO {
        .axisUPI(
            ConfirmedImportAxisUPIEventEvidenceDTO(
                operation: ConfirmedImportAxisUPIEventEvidenceDTO.Operation(rawValue: evidence.operation.rawValue)!,
                reference: evidence.reference,
                subtype: ConfirmedImportAxisUPIEventEvidenceDTO.LedgerSubtype(rawValue: evidence.subtype.rawValue)!
            )
        )
    }

    private func requiredCurrency(_ financialDocument: FinancialDocument) throws -> String {
        guard let currency = financialDocument.bookedCurrency else {
            throw ImportPersistenceError.missingDocumentCurrency
        }
        return currency.code
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
