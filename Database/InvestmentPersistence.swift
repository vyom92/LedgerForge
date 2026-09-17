import Foundation

nonisolated public struct InvestmentSnapshot: Equatable, Sendable {
    public let containers: [InvestmentContainer]
    public let holdings: [InvestmentHolding]
    public static let empty = InvestmentSnapshot(containers: [], holdings: [])

    func validated(workspaceID: String) throws -> Self {
        guard Set(containers.map(\.id)).count == containers.count,
              Set(holdings.map(\.id)).count == holdings.count else { throw InvestmentError.invalidPersistedState }
        var identities = Set<String>()
        for container in containers {
            _ = try StatementDate(canonical: container.holdingsDate)
            guard container.workspaceID == workspaceID, !container.id.isEmpty,
                  !container.institution.isEmpty, !container.identityKind.isEmpty, !container.identity.isEmpty,
                  !container.displayName.isEmpty, !container.documentID.isEmpty, !container.importSessionID.isEmpty,
                  container.aliases.contains(container.identity), Set(container.aliases).count == container.aliases.count else {
                throw InvestmentError.invalidPersistedState
            }
            for alias in container.aliases {
                guard !alias.isEmpty, identities.insert([container.institution, container.identityKind, alias].joined(separator: "\u{1F}")).inserted else {
                    throw InvestmentError.invalidPersistedState
                }
            }
        }
        var positionKeys = Set<String>()
        for holding in holdings {
            guard let container = containers.first(where: { $0.id == holding.containerID }),
                  !holding.id.isEmpty, holding.units.value > 0,
                  holding.holdingsDate <= container.holdingsDate,
                  !holding.documentID.isEmpty, !holding.importSessionID.isEmpty,
                  !holding.normalizedDocumentID.isEmpty,
                  positionKeys.insert([holding.containerID, holding.instrumentIdentity, holding.currency].joined(separator: "\u{1F}")).inserted else {
                throw InvestmentError.invalidPersistedState
            }
            let evidence = InvestmentPositionEvidence(
                instrumentIdentity: holding.instrumentIdentity, sourceAliases: holding.sourceAliases,
                displayName: holding.displayName, units: holding.units, currency: holding.currency,
                averageCost: holding.averageCost, totalCost: holding.totalCost,
                averageCostLabel: holding.averageCostLabel, totalCostLabel: holding.totalCostLabel,
                costCurrency: holding.costCurrency, sourceOrdinal: holding.sourceOrdinal, valuationDate: holding.valuationDate)
            try InvestmentStatementEvidence(parserProfile: holding.parserProfile, issueDate: holding.issueDate,
                scopes: [.init(institution: container.institution, identityKind: container.identityKind,
                    identity: container.identity, aliases: container.aliases, displayName: container.displayName,
                    holdingsDate: holding.holdingsDate, isComplete: false, positions: [evidence])],
                excludedSectionDescription: "").validate()
            if let mapping = holding.priceMapping {
                guard !mapping.provider.isEmpty, !mapping.code.isEmpty, mapping.currency == holding.currency else {
                    throw InvestmentError.invalidPersistedState
                }
            }
        }
        return self
    }
}

nonisolated struct InvestmentImportChoices: Equatable, Sendable {
    /// Explicit review decisions only. No name matching or suffix stripping.
    var containerTargets: [String: String] = [:]
    var instrumentTargets: [String: String] = [:]
    var newContainerScopes: Set<String> = []
    var newInstrumentKeys: Set<String> = []
    var replaceSameDateScopes: Set<String> = []
}

public struct InvestmentImportPlan: nonisolated Equatable, Sendable {
    let providerGeneration: ProviderGenerationToken
    let workspace: WorkspaceDTO
    let history: ConfirmedImportHistoryTemplateDTO
    let evidence: InvestmentStatementEvidence
    let baseline: InvestmentSnapshot
    let choices: InvestmentImportChoices

    func validate() throws {
        try evidence.validate()
        _ = try baseline.validated(workspaceID: workspace.id)
        try history.validateFingerprints()
        guard let normalized = history.normalizedDocument, history.normalizedRows.isEmpty,
              history.document.workspaceId == workspace.id, history.importSession.workspaceId == workspace.id,
              history.document.importSessionId == history.importSession.id,
              normalized.documentId == history.document.id, normalized.importSessionId == history.importSession.id,
              normalized.profileId == evidence.parserProfile, normalized.profileVersion == "1",
              history.successfulAttempt.workspaceId == workspace.id,
              history.successfulAttempt.documentId == history.document.id,
              history.successfulAttempt.importSessionId == history.importSession.id,
              history.successfulAttempt.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue,
              history.successfulAttempt.transactionCount == 0,
              history.duplicateAuthorityFingerprint != nil else {
            throw InvestmentError.invalidEvidence
        }
    }
}

nonisolated enum InvestmentChangeKind: String, CaseIterable, Sendable { case added = "Added", updated = "Updated", removed = "Removed", unchanged = "Unchanged" }

nonisolated struct InvestmentChange: Identifiable, Equatable, Sendable {
    let id: String
    let scopeKey: String
    let portfolio: String
    let kind: InvestmentChangeKind
    let before: InvestmentHolding?
    let after: InvestmentHolding?
    var name: String { after?.displayName ?? before?.displayName ?? "Investment" }
}

nonisolated public struct InvestmentUpdateReview: Equatable, Sendable {
    let changes: [InvestmentChange]
    let sameDateConflictScopes: Set<String>
    let snapshot: InvestmentSnapshot
    let affectedContainerIDs: Set<String>
    let mappingQuestions: [InvestmentMappingQuestion]

    var requiresChoice: Bool { !sameDateConflictScopes.isEmpty || !mappingQuestions.isEmpty }
    func count(_ kind: InvestmentChangeKind) -> Int { changes.filter { $0.kind == kind }.count }
}

nonisolated struct InvestmentMappingQuestion: Identifiable, Equatable, Sendable {
    enum Kind: Sendable { case container, instrument }
    struct Candidate: Equatable, Sendable { let id: String; let label: String }
    let id: String
    let scopeKey: String
    let kind: Kind
    let label: String
    let candidates: [Candidate]
}

nonisolated public enum InvestmentImportRepositoryResult: Equatable {
    case committed(importSessionID: String)
    case exactSourceDuplicate(PriorImportedStatementDTO)
    case rejected(InvestmentError)
    case staleProviderGeneration, retryableContention, repositoryIntegrityConflict, persistenceUnavailable
}

public protocol InvestmentRepository {
    func snapshot(workspaceID: String) throws -> InvestmentSnapshot
    func commitCurrentHoldings(_ plan: InvestmentImportPlan) -> InvestmentImportRepositoryResult
}

struct EmptyInvestmentRepository: InvestmentRepository {
    func snapshot(workspaceID: String) throws -> InvestmentSnapshot { .empty }
    func commitCurrentHoldings(_ plan: InvestmentImportPlan) -> InvestmentImportRepositoryResult { .persistenceUnavailable }
}

struct UnavailableInvestmentRepository: InvestmentRepository {
    func snapshot(workspaceID: String) throws -> InvestmentSnapshot { throw RepositoryError.persistenceUnavailable }
    func commitCurrentHoldings(_ plan: InvestmentImportPlan) -> InvestmentImportRepositoryResult { .persistenceUnavailable }
}

/// Pure current-state replacement. Both providers re-run this under their transaction lock.
enum InvestmentUpdatePlanner {
    static func review(_ plan: InvestmentImportPlan, current: InvestmentSnapshot) throws -> InvestmentUpdateReview {
        try plan.validate()
        guard current == plan.baseline else { throw InvestmentError.staleReview }
        var containers = current.containers
        var holdings = current.holdings
        var changes: [InvestmentChange] = []
        var conflicts = Set<String>(), affected = Set<String>()
        var questions: [InvestmentMappingQuestion] = []
        for (offset, scope) in plan.evidence.scopes.enumerated() {
            let printedAliases = Set(scope.aliases + [scope.identity])
            let matches = containers.filter { candidate in
                guard compatibleInstitution(scope, candidate), candidate.identityKind == scope.identityKind,
                      !Set(candidate.aliases).isDisjoint(with: printedAliases) else { return false }
                if candidate.institution == scope.institution { return true }
                // A CAS summary omits the fund-house heading. Bind it to a known
                // fund house only through the same printed folio and exact ISIN.
                let instruments = Set(scope.positions.map(\.instrumentIdentity))
                return current.holdings.contains { $0.containerID == candidate.id && instruments.contains($0.instrumentIdentity) }
            }
            guard matches.count <= 1 else { throw InvestmentError.identityChoiceRequired }
            var prior = matches.first
            if let target = plan.choices.containerTargets[scope.key] {
                guard let chosen = current.containers.first(where: { $0.id == target }),
                      compatibleInstitution(scope, chosen), chosen.identityKind == scope.identityKind,
                      prior == nil || prior?.id == chosen.id else { throw InvestmentError.identityChoiceRequired }
                prior = chosen
            }
            if let prior, scope.holdingsDate < prior.holdingsDate { throw InvestmentError.olderSnapshot }
            // An all-zero historical folio with no established container or
            // confirmed alias contributes no current holding. A shared ISIN in
            // another folio does not make that historical folio a removal scope.
            if prior == nil && scope.positions.allSatisfy({ $0.units.value == 0 }) { continue }
            if scope.identityKind == "folio", prior == nil, !plan.choices.newContainerScopes.contains(scope.key) {
                let incomingInstruments = Set(scope.positions.map(\.instrumentIdentity))
                let candidates = current.containers.filter { candidate in
                    compatibleInstitution(scope, candidate) && candidate.identityKind == scope.identityKind
                        && (!Set(candidate.aliases).isDisjoint(with: printedAliases)
                            || current.holdings.contains { $0.containerID == candidate.id && incomingInstruments.contains($0.instrumentIdentity) })
                }
                if !candidates.isEmpty {
                    questions.append(.init(id: scope.key, scopeKey: scope.key, kind: .container,
                        label: scope.displayName + " · " + scope.identity,
                        candidates: candidates.map { .init(id: $0.id, label: $0.displayName + " · " + $0.identity) }))
                }
            }
            let containerID = prior?.id ?? "investment-container-\(plan.history.importSession.id)-\(offset)"
            guard affected.insert(containerID).inserted else { throw InvestmentError.identityChoiceRequired }
            let oldHoldings = holdings.filter { $0.containerID == containerID }
            var container = prior ?? InvestmentContainer(id: containerID, workspaceID: plan.workspace.id,
                institution: scope.institution, identityKind: scope.identityKind, identity: scope.identity,
                aliases: [], displayName: scope.displayName, holdingsDate: scope.holdingsDate,
                completeAtHoldingsDate: scope.isComplete, documentID: plan.history.document.id,
                importSessionID: plan.history.importSession.id)
            container.aliases = Set(container.aliases).union(printedAliases).sorted()
            if scope.institution != casSummaryInstitution {
                container.institution = scope.institution
                container.displayName = scope.displayName
            }
            container.holdingsDate = scope.holdingsDate
            container.completeAtHoldingsDate = scope.isComplete || (prior?.holdingsDate == scope.holdingsDate && prior?.completeAtHoldingsDate == true)
            container.documentID = plan.history.document.id
            container.importSessionID = plan.history.importSession.id
            var mentionedIDs = Set<String>()
            for (row, position) in scope.positions.enumerated() {
                let aliasKey = scope.key + "\u{1F}" + position.instrumentIdentity + "\u{1F}" + position.currency
                let incomingKeys = identityKeys(position.instrumentIdentity, aliases: position.sourceAliases)
                let candidates = oldHoldings.filter {
                    $0.currency == position.currency
                        && !identityKeys($0.instrumentIdentity, aliases: $0.sourceAliases).isDisjoint(with: incomingKeys)
                }
                guard candidates.count <= 1 else { throw InvestmentError.identityChoiceRequired }
                var old = candidates.first
                if let target = plan.choices.instrumentTargets[aliasKey] {
                    guard let chosen = oldHoldings.first(where: { $0.id == target }), chosen.currency == position.currency,
                          old == nil || old?.id == chosen.id else { throw InvestmentError.identityChoiceRequired }
                    old = chosen
                }
                if old == nil, !plan.choices.newInstrumentKeys.contains(aliasKey) {
                    // Only the known weak-name/strong-identifier boundary needs an
                    // explicit mapping. An ISIN in a different folio is not an alias.
                    let candidates = oldHoldings.filter {
                        $0.currency == position.currency &&
                            ($0.instrumentIdentity.hasPrefix("cbq-fund-name:") || position.instrumentIdentity.hasPrefix("cbq-fund-name:"))
                    }
                    if !candidates.isEmpty && position.units.value != 0 {
                        questions.append(.init(id: aliasKey, scopeKey: scope.key, kind: .instrument,
                            label: position.displayName, candidates: candidates.map { .init(id: $0.id, label: $0.displayName) }))
                    }
                }
                let id = old?.id ?? "investment-holding-\(plan.history.importSession.id)-\(offset)-\(row)"
                guard mentionedIDs.insert(id).inserted else { throw InvestmentError.identityChoiceRequired }
                if position.units.value == 0 {
                    if let old {
                        holdings.removeAll { $0.id == old.id }
                        changes.append(.init(id: id, scopeKey: scope.key, portfolio: container.displayName, kind: .removed, before: old, after: nil))
                    }
                    continue
                }
                let replacement = InvestmentHolding(id: id, containerID: containerID,
                    instrumentIdentity: old?.instrumentIdentity ?? position.instrumentIdentity,
                    sourceAliases: Set((old?.sourceAliases ?? []) + position.sourceAliases + [position.instrumentIdentity]).sorted(),
                    displayName: position.displayName, units: position.units, currency: position.currency,
                    averageCost: position.averageCost, totalCost: position.totalCost,
                    averageCostLabel: position.averageCostLabel, totalCostLabel: position.totalCostLabel,
                    costCurrency: position.costCurrency, holdingsDate: scope.holdingsDate,
                    documentID: plan.history.document.id, importSessionID: plan.history.importSession.id,
                    normalizedDocumentID: plan.history.normalizedDocument!.id,
                    sourceOrdinal: position.sourceOrdinal, parserProfile: plan.evidence.parserProfile,
                    issueDate: plan.evidence.issueDate, valuationDate: position.valuationDate,
                    priceMapping: old?.priceMapping)
                let sameDate = old?.holdingsDate == scope.holdingsDate
                let same = old.map { exactlyAgrees($0, replacement) } ?? false
                let kind: InvestmentChangeKind = old == nil ? .added : same ? .unchanged : .updated
                // Retain a same-date source only when its exact printed values and
                // evidence dates agree. Different precision or dates require the
                // same explicit source choice in either import order.
                var result = same && sameDate && !plan.choices.replaceSameDateScopes.contains(scope.key) ? old! : replacement
                result.sourceAliases = replacement.sourceAliases
                holdings.removeAll { $0.id == id }
                holdings.append(result)
                changes.append(.init(id: id, scopeKey: scope.key, portfolio: container.displayName, kind: kind, before: old, after: result))
            }
            if scope.isComplete {
                for old in oldHoldings where !mentionedIDs.contains(old.id) {
                    holdings.removeAll { $0.id == old.id }
                    changes.append(.init(id: old.id, scopeKey: scope.key, portfolio: container.displayName, kind: .removed, before: old, after: nil))
                }
            }
            if prior?.holdingsDate == scope.holdingsDate {
                let material = changes.filter { $0.scopeKey == scope.key && $0.kind != .unchanged }
                let contradicts = material.contains { $0.before != nil || prior?.completeAtHoldingsDate == true }
                if contradicts && !plan.choices.replaceSameDateScopes.contains(scope.key) { conflicts.insert(scope.key) }
            }
            containers.removeAll { $0.id == containerID }
            containers.append(container)
        }
        let result = try InvestmentSnapshot(containers: containers.sorted { $0.id < $1.id }, holdings: holdings.sorted { $0.id < $1.id })
            .validated(workspaceID: plan.workspace.id)
        return InvestmentUpdateReview(changes: changes, sameDateConflictScopes: conflicts,
            snapshot: result, affectedContainerIDs: affected, mappingQuestions: questions)
    }

    private static let casSummaryInstitution = "CAMS / KFin CAS"

    private static func compatibleInstitution(_ scope: InvestmentScopeEvidence, _ container: InvestmentContainer) -> Bool {
        scope.institution == container.institution
            || (scope.identityKind == "folio" && container.identityKind == "folio"
                && (scope.institution == casSummaryInstitution || container.institution == casSummaryInstitution))
    }

    /// Printed names and exchange-unspecified tickers are not identity mappings.
    /// Typed prior canonical identities enter aliases only through source evidence
    /// or an explicit confirmed mapping and work in either import direction.
    private static func identityKeys(_ identity: String, aliases: [String]) -> Set<String> {
        Set([identity] + aliases.filter {
            $0.hasPrefix("isin:") || $0.hasPrefix("ibkr-conid:")
                || $0.hasPrefix("cbq-fund-name:") || $0.hasPrefix("zurich-fund-name:")
        })
    }

    private static func exactlyAgrees(_ lhs: InvestmentHolding, _ rhs: InvestmentHolding) -> Bool {
        lhs.units == rhs.units && lhs.currency == rhs.currency && lhs.costCurrency == rhs.costCurrency
            && lhs.averageCost == rhs.averageCost && lhs.totalCost == rhs.totalCost
            && lhs.averageCostLabel == rhs.averageCostLabel && lhs.totalCostLabel == rhs.totalCostLabel
            && lhs.displayName == rhs.displayName && lhs.valuationDate == rhs.valuationDate
            && lhs.issueDate == rhs.issueDate
    }
}
