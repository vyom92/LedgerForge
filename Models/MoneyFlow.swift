import Foundation

/// Read-only, native-currency views over the shared spending interpretation.
/// A flow is an aggregate relationship between accounts, never a tracing of a
/// particular salary receipt or a reconciliation against an invented balance.
nonisolated enum MoneyFlowMeasure: String, CaseIterable, Identifiable, Sendable {
    case actualMovements = "Actual movements"
    case adjustedSpending = "Adjusted spending"
    var id: Self { self }
}

nonisolated enum MoneyFlowRole: String, Sendable {
    case bank, card, income, spending, transfer, cardPayment, refund, reversal
    case outsideSpendingScope, unresolved, periodBoundary, conversionBoundary

    var explanation: String {
        switch self {
        case .bank, .card: "Recorded incoming and outgoing relationships are shown separately."
        case .income: "Income follows the saved interpretation or selected salary rule."
        case .spending: "Recognised spending. Category and financial treatment remain separate."
        case .transfer: "Confirmed transfer between owned accounts; not terminal spending."
        case .cardPayment: "Confirmed bank payment to a card; not a second spending charge."
        case .refund: "An actual credit on its source date; adjusted spending belongs to the purchase month."
        case .reversal: "Actual reversal entries remain on their recorded dates."
        case .outsideSpendingScope: "Recorded account or card-liability movement, excluded from adjusted spending."
        case .unresolved: "The source movement is recorded; its full financial meaning is not resolved."
        case .periodBoundary: "The confirmed counterpart is supporting context outside this period."
        case .conversionBoundary: "Both reviewed native amounts are retained without a common exchange-rate scale."
        }
    }
}

nonisolated struct MoneyFlowRecord: Identifiable, Sendable {
    let id: String
    let accountID: String
    let accountTitle: String
    let date: StatementDate?
    let dateRole: String
    let money: Money
}

nonisolated struct MoneyFlowNode: Identifiable, Sendable {
    let id: String
    /// Repeated visual endpoints retain the same authentic account identity.
    let accountID: String?
    let title: String
    let subtitle: String?
    let role: MoneyFlowRole
    let stage: Int
    let incoming: Money
    let outgoing: Money
    let transactionIDs: Set<String>
    let supportingIDs: Set<String>

    /// Rendering magnitude only; it is not a balance, income or savings total.
    var magnitude: Money { incoming.amount >= outgoing.amount ? incoming : outgoing }
    var isAccount: Bool { role == .bank || role == .card }
}

nonisolated struct MoneyFlowLink: Identifiable, Sendable {
    let id: String
    let sourceID: String
    let targetID: String
    let role: MoneyFlowRole
    let amount: Money
    let transactionIDs: Set<String>
    let supportingIDs: Set<String>
    let amounts: SpendingAmounts?
    let refundDetails: [SpendingRefundDetail]
}

nonisolated enum MoneyFlowSelection: Hashable, Sendable {
    case node(String)
    case link(String)
}

nonisolated struct MoneyFlowSelectionDetail: Sendable {
    let title: String
    let role: MoneyFlowRole
    let incoming: Money?
    let outgoing: Money?
    let amount: Money?
    let transactionIDs: Set<String>
    let supportingIDs: Set<String>
    let amounts: SpendingAmounts?
    let refundDetails: [SpendingRefundDetail]
    var allTransactionIDs: Set<String> { transactionIDs.union(supportingIDs) }
}

nonisolated struct MoneyFlowGraph: Sendable {
    let nodes: [MoneyFlowNode]
    let links: [MoneyFlowLink]
    let transactionIDs: Set<String>

    func detail(for selection: MoneyFlowSelection) throws -> MoneyFlowSelectionDetail? {
        switch selection {
        case .link(let id):
            guard let link = links.first(where: { $0.id == id }),
                  let source = nodes.first(where: { $0.id == link.sourceID }),
                  let target = nodes.first(where: { $0.id == link.targetID }) else { return nil }
            return .init(title: source.title + " → " + target.title, role: link.role,
                incoming: nil, outgoing: nil, amount: link.amount,
                transactionIDs: link.transactionIDs, supportingIDs: link.supportingIDs,
                amounts: link.amounts, refundDetails: link.refundDetails)
        case .node(let id):
            guard let node = nodes.first(where: { $0.id == id }) else { return nil }
            let connected = links.filter { $0.sourceID == id || $0.targetID == id }
            let values = connected.compactMap(\.amounts)
            let amounts = try values.first.map { first in
                try values.dropFirst().reduce(first) { try $0.adding($1) }
            }
            let details = Dictionary(connected.flatMap(\.refundDetails).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return .init(title: node.title, role: node.role,
                incoming: node.incoming, outgoing: node.outgoing, amount: nil,
                transactionIDs: node.transactionIDs, supportingIDs: node.supportingIDs,
                amounts: amounts, refundDetails: details.values.sorted { $0.id < $1.id })
        }
    }
}

nonisolated struct MoneyFlowConversionBridge: Identifiable, Sendable {
    let id: String
    let sent: MoneyFlowRecord
    let received: MoneyFlowRecord
    let transactionIDs: Set<String>
    let supportingIDs: Set<String>
    var allTransactionIDs: Set<String> { transactionIDs.union(supportingIDs) }
}

nonisolated struct MoneyFlowCoverage: Identifiable, Sendable {
    let id: String
    let title: String
    let isHistoryOnly: Bool
    let isComplete: Bool
    let recordedThrough: StatementDate?
}

nonisolated struct MoneyFlowProjection: Sendable {
    let month: SelectedStatementMonth
    let currency: String
    let actual: MoneyFlowGraph
    let adjusted: MoneyFlowGraph
    let adjustedAmounts: SpendingAmounts
    let records: [String: MoneyFlowRecord]
    let conversionBridges: [MoneyFlowConversionBridge]
    let coverage: [MoneyFlowCoverage]
    let periodTransactionIDs: Set<String>
    let undatedTransactionIDs: Set<String>
    /// Outside adjusted spending; directed bank/card entries remain in actual.
    let excludedTransactionIDs: Set<String>
    let unknownDirectionIDs: Set<String>
    let unresolvedTransactionIDs: Set<String>
    let refundReviewTransactionIDs: Set<String>
    /// The same selected-period interpretation used to build the graph.
    let reviewRows: [String: SpendingReviewRow]

    func graph(for measure: MoneyFlowMeasure) -> MoneyFlowGraph {
        measure == .actualMovements ? actual : adjusted
    }
}

nonisolated struct MoneyFlowInspection: Sendable {
    let month: SelectedStatementMonth
    let currency: String
    let transactionIDs: Set<String>
    let supportingIDs: Set<String>
    let reviewRows: [String: SpendingReviewRow]
    let unknownDirectionIDs: Set<String>
    var allTransactionIDs: Set<String> { transactionIDs.union(supportingIDs) }
}

extension MoneyFlowProjection {
    func inspection(ids: Set<String>, supportingIDs: Set<String> = []) -> MoneyFlowInspection {
        let actual = ids.subtracting(supportingIDs)
        return .init(month: month, currency: currency, transactionIDs: actual, supportingIDs: ids.subtracting(actual),
            reviewRows: reviewRows.filter { ids.contains($0.key) }, unknownDirectionIDs: unknownDirectionIDs.intersection(ids))
    }
}

nonisolated enum MoneyFlowError: Error, LocalizedError {
    case inconsistentSnapshot
    var errorDescription: String? {
        "Recorded money flow could not be matched to the current financial context. Refresh the ledger before reviewing this period."
    }
}

nonisolated enum MoneyFlow {
    /// The caller supplies one coherent full-history source snapshot and the
    /// shared oracle's selected calendar month, including historical accounts.
    /// Automatic intent, source fees and refund allocation are resolved there.
    static func project(rows: [SpendingSourceRow], metadata: FinancialIntelligenceSnapshot,
                        sources: FinancialSourceContext, month: SelectedStatementMonth,
                        currency: String, spending: SpendingProjection) throws -> MoneyFlowProjection {
        try Task.checkCancellation()
        let native = try CurrencyCode(currency).code
        guard spending.selectedCurrency == native,
              Set(rows.map(\.id)).count == rows.count,
              Set(spending.rows.map(\.id)).count == spending.rows.count else { throw MoneyFlowError.inconsistentSnapshot }
        let allRows = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        let selected = rows.filter { $0.currency == native && contains($0.date, in: month) }
        let selectedIDs = Set(selected.map(\.id))
        let review = Dictionary(uniqueKeysWithValues: spending.rows.map { ($0.id, $0) })
        guard selectedIDs == Set(review.keys) else { throw MoneyFlowError.inconsistentSnapshot }

        var confirmed: [String: MovementEvent] = [:]
        for event in metadata.movements where event.decision == .confirmed {
            try Task.checkCancellation()
            guard event.workspaceID == metadata.workspaceID,
                  Set(event.transactionIDs).count == event.transactionIDs.count else { throw MoneyFlowError.inconsistentSnapshot }
            for id in event.transactionIDs {
                guard confirmed.updateValue(event, forKey: id) == nil else { throw MoneyFlowError.inconsistentSnapshot }
            }
        }

        let records = Dictionary(uniqueKeysWithValues: rows.map { row in
            (row.id, MoneyFlowRecord(id: row.id, accountID: row.accountID, accountTitle: row.accountTitle,
                date: row.date, dateRole: row.dateRole, money: row.transaction.money))
        })
        var actual = try Builder(currency: native)
        var adjusted = try Builder(currency: native)
        var consumed: Set<String> = []
        var bridges: [MoneyFlowConversionBridge] = []
        let excluded = Set(selected.filter { review[$0.id]?.treatment == .outsideScope }.map(\.id))
        var unknownDirection: Set<String> = []

        // Each confirmed pair has one principal link. Its real source legs are
        // retained as contributors; it is never another terminal expense.
        for event in metadata.movements.sorted(by: { $0.id < $1.id })
            where event.decision == .confirmed && [.ownTransfer, .cardPayment].contains(event.kind)
                && !selectedIDs.isDisjoint(with: event.transactionIDs) {
            try Task.checkCancellation()
            let legs = event.transactionIDs.compactMap { allRows[$0] }
            guard legs.count == 2,
                  let sent = legs.first(where: \.isBankOut),
                  let received = legs.first(where: { event.kind == .ownTransfer ? $0.isBankIn : $0.isCardDecrease }),
                  sent.id != received.id, sent.accountID != received.accountID,
                  event.kind != .cardPayment || received.domain == "credit_card" else { throw MoneyFlowError.inconsistentSnapshot }
            let sentAmount = try magnitude(sent), receivedAmount = try magnitude(received)
            let isConversion = sent.currency != received.currency
            guard event.kind != .cardPayment || !isConversion,
                  isConversion || sentAmount == receivedAmount else { throw MoneyFlowError.inconsistentSnapshot }
            let current = Set(legs.filter { selectedIDs.contains($0.id) }.map(\.id))
            let support = Set(event.transactionIDs).subtracting(current)
            let role: MoneyFlowRole = event.kind == .cardPayment ? .cardPayment : .transfer

            if isConversion {
                guard let sentRecord = records[sent.id], let receivedRecord = records[received.id] else { throw MoneyFlowError.inconsistentSnapshot }
                bridges.append(.init(id: event.id, sent: sentRecord, received: receivedRecord,
                    transactionIDs: current, supportingIDs: support))
            }
            if current.contains(sent.id) && current.contains(received.id) {
                try actual.add(from: .account(sent), to: .account(received), role: role, amount: sentAmount,
                    transactionIDs: current, supportingIDs: [], amounts: nil, refundDetails: [])
            } else if current.contains(sent.id) {
                let endpoint = Endpoint(id: key("to-counterpart", event.id), title: received.accountTitle,
                    subtitle: isConversion ? "Reviewed \(received.currency) counterpart" : counterpartSubtitle(received),
                    role: isConversion ? .conversionBoundary : .periodBoundary, position: .destination)
                try actual.add(from: .account(sent), to: endpoint, role: role, amount: sentAmount,
                    transactionIDs: current, supportingIDs: support, amounts: nil, refundDetails: [])
            } else if current.contains(received.id) {
                let endpoint = Endpoint(id: key("from-counterpart", event.id), title: sent.accountTitle,
                    subtitle: isConversion ? "Reviewed \(sent.currency) counterpart" : counterpartSubtitle(sent),
                    role: isConversion ? .conversionBoundary : .periodBoundary, position: .source)
                try actual.add(from: endpoint, to: .account(received), role: role, amount: receivedAmount,
                    transactionIDs: current, supportingIDs: support, amounts: nil, refundDetails: [])
            }
            consumed.formUnion(current)
        }

        for row in selected.sorted(by: { $0.id < $1.id }) {
            try Task.checkCancellation()
            guard let interpretation = review[row.id] else { throw MoneyFlowError.inconsistentSnapshot }
            let outgoing = row.isBankOut || row.isCardIncrease
            let incoming = row.isBankIn || row.isCardDecrease
            guard outgoing != incoming, row.domain == "bank" || row.domain == "credit_card" else {
                unknownDirection.insert(row.id)
                continue
            }

            if !consumed.contains(row.id) {
                let endpoint: Endpoint
                let role: MoneyFlowRole
                switch interpretation.treatment {
                case .outsideScope:
                    endpoint = .init(id: outgoing ? "outside-spending-outflow" : "outside-spending-inflow",
                        title: "Outside spending scope", subtitle: "Actual recorded movement",
                        role: .outsideSpendingScope, position: outgoing ? .destination : .source)
                    role = .outsideSpendingScope
                case .expense where outgoing:
                    endpoint = .category(row); role = .spending
                case .income where incoming:
                    endpoint = .init(id: row.isRegularSalary ? "salary" : "income",
                        title: row.isRegularSalary ? "Salary" : "Income", subtitle: nil, role: .income, position: .source)
                    role = .income
                case .refund where incoming:
                    let unresolvedCredit = interpretation.refundNeedsReview || (interpretation.refundResidual?.amount ?? 0) > 0
                    endpoint = .init(id: unresolvedCredit ? "unallocated-refund-credit" : "refund-credit",
                        title: unresolvedCredit ? "Credits needing allocation" : "Refund credits", subtitle: nil,
                        role: unresolvedCredit ? .unresolved : .refund, position: .source)
                    role = unresolvedCredit ? .unresolved : .refund
                case .reversal:
                    endpoint = .init(id: outgoing ? "reversal-debit" : "reversal-credit",
                        title: outgoing ? "Reversal debits" : "Reversal credits", subtitle: nil, role: .reversal,
                        position: outgoing ? .destination : .source)
                    role = .reversal
                default:
                    endpoint = .init(id: outgoing ? "unresolved-outflow" : "unresolved-inflow",
                        title: outgoing ? "Unresolved outflow" : "Unresolved inflow", subtitle: nil, role: .unresolved,
                        position: outgoing ? .destination : .source)
                    role = .unresolved
                }
                var supporting = Set(interpretation.refundDetails.flatMap { [$0.purchaseTransactionID, $0.creditTransactionID] })
                if interpretation.treatment == .reversal, let event = confirmed[row.id] { supporting.formUnion(event.transactionIDs) }
                supporting.remove(row.id)
                try actual.add(from: outgoing ? .account(row) : endpoint, to: outgoing ? endpoint : .account(row),
                    role: role, amount: magnitude(row), transactionIDs: [row.id], supportingIDs: supporting,
                    amounts: nil, refundDetails: interpretation.refundDetails)
            }

            if interpretation.treatment == .expense {
                guard outgoing, let amounts = interpretation.amounts,
                      amounts.gross.currency.code == native, amounts.allocatedRefund.currency.code == native,
                      amounts.net.currency.code == native, amounts.gross.amount >= 0,
                      amounts.allocatedRefund.amount >= 0, amounts.net.amount >= 0,
                      amounts.gross == (try magnitude(row)),
                      try amounts.gross - amounts.allocatedRefund == amounts.net else { throw MoneyFlowError.inconsistentSnapshot }
                let supporting = Set(interpretation.refundDetails.map(\.creditTransactionID)).subtracting([row.id])
                // Zero-net links stay in the graph/list and retain their real
                // purchase and credit IDs, although they have no ribbon width.
                try adjusted.add(from: .account(row), to: .category(row), role: .spending, amount: amounts.net,
                    transactionIDs: [row.id], supportingIDs: supporting, amounts: amounts,
                    refundDetails: interpretation.refundDetails)
            }
        }

        let actualGraph = try actual.finish(), adjustedGraph = try adjusted.finish()
        let expectedActual = selectedIDs.subtracting(unknownDirection)
        guard actualGraph.transactionIDs == expectedActual,
              adjustedGraph.transactionIDs.isDisjoint(with: excluded) else { throw MoneyFlowError.inconsistentSnapshot }
        let calculated = try adjustedGraph.links.compactMap(\.amounts).reduce(SpendingAmounts.zero(currency: native)) {
            try $0.adding($1)
        }
        guard calculated.gross == spending.amounts.gross,
              calculated.allocatedRefund == spending.amounts.allocatedRefund,
              calculated.net == spending.amounts.net else { throw MoneyFlowError.inconsistentSnapshot }
        let first = try StatementDate(year: month.year, month: month.month, day: 1)
        guard let last = FinancialCalendar.lastDay(month) else { throw MoneyFlowError.inconsistentSnapshot }
        let coverage = sources.accounts.filter { $0.currency == native && ["bank", "credit_card"].contains($0.domain) }
            .map { account in
                MoneyFlowCoverage(id: account.id, title: account.title, isHistoryOnly: account.isHistoryOnly,
                    isComplete: sources.hasCompleteCoverage(accountID: account.id, start: first, end: last),
                    recordedThrough: sources.periods.filter { $0.accountID == account.id && $0.start <= last }.map(\.end).max())
            }.sorted { ($0.title, $0.id) < ($1.title, $1.id) }
        let referenced = actualGraph.links.flatMap { $0.transactionIDs.union($0.supportingIDs) }
            + adjustedGraph.links.flatMap { $0.transactionIDs.union($0.supportingIDs) }
        guard Set(referenced).isSubset(of: Set(records.keys)) else { throw MoneyFlowError.inconsistentSnapshot }
        return .init(month: month, currency: native, actual: actualGraph, adjusted: adjustedGraph,
            adjustedAmounts: spending.amounts, records: records, conversionBridges: bridges, coverage: coverage,
            periodTransactionIDs: selectedIDs,
            undatedTransactionIDs: Set(rows.filter { $0.currency == native && $0.date == nil }.map(\.id)),
            excludedTransactionIDs: excluded, unknownDirectionIDs: unknownDirection,
            unresolvedTransactionIDs: Set(spending.rows.filter { $0.treatment == .unresolved }.map(\.id)),
            refundReviewTransactionIDs: Set(spending.rows.filter { $0.refundNeedsReview || ($0.refundResidual?.amount ?? 0) > 0 }.map(\.id)),
            reviewRows: review)
    }

    private static func contains(_ date: StatementDate?, in month: SelectedStatementMonth) -> Bool {
        date.map { $0.year == month.year && $0.month == month.month } ?? false
    }

    private static func magnitude(_ row: SpendingSourceRow) throws -> Money {
        try Money(amount: abs(row.transaction.money.amount), currency: row.transaction.money.currency)
    }

    private static func counterpartSubtitle(_ row: SpendingSourceRow) -> String {
        row.date.map { "Counterpart " + $0.presentation + " · outside month" } ?? "Counterpart date unavailable"
    }

    private static func key(_ parts: String...) -> String {
        parts.map { "\($0.utf8.count):\($0)" }.joined()
    }

    private enum Position: Equatable { case source, account, destination }

    private struct Endpoint {
        let id: String
        let title: String
        let subtitle: String?
        let role: MoneyFlowRole
        let position: Position
        var accountID: String? = nil

        static func account(_ row: SpendingSourceRow) -> Self {
            .init(id: key("account", row.accountID), title: row.accountTitle,
                subtitle: row.domain == "credit_card" ? "Card liability" : "Bank account",
                role: row.domain == "credit_card" ? .card : .bank, position: .account, accountID: row.accountID)
        }

        static func category(_ row: SpendingSourceRow) -> Self {
            let id = row.categoryConflict ? "conflict" : (row.categoryID ?? "uncategorized")
            return .init(id: key("category", id), title: row.categoryConflict ? "Category conflict" : row.categoryName,
                subtitle: "Spending", role: .spending, position: .destination)
        }
    }

    private struct LinkKey: Hashable {
        let source: String
        let target: String
        let role: String
        var id: String { key(source, target, role) }
    }

    private struct LinkValue {
        let role: MoneyFlowRole
        var amount: Money
        var transactionIDs: Set<String>
        var supportingIDs: Set<String>
        var amounts: SpendingAmounts?
        var refundDetails: [String: SpendingRefundDetail]
    }

    private struct Builder {
        let zero: Money
        var endpoints: [String: Endpoint] = [:]
        var values: [LinkKey: LinkValue] = [:]

        init(currency: String) throws { zero = try Money(amount: 0, currency: currency) }

        mutating func add(from source: Endpoint, to target: Endpoint, role: MoneyFlowRole, amount: Money,
                          transactionIDs: Set<String>, supportingIDs: Set<String>, amounts: SpendingAmounts?,
                          refundDetails: [SpendingRefundDetail]) throws {
            guard source.id != target.id, amount.currency == zero.currency, amount.amount >= 0,
                  !transactionIDs.isEmpty else { throw MoneyFlowError.inconsistentSnapshot }
            endpoints[source.id] = source; endpoints[target.id] = target
            let key = LinkKey(source: source.id, target: target.id, role: role.rawValue)
            var value = values[key] ?? .init(role: role, amount: zero, transactionIDs: [], supportingIDs: [],
                amounts: nil, refundDetails: [:])
            guard value.transactionIDs.isDisjoint(with: transactionIDs) else { throw MoneyFlowError.inconsistentSnapshot }
            value.amount = try value.amount + amount
            value.transactionIDs.formUnion(transactionIDs); value.supportingIDs.formUnion(supportingIDs)
            if let amounts { value.amounts = try value.amounts.map { try $0.adding(amounts) } ?? amounts }
            for detail in refundDetails { value.refundDetails[detail.id] = detail }
            values[key] = value
        }

        mutating func finish() throws -> MoneyFlowGraph {
            let accountIDs = Set(endpoints.values.filter { $0.position == .account }.map(\.id))
            var adjacency: [String: Set<String>] = [:]
            var indegree = Dictionary(uniqueKeysWithValues: accountIDs.map { ($0, 0) })
            var stages = Dictionary(uniqueKeysWithValues: accountIDs.map { ($0, endpoints[$0]?.role == .card ? 2 : 1) })
            for key in values.keys where accountIDs.contains(key.source) && accountIDs.contains(key.target) {
                if adjacency[key.source, default: []].insert(key.target).inserted { indegree[key.target, default: 0] += 1 }
            }
            var ready = accountIDs.filter { indegree[$0] == 0 }.sorted()
            while !ready.isEmpty {
                try Task.checkCancellation()
                let id = ready.removeFirst()
                for target in (adjacency[id] ?? []).sorted() {
                    stages[target] = max(stages[target, default: 1], stages[id, default: 1] + 1)
                    indegree[target, default: 0] -= 1
                    if indegree[target] == 0 { ready.append(target); ready.sort() }
                }
            }
            // Cyclic relationships have no forward-only account ordering. Keep
            // every real link once, repeating only the backward endpoint.
            var rewritten: [LinkKey: LinkValue] = [:]
            for (original, value) in values.sorted(by: { $0.key.id < $1.key.id }) {
                var target = original.target
                if accountIDs.contains(original.source), accountIDs.contains(target),
                   stages[target, default: 1] <= stages[original.source, default: 1], let existing = endpoints[target] {
                    target = key("repeated-account", target, original.source)
                    endpoints[target] = .init(id: target, title: existing.title, subtitle: "Same account · repeated endpoint",
                        role: existing.role, position: .account, accountID: existing.accountID)
                    stages[target] = stages[original.source, default: 1] + 1
                }
                rewritten[LinkKey(source: original.source, target: target, role: original.role)] = value
            }
            values = rewritten
            let finalStage = (stages.values.max() ?? 0) + 1
            for endpoint in endpoints.values {
                if endpoint.position == .source { stages[endpoint.id] = 0 }
                if endpoint.position == .destination { stages[endpoint.id] = finalStage }
            }
            let activeIDs = Set(values.keys.flatMap { [$0.source, $0.target] })
            let uniqueStages = Set(activeIDs.compactMap { stages[$0] }).sorted()
            let compactStages = Dictionary(uniqueKeysWithValues: uniqueStages.enumerated().map { ($0.element, $0.offset) })
            let links = values.map { key, value in
                MoneyFlowLink(id: key.id, sourceID: key.source, targetID: key.target, role: value.role,
                    amount: value.amount, transactionIDs: value.transactionIDs,
                    supportingIDs: value.supportingIDs.subtracting(value.transactionIDs), amounts: value.amounts,
                    refundDetails: value.refundDetails.values.sorted { $0.id < $1.id })
            }.sorted { $0.id < $1.id }
            let nodes = try activeIDs.map { id -> MoneyFlowNode in
                guard let endpoint = endpoints[id], let stage = stages[id], let compact = compactStages[stage] else { throw MoneyFlowError.inconsistentSnapshot }
                let incoming = links.filter { $0.targetID == id }, outgoing = links.filter { $0.sourceID == id }
                let contributors = Set((incoming + outgoing).flatMap(\.transactionIDs))
                let supporting = Set((incoming + outgoing).flatMap(\.supportingIDs)).subtracting(contributors)
                return .init(id: id, accountID: endpoint.accountID, title: endpoint.title,
                    subtitle: endpoint.subtitle, role: endpoint.role, stage: compact,
                    incoming: try incoming.reduce(zero) { try $0 + $1.amount },
                    outgoing: try outgoing.reduce(zero) { try $0 + $1.amount },
                    transactionIDs: contributors, supportingIDs: supporting)
            }.sorted { ($0.stage, $0.title, $0.id) < ($1.stage, $1.title, $1.id) }
            return .init(nodes: nodes, links: links, transactionIDs: Set(links.flatMap(\.transactionIDs)))
        }
    }
}
