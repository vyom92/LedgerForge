// LedgerForgeTests/TransactionListViewModelTests.swift

import Foundation
import AppKit
import Testing
@testable import LedgerForge

@MainActor
enum Sprint89TransactionPresentationOracle {
    private struct Row {
        let transaction: Transaction
        let stableID: String
        let accountID: String?
        let historyOnly: Bool
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
    static func verify(hydrated: RepositoryRuntimeSnapshot, historyOnlyAccountIDs: Set<String>) throws -> [String] {
        var missingCases = [String]()
        guard hydrated.providerGeneration != nil else {
            throw Failure(reason: "hydrated snapshot has no provider generation")
        }
        let rows = independentRows(hydrated, historyOnlyAccountIDs: historyOnlyAccountIDs)
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
        try require(actual.rows.map(\.accountDisplayName) == expected.map(\.accountName), "\(name) account names")
        try require(actual.rows.map(\.institutionDisplayName) == expected.map(\.institution), "\(name) institution names")
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

    private static func independentRows(_ hydrated: RepositoryRuntimeSnapshot, historyOnlyAccountIDs: Set<String>) -> [Row] {
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
                historyOnly: transaction.repositoryAccountId.map(historyOnlyAccountIDs.contains) == true,
                accountName: account.map(expectedAccountTitle) ?? "Unavailable",
                institution: account.map { shortInstitution($0.institution) } ?? "Unavailable",
                categoryID: categoryID,
                categoryName: categoryID == nil ? "Uncategorized" : (categories[categoryID!]?.name ?? "Unavailable"),
                domain: domain,
                effect: effect,
                date: transaction.statementDate
            )
        }
    }

    // Owner display contract: a saved nickname is shown verbatim. Account
    // context belongs in a separate label, never reconstructed into its name.
    // Keep this independent of the production presentation engine/accessors.
    private static func expectedAccountTitle(_ account: Account) -> String {
        if let nickname = account.nickname, nickname.contains(where: { !$0.isWhitespace }) {
            return nickname
        }
        if account.name.contains(where: { !$0.isWhitespace }) { return account.name }
        return shortInstitution(account.sourceProductName ?? account.institution + " account")
    }

    private static func shortInstitution(_ text: String) -> String {
        text.replacingOccurrences(of: "(?i)Commercial Bank of Qatar", with: "CBQ", options: .regularExpression)
    }

    private static func matches(_ row: Row, filter: TransactionPresentationFilterSpec) -> Bool {
        let terms = normalize(filter.searchText).split(separator: " ").map(String.init)
        let visible = [row.transaction.description, row.accountName, row.institution, row.categoryName]
            .map(normalize).joined(separator: " ")
        guard terms.allSatisfy({ visible.contains($0) }) else { return false }
        guard !filter.excludesAllAccounts else { return false }
        guard filter.accountIDs.isEmpty ? !row.historyOnly : row.accountID.map(filter.accountIDs.contains) == true else { return false }
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

    @Test
    func relativePeriodRefreshAdvancesMonthAndYearAtLocalMidnight() throws {
        let model = TransactionListViewModel(transactionStore: TransactionStore(),
            importSessionStore: ImportSessionStore(), accountStore: AccountStore(), categoryStore: CategoryStore())
        let timeZone = try #require(TimeZone(identifier: "Asia/Qatar"))
        let before = try #require(ISO8601DateFormatter().date(from: "2025-12-31T20:59:59Z"))
        let after = try #require(ISO8601DateFormatter().date(from: "2025-12-31T21:00:00Z"))
        let cases: [(TransactionPeriodChoice, String, String, String, String)] = [
            (.thisMonth, "2025-12-01", "2025-12-31", "2026-01-01", "2026-01-31"),
            (.lastMonth, "2025-11-01", "2025-11-30", "2025-12-01", "2025-12-31"),
            (.yearToDate, "2025-01-01", "2025-12-31", "2026-01-01", "2026-01-01")
        ]
        model.presentationFilter.searchText = "retained search"
        for (period, oldStart, oldEnd, newStart, newEnd) in cases {
            model.presentationControls.period = period
            model.refreshRelativePeriod(isOverview: false, now: before, timeZone: timeZone)
            #expect(model.presentationFilter.statementDateRange == .init(
                start: try StatementDate(canonical: oldStart), end: try StatementDate(canonical: oldEnd)))
            model.refreshRelativePeriod(isOverview: false, now: after, timeZone: timeZone)
            #expect(model.presentationFilter.statementDateRange == .init(
                start: try StatementDate(canonical: newStart), end: try StatementDate(canonical: newEnd)))
            #expect(model.presentationFilter.searchText == "retained search")
            #expect(model.presentationControls.period == period)
            #expect(model.presentationControls.dateInputError == nil)
        }
    }

    @Test
    func relativePeriodRefreshRevalidatesSamePresetAfterSpendingDrilldownRestoration() throws {
        let model = TransactionListViewModel(transactionStore: TransactionStore(),
            importSessionStore: ImportSessionStore(), accountStore: AccountStore(), categoryStore: CategoryStore())
        let timeZone = try #require(TimeZone(identifier: "Asia/Qatar"))
        let before = try #require(ISO8601DateFormatter().date(from: "2026-09-30T20:59:59Z"))
        let after = try #require(ISO8601DateFormatter().date(from: "2026-09-30T21:00:00Z"))
        model.presentationControls.period = .thisMonth
        model.presentationFilter.searchText = "retained original criteria"
        model.refreshRelativePeriod(isOverview: false, now: before, timeZone: timeZone)
        let retained = (filter: model.presentationFilter, controls: model.presentationControls)

        // The drilldown clears controls, then the owner selects the same preset.
        model.presentationFilter = .empty
        model.presentationControls = TransactionPresentationControls()
        model.presentationControls.period = .thisMonth
        model.refreshRelativePeriod(isOverview: false, now: after, timeZone: timeZone)
        let periodBeforeRestoration = model.presentationControls.period

        // Restoring equal preset values does not produce a period-change event.
        model.presentationFilter = retained.filter
        model.presentationControls = retained.controls
        #expect(model.presentationControls.period == periodBeforeRestoration)
        #expect(model.presentationFilter.statementDateRange == .init(
            start: try StatementDate(canonical: "2026-09-01"), end: try StatementDate(canonical: "2026-09-30")))
        model.refreshRelativePeriod(isOverview: false, now: after, timeZone: timeZone)
        #expect(model.presentationFilter.statementDateRange == .init(
            start: try StatementDate(canonical: "2026-10-01"), end: try StatementDate(canonical: "2026-10-31")))
        #expect(model.presentationControls.period == .thisMonth)
        #expect(model.presentationFilter.searchText == "retained original criteria")
    }

    @Test
    func yearToDateRefreshAdvancesOnCalendarDayWithinTheSameMonth() throws {
        let model = TransactionListViewModel(transactionStore: TransactionStore(),
            importSessionStore: ImportSessionStore(), accountStore: AccountStore(), categoryStore: CategoryStore())
        let timeZone = try #require(TimeZone(identifier: "Asia/Qatar"))
        let before = try #require(ISO8601DateFormatter().date(from: "2024-02-28T20:59:59Z"))
        let after = try #require(ISO8601DateFormatter().date(from: "2024-02-28T21:00:00Z"))
        model.presentationControls.period = .yearToDate
        model.refreshRelativePeriod(isOverview: false, now: before, timeZone: timeZone)
        #expect(model.presentationFilter.statementDateRange == .init(
            start: try StatementDate(canonical: "2024-01-01"), end: try StatementDate(canonical: "2024-02-28")))
        model.refreshRelativePeriod(isOverview: false, now: after, timeZone: timeZone)
        #expect(model.presentationFilter.statementDateRange == .init(
            start: try StatementDate(canonical: "2024-01-01"), end: try StatementDate(canonical: "2024-02-29")))
    }

    @Test
    func relativePeriodRefreshPreservesAllCustomAndPeriodOverviewDates() throws {
        let model = TransactionListViewModel(transactionStore: TransactionStore(),
            importSessionStore: ImportSessionStore(), accountStore: AccountStore(), categoryStore: CategoryStore())
        let timeZone = try #require(TimeZone(identifier: "Asia/Qatar"))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z"))
        let selectedRange = TransactionPresentationStatementDateRange(
            start: try StatementDate(canonical: "2024-02-01"), end: try StatementDate(canonical: "2024-02-29"))
        model.presentationFilter.searchText = "retained search"
        model.refreshRelativePeriod(isOverview: false, now: now, timeZone: timeZone)
        #expect(model.presentationControls.period == .all)
        #expect(model.presentationFilter.statementDateRange == nil)
        model.presentationControls.period = .custom
        model.presentationControls.customStart = "invalid pending edit"
        model.presentationControls.customEnd = "2024-02-29"
        model.presentationControls.dateInputError = "Use a valid source date in YYYY-MM-DD format."
        model.presentationFilter.statementDateRange = selectedRange
        let filter = model.presentationFilter
        model.refreshRelativePeriod(isOverview: false, now: now, timeZone: timeZone)
        #expect(model.presentationFilter == filter)
        #expect(model.presentationControls.customStart == "invalid pending edit")
        #expect(model.presentationControls.customEnd == "2024-02-29")
        #expect(model.presentationControls.dateInputError == "Use a valid source date in YYYY-MM-DD format.")

        let overview = model.makePeriodOverview()
        // The overview guard remains effective even if a relative control is
        // later retained alongside its independently selected date bounds.
        overview.presentationControls.period = .thisMonth
        overview.refreshRelativePeriod(isOverview: true, now: now, timeZone: timeZone)
        #expect(overview.presentationFilter == filter)
        #expect(model.presentationFilter == filter)
    }

    @Test(.globalRuntimeStateIsolation)
    func acceptedCanonicalSnapshotMatchesIndependentInMemoryOracle() async throws {
        let context = try await authenticTransactionListContext()
        let missing = try Sprint89TransactionPresentationOracle.verify(hydrated: context.snapshot, historyOnlyAccountIDs: context.historyOnlyAccountIDs)
        let amounts = context.transactionStore.transactions.map(\.money)
        for localeID in ["en_US", "en_IN", "ar_QA"] {
            let locale = Locale(identifier: localeID)
            let singleValueDisplays = amounts.map { MoneyFormatting.display($0, locale: locale) }
            let displaysMatch = MoneyFormatting.display(amounts, locale: locale) == singleValueDisplays
            #expect(displaysMatch)
        }
        let nativeAmountsUnchanged = context.transactionStore.transactions.map(\.money) == amounts
        #expect(nativeAmountsUnchanged)
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
        let allTransactions = context.transactionStore.transactions.filter { $0.repositoryAccountId.map(context.historyOnlyAccountIDs.contains) != true }
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
            guard row.repositoryAccountId.map(context.historyOnlyAccountIDs.contains) != true else { return false }
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
        filter.accountIDs = [try #require(transaction.repositoryAccountId)]

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
        let firstID = try #require(viewModel.transactionPresentationResult.rows.first?.stableID)

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
    func currentProjectionIsReusedAcrossReadsAndQueryChanges() async throws {
        let context = try await authenticTransactionListContext()
        let model = TransactionListViewModel(
            transactionStore: context.transactionStore, importSessionStore: context.importSessionStore,
            accountStore: context.accountStore, categoryStore: context.categoryStore
        )
        model.synchronizePresentation(generation: context.provider.generationToken, availabilityState: .current)
        let original = model.transactionPresentationResult
        let ids = original.rows.map(\.stableID)
        let money = original.rows.map { $0.transaction.money }
        for _ in 0..<12 {
            #expect(model.transactionPresentationResult.rows.map(\.stableID) == ids)
            #expect(model.transactionPresentationResult.rows.map { $0.transaction.money } == money)
            #expect(model.transactionPresentationResult.totals == original.totals)
            #expect(model.allPresentationRows.count == context.transactionStore.transactions.count)
        }
        #expect(model.canonicalProjectionBuildCount == 1)
        #expect(model.queryEvaluationCount == 1)
        model.presentationFilter.searchText = "post94-no-displayed-match-85746"
        #expect(model.transactionPresentationResult.state == .validEmpty)
        #expect(model.allPresentationRows.count == context.snapshot.transactions.count)
        #expect(model.canonicalProjectionBuildCount == 1)
        #expect(model.queryEvaluationCount == 2)
        model.presentationFilter = .empty
        #expect(model.transactionPresentationResult.rows.map(\.stableID) == ids)
        #expect(model.transactionPresentationResult.totals == original.totals)
        #expect(model.canonicalProjectionBuildCount == 1)
        model.synchronizePresentation(generation: nil, availabilityState: .unavailable)
        #expect(model.transactionPresentationResult.state == .unavailable)
        #expect(model.allPresentationRows.isEmpty)
    }

    @Test(.globalRuntimeStateIsolation)
    func sameCountAccountMetadataPublicationInvalidatesRowsAndSearch() async throws {
        let context = try await authenticTransactionListContext()
        let accounts = AccountStore()
        accounts.replaceAccounts(context.accountStore.accounts)
        let model = TransactionListViewModel(
            transactionStore: context.transactionStore, importSessionStore: context.importSessionStore,
            accountStore: accounts, categoryStore: context.categoryStore
        )
        model.synchronizePresentation(generation: context.provider.generationToken, availabilityState: .current)
        let canonicalRows = model.allPresentationRows
        let original = model.transactionPresentationResult
        let revision = model.canonicalContentRevision
        let accountID = try #require(original.rows.first?.accountID)
        var renamed = accounts.accounts
        let index = try #require(renamed.firstIndex { $0.repositoryAccountId == accountID })
        let savedName = "Commercial Bank of Qatar / My eSavings — HISTORY!"
        renamed[index].name = savedName
        accounts.replaceAccounts(renamed)
        for _ in 0..<100 where model.canonicalContentRevision == revision {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.canonicalContentRevision > revision)
        #expect(model.transactionPresentationResult.rows.count == original.rows.count)
        #expect(model.transactionPresentationResult.totals == original.totals)
        #expect(model.allPresentationRows.filter { $0.accountID == accountID }.allSatisfy { $0.accountDisplayName == savedName })
        let updated = try #require(model.allPresentationRows.first { $0.accountID == accountID })
        #expect(model.detailPresentation(for: updated.transaction).accountDisplayName == savedName)
        #expect(Dictionary(uniqueKeysWithValues: model.allPresentationRows.map { ($0.stableID, $0.transaction.description) }) ==
            Dictionary(uniqueKeysWithValues: canonicalRows.map { ($0.stableID, $0.transaction.description) }))
        model.presentationFilter.searchText = savedName
        #expect(!model.transactionPresentationResult.rows.isEmpty)
        #expect(model.transactionPresentationResult.rows.allSatisfy { $0.accountID == accountID })
        #expect(model.allPresentationRows.count == canonicalRows.count)
    }

    @Test
    func amountMeasurementChangesOnlyForRowRevisionOrNativeFont() {
        let measurement = TransactionAmountWidthMeasurement()
        let font = NSFont.systemFont(ofSize: 14)
        var calls = 0
        for _ in 0..<8 {
            #expect(measurement.value(revision: 1, font: font) { calls += 1; return 240 } == 240)
        }
        #expect(calls == 1)
        #expect(measurement.value(revision: 2, font: font) { calls += 1; return 260 } == 260)
        #expect(calls == 2)
        #expect(measurement.value(revision: 2, font: .systemFont(ofSize: 18)) { calls += 1; return 290 } == 290)
        #expect(calls == 3)
    }

    @Test
    func periodOverviewRollingRangesUseLocalTodayAndCalendarMonthOffsets() throws {
        let today = try StatementDate(canonical: "2026-09-29")
        #expect(PeriodOverviewRange.three.dates(ending: today) == .init(
            start: try StatementDate(canonical: "2026-06-29"), end: today))
        #expect(PeriodOverviewRange.one.dates(ending: try StatementDate(canonical: "2026-03-31"))?.start ==
            (try StatementDate(canonical: "2026-02-28")))
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-09-29T22:30:00Z"))
        #expect(PeriodOverviewRange.today(now: instant, timeZone: try #require(TimeZone(identifier: "Asia/Qatar"))) ==
            (try StatementDate(canonical: "2026-09-30")))
    }

    @Test(.globalRuntimeStateIsolation)
    func periodOverviewKeepsOriginAndIndependentOverridesOverAuthenticRows() async throws {
        let context = try await authenticTransactionListContext()
        let origin = TransactionListViewModel(transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore, accountStore: context.accountStore, categoryStore: context.categoryStore)
        origin.synchronizePresentation(generation: context.provider.generationToken, availabilityState: .current)
        let first = try #require(origin.transactionPresentationResult.rows.first)
        let accountID = try #require(first.accountID)
        origin.presentationFilter.accountIDs = [accountID]
        origin.presentationFilter.currencies = [first.transaction.money.currency]
        origin.presentationSort = .init(key: .nativeAmount, direction: .ascending)
        origin.selectPresentationRow(id: first.stableID)
        let filter = origin.presentationFilter
        let selected = origin.selectedPresentationRowID
        let overview = origin.makePeriodOverview()
        #expect(overview.presentationFilter == filter)
        #expect(overview.presentationSort == origin.presentationSort)
        #expect(overview.selectedPresentationRowID == selected)
        let dates = try #require(PeriodOverviewRange.three.dates(ending: StatementDate(canonical: "2026-09-29")))
        overview.presentationFilter.statementDateRange = dates
        #expect(overview.presentationFilter.accountIDs == [accountID])
        overview.presentationFilter.accountIDs = []
        #expect(overview.presentationFilter.statementDateRange == dates)
        #expect(overview.presentationFilter.currencies == filter.currencies)
        overview.presentationFilter.excludesAllAccounts = true
        #expect(overview.transactionPresentationResult.state == .validEmpty)
        #expect(origin.presentationFilter == filter)
        #expect(origin.selectedPresentationRowID == selected)
        #expect(origin.presentationSort == .init(key: .nativeAmount, direction: .ascending))
    }

    @Test(.globalRuntimeStateIsolation)
    func periodOverviewDailyTotalsKeepNativePartitionsAndOnlyObservedDates() async throws {
        let context = try await authenticTransactionListContext()
        let model = TransactionListViewModel(transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore, accountStore: context.accountStore, categoryStore: context.categoryStore)
        model.synchronizePresentation(generation: context.provider.generationToken, availabilityState: .current)
        let rows = model.transactionPresentationResult.rows
        #expect(!rows.isEmpty)
        let days = PeriodOverviewDay.observed(in: rows)
        #expect(Set(days.map(\.date)) == Set(rows.compactMap(\.sourceCivilDate)))
        for day in days {
            let observed = rows.filter { $0.sourceCivilDate == day.date }
            for (key, total) in day.totals.partitions {
                let matching = observed.filter {
                    $0.transaction.money.currency == key.currency && $0.domain == key.domain && $0.effect == key.effect
                }
                #expect(!matching.isEmpty)
                #expect(total.amount == matching.reduce(Decimal.zero) { $0 + $1.transaction.money.amount })
            }
            #expect(day.totals.withheldUnknownDomainCount == observed.filter { $0.domain == .unknown }.count)
            #expect(day.totals.withheldUnknownEffectCount == observed.filter { $0.domain != .unknown && $0.effect == .unknown }.count)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func coherentStorePublicationRebuildsSelectedRowsOnce() async throws {
        let context = try await authenticTransactionListContext()
        let model = TransactionListViewModel(
            transactionStore: context.transactionStore, importSessionStore: context.importSessionStore,
            accountStore: context.accountStore, categoryStore: context.categoryStore
        )
        model.synchronizePresentation(generation: context.provider.generationToken, availabilityState: .current)
        let original = model.transactionPresentationResult
        let selected = try #require(original.rows.first?.stableID)
        model.selectPresentationRow(id: selected)
        let revision = model.canonicalContentRevision
        let builds = model.canonicalProjectionBuildCount
        let queries = model.queryEvaluationCount

        context.transactionStore.notifyTransactionsOfInstalledValues()
        context.accountStore.notifyAccountsOfInstalledValue()
        context.categoryStore.notifySnapshotOfInstalledValue()
        for _ in 0..<100 where model.canonicalContentRevision == revision {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.canonicalContentRevision == revision + 1)
        #expect(model.canonicalProjectionBuildCount == builds + 1)
        #expect(model.queryEvaluationCount == queries + 1)
        #expect(model.selectedPresentationRowID == selected)
        #expect(model.transactionPresentationResult.rows.map(\.stableID) == original.rows.map(\.stableID))
        #expect(model.transactionPresentationResult.totals == original.totals)

        context.transactionStore.notifyTransactionsOfInstalledValues()
        model.synchronizePresentation(generation: nil, availabilityState: .unavailable)
        let withdrawnRevision = model.canonicalContentRevision
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.canonicalContentRevision == withdrawnRevision)
        #expect(model.transactionPresentationResult.state == .unavailable)
        #expect(model.allPresentationRows.isEmpty)
        #expect(model.selectedPresentationRowID == nil)
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

    @Test
    func sourceDocumentLabelsKeepOriginalImportAndPreferredEvidenceSeparate() {
        // These are filename/availability mechanics, not statement or DTO inputs.
        let separate = TransactionSourceDocumentsPresentation(
            originalImportDocumentName: "original.csv", preferredSourceDocumentName: "later.pdf")
        #expect(separate.originalImportDocumentName == "original.csv")
        #expect(separate.preferredSourceDocumentName == "later.pdf")

        let missingOriginal = TransactionSourceDocumentsPresentation(
            originalImportDocumentName: nil, preferredSourceDocumentName: "later.pdf")
        #expect(missingOriginal.originalImportDocumentName == "Unavailable")
        #expect(missingOriginal.preferredSourceDocumentName == "later.pdf")

        let blankPreferred = TransactionSourceDocumentsPresentation(
            originalImportDocumentName: " original.csv ", preferredSourceDocumentName: " \n ")
        #expect(blankPreferred.originalImportDocumentName == "original.csv")
        #expect(blankPreferred.preferredSourceDocumentName == nil)

        // Equal filenames do not prove that the two source owners are identical.
        let sameNames = TransactionSourceDocumentsPresentation(
            originalImportDocumentName: "statement.pdf", preferredSourceDocumentName: "statement.pdf")
        #expect(sameNames.originalImportDocumentName == "statement.pdf")
        #expect(sameNames.preferredSourceDocumentName == "statement.pdf")
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

        #expect(presentation.sourceDocumentName == transaction.repositorySourceDocumentName)
        #expect(presentation.preferredSourceDocumentName == transaction.repositoryPreferredSourceDocumentName)
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
    let historyOnlyAccountIDs: Set<String>
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
    let databaseURL = try AuthenticSourceTestSupport.presentationDatabaseURL()
    // Read-only access applies before provider initialization, so this
    // presentation check cannot create a database, apply migrations, or write rows.
    let provider = try AuthenticSourceTestSupport.readOnlyRegisteredProvider(at: databaseURL)
    try provider.database.execute(sql: "PRAGMA query_only = ON;")
    // Keep the same committed source snapshot across every hydration query,
    // including when the separate app process accepts another original.
    try provider.database.execute(sql: "BEGIN DEFERRED TRANSACTION;")
    defer { try? provider.database.execute(sql: "ROLLBACK;") }
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
        historyOnlyAccountIDs: Set(try provider.accountRepo.accounts(workspaceId: workspaceID).filter { $0.closedAtISO != nil }.map(\.id)),
        accountStore: accountStore,
        transactionStore: transactionStore,
        categoryStore: categoryStore,
        importSessionStore: importSessionStore
    )
    AcceptedTransactionSnapshot.cached = context
    return context
}
