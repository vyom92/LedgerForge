import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct SourceSnapshotRejectionTests {
    @Test(.globalRuntimeStateIsolation)
    func acquisitionFailureRecordsBoundedAttemptAndLeavesZeroAcceptedResidue() async throws {
        let setup = try rejectionSetup(name: "acquisition")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let console = DeveloperConsole()
        let coordinator = RejectionReaderProbe()
        let engine = ImportEngine(
            importCoordinator: coordinator,
            sourceSnapshotAcquirer: { _ in throw RejectionProbeError.acquisition },
            importPersistenceCoordinator: setup.persistence,
            developerConsole: console,
            persistenceStateProvider: { setup.provider.persistenceState },
            providerGenerationProvider: { setup.provider.generationToken },
            rejectedAttemptHydration: {}
        )
        let privateURL = URL(fileURLWithPath: "/private/source/must-not-appear.csv")

        await #expect(throws: SourceContentSnapshotError.acquisitionFailed) {
            try await engine.prepareImport(from: privateURL)
        }

        let attempt = try #require(setup.provider.importSessionRepo.importAttempts(workspaceId: "default-workspace").only)
        assertSnapshotAttempt(attempt, outcome: .sourceSnapshotAcquisitionFailed)
        #expect(coordinator.invocationCount == 0)
        #expect(!SourceContentSnapshotError.acquisitionFailed.localizedDescription.contains(privateURL.path))
        let diagnostics = console.entries.flatMap { entry in
            [entry.message] + (entry.metadata?.flatMap { [$0.key, $0.value] } ?? [])
        }.joined(separator: "|")
        #expect(!diagnostics.contains(privateURL.path))
        #expect(!diagnostics.contains(privateURL.lastPathComponent))
        try assertZeroAcceptedResidue(setup.sqlite.database)
    }

    @Test(.globalRuntimeStateIsolation)
    func integrityFailureRecordsBoundedAttemptBeforeProviderAndLeavesZeroAcceptedResidue() async throws {
        let setup = try rejectionSetup(name: "integrity")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let engine = ImportEngine(
            importPersistenceCoordinator: setup.persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { setup.provider.persistenceState },
            providerGenerationProvider: { setup.provider.generationToken },
            rejectedAttemptHydration: {}
        )
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        prepared.sourceSnapshot.invalidate()

        let result = await engine.commitPreparedImport(prepared)

        #expect(result.errorMessage == ImportEngineCommitError.sourceSnapshotIntegrityFailed.localizedDescription)
        let attempt = try #require(setup.provider.importSessionRepo.importAttempts(workspaceId: "default-workspace").only)
        assertSnapshotAttempt(attempt, outcome: .sourceSnapshotIntegrityFailed)
        #expect(result.importAttemptId == attempt.id)
        #expect(!result.errorMessage!.contains(prepared.fingerprint.digest))
        #expect(!result.errorMessage!.contains(prepared.sourceURL.path))
        try assertZeroAcceptedResidue(setup.sqlite.database)
    }

    @Test(.globalRuntimeStateIsolation)
    func cancellationWritesNoRejectionAndAuditWriteFailureIsBounded() async throws {
        let setup = try rejectionSetup(name: "cancel")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let engine = ImportEngine(
            importPersistenceCoordinator: setup.persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { setup.provider.persistenceState },
            providerGenerationProvider: { setup.provider.generationToken },
            rejectedAttemptHydration: {}
        )
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        engine.cancelPreparedImport(prepared)

        #expect(try setup.provider.importSessionRepo.importAttempts(workspaceId: "default-workspace").isEmpty)
        try assertZeroAcceptedResidue(setup.sqlite.database)

        let providerWithoutWorkspace = DatabaseProvider(inMemory: true)
        let unavailable = DefaultImportPersistenceCoordinator(
            databaseProviderProvider: { providerWithoutWorkspace },
            mapper: ImportPersistenceMapper(),
            developerConsole: nil
        ).recordSourceSnapshotRejection(.integrityFailed)
        #expect(unavailable == .auditWriteUnavailable)
    }
}

private enum RejectionProbeError: Error { case acquisition }

private final class RejectionReaderProbe: ImportFramework.ImportCoordinator, @unchecked Sendable {
    private(set) var invocationCount = 0
    func importDocument(_ request: ImportRequest, snapshot: SourceContentSnapshot) async -> ImportResult {
        invocationCount += 1
        return .failure(request: request, error: .readerFailure(message: "Unexpected reader invocation."))
    }
}

private func rejectionSetup(name: String) throws -> (
    sqlite: SQLiteRepositoryProvider,
    provider: DatabaseProvider,
    persistence: DefaultImportPersistenceCoordinator,
    folder: URL
) {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForge-Packet3-Rejection-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let sqlite = try SQLiteRepositoryProvider(
        path: folder.appendingPathComponent("provider.sqlite").path,
        migrations: allMigrations
    )
    let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
    _ = try provider.workspaceRepo.upsertWorkspace(
        WorkspaceDTO(
            id: "default-workspace",
            name: "Default Workspace",
            createdAtISO: "2027-03-13T00:00:00Z"
        )
    )
    return (
        sqlite,
        provider,
        DefaultImportPersistenceCoordinator(
            databaseProviderProvider: { provider },
            mapper: ImportPersistenceMapper(),
            developerConsole: nil
        ),
        folder
    )
}

private func assertSnapshotAttempt(_ attempt: ImportAttemptDTO, outcome: ImportAttemptOutcome) {
    #expect(attempt.outcomeCode == outcome.rawValue)
    #expect(attempt.coverageCode == ImportAttemptCoverage.unsupportedOrUnevaluated.rawValue)
    #expect(attempt.accountDecisionCode == ImportAttemptAccountDecision.noFinancialMutation.rawValue)
    #expect(attempt.guidanceCode == ImportAttemptGuidance.prepareAgain.rawValue)
    #expect(attempt.persistenceCode == ImportAttemptPersistence.rejectedRecorded.rawValue)
    #expect(attempt.transactionCount == 0)
    #expect(attempt.accountId == nil)
    #expect(attempt.importSessionId == nil)
    #expect(attempt.documentId == nil)
}

private func assertZeroAcceptedResidue(_ database: SQLiteDatabase) throws {
    for table in ["accounts", "documents", "document_fingerprints", "import_sessions", "transactions"] {
        #expect(try database.queryInt("SELECT COUNT(*) FROM \(table);") == 0)
    }
}

private extension Collection {
    var only: Element? { count == 1 ? first : nil }
}
