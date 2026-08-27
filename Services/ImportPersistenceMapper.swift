// LedgerForge
// ImportPersistenceMapper.swift

import Foundation

enum ImportPersistenceError: Error, LocalizedError, Equatable {
    case validationFailed
    case missingDocumentCurrency
    case currencyRelationshipInvalid
    case missingTransactionDate(UUID)
    case missingTransactionDirection(UUID)
    case missingTransactionProvenance
    case conflictingTransactionProvenance
    case missingParserProfileProvenance
    case malformedParserProfileProvenance
    case conflictingParserProfileProvenance
    case invalidFingerprintSet
    case unsupportedPreparedSourceFormat
    case conflictingPreparedSourceFormat
    case missingLegacyRawTextFingerprint
    case duplicateAuthorityFormatMismatch

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
        case .missingTransactionProvenance:
            return "Import persistence requires transaction source provenance."
        case .conflictingTransactionProvenance:
            return "Import persistence found conflicting transaction source provenance."
        case .missingParserProfileProvenance:
            return "Import persistence requires parser-produced profile provenance."
        case .malformedParserProfileProvenance:
            return "Import persistence requires an exact nonempty parser profile identifier and version."
        case .conflictingParserProfileProvenance:
            return "Import persistence found conflicting parser profile provenance."
        case .invalidFingerprintSet:
            return "Import persistence requires a valid prepared fingerprint set."
        case .unsupportedPreparedSourceFormat:
            return "Import persistence does not support the prepared source format."
        case .conflictingPreparedSourceFormat:
            return "Import persistence found conflicting prepared source-format evidence."
        case .missingLegacyRawTextFingerprint:
            return "Import persistence requires the prepared raw-text fingerprint."
        case .duplicateAuthorityFormatMismatch:
            return "Import persistence found a source-format and duplicate-authority mismatch."
        }
    }
}

enum ImportPersistenceSourceFormat: Equatable, Sendable {
    case csv
    case pdf
    case xls
    case xlsx

    var mimeType: String {
        switch self {
        case .csv:
            return "text/csv"
        case .pdf:
            return "application/pdf"
        case .xls:
            return "application/vnd.ms-excel"
        case .xlsx:
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        }
    }

    var duplicateAuthorityAlgorithm: String {
        switch self {
        case .csv:
            return DocumentFingerprintDTO.rawTextSHA256Algorithm
        case .pdf, .xls, .xlsx:
            return DocumentFingerprintDTO.sourceBytesSHA256Algorithm
        }
    }

    init(preparedDocument financialDocument: FinancialDocument) throws {
        switch financialDocument.metadata.fileFormat {
        case .csv:
            self = .csv
        case .pdf:
            self = .pdf
        case .xls:
            self = .xls
        case .xlsx:
            self = .xlsx
        case .unknown:
            throw ImportPersistenceError.unsupportedPreparedSourceFormat
        }

        let sourceDocumentFormat = FileFormat(
            rawValue: financialDocument.sourceDocument.fileType
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
        )
        guard sourceDocumentFormat == financialDocument.metadata.fileFormat else {
            throw ImportPersistenceError.conflictingPreparedSourceFormat
        }
    }

    init?(mimeType: String?) {
        switch mimeType {
        case "text/csv":
            self = .csv
        case "application/pdf":
            self = .pdf
        case "application/vnd.ms-excel":
            self = .xls
        case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
            self = .xlsx
        default:
            return nil
        }
    }
}

struct ImportPersistencePayload {
    let workspace: WorkspaceDTO
    let account: AccountDTO
    let document: ImportedDocumentDTO
    let fingerprint: DocumentFingerprintDTO
    let fingerprints: [DocumentFingerprintDTO]
    let importSession: ImportSessionDTO
    let completedAtISO: String
    let normalizedDocument: NormalizedDocumentDTO
    let normalizedRows: [NormalizedRowDTO]
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
        try payload(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            accountId: accountId,
            fingerprintSet: PreparedDocumentFingerprintSet(fingerprints: [
                VersionedDocumentFingerprint(
                    algorithm: fingerprint.algorithm,
                    digest: fingerprint.digest,
                    byteCount: fingerprint.byteCount,
                    isDuplicateAuthority: true
                )
            ])
        )
    }

    func payload(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountId: String,
        fingerprintSet: PreparedDocumentFingerprintSet
    ) throws -> ImportPersistencePayload {
        guard validation.passed else {
            throw ImportPersistenceError.validationFailed
        }
        let sourceFormat = try ImportPersistenceSourceFormat(
            preparedDocument: financialDocument
        )
        guard fingerprintSet.isValid,
              fingerprintSet.fingerprints.allSatisfy({
                  DocumentFingerprintDTO.approvedAlgorithms.contains($0.algorithm)
              }),
              let duplicateAuthority = fingerprintSet.duplicateAuthority else {
            throw ImportPersistenceError.invalidFingerprintSet
        }
        guard duplicateAuthority.algorithm == sourceFormat.duplicateAuthorityAlgorithm else {
            throw ImportPersistenceError.duplicateAuthorityFormatMismatch
        }
        guard let rawTextFingerprint = fingerprintSet.fingerprints.first(where: {
            $0.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm
        }) else {
            throw ImportPersistenceError.missingLegacyRawTextFingerprint
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
            mimeType: sourceFormat.mimeType,
            sizeBytes: duplicateAuthority.byteCount,
            legacyRawTextSHA256: rawTextFingerprint.digest,
            createdAtISO: importedAtISO
        )

        // Only privacy-safe digest DTOs cross into persistence. Snapshot bytes,
        // transient byte counts, and external URL metadata remain engine-owned.
        let fingerprints = fingerprintSet.fingerprints.enumerated().map { index, fingerprint in
            DocumentFingerprintDTO(
                id: "fingerprint-\(importSession.id.uuidString.lowercased())-\(index)",
                documentId: documentId,
                importSessionId: importSessionId,
                algorithm: fingerprint.algorithm,
                fingerprint: fingerprint.digest,
                fingerprintData: nil,
                isDuplicateAuthority: fingerprint.isDuplicateAuthority,
                createdAtISO: importedAtISO
            )
        }

        let normalizedDocumentID = "normalized-document-\(importSession.id.uuidString.lowercased())"
        let parserProfile = try requiredParserProfile(
            from: financialDocument.transactions
        )
        let normalizedRows = try financialDocument.transactions.flatMap(\.sourceProvenance).map { provenance in
            guard provenance.sourceOrdinal > 0, !provenance.normalizedRecordDigest.isEmpty else {
                throw ImportPersistenceError.missingTransactionProvenance
            }
            return NormalizedRowDTO(
                id: "normalized-row-\(importSession.id.uuidString.lowercased())-\(provenance.sourceOrdinal)",
                normalizedDocumentId: normalizedDocumentID,
                sourceOrdinal: provenance.sourceOrdinal,
                digest: provenance.normalizedRecordDigest
            )
        }
        guard Set(normalizedRows.map(\.sourceOrdinal)).count == normalizedRows.count else {
            throw ImportPersistenceError.conflictingTransactionProvenance
        }
        let transactions = try financialDocument.transactions.map {
            try transactionDTO(
                from: $0,
                createdAtISO: importedAtISO,
                documentCurrency: documentCurrency,
                normalizedDocumentID: normalizedDocumentID,
                importSessionID: importSession.id.uuidString
            )
        }
        return ImportPersistencePayload(
            workspace: workspace(createdAt: importSession.importedAt),
            account: account,
            document: document,
            fingerprint: fingerprints.first(where: \.isDuplicateAuthority)!,
            fingerprints: fingerprints,
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
            normalizedDocument: NormalizedDocumentDTO(
                id: normalizedDocumentID,
                importSessionId: importSessionId,
                documentId: documentId,
                profileId: parserProfile.id,
                profileVersion: parserProfile.version
            ),
            normalizedRows: normalizedRows,
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
        selectedAccountId: String,
        cardInstrumentChoice: ConfirmedCardInstrumentChoiceDTO = .unspecified,
        cardAssociationAuthority: String = "user_confirmed",
        cardRelationshipKind: CardInstrumentRelationshipKind? = nil,
        relatedInstrumentId: String? = nil,
        cardSectionChoices: [String: ConfirmedCardInstrumentChoiceDTO] = [:],
        cardSectionAuthorities: [String: String] = [:],
        cardSectionRelationships: [String: (kind: CardInstrumentRelationshipKind, relatedInstrumentId: String)] = [:]
    ) throws -> ConfirmedImportPlanDTO {
        try confirmedImportPlan(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprintSet: PreparedDocumentFingerprintSet(fingerprints: [
                VersionedDocumentFingerprint(
                    algorithm: fingerprint.algorithm,
                    digest: fingerprint.digest,
                    byteCount: fingerprint.byteCount,
                    isDuplicateAuthority: true
                )
            ]),
            providerGeneration: providerGeneration,
            advisoryIdentity: advisoryIdentity,
            accountChoice: accountChoice,
            selectedAccountId: selectedAccountId,
            cardInstrumentChoice: cardInstrumentChoice,
            cardAssociationAuthority: cardAssociationAuthority,
            cardRelationshipKind: cardRelationshipKind,
            relatedInstrumentId: relatedInstrumentId,
            cardSectionChoices: cardSectionChoices,
            cardSectionAuthorities: cardSectionAuthorities,
            cardSectionRelationships: cardSectionRelationships
        )
    }

    func confirmedImportPlan(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        providerGeneration: ProviderGenerationToken,
        advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO,
        accountChoice: ConfirmedImportAccountChoiceDTO,
        selectedAccountId: String,
        cardInstrumentChoice: ConfirmedCardInstrumentChoiceDTO = .unspecified,
        cardAssociationAuthority: String = "user_confirmed",
        cardRelationshipKind: CardInstrumentRelationshipKind? = nil,
        relatedInstrumentId: String? = nil,
        cardSectionChoices: [String: ConfirmedCardInstrumentChoiceDTO] = [:],
        cardSectionAuthorities: [String: String] = [:],
        cardSectionRelationships: [String: (kind: CardInstrumentRelationshipKind, relatedInstrumentId: String)] = [:]
    ) throws -> ConfirmedImportPlanDTO {
        let payload = try payload(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            accountId: selectedAccountId,
            fingerprintSet: fingerprintSet
        )
        let identifiers = FinancialIdentityResolver.strongVerifiedIdentifiers(
            from: financialDocument.financialIdentifiers
        ).map {
            ConfirmedImportIdentifierCandidateDTO(
                scheme: $0.kind.rawValue,
                normalizedValue: $0.normalizedValue,
                provenanceCode: $0.provenance.rawValue
            )
        }
        let accountOutcome = ImportAccountOutcome.confirmed(
            advisoryIdentity: advisoryIdentity,
            accountChoice: accountChoice,
            eligibleIdentifierCount: identifiers.count
        )
        let successfulAttempt = ImportAttemptDTO(
            workspaceId: workspaceId,
            createdAtISO: payload.completedAtISO,
            outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
            coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
            accountDecisionCode: accountOutcome.successfulAttemptDecision.rawValue,
            guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
            persistenceCode: ImportAttemptPersistence.committed.rawValue,
            transactionCount: payload.transactions.count,
            accountId: selectedAccountId,
            importSessionId: payload.importSession.id,
            documentId: payload.document.id,
            sourceRowCount: payload.transactions.count,
            importedTransactionCount: payload.transactions.count,
            recognizedExistingRowCount: 0,
            blockedRowCount: 0
        )
        let templates = zip(payload.transactions, financialDocument.transactions).map { transaction, source in
            ConfirmedImportTransactionTemplateDTO(
                transaction: transaction,
                eventEvidence: source.verifiedAxisUPIEventEvidence.map(Self.confirmedEventEvidence(from:))
            )
        }
        let statementProjection = try statementFinancialProjectionDTO(
            financialDocument: financialDocument,
            normalizedDocument: payload.normalizedDocument,
            importSessionID: payload.importSession.id
        )
        let cbqRows: [CBQSourceRowDTO]
        let cbqStatementEvidence: CBQStatementSourceEvidenceDTO?
        let isCBQCurrentAccount = financialDocument.metadata.institution == .cbq &&
            financialDocument.metadata.documentType == .bankAccount &&
            [CBQCurrentAccountXLSParser.profileID, CBQCurrentAccountPDFParser.historyProfileID, CBQCurrentAccountPDFParser.monthlyProfileID]
                .contains(payload.normalizedDocument.profileId)
        if isCBQCurrentAccount {
            cbqRows = try financialDocument.transactions.enumerated().map { index, source in
                guard source.sourceProvenance.count == 1,
                      index < payload.transactions.count,
                      index < payload.normalizedRows.count,
                      let date = source.statementDate,
                      let balance = source.runningBalanceMoney else {
                    throw ImportPersistenceError.missingTransactionProvenance
                }
                let provenance = source.sourceProvenance[0]
                return CBQSourceRowDTO(
                    incomingTransactionId: payload.transactions[index].id,
                    normalizedRowId: payload.normalizedRows[index].id,
                    sourceOrdinal: provenance.sourceOrdinal,
                    normalizedRecordDigest: provenance.normalizedRecordDigest,
                    postingDateISO: date.canonical,
                    sourceTransactionDateISO: provenance.sourceTransactionDate?.canonical,
                    nativeCurrency: source.money.currency.code,
                    signedAmountMinor: try source.money.minorUnits(),
                    signedAmountDecimal: try source.money.canonicalDecimalString(),
                    direction: source.debitMoney == nil ? "credit" : "debit",
                    runningBalanceMinor: try balance.minorUnits(),
                    runningBalanceDecimal: try balance.canonicalDecimalString(),
                    structuredReferenceDigest: provenance.structuredReferenceDigest
                )
            }
            guard let evidence = financialDocument.sourceStatementEvidence else {
                throw ImportPersistenceError.missingTransactionProvenance
            }
            cbqStatementEvidence = CBQStatementSourceEvidenceDTO(
                sourceFormatCode: evidence.sourceFormatCode,
                statementBoundaryDateISO: evidence.statementBoundaryDate?.canonical,
                statementStartDateISO: evidence.period?.start.canonical,
                statementEndDateISO: evidence.period?.end.canonical,
                openingBalanceMinor: try evidence.openingBalance.map { try $0.minorUnits() },
                openingBalanceDecimal: try evidence.openingBalance.map { try $0.canonicalDecimalString() },
                closingBalanceMinor: try evidence.closingBalance.map { try $0.minorUnits() },
                closingBalanceDecimal: try evidence.closingBalance.map { try $0.canonicalDecimalString() }
            )
        } else {
            cbqRows = []
            cbqStatementEvidence = nil
        }
        let cardPlan = try cardImportPlan(
            financialDocument: financialDocument,
            payload: payload,
            selectedAccountId: selectedAccountId,
            instrumentChoice: cardInstrumentChoice,
            associationAuthority: cardAssociationAuthority,
            relationshipKind: cardRelationshipKind,
            relatedInstrumentId: relatedInstrumentId,
            sectionChoices: cardSectionChoices,
            sectionAuthorities: cardSectionAuthorities,
            sectionRelationships: cardSectionRelationships
        )
        return ConfirmedImportPlanDTO(
            providerGeneration: providerGeneration,
            workspace: payload.workspace,
            proposedAccount: payload.account,
            accountChoice: accountChoice,
            advisoryIdentity: advisoryIdentity,
            identifiers: identifiers,
            historyTemplate: ConfirmedImportHistoryTemplateDTO(
                document: payload.document,
                fingerprints: payload.fingerprints,
                importSession: payload.importSession,
                completedAtISO: payload.completedAtISO,
                successfulAttempt: successfulAttempt,
                normalizedDocument: payload.normalizedDocument,
                normalizedRows: payload.normalizedRows
            ),
            transactionTemplates: templates,
            declaredStatementStartISO: financialDocument.declaredStatementPeriod?.start.canonical,
            declaredStatementEndISO: financialDocument.declaredStatementPeriod?.end.canonical,
            openingBalanceMinor: try validation.openingBalanceMoney.map { try $0.minorUnits() },
            openingBalanceDecimal: try validation.openingBalanceMoney.map { try $0.canonicalDecimalString() },
            closingBalanceMinor: try validation.closingBalanceMoney.map { try $0.minorUnits() },
            closingBalanceDecimal: try validation.closingBalanceMoney.map { try $0.canonicalDecimalString() },
            statementFinancialProjection: statementProjection,
            cbqSourceIdentityPatterns: financialDocument.cbqSourceIdentityObservations.map {
                CBQSourceIdentityPatternDTO(kind: $0.kind.rawValue, pattern: $0.pattern)
            },
            cbqSourceRows: cbqRows,
            cbqStatementSourceEvidence: cbqStatementEvidence,
            cardImportPlan: cardPlan
        )
    }

    private func cardImportPlan(
        financialDocument: FinancialDocument,
        payload: ImportPersistencePayload,
        selectedAccountId: String,
        instrumentChoice: ConfirmedCardInstrumentChoiceDTO,
        associationAuthority: String,
        relationshipKind: CardInstrumentRelationshipKind?,
        relatedInstrumentId: String?,
        sectionChoices: [String: ConfirmedCardInstrumentChoiceDTO],
        sectionAuthorities: [String: String],
        sectionRelationships: [String: (kind: CardInstrumentRelationshipKind, relatedInstrumentId: String)]
    ) throws -> ConfirmedCardImportPlanDTO? {
        guard let evidence = financialDocument.cardStatementEvidence else { return nil }
        let isAmex = financialDocument.metadata.institution == .amex &&
            evidence.reconciliationRuleIdentifier == CardStatementEvidence.amexQARReconciliationRule &&
            payload.normalizedDocument.profileId == "amex.credit-card.pdf" &&
            payload.normalizedDocument.profileVersion == "1"
        let isCBQ = financialDocument.metadata.institution == .cbq &&
            [CardStatementEvidence.cbqV1QARReconciliationRule, CardStatementEvidence.cbqV2QARReconciliationRule]
                .contains(evidence.reconciliationRuleIdentifier) &&
            payload.normalizedDocument.profileId == "cbq.credit-card.pdf" &&
            payload.normalizedDocument.profileVersion == "1"
        let isAxis = financialDocument.metadata.institution == .axis &&
            [CardStatementEvidence.axisINRRowLedgerReconciliationRule,
             CardStatementEvidence.axisINRAppRowLedgerReconciliationRule]
                .contains(evidence.reconciliationRuleIdentifier) &&
            ((financialDocument.metadata.fileFormat == .pdf && payload.normalizedDocument.profileId == "axis.credit-card.pdf") ||
             (financialDocument.metadata.fileFormat == .xlsx && payload.normalizedDocument.profileId == "axis.credit-card.xlsx")) &&
            payload.normalizedDocument.profileVersion == "1"
        guard (isAmex || isCBQ || isAxis),
              financialDocument.metadata.documentType == .creditCard,
              ((isAxis && [.pdf, .xlsx].contains(financialDocument.metadata.fileFormat)) ||
               (!isAxis && financialDocument.metadata.fileFormat == .pdf)),
              payload.transactions.count == financialDocument.transactions.count,
              payload.transactions.count == evidence.transactionAnnotations.count,
              ["user_confirmed", "prior_user_confirmed_mapping", "parser_strong_evidence"].contains(associationAuthority) else {
            throw ImportPersistenceError.conflictingTransactionProvenance
        }
        guard isAxis
            ? evidence.instrumentSections.isEmpty && evidence.accountSourceIdentityObservations.isEmpty
            : !evidence.instrumentSections.isEmpty && evidence.accountSourceIdentityObservations.count == 1 else {
            throw ImportPersistenceError.conflictingTransactionProvenance
        }
        let statementID = "card-statement-\(payload.importSession.id.lowercased())"
        let sectionCount = evidence.instrumentSections.count
        var selectedInstrumentIDs = [String: String]()
        var sectionDecisions = [ConfirmedCardSectionDecisionDTO]()
        for section in evidence.instrumentSections {
            let sectionID = section.documentScopedSectionID
            let choice = sectionChoices[sectionID] ?? (sectionCount == 1 ? instrumentChoice : .unspecified)
            let authority = sectionAuthorities[sectionID] ?? associationAuthority
            guard ["user_confirmed", "prior_user_confirmed_mapping", "parser_strong_evidence"].contains(authority) else {
                throw ImportPersistenceError.conflictingTransactionProvenance
            }
            let proposedInstrumentID = sectionCount == 1
                ? "card-instrument-\(payload.importSession.id.lowercased())"
                : "card-instrument-\(payload.importSession.id.lowercased())-\(section.sourceOrdinal)"
            let selectedInstrumentID: String
            switch choice {
            case .unspecified, .createProposedInstrument:
                selectedInstrumentID = proposedInstrumentID
            case .useExistingInstrument(let instrumentId):
                selectedInstrumentID = instrumentId
            }
            selectedInstrumentIDs[sectionID] = selectedInstrumentID
            let proposed = CardInstrumentDTO(
                id: proposedInstrumentID,
                workspaceId: workspaceId,
                liabilityAccountId: selectedAccountId,
                lifecycleStateCode: CardInstrumentLifecycleState.unknown.rawValue,
                createdAtISO: payload.completedAtISO
            )
            let durableSectionID = "card-section-\(payload.importSession.id.lowercased())-\(section.sourceOrdinal)"
            let sectionDTO = CardStatementSectionDTO(
                id: durableSectionID,
                cardStatementId: statementID,
                documentScopedSectionId: sectionID,
                sourceOrdinal: section.sourceOrdinal,
                instrumentId: selectedInstrumentID,
                holderLabel: section.holderLabel,
                signedTotalCurrency: section.signedNetTotal.currency.code,
                signedTotalMinor: try section.signedNetTotal.minorUnits(),
                signedTotalDecimal: try section.signedNetTotal.canonicalDecimalString(),
                reconciliationRuleCode: section.reconciliationRuleIdentifier
            )
            let observations = section.sourceIdentityObservations.map { observation in
                CardStatementSectionObservationDTO(
                    id: "card-section-observation-\(payload.importSession.id.lowercased())-\(section.sourceOrdinal)-\(observation.kind.rawValue)",
                    cardStatementSectionId: durableSectionID,
                    workspaceId: workspaceId,
                    documentId: payload.document.id,
                    importSessionId: payload.importSession.id,
                    normalizedDocumentId: payload.normalizedDocument.id,
                    parserProfileId: payload.normalizedDocument.profileId,
                    parserProfileVersion: payload.normalizedDocument.profileVersion,
                    observationKind: observation.kind.rawValue,
                    sourceValue: observation.value,
                    associationAuthority: authority,
                    createdAtISO: payload.completedAtISO
                )
            }
            let requestedRelationship = sectionRelationships[sectionID] ?? {
                guard sectionCount == 1, let relationshipKind, let relatedInstrumentId else { return nil }
                return (relationshipKind, relatedInstrumentId)
            }()
            let relationships: [CardInstrumentRelationshipDTO]
            if case .createProposedInstrument = choice, let requestedRelationship {
                relationships = [CardInstrumentRelationshipDTO(
                    id: "card-relationship-\(payload.importSession.id.lowercased())-\(section.sourceOrdinal)",
                    workspaceId: workspaceId,
                    liabilityAccountId: selectedAccountId,
                    predecessorInstrumentId: requestedRelationship.relatedInstrumentId,
                    successorInstrumentId: proposedInstrumentID,
                    relationshipKind: requestedRelationship.kind.rawValue,
                    authority: "user_confirmed",
                    effectiveDateISO: nil,
                    createdAtISO: payload.completedAtISO
                )]
            } else {
                relationships = []
            }
            sectionDecisions.append(ConfirmedCardSectionDecisionDTO(
                instrumentChoice: choice,
                proposedInstrument: proposed,
                section: sectionDTO,
                sourceObservations: observations,
                relationships: relationships
            ))
        }
        let accountObservations = evidence.accountSourceIdentityObservations.map { observation in
            CardSourceIdentityObservationDTO(
                id: "card-observation-\(payload.importSession.id.lowercased())-account-\(observation.kind.rawValue)",
                workspaceId: workspaceId,
                documentId: payload.document.id,
                importSessionId: payload.importSession.id,
                normalizedDocumentId: payload.normalizedDocument.id,
                parserProfileId: payload.normalizedDocument.profileId,
                parserProfileVersion: payload.normalizedDocument.profileVersion,
                subjectKind: observation.subject.rawValue,
                subjectId: selectedAccountId,
                observationKind: observation.kind.rawValue,
                sourceValue: observation.value,
                associationAuthority: associationAuthority,
                createdAtISO: payload.completedAtISO
            )
        }
        let selectedStatementMonthISO = evidence.selectedStatementMonth?.canonical
        let cycleMonthISO: String?
        if isAxis {
            cycleMonthISO = evidence.selectedStatementMonth?.canonical
        } else {
            cycleMonthISO = nil
        }
        let statement = CardStatementDTO(
            id: statementID,
            workspaceId: workspaceId,
            liabilityAccountId: selectedAccountId,
            documentId: payload.document.id,
            importSessionId: payload.importSession.id,
            normalizedDocumentId: payload.normalizedDocument.id,
            parserProfileId: payload.normalizedDocument.profileId,
            parserProfileVersion: payload.normalizedDocument.profileVersion,
            statementDateISO: evidence.statementDate?.canonical,
            statementStartDateISO: evidence.declaredStatementPeriod?.start.canonical,
            statementEndDateISO: evidence.declaredStatementPeriod?.end.canonical,
            selectedStatementMonthISO: selectedStatementMonthISO,
            statementCurrency: evidence.nativeCurrency.code,
            sourceRowCount: payload.transactions.count,
            reconciliationRuleCode: evidence.reconciliationRuleIdentifier,
            createdAtISO: payload.completedAtISO
        )
        let summary = try evidence.summaryComponents.map { component in
            CardStatementSummaryComponentDTO(
                id: "\(statementID)-summary-\(component.persistenceCode)",
                cardStatementId: statementID,
                componentCode: component.persistenceCode,
                moneyCurrency: component.money?.currency.code,
                moneyMinor: try component.money.map { try $0.minorUnits() },
                moneyDecimal: try component.money.map { try $0.canonicalDecimalString() },
                dateISO: component.date?.canonical
            )
        }
        let annotations = Dictionary(uniqueKeysWithValues: evidence.transactionAnnotations.map { ($0.parserTransactionID, $0) })
        let transactionEvidence = try zip(financialDocument.transactions, payload.transactions).map { source, transaction in
            guard let annotation = annotations[source.id] else {
                throw ImportPersistenceError.missingTransactionProvenance
            }
            let sectionID = annotation.documentScopedSectionID
            let instrumentID: String?
            switch annotation.financialScope {
            case .accountLevel:
                instrumentID = nil
            case .instrument:
                guard let sectionID, let selected = selectedInstrumentIDs[sectionID] else {
                    throw ImportPersistenceError.conflictingTransactionProvenance
                }
                instrumentID = selected
            }
            return CardTransactionEvidenceDTO(
                id: "card-transaction-evidence-\(transaction.id.lowercased())",
                cardStatementId: statementID,
                transactionId: transaction.id,
                rowScopeCode: annotation.financialScope.persistenceCode,
                instrumentId: instrumentID,
                liabilityEffectCode: annotation.liabilityEffect.rawValue,
                sourceTransactionDateISO: annotation.sourceTransactionDate.canonical,
                documentScopedSectionId: sectionID,
                originalCurrency: annotation.originalMerchantMoney?.currency.code,
                originalAmountMinor: try annotation.originalMerchantMoney.map { try $0.minorUnits() },
                originalAmountDecimal: try annotation.originalMerchantMoney.map { try $0.canonicalDecimalString() },
                summaryMembershipCode: annotation.summaryMembership?.rawValue
            )
        }
        let semanticProjection: CardStatementSemanticProjectionDTO?
        if isAmex || isAxis {
            let projectionID = "card-semantic-projection-\(payload.importSession.id.lowercased())"
            let projectionSections = sectionDecisions.map { decision in
            CardStatementSemanticProjectionSectionDTO(
                id: "\(projectionID)-section-\(decision.section.sourceOrdinal)",
                projectionId: projectionID,
                sourceOrdinal: decision.section.sourceOrdinal,
                documentScopedSectionId: decision.section.documentScopedSectionId,
                signedTotalCurrency: decision.section.signedTotalCurrency,
                signedTotalMinor: decision.section.signedTotalMinor,
                signedTotalDecimal: decision.section.signedTotalDecimal,
                reconciliationRuleCode: decision.section.reconciliationRuleCode
            )
        }
            let sectionOrdinals = Dictionary(uniqueKeysWithValues: projectionSections.map {
                ($0.documentScopedSectionId, $0.sourceOrdinal)
            })
            let projectionEvents = try zip(financialDocument.transactions, zip(payload.transactions, transactionEvidence)).map {
            source, pair -> CardStatementSemanticProjectionEventPlanDTO in
            let (transaction, persistedEvidence) = pair
            guard let provenance = source.sourceProvenance.first,
                  source.sourceProvenance.count == 1,
                  let normalizedRow = transaction.rawRows.first,
                  transaction.rawRows.count == 1,
                  normalizedRow.sourceOrdinal == provenance.sourceOrdinal,
                  let financialDate = source.statementDate else {
                throw ImportPersistenceError.missingTransactionProvenance
            }
            return CardStatementSemanticProjectionEventPlanDTO(
                incomingTransactionId: transaction.id,
                normalizedRowId: normalizedRow.normalizedRowId,
                sourceOrdinal: provenance.sourceOrdinal,
                financialDateISO: financialDate.canonical,
                financialDateRoleCode: source.financialDateRole.rawValue,
                sourceTransactionDateISO: persistedEvidence.sourceTransactionDateISO,
                liabilityEffectCode: persistedEvidence.liabilityEffectCode,
                postedCurrency: source.money.currency.code,
                postedAmountMinor: try source.money.minorUnits(),
                postedAmountDecimal: try source.money.canonicalDecimalString(),
                originalCurrency: persistedEvidence.originalCurrency,
                originalAmountMinor: persistedEvidence.originalAmountMinor,
                originalAmountDecimal: persistedEvidence.originalAmountDecimal,
                sourceReference: source.reference,
                rowScopeCode: persistedEvidence.rowScopeCode,
                documentScopedSectionId: persistedEvidence.documentScopedSectionId,
                documentSectionOrdinal: persistedEvidence.documentScopedSectionId.flatMap { sectionOrdinals[$0] }
            )
            }.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            let provisionalProjection = CardStatementSemanticProjectionDTO(
            id: projectionID,
            algorithmIdentifier: isAxis
                ? CardStatementSemanticProjectionDTO.axisMultisetAlgorithm
                : CardStatementSemanticProjectionDTO.amexAlgorithm,
            digest: String(repeating: "0", count: 64),
            institutionCode: (isAxis ? Institution.axis : Institution.amex).rawValue,
            statementFamilyCode: isAxis ? "axis.credit-card@1" : "amex.credit-card.pdf@1",
            parserProfileId: payload.normalizedDocument.profileId,
            parserProfileVersion: payload.normalizedDocument.profileVersion,
            statementDateISO: statement.statementDateISO,
            statementStartDateISO: statement.statementStartDateISO,
            statementEndDateISO: statement.statementEndDateISO,
            selectedStatementMonthISO: statement.selectedStatementMonthISO,
            cycleMonthISO: cycleMonthISO,
            nativeCurrency: statement.statementCurrency,
            reconciliationRuleCode: statement.reconciliationRuleCode,
            summaryComponents: summary,
            sections: projectionSections,
            events: projectionEvents
        )
            let projection = CardStatementSemanticProjectionDTO(
            id: provisionalProjection.id,
            algorithmIdentifier: provisionalProjection.algorithmIdentifier,
            digest: provisionalProjection.calculatedDigest(),
            institutionCode: provisionalProjection.institutionCode,
            statementFamilyCode: provisionalProjection.statementFamilyCode,
            parserProfileId: provisionalProjection.parserProfileId,
            parserProfileVersion: provisionalProjection.parserProfileVersion,
            statementDateISO: provisionalProjection.statementDateISO,
            statementStartDateISO: provisionalProjection.statementStartDateISO,
            statementEndDateISO: provisionalProjection.statementEndDateISO,
            selectedStatementMonthISO: provisionalProjection.selectedStatementMonthISO,
            cycleMonthISO: provisionalProjection.cycleMonthISO,
            nativeCurrency: provisionalProjection.nativeCurrency,
            reconciliationRuleCode: provisionalProjection.reconciliationRuleCode,
            summaryComponents: provisionalProjection.summaryComponents,
            sections: provisionalProjection.sections,
            events: provisionalProjection.events
            )
            guard projection.isValid() else {
                throw ImportPersistenceError.conflictingTransactionProvenance
            }
            semanticProjection = projection
        } else {
            semanticProjection = nil
        }
        let firstDecision = sectionDecisions.first
        let legacyInstrumentObservations: [CardSourceIdentityObservationDTO]
        if sectionCount == 1, let firstDecision {
            legacyInstrumentObservations = zip(
                evidence.instrumentSections[0].sourceIdentityObservations,
                firstDecision.sourceObservations
            ).map { observation, sectionObservation in
                CardSourceIdentityObservationDTO(
                    id: "card-observation-\(payload.importSession.id.lowercased())-instrument-\(observation.kind.rawValue)",
                    workspaceId: sectionObservation.workspaceId,
                    documentId: sectionObservation.documentId,
                    importSessionId: sectionObservation.importSessionId,
                    normalizedDocumentId: sectionObservation.normalizedDocumentId,
                    parserProfileId: sectionObservation.parserProfileId,
                    parserProfileVersion: sectionObservation.parserProfileVersion,
                    subjectKind: observation.subject.rawValue,
                    subjectId: firstDecision.section.instrumentId,
                    observationKind: observation.kind.rawValue,
                    sourceValue: observation.value,
                    associationAuthority: sectionObservation.associationAuthority,
                    createdAtISO: sectionObservation.createdAtISO
                )
            }
        } else {
            legacyInstrumentObservations = []
        }
        return ConfirmedCardImportPlanDTO(
            liabilityAccountId: selectedAccountId,
            instrumentChoice: firstDecision?.instrumentChoice ?? .unspecified,
            proposedInstrument: firstDecision?.proposedInstrument,
            sourceObservations: accountObservations + legacyInstrumentObservations,
            relationships: sectionDecisions.flatMap(\.relationships),
            statement: statement,
            summaryComponents: summary,
            transactionEvidence: transactionEvidence,
            sectionDecisions: sectionDecisions,
            semanticProjection: semanticProjection
        )
    }

    private func statementFinancialProjectionDTO(
        financialDocument: FinancialDocument,
        normalizedDocument: NormalizedDocumentDTO,
        importSessionID: String
    ) throws -> StatementFinancialProjectionDTO? {
        guard financialDocument.metadata.institution == .hdfc,
              financialDocument.metadata.documentType == .bankAccount,
              [.pdf, .xls].contains(financialDocument.metadata.fileFormat) else {
            return nil
        }
        let projection = try StatementFinancialProjection.make(from: financialDocument)
        let sourceFormatCode = financialDocument.metadata.fileFormat == .pdf ? "pdf" : "xls"
        let projectionID = "statement-projection-\(importSessionID.lowercased())"
        let events = try projection.events.map { event in
            StatementFinancialProjectionEventDTO(
                id: "\(projectionID)-event-\(event.ordinal)",
                ordinal: event.ordinal,
                statementDateISO: event.statementDate.canonical,
                valueDateISO: event.valueDate.canonical,
                direction: event.direction.rawValue,
                signedAmountMinor: try event.signedAmount.minorUnits(),
                signedAmountDecimal: try event.signedAmount.canonicalDecimalString(),
                runningBalanceMinor: try event.runningBalance.minorUnits(),
                runningBalanceDecimal: try event.runningBalance.canonicalDecimalString(),
                reference: event.reference
            )
        }
        let dto = StatementFinancialProjectionDTO(
            id: projectionID,
            digest: projection.digest,
            institutionCode: projection.institutionCode,
            statementFamilyCode: projection.statementFamilyCode,
            parserProfileID: normalizedDocument.profileId,
            parserProfileVersion: normalizedDocument.profileVersion,
            sourceFormatCode: sourceFormatCode,
            statementStartDateISO: projection.statementPeriod.start.canonical,
            statementEndDateISO: projection.statementPeriod.end.canonical,
            nativeCurrency: projection.nativeCurrency.code,
            eventCount: projection.eventCount,
            openingBalanceMinor: try projection.openingBalance.minorUnits(),
            openingBalanceDecimal: try projection.openingBalance.canonicalDecimalString(),
            debitCount: projection.debitCount,
            creditCount: projection.creditCount,
            debitTotalMinor: try projection.debitTotal.minorUnits(),
            debitTotalDecimal: try projection.debitTotal.canonicalDecimalString(),
            creditTotalMinor: try projection.creditTotal.minorUnits(),
            creditTotalDecimal: try projection.creditTotal.canonicalDecimalString(),
            closingBalanceMinor: try projection.closingBalance.minorUnits(),
            closingBalanceDecimal: try projection.closingBalance.canonicalDecimalString(),
            events: events
        )
        guard dto.isValid() else {
            throw ImportPersistenceError.conflictingTransactionProvenance
        }
        return dto
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
        documentCurrency: String,
        normalizedDocumentID: String,
        importSessionID: String
    ) throws -> TransactionDTO {
        guard let postedDate = transaction.statementDate else {
            throw ImportPersistenceError.missingTransactionDate(transaction.id)
        }
        guard !transaction.sourceProvenance.isEmpty else { throw ImportPersistenceError.missingTransactionProvenance }

        let direction: String
        if let cardEffect = transaction.cardLiabilityEffect,
           transaction.debitMoney == nil, transaction.creditMoney == nil {
            direction = cardEffect.rawValue
        } else if transaction.debitMoney != nil {
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
            postedDateISO: postedDate.canonical,
            financialDateRole: transaction.financialDateRole.rawValue,
            statementTimezoneEvidence: transaction.statementTimezoneEvidence.persistenceCode,
            valueDateISO: transaction.valueDate?.canonical,
            description: transaction.description,
            payee: nil,
            reference: transaction.reference,
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
            rawRows: transaction.sourceProvenance.map { provenance in
                TransactionRawRowDTO(
                    id: "transaction-source-\(transaction.id.uuidString.lowercased())-\(provenance.sourceOrdinal)",
                    normalizedRowId: "normalized-row-\(importSessionID.lowercased())-\(provenance.sourceOrdinal)",
                    contributionType: "transaction",
                    sourceOrdinal: provenance.sourceOrdinal,
                    normalizedRecordDigest: provenance.normalizedRecordDigest,
                    normalizedDocumentId: normalizedDocumentID,
                    parserProfileId: provenance.parserProfileID,
                    parserProfileVersion: provenance.parserProfileVersion
                )
            }
        )
    }

    private func requiredParserProfile(
        from transactions: [Transaction]
    ) throws -> (id: String, version: String) {
        guard !transactions.isEmpty else {
            throw ImportPersistenceError.missingParserProfileProvenance
        }

        var profiles: Set<ParserProfilePair> = []
        for transaction in transactions {
            guard !transaction.sourceProvenance.isEmpty else {
                throw ImportPersistenceError.missingParserProfileProvenance
            }
            for provenance in transaction.sourceProvenance {
                let id = provenance.parserProfileID
                let version = provenance.parserProfileVersion
                guard !id.isEmpty, !version.isEmpty else {
                    throw ImportPersistenceError.missingParserProfileProvenance
                }
                guard id == id.trimmingCharacters(in: .whitespacesAndNewlines),
                      version == version.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    throw ImportPersistenceError.malformedParserProfileProvenance
                }
                profiles.insert(ParserProfilePair(id: id, version: version))
            }
        }

        guard profiles.count == 1, let profile = profiles.first else {
            throw ImportPersistenceError.conflictingParserProfileProvenance
        }
        return (profile.id, profile.version)
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

}

private struct ParserProfilePair: Hashable {
    let id: String
    let version: String
}
