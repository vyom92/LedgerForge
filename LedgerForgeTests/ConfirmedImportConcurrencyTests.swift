import Foundation
import Testing
@testable import LedgerForge

struct ConfirmedImportConcurrencyTests {
    @Test func independentSQLiteProvidersSerializeFingerprintRace() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("race.sqlite").path
        let first = try SQLiteRepositoryProvider(path: path, migrations: allMigrations + [migrationV5])
        let second = try SQLiteRepositoryProvider(path: path, migrations: allMigrations + [migrationV5])
        let firstPlan = confirmedImportPlan(generationToken: first.generationToken)
        let secondPlan = confirmedImportPlan(generationToken: second.generationToken)
        let lock = NSLock()
        var results = [ConfirmedImportRepositoryResult]()
        let group = DispatchGroup()

        for (repo, plan) in [(first.confirmedImportRepo, firstPlan), (second.confirmedImportRepo, secondPlan)] {
            group.enter()
            DispatchQueue.global().async {
                let result = repo.commitConfirmedImport(plan)
                lock.lock(); results.append(result); lock.unlock()
                group.leave()
            }
        }
        #expect(group.wait(timeout: .now() + 5) == .success)
        #expect(results.filter { if case .committed = $0 { true } else { false } }.count == 1)
        #expect(results.filter { $0 == .exactDuplicate }.count == 1)
        #expect(try first.importSessionRepo.importAttempts(workspaceId: firstPlan.workspace.id).count == 1)
        #expect(try first.accountRepo.accounts(workspaceId: firstPlan.workspace.id).count == 1)
        first.database.close(); second.database.close()
    }

    @Test func inMemoryProviderSerializesConcurrentConfirmations() throws {
        let provider = InMemoryRepositoryProvider()
        let plan = confirmedImportPlan(generationToken: provider.generationToken)
        let lock = NSLock()
        var results = [ConfirmedImportRepositoryResult]()
        let group = DispatchGroup()
        for _ in 0..<2 {
            group.enter()
            DispatchQueue.global().async {
                let result = provider.confirmedImportRepo.commitConfirmedImport(plan)
                lock.lock(); results.append(result); lock.unlock()
                group.leave()
            }
        }
        #expect(group.wait(timeout: .now() + 5) == .success)
        #expect(results.filter { if case .committed = $0 { true } else { false } }.count == 1)
        #expect(results.filter { $0 == .exactDuplicate }.count == 1)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: plan.workspace.id).count == 1)
    }
}
