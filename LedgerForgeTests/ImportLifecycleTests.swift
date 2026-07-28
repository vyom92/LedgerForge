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
