import Foundation
import Combine

/// A proposal is metadata keyed to the already-committed bank credit. This
/// observer does not import, create or save a monthly plan.
@MainActor
final class SalaryAssistanceSession: ObservableObject {
    static let shared = SalaryAssistanceSession()
    @Published private(set) var message: String?
    private var subscription: AnyCancellable?
    private var task: Task<Void, Never>?
    private var lastAttempt: (ProviderGenerationToken, UInt64)?
    private let enabled: Bool
    init(enabled: Bool = ProcessInfo.processInfo.environment["LEDGERFORGE_TEST_HOST"] != "1") { self.enabled = enabled }

    func start() {
        guard enabled, subscription == nil else { return }
        subscription = FinancialIntelligenceStore.shared.$snapshot.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
        }
    }
    func retry() { lastAttempt = nil; resume() }

    private func resume() {
        let store = FinancialIntelligenceStore.shared
        guard task == nil, let metadata = store.snapshot, let generation = store.generation,
              generation == DatabaseProvider.shared.generationToken else { return }
        guard let preferences = metadata.preferences, preferences.salaryAssistanceEnabled else { message = nil; return }
        if let issue = SpendingIntelligence.salarySetupIssue(preferences: preferences, categories: CategoryStore.shared.snapshot, sources: store.sources) {
            if message != issue { message = issue }
            return
        }
        if message?.hasPrefix("Setup incomplete:") == true { message = nil }
        guard
              !CategoryReconciliationGate.shared.isBlocked(for: generation),
              lastAttempt?.0 != generation || lastAttempt?.1 != store.revision else { return }
        let revision = store.revision
        lastAttempt = (generation, revision)
        let transactions = TransactionStore.shared.transactions, source = store.sources
        let categories = CategoryStore.shared.snapshot, cards = CardStore.shared.snapshot
        let today = FinancialCalendar.statement(Date())!
        task = Task { [weak self] in
            let work = Task.detached(priority: .utility) {
                let rows = try SpendingIntelligence.rows(transactions: transactions, sources: source, cards: cards, categories: categories, salaryRuleIDs: preferences.salaryRuleIDs)
                return Self.proposals(rows: rows, metadata: metadata, today: today)
            }
            let proposals = (try? await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })) ?? []
            guard let self else { return }
            defer {
                self.task = nil
                Task { @MainActor [weak self] in await Task.yield(); self?.resume() }
            }
            guard !Task.isCancelled, store.generation == generation, store.revision == revision,
                  DatabaseProvider.shared.generationToken == generation else { return }
            for proposal in proposals {
                // Each publication can change the saved metadata; recheck before writing.
                guard store.snapshot?.salaries.contains(where: { $0.id == proposal.id }) == false else { continue }
                do { try FinancialIntelligenceCoordinator().applyPlanning(.salary(proposal, replacing: nil), generation: generation) }
                catch { self.message = "Salary assistance is waiting: " + error.localizedDescription; return }
            }
            if !proposals.isEmpty { self.message = "A received salary is ready to review in Budget Planning." }
        }
    }

    nonisolated static func proposals(rows: [SpendingSourceRow], metadata: FinancialIntelligenceSnapshot, today: StatementDate, includeHistorical: Bool = false) -> [SalaryAssistance] {
        let current = String(today.canonical.prefix(7))
        let existing = Set(metadata.salaries.map(\.id)), confirmed = metadata.confirmedByTransaction
        return rows.compactMap { row in
            // Salary assistance follows the actual bank-credit/balance date.
            // The separate source transaction date is for spending presentation.
            guard row.isRegularSalary, !existing.contains(row.id), let day = row.transaction.statementDate, day <= today,
                  confirmed[row.id].map({ $0.kind == .income }) ?? true else { return nil }
            let target = String(day.canonical.prefix(7))
            guard includeHistorical || target == current else { return nil }
            return SalaryAssistance(transactionID: row.id, workspaceID: metadata.workspaceID, financialDate: day.canonical, targetMonth: target, planningBasis: .creditMonth)
        }.sorted { ($0.targetMonth, $0.financialDate, $0.id) < ($1.targetMonth, $1.financialDate, $1.id) }
    }
}
