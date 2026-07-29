import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct ImportLifecycleTests {

    @Test(.globalRuntimeStateIsolation)
    func approvedAxisPreparationEmitsOrderedNamedStagesWithoutSourceEvidence() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let engine = ImportEngine(
            importPersistenceCoordinator: PreparationOnlyPersistenceCoordinator(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) }
        )
        let requestID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        var progress: [ImportProgress] = []

        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv"),
            requestId: requestID
        ) { progress.append($0) }
        defer { engine.cancelPreparedImport(prepared) }

        #expect(prepared.validation.passed)
        #expect(progress.map(\.requestId) == Array(repeating: requestID, count: 7))
        #expect(progress.map(\.phase) == [
            .openingSource,
            .detectingInstitution,
            .classifyingStatement,
            .selectingParser,
            .parsingFinancialContent,
            .validatingPreparedContent,
            .preparingConfirmationPreview
        ])
        #expect(progress.allSatisfy { $0.completedUnitCount == 0 && $0.totalUnitCount == 0 })

        let presentedProgress = progress.map { $0.phase.userFacingTitle }.joined(separator: "|")
        for prohibited in ["axis_bank_nre", "Account No", "UPI", "private"] {
            #expect(!presentedProgress.localizedCaseInsensitiveContains(prohibited))
        }
    }

    @Test func taskOwnerSupersedesReleasesAndCancelsOnlyTheCurrentPreparation() async {
        let owner = ImportPreparationTaskOwner()
        let probe = ImportLifecycleCancellationProbe()

        let firstID = owner.start { _ in
            await probe.markFirstOperationReadyToObserveCancellation()
            do {
                try await Task.sleep(for: .seconds(10))
            } catch is CancellationError {
                await probe.markFirstCancellationObserved()
            } catch {
                Issue.record("Unexpected preparation task error: \(error.localizedDescription)")
            }
        }
        await probe.waitForFirstOperationToBeReady()

        let secondID = owner.start { _ in }
        await probe.waitForFirstCancellation()

        #expect(firstID != secondID)
        #expect(!owner.isCurrent(firstID))
        #expect(owner.isCurrent(secondID))

        owner.finish(firstID)
        #expect(owner.isCurrent(secondID))

        owner.finish(secondID)
        #expect(owner.activeOperationID == nil)

        owner.cancel()
        owner.cancel()
        #expect(owner.activeOperationID == nil)
    }

    @Test(.globalRuntimeStateIsolation)
    func preparedSourceSupersessionConsumesOnlyTheOldSnapshotWithoutRecordingRejection() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let persistence = SupersessionPersistenceProbe()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { ProviderGenerationToken() },
            forcedHydration: {
                RepositoryStoreHydrationResult(didHydrate: true, accountCount: 0, transactionCount: 0)
            },
            rejectedAttemptHydration: {}
        )
        let source = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")

        let sourceA = try await engine.prepareImport(from: source)
        engine.cancelPreparedImport(sourceA)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try sourceA.sourceSnapshot.withBytes { $0 }
        }

        let sourceB = try await engine.prepareImport(from: source)
        let supersededResult = await engine.commitPreparedImport(sourceA)

        #expect(supersededResult.errorMessage == ImportEngineCommitError.alreadyCommitted.localizedDescription)
        #expect(persistence.persistInvocationCount == 0)
        #expect(persistence.rejectionInvocationCount == 0)
        #expect(try sourceB.sourceSnapshot.withBytes { !$0.isEmpty })

        let replacementResult = await engine.commitPreparedImport(sourceB)

        #expect(replacementResult.persisted)
        #expect(persistence.persistInvocationCount == 1)
        #expect(persistence.rejectionInvocationCount == 0)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try sourceB.sourceSnapshot.withBytes { $0 }
        }
    }

#if DEBUG
    @Test(.globalRuntimeStateIsolation)
    func directPreparationRequiresAcknowledgementBeforeSourceAcquisition() async {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let generation = ProviderGenerationToken()
        let state = DevelopmentProfileAcknowledgementState(
            providerGeneration: generation,
            profileKind: .persistentDebug
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        var acquisitionCount = 0
        let engine = ImportEngine(
            sourceSnapshotAcquirer: { _ in
                acquisitionCount += 1
                throw SourceContentSnapshotError.acquisitionFailed
            },
            importPersistenceCoordinator: PreparationOnlyPersistenceCoordinator(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { generation },
            developmentProfileAcknowledgementGate: gate
        )

        do {
            _ = try await engine.prepareImport(from: URL(fileURLWithPath: "/not-opened.csv"))
            Issue.record("Expected acknowledgement requirement")
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired {
            // Expected typed, pre-I/O result.
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }

        #expect(acquisitionCount == 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func directConfirmationRequiresFreshGenerationAcknowledgementWithoutConsumingPreview() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let firstGeneration = ProviderGenerationToken()
        var currentGeneration = firstGeneration
        var state = DevelopmentProfileAcknowledgementState(
            providerGeneration: firstGeneration,
            profileKind: .current
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        let persistence = SupersessionPersistenceProbe()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { currentGeneration },
            developmentProfileAcknowledgementGate: gate
        )
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        defer { engine.cancelPreparedImport(prepared) }

        let secondGeneration = ProviderGenerationToken()
        currentGeneration = secondGeneration
        state = DevelopmentProfileAcknowledgementState(
            providerGeneration: secondGeneration,
            profileKind: .temporarySession
        )

        let result = await engine.commitPreparedImport(prepared)

        #expect(result.developmentProtectedActionOutcome == .acknowledgementRequired)
        #expect(!result.persisted)
        #expect(persistence.persistInvocationCount == 0)
        #expect(try prepared.sourceSnapshot.withBytes { !$0.isEmpty })
    }

    @Test(.globalRuntimeStateIsolation)
    func profileSwitchInvalidationConsumesPreparedImportBeforeProviderUseWithoutAuditWrite() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let persistence = SupersessionPersistenceProbe()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { DatabaseProvider.shared.generationToken },
            forcedHydration: {
                RepositoryStoreHydrationResult(didHydrate: true, accountCount: 0, transactionCount: 0)
            },
            rejectedAttemptHydration: {}
        )
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )

        let barrier = DevelopmentDatabaseActivityGate.shared.beginProfileSwitch {
            engine.invalidatePreparedImportsForProfileSwitch($0)
        }
        guard case .acquired(let invalidation) = barrier else {
            Issue.record("Expected prepared import to drain into exclusive ownership")
            return
        }
        defer { DevelopmentDatabaseActivityGate.shared.finishExclusive(providerChanged: false) }

        #expect(invalidation.invalidatedCount == 1)
        #expect(!DevelopmentDatabaseActivityGate.shared.hasActiveOperations)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
        #expect(throws: DevelopmentDatabaseActivityError.self) {
            _ = try DevelopmentDatabaseActivityGate.shared.begin(.repositoryWrite)
        }

        let result = await engine.commitPreparedImport(prepared)

        #expect(result.errorMessage == ImportEngineCommitError.alreadyCommitted.localizedDescription)
        #expect(!result.persisted)
        #expect(persistence.persistInvocationCount == 0)
        #expect(persistence.rejectionInvocationCount == 0)
    }
#endif
}

private actor ImportLifecycleCancellationProbe {
    private var firstOperationReady = false
    private var firstCancellationObserved = false
    private var firstOperationReadyContinuation: CheckedContinuation<Void, Never>?
    private var firstCancellationContinuation: CheckedContinuation<Void, Never>?

    func markFirstOperationReadyToObserveCancellation() {
        firstOperationReady = true
        firstOperationReadyContinuation?.resume()
        firstOperationReadyContinuation = nil
    }

    func waitForFirstOperationToBeReady() async {
        guard !firstOperationReady else { return }
        await withCheckedContinuation { continuation in
            firstOperationReadyContinuation = continuation
        }
    }

    func markFirstCancellationObserved() {
        firstCancellationObserved = true
        firstCancellationContinuation?.resume()
        firstCancellationContinuation = nil
    }

    func waitForFirstCancellation() async {
        guard !firstCancellationObserved else { return }
        await withCheckedContinuation { continuation in
            firstCancellationContinuation = continuation
        }
    }
}

private final class PreparationOnlyPersistenceCoordinator: ImportPersistenceCoordinating {
    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        nil
    }
}

private final class SupersessionPersistenceProbe: ImportPersistenceCoordinating {
    private(set) var persistInvocationCount = 0
    private(set) var rejectionInvocationCount = 0

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        persistInvocationCount += 1
        return ImportPersistenceResult(
            persisted: true,
            workspaceId: "workspace",
            accountId: "account",
            importSessionId: importSession.id.uuidString,
            transactionCount: financialDocument.transactions.count
        )
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        nil
    }

    func recordSourceSnapshotRejection(_ kind: SourceSnapshotRejectionKind) -> SourceSnapshotRejectionRecord {
        rejectionInvocationCount += 1
        return .auditWriteUnavailable
    }
}
