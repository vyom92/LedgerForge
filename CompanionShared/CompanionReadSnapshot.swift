import Foundation

/// Mac-authored presentation only. Never parse display text back into financial inputs.
nonisolated struct CompanionExactAmount: Codable, Equatable, Sendable {
    let numerator: String
    let denominator: String
    let currency: String
}

nonisolated struct CompanionReadMetric: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let display: String
    let exact: CompanionExactAmount?
    let note: String?
}

nonisolated struct CompanionReadFact: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
}

nonisolated struct CompanionReadMember: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let kind: String
    let context: String
    /// Nil for native positions whose report membership is not part of this projection.
    let isIncluded: Bool?
    let metrics: [CompanionReadMetric]
    let details: [CompanionReadFact]
}

nonisolated struct CompanionDashboardProjection: Codable, Equatable, Sendable {
    let state: CompanionProjectionState
    let message: String?
    let totals: [CompanionReadMetric]
    let members: [CompanionReadMember]
    let scopeNotes: [String]
    let historyOnlyCount: Int
    let positions: [CompanionPositionGroup]
    let charts: [CompanionReadChart]
}

/// Coordinates are for drawing only. All financial readouts remain Mac-authored
/// exact values; the phone never computes money from a plotting coordinate.
nonisolated struct CompanionReadChart: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let currency: String
    let rows: [CompanionReadChartRow]
    let note: String
}

nonisolated struct CompanionReadChartRow: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let coordinate: Double?
    let metrics: [CompanionReadMetric]
    let details: [CompanionReadFact]
}

nonisolated enum CompanionProjectionState: String, Codable, Sendable {
    case loading, unavailable, empty, ready
}

nonisolated struct CompanionPositionGroup: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let total: CompanionReadMetric
    let accounts: [CompanionReadMember]
}

nonisolated struct CompanionInvestmentGroup: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let metrics: [CompanionReadMetric]
    let notes: [String]
    let holdingIDs: [String]
    let funds: [CompanionInvestmentFund]
}

nonisolated struct CompanionInvestmentFund: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let identifier: String
    let holdingIDs: [String]
    let metrics: [CompanionReadMetric]
    let details: [CompanionReadFact]
}

nonisolated struct CompanionInvestmentContainer: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let institution: String
    let identityLabel: String
    let identity: String
    /// Nil means the reporting membership projection was unavailable.
    let includedInNetWorth: Bool?
    let holdingIDs: [String]
    let metrics: [CompanionReadMetric]
    let details: [CompanionReadFact]
}

nonisolated struct CompanionInvestmentHolding: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let containerID: String
    let groupID: String?
    let title: String
    let currency: String
    let unitsExact: String
    let unitsDisplay: String
    let metrics: [CompanionReadMetric]
    let details: [CompanionReadFact]
    let issue: String?
}

nonisolated struct CompanionInvestmentsProjection: Codable, Equatable, Sendable {
    let state: CompanionProjectionState
    let message: String?
    let metrics: [CompanionReadMetric]
    let basis: String
    let sourceDetails: [CompanionReadFact]
    let groups: [CompanionInvestmentGroup]
    let containers: [CompanionInvestmentContainer]
    let holdings: [CompanionInvestmentHolding]
}

/// Foreground reference for a valid open worksheet's presentation. This never
/// changes the retained monthly editor, source binding, or owner's FX choice.
/// A present wrapper with no quote preserves the Mac's unavailable-rate result.
nonisolated struct CompanionPlannerPresentation: Codable, Equatable, Sendable {
    let alDarQuote: AlDarReferenceQuote?
}

nonisolated struct CompanionReadSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let ledgerLineage: String
    let publicationID: String
    let generation: UInt64
    let publishedAt: Date
    let dashboard: CompanionDashboardProjection
    let investments: CompanionInvestmentsProjection
    /// Absent only in earlier retained publications; their saved-plan basis is kept.
    var plannerPresentation: CompanionPlannerPresentation? = nil

    /// Structural gate only; transport must additionally validate lineage, generation,
    /// complete delivery and size. Display strings are never a financial oracle.
    func validateStructure() throws {
        guard schemaVersion == 1, generation > 0, !ledgerLineage.isEmpty, !publicationID.isEmpty,
              publishedAt.timeIntervalSince1970.isFinite else { throw ValidationError.invalidIdentity }
        if let quote = plannerPresentation?.alDarQuote {
            guard quote.submittedQAR.amount == 1, quote.fetchedAt <= publishedAt else {
                throw ValidationError.invalidValue
            }
        }
        func unique(_ ids: [String]) -> Bool {
            ids.allSatisfy { !$0.isEmpty } && Set(ids).count == ids.count
        }
        // Validate numeric spelling without narrowing exact fractions to Decimal.
        func decimalToken(_ text: String, positive: Bool = false) -> Bool {
            guard text.range(of: #"\A-?[0-9]+(?:\.[0-9]+)?\z"#, options: .regularExpression) != nil else { return false }
            return !positive || (!text.hasPrefix("-") && text.utf8.contains { (49...57).contains($0) })
        }
        func currency(_ text: String) -> Bool {
            text.utf8.count == 3 && text.utf8.allSatisfy { (65...90).contains($0) }
        }
        func metrics(_ values: [CompanionReadMetric]) -> Bool {
            unique(values.map(\.id)) && values.allSatisfy { metric in
                guard let exact = metric.exact else { return true }
                return currency(exact.currency) && decimalToken(exact.numerator)
                    && decimalToken(exact.denominator, positive: true)
            }
        }
        func facts(_ values: [CompanionReadFact]) -> Bool { unique(values.map(\.id)) }
        func member(_ value: CompanionReadMember) -> Bool { metrics(value.metrics) && facts(value.details) }
        guard dashboard.historyOnlyCount >= 0, metrics(dashboard.totals),
              unique(dashboard.charts.map(\.id)), dashboard.charts.allSatisfy({ chart in
                  currency(chart.currency) && unique(chart.rows.map(\.id)) && chart.rows.allSatisfy {
                      ($0.coordinate?.isFinite ?? true) && metrics($0.metrics) && facts($0.details)
                  }
              }),
              dashboard.members.allSatisfy(member),
              dashboard.positions.allSatisfy({ metrics([$0.total]) && unique($0.accounts.map(\.id)) && $0.accounts.allSatisfy(member) }),
              metrics(investments.metrics), facts(investments.sourceDetails),
              investments.containers.allSatisfy({ metrics($0.metrics) && facts($0.details) }),
              investments.holdings.allSatisfy({ currency($0.currency) && decimalToken($0.unitsExact) && metrics($0.metrics) && facts($0.details) }),
              investments.groups.allSatisfy({ metrics($0.metrics) && $0.funds.allSatisfy { metrics($0.metrics) && facts($0.details) } }) else {
            throw ValidationError.invalidValue
        }
        let holdings = investments.holdings
        let containers = investments.containers
        guard unique(holdings.map(\.id)), unique(containers.map(\.id)),
              unique(investments.groups.map(\.id)), unique(dashboard.members.map(\.id)),
              unique(dashboard.positions.map(\.id)) else { throw ValidationError.invalidIdentity }
        let containerIDs = Set(containers.map(\.id)), holdingIDs = Set(holdings.map(\.id))
        let groupIDs = Set(investments.groups.map(\.id))
        guard holdings.allSatisfy({ containerIDs.contains($0.containerID) && ($0.groupID.map(groupIDs.contains) ?? true) }),
              containers.allSatisfy({ container in
                  unique(container.holdingIDs) && Set(container.holdingIDs) == Set(holdings.filter { $0.containerID == container.id }.map(\.id))
              }), investments.groups.allSatisfy({ group in
                  unique(group.holdingIDs) && Set(group.holdingIDs).isSubset(of: holdingIDs)
                      && Set(group.holdingIDs) == Set(holdings.filter { $0.groupID == group.id }.map(\.id))
                      && unique(group.funds.map(\.id))
                      && unique(group.funds.flatMap(\.holdingIDs))
                      && Set(group.funds.flatMap(\.holdingIDs)) == Set(group.holdingIDs)
                      && group.funds.allSatisfy { unique($0.holdingIDs) && Set($0.holdingIDs).isSubset(of: Set(group.holdingIDs)) }
              }) else { throw ValidationError.invalidRelationship }
    }

    enum ValidationError: Error { case invalidIdentity, invalidRelationship, invalidValue }
}
