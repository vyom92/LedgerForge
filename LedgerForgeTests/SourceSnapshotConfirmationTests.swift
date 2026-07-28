import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct SourceSnapshotConfirmationTests {
    @Test(.globalRuntimeStateIsolation)
    func preparationRetainsSnapshotAndConfirmationDoesNotRereadDeletedURL() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let source = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-snapshot-delete-\(UUID().uuidString).csv")
        try FileManager.default.copyItem(at: source, to: temporaryURL)
        let persistence = ConfirmationPersistenceProbe()
        let engine = confirmationEngine(persistence: persistence)

        let prepared = try await engine.prepareImport(from: temporaryURL)
        #expect(try prepared.sourceSnapshot.withBytes { !$0.isEmpty })
        try FileManager.default.removeItem(at: temporaryURL)

        let result = await engine.commitPreparedImport(prepared)
        let repeated = await engine.commitPreparedImport(prepared)

        #expect(result.persisted)
        #expect(repeated.errorMessage == ImportEngineCommitError.alreadyCommitted.localizedDescription)
        #expect(persistence.persistInvocationCount == 1)
        #expect(persistence.lastFingerprintSet == prepared.fingerprintSet)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func sourceURLMutationAfterPreparationDoesNotAffectConfirmation() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let source = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-snapshot-mutate-\(UUID().uuidString).csv")
        try FileManager.default.copyItem(at: source, to: temporaryURL)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        let persistence = ConfirmationPersistenceProbe()
        let engine = confirmationEngine(persistence: persistence)

        let prepared = try await engine.prepareImport(from: temporaryURL)
        try Data("changed after preparation".utf8).write(to: temporaryURL)
        let result = await engine.commitPreparedImport(prepared)

        #expect(result.persisted)
        #expect(persistence.persistInvocationCount == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func concurrentConfirmationsOfSamePreparationAllowExactlyOneConsumer() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let persistence = ConfirmationPersistenceProbe()
        let engine = confirmationEngine(persistence: persistence)
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        let context = ConcurrentConfirmationContext(engine: engine, prepared: prepared)
        let startGate = ConcurrentConfirmationStartGate(participantCount: 2)

        let firstTask = Task.detached {
            await startGate.arriveAndWait()
            let result = await context.engine.commitPreparedImport(context.prepared)
            return ConfirmationTaskObservation(result)
        }
        let secondTask = Task.detached {
            await startGate.arriveAndWait()
            let result = await context.engine.commitPreparedImport(context.prepared)
            return ConfirmationTaskObservation(result)
        }

        let firstObservation = await firstTask.value
        let secondObservation = await secondTask.value
        let observations = [firstObservation, secondObservation]
        let arrivalCount = await startGate.arrivalCount
        let returnedErrors = observations.compactMap(\.errorMessage).joined(separator: "|")
        let prohibitedEvidence = prepared.fingerprintSet.fingerprints.map(\.digest) + [
            prepared.sourceURL.path,
            prepared.fileName,
            prepared.sourceSnapshot.id.uuidString
        ]

        #expect(arrivalCount == 2)
        #expect(persistence.persistInvocationCount == 1)
        #expect(persistence.acceptedGraphCount == 1)
        #expect(observations.filter { $0.persisted }.count == 1)
        #expect(observations.filter {
            $0.errorMessage == ImportEngineCommitError.alreadyCommitted.localizedDescription
        }.count == 1)
        for evidence in prohibitedEvidence where !evidence.isEmpty {
            #expect(!returnedErrors.contains(evidence))
        }
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func invalidatedSnapshotRejectsBeforeProviderAndConsumesPreparation() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let persistence = ConfirmationPersistenceProbe()
        let engine = confirmationEngine(persistence: persistence)
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        prepared.sourceSnapshot.invalidate()

        let first = await engine.commitPreparedImport(prepared)
        let second = await engine.commitPreparedImport(prepared)

        #expect(first.errorMessage == ImportEngineCommitError.sourceSnapshotIntegrityFailed.localizedDescription)
        #expect(first.importAttemptId == ConfirmationPersistenceProbe.integrityAttemptID)
        #expect(second.errorMessage == ImportEngineCommitError.alreadyCommitted.localizedDescription)
        #expect(persistence.persistInvocationCount == 0)
        #expect(persistence.integrityRejectionCount == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func rawTextMutationAndAlteredAuthorityRejectBeforeProvider() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let source = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")

        let rawPersistence = ConfirmationPersistenceProbe()
        let rawEngine = confirmationEngine(persistence: rawPersistence)
        let original = try await rawEngine.prepareImport(from: source)
        let rawMutated = copy(
            original,
            rawContents: original.rawContents + "\nmutated",
            fingerprintSet: original.fingerprintSet
        )
        let rawResult = await rawEngine.commitPreparedImport(rawMutated)
        #expect(rawResult.errorMessage == ImportEngineCommitError.sourceSnapshotIntegrityFailed.localizedDescription)
        #expect(rawPersistence.persistInvocationCount == 0)

        let authorityPersistence = ConfirmationPersistenceProbe()
        let authorityEngine = confirmationEngine(persistence: authorityPersistence)
        let prepared = try await authorityEngine.prepareImport(from: source)
        let altered = PreparedDocumentFingerprintSet(
            fingerprints: prepared.fingerprintSet.fingerprints.map {
                VersionedDocumentFingerprint(
                    algorithm: $0.algorithm,
                    digest: $0.digest,
                    byteCount: $0.byteCount,
                    isDuplicateAuthority: $0.algorithm == SourceContentSnapshot.algorithm
                )
            }
        )
        let alteredPrepared = copy(prepared, fingerprintSet: altered)
        let alteredResult = await authorityEngine.commitPreparedImport(alteredPrepared)
        #expect(alteredResult.errorMessage == ImportEngineCommitError.sourceSnapshotIntegrityFailed.localizedDescription)
        #expect(authorityPersistence.persistInvocationCount == 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func previewCancellationAndHydrationFailureBothInvalidate() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let source = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")

        let cancelledPersistence = ConfirmationPersistenceProbe()
        let cancelledEngine = confirmationEngine(persistence: cancelledPersistence)
        let cancelled = try await cancelledEngine.prepareImport(from: source)
        cancelledEngine.cancelPreparedImport(cancelled)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try cancelled.sourceSnapshot.withBytes { $0 }
        }
        let cancelledConfirmation = await cancelledEngine.commitPreparedImport(cancelled)
        #expect(cancelledConfirmation.errorMessage == ImportEngineCommitError.alreadyCommitted.localizedDescription)
        #expect(cancelledPersistence.persistInvocationCount == 0)

        let hydrationPersistence = ConfirmationPersistenceProbe()
        let hydrationEngine = confirmationEngine(
            persistence: hydrationPersistence,
            forcedHydration: { throw ConfirmationProbeError.hydrationFailed }
        )
        let hydrationFailure = try await hydrationEngine.prepareImport(from: source)
        let result = await hydrationEngine.commitPreparedImport(hydrationFailure)
        #expect(result.persisted)
        #expect(result.hydrationOutcome == .committedReconciliationRequired)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try hydrationFailure.sourceSnapshot.withBytes { $0 }
        }
    }

    private func copy(
        _ prepared: PreparedImport,
        rawContents: String? = nil,
        fingerprintSet: PreparedDocumentFingerprintSet? = nil
    ) -> PreparedImport {
        PreparedImport(
            id: prepared.id,
            sourceURL: prepared.sourceURL,
            rawContents: rawContents ?? prepared.rawContents,
            fileName: prepared.fileName,
            detectedInstitution: prepared.detectedInstitution,
            detectedDocumentType: prepared.detectedDocumentType,
            parserName: prepared.parserName,
            financialDocument: prepared.financialDocument,
            validation: prepared.validation,
            importSession: prepared.importSession,
            fingerprint: prepared.fingerprint,
            sourceSnapshot: prepared.sourceSnapshot,
            fingerprintSet: fingerprintSet ?? prepared.fingerprintSet,
            advisoryPreviousImport: prepared.advisoryPreviousImport,
            providerGeneration: prepared.providerGeneration
        )
    }
}

private enum ConfirmationProbeError: Error { case hydrationFailed }

private final class ConfirmationPersistenceProbe: @unchecked Sendable, ImportPersistenceCoordinating {
    static let integrityAttemptID = "snapshot-integrity-attempt"
    private let lock = NSLock()
    private var storedPersistInvocationCount = 0
    private var storedAcceptedGraphCount = 0
    private var storedIntegrityRejectionCount = 0
    private var storedLastFingerprintSet: PreparedDocumentFingerprintSet?

    var persistInvocationCount: Int { withLock { storedPersistInvocationCount } }
    var acceptedGraphCount: Int { withLock { storedAcceptedGraphCount } }
    var integrityRejectionCount: Int { withLock { storedIntegrityRejectionCount } }
    var lastFingerprintSet: PreparedDocumentFingerprintSet? { withLock { storedLastFingerprintSet } }

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

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        withLock {
            storedPersistInvocationCount += 1
            storedAcceptedGraphCount += 1
            storedLastFingerprintSet = fingerprintSet
        }
        return ImportPersistenceResult(
            persisted: true,
            workspaceId: "workspace",
            accountId: "account",
            importSessionId: importSession.id.uuidString,
            transactionCount: financialDocument.transactions.count
        )
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? { nil }

    func recordSourceSnapshotRejection(_ kind: SourceSnapshotRejectionKind) -> SourceSnapshotRejectionRecord {
        guard kind == .integrityFailed else { return .auditWriteUnavailable }
        withLock {
            storedIntegrityRejectionCount += 1
        }
        return SourceSnapshotRejectionRecord(
            importAttemptId: Self.integrityAttemptID,
            persistence: .rejectedRecorded
        )
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class ConcurrentConfirmationContext: @unchecked Sendable {
    let engine: ImportEngine
    let prepared: PreparedImport

    init(engine: ImportEngine, prepared: PreparedImport) {
        self.engine = engine
        self.prepared = prepared
    }
}

private struct ConfirmationTaskObservation: Sendable {
    let persisted: Bool
    let errorMessage: String?

    init(_ result: ImportEngineResult) {
        persisted = result.persisted
        errorMessage = result.errorMessage
    }
}

private actor ConcurrentConfirmationStartGate {
    let participantCount: Int
    private var arrivals = 0
    private var continuations: [CheckedContinuation<Void, Never>] = []

    init(participantCount: Int) {
        self.participantCount = participantCount
    }

    var arrivalCount: Int { arrivals }

    func arriveAndWait() async {
        await withCheckedContinuation { continuation in
            arrivals += 1
            continuations.append(continuation)
            guard arrivals == participantCount else { return }
            let waiting = continuations
            continuations.removeAll()
            for continuation in waiting {
                continuation.resume()
            }
        }
    }
}

private func confirmationEngine(
    persistence: ImportPersistenceCoordinating,
    forcedHydration: @escaping () throws -> RepositoryStoreHydrationResult = {
        RepositoryStoreHydrationResult(didHydrate: true, accountCount: 0, transactionCount: 0)
    }
) -> ImportEngine {
    ImportEngine(
        importPersistenceCoordinator: persistence,
        developerConsole: DeveloperConsole(),
        persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
        providerGenerationProvider: { ProviderGenerationToken() },
        forcedHydration: forcedHydration,
        rejectedAttemptHydration: {}
    )
}
