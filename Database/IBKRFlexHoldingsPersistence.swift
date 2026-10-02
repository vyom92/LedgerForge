import CryptoKit
import Foundation

/// Only the authenticated account/conid scope is replaced. Original statement
/// history, all other providers and owner reporting choices stay untouched.
nonisolated public struct IBKRFlexHoldingsPlan: Sendable {
    let providerGeneration: ProviderGenerationToken
    let workspace: WorkspaceDTO
    let baseline: InvestmentSnapshot
    let source: IBKRFlexAccountSnapshot
    var backgroundJob: BackgroundJobRecord? = nil

    func applying(to current: InvestmentSnapshot, now: Date) throws -> InvestmentSnapshot {
        guard current.hasSameSource(as: baseline) else { throw InvestmentError.staleReview }
        _ = try current.validated(workspaceID: workspace.id)
        _ = try source.validated(expectedAccountID: source.accountID, now: now)
        let matches = current.containers.filter {
            $0.institution == "Interactive Brokers" && $0.identityKind == "account" && $0.identity == source.accountID
        }
        guard matches.count <= 1 else { throw InvestmentError.identityChoiceRequired }
        let prior = matches.first
        if let prior, source.reportDate < prior.holdingsDate { throw InvestmentError.olderSnapshot }
        if let previous = prior?.ibkrSource, source.fetchedAt < previous.fetchedAt { throw InvestmentError.olderSnapshot }
        let containerID = prior?.id ?? Self.identity("container", workspace.id, source.accountID)
        var container = InvestmentContainer(id: containerID, workspaceID: workspace.id,
            institution: "Interactive Brokers", identityKind: "account", identity: source.accountID,
            aliases: prior?.aliases ?? [source.accountID], displayName: prior?.displayName ?? "IBKR",
            holdingsDate: source.reportDate, completeAtHoldingsDate: true, documentID: nil, importSessionID: nil)
        container.ibkrSource = source
        let existing = current.holdings.filter { $0.containerID == containerID }
        let replacements = try source.positions.map { position in
            // ISIN is evidence, not authority for merging different contracts.
            let candidates = existing.filter { $0.instrumentIdentity == position.instrumentIdentity }
            guard candidates.count <= 1,
                  candidates.first.map({ $0.currency == position.currency }) ?? true else { throw InvestmentError.identityChoiceRequired }
            let old = candidates.first
            var holding = InvestmentHolding(id: old?.id ?? Self.identity("holding", containerID, position.conid),
                containerID: containerID, instrumentIdentity: position.instrumentIdentity,
                sourceAliases: Array(Set((old?.sourceAliases ?? []) + position.sourceAliases)).sorted(),
                displayName: old?.displayName ?? position.displayName, units: position.units, currency: position.currency,
                averageCost: position.averageCost, totalCost: position.totalCost,
                averageCostLabel: "Reported cost basis price", totalCostLabel: "Reported total cost",
                costCurrency: position.currency, holdingsDate: source.reportDate, documentID: nil, importSessionID: nil,
                normalizedDocumentID: nil, sourceOrdinal: position.sourceOrdinal, parserProfile: "ibkr.flex.open-positions",
                issueDate: nil, valuationDate: source.reportDate, priceMapping: old?.priceMapping)
            holding.ibkrObservationID = source.observationID
            return holding
        }
        return try InvestmentSnapshot(
            containers: (current.containers.filter { $0.id != containerID } + [container]).sorted { $0.id < $1.id },
            holdings: (current.holdings.filter { $0.containerID != containerID } + replacements).sorted { $0.id < $1.id })
            .validated(workspaceID: workspace.id)
    }

    private static func identity(_ kind: String, _ scope: String, _ key: String) -> String {
        "investment-ibkr-flex-" + kind + "-" + SHA256.hash(data: Data([scope, key].joined(separator: "\u{1F}").utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated public enum IBKRFlexHoldingsResult: Equatable, Sendable {
    case saved, rejected(InvestmentError), staleProviderGeneration, retryableContention, unavailable
}
