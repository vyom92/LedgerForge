import Foundation
import Testing
@testable import LedgerForge

/// Provider fingerprint persistence, rollback and reopen use deterministic
/// import plans through the real preparation and mapper. Source qualification
/// remains separate.
@MainActor
struct DocumentFingerprintProviderParityTests {
    @Test(.globalRuntimeStateIsolation)
    func repositoryFailureOnSecondAuthenticFingerprintPublishesNoAcceptedGraph() async throws {
        let setup = try makeProviders(name: "second-failure")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let sqlitePlan = try await confirmedImportPlan(generationToken: setup.sqlite.generationToken)
        let memoryPlan = try await confirmedImportPlan(generationToken: setup.memory.generationToken)
        let secondAlgorithm = try #require(sqlitePlan.historyTemplate.fingerprints.last?.algorithm)
        try setup.sqlite.database.execute(sql: """
            CREATE TEMP TRIGGER fail_second_authentic_fingerprint
            BEFORE INSERT ON document_fingerprints
            WHEN NEW.algorithm = '\(secondAlgorithm)'
            BEGIN SELECT RAISE(ABORT, 'injected fingerprint failure'); END;
            """)
        setup.memory.injectConfirmedImportFailure(after: .fingerprint)

        #expect(setup.sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .repositoryIntegrityConflict)
        #expect(setup.memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .repositoryIntegrityConflict)
        #expect(try acceptedGraphCount(setup.sqlite.database) == 0)
        #expect(try setup.memory.workspaceRepo.workspace(id: memoryPlan.workspace.id) == nil)
        #expect(try setup.memory.importSessionRepo.importSession(id: memoryPlan.historyTemplate.importSession.id) == nil)
    }

    @Test(.globalRuntimeStateIsolation)
    func reopenPreservesAuthenticFingerprintsAndAuthorityLookup() async throws {
        let setup = try makeProviders(name: "reopen")
        let path = setup.folder.appendingPathComponent("provider.sqlite").path
        let plan = try await confirmedImportPlan(generationToken: setup.sqlite.generationToken)
        #expect(isCommitted(setup.sqlite.confirmedImportRepo.commitConfirmedImport(plan)))
        try setup.sqlite.database.checkpointAndClose()

        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        defer { reopened.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM document_fingerprints;") == plan.historyTemplate.fingerprints.count)
        let authority = try #require(plan.historyTemplate.duplicateAuthorityFingerprint)
        #expect(try reopened.importSessionRepo.priorImportedStatement(
            algorithm: authority.algorithm,
            fingerprint: authority.fingerprint
        )?.importSessionId == plan.historyTemplate.importSession.id)
        for secondary in plan.historyTemplate.fingerprints where !secondary.isDuplicateAuthority {
            #expect(try reopened.importSessionRepo.priorImportedStatement(
                algorithm: secondary.algorithm,
                fingerprint: secondary.fingerprint
            ) == nil)
        }
    }
}

@MainActor
private func makeProviders(
    name: String
) throws -> (sqlite: SQLiteRepositoryProvider, memory: InMemoryRepositoryProvider, folder: URL) {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForge-FingerprintProvider-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return (
        try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("provider.sqlite").path,
            migrations: allMigrations
        ),
        InMemoryRepositoryProvider(),
        folder
    )
}

private func isCommitted(_ result: ConfirmedImportRepositoryResult) -> Bool {
    if case .committed = result { return true }
    return false
}

private func acceptedGraphCount(_ database: SQLiteDatabase) throws -> Int {
    let tables = [
        "workspaces",
        "accounts",
        "documents",
        "document_fingerprints",
        "import_sessions",
        "transactions",
        "import_attempts"
    ]
    return try tables.reduce(into: 0) { count, table in
        count += try database.queryInt("SELECT COUNT(*) FROM \(table);")
    }
}
