import Foundation
import Testing
@testable import LedgerForge

/// Concurrency checks replay one unchanged authentic source. They do not
/// manufacture competing financial statements or alter source identity.
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
        let results = race(
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
        let results = race(
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
    ) -> [ConfirmedImportRepositoryResult] {
        let operations = [first, second].map(ConcurrentCommitOperation.init)
        let lock = NSLock()
        var results: [ConfirmedImportRepositoryResult] = []
        let group = DispatchGroup()
        for operation in operations {
            group.enter()
            DispatchQueue.global().async {
                let result = operation.repository.commitConfirmedImport(operation.plan)
                lock.lock()
                results.append(result)
                lock.unlock()
                group.leave()
            }
        }
        #expect(group.wait(timeout: .now() + 5) == .success)
        return results
    }
}

/// The repository contract being exercised here is explicitly synchronous and
/// thread-safe. This box gives the concurrency harness ownership of each
/// immutable operation while leaving the production protocol unchanged.
private final class ConcurrentCommitOperation: @unchecked Sendable {
    let repository: ConfirmedImportRepository
    let plan: ConfirmedImportPlanDTO

    init(_ operation: (ConfirmedImportRepository, ConfirmedImportPlanDTO)) {
        repository = operation.0
        plan = operation.1
    }
}
