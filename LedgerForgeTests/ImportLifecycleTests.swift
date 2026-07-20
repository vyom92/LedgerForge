import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct ImportLifecycleTests {

    @Test func approvedAxisPreparationEmitsOrderedNamedStagesWithoutSourceEvidence() async throws {
        let engine = ImportEngine(importPersistenceCoordinator: PreparationOnlyPersistenceCoordinator())
        let requestID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        var progress: [ImportProgress] = []

        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv"),
            requestId: requestID
        ) { progress.append($0) }

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
