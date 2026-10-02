import Foundation

/// Source-only details for an account section. These observations never alter
/// booked transactions or reconcile sibling account totals.
nonisolated public struct BankSectionSourceDetailsDTO: Codable, Equatable, Sendable {
    nonisolated public struct Control: Codable, Equatable, Sendable {
        public let kind: String
        public let label: String
        public let literal: String
        public let sourceOrdinal: Int
        public let sourcePage: Int?
        public let sourceUnit: String?

        public init(kind: String, label: String, literal: String, sourceOrdinal: Int,
                    sourcePage: Int?, sourceUnit: String? = nil) {
            self.kind = kind; self.label = label; self.literal = literal
            self.sourceOrdinal = sourceOrdinal; self.sourcePage = sourcePage; self.sourceUnit = sourceUnit
        }
    }
    // Relationship PDFs retain their complete page/region geometry. A
    // standalone source may retain controls without inventing page evidence.
    public let firstPage: Int?
    public let lastPage: Int?
    public let regionDescriptor: String?
    public let regionSignature: String?
    public let recognizedRowCount: Int?
    public let controls: [Control]

    func isValidStandalone(sourceFormatCode: String) -> Bool {
        let expectedUnit: String
        switch sourceFormatCode {
        case "xls": expectedUnit = "row"
        case "pdf": expectedUnit = "line"
        default: return false
        }
        let allowed = Set(["openingBalance", "closingBalance", "debitTotal", "creditTotal", "debitCount", "creditCount"])
        return firstPage == nil && lastPage == nil && regionDescriptor == nil && regionSignature == nil &&
            recognizedRowCount == nil && !controls.isEmpty &&
            Set(controls.map(\.kind)).count == controls.count && controls.allSatisfy {
                allowed.contains($0.kind) && !$0.label.isEmpty && !$0.literal.isEmpty &&
                    $0.sourceOrdinal > 0 && $0.sourceUnit == expectedUnit &&
                    ($0.sourcePage.map { $0 > 0 } ?? true)
            }
    }
}

nonisolated public struct BankImportSectionDTO: Equatable, Sendable {
    public let proposedAccount: AccountDTO
    public let accountChoice: ConfirmedImportAccountChoiceDTO
    public let identifiers: [ConfirmedImportIdentifierCandidateDTO]
    public let source: BankStatementSectionPlanDTO
}

/// A transient request to record another complete representation of an
/// existing legacy standalone statement. Its original projection stays intact;
/// new correspondence is retained in the existing bank occurrence tables.
nonisolated public struct BankStatementCorrespondenceRequirementDTO: Equatable, Sendable {
    public let groupID: String
    public let authoritativeProjectionID: String

    public init(groupID: String, authoritativeProjectionID: String) {
        self.groupID = groupID
        self.authoritativeProjectionID = authoritativeProjectionID
    }
}

nonisolated public struct BankImportPlanDTO: Equatable, Sendable {
    public let providerGeneration: ProviderGenerationToken
    public let workspace: WorkspaceDTO
    public let history: ConfirmedImportHistoryTemplateDTO
    public let sections: [BankImportSectionDTO]
    public let transactions: [TransactionDTO]
    public let zeroActivityControl: StatementZeroActivityControlDTO?
    public let statementCorrespondence: BankStatementCorrespondenceRequirementDTO?

    public init(providerGeneration: ProviderGenerationToken, workspace: WorkspaceDTO,
                history: ConfirmedImportHistoryTemplateDTO, sections: [BankImportSectionDTO],
                transactions: [TransactionDTO], zeroActivityControl: StatementZeroActivityControlDTO? = nil,
                statementCorrespondence: BankStatementCorrespondenceRequirementDTO? = nil) {
        self.providerGeneration = providerGeneration; self.workspace = workspace; self.history = history
        self.sections = sections; self.transactions = transactions; self.zeroActivityControl = zeroActivityControl
        self.statementCorrespondence = statementCorrespondence
    }
}

nonisolated public struct ReviewedBankImportPlanDTO: Equatable, Sendable {
    public let plan: BankImportPlanDTO
    /// Every incoming normalized row is retained, including represented rows.
    public let canonicalTransactionByNormalizedRow: [String: String]
}

nonisolated public struct BankImportHoldDTO: Error, Equatable, Sendable {
    public let sectionID: String?
    public let sourceOrdinal: Int?
    public let reason: String
    init(_ reason: String, sectionID: String? = nil, sourceOrdinal: Int? = nil) {
        self.reason = reason; self.sectionID = sectionID; self.sourceOrdinal = sourceOrdinal
    }
}

nonisolated public enum BankImportReviewResult: Equatable, Sendable {
    case ready(ReviewedBankImportPlanDTO)
    case exactDuplicate
    case held(BankImportHoldDTO)
    case staleProviderGeneration
    case persistenceUnavailable
}

nonisolated public struct BankImportReceiptDTO: Equatable, Sendable {
    nonisolated public struct Section: Equatable, Sendable {
        public let sectionID: String
        public let accountID: String
        public let sourceRowCount: Int
        public let importedTransactionCount: Int
    }
    public let importSessionID: String
    public let documentID: String
    public let sections: [Section]
    public var importedCount: Int { sections.reduce(0) { $0 + $1.importedTransactionCount } }
    public var sourceCount: Int { sections.reduce(0) { $0 + $1.sourceRowCount } }
}

nonisolated public enum BankImportRepositoryResult: Equatable, Sendable {
    case committed(BankImportReceiptDTO)
    case exactDuplicate
    case held(BankImportHoldDTO)
    case staleProviderGeneration
    case retryableContention
    case persistenceUnavailable
}

/// The persisted bank-section profiles are deliberately finite. This is the
/// shared provider/hydration fence for a profile's owning institution and
/// native currency; parser selection alone is never authorization to attach a
/// source section to an arbitrary bank account.
enum BankStatementSectionProfileContract: String, CaseIterable, Sendable {
    case cbqCurrentMonthly = "cbq.current-account.monthly.pdf"
    case cbqCurrentLegacy = "cbq.current-account.legacy.pdf"
    case cbqCurrentUSDMonthly = "cbq.current-account.usd-monthly.pdf"
    case cbqSavingsLegacy = "cbq.savings-account.legacy.pdf"
    case cbqSavingsMonthly = "cbq.savings-account.monthly.pdf"
    case cbqESavingsMonthly = "cbq.e-savings-account.monthly.pdf"
    case axisRelationship = "axis.relationship-bank.pdf"
    case hdfcRelationship = "hdfc.relationship-bank.pdf"
    case axisCSV = "axis.bank-account.csv"
    case axisPDF = "axis.bank-account.pdf"
    case axisXLS = "axis.bank-account.xls"
    case hdfcPDF = "hdfc.bank-account.pdf"
    case hdfcXLS = "hdfc.bank-account.xls"

    var parserProfileVersion: String { self == .axisCSV ? "3" : "1" }
    var sourceFormatCode: String {
        switch self {
        case .cbqCurrentLegacy, .cbqSavingsLegacy:
            return "legacy-pdf"
        case .cbqCurrentMonthly, .cbqCurrentUSDMonthly, .cbqSavingsMonthly, .cbqESavingsMonthly:
            return "monthly-pdf"
        default:
            return rawValue.split(separator: ".").last.map(String.init) ?? ""
        }
    }
    var institutionID: String {
        switch self {
        case .cbqCurrentMonthly, .cbqCurrentLegacy, .cbqCurrentUSDMonthly,
             .cbqSavingsLegacy, .cbqSavingsMonthly, .cbqESavingsMonthly:
            return "Commercial Bank of Qatar"
        case .axisRelationship, .axisCSV, .axisPDF, .axisXLS:
            return "Axis Bank"
        case .hdfcRelationship, .hdfcPDF, .hdfcXLS:
            return "HDFC Bank"
        }
    }
    var nativeCurrency: String { self == .cbqCurrentUSDMonthly ? "USD" : (rawValue.hasPrefix("cbq.") ? "QAR" : "INR") }

    static func matches(
        profileID: String,
        version: String,
        nativeCurrency: String,
        sourceFormatCode: String,
        institutionID: String
    ) -> Bool {
        guard let contract = Self(rawValue: profileID) else { return false }
        return contract.parserProfileVersion == version &&
            contract.nativeCurrency == nativeCurrency &&
            contract.sourceFormatCode == sourceFormatCode &&
            contract.institutionID == institutionID
    }
}

/// Both providers run this same bounded decision again while owning their
/// transaction boundary. No mutation occurs while making the decision.
enum BankImportDecision {
    struct Resolution {
        let accounts: [AccountDTO]
        let newAccounts: [AccountDTO]
        let links: [String: String]
        let newTransactions: [TransactionDTO]
        let sections: [BankStatementSectionPlanDTO]
        let receipt: BankImportReceiptDTO
        let zeroActivityControl: StatementZeroActivityControlDTO?
    }

    static let relationshipProfiles = ["axis.relationship-bank.pdf", "hdfc.relationship-bank.pdf"]
    static let standaloneProfiles = ["axis.bank-account.csv", "axis.bank-account.pdf", "axis.bank-account.xls",
                                     "hdfc.bank-account.pdf", "hdfc.bank-account.xls"]
    static func supportedVersion(for profile: String) -> String? {
        guard (relationshipProfiles + standaloneProfiles).contains(profile) else { return nil }
        return profile == "axis.bank-account.csv" ? "3" : "1"
    }

    static func mask(_ lhs: String, matches rhs: String) -> Bool {
        lhs.count == 15 && rhs.count == 15 &&
            lhs.allSatisfy { $0.isASCII && ($0.isNumber || $0 == "X") } &&
            rhs.allSatisfy { $0.isASCII && ($0.isNumber || $0 == "X") } &&
            zip(lhs, rhs).allSatisfy { $0 == "X" || $1 == "X" || $0 == $1 }
    }

    static func resolve(_ plan: BankImportPlanDTO, accounts: [AccountDTO],
                        identifiers: [AccountIdentifierDTO], existingSections: [BankStatementSectionPlanDTO],
                        transactions: [TransactionDTO], existingZeroControls: [StatementZeroActivityControlDTO] = [],
                        existingStatementGroups: [StatementEquivalenceGroupDTO] = [],
                        existingStatementProjections: [StatementFinancialProjectionRecordDTO] = [],
                        existingStatementMembers: [StatementEquivalenceMemberDTO] = []) throws -> Resolution {
        try plan.history.validateFingerprints()
        let history = plan.history
        let occurrences = plan.sections.flatMap(\.source.rows)
        guard let normalized = history.normalizedDocument,
              history.document.workspaceId == plan.workspace.id,
              history.importSession.workspaceId == plan.workspace.id,
              history.document.importSessionId == history.importSession.id,
              normalized.documentId == history.document.id, normalized.importSessionId == history.importSession.id,
              history.successfulAttempt.accountId == nil,
              !plan.sections.isEmpty,
              plan.sections.map(\.source.sectionOrdinal) == Array(1...plan.sections.count),
              Set(plan.sections.map(\.source.accountId)).count == plan.sections.count,
              Set(plan.sections.map(\.source.id)).count == plan.sections.count,
              Set(plan.transactions.map(\.id)).count == plan.transactions.count,
              Set(history.normalizedRows.map(\.id)).count == history.normalizedRows.count,
              Set(history.normalizedRows.map(\.sourceOrdinal)).count == history.normalizedRows.count,
              plan.transactions.allSatisfy({ $0.workspaceId == plan.workspace.id && $0.accountId == nil && $0.isTrusted }),
              Set(plan.sections.flatMap(\.source.rows).map(\.normalizedRowId)) == Set(history.normalizedRows.map(\.id)),
              Set(occurrences.map(\.normalizedRowId)).count == occurrences.count,
              Set(occurrences.map(\.source.incomingTransactionId)).count == occurrences.count,
              Set(occurrences.map(\.source.incomingTransactionId)) == Set(plan.transactions.map(\.id)),
              occurrences.count == history.normalizedRows.count,
              occurrences.count == plan.transactions.count,
              history.normalizedRows.allSatisfy({ $0.normalizedDocumentId == normalized.id }) else {
            throw BankImportHoldDTO("invalid_parent_source_graph")
        }
        let incomingByID = Dictionary(uniqueKeysWithValues: plan.transactions.map { ($0.id, $0) })
        var resolvedAccounts: [AccountDTO] = [], newAccounts: [AccountDTO] = []
        var links = [String: String](), newTransactions: [TransactionDTO] = []
        var observations: [BankStatementSectionPlanDTO] = [], receipts: [BankImportReceiptDTO.Section] = []
        var resolvedZeroControl: StatementZeroActivityControlDTO?
        for item in plan.sections {
            let section = item.source
            let relationship = relationshipProfiles.contains(section.parserProfileId)
            let standalone = standaloneProfiles.contains(section.parserProfileId)
            guard section.documentId == history.document.id, section.importSessionId == history.importSession.id,
                  section.normalizedDocumentId == normalized.id, section.parserProfileId == normalized.profileId,
                  section.parserProfileVersion == normalized.profileVersion,
                  relationship || (standalone && plan.sections.count == 1),
                  section.parserProfileVersion == supportedVersion(for: section.parserProfileId), section.nativeCurrency == "INR",
                  section.parserProfileId.hasSuffix("." + section.sourceEvidence.sourceFormatCode),
                  section.sourceEvidence.statementStartDateISO != nil, section.sourceEvidence.statementEndDateISO != nil,
                  Set(section.rows.map(\.source.incomingTransactionId)).count == section.rows.count,
                  section.rows.map(\.sourceOrdinal) == section.rows.map(\.sourceOrdinal).sorted(),
                  section.rows.isEmpty || (section.sourceRangeStart != nil && section.sourceRangeEnd != nil &&
                    section.rows.allSatisfy({ section.sourceRangeStart! <= $0.sourceOrdinal && $0.sourceOrdinal <= section.sourceRangeEnd! })) else {
                throw BankImportHoldDTO("invalid_section_source_graph", sectionID: section.id)
            }
            if relationship {
                guard section.sourceDetails?.recognizedRowCount == section.rows.count,
                      section.sourceDetails?.regionSignature?.count == 64,
                      let start = section.sourceRangeStart, let end = section.sourceRangeEnd, start > 0, start <= end,
                      plan.zeroActivityControl == nil else { throw BankImportHoldDTO("invalid_relationship_source_region", sectionID: section.id) }
            } else {
                guard section.sourceDetails?.isValidStandalone(sourceFormatCode: section.sourceEvidence.sourceFormatCode) ?? true else {
                    throw BankImportHoldDTO("invalid_standalone_source_controls", sectionID: section.id)
                }
                if section.rows.isEmpty && plan.zeroActivityControl == nil {
                    throw BankImportHoldDTO("missing_zero_activity_source_evidence", sectionID: section.id)
                }
            }
            let axis = section.parserProfileId.hasPrefix("axis.")
            let institution = axis ? "Axis Bank" : "HDFC Bank"
            guard item.proposedAccount.id == section.accountId, item.proposedAccount.workspaceId == plan.workspace.id,
                  item.proposedAccount.accountType == "bank", item.proposedAccount.nativeCurrency == section.nativeCurrency,
                  item.proposedAccount.institutionId == institution,
                  !item.proposedAccount.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BankImportHoldDTO("ineligible_section_account", sectionID: section.id)
            }
            let sourceIdentity: String
            if axis && relationship {
                guard item.identifiers.isEmpty, section.identityPatterns.count == 1,
                      section.identityPatterns[0].kind == "axis_masked_account_number",
                      section.identityPatterns[0].pattern.contains("X"),
                      mask(section.identityPatterns[0].pattern, matches: section.identityPatterns[0].pattern) else {
                    throw BankImportHoldDTO("invalid_axis_identity", sectionID: section.id)
                }
                sourceIdentity = section.identityPatterns[0].pattern
            } else {
                let kind = axis ? "axis_account_number" : "hdfc_account_number"
                guard item.identifiers.count == 1,
                      item.identifiers[0].scheme == "institution_account_id",
                      section.identityPatterns == [.init(kind: kind, pattern: item.identifiers[0].normalizedValue)],
                      item.identifiers[0].normalizedValue.range(of: axis ? #"^[0-9]{15}$"# : #"^[0-9]{14}$"#, options: .regularExpression) != nil else {
                    throw BankImportHoldDTO("invalid_full_account_identity", sectionID: section.id)
                }
                sourceIdentity = item.identifiers[0].normalizedValue
            }
            let eligible = accounts.filter { $0.workspaceId == plan.workspace.id && $0.accountType == "bank" && $0.institutionId == institution && $0.nativeCurrency == section.nativeCurrency }
            let owners = eligible.filter { account in
                let strong = identifiers.filter { $0.accountId == account.id && $0.workspaceId == plan.workspace.id &&
                    $0.scheme == "institution_account_id" && $0.strength == "strong" && $0.verificationState == "verified" }
                let observed = existingSections.filter { $0.accountId == account.id }.flatMap(\.identityPatterns)
                    .filter { $0.kind == "axis_masked_account_number" }
                guard !axis || observed.allSatisfy({ mask(sourceIdentity, matches: $0.pattern) }) else { return false }
                if !strong.isEmpty {
                    return strong.allSatisfy { axis ? mask(sourceIdentity, matches: $0.identifier) : sourceIdentity == $0.identifier }
                }
                guard axis else { return false }
                return !observed.isEmpty && observed.allSatisfy { mask(sourceIdentity, matches: $0.pattern) }
            }
            guard owners.count <= 1 else { throw BankImportHoldDTO("ambiguous_account_identity", sectionID: section.id) }
            let account: AccountDTO
            switch item.accountChoice {
            case .unspecified:
                throw BankImportHoldDTO("account_choice_required", sectionID: section.id)
            case .createProposedAccount:
                guard owners.isEmpty, !accounts.contains(where: { $0.id == section.accountId }) else {
                    throw BankImportHoldDTO("account_identity_changed", sectionID: section.id)
                }
                account = item.proposedAccount
                newAccounts.append(account)
            case .useExistingAccount(let id):
                guard id == section.accountId, let selected = eligible.first(where: { $0.id == id }),
                      owners.isEmpty || owners[0].id == id else {
                    throw BankImportHoldDTO("account_identity_changed", sectionID: section.id)
                }
                let strong = identifiers.filter { $0.accountId == id && $0.scheme == "institution_account_id" && $0.strength == "strong" && $0.verificationState == "verified" }
                guard strong.allSatisfy({ axis ? mask(sourceIdentity, matches: $0.identifier) : sourceIdentity == $0.identifier }) else {
                    throw BankImportHoldDTO("conflicting_strong_account_identity", sectionID: section.id)
                }
                let observed = existingSections.filter { $0.accountId == id }.flatMap(\.identityPatterns)
                    .filter { $0.kind == "axis_masked_account_number" }
                guard !axis || observed.allSatisfy({ mask(sourceIdentity, matches: $0.pattern) }) else {
                    throw BankImportHoldDTO("conflicting_observed_account_identity", sectionID: section.id)
                }
                account = selected
            }
            resolvedAccounts.append(account)
            if let zero = plan.zeroActivityControl {
                guard standalone, plan.sections.count == 1, section.rows.isEmpty,
                      zero.isValid(), zero.matchesAccount(account), zero.authorityRole == "authoritative",
                      zero.workspaceId == plan.workspace.id, zero.accountId == account.id,
                      zero.documentId == history.document.id, zero.importSessionId == history.importSession.id,
                      zero.normalizedDocumentId == normalized.id,
                      zero.parserProfileId == normalized.profileId, zero.parserProfileVersion == normalized.profileVersion,
                      zero.sourceFingerprintAlgorithm == history.duplicateAuthorityFingerprint?.algorithm,
                      zero.sourceFingerprintDigest == history.duplicateAuthorityFingerprint?.fingerprint else {
                    throw BankImportHoldDTO("invalid_zero_activity_source_evidence", sectionID: section.id)
                }
                let sameCycle = existingZeroControls.filter {
                    $0.workspaceId == zero.workspaceId && $0.accountId == account.id &&
                        $0.institutionCode == zero.institutionCode && $0.statementFamilyCode == zero.statementFamilyCode &&
                        $0.semanticCycleKey == zero.semanticCycleKey && $0.nativeCurrency == zero.nativeCurrency
                }
                guard sameCycle.allSatisfy({ $0.semanticDigest == zero.semanticDigest }) else {
                    throw BankImportHoldDTO("conflicting_zero_activity_source_evidence", sectionID: section.id)
                }
                let authorities = sameCycle.filter { $0.authorityRole == "authoritative" }
                guard authorities.count <= 1, authorities.count == 1 || sameCycle.isEmpty else {
                    throw BankImportHoldDTO("ambiguous_zero_activity_authority", sectionID: section.id)
                }
                resolvedZeroControl = authorities.isEmpty ? zero : zero.withAuthorityRole("supporting")
            }
            var existing = transactions.filter { $0.workspaceId == plan.workspace.id && $0.accountId == account.id }
            let requiredCanonicalIDs: Set<String>?
            if let required = plan.statementCorrespondence {
                guard standalone, plan.sections.count == 1, plan.zeroActivityControl == nil,
                      let group = existingStatementGroups.first(where: { $0.id == required.groupID }),
                      group.workspaceID == plan.workspace.id, group.accountID == account.id,
                      group.authoritativeProjectionID == required.authoritativeProjectionID,
                      group.institutionCode == (axis ? "axis" : "hdfc"),
                      group.statementFamilyCode == (axis ? "axis.bank-account" : "hdfc.bank-account"),
                      group.nativeCurrency == section.nativeCurrency,
                      group.statementStartDateISO == section.sourceEvidence.statementStartDateISO,
                      group.statementEndDateISO == section.sourceEvidence.statementEndDateISO,
                      let authoritative = existingStatementProjections.first(where: {
                          $0.projection.id == group.authoritativeProjectionID
                      }),
                      authoritative.workspaceID == group.workspaceID, authoritative.accountID == group.accountID,
                      authoritative.projection.algorithmIdentifier == group.projectionAlgorithm,
                      authoritative.projection.digest == group.projectionDigest,
                      authoritative.projection.isValid(),
                      authoritative.projection.eventCount == section.rows.count else {
                    throw BankImportHoldDTO("statement_correspondence_evidence_unavailable", sectionID: section.id)
                }
                existing = existing.filter {
                    $0.importSessionId == authoritative.importSessionID && $0.documentId == authoritative.documentID
                }
                guard existing.count == authoritative.projection.eventCount,
                      Set(existing.map(\.id)).count == existing.count else {
                    throw BankImportHoldDTO("statement_correspondence_evidence_unavailable", sectionID: section.id)
                }
                requiredCanonicalIDs = Set(existing.map(\.id))
                let previouslyRecorded = existingStatementMembers.contains {
                    $0.groupID == group.id && $0.sourceFormatCode == section.sourceEvidence.sourceFormatCode
                } || existingSections.contains {
                    $0.accountId == account.id && $0.nativeCurrency == section.nativeCurrency &&
                        $0.sourceEvidence.statementStartDateISO == group.statementStartDateISO &&
                        $0.sourceEvidence.statementEndDateISO == group.statementEndDateISO &&
                        $0.sourceEvidence.sourceFormatCode == section.sourceEvidence.sourceFormatCode &&
                        Set($0.rows.map(\.source.incomingTransactionId)) == requiredCanonicalIDs
                }
                guard !previouslyRecorded else {
                    throw BankImportHoldDTO("statement_format_already_recorded", sectionID: section.id)
                }
            } else {
                requiredCanonicalIDs = nil
            }
            var candidatesByRow = [String: [TransactionDTO]]()
            for occurrence in section.rows {
                let row = occurrence.source
                guard let incoming = incomingByID[row.incomingTransactionId],
                      incoming.postedDateISO == row.postingDateISO, incoming.valueDateISO == occurrence.valueDateISO,
                      incoming.nativeCurrency == row.nativeCurrency, incoming.amountMinor == row.signedAmountMinor,
                      incoming.amountDecimal == row.signedAmountDecimal, incoming.direction == row.direction,
                      incoming.runningBalanceMinor == row.runningBalanceMinor,
                      incoming.description == occurrence.literalNarration, incoming.reference == occurrence.literalReference,
                      incoming.financialDateRole == FinancialDateRole.transactionDate.rawValue,
                      incoming.rawRows.count == 1, let raw = incoming.rawRows.first,
                      raw.normalizedRowId == row.normalizedRowId, raw.normalizedDocumentId == normalized.id,
                      raw.parserProfileId == section.parserProfileId, raw.parserProfileVersion == section.parserProfileVersion,
                      raw.sourceOrdinal == row.sourceOrdinal, raw.normalizedRecordDigest == row.normalizedRecordDigest,
                      history.normalizedRows.contains(where: { $0.id == row.normalizedRowId && $0.digest == row.normalizedRecordDigest && $0.sourceOrdinal == row.sourceOrdinal }),
                      try Money(canonicalDecimal: row.signedAmountDecimal, currency: row.nativeCurrency).minorUnits() == row.signedAmountMinor,
                      try Money(canonicalDecimal: row.runningBalanceDecimal, currency: row.nativeCurrency).minorUnits() == row.runningBalanceMinor else {
                    throw BankImportHoldDTO("invalid_occurrence_source_graph", sectionID: section.id, sourceOrdinal: row.sourceOrdinal)
                }
                let coarse = existing.filter { $0.postedDateISO == incoming.postedDateISO && $0.nativeCurrency == incoming.nativeCurrency && $0.amountMinor == incoming.amountMinor }
                if coarse.isEmpty {
                    links[row.normalizedRowId] = incoming.id
                    newTransactions.append(bind(incoming, accountID: account.id, history: history))
                    continue
                }
                // Each statement retains its own reported balance. Cross-source
                // links identify the transaction, not an equal balance snapshot.
                let matches = coarse.filter { candidate in
                    guard candidate.isTrusted, candidate.financialDateRole == incoming.financialDateRole,
                          candidate.valueDateISO == incoming.valueDateISO, candidate.amountDecimal == incoming.amountDecimal,
                          candidate.direction == incoming.direction,
                          candidate.rawRows.count == 1, let profile = candidate.rawRows.first?.parserProfileId,
                          (relationshipProfiles + standaloneProfiles).contains(profile),
                          candidate.rawRows.first?.parserProfileVersion == supportedVersion(for: profile),
                          profile.hasPrefix(axis ? "axis." : "hdfc.") else { return false }
                    return referencesAgree(incoming: incoming, incomingProfile: section.parserProfileId, existing: candidate, existingProfile: profile)
                }
                guard !matches.isEmpty else {
                    let reason = coarse.contains { $0.valueDateISO != incoming.valueDateISO } ? "conflicting_value_date" :
                        "missing_or_conflicting_linkage_evidence"
                    throw BankImportHoldDTO(reason, sectionID: section.id, sourceOrdinal: row.sourceOrdinal)
                }
                candidatesByRow[row.normalizedRowId] = matches
            }
            // Transaction evidence, never printed order, determines overlap.
            // Each occurrence consumes a different canonical transaction so
            // genuine repeated payments are not collapsed into a single row.
            // Source ordinals remain untouched as provenance in both sources.
            guard let assignment = uniqueAssignment(candidatesByRow.mapValues { $0.map(\.id) }) else {
                throw BankImportHoldDTO("ambiguous_occurrence_multiplicity", sectionID: section.id)
            }
            for (rowID, canonicalID) in assignment {
                links[rowID] = canonicalID
            }
            guard section.rows.allSatisfy({ links[$0.normalizedRowId] != nil }),
                  Set(section.rows.compactMap { links[$0.normalizedRowId] }).count == section.rows.count else {
                throw BankImportHoldDTO("ambiguous_occurrence_multiplicity", sectionID: section.id)
            }
            if let requiredCanonicalIDs {
                guard Set(section.rows.compactMap { links[$0.normalizedRowId] }) == requiredCanonicalIDs,
                      section.rows.count == requiredCanonicalIDs.count else {
                    throw BankImportHoldDTO("conflicting_statement_occurrences", sectionID: section.id)
                }
            }
            let stored = section.replacingCanonicalTransactions(links)
            observations.append(stored)
            let importedCount = section.rows.filter { links[$0.normalizedRowId] == $0.source.incomingTransactionId }.count
            receipts.append(.init(sectionID: section.id, accountID: account.id, sourceRowCount: section.rows.count, importedTransactionCount: importedCount))
        }
        return Resolution(accounts: resolvedAccounts, newAccounts: newAccounts, links: links, newTransactions: newTransactions,
                          sections: observations, receipt: .init(importSessionID: history.importSession.id, documentID: history.document.id, sections: receipts),
                          zeroActivityControl: resolvedZeroControl)
    }

    /// Returns a complete assignment only when every occurrence has exactly
    /// one possible counterpart across the entire candidate graph. The sort
    /// order makes traversal deterministic; it never supplies identity.
    static func uniqueAssignment(_ candidates: [String: [String]]) -> [String: String]? {
        let candidateIDs = candidates.mapValues { Array(Set($0)).sorted() }
        let rowIDs = candidateIDs.keys.sorted {
            let firstCount = candidateIDs[$0]?.count ?? 0
            let secondCount = candidateIDs[$1]?.count ?? 0
            return firstCount == secondCount ? $0 < $1 : firstCount < secondCount
        }
        guard rowIDs.allSatisfy({ candidateIDs[$0]?.isEmpty == false }) else { return nil }
        if rowIDs.allSatisfy({ candidateIDs[$0]?.count == 1 }) {
            let pairs = rowIDs.compactMap { rowID in candidateIDs[rowID]?.first.map { (rowID, $0) } }
            guard Set(pairs.map(\.1)).count == pairs.count else { return nil }
            return Dictionary(uniqueKeysWithValues: pairs)
        }
        func augment(_ rowID: String, excluding: (String, String)?,
                     seen: inout Set<String>, owners: inout [String: String]) -> Bool {
            for candidateID in candidateIDs[rowID] ?? [] {
                if excluding?.0 == rowID && excluding?.1 == candidateID { continue }
                guard seen.insert(candidateID).inserted else { continue }
                if let owner = owners[candidateID],
                   !augment(owner, excluding: excluding, seen: &seen, owners: &owners) { continue }
                owners[candidateID] = rowID
                return true
            }
            return false
        }
        var owners: [String: String] = [:]
        for rowID in rowIDs {
            var seen = Set<String>()
            guard augment(rowID, excluding: nil, seen: &seen, owners: &owners) else { return nil }
        }
        let assignment = Dictionary(uniqueKeysWithValues: owners.map { ($0.value, $0.key) })
        for rowID in rowIDs where (candidateIDs[rowID]?.count ?? 0) > 1 {
            guard let candidateID = assignment[rowID] else { return nil }
            var alternateOwners = owners
            alternateOwners.removeValue(forKey: candidateID)
            var seen = Set<String>()
            if augment(rowID, excluding: (rowID, candidateID), seen: &seen, owners: &alternateOwners) {
                return nil
            }
        }
        return assignment
    }

    static func referencesAgree(incoming: TransactionDTO, incomingProfile: String, existing: TransactionDTO, existingProfile: String) -> Bool {
        sourceLinkageAgrees(reference: incoming.reference, narration: incoming.description ?? "", profile: incomingProfile,
                            otherReference: existing.reference, otherNarration: existing.description ?? "", otherProfile: existingProfile,
                            postingDateISO: incoming.postedDateISO)
    }

    static func sourceLinkageAgrees(reference: String?, narration: String, profile: String,
                                    otherReference: String?, otherNarration: String, otherProfile: String,
                                    postingDateISO: String) -> Bool {
        let first = profile.hasPrefix("axis.") ? reference : hdfcReference(reference, narration: narration, profile: profile)
        let second = otherProfile.hasPrefix("axis.") ? otherReference : hdfcReference(otherReference, narration: otherNarration, profile: otherProfile)
        let firstAbsent = first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        let secondAbsent = second?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        if !firstAbsent && !secondAbsent { return first == second }
        guard firstAbsent && secondAbsent, !narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if narration == otherNarration { return true }
        let axisTabularProfiles = ["axis.bank-account.csv", "axis.bank-account.xls"]
        if profile == "axis.bank-account.pdf", axisTabularProfiles.contains(otherProfile) {
            return axisStandalonePDFNarrationAgrees(pdfNarration: narration, tabularNarration: otherNarration)
        }
        if otherProfile == "axis.bank-account.pdf", axisTabularProfiles.contains(profile) {
            return axisStandalonePDFNarrationAgrees(pdfNarration: otherNarration, tabularNarration: narration)
        }
        let hdfcProfiles = ["hdfc.relationship-bank.pdf", "hdfc.bank-account.pdf", "hdfc.bank-account.xls"]
        if hdfcProfiles.contains(profile), hdfcProfiles.contains(otherProfile),
           let firstNarration = hdfcComparisonNarration(narration, profile: profile),
           let secondNarration = hdfcComparisonNarration(otherNarration, profile: otherProfile) {
            let firstText = bankComparisonText(firstNarration)
            return !firstText.isEmpty && firstText == bankComparisonText(secondNarration)
        }
        // Axis prints friendly descriptions in the relationship PDF and coded
        // descriptions in its standalone PDF/CSV/XLS. Compare shared evidence;
        // neither source's stored narration is rewritten. Account/date/Money,
        // supported versions and unique one-to-one assignment are checked by
        // the caller before a source relationship can be accepted.
        let axisStandalone = ["axis.bank-account.csv", "axis.bank-account.pdf", "axis.bank-account.xls"]
        guard (profile == "axis.relationship-bank.pdf" && axisStandalone.contains(otherProfile)) ||
              (otherProfile == "axis.relationship-bank.pdf" && axisStandalone.contains(profile)) else { return false }
        if bankComparisonText(narration) == bankComparisonText(otherNarration) { return true }
        let relationship = profile == "axis.relationship-bank.pdf" ? narration : otherNarration
        let standalone = profile == "axis.relationship-bank.pdf" ? otherNarration : narration
        guard let relationshipKey = axisRelationshipNarrationKey(relationship),
              let standaloneKey = axisStandaloneNarrationKey(standalone, postingDateISO: postingDateISO) else { return false }
        return relationshipKey == standaloneKey
    }

    /// The standalone PDF normalizer joins wrapped narration fragments with
    /// spaces. Permit additional PDF spaces while preserving every tabular
    /// word boundary and every non-whitespace character, including case.
    /// The caller has already required two absent references; ownership,
    /// transaction facts and unique occurrence assignment remain mandatory.
    static func axisStandalonePDFNarrationAgrees(pdfNarration: String, tabularNarration: String) -> Bool {
        let expected = Array(tabularNarration.split(whereSeparator: \.isWhitespace).joined(separator: " "))
        let printed = pdfNarration.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !expected.isEmpty else { return false }
        var index = 0
        for character in printed {
            if character == " ", index == expected.count || expected[index] != " " {
                continue
            }
            guard index < expected.count, character == expected[index] else { return false }
            index += 1
        }
        return index == expected.count
    }

    private static func bankComparisonText(_ text: String) -> String {
        text.uppercased().filter { !$0.isWhitespace }
    }

    private static func hdfcComparisonNarration(_ text: String, profile: String) -> String? {
        guard profile == "hdfc.relationship-bank.pdf" else { return text }
        // Value date/reference are separate checked fields. Only the authentic
        // trailing structural suffix is omitted from this narration comparison;
        // it can directly follow the last word. Keep the stored literal intact.
        guard let expression = try? NSRegularExpression(
            pattern: #"Value\s*Dt\s*[0-9]{2}/[0-9]{2}/[0-9]{4}(?:\s+Ref\s+.*)?$"#,
            options: .caseInsensitive),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return String(text[..<range.lowerBound])
    }

    private static func axisCaptures(_ pattern: String, in text: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.range.length == (text as NSString).length else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
    }

    private static func axisRelationshipNarrationKey(_ text: String) -> [String]? {
        let text = text.uppercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        func key(_ operation: String, _ fields: [String]) -> [String] {
            [operation] + fields.map(bankComparisonText)
        }
        if let fields = axisCaptures(#"^UPI TO MERCHANT : (.+) \(([0-9]{12})\)$"#, in: text) {
            return key("UPI/P2M", [fields[1], fields[0]])
        }
        if let fields = axisCaptures(#"^UPI TRANSFER TO (.+) \(([0-9]{12})\)$"#, in: text) {
            return key("UPI/P2A", [fields[1], fields[0]])
        }
        if let fields = axisCaptures(#"^IMPS (?:TRANSFER FROM|TO) ID: (.+) \(([0-9]{12})\)$"#, in: text) {
            return key("IMPS/P2A", [fields[1], fields[0]])
        }
        if let fields = axisCaptures(#"^NEFT TRANSFER FROM (.+) \(([A-Z0-9]+)\)$"#, in: text) {
            return key("NEFT", [fields[1], fields[0]])
        }
        if let fields = axisCaptures(#"^RTGS TRANSFER FROM (.+)\(([^()]+)\) \(([A-Z0-9]+)\)$"#, in: text) {
            return key("RTGS", [fields[2], fields[0], fields[1]])
        }
        if let fields = axisCaptures(#"^CREDIT CARD BILL PAYMENT - ([0-9]{16})$"#, in: text) {
            return key("CARD PAYMENT", fields)
        }
        if let fields = axisCaptures(#"^SELF TRANSFER VIA APP TO ([0-9]+) \(([0-9]+)\)$"#, in: text), fields[0] == fields[1] {
            return key("SELF TRANSFER", fields)
        }
        if let fields = axisCaptures(#"^SELF FUND TRANSFER FROM (.+) \(([0-9]+)\)$"#, in: text) {
            return key("SELF TRANSFER", fields)
        }
        if let fields = axisCaptures(#"^ATM WITHDRAWAL : (.+)-([^-]+)$"#, in: text) {
            return key("ATM", fields)
        }
        if let fields = axisCaptures(#"^E-COMMERCE PURCHASE AT (.+)-([^-]+)$"#, in: text) {
            return key("ECOM", fields)
        }
        return nil
    }

    private static func axisStandaloneNarrationKey(_ text: String, postingDateISO: String) -> [String]? {
        let text = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = text.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        func key(_ operation: String, _ values: [String]) -> [String]? {
            let values = values.map(bankComparisonText)
            guard values.allSatisfy({ !$0.isEmpty }) else { return nil }
            return [operation] + values
        }
        if fields.count >= 4, fields[0] == "UPI", ["P2A", "P2M"].contains(fields[1]),
           fields[2].range(of: #"^[0-9]{12}$"#, options: .regularExpression) != nil {
            return key("UPI/" + fields[1], [fields[2], fields[3]])
        }
        // Authentic IMPS tails print a remitter label, destination account or
        // bank. The shared evidence is the operation, full reference and party;
        // exact signed Money and unique occurrence assignment are checked above.
        if fields.count >= 5, fields[0] == "IMPS", fields[1] == "P2A",
           fields[2].range(of: #"^[0-9]{12}$"#, options: .regularExpression) != nil {
            return key("IMPS/P2A", [fields[2], fields[3]])
        }
        if fields.count >= 3, fields[0] == "NEFT",
           fields[1].range(of: #"^[A-Z0-9]+$"#, options: .regularExpression) != nil {
            return key("NEFT", [fields[1], fields[2]])
        }
        if fields.count >= 4, fields[0] == "RTGS",
           fields[1].range(of: #"^[A-Z0-9]+$"#, options: .regularExpression) != nil {
            return key("RTGS", [fields[1], fields[2], fields[3]])
        }
        if let number = axisCaptures(#"^BRN-PYMT-CARD-([0-9]{16})$"#, in: text) {
            return key("CARD PAYMENT", number)
        }
        if fields.count == 4, fields[0] == "MOB", fields[1] == "SELFFT",
           bankComparisonText(fields[3]).range(of: #"^[0-9]{15}$"#, options: .regularExpression) != nil {
            return key("SELF TRANSFER", [fields[2], fields[3]])
        }
        let dateParts = postingDateISO.split(separator: "-")
        guard dateParts.count == 3, dateParts[0].count == 4, dateParts[1].count == 2, dateParts[2].count == 2 else { return nil }
        let printedDate = String(dateParts[2]) + String(dateParts[1]) + String(dateParts[0].suffix(2))
        if fields.count == 4, fields[0] == "ATM-CASH", fields[3] == printedDate {
            let location = fields[1].hasPrefix("+") ? String(fields[1].dropFirst()) : fields[1]
            return key("ATM", [location, fields[2]])
        }
        if fields.count == 6, fields[0] == "ECOM PUR", fields[3] == printedDate,
           fields[4].range(of: #"^[0-9]{2}:[0-9]{2}$"#, options: .regularExpression) != nil,
           fields[5].range(of: #"^[0-9]+$"#, options: .regularExpression) != nil {
            return key("ECOM", [fields[1], fields[2]])
        }
        return nil
    }

    /// Qualified HDFC relationship/standalone representation rules, proven
    /// against all 165 authentic counterpart occurrences. Literal fields stay
    /// unchanged. This function is never used for account identifiers.
    static func hdfcReference(_ reference: String?, narration: String, profile: String) -> String? {
        if profile == "hdfc.relationship-bank.pdf" {
            if let reference {
                if reference.range(of: #"^(?:[0-9]{4}|[0-9]{12})$"#, options: .regularExpression) != nil {
                    return String(repeating: "0", count: 16-reference.count) + reference
                }
                if reference.range(of: #"^I[0-9]{11}$"#, options: .regularExpression) != nil { return "0000" + reference }
                return reference
            }
            if narration.range(of: #"^(RTGS|NEFT)\s+(Dr|Cr)-"#, options: .regularExpression) != nil {
                let compact = narration.filter { !$0.isWhitespace }
                if let expression = try? NSRegularExpression(pattern: #"(?:HDFCR5|HDFCN5|FDRLN5)[0-9]{16}(?![0-9])"#) {
                    let matches = expression.matches(in: compact, range: NSRange(compact.startIndex..., in: compact))
                    if matches.count == 1, let range = Range(matches[0].range, in: compact) { return String(compact[range]) }
                }
            }
            return nil
        }
        return reference == "000000000000000" ? nil : reference
    }

    static func bind(_ t: TransactionDTO, accountID: String, history: ConfirmedImportHistoryTemplateDTO) -> TransactionDTO {
        TransactionDTO(id: t.id, workspaceId: t.workspaceId, accountId: accountID, importSessionId: history.importSession.id,
            documentId: history.document.id, originalRowId: t.originalRowId, postedDateISO: t.postedDateISO,
            financialDateRole: t.financialDateRole, statementTimezoneEvidence: t.statementTimezoneEvidence, valueDateISO: t.valueDateISO,
            description: t.description, payee: t.payee, reference: t.reference, nativeCurrency: t.nativeCurrency,
            amountMinor: t.amountMinor, amountDecimal: t.amountDecimal, direction: t.direction, runningBalanceMinor: t.runningBalanceMinor,
            isReconciled: t.isReconciled, isTrusted: t.isTrusted, trustedAtISO: t.trustedAtISO,
            createdAtISO: t.createdAtISO, updatedAtISO: t.updatedAtISO, rawRows: t.rawRows)
    }

    static func acceptedHistory(_ history: ConfirmedImportHistoryTemplateDTO, receipt: BankImportReceiptDTO) -> ConfirmedImportHistoryTemplateDTO {
        let old = history.successfulAttempt
        let attempt = ImportAttemptDTO(id: old.id, workspaceId: old.workspaceId, createdAtISO: old.createdAtISO,
            outcomeCode: old.outcomeCode, coverageCode: old.coverageCode, accountDecisionCode: old.accountDecisionCode,
            guidanceCode: old.guidanceCode, persistenceCode: old.persistenceCode, transactionCount: receipt.importedCount,
            accountId: nil, importSessionId: history.importSession.id, documentId: history.document.id,
            sourceRowCount: receipt.sourceCount, importedTransactionCount: receipt.importedCount,
            recognizedExistingRowCount: receipt.sourceCount-receipt.importedCount, blockedRowCount: 0)
        return .init(document: history.document, fingerprints: history.fingerprints, importSession: history.importSession,
            completedAtISO: history.completedAtISO, successfulAttempt: attempt,
            normalizedDocument: history.normalizedDocument, normalizedRows: history.normalizedRows)
    }
}

extension BankStatementSectionPlanDTO {
    func replacingCanonicalTransactions(_ links: [String: String]) -> Self {
        Self(id: id, accountId: accountId, documentId: documentId, importSessionId: importSessionId,
             normalizedDocumentId: normalizedDocumentId, sectionOrdinal: sectionOrdinal, parserProfileId: parserProfileId,
             parserProfileVersion: parserProfileVersion, nativeCurrency: nativeCurrency, sourceEvidence: sourceEvidence,
             identityPatterns: identityPatterns, sourceRangeStart: sourceRangeStart, sourceRangeEnd: sourceRangeEnd, productLabel: productLabel,
             rows: rows.map { occurrence in
                 let row = occurrence.source
                 return BankTransactionOccurrencePlanDTO(source: CBQSourceRowDTO(incomingTransactionId: links[row.normalizedRowId] ?? row.incomingTransactionId,
                     normalizedRowId: row.normalizedRowId, sourceOrdinal: row.sourceOrdinal, normalizedRecordDigest: row.normalizedRecordDigest,
                     postingDateISO: row.postingDateISO, sourceTransactionDateISO: row.sourceTransactionDateISO, nativeCurrency: row.nativeCurrency,
                     signedAmountMinor: row.signedAmountMinor, signedAmountDecimal: row.signedAmountDecimal, direction: row.direction,
                     runningBalanceMinor: row.runningBalanceMinor, runningBalanceDecimal: row.runningBalanceDecimal, structuredReferenceDigest: row.structuredReferenceDigest),
                     valueDateISO: occurrence.valueDateISO, literalNarration: occurrence.literalNarration,
                     literalReference: occurrence.literalReference, literalBalance: occurrence.literalBalance)
             }, sourceDetails: sourceDetails)
    }
}
