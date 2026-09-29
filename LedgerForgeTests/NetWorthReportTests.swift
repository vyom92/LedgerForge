import Foundation
import Testing
@testable import LedgerForge

/// Financial operands come exclusively from the nominated, source-qualified
/// ledger and its actual public observations. No authored account/holding rows.
@Suite(.serialized)
@MainActor
struct NetWorthReportTests {
    @MainActor private struct Context {
        let provider: SQLiteRepositoryProvider
        let snapshot: RepositoryRuntimeSnapshot
        let workspaceID: String
        let cache: BackgroundPublicCacheSnapshot
        let now: Date
        var valuations: [String: InvestmentValuation] {
            Dictionary(uniqueKeysWithValues: snapshot.investments.holdings.map { holding in
                let quote = holding.priceMapping.flatMap { mapping in
                    InvestmentPriceRegistry.confirmedMapping(for: holding) == mapping ? cache.investmentQuotes[mapping.identity] : nil
                }
                return (holding.id, InvestmentValuation(holding: holding, quote: quote))
            })
        }
        func report(excluded: Set<NetWorthMemberID> = [], legs: [AlDarCurrency: AlDarUnitReference]? = nil,
                    valuations supplied: [String: InvestmentValuation]? = nil, now date: Date? = nil,
                    notes: [String] = ["Source coverage unresolved"]) -> NetWorthReport {
            NetWorthProjection.make(accounts: snapshot.accounts,
                positions: DashboardPositionProjection.make(accounts: snapshot.accounts, transactions: snapshot.transactions, cardSnapshot: snapshot.cardSnapshot),
                investments: snapshot.investments, valuations: supplied ?? valuations,
                membership: .init(workspaceID: workspaceID, excluded: excluded), currencies: ReportingCurrency.allCases,
                legs: legs ?? cache.alDarLegs, rateFailures: [], priceFailures: [], scopeNotes: notes, now: date ?? now,
                generation: provider.generationToken)
        }
    }

    private func context() throws -> Context {
        _ = try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_PRESENTATION_DATABASE"], "This campaign must explicitly nominate an isolated ledger.")
        let provider = try AuthenticSourceTestSupport.readOnlyRegisteredProvider(at: AuthenticSourceTestSupport.presentationDatabaseURL())
        let workspaces = try provider.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0)! }
        #expect(workspaces.count == 1)
        let workspace = try #require(workspaces.first)
        let runtime = DatabaseProvider.verifiedSQLite(provider)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: runtime, workspaceId: workspace,
            participatesInLifecycleGate: false).stageHydration()
        let now = Date()
        return .init(provider: provider, snapshot: snapshot, workspaceID: workspace,
                     cache: try provider.backgroundPublicCacheRepo.snapshot(now: now), now: now)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticAccountsKeepBankCashSeparateFromSourceCardLiabilities() throws {
        let source = try context(); defer { source.provider.database.close() }
        let accounts = AccountStore(), transactions = TransactionStore(), cards = CardStore()
        accounts.installAccountsWithoutObservation(source.snapshot.accounts)
        transactions.installTransactionsWithoutObservation(source.snapshot.transactions, validation: nil)
        cards.installSnapshotWithoutObservation(source.snapshot.cardSnapshot)
        let model = AccountsViewModel(accountStore: accounts, transactionStore: transactions,
            importSessionStore: ImportSessionStore(), metadataCoordinator: AccountMetadataCoordinator(), cardStore: cards)
        for summary in model.nativeBalanceSummaries {
            #expect(summary.banks.allSatisfy { id in source.snapshot.accounts.contains { $0.repositoryAccountId == id.id && $0.type == .bank && !$0.isHistoryOnly } })
            #expect(summary.cards.allSatisfy { id in source.snapshot.accounts.contains { $0.repositoryAccountId == id.id && $0.type == .creditCard && !$0.isHistoryOnly } })
            for position in summary.banks + summary.cards {
                #expect(model.accounts.first { $0.id == position.id }?.currentBalance == position.amount?.amount)
                if summary.cards.contains(where: { $0.id == position.id }), let amount = position.amount {
                    #expect(source.snapshot.cardSnapshot.statements.contains { $0.liabilityAccountID == position.id && $0.newBalance == amount })
                }
            }
            if !summary.banks.isEmpty && summary.banks.allSatisfy({ $0.amount != nil }) { #expect(summary.bankTotal == (try Money.aggregate(summary.banks.compactMap(\.amount)))) }
            if !summary.cards.isEmpty && summary.cards.allSatisfy({ $0.amount != nil }) { #expect(summary.cardTotal == (try Money.aggregate(summary.cards.compactMap(\.amount)))) }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticZurichContributionsEnterCapitalOnceWithoutInventingFundCosts() throws {
        let source = try context(); defer { source.provider.database.close() }
        let snapshot = source.snapshot.investments, account = try #require(snapshot.latestZioAccount)
        let before = try NetWorthTestSupport.financialDigest(source.provider.database)
        let overview = InvestmentOverview.build(holdings: snapshot.holdings, valuations: source.valuations,
            legs: source.cache.alDarLegs, containers: snapshot.containers, ispAccount: account)
        let isp = try #require(overview.ispPerformance)
        #expect(account.policies.count == 3 && isp.holdingCount == 7)
        let contributions = try account.policies.reduce(Decimal.zero) { $0 + (try #require($1.allocatedContributions)).amount.value }
        let policyContainers = Set(snapshot.containers.filter { account.policyIDs.contains($0.identity) }.map(\.id))
        let members = snapshot.holdings.filter { policyContainers.contains($0.containerID) }
        let values = members.compactMap { source.valuations[$0.id]?.currentValue }
        #expect(values.count == members.count)
        let current = values.reduce(Decimal.zero, +)
        func exact(_ actual: InvestmentConvertedAmount?, _ expected: Decimal) throws {
            let actual = try #require(actual)
            #expect(actual.numerator == (try InvestmentArithmetic.product(InvestmentArithmetic.Exact(expected), actual.denominator)))
        }
        try exact(isp.usd?.cost, contributions)
        try exact(isp.usd?.gain, current - contributions)
        #expect(isp.costCount == members.count && isp.gainCount == members.count)
        #expect(overview.performance.costCount == overview.total.costCount + members.count)
        #expect(overview.ispFunds.allSatisfy { $0.scope.costCount == 0 && $0.scope.gainCount == 0 && $0.scope.returnPercent == nil })
        let combined = try #require(overview.performance.usd?.cost), old = try #require(overview.total.usd?.cost)
        let left = try InvestmentArithmetic.product(combined.numerator, old.denominator)
        let right = try InvestmentArithmetic.product(old.numerator, combined.denominator)
        let added = try InvestmentArithmetic.product(InvestmentArithmetic.Exact(contributions), InvestmentArithmetic.product(combined.denominator, old.denominator))
        #expect(left == (try InvestmentArithmetic.combine(right, added)))
        var missing = source.valuations
        let withheld = try #require(members.first)
        missing[withheld.id] = InvestmentValuation(holding: withheld, quote: nil)
        let partial = InvestmentOverview.build(holdings: snapshot.holdings, valuations: missing, legs: source.cache.alDarLegs, containers: snapshot.containers, ispAccount: account)
        try exact(partial.ispPerformance?.usd?.cost, contributions)
        #expect(partial.ispPerformance?.hasCompleteGain == false)
        #expect(try NetWorthTestSupport.financialDigest(source.provider.database) == before)
    }

    @Test(.globalRuntimeStateIsolation)
    func qualifiedComponentsAndAllCurrencyTotalsMatchIndependentArithmetic() throws {
        let source = try context(); defer { source.provider.database.close() }
        let digest = try NetWorthTestSupport.financialDigest(source.provider.database)
        let snapshot = source.snapshot
        var expected: [String: (String, Decimal?)] = [:]
        for account in snapshot.accounts where [.bank, .creditCard].contains(account.type) && !account.isHistoryOnly {
            let id = try #require(account.repositoryAccountId)
            let available = account.type == .bank ? account.currentBalanceAsOfISO != nil
                : snapshot.cardSnapshot.statements.contains { $0.liabilityAccountID == id && $0.newBalance != nil }
            if account.type == .creditCard, available {
                // Independent source-summary sign check: the canonical balance
                // is one liability, not one value per instrument or section.
                #expect(snapshot.cardSnapshot.statements.contains {
                    $0.liabilityAccountID == id && $0.newBalance?.amount == -account.currentBalanceMoney.amount
                        && $0.newBalance?.currency == account.nativeCurrency
                })
            }
            expected[NetWorthMemberID.account(id).stableKey] = (account.nativeCurrency.code, available ? account.currentBalanceMoney.amount : nil)
        }
        var pricesWithoutCost = 0
        for holding in snapshot.investments.holdings {
            let mapping = holding.priceMapping
            let quote = mapping.flatMap { source.cache.investmentQuotes[$0.identity] }
            let qualified = mapping != nil && mapping == InvestmentPriceRegistry.confirmedMapping(for: holding)
                && quote?.mapping == mapping && quote?.mapping.currency == holding.currency
            // Foundation's checked primitive is deliberately independent of the
            // production digit-array product and reporting conversion functions.
            let value = try qualified ? quote.map { try multiply(holding.units.value, $0.price.value) } : nil
            expected["holding:" + holding.id] = (holding.currency, value)
            if value != nil && holding.averageCost == nil && holding.totalCost == nil { pricesWithoutCost += 1 }
        }
        let report = source.report()
        #expect(report.state == .ready)
        #expect(Set(report.members.flatMap(\.components).map(\.id)) == Set(expected.keys))
        #expect(report.members.count == Set(report.members.map(\.id)).count)
        #expect(report.members.filter { $0.kind == .investment }.count == snapshot.investments.containers.count)
        for container in snapshot.investments.containers {
            let sourceOrder = snapshot.investments.holdings.filter { $0.containerID == container.id }
                .sorted { ($0.sourceOrdinal, $0.id) < ($1.sourceOrdinal, $1.id) }.map { "holding:" + $0.id }
            #expect(report.members.first { $0.id == .investmentContainer(container.id) }?.components.map(\.id) == sourceOrder)
            #expect(report.members.first { $0.id == .investmentContainer(container.id) }?.identifierLabel == container.identity)
        }
        #expect(report.historyOnlyCount == snapshot.accounts.filter(\.isHistoryOnly).count)
        #expect(report.members.allSatisfy { member in
            !snapshot.accounts.filter(\.isHistoryOnly).compactMap(\.repositoryAccountId).contains {
                member.id == .account($0)
            }
        })
        for component in report.members.flatMap(\.components) {
            #expect(component.currency == expected[component.id]?.0)
            #expect(component.nativeValue == expected[component.id]?.1)
            #expect(!component.dateContext.isEmpty)
        }
        try independentExactOracle(report: report, inputs: expected, rates: source.cache.alDarLegs)
        for target in report.targets {
            #expect(target.isPartial)
            #expect(target.missingCount == expected.values.filter { $0.1 == nil }.count)
            print("S99_REPORT \(target.currency.rawValue) \(target.amount?.display ?? "unavailable") missing=\(target.missingCount) stale=\(target.isStale)")
        }
        #expect(pricesWithoutCost > 0)
        // Source-qualified container ownership stays visible while the genuine
        // CBQ instrument mappings are held. Counting a holding is not pricing it.
        let overview = InvestmentOverview.build(holdings: snapshot.investments.holdings,
            valuations: source.valuations, legs: source.cache.alDarLegs,
            containers: snapshot.investments.containers)
        let cbqContainerIDs = Set(snapshot.investments.containers.filter {
            $0.institution == "CBQ" && $0.identityKind == "fund-portfolio"
        }.map(\.id))
        let cbqHoldings = snapshot.investments.holdings.filter { cbqContainerIDs.contains($0.containerID) }
        let cbqOverview = try #require(overview.portfolios.first { $0.group == .cbq })
        #expect(!cbqHoldings.isEmpty)
        #expect(cbqOverview.scope.holdingCount == cbqHoldings.count)
        #expect(Set(cbqOverview.funds.flatMap(\.holdingIDs)) == Set(cbqHoldings.map(\.id)))
        #expect(cbqOverview.scope.priceCount == cbqHoldings.filter { expected["holding:" + $0.id]?.1 != nil }.count)
        #expect(cbqOverview.scope.costCount == cbqHoldings.filter { source.valuations[$0.id]?.supportedCost != nil }.count)
        for holding in cbqHoldings where InvestmentPriceRegistry.confirmedMapping(for: holding) == nil {
            let fund = try #require(cbqOverview.funds.first { $0.holdingIDs.contains(holding.id) })
            #expect(fund.holdingIDs == [holding.id] && fund.quote == nil)
            #expect(fund.scope.priceCount == 0 && fund.scope.gainCount == 0)
        }
        #expect(overview.total == InvestmentOverview.build(holdings: snapshot.investments.holdings,
            valuations: source.valuations, legs: source.cache.alDarLegs).total)
        #expect(try NetWorthTestSupport.financialDigest(source.provider.database) == digest)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticMembershipMissingPricesAndTargetSpecificFXRemainExplicit() throws {
        let source = try context(); defer { source.provider.database.close() }
        let initial = source.report()
        let exclusions = Set(initial.members.map(\.id))
        let none = source.report(excluded: exclusions)
        #expect(none.state == .noIncludedMembers && none.targets.isEmpty)
        #expect(none.members.allSatisfy { !$0.isIncluded })
        #expect(none.members.allSatisfy { !$0.isIncludedZeroBalanceAccount })
        for member in initial.members where member.kind == .card || member.kind == .bank {
            let balance = try #require(member.components.first).nativeValue
            #expect(member.isIncludedZeroBalanceAccount == (balance == 0))
        }
        let only = try #require(initial.members.first { $0.kind == .investment })
        let one = source.report(excluded: exclusions.subtracting([only.id]))
        #expect(one.targets.allSatisfy { $0.contributions.allSatisfy { $0.memberID == only.id } })
        let noPrices = source.report(valuations: [:])
        #expect(noPrices.members.filter { $0.kind == .investment }.flatMap(\.components).allSatisfy { $0.nativeValue == nil })
        let noRates = source.report(legs: [:])
        for target in noRates.targets {
            for component in noRates.members.flatMap(\.components) {
                let item = try #require(target.contributions.first { $0.id == component.id })
                let isAvailable = component.nativeValue != nil && (component.currency == target.currency.rawValue || component.nativeValue == 0)
                #expect((item.amount != nil) == isAvailable)
            }
        }
        let old = source.report(now: source.now.addingTimeInterval(5 * 86400))
        #expect(old.targets.allSatisfy { $0.isStale })
        #expect(old.members.flatMap(\.components) == initial.members.flatMap(\.components))
        #expect(old.targets.compactMap(\.amount) == initial.targets.compactMap(\.amount))
    }

    private enum OracleError: Error { case range, currency }

    @Test(.globalRuntimeStateIsolation)
    func chartsPartitionTheGenuineIncludedPositionsAndPreserveMissingAndSignedValues() throws {
        let source = try context(); defer { source.provider.database.close() }
        let initial = source.report()
        let excluded = try #require(initial.members.first { $0.kind == .investment })
        for report in [initial, source.report(excluded: [excluded.id]), source.report(legs: [:])] {
            for target in report.targets {
                for scope in NetWorthChartProjection.Scope.allCases {
                    let chart = NetWorthChartProjection.make(report: report, currency: target.currency, scope: scope)
                    let included = report.members.filter { $0.isIncluded && (scope == .position || $0.kind == .investment) }
                    let expected = included.flatMap(\.components)
                    let ids = chart.rows.flatMap(\.componentIDs)
                    #expect(ids.count == Set(ids).count)
                    #expect(Set(ids) == Set(expected.map(\.id)))
                    if scope == .position {
                        let cardIDs = Set(included.filter { $0.kind == .card }.flatMap(\.components).map(\.id))
                        let cardRows = chart.rows.filter { $0.id.hasPrefix("Cards:") }
                        #expect(cardRows.count == (cardIDs.isEmpty ? 0 : 1))
                        #expect(Set(cardRows.flatMap(\.componentIDs)) == cardIDs)
                        #expect(cardRows.allSatisfy { $0.id == "Cards:net" })
                    }
                    #expect(chart.missingCount == target.contributions.filter { ids.contains($0.id) && $0.amount == nil }.count)
                    for row in chart.rows {
                        let values = target.contributions.filter { row.componentIDs.contains($0.id) }.compactMap(\.amount)
                        if values.isEmpty {
                            #expect(row.amount == nil && row.coordinate == nil)
                        } else {
                            let sum = try NetWorthArithmetic.sum(values)
                            let actual = try #require(row.amount)
                            #expect(try InvestmentArithmetic.product(sum.numerator, actual.denominator)
                                == InvestmentArithmetic.product(actual.numerator, sum.denominator))
                            #expect(row.coordinate?.isFinite == true)
                        }
                        if scope == .position && row.id.hasSuffix(":negative") {
                            #expect(values.allSatisfy { $0.numerator.sign < 0 })
                            #expect((row.coordinate ?? 0) < 0)
                        }
                        if scope == .position && row.id.hasSuffix(":positive") {
                            #expect(values.allSatisfy { $0.numerator.sign >= 0 })
                        }
                        #expect(Set(row.memberIDs).isSubset(of: Set(included.map(\.id))))
                        let converted = NetWorthChartProjection.convertedValues(report: report, componentIDs: Set(row.componentIDs))
                        #expect(converted.map(\.currency) == report.targets.map(\.currency))
                        for (shown, target) in zip(converted, report.targets) {
                            let items = target.contributions.filter { row.componentIDs.contains($0.id) }
                            let amounts = items.compactMap(\.amount)
                            #expect(shown.missingCount == items.count - amounts.count)
                            if amounts.isEmpty { #expect(shown.amount == nil) }
                            else {
                                let expected = try NetWorthArithmetic.sum(amounts)
                                let actual = try #require(shown.amount)
                                #expect(try InvestmentArithmetic.product(expected.numerator, actual.denominator)
                                    == InvestmentArithmetic.product(actual.numerator, expected.denominator))
                            }
                        }
                    }
                    #expect(chart.costCount == source.snapshot.investments.holdings.filter { holding in
                        included.contains { $0.id == .investmentContainer(holding.containerID) }
                            && source.valuations[holding.id]?.supportedCost != nil
                    }.count)
                }
            }
        }
        #expect(NetWorthChartProjection.make(report: .withdrawn(.unavailable), currency: .usd, scope: .position).rows.isEmpty)
    }

    private func multiply(_ left: Decimal, _ right: Decimal) throws -> Decimal {
        var a = left, b = right, result = Decimal()
        guard NSDecimalMultiply(&result, &a, &b, .plain) == .noError, !result.isNaN else { throw OracleError.range }
        return result
    }
    private func independentExactOracle(report: NetWorthReport, inputs: [String: (String, Decimal?)],
                                        rates: [AlDarCurrency: AlDarUnitReference]) throws {
        func decimal(_ value: Decimal) -> String { var number = value; return NSDecimalString(&number, Locale(identifier: "en_US_POSIX")) }
        func exact(_ value: InvestmentArithmetic.Exact) -> String {
            let digits = value.digits.map(String.init).joined()
            return (value.negative ? "-" : "") + digits + "e-" + String(value.scale)
        }
        let inputRows: [[String: Any]] = inputs.sorted { $0.key < $1.key }.map {
            ["id": $0.key, "currency": $0.value.0, "value": $0.value.1.map(decimal) as Any? ?? NSNull()]
        }
        let targets: [[String: Any]] = try report.targets.map { target in
            let amount = try #require(target.amount)
            return ["currency": target.currency.rawValue, "numerator": exact(amount.numerator), "denominator": exact(amount.denominator),
                    "rounded": try InvestmentRatioFormatter.rounded(numerator: amount.numerator, denominator: amount.denominator, places: 0),
                    "charts": NetWorthChartProjection.Scope.allCases.map { scope -> [String: Any] in
                        let chart = NetWorthChartProjection.make(report: report, currency: target.currency, scope: scope)
                        return ["scope": scope.rawValue, "rows": chart.rows.map { row -> [String: Any] in
                            ["ids": row.componentIDs, "numerator": row.amount.map { exact($0.numerator) } as Any? ?? NSNull(),
                             "denominator": row.amount.map { exact($0.denominator) } as Any? ?? NSNull()]
                        }]
                    },
                    "contributions": target.contributions.map { item -> [String: Any] in
                        ["id": item.id, "numerator": item.amount.map { exact($0.numerator) } as Any? ?? NSNull(),
                         "denominator": item.amount.map { exact($0.denominator) } as Any? ?? NSNull()]
                    }]
        }
        let payload: [String: Any] = ["inputs": inputRows, "targets": targets,
            "rates": ["INR": decimal(try #require(rates[.inr]?.returned.decimal)), "USD": decimal(try #require(rates[.usd]?.returned.decimal))]]
        let command = Process(), input = Pipe(), output = Pipe()
        let python = try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_S99_ORACLE_PYTHON"], "Nominate the installed Python executable, not the xcrun launcher.")
        command.executableURL = URL(fileURLWithPath: python)
        command.arguments = [URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("script/verify_net_worth_oracle.py").path]
        command.standardInput = input; command.standardOutput = output; command.standardError = output
        try command.run()
        try input.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: payload))
        try input.fileHandleForWriting.close()
        let result = output.fileHandleForReading.readDataToEndOfFile()
        command.waitUntilExit()
        #expect(command.terminationStatus == 0, "Independent Fraction oracle: \(String(decoding: result, as: UTF8.self))")
    }
}
