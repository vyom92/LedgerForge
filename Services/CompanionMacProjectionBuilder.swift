import Foundation

/// Mac-only, no database or network access. Caller supplies one completed coherent
/// canonical generation and checks store/report/price freshness before publication.
@MainActor
enum CompanionMacProjectionBuilder {
    static func make(ledgerLineage: String, publicationID: String, generation: UInt64,
                     publishedAt: Date, report: NetWorthReport,
                     positions: [DashboardCurrencyPosition], investmentSnapshot: InvestmentSnapshot,
                     overview: InvestmentOverview, valuations: [String: InvestmentValuation],
                     investmentsAvailable: Bool,
                     plannerPresentation: CompanionPlannerPresentation? = nil) throws -> CompanionReadSnapshot {
        let members = report.members.map { member in
            CompanionReadMember(id: member.id.stableKey, title: member.title, kind: member.kind.rawValue,
                context: member.context, isIncluded: member.isIncluded,
                metrics: member.components.map { component in
                    decimal(id: component.id, label: component.title, value: component.nativeValue,
                            currency: component.currency, note: [component.dateContext, component.issue].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                } + NetWorthChartProjection.convertedValues(report: report, componentIDs: Set(member.components.map(\.id))).map {
                    amount(id: "converted:" + $0.currency.rawValue, label: "Report contribution · " + $0.currency.rawValue,
                        value: $0.amount, note: $0.missingCount > 0 ? "\($0.missingCount) components unavailable" : nil)
                }, details: [fact("context", "Context", member.context)]
                    + (member.coverageIssue.map { [fact("coverage", "Coverage", $0)] } ?? [])
                    + (member.identifierLabel.map { [fact("identifier", "Identifier", $0)] } ?? [])
                    + member.components.flatMap { component in
                        (component.quote.map(quoteDetails) ?? []).map {
                            fact(component.id + ":" + $0.id, component.title + " · " + $0.label, $0.value)
                        }
                    })
        }
        let dashboard = CompanionDashboardProjection(state: reportState(report.state), message: reportMessage(report.state),
            totals: report.targets.map { amount(id: $0.id, label: "Net worth estimate · " + $0.currency.rawValue,
                                               value: $0.amount, note: $0.label) },
            members: members, scopeNotes: report.scopeNotes, historyOnlyCount: report.historyOnlyCount,
            positions: positions.flatMap { position -> [CompanionPositionGroup] in
                [("bank", "Bank cash", position.bankTotal, position.banks),
                 ("card", "Card amounts owed", position.cardTotal, position.cards)].map { kind, title, total, accounts in
                    CompanionPositionGroup(id: kind + ":" + position.id, title: title + " · " + position.id,
                        total: money(id: kind + ":total:" + position.id, label: title, value: total),
                        accounts: accounts.map { account in
                            CompanionReadMember(id: account.id, title: account.displayName, kind: title,
                                context: account.institution, isIncluded: nil,
                                metrics: [money(id: "balance", label: title, value: account.amount)],
                                details: [fact("asOf", "Balance as of", account.asOf?.canonical ?? "Date unavailable"),
                                          fact("source", "Source context", account.sourceContext ?? "Unavailable"),
                                          fact("period", "Source period end", account.sourcePeriodEnd?.canonical ?? "Unavailable")])
                        })
                }
            }, charts: report.targets.flatMap { target in
                NetWorthChartProjection.Scope.allCases.map { scope in
                    let chart = NetWorthChartProjection.make(report: report, currency: target.currency, scope: scope)
                    return CompanionReadChart(id: target.id + ":" + scope.rawValue, title: scope.rawValue,
                        currency: target.currency.rawValue, rows: chart.rows.map { row in
                            CompanionReadChartRow(id: row.id, title: row.title, coordinate: row.coordinate,
                                metrics: NetWorthChartProjection.convertedValues(report: report, componentIDs: Set(row.componentIDs)).map {
                                    amount(id: $0.currency.rawValue, label: $0.currency.rawValue, value: $0.amount,
                                        note: $0.missingCount > 0 ? "\($0.missingCount) components unavailable" : nil)
                                } + (row.shareOfPricedValue.map { [textMetric("share", "Share of priced value", $0)] } ?? []),
                                details: [fact("basis", "Coverage", row.isStale ? "Some values are older" : "Recorded values")])
                        }, note: "\(chart.missingCount) components unavailable" + (chart.isStale ? " · Some values are older" : ""))
                }
            })
        let containers = investmentSnapshot.containers.map { container in
            var policyMetrics: [CompanionReadMetric] = []
            var policyDetails: [CompanionReadFact] = []
            if let policy = container.zioSource {
                policyMetrics = [
                    sourceAmount(id: "contributions", label: "Contributions", value: policy.contributions.amount, currency: policy.currency),
                    sourceAmount(id: "portalValue", label: "Portal value", value: policy.value.amount, currency: policy.currency),
                    sourceAmount(id: "reportedGrowth", label: "Reported growth", value: policy.growth.amount, currency: policy.currency),
                    sourceAmount(id: "allocatedContributions", label: "Allocated contributions", value: policy.allocatedContributions?.amount, currency: policy.currency),
                    decimal(id: "pendingAllocation", label: "Pending allocation", value: policy.pendingAllocation, currency: policy.currency),
                    sourceAmount(id: "vestedValue", label: "Vested value", value: policy.vestedValue?.amount, currency: policy.currency)
                ]
                policyDetails = [fact("portalValuation", "Portal valuation", policy.valuationDateText),
                                 fact("portalFetched", "Holdings fetched", instant(policy.fetchedAt)),
                                 fact("policyBasis", "Policy figures", "These policy-level source totals do not establish fund acquisition costs. The portal supplies no separate units-as-of date.")]
            }
            return CompanionInvestmentContainer(id: container.id, title: container.displayName, institution: container.institution,
                identityLabel: container.identityKind, identity: container.identity,
                includedInNetWorth: report.members.first { $0.id == .investmentContainer(container.id) }?.isIncluded,
                holdingIDs: investmentSnapshot.holdings.filter { $0.containerID == container.id }.map(\.id),
                metrics: policyMetrics,
                details: [fact("date", "Holdings date", container.holdingsDate),
                          fact("complete", "Source coverage", container.completeAtHoldingsDate ? "Complete at holdings date" : "Partial at holdings date")] + policyDetails)
        }
        let holdings = investmentSnapshot.holdings.map { holding -> CompanionInvestmentHolding in
            let container = investmentSnapshot.containers.first { $0.id == holding.containerID }
            let valuation = valuations[holding.id]
            var details = [fact("identity", "Instrument", holding.instrumentIdentity),
                           fact("codes", "ISIN / ticker", instrumentCodes(holding) ?? "Not in statement"),
                           fact("aliases", "Source aliases", holding.sourceAliases.joined(separator: " · ")),
                           fact("parser", "Source", holding.parserProfile),
                           fact("date", holding.sourceDateLabel, holding.holdingsDate)]
            if let date = holding.issueDate { details.append(fact("issueDate", "Issued", date)) }
            if let date = holding.valuationDate { details.append(fact("valuationDate", "Statement valuation date", date)) }
            if let quote = valuation?.quote { details += quoteDetails(quote) }
            if let mapping = valuation?.quote?.mapping ?? holding.priceMapping {
                details += [fact("provider", "Price provider", InvestmentPriceRegistry.providerNames[mapping.provider] ?? mapping.provider),
                            fact("lookup", "Provider lookup", mapping.code),
                            fact("publicInstrument", "Public instrument", mapping.instrumentReference ?? "Unavailable"),
                            fact("mapping", "Mapping evidence", mapping.evidence ?? "Unavailable")]
            }
            var metrics = [decimal(id: "value", label: "Current value", value: valuation?.currentValue, currency: holding.currency),
                           sourceAmount(id: "averageCost", label: holding.averageCostLabel ?? "Average cost", value: holding.averageCost, currency: holding.costCurrency ?? holding.currency),
                           sourceAmount(id: "totalCost", label: holding.totalCostLabel ?? "Source total cost", value: holding.totalCost, currency: holding.costCurrency ?? holding.currency),
                           decimal(id: "cost", label: valuation?.costBasis?.rawValue ?? "Supported cost", value: valuation?.supportedCost, currency: holding.currency),
                           decimal(id: "gain", label: "Gain / loss", value: valuation?.gain, currency: holding.currency),
                           textMetric("return", "Return", valuation?.simpleReturn?.display ?? "Unavailable")]
            metrics.append(sourceAmount(id: "price", label: "NAV / price", value: valuation?.quote?.price, currency: valuation?.quote?.mapping.currency))
            if let fund = overview.ispFunds.first(where: { $0.holdingIDs.contains(holding.id) }) {
                let positions = investmentSnapshot.holdings.filter { fund.holdingIDs.contains($0.id) }
                let share = InvestmentAllocationShare.policyUnits(positions, fund: fund)[holding.id]
                metrics.append(textMetric("policyUnitShare", "Share of this fund’s units", share?.label ?? "Unavailable"))
            }
            if let policy = container?.zioSource {
                details += [fact("portalDate", "Portal valuation date", policy.valuationDateText),
                            fact("portalFetched", "Holdings fetched", instant(policy.fetchedAt)),
                            fact("portalBasis", "Valuation basis", "The portal supplies no separate units-as-of date. Current value uses the public FE price.")]
                if let fund = policy.funds.first(where: { $0.code == holding.zioFundCode }) {
                    metrics += [sourceAmount(id: "portalPrice", label: "Portal unit price (exact)", value: fund.price, currency: fund.currency),
                                sourceAmount(id: "portalValue", label: "Portal value (exact)", value: fund.value, currency: fund.currency),
                                sourceAmount(id: "vested", label: "Portal vested value (exact)", value: fund.vestedValue, currency: fund.currency)]
                    details += [fact("portalAllocation", "Portal allocation", fund.allocation.sourceText + "%"),
                                fact("portalFX", "Portal FX rate", fund.fxRate.sourceText)]
                }
                if let strategy = policy.regularStrategy.first(where: { $0.code == holding.zioFundCode }) {
                    details += [fact("regularSplit", "Regular contribution split", strategy.percentage.sourceText + "%"),
                                fact("splitDate", "Split effective", strategy.effectiveDay),
                                fact("splitBasis", "Split meaning", "Contribution allocation within the policy; not this holding’s current weight.")]
                }
            }
            return CompanionInvestmentHolding(id: holding.id, containerID: holding.containerID,
                groupID: InvestmentPortfolioGroup.group(for: holding, container: container)?.id,
                title: holding.displayName, currency: holding.currency, unitsExact: holding.units.canonical,
                unitsDisplay: holding.units.sourceText, metrics: metrics, details: details, issue: valuation?.issue)
        }
        let groups = overview.portfolios.map { portfolio in
            CompanionInvestmentGroup(id: portfolio.id, title: portfolio.group.rawValue,
                metrics: scopeMetrics(portfolio.scope, performance: portfolio.group == .isp ? overview.ispPerformance : nil)
                    + [textMetric("capitalShare", overview.capitalShareLabel, portfolio.capitalShare ?? "Unavailable"),
                       textMetric("profitShare", overview.profitShareLabel, portfolio.profitShare ?? "Unavailable")],
                notes: [coverage(portfolio.scope)],
                holdingIDs: holdings.filter { $0.groupID == portfolio.id }.map(\.id),
                funds: portfolio.funds.map { fund in
                    CompanionInvestmentFund(id: fund.id, title: fund.name, identifier: fund.displayIdentifier,
                        holdingIDs: fund.holdingIDs, metrics: scopeMetrics(fund.scope)
                            + [textMetric("units", "Units", fund.unitsText),
                               textMetric("capitalShare", "Capital share within portfolio", fund.capitalShareWithinPortfolio ?? "Unavailable"),
                               textMetric("profitShare", "Profit share within portfolio", fund.profitShareWithinPortfolio ?? "Unavailable")],
                        details: [fact("dates", "Holding dates", fund.holdingDates.joined(separator: ", "))]
                            + (fund.contributionStrategy.map { [fact("strategy", "Contribution strategy", $0)] } ?? [])
                            + (fund.quote.map(quoteDetails) ?? []))
                })
        }
        var investmentMetrics = scopeMetrics(overview.total, performance: overview.performance)
        var sourceDetails = [fact("coverage", "Coverage", coverage(overview.total))]
        for currency in overview.fxLegs.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            if let leg = overview.fxLegs[currency] {
                sourceDetails.append(fact("fx:" + currency.rawValue, "FX reference · " + currency.rawValue,
                                          "1 QAR = " + leg.returned.rawToken + " " + currency.rawValue + " · fetched " + leg.fetchedAtISO))
            }
        }
        if let reported = overview.ispReported {
            for (key, title, amounts) in [("contributions", "ISP contributions", reported.contributions),
                                         ("allocated", "ISP allocated contributions", reported.allocatedContributions),
                                         ("pending", "ISP pending allocation", reported.pendingAllocation),
                                         ("growth", "ISP reported growth", reported.growth),
                                         ("vested", reported.vestedLabel, reported.vested)] {
                investmentMetrics += amounts.map { amount(id: key + ":" + $0.currency, label: title, value: $0) }
            }
            sourceDetails += [fact("ispDays", "ISP valuation dates", reported.valuationDays.joined(separator: ", ")),
                              fact("ispFetched", "ISP fetched", instant(reported.fetchedAt))]
        }
        let investments = CompanionInvestmentsProjection(state: investmentsAvailable ? (holdings.isEmpty ? .empty : .ready) : .unavailable,
            message: investmentsAvailable ? nil : "Current investment data is unavailable on the Mac.",
            metrics: investmentMetrics, basis: overview.performanceBasis, sourceDetails: sourceDetails,
            groups: groups, containers: containers, holdings: holdings)
        let snapshot = CompanionReadSnapshot(schemaVersion: 1, ledgerLineage: ledgerLineage,
            publicationID: publicationID, generation: generation, publishedAt: publishedAt,
            dashboard: dashboard, investments: investments, plannerPresentation: plannerPresentation)
        try snapshot.validateStructure()
        return snapshot
    }

    private static func fact(_ id: String, _ label: String, _ value: String) -> CompanionReadFact {
        .init(id: id, label: label, value: value)
    }
    private static func instrumentCodes(_ holding: InvestmentHolding) -> String? {
        if let mapping = InvestmentPriceRegistry.confirmedMapping(for: holding), mapping.provider == "fe" { return mapping.code }
        let aliases = [holding.instrumentIdentity] + holding.sourceAliases
        let isin = aliases.first(where: { $0.hasPrefix("isin:") }).map { String($0.dropFirst(5)) }
        let symbol = aliases.first(where: { $0.hasPrefix("symbol:") }).map { String($0.dropFirst(7)) }
        let codes = [isin, symbol].compactMap { $0 }
        return codes.isEmpty ? nil : codes.joined(separator: " · ")
    }
    private static func textMetric(_ id: String, _ label: String, _ display: String) -> CompanionReadMetric {
        .init(id: id, label: label, display: display, exact: nil, note: nil)
    }
    private static func exactText(_ value: InvestmentArithmetic.Exact) -> String {
        var text = value.digits.map(String.init).joined()
        if value.scale >= text.count { text = String(repeating: "0", count: value.scale - text.count + 1) + text }
        if value.scale > 0 { text.insert(".", at: text.index(text.endIndex, offsetBy: -value.scale)) }
        return (value.negative ? "-" : "") + text
    }
    private static func amount(id: String, label: String, value: InvestmentConvertedAmount?, note: String? = nil) -> CompanionReadMetric {
        .init(id: id, label: label, display: value?.display ?? "Unavailable",
              exact: value.map { .init(numerator: exactText($0.numerator), denominator: exactText($0.denominator), currency: $0.currency) }, note: note)
    }
    private static func decimal(id: String, label: String, value: Decimal?, currency: String, note: String? = nil) -> CompanionReadMetric {
        .init(id: id, label: label, display: InvestmentArithmetic.displayedMoney(value, currency: currency),
              exact: value.map { .init(numerator: InvestmentArithmetic.text($0), denominator: "1", currency: currency) }, note: note)
    }
    private static func money(id: String, label: String, value: Money?) -> CompanionReadMetric {
        .init(id: id, label: label, display: value.map { MoneyFormatting.display($0) } ?? "Unavailable",
              exact: value.map { .init(numerator: InvestmentArithmetic.text($0.amount), denominator: "1", currency: $0.currency.code) }, note: nil)
    }
    private static func sourceAmount(id: String, label: String, value: InvestmentDecimal?, currency: String?) -> CompanionReadMetric {
        .init(id: id, label: label,
              display: value.map { $0.sourceText + " " + (currency ?? "Currency unavailable") } ?? "Unavailable",
              exact: value.flatMap { value in currency.map { .init(numerator: value.canonical, denominator: "1", currency: $0) } }, note: nil)
    }
    private static func scopeMetrics(_ scope: InvestmentOverviewScope, performance: InvestmentOverviewScope? = nil) -> [CompanionReadMetric] {
        let basis = performance ?? scope
        return scope.lines.flatMap { line -> [CompanionReadMetric] in
            let costLine = basis.lines.first { $0.currency == line.currency }
            return [amount(id: "value:" + line.currency, label: (scope.priceCount < scope.holdingCount ? "Priced holdings value · " : "Current value · ") + line.currency,
                           value: line.value?.covering(scope.priceCount), note: coverage(scope)),
                    amount(id: "cost:" + line.currency, label: (performance == nil ? "Reported cost · " : "Invested / allocated · ") + line.currency,
                           value: costLine?.cost?.covering(basis.costCount), note: coverage(basis)),
                    amount(id: "gain:" + line.currency, label: (performance == nil ? "Gain / loss · " : "Gain / growth · ") + line.currency,
                           value: costLine?.gain?.covering(basis.gainCount)),
                    textMetric("return:" + line.currency, "Return · " + line.currency, costLine?.returnPercent ?? "Unavailable")]
        }
    }
    private static func coverage(_ scope: InvestmentOverviewScope) -> String {
        "\(scope.priceCount) of \(scope.holdingCount) holdings priced · \(scope.costCount) with cost · \(scope.gainCount) with gain/loss" + (scope.fxMissing ? " · FX unavailable" : "")
    }
    private static func quoteDetails(_ quote: InvestmentQuote) -> [CompanionReadFact] {
        [fact("priceDate", "NAV / price date", quote.valuationDay), fact("dateBasis", "Date basis", quote.dateBasis.label),
         fact("priceKind", "Price kind", quote.mapping.priceKind ?? "Unavailable"),
         fact("priceFetched", "Price fetched successfully", instant(quote.fetchedAt)),
         fact("qualification", "Price qualification", quote.qualification)]
            + (quote.valuationText.map { [fact("providerTime", "Provider date / time", $0)] } ?? [])
    }
    private static func instant(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    private static func reportState(_ state: NetWorthReport.State) -> CompanionProjectionState {
        switch state {
        case .loading: .loading
        case .unavailable, .membershipUnavailable: .unavailable
        case .noData, .noIncludedMembers: .empty
        case .ready: .ready
        }
    }
    private static func reportMessage(_ state: NetWorthReport.State) -> String? {
        switch state {
        case .loading: "The Mac is loading recorded positions."
        case .unavailable: "Current financial data is unavailable on the Mac."
        case .membershipUnavailable: "Saved reporting choices are unavailable on the Mac."
        case .noData: "No current bank, card or investment positions are recorded."
        case .noIncludedMembers: "No accounts are included in the report."
        case .ready: nil
        }
    }
}
