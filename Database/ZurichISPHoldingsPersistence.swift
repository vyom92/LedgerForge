import CryptoKit
import Foundation

/// A complete authenticated source replaces the same three current policy scopes
/// used by closing CSV imports. It creates no fabricated document/import history.
nonisolated public struct ZurichISPHoldingsPlan: Sendable {
    let providerGeneration: ProviderGenerationToken
    let workspace: WorkspaceDTO
    let baseline: InvestmentSnapshot
    let source: ZurichISPAccountSnapshot

    func applying(to current: InvestmentSnapshot, now: Date) throws -> InvestmentSnapshot {
        guard current.hasSameSource(as: baseline) else { throw InvestmentError.staleReview }
        _ = try current.validated(workspaceID: workspace.id)
        let existing = current.containers.filter { $0.institution == "Zurich ISP" }
        let expectedIDs = Set(existing.map(\.identity))
        try source.validate(expectedPolicyIDs: expectedIDs, now: now)
        var containers = current.containers, holdings = current.holdings
        for policy in source.policies {
            let matches = existing.filter { $0.identity == policy.policyID }
            guard matches.count <= 1 else { throw InvestmentError.identityChoiceRequired }
            let prior = matches.first
            if let prior, policy.valuationDay < prior.holdingsDate { throw InvestmentError.olderSnapshot }
            if let previous = prior?.zioSource {
                guard policy.fetchedAt >= previous.fetchedAt, policy.valuationDay >= previous.valuationDay else {
                    throw InvestmentError.olderSnapshot
                }
            }
            let containerID = prior?.id ?? Self.identity("container", workspace.id, policy.policyID)
            var container = InvestmentContainer(id: containerID, workspaceID: workspace.id,
                institution: "Zurich ISP", identityKind: "policy", identity: policy.policyID,
                aliases: prior?.aliases ?? [policy.policyID], displayName: policy.displayName,
                holdingsDate: policy.valuationDay, completeAtHoldingsDate: true,
                documentID: nil, importSessionID: nil)
            container.zioSource = policy
            if policy.policyID == source.policyIDs.sorted().first { container.lastZioAccount = source }
            let previousHoldings = holdings.filter { $0.containerID == containerID }
            if let prior, prior.zioSource == nil, policy.valuationDay == prior.holdingsDate {
                let incoming = policy.funds.filter { $0.units.value > 0 }
                guard previousHoldings.count == incoming.count,
                      previousHoldings.allSatisfy({ holding in
                          guard let mapping = InvestmentPriceRegistry.confirmedMapping(for: holding), mapping.provider == "fe",
                                let fund = incoming.first(where: { $0.code == mapping.code && $0.currency == holding.currency }) else { return false }
                          return holding.units.value == fund.units.value
                      }) else { throw InvestmentError.sameDateConflict }
            }
            var replacements: [InvestmentHolding] = []
            for fund in policy.funds where fund.units.value > 0 {
                guard let definition = InvestmentPriceRegistry.definitions.first(where: {
                    $0.mapping.provider == "fe" && $0.mapping.code == fund.code && $0.mapping.currency == fund.currency
                }) else { throw InvestmentError.identityChoiceRequired }
                let candidates = previousHoldings.filter {
                    InvestmentPriceRegistry.confirmedMapping(for: $0)?.code == fund.code
                }
                guard candidates.count <= 1 else { throw InvestmentError.identityChoiceRequired }
                let old = candidates.first
                var holding = InvestmentHolding(id: old?.id ?? Self.identity("holding", containerID, fund.code),
                    containerID: containerID, instrumentIdentity: old?.instrumentIdentity ?? definition.sourceIdentity,
                    sourceAliases: old?.sourceAliases ?? [definition.sourceIdentity], displayName: fund.name,
                    units: fund.units, currency: fund.currency, averageCost: nil, totalCost: nil,
                    averageCostLabel: nil, totalCostLabel: nil, costCurrency: nil,
                    holdingsDate: policy.valuationDay, documentID: nil, importSessionID: nil, normalizedDocumentID: nil,
                    sourceOrdinal: fund.ordinal, parserProfile: "zurich.isp.zio", issueDate: nil,
                    valuationDate: policy.valuationDay, priceMapping: definition.mapping)
                holding.zioObservationID = policy.observationID
                holding.zioFundCode = fund.code
                replacements.append(holding)
            }
            containers.removeAll { $0.id == containerID }; containers.append(container)
            holdings.removeAll { $0.containerID == containerID }; holdings.append(contentsOf: replacements)
        }
        return try InvestmentSnapshot(containers: containers.sorted { $0.id < $1.id }, holdings: holdings.sorted { $0.id < $1.id })
            .validated(workspaceID: workspace.id)
    }

    private static func identity(_ kind: String, _ scope: String, _ key: String) -> String {
        "investment-zio-" + kind + "-" + SHA256.hash(data: Data([scope, key].joined(separator: "\u{1F}").utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated public enum ZurichISPHoldingsResult: Equatable, Sendable {
    case saved
    case rejected(InvestmentError)
    case staleProviderGeneration, retryableContention, unavailable
}
