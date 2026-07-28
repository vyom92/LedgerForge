import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct SourceSnapshotPersistenceBindingTests {
    @Test(.globalRuntimeStateIsolation)
    func mapperEmitsCompleteSortedSetWithRawTextAuthorityAndLegacyDigest() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let engine = ImportEngine(
            importPersistenceCoordinator: BindingPreparationPersistence(),
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { ProviderGenerationToken() }
        )
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        defer { engine.cancelPreparedImport(prepared) }
        let plan = try ImportPersistenceMapper().confirmedImportPlan(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            fingerprintSet: prepared.fingerprintSet,
            providerGeneration: prepared.providerGeneration,
            advisoryIdentity: .noMatch,
            accountChoice: .createProposedAccount,
            selectedAccountId: "snapshot-binding-account"
        )

        let rows = plan.historyTemplate.fingerprints
        #expect(rows.map(\.algorithm) == [
            DocumentFingerprintDTO.rawTextSHA256Algorithm,
            DocumentFingerprintDTO.sourceBytesSHA256Algorithm
        ])
        #expect(rows.filter(\.isDuplicateAuthority).map(\.algorithm) == [
            DocumentFingerprintDTO.rawTextSHA256Algorithm
        ])
        #expect(rows.map(\.fingerprint) == prepared.fingerprintSet.fingerprints.map(\.digest))
        #expect(rows.allSatisfy {
            $0.documentId == plan.historyTemplate.document.id
                && $0.importSessionId == plan.historyTemplate.importSession.id
                && $0.fingerprintData == nil
        })
        #expect(plan.historyTemplate.document.legacyRawTextSHA256 == prepared.fingerprint.digest)
        #expect(plan.historyTemplate.document.sizeBytes == prepared.fingerprint.byteCount)
        try plan.historyTemplate.validateFingerprints()
    }

    @Test(.globalRuntimeStateIsolation)
    func reviewedPartialPlanRetainsTheCompleteSetWithoutSourceBytes() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let engine = ImportEngine(
            importPersistenceCoordinator: BindingPreparationPersistence(),
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { ProviderGenerationToken() }
        )
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        defer { engine.cancelPreparedImport(prepared) }
        let base = try ImportPersistenceMapper().confirmedImportPlan(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            fingerprintSet: prepared.fingerprintSet,
            providerGeneration: prepared.providerGeneration,
            advisoryIdentity: .noMatch,
            accountChoice: .useExistingAccount(accountId: "existing-account"),
            selectedAccountId: "existing-account"
        )
        let reviewed = ReviewedPartialImportPlanDTO(
            id: "snapshot-binding-reviewed",
            basePlan: base,
            existingAccountId: "existing-account",
            rows: [],
            sourceRowCount: 0,
            recognizedCount: 0,
            importedCount: 0,
            blockedCount: 0
        )

        #expect(reviewed.basePlan.historyTemplate.fingerprints == base.historyTemplate.fingerprints)
        #expect(reviewed.basePlan.historyTemplate.fingerprints.count == 2)
        #expect(reviewed.basePlan.historyTemplate.fingerprints.allSatisfy { $0.fingerprintData == nil })
        #expect(reviewed.hasValidDigest())
    }

    @Test(.globalRuntimeStateIsolation)
    func productionMappedSetPersistsExactlyWithSQLiteAndInMemoryParity() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let engine = ImportEngine(
            importPersistenceCoordinator: BindingPreparationPersistence(),
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { ProviderGenerationToken() }
        )
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        defer { engine.cancelPreparedImport(prepared) }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Packet3-Binding-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sqlite = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("provider.sqlite").path,
            migrations: allMigrations
        )
        let memory = InMemoryRepositoryProvider()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }

        let sqlitePlan = try mappedPlan(prepared, generation: sqlite.generationToken)
        let memoryPlan = try mappedPlan(prepared, generation: memory.generationToken)
        guard case .committed = sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan),
              case .committed = memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) else {
            Issue.record("Expected both providers to commit the production-mapped fingerprint set.")
            return
        }

        let stored = try sqlite.database.query(
            sql: "SELECT algorithm, fingerprint, is_duplicate_authority, document_id, import_session_id FROM document_fingerprints ORDER BY algorithm;"
        ) {
            ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.bool(at: 2), $0.string(at: 3) ?? "", $0.string(at: 4) ?? "")
        }
        #expect(stored.count == 2)
        #expect(stored.map { $0.0 } == prepared.fingerprintSet.fingerprints.map(\.algorithm))
        #expect(stored.map { $0.1 } == prepared.fingerprintSet.fingerprints.map(\.digest))
        #expect(stored.map { $0.2 } == prepared.fingerprintSet.fingerprints.map(\.isDuplicateAuthority))
        #expect(stored.allSatisfy {
            $0.3 == sqlitePlan.historyTemplate.document.id
                && $0.4 == sqlitePlan.historyTemplate.importSession.id
        })
        let legacyDigest = try sqlite.database.query(
            sql: "SELECT sha256 FROM documents LIMIT 1;"
        ) { $0.string(at: 0) ?? "" }
        #expect(legacyDigest == [prepared.fingerprint.digest])

        #expect(try memory.importSessionRepo.priorImportedStatement(
            algorithm: prepared.fingerprint.algorithm,
            fingerprint: prepared.fingerprint.digest
        )?.importSessionId == memoryPlan.historyTemplate.importSession.id)
        let source = try #require(prepared.fingerprintSet.fingerprints.first {
            $0.algorithm == SourceContentSnapshot.algorithm
        })
        #expect(try memory.importSessionRepo.priorImportedStatement(
            algorithm: source.algorithm,
            fingerprint: source.digest
        ) == nil)
    }

    private func mappedPlan(
        _ prepared: PreparedImport,
        generation: ProviderGenerationToken
    ) throws -> ConfirmedImportPlanDTO {
        try ImportPersistenceMapper().confirmedImportPlan(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            fingerprintSet: prepared.fingerprintSet,
            providerGeneration: generation,
            advisoryIdentity: .noMatch,
            accountChoice: .createProposedAccount,
            selectedAccountId: "snapshot-binding-account"
        )
    }
}

private final class BindingPreparationPersistence: ImportPersistenceCoordinating {
    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult { .skipped }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult { .skipped }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? { nil }
}
