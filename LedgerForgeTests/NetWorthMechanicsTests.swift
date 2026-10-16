import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct NetWorthMechanicsTests {
    @Test func displayPreferenceRejectsInvalidValuesAndPreservesOneStableSelection() throws {
        let name = "LedgerForge-s99-preferences-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        for raw: Any in [[], ["EUR"], ["USD", "USD"], ["USD", 1], "USD"] {
            defaults.set(raw, forKey: ReportingCurrencyPreferences.key)
            #expect(ReportingCurrencyPreferences(defaults: defaults).currencies == [.usd, .inr])
        }
        defaults.set(["QAR", "INR", "USD"], forKey: ReportingCurrencyPreferences.key)
        let preferences = ReportingCurrencyPreferences(defaults: defaults)
        #expect(preferences.currencies == [.usd, .inr, .qar])
        preferences.setVisible(false, currency: .usd)
        preferences.setVisible(false, currency: .inr)
        preferences.setVisible(false, currency: .qar)
        #expect(preferences.currencies == [.qar])
        #expect(ReportingCurrencyPreferences(defaults: defaults).currencies == [.qar])
    }

    @Test func exactConversionPreservesAllSixDirectionsAndSignedCancellation() throws {
        // Numbers only: these are arithmetic operands, not financial fixtures.
        let rates: [AlDarCurrency: Decimal] = [.inr: 3, .usd: 2]
        let expected: [(ReportingCurrency, ReportingCurrency, String)] = [
            (.qar, .usd, "12"), (.qar, .inr, "18"), (.usd, .qar, "3"),
            (.inr, .qar, "2"), (.usd, .inr, "9"), (.inr, .usd, "4")]
        for (from, to, answer) in expected {
            let value = try NetWorthArithmetic.convert(6, from: from, to: to, rates: rates)
            #expect(try InvestmentRatioFormatter.rounded(numerator: value.numerator, denominator: value.denominator, places: 0) == answer)
        }
        let third = try NetWorthArithmetic.convert(1, from: .inr, to: .qar, rates: rates)
        let sum = try NetWorthArithmetic.sum(Array(repeating: third, count: 300))
        #expect(try InvestmentRatioFormatter.rounded(numerator: sum.numerator, denominator: sum.denominator, places: 0) == "100")
        let negative = try NetWorthArithmetic.convert(-1, from: .inr, to: .qar, rates: rates)
        #expect(try NetWorthArithmetic.sum([third, negative]).numerator.isZero)
        #expect(NetWorthArithmetic.dependencies(from: .inr, to: .usd, isProvenZero: false) == [.inr, .usd])
    }

    @Test func missingRatesNeverBecomeZeroAndIrrelevantLegsAreNotRequired() throws {
        #expect(throws: InvestmentCalculationError.self) { try NetWorthArithmetic.convert(1, from: .inr, to: .usd, rates: [.usd: 2]) }
        #expect(throws: InvestmentCalculationError.self) { try NetWorthArithmetic.convert(1, from: .usd, to: .qar, rates: [.usd: 0]) }
        #expect(throws: InvestmentCalculationError.self) { try NetWorthArithmetic.convert(1, from: .usd, to: .qar, rates: [.usd: -1]) }
        #expect(try NetWorthArithmetic.convert(0, from: .inr, to: .usd, rates: [:]).numerator.isZero)
        #expect(try NetWorthArithmetic.convert(7, from: .usd, to: .usd, rates: [:]).denominator == .one)
        #expect(NetWorthArithmetic.dependencies(from: .usd, to: .inr, isProvenZero: true).isEmpty)
        #expect(NetWorthArithmetic.dependencies(from: .qar, to: .usd, isProvenZero: false) == [.usd])
    }

    @Test func rangeFailuresRemainExplicitAndOnlyFinalDisplayRounds() throws {
        let huge = InvestmentArithmetic.Exact(digits: Array(repeating: 9, count: 512), scale: 0, negative: false)
        #expect(throws: InvestmentCalculationError.self) { try NetWorthArithmetic.sum([.init(numerator: huge, denominator: .one)]) }
        let first = try NetWorthArithmetic.convert(1, from: .inr, to: .qar, rates: [.inr: 3])
        let total = try NetWorthArithmetic.sum([first, first])
        #expect(try InvestmentRatioFormatter.rounded(numerator: total.numerator, denominator: total.denominator, places: 0) == "1")
        #expect(try InvestmentRatioFormatter.rounded(numerator: first.numerator, denominator: first.denominator, places: 0) == "0")
    }

    @Test func selectedInputsDetermineCompletenessWhileSourceNotesStayInformational() throws {
        // Isolated presentation DTOs only: no statements, database or network.
        let instant = "2026-10-16T12:00:00Z"
        let now = try #require(ISO8601DateFormatter().date(from: instant))
        let account = Account(repositoryAccountId: "cash", workspaceId: "test", institution: "Test",
            name: "Cash", type: .bank, currencyCode: "QAR", currentBalance: 100,
            currentBalanceAsOfISO: "2026-10-16")
        let positions = DashboardPositionProjection.make(accounts: [account], transactions: [], cardSnapshot: .empty)
        let container = InvestmentContainer(id: "portfolio", workspaceID: "test", institution: "Test",
            identityKind: "portfolio", identity: "test", aliases: ["test"], displayName: "Portfolio",
            holdingsDate: "2026-10-16", completeAtHoldingsDate: true, documentID: nil, importSessionID: nil)
        let mapping = InvestmentPriceMapping(provider: "test", code: "unit", currency: "USD")
        let holding = InvestmentHolding(id: "holding", containerID: container.id, instrumentIdentity: "unit",
            sourceAliases: [], displayName: "Holding", units: try InvestmentDecimal("2"), currency: "USD",
            averageCost: nil, totalCost: nil, averageCostLabel: nil, totalCostLabel: nil, costCurrency: nil,
            holdingsDate: "2026-10-16", documentID: nil, importSessionID: nil, normalizedDocumentID: nil,
            sourceOrdinal: 0, parserProfile: "test", issueDate: nil, valuationDate: nil, priceMapping: mapping)
        let quote = InvestmentQuote(mapping: mapping, price: try InvestmentDecimal("10"), valuationDay: "2026-10-16",
            valuationText: nil, valuationInstant: nil, dateBasis: .providerCalendarDate, calendarTimeZone: "UTC",
            fetchedAt: now, sourceURL: "https://example.invalid", qualification: "Test")
        let valuations = [holding.id: InvestmentValuation(holding: holding, quote: quote)]
        let legs: [AlDarCurrency: AlDarUnitReference] = [
            .inr: try .init(currency: .inr, rawToken: "3", fetchedAtISO: instant),
            .usd: try .init(currency: .usd, rawToken: "2", fetchedAtISO: instant)]
        let notes = NetWorthProjection.scopeNotes(inbox: nil, importedSourceIDs: [])
        func report(balanceAvailable: Bool = true, priceAvailable: Bool = true, completeScope: Bool = true,
                    excludesPortfolio: Bool = false, rates: [AlDarCurrency: AlDarUnitReference]? = nil,
                    commentary: [String]? = nil, at date: Date? = nil) -> NetWorthReport {
            var scope = container
            scope.completeAtHoldingsDate = completeScope
            return NetWorthProjection.make(accounts: [account], positions: balanceAvailable ? positions : [],
                investments: .init(containers: [scope], holdings: [holding]), valuations: priceAvailable ? valuations : [:],
                membership: .init(workspaceID: "test", excluded: excludesPortfolio ? [.investmentContainer(scope.id)] : []),
                currencies: ReportingCurrency.allCases, legs: rates ?? legs, rateFailures: [], priceFailures: [],
                scopeNotes: commentary ?? notes, now: date ?? now)
        }
        let complete = report()
        #expect(!notes.isEmpty && complete.scopeNotes == notes)
        #expect(complete.targets == report(commentary: []).targets)
        let expected: [ReportingCurrency: String] = [.qar: "110", .usd: "220", .inr: "330"]
        for target in complete.targets {
            #expect(!target.isPartial && !target.isStale && target.missingCount == 0)
            #expect(target.label == "Recorded values")
            let amount = try #require(target.amount)
            #expect(try InvestmentRatioFormatter.rounded(numerator: amount.numerator,
                denominator: amount.denominator, places: 0) == expected[target.currency])
        }
        for incomplete in [report(balanceAvailable: false), report(priceAvailable: false)] {
            #expect(incomplete.targets.allSatisfy { $0.isPartial && $0.missingCount == 1 && $0.amount != nil })
            #expect(incomplete.targets.allSatisfy { $0.label == "Some values unavailable" })
        }
        let incompleteScope = report(completeScope: false)
        #expect(incompleteScope.targets.allSatisfy { $0.isPartial && $0.missingCount == 0 })
        #expect(incompleteScope.targets.compactMap(\.amount) == complete.targets.compactMap(\.amount))
        let excluded = report(priceAvailable: false, completeScope: false, excludesPortfolio: true)
        #expect(excluded.targets.allSatisfy { !$0.isPartial && $0.missingCount == 0 })
        let missingINR = report(rates: legs.filter { $0.key != .inr })
        #expect(missingINR.targets.filter { $0.currency != .inr } == complete.targets.filter { $0.currency != .inr })
        let unavailable = try #require(missingINR.targets.first { $0.currency == .inr })
        #expect(unavailable.isPartial && unavailable.missingCount == 2 && unavailable.amount == nil)
        #expect(unavailable.label == "Value unavailable")
        let stale = report(at: now.addingTimeInterval(12 * 86_400))
        #expect(stale.targets.allSatisfy { !$0.isPartial && $0.isStale && $0.label == "Some values are older" })
        #expect(stale.targets.compactMap(\.amount) == complete.targets.compactMap(\.amount))

        // The same report supplies the companion and Financial MCP Dashboard DTO.
        let snapshot = InvestmentSnapshot(containers: [container], holdings: [holding])
        let overview = InvestmentOverview.build(holdings: snapshot.holdings, valuations: valuations,
            legs: legs, containers: snapshot.containers)
        for value in [complete, incompleteScope, missingINR, stale] {
            let projected = try CompanionMacProjectionBuilder.make(ledgerLineage: "test", publicationID: "test",
                generation: 1, publishedAt: now, report: value, positions: positions, investmentSnapshot: snapshot,
                overview: overview, valuations: valuations, investmentsAvailable: true)
            #expect(projected.dashboard.scopeNotes == notes)
            #expect(projected.dashboard.totals.map(\.note) == value.targets.map { Optional($0.label) })
        }
    }
}
