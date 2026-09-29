import Combine
import Foundation

/// Classification runs only after coherent canonical publication. The repository
/// owns exact-new work and manual intent; this session owns no financial import.
@MainActor
final class CategoryAutomationSession: ObservableObject {
    static let shared = CategoryAutomationSession()
    @Published private(set) var isWorking = false
    @Published private(set) var message: String?
    private var subscription: AnyCancellable?
    private var task: Task<Void, Never>?
    private var lastAttempt: CategorySnapshot?
    private let categories: CategoryStore
    private let transactions: TransactionStore
    private let provider: () -> DatabaseProvider
    private let coordinator: () -> CategoryManagementCoordinator
    private let enabled: Bool
    private let evaluate: @Sendable ([CategoryRuleInput], CategoryAutomationSnapshot, [String: String], Set<String>) async -> CategoryEvaluation

    init(categories: CategoryStore = .shared, transactions: TransactionStore = .shared,
         provider: @escaping () -> DatabaseProvider = { .shared },
         coordinator: @escaping () -> CategoryManagementCoordinator = { CategoryManagementCoordinator() },
         enabled: Bool = ProcessInfo.processInfo.environment["LEDGERFORGE_TEST_HOST"] != "1",
         evaluate: @escaping @Sendable ([CategoryRuleInput], CategoryAutomationSnapshot, [String: String], Set<String>) async -> CategoryEvaluation = { inputs, snapshot, assignments, active in
             await Task.detached(priority: .utility) {
                 CategoryEvaluation.evaluate(inputs: inputs, snapshot: snapshot, assignments: assignments, activeCategoryIDs: active)
             }.value
         }) {
        self.categories = categories; self.transactions = transactions; self.provider = provider
        self.coordinator = coordinator; self.enabled = enabled; self.evaluate = evaluate
    }

    func start() {
        guard subscription == nil, enabled else { return }
        subscription = categories.$snapshot.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.resumeIfNeeded() }
        }
    }

    func retry() { lastAttempt = nil; resumeIfNeeded() }

    private func resumeIfNeeded() {
        guard !isWorking else { return }
        let snapshot = categories.snapshot
        guard snapshot != lastAttempt, let metadata = snapshot.automation, !metadata.pendingIDs.isEmpty,
              let generation = snapshot.providerGeneration,
              generation == provider().generationToken,
              !CategoryReconciliationGate.shared.isBlocked(for: generation) else { return }
        let ids = Set(metadata.pendingIDs.sorted().prefix(256))
        let inputs = Self.inputs(transactions: transactions.transactions, selectedIDs: ids)
        guard Set(inputs.map(\.transactionID)) == ids else {
            message = "Category work is waiting for the imported transactions to refresh."
            return
        }
        lastAttempt = snapshot; isWorking = true; message = nil
        let active = Set(snapshot.activeCategories.map(\.id))
        let evaluate = self.evaluate
        task = Task { [weak self] in
            let evaluation = await evaluate(inputs, metadata, snapshot.assignments, active)
            guard let self else { return }
            defer {
                self.isWorking = false; self.task = nil
                // Reconsider publications received during this task, including a
                // replacement generation. lastAttempt prevents a failed batch loop.
                Task { @MainActor [weak self] in
                    await Task.yield()
                    self?.resumeIfNeeded()
                }
            }
            guard !Task.isCancelled, self.provider().generationToken == generation,
                  self.categories.snapshot.providerGeneration == generation else { return }
            do {
                _ = try self.coordinator().applyEvaluation(evaluation, historical: false, expectedGeneration: generation)
                self.message = "Categories checked for \(inputs.count) newly imported transactions."
            } catch {
                self.message = CategoryManagementPresentation.message(for: error) + " Financial import is already saved; Retry checks categories only."
            }
        }
    }

    nonisolated static func inputs(transactions: [Transaction], selectedIDs: Set<String>) -> [CategoryRuleInput] {
        transactions.compactMap { transaction in
            guard let id = transaction.repositoryTransactionId, selectedIDs.contains(id) else { return nil }
            let direction = transaction.cardLiabilityEffect?.rawValue ?? (transaction.debitMoney != nil ? "debit" : "credit")
            return CategoryRuleInput(transactionID: id, accountID: transaction.repositoryAccountId,
                currency: transaction.currency, direction: direction,
                narration: transaction.description, reference: transaction.reference ?? "")
        }.sorted { $0.transactionID < $1.transactionID }
    }
}
