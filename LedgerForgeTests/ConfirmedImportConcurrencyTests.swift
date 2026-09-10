import Foundation
import Testing
@testable import LedgerForge

/// Concurrency checks replay one unchanged authentic source. They do not
/// manufacture competing financial statements or alter source identity.
/// Both requests rendezvous before the declared MainActor repository boundary.
/// SQLite and subprocess tests separately exercise storage lock contention.
@MainActor
struct ConfirmedImportConcurrencyTests {
    @Test(.globalRuntimeStateIsolation)
    func independentSQLiteProvidersSerializeAuthenticFingerprintRace() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("race.sqlite").path
        let first = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        let second = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        defer { first.database.close(); second.database.close() }
        let firstPlan = try await confirmedImportPlan(generationToken: first.generationToken)
        let secondPlan = try await confirmedImportPlan(generationToken: second.generationToken)
        let results = try await race(
            (first.confirmedImportRepo, firstPlan),
            (second.confirmedImportRepo, secondPlan)
        )

        #expect(results.filter { if case .committed = $0 { true } else { false } }.count == 1)
        #expect(results.filter { $0 == .exactDuplicate }.count == 1)
        #expect(try first.importSessionRepo.importAttempts(workspaceId: firstPlan.workspace.id).count == 1)
        #expect(try first.accountRepo.accounts(workspaceId: firstPlan.workspace.id).count == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func inMemoryProviderSerializesConcurrentAuthenticConfirmations() async throws {
        let provider = InMemoryRepositoryProvider()
        let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
        let results = try await race(
            (provider.confirmedImportRepo, plan),
            (provider.confirmedImportRepo, plan)
        )

        #expect(results.filter { if case .committed = $0 { true } else { false } }.count == 1)
        #expect(results.filter { $0 == .exactDuplicate }.count == 1)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: plan.workspace.id).count == 1)
    }

    private func race(
        _ first: (ConfirmedImportRepository, ConfirmedImportPlanDTO),
        _ second: (ConfirmedImportRepository, ConfirmedImportPlanDTO)
    ) async throws -> [ConfirmedImportRepositoryResult] {
        let operations = [first, second].map { MainActorCommitOperation($0) }
        let startBarrier = ConfirmedImportStartBarrier(expectedArrivals: operations.count)

        return try await withThrowingTaskGroup(of: ConfirmedImportRepositoryResult.self) { group in
            for operation in operations {
                group.addTask {
                    try await withTaskCancellationHandler(
                        operation: {
                            try Task.checkCancellation()
                            try await startBarrier.arriveAndWait()
                            return await operation.commit()
                        },
                        onCancel: {
                            Task { await startBarrier.cancel() }
                        }
                    )
                }
            }

            // This detects a stalled rendezvous; it does not order either commit.
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                await startBarrier.cancel()
                throw ConfirmedImportRaceError.timedOut
            }

            var results: [ConfirmedImportRepositoryResult] = []
            do {
                for _ in operations {
                    guard let result = try await group.next() else {
                        throw ConfirmedImportRaceError.incompleteResults
                    }
                    results.append(result)
                }
                group.cancelAll()
                return results
            } catch {
                await startBarrier.cancel()
                group.cancelAll()
                throw error
            }
        }
    }
}

/// Owns each protocol-erased repository only on the actor required by its API.
@MainActor
private final class MainActorCommitOperation {
    private let repository: ConfirmedImportRepository
    private let plan: ConfirmedImportPlanDTO

    init(_ operation: (ConfirmedImportRepository, ConfirmedImportPlanDTO)) {
        repository = operation.0
        plan = operation.1
    }

    func commit() -> ConfirmedImportRepositoryResult {
        repository.commitConfirmedImport(plan)
    }
}

private actor ConfirmedImportStartBarrier {
    private let expectedArrivals: Int
    private var arrivals = 0
    private var cancelled = false
    private var waiters: [CheckedContinuation<Void, Error>] = []

    init(expectedArrivals: Int) {
        self.expectedArrivals = expectedArrivals
    }

    func arriveAndWait() async throws {
        if cancelled {
            throw CancellationError()
        }

        arrivals += 1
        if arrivals == expectedArrivals {
            let pendingWaiters = waiters
            waiters.removeAll()
            pendingWaiters.forEach { $0.resume() }
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if cancelled {
                continuation.resume(throwing: CancellationError())
            } else {
                waiters.append(continuation)
            }
        }
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        let pendingWaiters = waiters
        waiters.removeAll()
        pendingWaiters.forEach { $0.resume(throwing: CancellationError()) }
    }
}

private enum ConfirmedImportRaceError: Error, Sendable {
    case timedOut
    case incompleteResults
}
