// LedgerForgeTests/TransactionListViewModelTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
enum Sprint89TransactionPresentationOracle {
    private struct Row {
        let transaction: Transaction
        let stableID: String
        let accountID: String?
        let accountName: String
        let institution: String
        let categoryID: String?
        let categoryName: String
        let domain: TransactionPresentationDomain
        let effect: TransactionPresentationEffect
        let date: StatementDate?
    }

    private struct Failure: LocalizedError {
        let reason: String
        var errorDescription: String? { "Sprint 89 presentation oracle: \(reason)" }
    }

    /// The accepted canonical database is presentation input. No statement is read or copied.
    static func verify(hydrated: RepositoryRuntimeSnapshot) throws -> [String] {
        var missingCases = [String]()
        guard hydrated.providerGeneration != nil else {
            throw Failure(reason: "hydrated snapshot has no provider generation")
        }
        let rows = independentRows(hydrated)
        try require(!rows.isEmpty, "empty authenticated transaction projection")

        var empty = TransactionPresentationFilterSpec.empty
        empty.searchText = "ledgerforge-sprint89-no-visible-match-4d8e"
        try verifyCase(name: "empty", filter: empty, sort: .init(), rows: rows, hydrated: hydrated)

        try verifyCase(
            name: "all",
            filter: .empty,
            sort: .init(),
            rows: rows,
            hydrated: hydrated
        )

        let splitSearch = try searchSplitAcrossDescriptionAndAccount(rows)
        var search = TransactionPresentationFilterSpec.empty
        search.searchText = splitSearch
        try verifyCase(name: "search-split", filter: search, sort: .init(), rows: rows, hydrated: hydrated)

        let punctuation = try literalPunctuationQuery(rows)
        search.searchText = punctuation
        try verifyCase(name: "search-punctuation", filter: search, sort: .init(), rows: rows, hydrated: hydrated)

        let hiddenID = try requireValue(rows.compactMap { $0.transaction.repositoryTransactionId }.first, "durable transaction identity")
        search.searchText = hiddenID
        try verifyCase(name: "search-hidden-identity", filter: search, sort: .init(), rows: rows, hydrated: hydrated)

        let accountIDs = Array(Set(rows.compactMap(\.accountID))).sorted()
        if accountIDs.count < 2 { missingCases.append("multiple accounts") }
        var accountFilter = TransactionPresentationFilterSpec.empty
        accountFilter.accountIDs = Set(accountIDs.prefix(2))
        try verifyCase(name: "account-or", filter: accountFilter, sort: .init(), rows: rows, hydrated: hydrated)

        let currencies = Array(Set(rows.map { $0.transaction.money.currency })).sorted { $0.code < $1.code }
        if currencies.count < 2 { missingCases.append("mixed native currencies") }
        for currency in currencies {
            var currencyFilter = TransactionPresentationFilterSpec.empty
            currencyFilter.currencies = [currency]
            try verifyCase(name: "currency", filter: currencyFilter, sort: .init(), rows: rows, hydrated: hydrated)
        }

        var uncategorized = TransactionPresentationFilterSpec.empty
        uncategorized.categories = [.uncategorized]
        try verifyCase(name: "uncategorized", filter: uncategorized, sort: .init(), rows: rows, hydrated: hydrated)

        for domain in [TransactionPresentationDomain.bank, .card] where !rows.contains(where: { $0.domain == domain }) {
            missingCases.append("\(domain.rawValue) transactions")
        }
        for effect in [TransactionPresentationEffect.credit, .debit, .increasesAmountOwed, .decreasesAmountOwed]
        where !rows.contains(where: { $0.effect == effect }) {
            missingCases.append("\(effect.rawValue) transactions")
        }
        if !rows.contains(where: { $0.date == nil }) { missingCases.append("unavailable source dates") }
        for domain in [TransactionPresentationDomain.bank, .card] {
            var filter = TransactionPresentationFilterSpec.empty
            filter.domains = [domain]
            try verifyCase(name: "domain-\(domain.rawValue)", filter: filter, sort: .init(), rows: rows, hydrated: hydrated)
        }
        for effect in [TransactionPresentationEffect.credit, .debit, .increasesAmountOwed, .decreasesAmountOwed] {
            var filter = TransactionPresentationFilterSpec.empty
            filter.effects = [effect]
            try verifyCase(name: "effect-\(effect.rawValue)", filter: filter, sort: .init(), rows: rows, hydrated: hydrated)
        }

        let institution = try requireValue(rows.map(\.institution).first(where: { !$0.isEmpty && $0 != "Unavailable" }), "institution coverage")
        var institutionFilter = TransactionPresentationFilterSpec.empty
        institutionFilter.institutionDisplayNames = [institution]
        try verifyCase(name: "institution", filter: institutionFilter, sort: .init(), rows: rows, hydrated: hydrated)

        let moneyRow = try requireValue(rows.first, "amount coverage")
        var amount = TransactionPresentationFilterSpec.empty
        amount.currencies = [moneyRow.transaction.money.currency]
        amount.amountRange = TransactionPresentationAmountRange(
            lowerBound: moneyRow.transaction.money.amount,
            upperBound: moneyRow.transaction.money.amount
        )
        try verifyCase(name: "amount-exact", filter: amount, sort: .init(), rows: rows, hydrated: hydrated)

        amount.amountRange = TransactionPresentationAmountRange(lowerBound: 1, upperBound: 0)
        try verifyInvalid(name: "amount-invalid", filter: amount, expected: .invalidAmountRange, hydrated: hydrated)

        let dated = try requireValue(rows.compactMap(\.date).sorted().first, "civil date coverage")
        var dateRange = TransactionPresentationFilterSpec.empty
        dateRange.statementDateRange = TransactionPresentationStatementDateRange(start: dated, end: dated)
        try verifyCase(name: "civil-date", filter: dateRange, sort: .init(), rows: rows, hydrated: hydrated)

        var month = TransactionPresentationFilterSpec.empty
        month.statementMonths = [try SelectedStatementMonth(year: dated.year, month: dated.month)]
        try verifyCase(name: "statement-month", filter: month, sort: .init(), rows: rows, hydrated: hydrated)

        for key in TransactionPresentationSortKey.allCases {
            for direction in [TransactionPresentationSortDirection.ascending, .descending] {
                try verifyCase(
                    name: "sort",
                    filter: .empty,
                    sort: TransactionPresentationSortSpec(key: key, direction: direction),
                    rows: rows,
                    hydrated: hydrated
                )
            }
        }
        var combined = accountFilter
        combined.currencies = [moneyRow.transaction.money.currency]
        combined.searchText = normalize(moneyRow.transaction.description).split(separator: " ").first.map(String.init) ?? ""
        try verifyCase(name: "combined-groups", filter: combined, sort: .init(), rows: rows, hydrated: hydrated)
        return missingCases
    }

    private static func verifyCase(
        name: String,
        filter: TransactionPresentationFilterSpec,
        sort: TransactionPresentationSortSpec,
        rows: [Row],
        hydrated: RepositoryRuntimeSnapshot
    ) throws {
        let expected = rows
            .filter { matches($0, filter: filter) }
            .sorted { compare($0, $1, sort: sort) == .orderedAscending }
        let actual = TransactionPresentationEngine.evaluate(
            transactions: hydrated.transactions,
            accounts: hydrated.accounts,
            categories: hydrated.categorySnapshot.categories,
            assignments: hydrated.categorySnapshot.assignments,
            filter: filter,
            sort: sort,
            availability: .available
        )
        let expectedState: TransactionPresentationResultState = expected.isEmpty ? .validEmpty : .ready
        try require(actual.state == expectedState, "\(name) state")
        try require(actual.rows.map(\.stableID) == expected.map(\.stableID), "\(name) membership/order")
        let expectedTotals = try totals(rows: expected)
        try require(actual.totals == expectedTotals, "\(name) totals")
    }

    private static func verifyInvalid(
        name: String,
        filter: TransactionPresentationFilterSpec,
        expected: TransactionPresentationResultState,
        hydrated: RepositoryRuntimeSnapshot
    ) throws {
        let actual = TransactionPresentationEngine.evaluate(
            transactions: hydrated.transactions,
            accounts: hydrated.accounts,
            categories: hydrated.categorySnapshot.categories,
            assignments: hydrated.categorySnapshot.assignments,
            filter: filter,
            sort: .init(),
            availability: .available
        )
        try require(actual.state == expected && actual.rows.isEmpty && actual.totals == .empty, "\(name) invalid state")
    }

    private static func independentRows(_ hydrated: RepositoryRuntimeSnapshot) -> [Row] {
        let accounts = Dictionary(uniqueKeysWithValues: hydrated.accounts.compactMap { account in
            account.repositoryAccountId.map { ($0, account) }
        })
        let categories = Dictionary(uniqueKeysWithValues: hydrated.categorySnapshot.categories.map { ($0.id, $0) })
        return hydrated.transactions.map { transaction in
            let account = transaction.repositoryAccountId.flatMap { accounts[$0] }
            let categoryID = transaction.repositoryTransactionId.flatMap { hydrated.categorySnapshot.assignments[$0] }
            let domain: TransactionPresentationDomain
            if transaction.cardLiabilityEffect != nil || account?.type == .creditCard {
                domain = .card
            } else if account?.type == .bank {
                domain = .bank
            } else {
                domain = .unknown
            }
            let effect: TransactionPresentationEffect
            switch domain {
            case .card:
                switch transaction.cardLiabilityEffect {
                case .increasesAmountOwed: effect = .increasesAmountOwed
                case .decreasesAmountOwed: effect = .decreasesAmountOwed
                case nil: effect = .unknown
                }
            case .bank:
                if transaction.creditMoney != nil, transaction.debitMoney == nil { effect = .credit }
                else if transaction.debitMoney != nil, transaction.creditMoney == nil { effect = .debit }
                else { effect = .unknown }
            case .unknown:
                effect = .unknown
            }
            return Row(
                transaction: transaction,
                stableID: transaction.repositoryTransactionId.map { "durable:" + $0 }
                    ?? "runtime:" + transaction.id.uuidString.lowercased(),
                accountID: transaction.repositoryAccountId,
                accountName: account?.name ?? "Unavailable",
                institution: account?.institution ?? "Unavailable",
                categoryID: categoryID,
                categoryName: categoryID == nil ? "Uncategorized" : (categories[categoryID!]?.name ?? "Unavailable"),
                domain: domain,
                effect: effect,
                date: transaction.statementDate
            )
        }
    }

    private static func matches(_ row: Row, filter: TransactionPresentationFilterSpec) -> Bool {
        let terms = normalize(filter.searchText).split(separator: " ").map(String.init)
        let visible = [row.transaction.description, row.accountName, row.institution, row.categoryName]
            .map(normalize).joined(separator: " ")
        guard terms.allSatisfy({ visible.contains($0) }) else { return false }
        guard filter.accountIDs.isEmpty || row.accountID.map(filter.accountIDs.contains) == true else { return false }
        guard filter.currencies.isEmpty || filter.currencies.contains(row.transaction.money.currency) else { return false }
        let category = row.categoryID.map(TransactionPresentationCategoryChoice.categoryID) ?? .uncategorized
        guard filter.categories.isEmpty || filter.categories.contains(category) else { return false }
        guard filter.domains.isEmpty || filter.domains.contains(row.domain) else { return false }
        guard filter.effects.isEmpty || filter.effects.contains(row.effect) else { return false }
        let institutions = Set(filter.institutionDisplayNames.map(normalize))
        guard institutions.isEmpty || institutions.contains(normalize(row.institution)) else { return false }
        if let range = filter.amountRange {
            if let lower = range.lowerBound, row.transaction.money.amount < lower { return false }
            if let upper = range.upperBound, row.transaction.money.amount > upper { return false }
        }
        if !filter.statementMonths.isEmpty {
            guard let date = row.date,
                  let month = try? SelectedStatementMonth(year: date.year, month: date.month),
                  filter.statementMonths.contains(month) else { return false }
        }
        if let range = filter.statementDateRange {
            guard let date = row.date else { return false }
            if let start = range.start, date < start { return false }
            if let end = range.end, date > end { return false }
        }
        return true
    }

    private static func totals(rows: [Row]) throws -> TransactionPresentationTotals {
        var buckets = [TransactionPresentationTotalKey: [Money]]()
        var unknownDomain = 0
        var unknownEffect = 0
        for row in rows {
            guard row.domain != .unknown else { unknownDomain += 1; continue }
            guard row.effect != .unknown else { unknownEffect += 1; continue }
            let key = TransactionPresentationTotalKey(currency: row.transaction.money.currency, domain: row.domain, effect: row.effect)
            buckets[key, default: []].append(row.transaction.money)
        }
        let partitions = try Dictionary(uniqueKeysWithValues: buckets.map { key, values in
            let zero = try Money(amount: .zero, currency: key.currency)
            return (key, try Money.aggregate(values + [zero]))
        })
        return TransactionPresentationTotals(
            partitions: partitions,
            withheldUnknownDomainCount: unknownDomain,
            withheldUnknownEffectCount: unknownEffect
        )
    }

    private static func compare(_ lhs: Row, _ rhs: Row, sort: TransactionPresentationSortSpec) -> ComparisonResult {
        guard lhs.stableID != rhs.stableID else { return .orderedSame }
        let order: ComparisonResult
        let nilLast: Bool
        switch sort.key {
        case .statementDate:
            order = compareDate(lhs.date, rhs.date); nilLast = lhs.date == nil || rhs.date == nil
        case .description:
            order = compareText(lhs.transaction.description, rhs.transaction.description); nilLast = unknownText(lhs.transaction.description) || unknownText(rhs.transaction.description)
        case .account:
            order = compareText(lhs.accountName, rhs.accountName); nilLast = unknownText(lhs.accountName) || unknownText(rhs.accountName)
        case .category:
            order = compareText(lhs.categoryName, rhs.categoryName); nilLast = unknownText(lhs.categoryName) || unknownText(rhs.categoryName)
        case .nativeAmount:
            let currency = lhs.transaction.money.currency.code.compare(rhs.transaction.money.currency.code)
            order = currency == .orderedSame ? compareDecimal(lhs.transaction.money.amount, rhs.transaction.money.amount) : currency
            nilLast = false
        }
        if order != .orderedSame {
            if nilLast || (sort.key == .nativeAmount && lhs.transaction.money.currency != rhs.transaction.money.currency) { return order }
            return sort.direction == .ascending ? order : reverse(order)
        }
        let left = lhs.transaction.documentScopedSourceOrder
        let right = rhs.transaction.documentScopedSourceOrder
        if let left, let right, left.documentID == right.documentID, left.ordinal != right.ordinal {
            return left.ordinal < right.ordinal ? .orderedAscending : .orderedDescending
        }
        let documentOrder = (lhs.transaction.repositoryDocumentId ?? left?.documentID ?? "").compare(rhs.transaction.repositoryDocumentId ?? right?.documentID ?? "")
        if documentOrder != .orderedSame { return documentOrder }
        return lhs.stableID < rhs.stableID ? .orderedAscending : .orderedDescending
    }

    static func normalize(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func unknownText(_ value: String) -> Bool {
        let value = normalize(value)
        return value.isEmpty || value == "unavailable"
    }

    private static func compareText(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if unknownText(lhs) { return unknownText(rhs) ? .orderedSame : .orderedDescending }
        if unknownText(rhs) { return .orderedAscending }
        return normalize(lhs).compare(normalize(rhs), options: [], range: nil, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func compareDate(_ lhs: StatementDate?, _ rhs: StatementDate?) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil): return .orderedSame
        case (nil, .some): return .orderedDescending
        case (.some, nil): return .orderedAscending
        case let (.some(lhs), .some(rhs)): return lhs == rhs ? .orderedSame : (lhs < rhs ? .orderedAscending : .orderedDescending)
        }
    }

    private static func compareDecimal(_ lhs: Decimal, _ rhs: Decimal) -> ComparisonResult {
        lhs == rhs ? .orderedSame : (lhs < rhs ? .orderedAscending : .orderedDescending)
    }

    private static func reverse(_ result: ComparisonResult) -> ComparisonResult {
        result == .orderedAscending ? .orderedDescending : (result == .orderedDescending ? .orderedAscending : .orderedSame)
    }

    private static func searchSplitAcrossDescriptionAndAccount(_ rows: [Row]) throws -> String {
        let row = try requireValue(rows.first(where: { $0.accountName != "Unavailable" && !$0.transaction.description.isEmpty }), "split search row")
        let description = try requireValue(normalize(row.transaction.description).split(separator: " ").first.map(String.init), "description search term")
        let account = try requireValue(normalize(row.accountName).split(separator: " ").first.map(String.init), "account search term")
        return description + " " + account
    }

    private static func literalPunctuationQuery(_ rows: [Row]) throws -> String {
        let token = rows.lazy
            .flatMap { $0.transaction.description.split(whereSeparator: \.isWhitespace).map(String.init) }
            .first { $0.contains(where: { $0.isPunctuation }) }
        return try requireValue(token, "punctuation literal")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ label: String) throws {
        guard condition() else { throw Failure(reason: label) }
    }

    private static func requireValue<T>(_ value: T?, _ label: String) throws -> T {
        guard let value else { throw Failure(reason: label) }
        return value
    }
}

@Suite("TransactionListViewModel", .serialized)
@MainActor
struct TransactionListViewModelTests {
    @Test
    func periodPresetsUseInclusiveCivilDatesAcrossLeapAndYearBoundaries() throws {
        let leapFebruary = try StatementDate(year: 2024, month: 2, day: 14)
        let thisMonth = try #require(try TransactionPeriodChoice.thisMonth.range(relativeTo: leapFebruary))
        #expect(thisMonth.start == (try StatementDate(year: 2024, month: 2, day: 1)))
        #expect(thisMonth.end == (try StatementDate(year: 2024, month: 2, day: 29)))
        let january = try StatementDate(year: 2026, month: 1, day: 7)
        let previous = try #require(try TransactionPeriodChoice.lastMonth.range(relativeTo: january))
        #expect(previous.start == (try StatementDate(year: 2025, month: 12, day: 1)))
        #expect(previous.end == (try StatementDate(year: 2025, month: 12, day: 31)))
        let yearToDate = try #require(try TransactionPeriodChoice.yearToDate.range(relativeTo: leapFebruary))
        #expect(yearToDate.start == (try StatementDate(year: 2024, month: 1, day: 1)))
        #expect(yearToDate.end == leapFebruary)
        #expect(try TransactionPeriodChoice.all.range(relativeTo: january) == nil)
    }

    @Test(.globalRuntimeStateIsolation)
    func acceptedCanonicalSnapshotMatchesIndependentInMemoryOracle() async throws {
        let context = try await authenticTransactionListContext()
        let missing = try Sprint89TransactionPresentationOracle.verify(hydrated: context.snapshot)
        print("Sprint 89 in-memory presentation oracle passed; missing genuine cases: " + missing.joined(separator: ", "))
    }

    @Test(.globalRuntimeStateIsolation)
    func searchTrimsWhitespaceAndMatchesAuthenticTransactionText() async throws {
        let context = try await authenticTransactionListContext()
        let transaction = try #require(context.transactionStore.transactions.first)
        let query = try #require(transaction.description.split(whereSeparator: \.isWhitespace).first.map(String.init))
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )

        viewModel.searchText = "  \(query.uppercased())  "

        #expect(!viewModel.filteredTransactions.isEmpty)
        #expect(viewModel.filteredTransactions.allSatisfy {
            [$0.description, $0.account, $0.sourceBank]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query)
        })
    }

    @Test(.globalRuntimeStateIsolation)
    func creditAndDebitFiltersUseUnchangedAuthenticTransactions() async throws {
        let context = try await authenticTransactionListContext()
        let allTransactions = context.transactionStore.transactions
        let bankIDs = Set(context.accountStore.accounts.filter { $0.type == .bank }.compactMap(\.repositoryAccountId))
        let bankTransactions = allTransactions.filter {
            $0.cardLiabilityEffect == nil && $0.repositoryAccountId.map(bankIDs.contains) == true
        }
        let credits = bankTransactions.filter { $0.creditMoney != nil && $0.debitMoney == nil }
        let debits = bankTransactions.filter { $0.debitMoney != nil && $0.creditMoney == nil }
        _ = try #require(credits.first)
        _ = try #require(debits.first)
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )

        viewModel.showOnlyCredits = true
        viewModel.showOnlyDebits = false
        #expect(Set(viewModel.filteredTransactions.map(\.id)) == Set(credits.map(\.id)))

        viewModel.showOnlyCredits = false
        viewModel.showOnlyDebits = true
        #expect(Set(viewModel.filteredTransactions.map(\.id)) == Set(debits.map(\.id)))

        viewModel.showOnlyCredits = true
        viewModel.showOnlyDebits = true
        #expect(Set(viewModel.filteredTransactions.map(\.id)) == Set(allTransactions.map(\.id)))
    }

    @Test(.globalRuntimeStateIsolation)
    func summariesUseTheAuthenticMatchingScopeRatherThanAllTransactions() async throws {
        let context = try await authenticTransactionListContext()
        let transactions = context.transactionStore.transactions
        let transaction = try #require(transactions.first)
        let query = try #require(transaction.description.split(whereSeparator: \.isWhitespace).first.map(String.init))
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )

        viewModel.searchText = "  \(query.uppercased())  "

        let normalizedQuery = Sprint89TransactionPresentationOracle.normalize(query)
        let accountsByID = Dictionary(uniqueKeysWithValues: context.accountStore.accounts.compactMap { account in
            account.repositoryAccountId.map { ($0, account) }
        })
        let categoriesByID = Dictionary(uniqueKeysWithValues: context.categoryStore.categories.map { ($0.id, $0) })
        let expected = transactions.filter { row in
            let account = row.repositoryAccountId.flatMap { accountsByID[$0] }
            let category = row.repositoryTransactionId
                .flatMap { context.categoryStore.snapshot.assignments[$0] }
                .flatMap { categoriesByID[$0] }
            return [
                row.description,
                account?.name ?? "Unavailable",
                account?.institution ?? "Unavailable",
                category?.name ?? "Uncategorized"
            ]
            .map(Sprint89TransactionPresentationOracle.normalize)
            .joined(separator: " ")
            .contains(normalizedQuery)
        }
        #expect(!expected.isEmpty)

        let expectedByCurrency = Dictionary(grouping: expected, by: \.money.currency)
        #expect(Set(viewModel.currencySummaries.map(\.currency)) == Set(expectedByCurrency.keys))
        for summary in viewModel.currencySummaries {
            let values = try #require(expectedByCurrency[summary.currency])
            let zero = try Money(amount: .zero, currency: summary.currency)
            let expectedInflow = try Money.aggregate(values.compactMap(\.creditMoney) + [zero])
            let expectedOutflow = try Money.aggregate(values.compactMap(\.debitMoney) + [zero])
            #expect(summary.inflow == expectedInflow)
            #expect(summary.outflow == expectedOutflow)
        }
    }

    @Test
    func presentationTextAndCivilDateRangeNormalizeWithoutFinancialFixtures() throws {
        #expect(TransactionPresentationText.normalized("  CAFÉ\n Market  ") == "cafe market")

        let start = try StatementDate(year: 2026, month: 9, day: 1)
        let end = try StatementDate(year: 2026, month: 9, day: 30)
        let range = TransactionPresentationStatementDateRange(start: start, end: end)
        #expect(range.isValid)
        #expect(range.contains(try StatementDate(year: 2026, month: 9, day: 1)))
        #expect(range.contains(try StatementDate(year: 2026, month: 9, day: 30)))
        #expect(!range.contains(try StatementDate(year: 2026, month: 10, day: 1)))
        #expect(TransactionPresentationSortKey.allCases.count == 5)
    }

    @Test
    func amountRangeWithoutExactlyOneCurrencyIsRejectedBeforeMatching() {
        var filter = TransactionPresentationFilterSpec.empty
        filter.amountRange = TransactionPresentationAmountRange(lowerBound: 1, upperBound: 2)
        let result = TransactionPresentationEngine.evaluate(
            transactions: [],
            accounts: [],
            categories: [],
            assignments: [:],
            filter: filter,
            sort: .init(),
            availability: .available
        )
        #expect(result.state == .invalidAmountCurrencySelection)
        #expect(result.rows.isEmpty)
        #expect(result.totals == .empty)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticRowsKeepCivilDateNilLastAcrossSortDirections() async throws {
        let context = try await authenticTransactionListContext()
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )
        viewModel.synchronizePresentation(
            generation: context.provider.generationToken,
            availabilityState: .current
        )

        for direction in [TransactionPresentationSortDirection.ascending, .descending] {
            viewModel.presentationSort = TransactionPresentationSortSpec(
                key: .statementDate,
                direction: direction
            )
            let rows = viewModel.transactionPresentationResult.rows
            #expect(!rows.isEmpty)
            for (left, right) in zip(rows, rows.dropFirst()) {
                switch (left.sourceCivilDate, right.sourceCivilDate) {
                case (nil, .some):
                    Issue.record("A nil civil date sorted before a source civil date.")
                case let (.some(leftDate), .some(rightDate)):
                    if direction == .ascending {
                        #expect(leftDate <= rightDate)
                    } else {
                        #expect(leftDate >= rightDate)
                    }
                    let leftOrder = left.transaction.documentScopedSourceOrder
                    let rightOrder = right.transaction.documentScopedSourceOrder
                    if leftDate == rightDate,
                       let leftOrder,
                       let rightOrder,
                       leftOrder.documentID == rightOrder.documentID {
                        #expect(leftOrder.ordinal <= rightOrder.ordinal)
                    }
                default:
                    break
                }
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func presentationSearchRequiresEveryNormalizedLiteralTerm() async throws {
        let context = try await authenticTransactionListContext()
        let transaction = try #require(context.transactionStore.transactions.first)
        let knownTerm = try #require(transaction.description.split(whereSeparator: \.isWhitespace).first.map(String.init))
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )
        viewModel.synchronizePresentation(
            generation: context.provider.generationToken,
            availabilityState: .current
        )

        viewModel.presentationFilter.searchText = "\(knownTerm) ledgerforge-presentation-no-match-7f23d0"

        #expect(viewModel.transactionPresentationResult.state == .validEmpty)
        #expect(viewModel.transactionPresentationResult.exclusions.search == context.transactionStore.transactions.count)
    }

    @Test(.globalRuntimeStateIsolation)
    func presentationRejectsMixedKnownAndUnknownSelectionsAndUnknownRestrictions() async throws {
        let context = try await authenticTransactionListContext()
        let knownAccountID = try #require(context.accountStore.accounts.compactMap(\.repositoryAccountId).first)
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )
        viewModel.synchronizePresentation(
            generation: context.provider.generationToken,
            availabilityState: .current
        )

        var filter = TransactionPresentationFilterSpec.empty
        filter.accountIDs = [knownAccountID, "ledgerforge-unknown-account-id"]
        viewModel.presentationFilter = filter
        #expect(viewModel.transactionPresentationResult.state == .invalidSelection)

        filter = .empty
        filter.categories = [.categoryID("ledgerforge-unknown-category-id")]
        viewModel.presentationFilter = filter
        #expect(viewModel.transactionPresentationResult.state == .invalidSelection)

        filter = .empty
        filter.institutionDisplayNames = ["ledgerforge-unknown-institution"]
        viewModel.presentationFilter = filter
        #expect(viewModel.transactionPresentationResult.state == .invalidSelection)

        filter = .empty
        filter.domains = [.unknown]
        viewModel.presentationFilter = filter
        #expect(viewModel.transactionPresentationResult.state == .invalidUnknownDomainOrEffectRestriction)

        filter = .empty
        filter.effects = [.unknown]
        viewModel.presentationFilter = filter
        #expect(viewModel.transactionPresentationResult.state == .invalidUnknownDomainOrEffectRestriction)
    }

    @Test(.globalRuntimeStateIsolation)
    func categoryMetadataFilterUsesDurableAssignmentForAnAuthenticTransaction() async throws {
        let context = try await authenticTransactionListContext()
        let transaction = try #require(context.transactionStore.transactions.first)
        let transactionID = try #require(transaction.repositoryTransactionId)
        let category = Category(
            id: "sprint89-presentation-category",
            workspaceID: context.workspaceID,
            name: "Presentation category",
            normalizedName: "presentation category",
            isArchived: false
        )
        var filter = TransactionPresentationFilterSpec.empty
        filter.categories = [.categoryID(category.id)]

        let result = TransactionPresentationEngine.evaluate(
            transactions: context.transactionStore.transactions,
            accounts: context.accountStore.accounts,
            categories: [category],
            assignments: [transactionID: category.id],
            filter: filter,
            sort: .init(),
            availability: .available
        )

        #expect(result.state == .ready)
        #expect(result.rows.map(\.transaction.repositoryTransactionId) == [transactionID])
        #expect(result.rows.first?.currentCategoryDisplayName == category.name)
    }

    @Test(.globalRuntimeStateIsolation)
    func invalidAmountBoundsAreExplicitlyRejected() async throws {
        let context = try await authenticTransactionListContext()
        let knownCurrency = try #require(context.transactionStore.transactions.first?.money.currency)
        var filter = TransactionPresentationFilterSpec.empty
        filter.currencies = [knownCurrency]
        filter.amountRange = TransactionPresentationAmountRange(lowerBound: 3, upperBound: 2)

        let result = TransactionPresentationEngine.evaluate(
            transactions: context.transactionStore.transactions,
            accounts: context.accountStore.accounts,
            categories: context.categoryStore.categories,
            assignments: context.categoryStore.snapshot.assignments,
            filter: filter,
            sort: .init(),
            availability: .available
        )

        #expect(result.state == .invalidAmountRange)
        #expect(result.rows.isEmpty)
        #expect(result.totals == .empty)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticDomainEffectPartitionsMatchIndependentMoneyAggregation() async throws {
        let context = try await authenticTransactionListContext()
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )
        viewModel.synchronizePresentation(
            generation: context.provider.generationToken,
            availabilityState: .current
        )

        let result = viewModel.transactionPresentationResult
        let independentlyIncluded = result.rows.filter { $0.domain != .unknown && $0.effect != .unknown }
        let expected = Dictionary(grouping: independentlyIncluded) {
            TransactionPresentationTotalKey(
                currency: $0.transaction.money.currency,
                domain: $0.domain,
                effect: $0.effect
            )
        }
        #expect(Set(result.totals.partitions.keys) == Set(expected.keys))
        for (key, rows) in expected {
            let zero = try Money(amount: .zero, currency: key.currency)
            let expectedTotal = try Money.aggregate(rows.map { $0.transaction.money } + [zero])
            #expect(result.totals.partitions[key] == expectedTotal)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func selectionClearsWhenMatchingMembershipOrGenerationChanges() async throws {
        let context = try await authenticTransactionListContext()
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )
        viewModel.synchronizePresentation(
            generation: context.provider.generationToken,
            availabilityState: .current
        )
        let firstID = try #require(viewModel.allPresentationRows.first?.stableID)

        viewModel.selectPresentationRow(id: firstID)
        #expect(viewModel.selectedPresentationRowID == firstID)

        viewModel.presentationFilter.searchText = "ledgerforge-presentation-no-match-7f23d0"
        #expect(viewModel.selectedPresentationRowID == nil)

        viewModel.presentationFilter = .empty
        viewModel.presentationSort = TransactionPresentationSortSpec(key: .category, direction: .ascending)
        viewModel.selectPresentationRow(id: firstID)
        #expect(viewModel.selectedPresentationRowID == firstID)

        viewModel.presentationFilter.searchText = ""
        viewModel.clearPresentationCriteria()
        #expect(viewModel.presentationSort == TransactionPresentationSortSpec(key: .category, direction: .ascending))
        #expect(viewModel.selectedPresentationRowID == firstID)

        viewModel.synchronizePresentation(
            generation: ProviderGenerationToken(),
            availabilityState: .current
        )
        #expect(viewModel.selectedPresentationRowID == nil)
    }

    @Test(.globalRuntimeStateIsolation)
    func presentationAvailabilityRequiresCurrentOrEmptyStateAndGeneration() async throws {
        let context = try await authenticTransactionListContext()
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )

        viewModel.synchronizePresentation(generation: context.provider.generationToken, availabilityState: .loading)
        #expect(viewModel.transactionPresentationResult.state == .unavailable)
        #expect(viewModel.allPresentationRows.isEmpty)

        viewModel.synchronizePresentation(generation: context.provider.generationToken, availabilityState: .empty)
        #expect(viewModel.transactionPresentationResult.state == .ready)

        viewModel.synchronizePresentation(generation: nil, availabilityState: .current)
        #expect(viewModel.transactionPresentationResult.state == .unavailable)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticCardDetailsPreserveNativeMoneySignAndLiabilityMeaning() async throws {
        let context = try await authenticTransactionListContext()
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )
        for transaction in context.transactionStore.transactions where transaction.cardLiabilityEffect != nil {
            let presentation = viewModel.detailPresentation(for: transaction)
            let preservesNativeAmount = presentation.signedAmount == MoneyFormatting.display(transaction.money)
            #expect(preservesNativeAmount)
            switch transaction.cardLiabilityEffect {
            case .increasesAmountOwed:
                #expect(presentation.direction == "Charge / increase owed")
            case .decreasesAmountOwed:
                #expect(presentation.direction == "Payment or credit / decrease owed")
            case nil:
                break
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticDurableRelationshipsProduceTransactionDetail() async throws {
        let context = try await authenticTransactionListContext()
        let transaction = try #require(context.transactionStore.transactions.first)
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore,
            accountStore: context.accountStore,
            categoryStore: context.categoryStore
        )

        let presentation = viewModel.detailPresentation(for: transaction)

        let sourceName = transaction.repositoryPreferredSourceDocumentName ?? transaction.repositorySourceDocumentName
        #expect(presentation.sourceDocumentName == sourceName)
        #expect(presentation.accountDisplayName != "Unavailable")
        #expect(presentation.institution != "Unavailable")
        #expect(presentation.importedAt != nil)
        #expect(presentation.validation?.title == "Passed")
        #expect(presentation.provenanceAvailability == .complete)
        #expect(presentation.nativeCurrency == transaction.currency)

        let presentedText = presentation.accessibilityText
        for internalValue in [
            transaction.repositoryTransactionId,
            transaction.repositoryAccountId,
            transaction.repositoryDocumentId,
            transaction.repositoryImportSessionId,
            transaction.sourceProvenance.first?.normalizedDocumentID,
            transaction.sourceProvenance.first?.normalizedRowID,
            transaction.sourceProvenance.first?.normalizedRecordDigest,
            transaction.sourceProvenance.first?.parserProfileID
        ].compactMap({ $0 }) where !internalValue.isEmpty {
            #expect(!presentedText.contains(internalValue))
        }
    }
}

private struct AuthenticTransactionListContext {
    let provider: SQLiteRepositoryProvider
    let workspaceID: String
    let snapshot: RepositoryRuntimeSnapshot
    let accountStore: AccountStore
    let transactionStore: TransactionStore
    let categoryStore: CategoryStore
    let importSessionStore: ImportSessionStore
}

@MainActor
private enum AcceptedTransactionSnapshot {
    static var cached: AuthenticTransactionListContext?
}

@MainActor
private func authenticTransactionListContext() async throws -> AuthenticTransactionListContext {
    if let cached = AcceptedTransactionSnapshot.cached { return cached }
    let identity = try DevelopmentDatabaseIdentity.applicationOwned(environment: ProcessInfo.processInfo.environment)
    let databaseURL = identity.canonicalDevelopmentURL
    guard !identity.isIsolatedCanonicalNamespace,
          identity.authorizesCurrentDatabaseIdentity(at: databaseURL),
          FileManager.default.fileExists(atPath: databaseURL.path) else {
        throw RepositoryError.persistenceUnavailable
    }
    // SQLite's URI read-only mode applies before provider initialization, so this
    // presentation check cannot create a database, apply migrations, or write rows.
    let provider = try SQLiteRepositoryProvider(path: databaseURL.absoluteString + "?mode=ro")
    try provider.database.execute(sql: "PRAGMA query_only = ON;")
    let workspaces = try provider.database.query(sql: "SELECT id FROM workspaces ORDER BY id", params: []) {
        $0.string(at: 0)
    }.compactMap { $0 }
    guard workspaces.count == 1, let workspaceID = workspaces.first else {
        throw RepositoryError.persistenceUnavailable
    }
    let accountStore = AccountStore()
    let transactionStore = TransactionStore()
    let categoryStore = CategoryStore()
    let importSessionStore = ImportSessionStore()
    let hydrator = RepositoryStoreHydrator(
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        categoryRepo: provider.categoryRepo,
        cardRepo: provider.cardRepo,
        salaryRepo: provider.salaryRepo,
        fundingPlanRepo: provider.fundingPlanRepo,
        accountStore: accountStore,
        transactionStore: transactionStore,
        categoryStore: categoryStore,
        cardStore: CardStore(),
        salaryStore: SalaryStore(),
        fundingPlanStore: FundingPlanStore(),
        importSessionStore: importSessionStore,
        importAttemptStore: ImportAttemptStore(),
        workspaceId: workspaceID,
        persistenceState: .verifiedSQLite,
        providerGeneration: provider.generationToken,
        participatesInLifecycleGate: false
    )
    let snapshot = try hydrator.stageHydration()
    hydrator.publish(snapshot)
    let context = AuthenticTransactionListContext(
        provider: provider,
        workspaceID: workspaceID,
        snapshot: snapshot,
        accountStore: accountStore,
        transactionStore: transactionStore,
        categoryStore: categoryStore,
        importSessionStore: importSessionStore
    )
    AcceptedTransactionSnapshot.cached = context
    return context
}
