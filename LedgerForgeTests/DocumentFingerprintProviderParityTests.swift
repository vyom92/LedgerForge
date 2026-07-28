import Foundation
import Testing
@testable import LedgerForge

struct DocumentFingerprintProviderParityTests {
    @Test func rawTextAuthorityDuplicatesMatchAcrossProviders() throws {
        let setup = try makePacket2Providers(name: "authority-duplicate")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }

        let sqliteFirst = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "sqlite-first", specs: [packet2RawAuthority()])
        let sqliteDuplicate = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "sqlite-duplicate", specs: [packet2RawAuthority(id: "sqlite-duplicate-raw")])
        let memoryFirst = packet2Plan(generationToken: setup.memory.generationToken, suffix: "memory-first", specs: [packet2RawAuthority()])
        let memoryDuplicate = packet2Plan(generationToken: setup.memory.generationToken, suffix: "memory-duplicate", specs: [packet2RawAuthority(id: "memory-duplicate-raw")])

        #expect(isCommitted(setup.sqlite.confirmedImportRepo.commitConfirmedImport(sqliteFirst)))
        #expect(isCommitted(setup.memory.confirmedImportRepo.commitConfirmedImport(memoryFirst)))
        #expect(setup.sqlite.confirmedImportRepo.commitConfirmedImport(sqliteDuplicate) == .exactDuplicate)
        #expect(setup.memory.confirmedImportRepo.commitConfirmedImport(memoryDuplicate) == .exactDuplicate)
    }

    @Test func secondaryCollisionIsAllowedButAuthorityCollisionIsDuplicate() throws {
        let setup = try makePacket2Providers(name: "collision-parity")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }

        let sqliteFirst = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "sqlite-collision-first", specs: [packet2RawAuthority(), packet2SourceSecondary()])
        let sqliteSecondary = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "sqlite-collision-secondary", specs: [packet2RawAuthority(id: "raw-secondary", digest: String(repeating: "3", count: 64)), packet2SourceSecondary(id: "source-secondary")])
        let sqliteAuthority = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "sqlite-collision-authority", specs: [packet2RawAuthority(id: "raw-authority"), packet2SourceSecondary(id: "source-authority", digest: String(repeating: "4", count: 64))])
        let memoryFirst = packet2Plan(generationToken: setup.memory.generationToken, suffix: "memory-collision-first", specs: [packet2RawAuthority(), packet2SourceSecondary()])
        let memorySecondary = packet2Plan(generationToken: setup.memory.generationToken, suffix: "memory-collision-secondary", specs: [packet2RawAuthority(id: "memory-raw-secondary", digest: String(repeating: "3", count: 64)), packet2SourceSecondary(id: "memory-source-secondary")])
        let memoryAuthority = packet2Plan(generationToken: setup.memory.generationToken, suffix: "memory-collision-authority", specs: [packet2RawAuthority(id: "memory-raw-authority"), packet2SourceSecondary(id: "memory-source-authority", digest: String(repeating: "4", count: 64))])

        #expect(isCommitted(setup.sqlite.confirmedImportRepo.commitConfirmedImport(sqliteFirst)))
        #expect(isCommitted(setup.memory.confirmedImportRepo.commitConfirmedImport(memoryFirst)))
        #expect(isCommitted(setup.sqlite.confirmedImportRepo.commitConfirmedImport(sqliteSecondary)))
        #expect(isCommitted(setup.memory.confirmedImportRepo.commitConfirmedImport(memorySecondary)))
        #expect(setup.sqlite.confirmedImportRepo.commitConfirmedImport(sqliteAuthority) == .exactDuplicate)
        #expect(setup.memory.confirmedImportRepo.commitConfirmedImport(memoryAuthority) == .exactDuplicate)

        let sharedSecondaryRows = try setup.sqlite.database.queryInt("SELECT COUNT(*) FROM document_fingerprints WHERE algorithm = '\(DocumentFingerprintDTO.sourceBytesSHA256Algorithm)' AND fingerprint = '\(packet2SourceDigest)' AND is_duplicate_authority = 0;")
        #expect(sharedSecondaryRows == 2)
    }

    @Test func successfulImportPersistsTheCompleteRelatedCollection() throws {
        let setup = try makePacket2Providers(name: "complete")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let plan = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "complete", specs: [packet2SourceSecondary(), packet2RawAuthority()])

        #expect(isCommitted(setup.sqlite.confirmedImportRepo.commitConfirmedImport(plan)))
        let rows = try setup.sqlite.database.query(
            sql: "SELECT id, document_id, import_session_id, algorithm, fingerprint, is_duplicate_authority FROM document_fingerprints ORDER BY algorithm, id;"
        ) {
            ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.string(at: 2) ?? "", $0.string(at: 3) ?? "", $0.string(at: 4) ?? "", $0.bool(at: 5))
        }
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.1 == plan.historyTemplate.document.id && $0.2 == plan.historyTemplate.importSession.id })
        #expect(rows.map { $0.3 } == plan.historyTemplate.fingerprints.map(\.algorithm))
        #expect(rows.filter { $0.5 }.count == 1)
    }

    @Test func malformedCollectionLeavesNoAcceptedResidueAcrossProviders() throws {
        let setup = try makePacket2Providers(name: "malformed")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let invalidSpecs = [Packet2FingerprintSpec(id: "invalid", algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm, digest: "NOT-A-DIGEST", isAuthority: true)]
        let sqlitePlan = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "sqlite-malformed", specs: invalidSpecs)
        let memoryPlan = packet2Plan(generationToken: setup.memory.generationToken, suffix: "memory-malformed", specs: invalidSpecs)

        #expect(setup.sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .repositoryIntegrityConflict)
        #expect(setup.memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .repositoryIntegrityConflict)
        #expect(try acceptedGraphCount(setup.sqlite.database) == 0)
        #expect(try setup.memory.workspaceRepo.workspace(id: memoryPlan.workspace.id) == nil)
        #expect(try setup.memory.importSessionRepo.importSession(id: memoryPlan.historyTemplate.importSession.id) == nil)
    }

    @Test func failureOnSecondFingerprintPublishesNoAcceptedGraph() throws {
        let setup = try makePacket2Providers(name: "second-failure")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let sqlitePlan = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "sqlite-second-failure", specs: [packet2RawAuthority(), packet2SourceSecondary()])
        let memoryPlan = packet2Plan(generationToken: setup.memory.generationToken, suffix: "memory-second-failure", specs: [packet2RawAuthority(), packet2SourceSecondary()])
        try setup.sqlite.database.execute(sql: """
            CREATE TEMP TRIGGER fail_second_packet2_fingerprint
            BEFORE INSERT ON document_fingerprints
            WHEN NEW.algorithm = '\(DocumentFingerprintDTO.sourceBytesSHA256Algorithm)'
            BEGIN SELECT RAISE(ABORT, 'injected fingerprint failure'); END;
            """)
        setup.memory.injectConfirmedImportFailure(after: .fingerprint)

        #expect(setup.sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .repositoryIntegrityConflict)
        #expect(setup.memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .repositoryIntegrityConflict)
        #expect(try acceptedGraphCount(setup.sqlite.database) == 0)
        #expect(try setup.memory.workspaceRepo.workspace(id: memoryPlan.workspace.id) == nil)
        #expect(try setup.memory.importSessionRepo.importSession(id: memoryPlan.historyTemplate.importSession.id) == nil)
    }

    @Test func partialReviewUsesTheSameCollectionAndAuthorityValidation() throws {
        let setup = try makePacket2Providers(name: "partial-validation")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let validSQLite = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "sqlite-partial-valid", specs: [packet2SourceSecondary(), packet2RawAuthority()])
        let validMemory = packet2Plan(generationToken: setup.memory.generationToken, suffix: "memory-partial-valid", specs: [packet2SourceSecondary(), packet2RawAuthority()])
        let invalidSpec = [Packet2FingerprintSpec(id: "no-authority", algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm, digest: packet2RawDigest, isAuthority: false)]
        let invalidSQLite = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "sqlite-partial-invalid", specs: invalidSpec)
        let invalidMemory = packet2Plan(generationToken: setup.memory.generationToken, suffix: "memory-partial-invalid", specs: invalidSpec)

        #expect(setup.sqlite.confirmedImportRepo.reviewPartialImport(validSQLite) == .unsupportedEvidence)
        #expect(setup.memory.confirmedImportRepo.reviewPartialImport(validMemory) == .unsupportedEvidence)
        #expect(setup.sqlite.confirmedImportRepo.reviewPartialImport(invalidSQLite) == .repositoryIntegrityConflict)
        #expect(setup.memory.confirmedImportRepo.reviewPartialImport(invalidMemory) == .repositoryIntegrityConflict)

        let reviewedSQLite = ReviewedPartialImportPlanDTO(basePlan: invalidSQLite, existingAccountId: "missing", rows: [], sourceRowCount: 0, recognizedCount: 0, importedCount: 0, blockedCount: 0)
        let reviewedMemory = ReviewedPartialImportPlanDTO(basePlan: invalidMemory, existingAccountId: "missing", rows: [], sourceRowCount: 0, recognizedCount: 0, importedCount: 0, blockedCount: 0)
        #expect(setup.sqlite.confirmedImportRepo.commitReviewedPartialImport(reviewedSQLite) == .reviewedPartialPlanStale)
        #expect(setup.memory.confirmedImportRepo.commitReviewedPartialImport(reviewedMemory) == .reviewedPartialPlanStale)
    }

    @Test func reopenPreservesRowsAndAuthorityLookupIgnoresSecondaryMatches() throws {
        let setup = try makePacket2Providers(name: "reopen")
        let path = setup.folder.appendingPathComponent("provider.sqlite").path
        let first = packet2Plan(generationToken: setup.sqlite.generationToken, suffix: "reopen-first", specs: [packet2RawAuthority(), packet2SourceSecondary()])
        #expect(isCommitted(setup.sqlite.confirmedImportRepo.commitConfirmedImport(first)))
        setup.sqlite.database.close()

        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        defer { reopened.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM document_fingerprints;") == 2)
        #expect(try reopened.importSessionRepo.priorImportedStatement(algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm, fingerprint: packet2RawDigest)?.importSessionId == first.historyTemplate.importSession.id)
        #expect(try reopened.importSessionRepo.priorImportedStatement(algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, fingerprint: packet2SourceDigest) == nil)

        let secondaryOnly = packet2Plan(generationToken: reopened.generationToken, suffix: "reopen-secondary", specs: [packet2RawAuthority(id: "reopen-raw-secondary", digest: String(repeating: "5", count: 64)), packet2SourceSecondary(id: "reopen-shared-secondary")])
        #expect(isCommitted(reopened.confirmedImportRepo.commitConfirmedImport(secondaryOnly)))
    }
}

private func makePacket2Providers(name: String) throws -> (sqlite: SQLiteRepositoryProvider, memory: InMemoryRepositoryProvider, folder: URL) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Packet2-Provider-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return (
        try SQLiteRepositoryProvider(path: folder.appendingPathComponent("provider.sqlite").path, migrations: allMigrations),
        InMemoryRepositoryProvider(),
        folder
    )
}

private func isCommitted(_ result: ConfirmedImportRepositoryResult) -> Bool {
    if case .committed = result { return true }
    return false
}

private func acceptedGraphCount(_ database: SQLiteDatabase) throws -> Int {
    let tables = ["workspaces", "accounts", "documents", "document_fingerprints", "import_sessions", "transactions", "import_attempts"]
    return try tables.reduce(into: 0) { count, table in
        count += try database.queryInt("SELECT COUNT(*) FROM \(table);")
    }
}
