// Bounded provider-owned contract for one accepted confirmed import.

import CryptoKit
import Foundation

/// Opaque provider identity captured with a prepared import. It has no display
/// representation and is compared only for equality.
public struct ProviderGenerationToken: nonisolated Equatable, Hashable, Sendable {
    fileprivate let value: UUID
    public init() { value = UUID() }
}

public enum ConfirmedImportAccountChoiceDTO: nonisolated Equatable, Sendable {
    case unspecified
    case createProposedAccount
    case useExistingAccount(accountId: String)
}

public enum ConfirmedImportAdvisoryIdentityDTO: nonisolated Equatable, Sendable {
    case resolved(accountId: String)
    case noMatch
    case ambiguous
    case conflict
}

public struct ConfirmedImportIdentifierCandidateDTO: nonisolated Equatable, Sendable {
    public let scheme: String
    public let normalizedValue: String
    public let provenanceCode: String

    public init(scheme: String, normalizedValue: String, provenanceCode: String) {
        self.scheme = scheme
        self.normalizedValue = normalizedValue
        self.provenanceCode = provenanceCode
    }
}

public struct CBQSourceIdentityPatternDTO: nonisolated Equatable, Sendable {
    public let kind: String
    public let pattern: String

    public init(kind: String, pattern: String) {
        self.kind = kind
        self.pattern = pattern
    }
}

public struct CBQSourceIdentityRecordDTO: nonisolated Equatable, Sendable {
    public let accountId: String
    public let kind: String
    public let pattern: String

    public init(accountId: String, kind: String, pattern: String) {
        self.accountId = accountId
        self.kind = kind
        self.pattern = pattern
    }
}

public struct CBQSourceRowDTO: nonisolated Equatable, Sendable {
    public let incomingTransactionId: String
    public let normalizedRowId: String
    public let sourceOrdinal: Int
    public let normalizedRecordDigest: String
    public let postingDateISO: String
    public let sourceTransactionDateISO: String?
    public let nativeCurrency: String
    public let signedAmountMinor: Int64
    public let signedAmountDecimal: String
    public let direction: String
    public let runningBalanceMinor: Int64
    public let runningBalanceDecimal: String
    public let structuredReferenceDigest: String?

    public init(incomingTransactionId: String, normalizedRowId: String, sourceOrdinal: Int, normalizedRecordDigest: String, postingDateISO: String, sourceTransactionDateISO: String?, nativeCurrency: String, signedAmountMinor: Int64, signedAmountDecimal: String, direction: String, runningBalanceMinor: Int64, runningBalanceDecimal: String, structuredReferenceDigest: String?) {
        self.incomingTransactionId = incomingTransactionId
        self.normalizedRowId = normalizedRowId
        self.sourceOrdinal = sourceOrdinal
        self.normalizedRecordDigest = normalizedRecordDigest
        self.postingDateISO = postingDateISO
        self.sourceTransactionDateISO = sourceTransactionDateISO
        self.nativeCurrency = nativeCurrency
        self.signedAmountMinor = signedAmountMinor
        self.signedAmountDecimal = signedAmountDecimal
        self.direction = direction
        self.runningBalanceMinor = runningBalanceMinor
        self.runningBalanceDecimal = runningBalanceDecimal
        self.structuredReferenceDigest = structuredReferenceDigest
    }
}

public struct CBQStatementSourceEvidenceDTO: nonisolated Equatable, Sendable {
    public let sourceFormatCode: String
    public let statementBoundaryDateISO: String?
    public let statementStartDateISO: String?
    public let statementEndDateISO: String?
    public let openingBalanceMinor: Int64?
    public let openingBalanceDecimal: String?
    public let closingBalanceMinor: Int64?
    public let closingBalanceDecimal: String?

    public init(sourceFormatCode: String, statementBoundaryDateISO: String? = nil, statementStartDateISO: String? = nil, statementEndDateISO: String? = nil, openingBalanceMinor: Int64? = nil, openingBalanceDecimal: String? = nil, closingBalanceMinor: Int64? = nil, closingBalanceDecimal: String? = nil) {
        self.sourceFormatCode = sourceFormatCode
        self.statementBoundaryDateISO = statementBoundaryDateISO
        self.statementStartDateISO = statementStartDateISO
        self.statementEndDateISO = statementEndDateISO
        self.openingBalanceMinor = openingBalanceMinor
        self.openingBalanceDecimal = openingBalanceDecimal
        self.closingBalanceMinor = closingBalanceMinor
        self.closingBalanceDecimal = closingBalanceDecimal
    }
}

public enum ConfirmedCardInstrumentChoiceDTO: nonisolated Equatable, Sendable {
    case unspecified
    case createProposedInstrument
    case useExistingInstrument(instrumentId: String)
}

public struct ConfirmedCardImportPlanDTO: nonisolated Equatable, Sendable {
    public let liabilityAccountId: String
    public let instrumentChoice: ConfirmedCardInstrumentChoiceDTO
    public let proposedInstrument: CardInstrumentDTO
    public let instrumentIdentifiers: [CardInstrumentIdentifierDTO]
    public let sourceObservations: [CardSourceIdentityObservationDTO]
    public let relationships: [CardInstrumentRelationshipDTO]
    public let statement: CardStatementDTO
    public let summaryComponents: [CardStatementSummaryComponentDTO]
    public let transactionEvidence: [CardTransactionEvidenceDTO]

    public init(
        liabilityAccountId: String,
        instrumentChoice: ConfirmedCardInstrumentChoiceDTO,
        proposedInstrument: CardInstrumentDTO,
        instrumentIdentifiers: [CardInstrumentIdentifierDTO] = [],
        sourceObservations: [CardSourceIdentityObservationDTO],
        relationships: [CardInstrumentRelationshipDTO] = [],
        statement: CardStatementDTO,
        summaryComponents: [CardStatementSummaryComponentDTO],
        transactionEvidence: [CardTransactionEvidenceDTO]
    ) {
        self.liabilityAccountId = liabilityAccountId
        self.instrumentChoice = instrumentChoice
        self.proposedInstrument = proposedInstrument
        self.instrumentIdentifiers = instrumentIdentifiers
        self.sourceObservations = sourceObservations
        self.relationships = relationships
        self.statement = statement
        self.summaryComponents = summaryComponents
        self.transactionEvidence = transactionEvidence
    }
}

/// Parser-produced, transient evidence transported only until the confirmed
/// provider has selected the final durable account. It is deliberately not a
/// persistence DTO and must never be serialized into history or diagnostics.
public enum ConfirmedImportTransactionEventEvidenceDTO: nonisolated Equatable, Sendable {
    case axisUPI(ConfirmedImportAxisUPIEventEvidenceDTO)
}

public struct ConfirmedImportAxisUPIEventEvidenceDTO: nonisolated Equatable, Sendable {
    public enum Operation: String, nonisolated Equatable, Sendable {
        case p2a
        case p2m
    }

    public enum LedgerSubtype: String, nonisolated Equatable, Sendable {
        case posting
        case creditAdjustment = "credit-adjustment"
    }

    public let operation: Operation
    public let reference: String
    public let subtype: LedgerSubtype

    public nonisolated init(operation: Operation, reference: String, subtype: LedgerSubtype) {
        self.operation = operation
        self.reference = reference
        self.subtype = subtype
    }
}

/// Account-independent input. The provider assigns the final account before it
/// derives any event identity.
public struct ConfirmedImportTransactionTemplateDTO: nonisolated Equatable, Sendable {
    public let transaction: TransactionDTO
    public let eventEvidence: ConfirmedImportTransactionEventEvidenceDTO?

    public init(
        transaction: TransactionDTO,
        eventEvidence: ConfirmedImportTransactionEventEvidenceDTO? = nil
    ) {
        self.transaction = transaction
        self.eventEvidence = eventEvidence
    }

    /// Providers reject preassigned transactions instead of accepting a
    /// caller-supplied durable account or an already-derived event identity.
    public var isAccountIndependent: Bool { transaction.accountId == nil }
}

public struct IdentifierObservationDTO: nonisolated Equatable, Sendable {
    public let ownershipId: String
    public let importSessionId: String
    public let documentId: String
    public let parserProvenanceCode: String
    public let associationAuthorityCode: String
    public let createdAtISO: String

    public init(ownershipId: String, importSessionId: String, documentId: String, parserProvenanceCode: String, associationAuthorityCode: String, createdAtISO: String) {
        self.ownershipId = ownershipId
        self.importSessionId = importSessionId
        self.documentId = documentId
        self.parserProvenanceCode = parserProvenanceCode
        self.associationAuthorityCode = associationAuthorityCode
        self.createdAtISO = createdAtISO
    }
}

/// Account-independent history inputs. The provider composes the final
/// `AtomicImportHistoryDTO` only after it has resolved an account and derived
/// final transaction-event identities.
public struct ConfirmedImportHistoryTemplateDTO: nonisolated Equatable, Sendable {
    public let document: ImportedDocumentDTO
    public let fingerprints: [DocumentFingerprintDTO]
    public let importSession: ImportSessionDTO
    public let completedAtISO: String
    public let successfulAttempt: ImportAttemptDTO
    public let normalizedDocument: NormalizedDocumentDTO?
    public let normalizedRows: [NormalizedRowDTO]

    public init(
        document: ImportedDocumentDTO,
        fingerprints: [DocumentFingerprintDTO],
        importSession: ImportSessionDTO,
        completedAtISO: String,
        successfulAttempt: ImportAttemptDTO,
        normalizedDocument: NormalizedDocumentDTO? = nil,
        normalizedRows: [NormalizedRowDTO] = []
    ) {
        self.document = document
        self.fingerprints = fingerprints.sorted(by: Self.fingerprintOrder)
        self.importSession = importSession
        self.completedAtISO = completedAtISO
        self.successfulAttempt = successfulAttempt
        self.normalizedDocument = normalizedDocument
        self.normalizedRows = normalizedRows
    }

    public init(
        document: ImportedDocumentDTO,
        fingerprint: DocumentFingerprintDTO,
        importSession: ImportSessionDTO,
        completedAtISO: String,
        successfulAttempt: ImportAttemptDTO,
        normalizedDocument: NormalizedDocumentDTO? = nil,
        normalizedRows: [NormalizedRowDTO] = []
    ) {
        self.init(
            document: document,
            fingerprints: [fingerprint],
            importSession: importSession,
            completedAtISO: completedAtISO,
            successfulAttempt: successfulAttempt,
            normalizedDocument: normalizedDocument,
            normalizedRows: normalizedRows
        )
    }

    public var duplicateAuthorityFingerprint: DocumentFingerprintDTO? {
        let authorities = fingerprints.filter(\.isDuplicateAuthority)
        return authorities.count == 1 ? authorities[0] : nil
    }

    public var fingerprint: DocumentFingerprintDTO {
        duplicateAuthorityFingerprint ?? fingerprints[0]
    }

    public func validateFingerprints() throws {
        guard fingerprints.allSatisfy({ !$0.id.isEmpty }) else {
            throw DocumentFingerprintValidationError.emptyIdentifier
        }
        guard fingerprints.allSatisfy({
            $0.documentId == document.id && $0.importSessionId == importSession.id
        }) else {
            throw DocumentFingerprintValidationError.relationshipMismatch
        }
        guard fingerprints.allSatisfy({ DocumentFingerprintDTO.approvedAlgorithms.contains($0.algorithm) }) else {
            throw DocumentFingerprintValidationError.unsupportedAlgorithm
        }
        let lowercaseHex = CharacterSet(charactersIn: "0123456789abcdef")
        guard fingerprints.allSatisfy({ fingerprint in
            fingerprint.fingerprint.utf8.count == 64 &&
            fingerprint.fingerprint.unicodeScalars.allSatisfy(lowercaseHex.contains)
        }) else {
            throw DocumentFingerprintValidationError.malformedDigest
        }
        guard Set(fingerprints.map(\.id)).count == fingerprints.count else {
            throw DocumentFingerprintValidationError.duplicateIdentifier
        }
        guard Set(fingerprints.map(\.algorithm)).count == fingerprints.count else {
            throw DocumentFingerprintValidationError.duplicateAlgorithm
        }
        guard fingerprints.filter(\.isDuplicateAuthority).count == 1 else {
            throw DocumentFingerprintValidationError.invalidAuthorityCount
        }
    }

    nonisolated private static func fingerprintOrder(_ lhs: DocumentFingerprintDTO, _ rhs: DocumentFingerprintDTO) -> Bool {
        lhs.algorithm == rhs.algorithm ? lhs.id < rhs.id : lhs.algorithm < rhs.algorithm
    }
}

public enum DocumentFingerprintValidationError: Error, nonisolated Equatable, LocalizedError {
    case emptyIdentifier
    case relationshipMismatch
    case unsupportedAlgorithm
    case malformedDigest
    case duplicateIdentifier
    case duplicateAlgorithm
    case invalidAuthorityCount

    public var errorDescription: String? {
        switch self {
        case .emptyIdentifier: return "A document fingerprint identifier is missing."
        case .relationshipMismatch: return "Document fingerprint relationships are inconsistent."
        case .unsupportedAlgorithm: return "A document fingerprint algorithm is unsupported."
        case .malformedDigest: return "A document fingerprint digest is malformed."
        case .duplicateIdentifier: return "Document fingerprint identifiers must be unique."
        case .duplicateAlgorithm: return "A document fingerprint algorithm is duplicated."
        case .invalidAuthorityCount: return "Exactly one document fingerprint must be duplicate authority."
        }
    }
}

public struct StatementFinancialProjectionEventDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let ordinal: Int
    public let statementDateISO: String
    public let valueDateISO: String
    public let direction: String
    public let signedAmountMinor: Int64
    public let signedAmountDecimal: String
    public let runningBalanceMinor: Int64
    public let runningBalanceDecimal: String
    public let reference: String?

    public init(
        id: String,
        ordinal: Int,
        statementDateISO: String,
        valueDateISO: String,
        direction: String,
        signedAmountMinor: Int64,
        signedAmountDecimal: String,
        runningBalanceMinor: Int64,
        runningBalanceDecimal: String,
        reference: String?
    ) {
        self.id = id
        self.ordinal = ordinal
        self.statementDateISO = statementDateISO
        self.valueDateISO = valueDateISO
        self.direction = direction
        self.signedAmountMinor = signedAmountMinor
        self.signedAmountDecimal = signedAmountDecimal
        self.runningBalanceMinor = runningBalanceMinor
        self.runningBalanceDecimal = runningBalanceDecimal
        self.reference = reference
    }
}

public struct StatementFinancialProjectionDTO: nonisolated Equatable, Sendable {
    public static let algorithm = "ledgerforge.statement-financial-projection.sha256.v1"

    public let id: String
    public let algorithmIdentifier: String
    public let digest: String
    public let institutionCode: String
    public let statementFamilyCode: String
    public let parserProfileID: String
    public let parserProfileVersion: String
    public let sourceFormatCode: String
    public let statementStartDateISO: String
    public let statementEndDateISO: String
    public let nativeCurrency: String
    public let eventCount: Int
    public let openingBalanceMinor: Int64
    public let openingBalanceDecimal: String
    public let debitCount: Int
    public let creditCount: Int
    public let debitTotalMinor: Int64
    public let debitTotalDecimal: String
    public let creditTotalMinor: Int64
    public let creditTotalDecimal: String
    public let closingBalanceMinor: Int64
    public let closingBalanceDecimal: String
    public let events: [StatementFinancialProjectionEventDTO]

    public init(
        id: String,
        algorithmIdentifier: String = Self.algorithm,
        digest: String,
        institutionCode: String,
        statementFamilyCode: String,
        parserProfileID: String,
        parserProfileVersion: String,
        sourceFormatCode: String,
        statementStartDateISO: String,
        statementEndDateISO: String,
        nativeCurrency: String,
        eventCount: Int,
        openingBalanceMinor: Int64,
        openingBalanceDecimal: String,
        debitCount: Int,
        creditCount: Int,
        debitTotalMinor: Int64,
        debitTotalDecimal: String,
        creditTotalMinor: Int64,
        creditTotalDecimal: String,
        closingBalanceMinor: Int64,
        closingBalanceDecimal: String,
        events: [StatementFinancialProjectionEventDTO]
    ) {
        self.id = id
        self.algorithmIdentifier = algorithmIdentifier
        self.digest = digest
        self.institutionCode = institutionCode
        self.statementFamilyCode = statementFamilyCode
        self.parserProfileID = parserProfileID
        self.parserProfileVersion = parserProfileVersion
        self.sourceFormatCode = sourceFormatCode
        self.statementStartDateISO = statementStartDateISO
        self.statementEndDateISO = statementEndDateISO
        self.nativeCurrency = nativeCurrency
        self.eventCount = eventCount
        self.openingBalanceMinor = openingBalanceMinor
        self.openingBalanceDecimal = openingBalanceDecimal
        self.debitCount = debitCount
        self.creditCount = creditCount
        self.debitTotalMinor = debitTotalMinor
        self.debitTotalDecimal = debitTotalDecimal
        self.creditTotalMinor = creditTotalMinor
        self.creditTotalDecimal = creditTotalDecimal
        self.closingBalanceMinor = closingBalanceMinor
        self.closingBalanceDecimal = closingBalanceDecimal
        self.events = events.sorted { $0.ordinal < $1.ordinal }
    }

    public func isValid() -> Bool {
        let lowercaseHex = CharacterSet(charactersIn: "0123456789abcdef")
        guard algorithmIdentifier == Self.algorithm,
              digest.utf8.count == 64,
              digest.unicodeScalars.allSatisfy(lowercaseHex.contains),
              institutionCode == "hdfc",
              statementFamilyCode == "hdfc.bank-account",
              ["hdfc.bank-account.pdf", "hdfc.bank-account.xls"].contains(parserProfileID),
              parserProfileVersion == "1",
              ["pdf", "xls"].contains(sourceFormatCode),
              parserProfileID.hasSuffix(".\(sourceFormatCode)"),
              !id.isEmpty,
              !events.isEmpty,
              eventCount == events.count,
              eventCount == debitCount + creditCount,
              debitCount >= 0,
              creditCount >= 0,
              events.map(\.ordinal) == Array(1...events.count),
              (try? StatementDate(canonical: statementStartDateISO)) != nil,
              (try? StatementDate(canonical: statementEndDateISO)) != nil,
              statementStartDateISO <= statementEndDateISO,
              (try? CurrencyCode(nativeCurrency)) != nil,
              moneyMatches(openingBalanceDecimal, minor: openingBalanceMinor),
              moneyMatches(debitTotalDecimal, minor: debitTotalMinor),
              moneyMatches(creditTotalDecimal, minor: creditTotalMinor),
              moneyMatches(closingBalanceDecimal, minor: closingBalanceMinor),
              debitTotalMinor >= 0,
              creditTotalMinor >= 0 else { return false }

        var computedDebitCount = 0
        var computedCreditCount = 0
        var computedDebitTotal: Int64 = 0
        var computedCreditTotal: Int64 = 0
        for event in events {
            guard !event.id.isEmpty,
                  (try? StatementDate(canonical: event.statementDateISO)) != nil,
                  (try? StatementDate(canonical: event.valueDateISO)) != nil,
                  moneyMatches(event.signedAmountDecimal, minor: event.signedAmountMinor),
                  moneyMatches(event.runningBalanceDecimal, minor: event.runningBalanceMinor) else {
                return false
            }
            switch event.direction {
            case "debit":
                guard event.signedAmountMinor < 0 else { return false }
                computedDebitCount += 1
                let magnitude = Int64.zero.subtractingReportingOverflow(event.signedAmountMinor)
                guard !magnitude.overflow else { return false }
                let addition = computedDebitTotal.addingReportingOverflow(magnitude.partialValue)
                guard !addition.overflow else { return false }
                computedDebitTotal = addition.partialValue
            case "credit":
                guard event.signedAmountMinor > 0 else { return false }
                computedCreditCount += 1
                let addition = computedCreditTotal.addingReportingOverflow(event.signedAmountMinor)
                guard !addition.overflow else { return false }
                computedCreditTotal = addition.partialValue
            default:
                return false
            }
        }
        guard let firstEvent = events.first else { return false }
        let derivedOpening = firstEvent.runningBalanceMinor.subtractingReportingOverflow(
            firstEvent.signedAmountMinor
        )
        guard !derivedOpening.overflow,
              computedDebitCount == debitCount,
              computedCreditCount == creditCount,
              computedDebitTotal == debitTotalMinor,
              computedCreditTotal == creditTotalMinor,
              events.last?.runningBalanceMinor == closingBalanceMinor,
              derivedOpening.partialValue == openingBalanceMinor else {
            return false
        }
        return digest == calculatedDigest()
    }

    private func moneyMatches(_ decimal: String, minor: Int64) -> Bool {
        guard let money = try? Money(canonicalDecimal: decimal, currency: nativeCurrency),
              let exactMinor = try? money.minorUnits() else { return false }
        return exactMinor == minor
    }

    private func calculatedDigest() -> String {
        var fields = [
            algorithmIdentifier,
            institutionCode,
            statementFamilyCode,
            statementStartDateISO,
            statementEndDateISO,
            nativeCurrency,
            String(eventCount),
            openingBalanceDecimal,
            String(debitCount),
            String(creditCount),
            debitTotalDecimal,
            creditTotalDecimal,
            closingBalanceDecimal
        ]
        for event in events {
            fields.append(contentsOf: [
                String(event.ordinal),
                event.statementDateISO,
                event.valueDateISO,
                event.direction,
                nativeCurrency,
                event.signedAmountDecimal,
                nativeCurrency,
                event.runningBalanceDecimal,
                event.reference == nil ? "0" : "1",
                event.reference ?? ""
            ])
        }
        let payload = fields.map { "\($0.utf8.count):\($0)" }.joined()
        return SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public enum StatementEquivalenceMemberRole: String, nonisolated Equatable, Sendable {
    case authoritative
    case supporting
}

public struct StatementFinancialProjectionRecordDTO: nonisolated Equatable, Sendable {
    public let projection: StatementFinancialProjectionDTO
    public let workspaceID: String
    public let accountID: String
    public let documentID: String
    public let importSessionID: String
    public let createdAtISO: String
}

public struct StatementEquivalenceGroupDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceID: String
    public let accountID: String
    public let institutionCode: String
    public let statementFamilyCode: String
    public let statementStartDateISO: String
    public let statementEndDateISO: String
    public let nativeCurrency: String
    public let projectionAlgorithm: String
    public let projectionDigest: String
    public let authoritativeProjectionID: String
    public let createdAtISO: String
}

public struct StatementEquivalenceMemberDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let groupID: String
    public let projectionID: String
    public let role: StatementEquivalenceMemberRole
    public let sourceFormatCode: String
    public let createdAtISO: String
}

public enum StatementEquivalenceReviewResult: nonisolated Equatable, Sendable {
    case notApplicable
    case firstAcceptedSource
    case equivalent(authoritativeImportSessionID: String)
    case conflict
    case evidenceUnavailable
    case formatAlreadyRecorded
}

public struct ConfirmedImportPlanDTO: nonisolated Equatable, Sendable {
    public let providerGeneration: ProviderGenerationToken
    public let workspace: WorkspaceDTO
    public let proposedAccount: AccountDTO
    public let accountChoice: ConfirmedImportAccountChoiceDTO
    public let advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO
    public let identifiers: [ConfirmedImportIdentifierCandidateDTO]
    public let historyTemplate: ConfirmedImportHistoryTemplateDTO
    public let transactionTemplates: [ConfirmedImportTransactionTemplateDTO]
    public let declaredStatementStartISO: String?
    public let declaredStatementEndISO: String?
    public let openingBalanceMinor: Int64?
    public let openingBalanceDecimal: String?
    public let closingBalanceMinor: Int64?
    public let closingBalanceDecimal: String?
    public let statementFinancialProjection: StatementFinancialProjectionDTO?
    public let cbqSourceIdentityPatterns: [CBQSourceIdentityPatternDTO]
    public let cbqSourceRows: [CBQSourceRowDTO]
    public let cbqStatementSourceEvidence: CBQStatementSourceEvidenceDTO?
    public let cardImportPlan: ConfirmedCardImportPlanDTO?

    public init(providerGeneration: ProviderGenerationToken, workspace: WorkspaceDTO, proposedAccount: AccountDTO, accountChoice: ConfirmedImportAccountChoiceDTO, advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO, identifiers: [ConfirmedImportIdentifierCandidateDTO], historyTemplate: ConfirmedImportHistoryTemplateDTO, transactionTemplates: [ConfirmedImportTransactionTemplateDTO], declaredStatementStartISO: String? = nil, declaredStatementEndISO: String? = nil, openingBalanceMinor: Int64? = nil, openingBalanceDecimal: String? = nil, closingBalanceMinor: Int64? = nil, closingBalanceDecimal: String? = nil, statementFinancialProjection: StatementFinancialProjectionDTO? = nil, cbqSourceIdentityPatterns: [CBQSourceIdentityPatternDTO] = [], cbqSourceRows: [CBQSourceRowDTO] = [], cbqStatementSourceEvidence: CBQStatementSourceEvidenceDTO? = nil, cardImportPlan: ConfirmedCardImportPlanDTO? = nil) {
        self.providerGeneration = providerGeneration
        self.workspace = workspace
        self.proposedAccount = proposedAccount
        self.accountChoice = accountChoice
        self.advisoryIdentity = advisoryIdentity
        self.identifiers = identifiers
        self.historyTemplate = historyTemplate
        self.transactionTemplates = transactionTemplates
        self.declaredStatementStartISO = declaredStatementStartISO
        self.declaredStatementEndISO = declaredStatementEndISO
        self.openingBalanceMinor = openingBalanceMinor
        self.openingBalanceDecimal = openingBalanceDecimal
        self.closingBalanceMinor = closingBalanceMinor
        self.closingBalanceDecimal = closingBalanceDecimal
        self.statementFinancialProjection = statementFinancialProjection
        self.cbqSourceIdentityPatterns = cbqSourceIdentityPatterns
        self.cbqSourceRows = cbqSourceRows.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
        self.cbqStatementSourceEvidence = cbqStatementSourceEvidence
        self.cardImportPlan = cardImportPlan
    }
}

public enum CBQSourceOverlapDisposition: String, nonisolated Equatable, Sendable {
    case new
    case representedExisting = "represented-existing"
}

public struct ReviewedCBQSourceOverlapRowDTO: nonisolated Equatable, Sendable {
    public let source: CBQSourceRowDTO
    public let disposition: CBQSourceOverlapDisposition
    public let expectedTransactionId: String?

    public init(source: CBQSourceRowDTO, disposition: CBQSourceOverlapDisposition, expectedTransactionId: String? = nil) {
        self.source = source
        self.disposition = disposition
        self.expectedTransactionId = expectedTransactionId
    }
}

public struct ReviewedCBQSourceOverlapPlanDTO: nonisolated Equatable, Sendable {
    public static let digestAlgorithm = "ledgerforge.cbq-source-overlap-plan.sha256.v1"
    public let id: String
    public let basePlan: ConfirmedImportPlanDTO
    public let accountId: String
    public let rows: [ReviewedCBQSourceOverlapRowDTO]
    public let newCount: Int
    public let representedCount: Int
    public let blockedCount: Int
    public let digest: String

    public init(id: String = UUID().uuidString, basePlan: ConfirmedImportPlanDTO, accountId: String, rows: [ReviewedCBQSourceOverlapRowDTO], newCount: Int, representedCount: Int, blockedCount: Int, digest: String? = nil) {
        self.id = id
        self.basePlan = basePlan
        self.accountId = accountId
        self.rows = rows.sorted { $0.source.sourceOrdinal < $1.source.sourceOrdinal }
        self.newCount = newCount
        self.representedCount = representedCount
        self.blockedCount = blockedCount
        self.digest = digest ?? Self.makeDigest(id: id, basePlan: basePlan, accountId: accountId, rows: self.rows, newCount: newCount, representedCount: representedCount, blockedCount: blockedCount)
    }

    public func hasValidDigest() -> Bool {
        digest == Self.makeDigest(id: id, basePlan: basePlan, accountId: accountId, rows: rows, newCount: newCount, representedCount: representedCount, blockedCount: blockedCount)
    }

    private static func makeDigest(id: String, basePlan: ConfirmedImportPlanDTO, accountId: String, rows: [ReviewedCBQSourceOverlapRowDTO], newCount: Int, representedCount: Int, blockedCount: Int) -> String {
        let normalized = basePlan.historyTemplate.normalizedDocument
        var values = [
            digestAlgorithm, id, basePlan.providerGeneration.value.uuidString.lowercased(),
            basePlan.workspace.id, accountId, normalized?.profileId ?? "", normalized?.profileVersion ?? "",
            basePlan.historyTemplate.document.id, basePlan.historyTemplate.importSession.id,
            String(newCount), String(representedCount), String(blockedCount)
        ]
        for fingerprint in basePlan.historyTemplate.fingerprints {
            values += [fingerprint.algorithm, fingerprint.fingerprint, fingerprint.isDuplicateAuthority ? "1" : "0"]
        }
        for identity in basePlan.cbqSourceIdentityPatterns.sorted(by: { $0.kind < $1.kind }) {
            values += [identity.kind, identity.pattern]
        }
        for row in rows {
            let source = row.source
            values += [source.incomingTransactionId, source.normalizedRowId, String(source.sourceOrdinal), source.normalizedRecordDigest,
                       source.postingDateISO, source.sourceTransactionDateISO ?? "", source.nativeCurrency,
                       String(source.signedAmountMinor), source.signedAmountDecimal, source.direction,
                       String(source.runningBalanceMinor), source.runningBalanceDecimal,
                       source.structuredReferenceDigest ?? "", row.disposition.rawValue, row.expectedTransactionId ?? ""]
        }
        let payload = values.map { "\($0.lengthOfBytes(using: .utf8)):\($0)" }.joined()
        return SHA256.hash(data: Data(payload.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public enum CBQSourceOverlapReviewResult: nonisolated Equatable, Sendable {
    case notApplicable
    case eligible(ReviewedCBQSourceOverlapPlanDTO)
    case accountChoiceRequired(compatibleAccountIds: [String])
    case identityConflict
    case staleProviderGeneration
    case blockedOrAmbiguousRows(count: Int)
    case repositoryIntegrityConflict
}

public enum PartialImportRowDisposition: String, nonisolated Equatable, Sendable {
    case recognizedExisting = "recognized_existing"
    case importedUnique = "imported_unique"
}

public struct ReviewedPartialImportRowDTO: nonisolated Equatable, Sendable {
    public let normalizedRowId: String
    public let sourceOrdinal: Int
    public let normalizedRecordDigest: String
    public let statementDateISO: String
    public let financialDateRole: String
    public let timezoneEvidence: String
    public let nativeCurrency: String
    public let amountMinor: Int64
    public let amountDecimal: String
    public let direction: String
    public let runningBalanceMinor: Int64
    public let eventAlgorithm: String
    public let eventDigest: String
    public let disposition: PartialImportRowDisposition
    public let expectedTransactionId: String?
    public let expectedEventIdentityId: String?

    public init(normalizedRowId: String, sourceOrdinal: Int, normalizedRecordDigest: String, statementDateISO: String, financialDateRole: String, timezoneEvidence: String, nativeCurrency: String, amountMinor: Int64, amountDecimal: String, direction: String, runningBalanceMinor: Int64, eventAlgorithm: String, eventDigest: String, disposition: PartialImportRowDisposition, expectedTransactionId: String? = nil, expectedEventIdentityId: String? = nil) {
        self.normalizedRowId = normalizedRowId
        self.sourceOrdinal = sourceOrdinal
        self.normalizedRecordDigest = normalizedRecordDigest
        self.statementDateISO = statementDateISO
        self.financialDateRole = financialDateRole
        self.timezoneEvidence = timezoneEvidence
        self.nativeCurrency = nativeCurrency
        self.amountMinor = amountMinor
        self.amountDecimal = amountDecimal
        self.direction = direction
        self.runningBalanceMinor = runningBalanceMinor
        self.eventAlgorithm = eventAlgorithm
        self.eventDigest = eventDigest
        self.disposition = disposition
        self.expectedTransactionId = expectedTransactionId
        self.expectedEventIdentityId = expectedEventIdentityId
    }
}

public struct ReviewedPartialImportPlanDTO: nonisolated Equatable, Sendable {
    public static let digestAlgorithm = "ledgerforge.partial-import-plan.sha256.v1"

    public let id: String
    public let basePlan: ConfirmedImportPlanDTO
    public let existingAccountId: String
    public let rows: [ReviewedPartialImportRowDTO]
    public let sourceRowCount: Int
    public let recognizedCount: Int
    public let importedCount: Int
    public let blockedCount: Int
    public let digestAlgorithm: String
    public let digest: String

    public init(id: String = UUID().uuidString, basePlan: ConfirmedImportPlanDTO, existingAccountId: String, rows: [ReviewedPartialImportRowDTO], sourceRowCount: Int, recognizedCount: Int, importedCount: Int, blockedCount: Int, digestAlgorithm: String = Self.digestAlgorithm, digest: String? = nil) {
        self.id = id
        self.basePlan = basePlan
        self.existingAccountId = existingAccountId
        self.rows = rows.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
        self.sourceRowCount = sourceRowCount
        self.recognizedCount = recognizedCount
        self.importedCount = importedCount
        self.blockedCount = blockedCount
        self.digestAlgorithm = digestAlgorithm
        self.digest = digest ?? Self.makeDigest(
            id: id,
            basePlan: basePlan,
            existingAccountId: existingAccountId,
            rows: self.rows,
            sourceRowCount: sourceRowCount,
            recognizedCount: recognizedCount,
            importedCount: importedCount,
            blockedCount: blockedCount,
            digestAlgorithm: digestAlgorithm
        )
    }

    public var uniqueRows: [ReviewedPartialImportRowDTO] {
        rows.filter { $0.disposition == .importedUnique }
    }

    public var recognizedRows: [ReviewedPartialImportRowDTO] {
        rows.filter { $0.disposition == .recognizedExisting }
    }

    public func hasValidDigest() -> Bool {
        digestAlgorithm == Self.digestAlgorithm &&
        digest == Self.makeDigest(
            id: id,
            basePlan: basePlan,
            existingAccountId: existingAccountId,
            rows: rows,
            sourceRowCount: sourceRowCount,
            recognizedCount: recognizedCount,
            importedCount: importedCount,
            blockedCount: blockedCount,
            digestAlgorithm: digestAlgorithm
        )
    }

    private static func makeDigest(id: String, basePlan: ConfirmedImportPlanDTO, existingAccountId: String, rows: [ReviewedPartialImportRowDTO], sourceRowCount: Int, recognizedCount: Int, importedCount: Int, blockedCount: Int, digestAlgorithm: String) -> String {
        let profile = basePlan.historyTemplate.normalizedDocument
        var components = [
            digestAlgorithm,
            id,
            basePlan.providerGeneration.value.uuidString.lowercased(),
            basePlan.workspace.id,
            existingAccountId,
            profile?.profileId ?? "",
            profile?.profileVersion ?? "",
            basePlan.declaredStatementStartISO ?? "",
            basePlan.declaredStatementEndISO ?? "",
            basePlan.proposedAccount.nativeCurrency,
            String(sourceRowCount),
            String(recognizedCount),
            String(importedCount),
            String(blockedCount),
            String(basePlan.openingBalanceMinor ?? 0),
            basePlan.openingBalanceDecimal ?? "",
            String(basePlan.closingBalanceMinor ?? 0),
            basePlan.closingBalanceDecimal ?? ""
        ]
        for fingerprint in basePlan.historyTemplate.fingerprints {
            components.append(contentsOf: [
                fingerprint.id,
                fingerprint.algorithm,
                fingerprint.fingerprint,
                fingerprint.isDuplicateAuthority ? "1" : "0",
                fingerprint.documentId,
                fingerprint.importSessionId
            ])
        }
        for row in rows.sorted(by: { $0.sourceOrdinal < $1.sourceOrdinal }) {
            components.append(contentsOf: [
                row.normalizedRowId,
                String(row.sourceOrdinal),
                row.normalizedRecordDigest,
                row.statementDateISO,
                row.financialDateRole,
                row.timezoneEvidence,
                row.nativeCurrency,
                String(row.amountMinor),
                row.amountDecimal,
                row.direction,
                String(row.runningBalanceMinor),
                row.eventAlgorithm,
                row.eventDigest,
                row.disposition.rawValue,
                row.expectedTransactionId ?? "",
                row.expectedEventIdentityId ?? ""
            ])
        }
        let payload = components.map { "\($0.lengthOfBytes(using: .utf8)):\($0)" }.joined()
        return SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public enum PartialImportReviewResult: nonisolated Equatable, Sendable {
    case ordinaryFullImport
    case fullSupportedOverlap(count: Int)
    case eligible(ReviewedPartialImportPlanDTO)
    case unsupportedEvidence
    case repeatedIncomingEvidence
    case ownershipConflict
    case repositoryIntegrityConflict
}

public struct ConfirmedImportReceiptDTO: nonisolated Equatable, Sendable {
    public let workspaceId: String
    public let accountId: String
    public let importSessionId: String
    public let documentId: String

    public init(workspaceId: String, accountId: String, importSessionId: String, documentId: String) {
        self.workspaceId = workspaceId
        self.accountId = accountId
        self.importSessionId = importSessionId
        self.documentId = documentId
    }
}

public enum ConfirmedImportRepositoryResult: nonisolated Equatable, Sendable, CustomStringConvertible {
    case committed(ConfirmedImportReceiptDTO)
    case equivalentSourceRecorded(ConfirmedImportReceiptDTO)
    case partialCommitted(ConfirmedImportReceiptDTO)
    case sourceOverlapCommitted(ConfirmedImportReceiptDTO, newTransactionCount: Int)
    case exactDuplicate
    case repeatedIncomingEventEvidence
    case existingEventDuplicate
    case eventOwnershipConflict
    case identityAmbiguous
    case identityConflict
    case explicitAccountChoiceRequired
    case selectedAccountUnavailable
    case selectedAccountIneligible
    case selectedAccountWorkspaceMismatch
    case identifierOwnershipConflict
    case staleIdentityDecision
    case staleProviderGeneration
    case reviewedPartialPlanStale
    case statementEquivalenceConflict
    case statementEquivalenceEvidenceUnavailable
    case equivalentFormatAlreadyRecorded
    case repositoryIntegrityConflict
    case retryableContention
    case persistenceUnavailable

    public var description: String {
        switch self {
        case .committed: return "Confirmed import committed."
        case .equivalentSourceRecorded: return "Equivalent supporting source recorded."
        case .partialCommitted: return "Reviewed partial import committed."
        case .sourceOverlapCommitted: return "Reviewed CBQ source overlap committed."
        case .exactDuplicate: return "The statement was already imported."
        case .repeatedIncomingEventEvidence: return "Incoming transaction evidence conflicts within this import."
        case .existingEventDuplicate: return "A supported transaction event already exists."
        case .eventOwnershipConflict: return "Supported transaction event ownership conflicts."
        case .identityAmbiguous: return "Account identity is ambiguous."
        case .identityConflict: return "Account identity conflicts."
        case .explicitAccountChoiceRequired: return "An explicit account choice is required."
        case .selectedAccountUnavailable: return "The selected account is unavailable."
        case .selectedAccountIneligible: return "The selected account is not eligible."
        case .selectedAccountWorkspaceMismatch: return "The selected account does not belong to this workspace."
        case .identifierOwnershipConflict: return "Account ownership conflicts."
        case .staleIdentityDecision: return "The prepared account decision is no longer current."
        case .staleProviderGeneration: return "The persistence provider changed before confirmation."
        case .reviewedPartialPlanStale: return "The reviewed partial-import plan is no longer current."
        case .statementEquivalenceConflict: return "Exact statement equivalence conflicts."
        case .statementEquivalenceEvidenceUnavailable: return "Exact statement equivalence evidence is unavailable."
        case .equivalentFormatAlreadyRecorded: return "This statement format is already represented."
        case .repositoryIntegrityConflict: return "Repository integrity prevented confirmation."
        case .retryableContention: return "Persistence is busy; retry confirmation."
        case .persistenceUnavailable: return "Persistence is unavailable."
        }
    }
}

enum ReviewedPartialImportPlanner {
    static func review(
        _ plan: ConfirmedImportPlanDTO,
        account: AccountDTO?,
        owners: [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO],
        transactionsByID: [String: TransactionDTO],
        planID: String = UUID().uuidString
    ) -> PartialImportReviewResult {
        guard case .useExistingAccount(let accountID) = plan.accountChoice,
              let account,
              account.id == accountID,
              account.workspaceId == plan.workspace.id,
              account.nativeCurrency == "INR",
              plan.proposedAccount.nativeCurrency == "INR",
              let normalizedDocument = plan.historyTemplate.normalizedDocument,
              normalizedDocument.profileId == "axis.bank-account.csv",
              normalizedDocument.profileVersion == "2",
              let startText = plan.declaredStatementStartISO,
              let endText = plan.declaredStatementEndISO,
              let start = try? StatementDate(canonical: startText),
              let end = try? StatementDate(canonical: endText),
              start <= end,
              let openingMinor = plan.openingBalanceMinor,
              let openingDecimal = plan.openingBalanceDecimal,
              let closingMinor = plan.closingBalanceMinor,
              let closingDecimal = plan.closingBalanceDecimal,
              decimalMatchesMinor(openingDecimal, minor: openingMinor),
              decimalMatchesMinor(closingDecimal, minor: closingMinor),
              !plan.transactionTemplates.isEmpty,
              plan.transactionTemplates.count == plan.historyTemplate.normalizedRows.count else {
            return .unsupportedEvidence
        }

        var normalizedRows: [String: NormalizedRowDTO] = [:]
        for row in plan.historyTemplate.normalizedRows {
            guard normalizedRows.updateValue(row, forKey: row.id) == nil else {
                return .repositoryIntegrityConflict
            }
        }
        var reviewedRows: [ReviewedPartialImportRowDTO] = []
        var seenEvents = Set<TransactionEventIdentityKeyDTO>()

        for template in plan.transactionTemplates {
            let transaction = template.transaction
            guard transaction.isTrusted,
                  transaction.accountId == nil,
                  transaction.importSessionId == nil,
                  transaction.documentId == nil,
                  transaction.nativeCurrency == "INR",
                  let runningBalance = transaction.runningBalanceMinor,
                  let evidence = template.eventEvidence,
                  transaction.rawRows.count == 1,
                  let raw = transaction.rawRows.first,
                  let sourceOrdinal = raw.sourceOrdinal,
                  let digest = raw.normalizedRecordDigest,
                  let normalizedRow = normalizedRows[raw.normalizedRowId],
                  normalizedRow.sourceOrdinal == sourceOrdinal,
                  normalizedRow.digest == digest,
                  raw.normalizedDocumentId == normalizedDocument.id,
                  raw.parserProfileId == normalizedDocument.profileId,
                  raw.parserProfileVersion == normalizedDocument.profileVersion,
                  let date = try? StatementDate(canonical: transaction.postedDateISO),
                  start <= date, date <= end,
                  ["debit", "credit"].contains(transaction.direction),
                  decimalMatchesMinor(transaction.amountDecimal, minor: transaction.amountMinor) else {
                return .unsupportedEvidence
            }

            let identity: TransactionEventIdentity
            do {
                identity = try TransactionEventIdentity.make(
                    transactionID: transaction.id,
                    evidence: evidence,
                    accountID: accountID
                )
            } catch {
                return .unsupportedEvidence
            }
            let key = TransactionEventIdentityKeyDTO(
                algorithm: identity.algorithmIdentifier,
                digest: identity.digest
            )
            guard seenEvents.insert(key).inserted else {
                return .repeatedIncomingEvidence
            }

            let owner = owners[key]
            if let owner, owner.accountId != accountID {
                return .ownershipConflict
            }
            if let owner {
                guard !owner.eventIdentityId.isEmpty,
                      let existing = transactionsByID[owner.transactionId],
                      projectionsAgree(incoming: transaction, existing: existing) else {
                    return .repositoryIntegrityConflict
                }
            }

            reviewedRows.append(
                ReviewedPartialImportRowDTO(
                    normalizedRowId: normalizedRow.id,
                    sourceOrdinal: sourceOrdinal,
                    normalizedRecordDigest: digest,
                    statementDateISO: transaction.postedDateISO,
                    financialDateRole: transaction.financialDateRole,
                    timezoneEvidence: transaction.statementTimezoneEvidence,
                    nativeCurrency: transaction.nativeCurrency,
                    amountMinor: transaction.amountMinor,
                    amountDecimal: transaction.amountDecimal,
                    direction: transaction.direction,
                    runningBalanceMinor: runningBalance,
                    eventAlgorithm: identity.algorithmIdentifier,
                    eventDigest: identity.digest,
                    disposition: owner == nil ? .importedUnique : .recognizedExisting,
                    expectedTransactionId: owner?.transactionId,
                    expectedEventIdentityId: owner?.eventIdentityId
                )
            )
        }

        reviewedRows.sort { $0.sourceOrdinal < $1.sourceOrdinal }
        guard Set(reviewedRows.map(\.sourceOrdinal)).count == reviewedRows.count,
              reconcile(rows: reviewedRows, openingMinor: openingMinor, closingMinor: closingMinor) else {
            return .repositoryIntegrityConflict
        }

        let recognized = reviewedRows.filter { $0.disposition == .recognizedExisting }.count
        let imported = reviewedRows.filter { $0.disposition == .importedUnique }.count
        if recognized == 0 { return .ordinaryFullImport }
        if imported == 0 { return .fullSupportedOverlap(count: recognized) }

        // The former reviewed-partial fixture pair has no immutable source
        // lineage. Full imports and full supported-overlap blocking remain
        // available, but a mixed recognized/unique result must fail closed
        // until source-faithful evidence re-establishes this exception.
        return .unsupportedEvidence

    }

    static func projectionsAgree(incoming: TransactionDTO, existing: TransactionDTO) -> Bool {
        incoming.postedDateISO == existing.postedDateISO &&
        incoming.financialDateRole == existing.financialDateRole &&
        incoming.statementTimezoneEvidence == existing.statementTimezoneEvidence &&
        incoming.nativeCurrency == existing.nativeCurrency &&
        incoming.amountMinor == existing.amountMinor &&
        incoming.amountDecimal == existing.amountDecimal &&
        incoming.direction == existing.direction &&
        incoming.runningBalanceMinor == existing.runningBalanceMinor &&
        existing.isTrusted
    }

    private static func decimalMatchesMinor(_ decimal: String, minor: Int64) -> Bool {
        guard let money = try? Money(canonicalDecimal: decimal, currency: "INR"),
              let moneyMinor = try? money.minorUnits() else { return false }
        return moneyMinor == minor
    }

    private static func reconcile(
        rows: [ReviewedPartialImportRowDTO],
        openingMinor: Int64,
        closingMinor: Int64
    ) -> Bool {
        let firstAddition = rows.first.map { openingMinor.addingReportingOverflow($0.amountMinor) }
        guard let first = rows.first, let last = rows.last,
              let firstAddition,
              !firstAddition.overflow,
              firstAddition.partialValue == first.runningBalanceMinor,
              last.runningBalanceMinor == closingMinor else {
            return false
        }
        for index in rows.indices.dropFirst() {
            let previous = rows[index - 1].runningBalanceMinor
            let addition = previous.addingReportingOverflow(rows[index].amountMinor)
            guard !addition.overflow, addition.partialValue == rows[index].runningBalanceMinor else {
                return false
            }
        }
        return true
    }
}
