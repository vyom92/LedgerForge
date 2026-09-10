import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct ImportCentreCoordinatorTests {
    @Test func intakeIsSingleItemOrderedAndRejectsOverlapUntilCancelledTaskDrains() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsPreparation = true
        let coordinator = makeCoordinator(probe)
        let firstURL = URL(fileURLWithPath: "/tmp/opaque-mechanics-a")

        #expect(coordinator.selectSource(firstURL))
        await waitUntil { probe.prepareCallCount == 1 }
        let itemID = coordinator.currentItem?.id
        let operationID = coordinator.currentItem?.preparationOperationID

        #expect(coordinator.items.count == 1)
        #expect(coordinator.currentItem?.queuePosition == 0)
        #expect(coordinator.currentItem?.sourceURL == firstURL)
        #expect(!coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-mechanics-b")))
        #expect(probe.maximumConcurrentPreparationCount == 1)

        probe.emitProgress(requestID: UUID(), phase: .selectingParser)
        await Task.yield()
        #expect(coordinator.currentItem?.progress.phase == .openingSource)

        if let operationID {
            probe.emitProgress(requestID: operationID, phase: .selectingParser)
        }
        await waitUntil { coordinator.currentItem?.progress.phase == .selectingParser }
        #expect(coordinator.currentItem?.id == itemID)

        coordinator.cancelCurrent()
        #expect(coordinator.currentItem?.phase == .cancelled)
        #expect(coordinator.currentItem?.preparation == nil)
        #expect(coordinator.currentItem?.outcome == nil)
        #expect(coordinator.isPreparationDraining)
        #expect(!coordinator.permitsSourceSelection)
        #expect(probe.passwordCancellationCount == 1)

        let latePreparation = OpaqueImportCentrePreparation()
        probe.resumeNextPreparation(with: latePreparation)
        await waitUntil { !coordinator.isPreparationDraining }

        #expect(probe.cancelledPreparationIDs == [latePreparation.id])
        #expect(coordinator.currentItem?.phase == .cancelled)
        #expect(probe.maximumConcurrentPreparationCount == 1)

        probe.suspendsPreparation = false
        #expect(coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-mechanics-b")))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        #expect(probe.maximumConcurrentPreparationCount == 1)
        let previewPreparationID = coordinator.currentItem?.preparation?.id
        coordinator.cancelCurrent()
        #expect(coordinator.currentItem?.phase == .cancelled)
        #expect(probe.cancelledPreparationIDs.last == previewPreparationID)
    }

    @Test func resetRejectsReplacementUntilLateCompletionIsDisposed() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsPreparation = true
        let coordinator = makeCoordinator(probe)

        #expect(coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-reset-a")))
        await waitUntil { probe.prepareCallCount == 1 }
        let staleProgress = probe.lastProgressCallback
        let staleOperationID = probe.lastOperationID

        #expect(coordinator.reset())
        #expect(coordinator.items.isEmpty)
        #expect(coordinator.isPreparationDraining)
        #expect(!coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-reset-b")))

        staleProgress?(
            ImportProgress(
                requestId: probe.lastOperationID ?? UUID(),
                phase: .validatingPreparedContent,
                completedUnitCount: 0,
                totalUnitCount: 0
            )
        )
        await Task.yield()
        #expect(coordinator.items.isEmpty)

        let stalePreparation = OpaqueImportCentrePreparation()
        probe.resumeNextPreparation(with: stalePreparation)
        await waitUntil { !coordinator.isPreparationDraining }
        #expect(probe.cancelledPreparationIDs == [stalePreparation.id])

        #expect(coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-reset-b")))
        await waitUntil { probe.prepareCallCount == 2 }
        let replacementID = coordinator.currentItem?.id
        staleProgress?(
            ImportProgress(
                requestId: staleOperationID ?? UUID(),
                phase: .validatingPreparedContent,
                completedUnitCount: 0,
                totalUnitCount: 0
            )
        )
        await Task.yield()
        #expect(coordinator.currentItem?.id == replacementID)
        #expect(coordinator.currentItem?.progress.phase == .openingSource)

        probe.resumeNextPreparation(with: OpaqueImportCentrePreparation())
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        #expect(coordinator.currentItem?.sourceURL.lastPathComponent == "opaque-reset-b")
        coordinator.cancelCurrent()
    }

    @Test func sameFilenameSelectionsReceiveFreshIdentityAndPerItemReviewState() async {
        let probe = ImportCentreWorkflowProbe()
        let coordinator = makeCoordinator(probe)
        let firstURL = URL(fileURLWithPath: "/tmp/first/shared-name")
        let secondURL = URL(fileURLWithPath: "/tmp/second/shared-name")

        #expect(coordinator.selectSource(firstURL))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let firstItemID = coordinator.currentItem?.id
        let firstPreparationID = coordinator.currentItem?.preparation?.id
        coordinator.updateAccountChoice(.createNewAccount)
        #expect(coordinator.currentItem?.accountChoice == .createNewAccount)

        #expect(coordinator.selectSource(secondURL))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }

        #expect(coordinator.currentItem?.displayFileName == "shared-name")
        #expect(coordinator.currentItem?.id != firstItemID)
        #expect(coordinator.currentItem?.sourceURL == secondURL)
        #expect(coordinator.currentItem?.queuePosition == 0)
        #expect(coordinator.currentItem?.accountChoice == nil)
        #expect(coordinator.currentItem?.cardSectionDraftAccountID == nil)
        #expect(coordinator.currentItem?.cardSectionDraftChoices.isEmpty == true)
        #expect(coordinator.currentItem?.partialReview == .ordinaryFullImport)
        #expect(coordinator.currentItem?.outcome == nil)
        #expect(coordinator.currentItem?.recoveryContext == nil)
        #expect(probe.cancelledPreparationIDs == [firstPreparationID].compactMap { $0 })
        coordinator.cancelCurrent()
    }

    @Test func previewRequiresExplicitMatchingConfirmationAndCommitsOnlyOnce() async {
        let probe = ImportCentreWorkflowProbe()
        let coordinator = makeCoordinator(probe)
        let sourceURL = URL(fileURLWithPath: "/tmp/opaque-confirm")

        #expect(coordinator.selectSource(sourceURL))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let preparationID = coordinator.currentItem?.preparation?.id

        #expect(probe.commitCallCount == 0)
        await coordinator.confirmCurrent(expectedPreparationID: UUID())
        #expect(probe.commitCallCount == 0)

        await coordinator.confirmCurrent(expectedPreparationID: preparationID)
        #expect(probe.commitCallCount == 1)
        #expect(coordinator.currentItem?.phase == .completed)
        #expect(coordinator.currentItem?.outcome?.fileName == sourceURL.lastPathComponent)

        await coordinator.confirmCurrent(expectedPreparationID: preparationID)
        #expect(probe.commitCallCount == 1)
        #expect(probe.cancelledPreparationIDs.isEmpty)
    }

    @Test func pickerFailureCannotEraseAnotherPresentationOwnersPreviewOrOutcome() async {
        let probe = ImportCentreWorkflowProbe()
        let coordinator = makeCoordinator(probe)

        #expect(coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-picker-owner")))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let itemID = coordinator.currentItem?.id
        let preparationID = coordinator.currentItem?.preparation?.id

        coordinator.recordSelectionFailure(ImportError.unknown(message: "opaque picker failure"))
        #expect(coordinator.currentItem?.id == itemID)
        #expect(coordinator.currentItem?.phase == .awaitingConfirmation)
        #expect(coordinator.currentItem?.preparation?.id == preparationID)
        #expect(coordinator.selectionFailureMessage == nil)
        #expect(probe.cancelledPreparationIDs.isEmpty)

        await coordinator.confirmCurrent(expectedPreparationID: preparationID)
        let outcome = coordinator.currentItem?.outcome
        coordinator.recordSelectionFailure(ImportError.unknown(message: "opaque picker failure"))

        #expect(coordinator.currentItem?.id == itemID)
        #expect(coordinator.currentItem?.phase == .completed)
        #expect(coordinator.currentItem?.outcome == outcome)
        #expect(coordinator.selectionFailureMessage == nil)
    }

    @Test func committingDisablesCancellationSelectionAndRepeatedConfirmation() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsCommit = true
        let coordinator = makeCoordinator(probe)

        #expect(coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-commit")))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let preparationID = coordinator.currentItem?.preparation?.id

        let confirmation = Task {
            await coordinator.confirmCurrent(expectedPreparationID: preparationID)
        }
        await waitUntil { probe.commitCallCount == 1 }

        #expect(coordinator.currentItem?.phase == .committing)
        #expect(!coordinator.permitsCancellation)
        coordinator.cancelCurrent()
        #expect(coordinator.currentItem?.phase == .committing)
        #expect(!coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-overlap")))
        await coordinator.confirmCurrent(expectedPreparationID: preparationID)
        #expect(probe.commitCallCount == 1)

        probe.resumeCommit()
        await confirmation.value
        #expect(coordinator.currentItem?.phase == .completed)
        #expect(probe.commitCallCount == 1)
    }

    @Test func previewIsDisposedOnlyWhenLastPresentationOwnerDetaches() async {
        let probe = ImportCentreWorkflowProbe()
        let coordinator = makeCoordinator(probe)
        let firstOwner = UUID()
        let secondOwner = UUID()
        coordinator.attachPresentationOwner(firstOwner)
        coordinator.attachPresentationOwner(secondOwner)

        #expect(coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-window")))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let preparationID = coordinator.currentItem?.preparation?.id

        coordinator.detachPresentationOwner(firstOwner)
        #expect(coordinator.presentationOwnerCount == 1)
        #expect(coordinator.currentItem?.phase == .awaitingConfirmation)
        #expect(probe.cancelledPreparationIDs.isEmpty)

        coordinator.detachPresentationOwner(secondOwner)
        #expect(coordinator.presentationOwnerCount == 0)
        #expect(coordinator.items.isEmpty)
        #expect(probe.cancelledPreparationIDs == [preparationID].compactMap { $0 })
    }

    @Test func lastOwnerCancellationKeepsSerialSlotUntilPreparationDrains() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsPreparation = true
        let coordinator = makeCoordinator(probe)
        let owner = UUID()
        coordinator.attachPresentationOwner(owner)

        #expect(coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-window-drain")))
        await waitUntil { probe.prepareCallCount == 1 }
        coordinator.detachPresentationOwner(owner)

        #expect(coordinator.items.isEmpty)
        #expect(coordinator.isPreparationDraining)
        #expect(probe.passwordCancellationCount == 1)
        #expect(!coordinator.selectSource(URL(fileURLWithPath: "/tmp/opaque-window-new")))

        let latePreparation = OpaqueImportCentrePreparation()
        probe.resumeNextPreparation(with: latePreparation)
        await waitUntil { !coordinator.isPreparationDraining }
        #expect(probe.cancelledPreparationIDs == [latePreparation.id])
    }

    @Test func preparationFailureStaysWithItsItemAndExposesOnlyEligibleRetry() async {
        let probe = ImportCentreWorkflowProbe()
        probe.nextPreparationError = ImportError.readerFailure(message: "opaque mechanics failure")
        let coordinator = makeCoordinator(probe)
        let sourceURL = URL(fileURLWithPath: "/tmp/opaque-failure")

        #expect(coordinator.selectSource(sourceURL))
        await waitUntil { coordinator.currentItem?.phase == .failed }

        #expect(coordinator.items.count == 1)
        #expect(coordinator.currentItem?.sourceURL == sourceURL)
        #expect(coordinator.currentItem?.retrySourceURL == sourceURL)
        #expect(coordinator.currentItem?.preparation == nil)
        #expect(coordinator.currentItem?.failureMessage == "Opaque preparation failed. Retry the isolated mechanics operation.")
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticSourceUsesProductionCoordinatorRouteAndSnapshotEndsAtConfirmation() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let coordinator = ImportCentreCoordinator<PreparedImport>.production()
        let owner = UUID()
        coordinator.attachPresentationOwner(owner)
        defer { coordinator.detachPresentationOwner(owner) }
        let sourceURL = try AuthenticSourceTestSupport.axisBankCSV()

        #expect(coordinator.selectSource(sourceURL))
        try await waitUntilAuthentic(timeoutIterations: 2_000) {
            coordinator.currentItem?.phase == .awaitingConfirmation
        }
        let prepared = try #require(coordinator.currentItem?.preparation)
        #expect(try prepared.sourceSnapshot.withBytes { !$0.isEmpty })

        coordinator.updateAccountChoice(.createNewAccount)
        await coordinator.confirmCurrent(expectedPreparationID: prepared.id)

        let outcome = try #require(coordinator.currentItem?.outcome)
        #expect(coordinator.currentItem?.phase == .completed)
        #expect(outcome.validationStatus == "Validation Passed")
        #expect(outcome.persistenceStatus == "Persistence Succeeded")
        let persistedTransactions = try DatabaseProvider.shared.transactionRepo.trustedTransactions(
            workspaceId: "default-workspace"
        )
        let persistedAccounts = try DatabaseProvider.shared.accountRepo.accounts(
            workspaceId: "default-workspace"
        )
        let persistedAttempts = try DatabaseProvider.shared.importSessionRepo.importAttempts(
            workspaceId: "default-workspace"
        )
        #expect(!persistedTransactions.isEmpty)
        #expect(!persistedAccounts.isEmpty)
        #expect(!persistedAttempts.isEmpty)
        #expect(!TransactionStore.shared.transactions.isEmpty)
        #expect(!AccountStore.shared.accounts.isEmpty)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticSourceCancellationBeforeConfirmationLeavesZeroAcceptedPersistence() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let coordinator = ImportCentreCoordinator<PreparedImport>.production()
        let owner = UUID()
        coordinator.attachPresentationOwner(owner)
        defer { coordinator.detachPresentationOwner(owner) }

        #expect(coordinator.selectSource(try AuthenticSourceTestSupport.axisBankCSV()))
        try await waitUntilAuthentic(timeoutIterations: 2_000) {
            coordinator.currentItem?.phase == .awaitingConfirmation
        }
        let prepared = try #require(coordinator.currentItem?.preparation)

        coordinator.cancelCurrent()

        #expect(coordinator.currentItem?.phase == .cancelled)
        #expect(try DatabaseProvider.shared.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
        #expect(try DatabaseProvider.shared.importSessionRepo.importAttempts(workspaceId: "default-workspace").isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    private func makeCoordinator(
        _ probe: ImportCentreWorkflowProbe
    ) -> ImportCentreCoordinator<OpaqueImportCentrePreparation> {
        ImportCentreCoordinator(
            dependencies: .init(
                prepare: { url, operationID, progress in
                    try await probe.prepare(url: url, operationID: operationID, progress: progress)
                },
                review: { preparation in
                    probe.review(preparation)
                },
                refreshPartialReview: { preparation, choice in
                    probe.refreshPartialReview(preparation, choice: choice)
                },
                commit: { preparation, choice, plan in
                    await probe.commit(preparation, choice: choice, plan: plan)
                },
                cancelPreparation: { probe.cancelPreparation($0) },
                cancelPasswordChallenge: { probe.cancelPasswordChallenge() },
                failureSummary: { _ in
                    ImportFailureSummary(
                        stage: .documentPreparation,
                        family: .unknown,
                        explanation: "Opaque preparation failed.",
                        guidance: "Retry the isolated mechanics operation."
                    )
                },
                isRetryablePreparationFailure: { $0 is ImportError }
            )
        )
    }

    private func waitUntil(
        timeoutIterations: Int = 500,
        _ condition: () -> Bool
    ) async {
        for _ in 0..<timeoutIterations {
            if condition() { return }
            await Task.yield()
        }
        Issue.record("Timed out waiting for Import Centre state.")
    }

    private func waitUntilAuthentic(
        timeoutIterations: Int,
        _ condition: () -> Bool
    ) async throws {
        for _ in 0..<timeoutIterations {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for authentic Import Centre state.")
    }
}

private struct OpaqueImportCentrePreparation: ImportCentrePreparation {
    let id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }
}

@MainActor
private final class ImportCentreWorkflowProbe {
    var suspendsPreparation = false
    var suspendsCommit = false
    var nextPreparationError: Error?
    private(set) var prepareCallCount = 0
    private(set) var commitCallCount = 0
    private(set) var activePreparationCount = 0
    private(set) var maximumConcurrentPreparationCount = 0
    private(set) var passwordCancellationCount = 0
    private(set) var cancelledPreparationIDs: [UUID] = []
    private(set) var lastOperationID: UUID?
    private(set) var lastProgressCallback: ((ImportProgress) -> Void)?
    private var preparationContinuations: [CheckedContinuation<OpaqueImportCentrePreparation, Never>] = []
    private var commitContinuation: CheckedContinuation<Void, Never>?

    func prepare(
        url _: URL,
        operationID: UUID,
        progress: @escaping (ImportProgress) -> Void
    ) async throws -> OpaqueImportCentrePreparation {
        prepareCallCount += 1
        activePreparationCount += 1
        maximumConcurrentPreparationCount = max(
            maximumConcurrentPreparationCount,
            activePreparationCount
        )
        lastOperationID = operationID
        lastProgressCallback = progress
        defer { activePreparationCount -= 1 }

        if let error = nextPreparationError {
            nextPreparationError = nil
            throw error
        }
        if suspendsPreparation {
            return await withCheckedContinuation { continuation in
                preparationContinuations.append(continuation)
            }
        }
        return OpaqueImportCentrePreparation()
    }

    func emitProgress(requestID: UUID, phase: ImportProgressPhase) {
        lastProgressCallback?(
            ImportProgress(
                requestId: requestID,
                phase: phase,
                completedUnitCount: 0,
                totalUnitCount: 0
            )
        )
    }

    func resumeNextPreparation(with preparation: OpaqueImportCentrePreparation) {
        guard !preparationContinuations.isEmpty else {
            Issue.record("No suspended preparation was available to resume.")
            return
        }
        preparationContinuations.removeFirst().resume(returning: preparation)
    }

    func review(_ preparation: OpaqueImportCentrePreparation) -> ImportCentreReviewState {
        ImportCentreReviewState(
            identityReview: .unavailable,
            initialAccountChoice: nil,
            partialReview: .ordinaryFullImport,
            validationPassed: true
        )
    }

    func refreshPartialReview(
        _ preparation: OpaqueImportCentrePreparation,
        choice: ImportAccountChoice?
    ) -> PartialImportReviewResult {
        .ordinaryFullImport
    }

    func commit(
        _ preparation: OpaqueImportCentrePreparation,
        choice: ImportAccountChoice?,
        plan: ReviewedPartialImportPlanDTO?
    ) async -> ImportOutcomePresentation {
        commitCallCount += 1
        if suspendsCommit {
            await withCheckedContinuation { continuation in
                commitContinuation = continuation
            }
        }
        return ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "opaque",
                transactionCount: 0,
                validationPassed: true,
                persisted: true,
                errorMessage: nil
            )
        )
    }

    func resumeCommit() {
        let continuation = commitContinuation
        commitContinuation = nil
        continuation?.resume()
    }

    func cancelPreparation(_ preparation: OpaqueImportCentrePreparation) {
        cancelledPreparationIDs.append(preparation.id)
    }

    func cancelPasswordChallenge() {
        passwordCancellationCount += 1
    }
}
