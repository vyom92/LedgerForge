import Foundation

/// Exact conversion mechanics, independent of accounts, sources and UI.
nonisolated enum NetWorthArithmetic {
    struct Fraction: Equatable, Sendable {
        let numerator: InvestmentArithmetic.Exact
        let denominator: InvestmentArithmetic.Exact
        static let zero = Self(numerator: .init(digits: [0], scale: 0, negative: false), denominator: .one)
    }

    static func dependencies(from native: ReportingCurrency, to target: ReportingCurrency,
                             isProvenZero: Bool) -> Set<AlDarCurrency> {
        guard native != target, !isProvenZero else { return [] }
        switch (native, target) {
        case (.qar, .inr), (.inr, .qar): return [.inr]
        case (.qar, .usd), (.usd, .qar): return [.usd]
        default: return [.inr, .usd]
        }
    }

    static func convert(_ value: Decimal, from native: ReportingCurrency, to target: ReportingCurrency,
                        rates: [AlDarCurrency: Decimal]) throws -> Fraction {
        let number = try InvestmentArithmetic.Exact(value)
        guard native != target, !number.isZero else { return .init(numerator: number, denominator: .one) }
        func rate(_ currency: AlDarCurrency) throws -> InvestmentArithmetic.Exact {
            guard let value = rates[currency], value > 0 else { throw InvestmentCalculationError.invalidDenominator }
            return try InvestmentArithmetic.Exact(value)
        }
        switch (native, target) {
        case (.qar, .usd): return try .init(numerator: InvestmentArithmetic.product(number, rate(.usd)), denominator: .one)
        case (.qar, .inr): return try .init(numerator: InvestmentArithmetic.product(number, rate(.inr)), denominator: .one)
        case (.usd, .qar): return try .init(numerator: number, denominator: rate(.usd))
        case (.inr, .qar): return try .init(numerator: number, denominator: rate(.inr))
        case (.usd, .inr): return try .init(numerator: InvestmentArithmetic.product(number, rate(.inr)), denominator: rate(.usd))
        case (.inr, .usd): return try .init(numerator: InvestmentArithmetic.product(number, rate(.usd)), denominator: rate(.inr))
        default: return .init(numerator: number, denominator: .one)
        }
    }

    static func sum(_ amounts: [Fraction]) throws -> Fraction {
        // At most three denominators (1, I, U). Combine equal denominators first
        // so a long portfolio cannot grow a product of identical FX rates.
        var groups: [Fraction] = []
        for amount in amounts {
            guard amount.denominator.sign > 0 else { throw InvestmentCalculationError.invalidDenominator }
            if let index = groups.firstIndex(where: { $0.denominator == amount.denominator }) {
                groups[index] = try .init(numerator: InvestmentArithmetic.combine(groups[index].numerator, amount.numerator),
                                          denominator: amount.denominator)
            } else { groups.append(amount) }
        }
        return try groups.reduce(.zero) { result, amount in
            try .init(numerator: InvestmentArithmetic.combine(
                InvestmentArithmetic.product(result.numerator, amount.denominator),
                InvestmentArithmetic.product(amount.numerator, result.denominator)),
                denominator: InvestmentArithmetic.product(result.denominator, amount.denominator))
        }
    }
}

nonisolated struct NetWorthComponent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let currency: String
    let nativeValue: Decimal?
    let dateContext: String
    let quote: InvestmentQuote?
    let issue: String?
    var portfolioGroup: InvestmentPortfolioGroup? = nil
    var hasSupportedCost: Bool? = nil
}

nonisolated struct NetWorthMember: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable { case bank = "Bank", card = "Cards", investment = "Investments" }
    let id: NetWorthMemberID
    let kind: Kind
    let title: String
    let context: String
    let identifierLabel: String?
    let isIncluded: Bool
    let components: [NetWorthComponent]
    let coverageIssue: String?

    /// A presentation default only: unknown balances and explicit exclusions
    /// stay visible, and zero never removes an eligible member from the report.
    var isIncludedZeroBalanceAccount: Bool {
        (kind == .bank || kind == .card) && isIncluded && components.count == 1 && components[0].nativeValue == 0
    }
}

nonisolated struct NetWorthContribution: Identifiable, Equatable, Sendable {
    let id: String
    let memberID: NetWorthMemberID
    let amount: NetWorthArithmetic.Fraction?
    let dependencies: Set<AlDarCurrency>
    let fxDates: [Date]
    let issues: [String]
    let isStale: Bool
}

nonisolated struct NetWorthTarget: Identifiable, Equatable, Sendable {
    let currency: ReportingCurrency
    var id: String { currency.rawValue }
    let amount: InvestmentConvertedAmount?
    let contributions: [NetWorthContribution]
    let isPartial: Bool
    let arithmeticFailure: Bool
    var missingCount: Int { contributions.filter { $0.amount == nil }.count }
    var isStale: Bool { contributions.contains(where: \.isStale) }
    var label: String {
        if arithmeticFailure { return "Total out of range" }
        if amount == nil { return "Value unavailable" }
        if isPartial { return isStale ? "Known subtotal · stale inputs" : "Known subtotal" }
        return isStale ? "Stale estimate" : "Available within recorded scope"
    }
}

nonisolated struct NetWorthReport: Equatable, Sendable {
    enum State: Equatable, Sendable { case loading, unavailable, membershipUnavailable, noData, noIncludedMembers, ready }
    let state: State
    let members: [NetWorthMember]
    let targets: [NetWorthTarget]
    let scopeNotes: [String]
    let historyOnlyCount: Int
    let generation: ProviderGenerationToken?
    static func withdrawn(_ state: State) -> Self {
        .init(state: state, members: [], targets: [], scopeNotes: [], historyOnlyCount: 0, generation: nil)
    }
}

/// A visual projection of the same exact contributions as the report. Drawing
/// coordinates never participate in totals, membership or drill-down selection.
nonisolated struct NetWorthChartProjection: Equatable, Sendable {
    struct ConvertedValue: Identifiable, Equatable, Sendable {
        var id: ReportingCurrency { currency }
        let currency: ReportingCurrency
        let amount: InvestmentConvertedAmount?
        let missingCount: Int
        var display: String { currency.rawValue + " " + (amount?.display ?? "Unavailable") }
    }

    /// Every visible currency describes the same selected components. A missing
    /// conversion remains explicit for that currency instead of removing a row.
    static func convertedValues(report: NetWorthReport, componentIDs: Set<String>) -> [ConvertedValue] {
        report.targets.map { target in
            let items = target.contributions.filter { componentIDs.contains($0.id) }
            let values = items.compactMap(\.amount)
            let sum = values.isEmpty ? nil : try? NetWorthArithmetic.sum(values)
            return .init(currency: target.currency,
                amount: sum.map { .init(numerator: $0.numerator, denominator: $0.denominator,
                    currency: target.currency.rawValue, coverage: values.count) },
                missingCount: items.count - values.count)
        }
    }

    enum Scope: String, CaseIterable, Identifiable, Sendable {
        case position = "Assets and liabilities"
        case allocation = "Investment allocation"
        var id: String { rawValue }
    }
    struct Row: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        let componentIDs: [String]
        let memberIDs: Set<NetWorthMemberID>
        let amount: InvestmentConvertedAmount?
        let missingCount: Int
        let isStale: Bool
        var shareOfPricedValue: String? = nil

        /// A finite, rounded plotting coordinate only. Exact fractions remain
        /// available for the text and independent aggregate reconciliation.
        var coordinate: Double? {
            guard let amount,
                  let token = try? InvestmentRatioFormatter.rounded(numerator: amount.numerator,
                    denominator: amount.denominator, places: 6),
                  let value = Double(token), value.isFinite else { return nil }
            return value
        }
    }
    let rows: [Row]
    let currency: ReportingCurrency
    let missingCount: Int
    let isPartial: Bool
    let isStale: Bool
    let costCount: Int
    let holdingCount: Int

    static func make(report: NetWorthReport, currency: ReportingCurrency, scope: Scope) -> Self {
        guard report.state == .ready, let target = report.targets.first(where: { $0.currency == currency }) else {
            return .init(rows: [], currency: currency, missingCount: 0, isPartial: true, isStale: false, costCount: 0, holdingCount: 0)
        }
        let members = report.members.filter { $0.isIncluded && (scope == .position || $0.kind == .investment) }
        let memberIDs = Set(members.map(\.id))
        let contributions = target.contributions.filter { memberIDs.contains($0.memberID) }
        func row(id: String, title: String, items: [NetWorthContribution]) -> Row {
            let values = items.compactMap(\.amount)
            let sum = values.isEmpty ? nil : try? NetWorthArithmetic.sum(values)
            let amount = sum.map { InvestmentConvertedAmount(numerator: $0.numerator, denominator: $0.denominator,
                currency: currency.rawValue, coverage: values.count) }
            return .init(id: id, title: title, componentIDs: items.map(\.id), memberIDs: Set(items.map(\.memberID)),
                amount: amount, missingCount: items.count - values.count, isStale: items.contains(where: \.isStale))
        }
        var rows: [Row] = []
        switch scope {
        case .position:
            for kind in NetWorthMember.Kind.allCases {
                let ids = Set(members.filter { $0.kind == kind }.map(\.id))
                let items = contributions.filter { ids.contains($0.memberID) }
                if kind == .card {
                    // Owner-selected overview: one net liability, preserving
                    // each signed account contribution in its drill-down.
                    if !items.isEmpty { rows.append(row(id: "Cards:net", title: "Total card liability", items: items)) }
                    continue
                }
                // Keep positive and negative balances apart. An overdrawn bank
                // account must retain its actual sign.
                for negative in [false, true] {
                    let signed = items.filter { item in
                        guard let value = item.amount else { return false }
                        return (value.numerator.sign < 0) == negative
                    }
                    if !signed.isEmpty {
                        rows.append(row(id: kind.rawValue + (negative ? ":negative" : ":positive"),
                            title: kind.rawValue + (negative ? " · liabilities" : " · assets"), items: signed))
                    }
                }
                let missing = items.filter { $0.amount == nil }
                if !missing.isEmpty { rows.append(row(id: kind.rawValue + ":missing", title: kind.rawValue + " · unavailable", items: missing)) }
            }
        case .allocation:
            let components = members.flatMap(\.components)
            for group in InvestmentPortfolioGroup.allCases.map(Optional.some) + [nil] {
                let ids = Set(components.filter { $0.portfolioGroup == group }.map(\.id))
                let items = contributions.filter { ids.contains($0.id) }
                if !items.isEmpty { rows.append(row(id: group?.id ?? "unmapped", title: group?.rawValue ?? "Unmapped investments", items: items)) }
            }
        }
        let holdings = report.members.filter { $0.isIncluded && $0.kind == .investment }.flatMap(\.components)
        if scope == .allocation, rows.allSatisfy({ ($0.amount?.numerator.sign ?? 0) >= 0 }),
           let sum = try? NetWorthArithmetic.sum(contributions.compactMap(\.amount)), sum.numerator.sign > 0 {
            let total = InvestmentConvertedAmount(numerator: sum.numerator, denominator: sum.denominator,
                currency: currency.rawValue, coverage: contributions.filter { $0.amount != nil }.count)
            for index in rows.indices { rows[index].shareOfPricedValue = rows[index].amount?.percent(of: total, positiveDenominator: true) }
        }
        return .init(rows: rows, currency: currency, missingCount: contributions.filter { $0.amount == nil }.count,
            isPartial: target.isPartial, isStale: contributions.contains(where: \.isStale),
            costCount: holdings.filter { $0.hasSupportedCost == true }.count, holdingCount: holdings.count)
    }
}

/// Reads one already-published canonical snapshot. It never selects sources,
/// opens repositories, fetches quotes or changes any financial/native fact.
enum NetWorthProjection {
    static func make(accounts: [Account], positions: [DashboardCurrencyPosition], investments: InvestmentSnapshot,
                     valuations: [String: InvestmentValuation], membership: NetWorthMembershipSnapshot?,
                     currencies: [ReportingCurrency], legs: [AlDarCurrency: AlDarUnitReference],
                     rateFailures: Set<AlDarCurrency>, priceFailures: Set<String>,
                     scopeNotes: [String], now: Date, generation: ProviderGenerationToken? = nil) -> NetWorthReport {
        guard let membership else { return .withdrawn(.membershipUnavailable) }
        let bankPositions = Dictionary(uniqueKeysWithValues: positions.flatMap(\.banks).map { ($0.id, $0) })
        let cardPositions = Dictionary(uniqueKeysWithValues: positions.flatMap(\.cards).map { ($0.id, $0) })
        var members: [NetWorthMember] = []
        for account in accounts where (account.type == .bank || account.type == .creditCard) && !account.isHistoryOnly {
            guard let id = account.repositoryAccountId else { return .withdrawn(.unavailable) }
            let memberID = NetWorthMemberID.account(id)
            let position = account.type == .bank ? bankPositions[id] : cardPositions[id]
            // Dashboard's card position supplies accepted source/date availability,
            // but its positive "amount owed" is not the signed reporting amount.
            let amount = position?.amount != nil && account.currentBalanceMoney.currency == account.nativeCurrency
                ? account.currentBalanceMoney.amount : nil
            let component = NetWorthComponent(id: memberID.stableKey, title: account.preferredDisplayName,
                currency: account.nativeCurrency.code, nativeValue: amount,
                dateContext: position?.asOf.map { "Balance as of \($0.presentation)" }
                    ?? position?.sourceContext ?? "Source balance/date unavailable",
                quote: nil, issue: amount == nil ? "Source-backed balance unavailable" : nil)
            members.append(.init(id: memberID, kind: account.type == .bank ? .bank : .card,
                title: component.title, context: ([account.institutionDisplayName] + account.identitySummaries.map(\.redactedValue).sorted()).joined(separator: " · "),
                identifierLabel: account.identitySummaries.map(\.redactedValue).sorted().first,
                isIncluded: !membership.excluded.contains(memberID), components: [component], coverageIssue: nil))
        }
        for container in investments.containers.sorted(by: { $0.id < $1.id }) {
            guard container.workspaceID == membership.workspaceID else { return .withdrawn(.unavailable) }
            let memberID = NetWorthMemberID.investmentContainer(container.id)
            let components = investments.holdings.filter { $0.containerID == container.id }
                .sorted { ($0.sourceOrdinal, $0.id) < ($1.sourceOrdinal, $1.id) }.map { holding in
                let valuation = valuations[holding.id]
                let quote = valuation?.quote
                let value = quote != nil ? valuation?.currentValue : nil
                return NetWorthComponent(id: "holding:" + holding.id, title: holding.displayName,
                    currency: holding.currency, nativeValue: value,
                    dateContext: "\(holding.sourceDateLabel) \(AppDateDisplay.civil(holding.holdingsDate))", quote: quote,
                    issue: value == nil ? (valuation?.issue ?? "Qualified price unavailable") : nil,
                    // A known container can remain CBQ even when a holding's
                    // price mapping is held. This labels ownership only; it
                    // supplies neither a price nor an instrument alias.
                    portfolioGroup: InvestmentPortfolioGroup.group(for: holding, container: container),
                    hasSupportedCost: valuation?.supportedCost != nil)
            }
            members.append(.init(id: memberID, kind: .investment, title: container.displayName,
                context: "\(container.institution) · \(container.identity) · Holdings as of \(AppDateDisplay.civil(container.holdingsDate))",
                identifierLabel: container.identity,
                isIncluded: !membership.excluded.contains(memberID), components: components,
                coverageIssue: container.completeAtHoldingsDate ? nil : "Holdings scope is incomplete"))
        }
        members.sort { ($0.kind.rawValue, $0.context, $0.title, $0.id.stableKey) < ($1.kind.rawValue, $1.context, $1.title, $1.id.stableKey) }
        let included = members.filter(\.isIncluded)
        let state: NetWorthReport.State = members.isEmpty ? .noData : included.isEmpty ? .noIncludedMembers : .ready
        let targets = state == .ready ? currencies.map { target in
            calculate(target, members: included, legs: legs, rateFailures: rateFailures,
                      priceFailures: priceFailures, scopeUnverified: !scopeNotes.isEmpty, now: now)
        } : []
        return .init(state: state, members: members, targets: targets, scopeNotes: scopeNotes,
                     historyOnlyCount: accounts.filter(\.isHistoryOnly).count, generation: generation)
    }

    private static func calculate(_ target: ReportingCurrency, members: [NetWorthMember],
                                  legs: [AlDarCurrency: AlDarUnitReference], rateFailures: Set<AlDarCurrency>,
                                  priceFailures: Set<String>, scopeUnverified: Bool, now: Date) -> NetWorthTarget {
        let rates = legs.mapValues { $0.returned.decimal }
        let contributions = members.flatMap { member in member.components.map { component -> NetWorthContribution in
            var issues: [String] = []
            if let issue = component.issue { issues.append(issue) }
            var dependencies: Set<AlDarCurrency> = [], dates: [Date] = [], stale = false
            var converted: NetWorthArithmetic.Fraction?
            if let quote = component.quote {
                if quote.freshnessAge(at: now) >= 4 { stale = true; issues.append("Price valuation is \(quote.age(at: now)) days old") }
                if priceFailures.contains(quote.mapping.identity) { issues.append("Price refresh failed; last successful quote retained") }
            }
            if let amount = component.nativeValue {
                if let native = ReportingCurrency(rawValue: component.currency) {
                    dependencies = NetWorthArithmetic.dependencies(from: native, to: target, isProvenZero: amount == 0)
                    for dependency in dependencies.sorted(by: { $0.rawValue < $1.rawValue }) {
                        if let leg = legs[dependency] {
                            dates.append(leg.fetchedAt)
                            if WeekdayFreshness.seconds(from: leg.fetchedAt, to: now) > AlDarReferenceSession.staleInterval {
                                stale = true; issues.append("\(dependency.rawValue) exchange rate is stale")
                            }
                            if rateFailures.contains(dependency) { issues.append("\(dependency.rawValue) rate refresh failed; last fetched rate retained") }
                        } else { issues.append("\(dependency.rawValue) exchange rate unavailable") }
                    }
                    if dependencies.allSatisfy({ legs[$0] != nil }) {
                        do { converted = try NetWorthArithmetic.convert(amount, from: native, to: target, rates: rates) }
                        catch { issues.append("Conversion is invalid or out of range") }
                    }
                } else { issues.append("Unsupported reporting currency: \(component.currency)") }
            }
            return .init(id: component.id, memberID: member.id, amount: converted, dependencies: dependencies,
                         fxDates: dates, issues: issues, isStale: stale)
        } }
        let available = contributions.compactMap(\.amount)
        // A resolved, complete empty container establishes absence of positions.
        // An unresolved empty scope does not establish zero.
        let establishedEmpty = contributions.isEmpty && members.allSatisfy { $0.components.isEmpty && $0.coverageIssue == nil }
        var amount: InvestmentConvertedAmount?, failed = false
        if !available.isEmpty || establishedEmpty {
            do {
                let total = try NetWorthArithmetic.sum(available)
                let value = InvestmentConvertedAmount(numerator: total.numerator, denominator: total.denominator,
                    currency: target.rawValue, coverage: available.count)
                if value.display == "Out of range" { failed = true } else { amount = value }
            } catch { failed = true }
        }
        let partial = scopeUnverified || members.contains { $0.coverageIssue != nil }
            || contributions.contains { $0.amount == nil } || failed
        return .init(currency: target, amount: amount, contributions: contributions, isPartial: partial, arithmeticFailure: failed)
    }

    static func scopeNotes(inbox: GmailInboxState?, importedSourceIDs: Set<String>) -> [String] {
        var notes = ["Coverage is not established for every account. Held or unresolved updates are not included; recorded positions retain their own dates."]
        guard let inbox else { return notes }
        // Acquisition/attention is a global scope limitation, never evidence that
        // a particular account or instrument has a financially accepted update.
        let pending = inbox.orderedSources.filter { !importedSourceIDs.contains($0.id) }
        var seen: Set<String> = []
        let originals = pending.filter { seen.insert($0.sha256 ?? $0.id).inserted }
        let passwords = originals.filter { $0.attention == .password }.count
        let review = originals.filter { [.pending, .review, .invalid, .failed].contains($0.attention) }.count
        let skipped = originals.filter { $0.attention == .skipped }.count
        let unsupported = originals.filter { $0.attention == .unsupported }.count
        let details = [(review, "awaiting financial review"), (skipped, "skipped or held"),
                       (passwords, "password-held"), (unsupported, "unsupported")]
            .filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }
        if !details.isEmpty {
            notes.append("Saved email originals outside this ledger: " + details.joined(separator: ", ") + ". See Email Statements for source details.")
        }
        if inbox.activeScan != nil { notes.append("Email collection is incomplete.") }
        return notes
    }
}
