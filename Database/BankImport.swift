import Foundation

/// Source-only details for an account section. These observations never alter
/// booked transactions or reconcile sibling account totals.
nonisolated public struct BankSectionSourceDetailsDTO: Codable, Equatable, Sendable {
    nonisolated public struct Control: Codable, Equatable, Sendable {
        public let kind: String
        public let label: String
        public let literal: String
        public let sourceOrdinal: Int
        public let sourcePage: Int
    }
    public let firstPage: Int
    public let lastPage: Int
    public let regionDescriptor: String
    public let regionSignature: String
    public let recognizedRowCount: Int
    public let controls: [Control]
}

nonisolated public struct BankImportSectionDTO: Equatable, Sendable {
    public let proposedAccount: AccountDTO
    public let accountChoice: ConfirmedImportAccountChoiceDTO
    public let identifiers: [ConfirmedImportIdentifierCandidateDTO]
    public let source: BankStatementSectionPlanDTO
}

nonisolated public struct BankImportPlanDTO: Equatable, Sendable {
    public let providerGeneration: ProviderGenerationToken
    public let workspace: WorkspaceDTO
    public let history: ConfirmedImportHistoryTemplateDTO
    public let sections: [BankImportSectionDTO]
    public let transactions: [TransactionDTO]
    public let zeroActivityControl: StatementZeroActivityControlDTO?

    public init(providerGeneration: ProviderGenerationToken, workspace: WorkspaceDTO,
                history: ConfirmedImportHistoryTemplateDTO, sections: [BankImportSectionDTO],
                transactions: [TransactionDTO], zeroActivityControl: StatementZeroActivityControlDTO? = nil) {
        self.providerGeneration = providerGeneration; self.workspace = workspace; self.history = history
        self.sections = sections; self.transactions = transactions; self.zeroActivityControl = zeroActivityControl
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
                        transactions: [TransactionDTO], existingZeroControls: [StatementZeroActivityControlDTO] = []) throws -> Resolution {
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
                      section.sourceDetails?.regionSignature.count == 64,
                      let start = section.sourceRangeStart, let end = section.sourceRangeEnd, start > 0, start <= end,
                      plan.zeroActivityControl == nil else { throw BankImportHoldDTO("invalid_relationship_source_region", sectionID: section.id) }
            } else if section.rows.isEmpty && plan.zeroActivityControl == nil {
                throw BankImportHoldDTO("missing_zero_activity_source_evidence", sectionID: section.id)
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
            let existing = transactions.filter { $0.workspaceId == plan.workspace.id && $0.accountId == account.id }
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
                let matches = coarse.filter { candidate in
                    guard candidate.isTrusted, candidate.financialDateRole == incoming.financialDateRole,
                          candidate.valueDateISO == incoming.valueDateISO, candidate.amountDecimal == incoming.amountDecimal,
                          candidate.direction == incoming.direction, candidate.runningBalanceMinor == incoming.runningBalanceMinor,
                          candidate.rawRows.count == 1, let profile = candidate.rawRows.first?.parserProfileId,
                          (relationshipProfiles + standaloneProfiles).contains(profile),
                          candidate.rawRows.first?.parserProfileVersion == supportedVersion(for: profile),
                          profile.hasPrefix(axis ? "axis." : "hdfc.") else { return false }
                    return referencesAgree(incoming: incoming, incomingProfile: section.parserProfileId, existing: candidate, existingProfile: profile)
                }
                guard !matches.isEmpty else {
                    let reason = coarse.contains { $0.valueDateISO != incoming.valueDateISO } ? "conflicting_value_date" :
                        coarse.contains { $0.runningBalanceMinor != incoming.runningBalanceMinor } ? "conflicting_running_balance" : "missing_or_conflicting_linkage_evidence"
                    throw BankImportHoldDTO(reason, sectionID: section.id, sourceOrdinal: row.sourceOrdinal)
                }
                candidatesByRow[row.normalizedRowId] = matches
            }
            // Ordered one-to-one assignment within each authentic first source
            // preserves reversal/retry multiplicity. More than one assignment
            // is a hold, even when narration happens to look similar.
            let groups = Set(candidatesByRow.values.flatMap { $0.compactMap(\.documentId) })
            for documentID in groups.sorted() {
                let relevant = section.rows.filter { occurrence in candidatesByRow[occurrence.normalizedRowId]?.contains(where: { $0.documentId == documentID }) == true }
                var solutions: [[String: String]] = []
                func assign(_ index: Int, _ lastOrdinal: Int, _ chosen: [String: String]) {
                    guard solutions.count < 2 else { return }
                    if index == relevant.count { solutions.append(chosen); return }
                    let rowID = relevant[index].normalizedRowId
                    for candidate in candidatesByRow[rowID] ?? [] where candidate.documentId == documentID {
                        guard let ordinal = candidate.rawRows.first?.sourceOrdinal, ordinal > lastOrdinal,
                              !chosen.values.contains(candidate.id) else { continue }
                        var next = chosen; next[rowID] = candidate.id
                        assign(index + 1, ordinal, next)
                    }
                }
                assign(0, 0, [:])
                guard solutions.count == 1 else { throw BankImportHoldDTO("ambiguous_occurrence_multiplicity_or_order", sectionID: section.id) }
                for (rowID, canonicalID) in solutions[0] {
                    guard links[rowID] == nil || links[rowID] == canonicalID else { throw BankImportHoldDTO("ambiguous_occurrence_identity", sectionID: section.id) }
                    links[rowID] = canonicalID
                }
            }
            guard section.rows.allSatisfy({ links[$0.normalizedRowId] != nil }),
                  Set(section.rows.compactMap { links[$0.normalizedRowId] }).count == section.rows.count else {
                throw BankImportHoldDTO("ambiguous_occurrence_multiplicity", sectionID: section.id)
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

    static func referencesAgree(incoming: TransactionDTO, incomingProfile: String, existing: TransactionDTO, existingProfile: String) -> Bool {
        if incomingProfile.hasPrefix("axis.") { return incoming.reference == existing.reference }
        return hdfcReference(incoming.reference, narration: incoming.description ?? "", profile: incomingProfile) ==
            hdfcReference(existing.reference, narration: existing.description ?? "", profile: existingProfile)
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
