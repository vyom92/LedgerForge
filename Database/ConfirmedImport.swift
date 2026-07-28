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

    public init(providerGeneration: ProviderGenerationToken, workspace: WorkspaceDTO, proposedAccount: AccountDTO, accountChoice: ConfirmedImportAccountChoiceDTO, advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO, identifiers: [ConfirmedImportIdentifierCandidateDTO], historyTemplate: ConfirmedImportHistoryTemplateDTO, transactionTemplates: [ConfirmedImportTransactionTemplateDTO], declaredStatementStartISO: String? = nil, declaredStatementEndISO: String? = nil, openingBalanceMinor: Int64? = nil, openingBalanceDecimal: String? = nil, closingBalanceMinor: Int64? = nil, closingBalanceDecimal: String? = nil) {
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
    }
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
    case partialCommitted(ConfirmedImportReceiptDTO)
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
    case repositoryIntegrityConflict
    case retryableContention
    case persistenceUnavailable

    public var description: String {
        switch self {
        case .committed: return "Confirmed import committed."
        case .partialCommitted: return "Reviewed partial import committed."
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
