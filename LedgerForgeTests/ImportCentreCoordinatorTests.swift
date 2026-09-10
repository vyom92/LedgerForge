import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct ImportCentreCoordinatorTests {
    @Test func skippedPresentationRemainsDistinctFromCancellation() {
        let presentation = ImportActivityPresentation(
            importState: .skipped(fileName: "opaque-skipped"),
            latestDurableAttempt: nil
        )

        #expect(presentation.title == "opaque-skipped")
        #expect(presentation.status == "Skipped")
        #expect(presentation.subtitle == "Statement skipped. No data was written.")
        #expect(ImportFooterPresentation.presentation(
            for: .skipped(fileName: "opaque-skipped")
        ).kind == .none)
    }

    @Test func oneFileUsesTheOrderedBatchPath() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsPreparation = true
        let coordinator = makeCoordinator(probe)
        let sourceURL = URL(fileURLWithPath: "/tmp/opaque-single")

        #expect(coordinator.enqueueSources([sourceURL]))
        await waitUntil { probe.prepareCallCount == 1 }

        #expect(coordinator.items.count == 1)
        #expect(coordinator.items[0].sourceURL == sourceURL)
        #expect(coordinator.items[0].queuePosition == 0)
        #expect(coordinator.currentItem?.id == coordinator.items[0].id)
        #expect(coordinator.items[0].phase == .preparing)

        coordinator.cancelBatch()
        probe.resumeNextPreparation(with: OpaqueImportCentrePreparation())
        await waitUntil { !coordinator.isPreparationDraining }
    }

    @Test func orderedBatchPreservesPickerOrderAndDistinctTransientIdentity() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsPreparation = true
        let coordinator = makeCoordinator(probe)
        let firstURL = URL(fileURLWithPath: "/tmp/first/shared-name")
        let repeatedURL = firstURL
        let sameNameURL = URL(fileURLWithPath: "/tmp/second/shared-name")
        let sourceURLs = [firstURL, repeatedURL, sameNameURL]

        #expect(coordinator.enqueueSources(sourceURLs))
        await waitUntil { probe.prepareCallCount == 1 }

        #expect(coordinator.items.map(\.sourceURL) == sourceURLs)
        #expect(coordinator.items.map(\.queuePosition) == [0, 1, 2])
        #expect(Set(coordinator.items.map(\.id)).count == 3)
        #expect(coordinator.items.map(\.displayFileName) == ["shared-name", "shared-name", "shared-name"])
        #expect(coordinator.items.map(\.phase) == [.preparing, .pending, .pending])
        #expect(coordinator.currentItem?.id == coordinator.items[0].id)
        #expect(!coordinator.enqueueSources([URL(fileURLWithPath: "/tmp/opaque-overlap")]))
        #expect(probe.maximumConcurrentPreparationCount == 1)

        coordinator.cancelBatch()
        probe.resumeNextPreparation(with: OpaqueImportCentrePreparation())
        await waitUntil { !coordinator.isPreparationDraining }
    }

    @Test func confirmationCommitsOneItemAndOnlyThenPreparesTheNext() async {
        let probe = ImportCentreWorkflowProbe()
        let coordinator = makeCoordinator(probe)
        let firstURL = URL(fileURLWithPath: "/tmp/first/shared-name")
        let secondURL = URL(fileURLWithPath: "/tmp/second/shared-name")
        let sourceURLs = [
            firstURL,
            secondURL
        ]

        #expect(coordinator.enqueueSources(sourceURLs))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let firstItemID = coordinator.currentItem?.id
        let firstPreparationID = coordinator.currentItem?.preparation?.id
        let secondItemID = coordinator.items[1].id

        #expect(probe.prepareCallCount == 1)
        #expect(coordinator.items[1].phase == .pending)
        coordinator.updateAccountChoice(.createNewAccount)
        #expect(coordinator.currentItem?.accountChoice == .createNewAccount)
        await coordinator.confirmCurrent(expectedPreparationID: firstPreparationID)
        await waitUntil {
            coordinator.currentItem?.id == secondItemID
                && coordinator.currentItem?.phase == .awaitingConfirmation
        }

        #expect(probe.commitCallCount == 1)
        #expect(probe.prepareCallCount == 2)
        #expect(probe.maximumConcurrentPreparationCount == 1)
        #expect(coordinator.items.first { $0.id == firstItemID }?.phase == .completed)
        #expect(coordinator.items.first { $0.id == firstItemID }?.completionDisposition == .committed)
        #expect(coordinator.currentItem?.id == secondItemID)
        #expect(coordinator.currentItem?.id != firstItemID)
        #expect(coordinator.currentItem?.sourceURL == secondURL)
        #expect(coordinator.currentItem?.displayFileName == "shared-name")
        #expect(coordinator.currentItem?.accountChoice == nil)
        #expect(coordinator.currentItem?.cardSectionDraftAccountID == nil)
        #expect(coordinator.currentItem?.cardSectionDraftChoices.isEmpty == true)
        #expect(coordinator.currentItem?.partialReview == .ordinaryFullImport)
        #expect(coordinator.currentItem?.outcome == nil)
        #expect(coordinator.currentItem?.recoveryContext == nil)

        await coordinator.confirmCurrent(expectedPreparationID: coordinator.currentItem?.preparation?.id)
        #expect(coordinator.currentItem == nil)
        #expect(coordinator.batchSummary.committedCount == 2)
        #expect(coordinator.batchSummary.isComplete)
    }

    @Test func cancellingPreparationDrainsBeforeNextAndRejectsStaleCallbacks() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsPreparation = true
        let coordinator = makeCoordinator(probe)
        let sourceURLs = [
            URL(fileURLWithPath: "/tmp/opaque-cancel-a"),
            URL(fileURLWithPath: "/tmp/opaque-cancel-b")
        ]

        #expect(coordinator.enqueueSources(sourceURLs))
        await waitUntil { probe.prepareCallCount == 1 }
        let firstItemID = coordinator.currentItem?.id
        let staleProgress = probe.lastProgressCallback
        let staleOperationID = probe.lastOperationID

        coordinator.cancelCurrent()
        #expect(coordinator.items.first { $0.id == firstItemID }?.phase == .cancelled)
        #expect(coordinator.isPreparationDraining)
        #expect(probe.prepareCallCount == 1)
        #expect(coordinator.items[1].phase == .pending)

        let latePreparation = OpaqueImportCentrePreparation()
        probe.resumeNextPreparation(with: latePreparation)
        await waitUntil { probe.prepareCallCount == 2 }
        #expect(probe.cancelledPreparationIDs == [latePreparation.id])
        #expect(coordinator.currentItem?.id == coordinator.items[1].id)
        #expect(probe.maximumConcurrentPreparationCount == 1)

        staleProgress?(
            ImportProgress(
                requestId: staleOperationID ?? UUID(),
                phase: .validatingPreparedContent,
                completedUnitCount: 0,
                totalUnitCount: 0
            )
        )
        await Task.yield()
        #expect(coordinator.currentItem?.id == coordinator.items[1].id)
        #expect(coordinator.currentItem?.progress.phase == .openingSource)

        probe.resumeNextPreparation(with: OpaqueImportCentrePreparation())
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        coordinator.cancelBatch()
    }

    @Test func skipDisposesPreviewWritesNothingAndAdvances() async {
        let probe = ImportCentreWorkflowProbe()
        let coordinator = makeCoordinator(probe)
        let sourceURLs = [
            URL(fileURLWithPath: "/tmp/opaque-skip-a"),
            URL(fileURLWithPath: "/tmp/opaque-skip-b")
        ]

        #expect(coordinator.enqueueSources(sourceURLs))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let firstItemID = coordinator.currentItem?.id
        let firstPreparationID = coordinator.currentItem?.preparation?.id
        coordinator.skipCurrent()
        await waitUntil { coordinator.currentItem?.id == coordinator.items[1].id }

        #expect(probe.commitCallCount == 0)
        #expect(coordinator.items.first { $0.id == firstItemID }?.phase == .skipped)
        #expect(probe.cancelledPreparationIDs == [firstPreparationID].compactMap { $0 })
        #expect(coordinator.batchSummary.skippedCount == 1)
        coordinator.cancelBatch()
    }

    @Test func retryKeepsItemIdentityAndQueuePositionWithFreshOperation() async {
        let probe = ImportCentreWorkflowProbe()
        probe.nextPreparationError = ImportError.readerFailure(message: "opaque mechanics failure")
        let coordinator = makeCoordinator(probe)
        let sourceURLs = [
            URL(fileURLWithPath: "/tmp/opaque-retry-a"),
            URL(fileURLWithPath: "/tmp/opaque-retry-b")
        ]

        #expect(coordinator.enqueueSources(sourceURLs))
        await waitUntil { coordinator.currentItem?.phase == .failed && !coordinator.isPreparationDraining }
        let itemID = coordinator.currentItem?.id
        let firstOperationID = probe.operationIDs.first

        #expect(coordinator.currentItem?.sourceURL == sourceURLs[0])
        #expect(coordinator.currentItem?.retrySourceURL == sourceURLs[0])
        #expect(coordinator.currentItem?.preparation == nil)
        #expect(coordinator.currentItem?.failureMessage == "Opaque preparation failed. Retry the isolated mechanics operation.")
        #expect(coordinator.permitsRetry)
        #expect(coordinator.retryCurrent())
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }

        #expect(coordinator.currentItem?.id == itemID)
        #expect(coordinator.currentItem?.queuePosition == 0)
        #expect(coordinator.items.count == 2)
        #expect(probe.operationIDs.count == 2)
        #expect(probe.operationIDs.last != firstOperationID)
        #expect(coordinator.items[1].phase == .pending)
        coordinator.cancelBatch()
    }

    @Test func preparationFailureRequiresExplicitContinueAndLeavesPendingItemUntouched() async {
        let probe = ImportCentreWorkflowProbe()
        probe.nextPreparationError = ImportError.readerFailure(message: "opaque mechanics failure")
        let coordinator = makeCoordinator(probe)
        let sourceURLs = [
            URL(fileURLWithPath: "/tmp/opaque-failure-a"),
            URL(fileURLWithPath: "/tmp/opaque-failure-b")
        ]

        #expect(coordinator.enqueueSources(sourceURLs))
        await waitUntil { coordinator.currentItem?.phase == .failed && !coordinator.isPreparationDraining }
        let failedItemID = coordinator.currentItem?.id

        #expect(probe.prepareCallCount == 1)
        #expect(coordinator.items[1].phase == .pending)
        #expect(coordinator.permitsContinue)
        #expect(coordinator.continueAfterCurrent())
        await waitUntil {
            coordinator.currentItem?.id == coordinator.items[1].id
                && coordinator.currentItem?.phase == .awaitingConfirmation
        }

        #expect(coordinator.items.first { $0.id == failedItemID }?.phase == .failed)
        #expect(probe.prepareCallCount == 2)
        #expect(coordinator.batchSummary.failedPreparationCount == 1)
        coordinator.cancelBatch()
    }

    @Test func rejectedConfirmationPausesUntilExplicitContinue() async {
        let probe = ImportCentreWorkflowProbe()
        probe.nextCommitResult = ImportEngineResult(
            fileName: "opaque",
            transactionCount: 0,
            validationPassed: true,
            persisted: false,
            errorMessage: "opaque rejection",
            recoveryRoute: .reviewRequired(.repositoryIntegrityConflict)
        )
        let coordinator = makeCoordinator(probe)
        #expect(coordinator.enqueueSources([
            URL(fileURLWithPath: "/tmp/opaque-rejected-a"),
            URL(fileURLWithPath: "/tmp/opaque-rejected-b")
        ]))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let rejectedItemID = coordinator.currentItem?.id

        await coordinator.confirmCurrent(expectedPreparationID: coordinator.currentItem?.preparation?.id)

        #expect(coordinator.currentItem?.id == rejectedItemID)
        #expect(coordinator.currentItem?.completionDisposition == .rejected)
        #expect(coordinator.items[1].phase == .pending)
        #expect(probe.prepareCallCount == 1)
        #expect(coordinator.continueAfterCurrent())
        await waitUntil {
            coordinator.currentItem?.id == coordinator.items[1].id
                && coordinator.currentItem?.phase == .awaitingConfirmation
        }
        #expect(probe.prepareCallCount == 2)
        coordinator.cancelBatch()
    }

    @Test func finalRejectedOutcomeShowsTruthfulSummaryBeforeRequiredContinuation() async {
        let probe = ImportCentreWorkflowProbe()
        probe.nextCommitResult = ImportEngineResult(
            fileName: "opaque",
            transactionCount: 0,
            validationPassed: true,
            persisted: false,
            errorMessage: "opaque rejection",
            recoveryRoute: .reviewRequired(.repositoryIntegrityConflict)
        )
        let coordinator = makeCoordinator(probe)
        #expect(coordinator.enqueueSources([
            URL(fileURLWithPath: "/tmp/opaque-final-rejected")
        ]))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }

        await coordinator.confirmCurrent(expectedPreparationID: coordinator.currentItem?.preparation?.id)

        #expect(coordinator.currentItem?.completionDisposition == .rejected)
        #expect(coordinator.hasTerminalOutcomesForEntireBatch)
        #expect(coordinator.batchSummary.rejectedCount == 1)
        #expect(!coordinator.batchSummary.isComplete)
        #expect(coordinator.permitsContinue)

        #expect(coordinator.continueAfterCurrent())
        #expect(coordinator.currentItem == nil)
        #expect(coordinator.batchSummary.isComplete)
        #expect(coordinator.batchSummary.rejectedCount == 1)
    }

    @Test func committedReconciliationOutcomeCountsAsCommittedAndPauses() async {
        let probe = ImportCentreWorkflowProbe()
        probe.nextCommitResult = ImportEngineResult(
            fileName: "opaque",
            transactionCount: 0,
            validationPassed: true,
            persisted: true,
            errorMessage: nil,
            hydrationOutcome: .committedReconciliationRequired,
            recoveryRoute: .retryCanonicalReconciliation
        )
        let coordinator = makeCoordinator(probe)
        #expect(coordinator.enqueueSources([
            URL(fileURLWithPath: "/tmp/opaque-reconciliation-a"),
            URL(fileURLWithPath: "/tmp/opaque-reconciliation-b")
        ]))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let firstItemID = coordinator.currentItem?.id

        await coordinator.confirmCurrent(expectedPreparationID: coordinator.currentItem?.preparation?.id)

        #expect(coordinator.currentItem?.id == firstItemID)
        #expect(coordinator.currentItem?.completionDisposition == .reconciliationRequired)
        #expect(coordinator.items[1].phase == .pending)
        #expect(coordinator.batchSummary.committedCount == 1)
        #expect(coordinator.batchSummary.reconciliationRequiredCount == 1)
        #expect(!coordinator.permitsContinue)
        coordinator.cancelBatch()
    }

    @Test func batchCancellationDuringCommitPreservesCommitAndCancelsUncommittedItems() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsCommit = true
        let coordinator = makeCoordinator(probe)
        #expect(coordinator.enqueueSources([
            URL(fileURLWithPath: "/tmp/opaque-batch-cancel-a"),
            URL(fileURLWithPath: "/tmp/opaque-batch-cancel-b"),
            URL(fileURLWithPath: "/tmp/opaque-batch-cancel-c")
        ]))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let firstItemID = coordinator.currentItem?.id
        let preparationID = coordinator.currentItem?.preparation?.id
        let confirmation = Task {
            await coordinator.confirmCurrent(expectedPreparationID: preparationID)
        }
        await waitUntil { probe.commitCallCount == 1 }

        coordinator.cancelBatch()
        coordinator.cancelCurrent()
        await coordinator.confirmCurrent(expectedPreparationID: preparationID)
        #expect(coordinator.currentItem?.phase == .committing)
        #expect(coordinator.batchCancellationRequested)
        #expect(probe.commitCallCount == 1)

        probe.resumeCommit()
        await confirmation.value

        #expect(coordinator.currentItem == nil)
        #expect(coordinator.items.first { $0.id == firstItemID }?.completionDisposition == .committed)
        #expect(coordinator.items.dropFirst().allSatisfy { $0.phase == .cancelled })
        #expect(coordinator.batchSummary.committedCount == 1)
        #expect(coordinator.batchSummary.cancelledOrNotProcessedCount == 2)
        #expect(coordinator.batchSummary.isComplete)
    }

    @Test func confirmationRequiresMatchingPreviewAndCommitRemainsOneShot() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsCommit = true
        let coordinator = makeCoordinator(probe)
        let firstOwner = UUID()
        let secondOwner = UUID()
        coordinator.attachPresentationOwner(firstOwner)
        coordinator.attachPresentationOwner(secondOwner)
        defer { coordinator.detachPresentationOwner(secondOwner) }
        let sourceURL = URL(fileURLWithPath: "/tmp/opaque-one-shot")

        #expect(coordinator.enqueueSources([sourceURL]))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let preparationID = coordinator.currentItem?.preparation?.id

        await coordinator.confirmCurrent(expectedPreparationID: UUID())
        #expect(probe.commitCallCount == 0)

        let confirmation = Task {
            await coordinator.confirmCurrent(expectedPreparationID: preparationID)
        }
        await waitUntil { probe.commitCallCount == 1 }

        #expect(coordinator.currentItem?.phase == .committing)
        coordinator.detachPresentationOwner(firstOwner)
        #expect(coordinator.presentationOwnerCount == 1)
        #expect(coordinator.currentItem?.phase == .committing)
        #expect(!coordinator.permitsCancellation)
        coordinator.cancelCurrent()
        #expect(coordinator.currentItem?.phase == .committing)
        #expect(!coordinator.enqueueSources([URL(fileURLWithPath: "/tmp/opaque-overlap")]))
        await coordinator.confirmCurrent(expectedPreparationID: preparationID)
        #expect(probe.commitCallCount == 1)

        probe.resumeCommit()
        await confirmation.value
        await coordinator.confirmCurrent(expectedPreparationID: preparationID)

        #expect(probe.commitCallCount == 1)
        #expect(coordinator.currentItem == nil)
        #expect(coordinator.items.first?.phase == .completed)
        #expect(coordinator.items.first?.outcome?.fileName == sourceURL.lastPathComponent)
    }

    @Test func batchSummaryCountsSixDistinctTerminalCategories() async {
        let probe = ImportCentreWorkflowProbe()
        let coordinator = makeCoordinator(probe)
        #expect(coordinator.enqueueSources((0..<6).map {
            URL(fileURLWithPath: "/tmp/opaque-summary-\($0)")
        }))

        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        await coordinator.confirmCurrent(expectedPreparationID: coordinator.currentItem?.preparation?.id)
        await waitUntil {
            coordinator.currentItem?.queuePosition == 1
                && coordinator.currentItem?.phase == .awaitingConfirmation
        }

        probe.nextCommitResult = ImportEngineResult(
            fileName: "opaque",
            transactionCount: 0,
            validationPassed: true,
            persisted: false,
            errorMessage: "opaque transaction-event block",
            transactionEventBlock: .existing(count: 1),
            recoveryRoute: .reviewRequired(.transactionEventBlock)
        )
        await coordinator.confirmCurrent(expectedPreparationID: coordinator.currentItem?.preparation?.id)
        #expect(coordinator.currentItem?.completionDisposition == .transactionEventBlocked)
        #expect(coordinator.continueAfterCurrent())
        await waitUntil {
            coordinator.currentItem?.queuePosition == 2
                && coordinator.currentItem?.phase == .awaitingConfirmation
        }

        probe.nextCommitResult = ImportEngineResult(
            fileName: "opaque",
            transactionCount: 0,
            validationPassed: true,
            persisted: false,
            errorMessage: "opaque rejection",
            recoveryRoute: .reviewRequired(.repositoryIntegrityConflict)
        )
        await coordinator.confirmCurrent(expectedPreparationID: coordinator.currentItem?.preparation?.id)
        #expect(coordinator.currentItem?.completionDisposition == .rejected)
        probe.nextPreparationError = ImportError.readerFailure(message: "opaque preparation failure")
        #expect(coordinator.continueAfterCurrent())
        await waitUntil {
            coordinator.currentItem?.queuePosition == 3
                && coordinator.currentItem?.phase == .failed
                && !coordinator.isPreparationDraining
        }

        #expect(coordinator.continueAfterCurrent())
        await waitUntil {
            coordinator.currentItem?.queuePosition == 4
                && coordinator.currentItem?.phase == .awaitingConfirmation
        }
        coordinator.skipCurrent()
        await waitUntil {
            coordinator.currentItem?.queuePosition == 5
                && coordinator.currentItem?.phase == .awaitingConfirmation
        }
        coordinator.cancelCurrent()

        #expect(coordinator.items.map(\.phase) == [
            .completed, .completed, .completed, .failed, .skipped, .cancelled
        ])
        #expect(coordinator.items.map(\.completionDisposition) == [
            .committed, .transactionEventBlocked, .rejected, nil, nil, nil
        ])
        let summary = coordinator.batchSummary
        #expect(summary.totalSelected == 6)
        #expect(summary.committedCount == 1)
        #expect(summary.exactDuplicateCount == 0)
        #expect(summary.transactionEventBlockedCount == 1)
        #expect(summary.rejectedCount == 1)
        #expect(summary.failedPreparationCount == 1)
        #expect(summary.skippedCount == 1)
        #expect(summary.cancelledOrNotProcessedCount == 1)
        #expect(summary.reconciliationRequiredCount == 0)
        #expect(coordinator.hasTerminalOutcomesForEntireBatch)
        #expect(summary.isComplete)
    }

    @Test func competingPresentationOwnersShareOnePreparationUntilLastOwnerDrains() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsPreparation = true
        let coordinator = makeCoordinator(probe)
        let firstOwner = UUID()
        let secondOwner = UUID()
        coordinator.attachPresentationOwner(firstOwner)
        coordinator.attachPresentationOwner(secondOwner)
        let sources = [
            URL(fileURLWithPath: "/tmp/opaque-owner-queue-a"),
            URL(fileURLWithPath: "/tmp/opaque-owner-queue-b")
        ]

        #expect(coordinator.enqueueSources(sources))
        await waitUntil { probe.prepareCallCount == 1 }
        let itemIDs = coordinator.items.map(\.id)
        #expect(!coordinator.enqueueSources([
            URL(fileURLWithPath: "/tmp/opaque-owner-competing")
        ]))
        #expect(coordinator.items.map(\.id) == itemIDs)
        #expect(coordinator.items.map(\.sourceURL) == sources)
        #expect(probe.maximumConcurrentPreparationCount == 1)

        coordinator.detachPresentationOwner(firstOwner)
        #expect(coordinator.presentationOwnerCount == 1)
        #expect(coordinator.currentItem?.phase == .preparing)
        #expect(probe.passwordCancellationCount == 0)

        coordinator.detachPresentationOwner(secondOwner)
        #expect(coordinator.items.isEmpty)
        #expect(coordinator.isPreparationDraining)
        #expect(probe.passwordCancellationCount == 1)
        #expect(!coordinator.enqueueSources([
            URL(fileURLWithPath: "/tmp/opaque-owner-replacement")
        ]))

        let latePreparation = OpaqueImportCentrePreparation()
        probe.resumeNextPreparation(with: latePreparation)
        await waitUntil { !coordinator.isPreparationDraining }
        #expect(probe.cancelledPreparationIDs == [latePreparation.id])
        #expect(probe.prepareCallCount == 1)
        #expect(probe.maximumConcurrentPreparationCount == 1)
    }

    @Test func pickerFailureCannotEraseRetainedPreviewOrCompletedOutcome() async {
        let probe = ImportCentreWorkflowProbe()
        let coordinator = makeCoordinator(probe)

        #expect(coordinator.enqueueSources([URL(fileURLWithPath: "/tmp/opaque-picker-owner")]))
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
        let outcome = coordinator.items.first?.outcome
        coordinator.recordSelectionFailure(ImportError.unknown(message: "opaque picker failure"))

        #expect(coordinator.items.first?.id == itemID)
        #expect(coordinator.items.first?.phase == .completed)
        #expect(coordinator.items.first?.outcome == outcome)
        #expect(coordinator.selectionFailureMessage == nil)
    }

    @Test func resetRejectsReplacementUntilLatePreparationIsDisposed() async {
        let probe = ImportCentreWorkflowProbe()
        probe.suspendsPreparation = true
        let coordinator = makeCoordinator(probe)

        #expect(coordinator.enqueueSources([URL(fileURLWithPath: "/tmp/opaque-reset-a")]))
        await waitUntil { probe.prepareCallCount == 1 }
        let staleProgress = probe.lastProgressCallback
        let staleOperationID = probe.lastOperationID
        let replacementURL = URL(fileURLWithPath: "/tmp/opaque-reset-b")

        #expect(coordinator.reset())
        #expect(coordinator.items.isEmpty)
        #expect(coordinator.isPreparationDraining)
        #expect(!coordinator.enqueueSources([replacementURL]))

        let latePreparation = OpaqueImportCentrePreparation()
        probe.resumeNextPreparation(with: latePreparation)
        await waitUntil { !coordinator.isPreparationDraining }
        #expect(probe.cancelledPreparationIDs == [latePreparation.id])

        #expect(coordinator.enqueueSources([replacementURL]))
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
        #expect(coordinator.currentItem?.sourceURL == replacementURL)
        coordinator.cancelBatch()
    }

    @Test func onlyLastPresentationOwnerDisposesTheBatchAndDrainsPreparation() async {
        let previewProbe = ImportCentreWorkflowProbe()
        let previewCoordinator = makeCoordinator(previewProbe)
        let firstOwner = UUID()
        let secondOwner = UUID()
        previewCoordinator.attachPresentationOwner(firstOwner)
        previewCoordinator.attachPresentationOwner(secondOwner)

        #expect(previewCoordinator.enqueueSources([URL(fileURLWithPath: "/tmp/opaque-owner-preview")]))
        await waitUntil { previewCoordinator.currentItem?.phase == .awaitingConfirmation }
        let preparationID = previewCoordinator.currentItem?.preparation?.id

        previewCoordinator.detachPresentationOwner(firstOwner)
        #expect(previewCoordinator.presentationOwnerCount == 1)
        #expect(previewCoordinator.currentItem?.phase == .awaitingConfirmation)
        #expect(previewProbe.cancelledPreparationIDs.isEmpty)

        previewCoordinator.detachPresentationOwner(secondOwner)
        #expect(previewCoordinator.items.isEmpty)
        #expect(previewProbe.cancelledPreparationIDs == [preparationID].compactMap { $0 })

        let drainProbe = ImportCentreWorkflowProbe()
        drainProbe.suspendsPreparation = true
        let drainCoordinator = makeCoordinator(drainProbe)
        let owner = UUID()
        drainCoordinator.attachPresentationOwner(owner)

        #expect(drainCoordinator.enqueueSources([URL(fileURLWithPath: "/tmp/opaque-owner-drain")]))
        await waitUntil { drainProbe.prepareCallCount == 1 }
        drainCoordinator.detachPresentationOwner(owner)

        #expect(drainCoordinator.items.isEmpty)
        #expect(drainCoordinator.isPreparationDraining)
        #expect(drainProbe.passwordCancellationCount == 1)
        #expect(!drainCoordinator.enqueueSources([URL(fileURLWithPath: "/tmp/opaque-owner-new")]))

        let latePreparation = OpaqueImportCentrePreparation()
        drainProbe.resumeNextPreparation(with: latePreparation)
        await waitUntil { !drainCoordinator.isPreparationDraining }
        #expect(drainProbe.cancelledPreparationIDs == [latePreparation.id])
    }

    @Test func recoveryRepreparesTheSameQueueItemWithFreshOperationIdentity() async {
        let probe = ImportCentreWorkflowProbe()
        probe.nextCommitResult = ImportEngineResult(
            fileName: "opaque",
            transactionCount: 0,
            validationPassed: true,
            persisted: false,
            errorMessage: "opaque retryable persistence contention",
            recoveryRoute: .prepareAgain(.persistenceContention)
        )
        let coordinator = makeCoordinator(probe)
        let sourceURL = URL(fileURLWithPath: "/tmp/opaque-recovery")

        #expect(coordinator.enqueueSources([sourceURL]))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let itemID = coordinator.currentItem?.id
        let firstOperationID = probe.operationIDs.first
        await coordinator.confirmCurrent(expectedPreparationID: coordinator.currentItem?.preparation?.id)
        let contextID = coordinator.currentItem?.recoveryContext?.id

        #expect(contextID != nil)
        #expect(coordinator.reprepareCurrentRecovery(
            contextID: contextID ?? UUID(),
            route: .prepareAgain(.persistenceContention),
            sourceURL: sourceURL
        ))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }

        #expect(coordinator.currentItem?.id == itemID)
        #expect(coordinator.currentItem?.queuePosition == 0)
        #expect(coordinator.items.count == 1)
        #expect(probe.operationIDs.count == 2)
        #expect(probe.operationIDs.last != firstOperationID)
        coordinator.cancelBatch()
    }

    @Test func laterPreparationFailureCannotAlterAnEarlierCommittedItem() async {
        let probe = ImportCentreWorkflowProbe()
        let coordinator = makeCoordinator(probe)
        #expect(coordinator.enqueueSources([
            URL(fileURLWithPath: "/tmp/opaque-preserve-a"),
            URL(fileURLWithPath: "/tmp/opaque-preserve-b")
        ]))
        await waitUntil { coordinator.currentItem?.phase == .awaitingConfirmation }
        let committedItemID = coordinator.currentItem?.id
        probe.nextPreparationError = ImportError.readerFailure(message: "opaque later failure")

        await coordinator.confirmCurrent(expectedPreparationID: coordinator.currentItem?.preparation?.id)
        await waitUntil { coordinator.currentItem?.phase == .failed && !coordinator.isPreparationDraining }

        #expect(coordinator.items.first { $0.id == committedItemID }?.phase == .completed)
        #expect(coordinator.items.first { $0.id == committedItemID }?.completionDisposition == .committed)
        #expect(coordinator.items.first { $0.id == committedItemID }?.outcome != nil)
        #expect(coordinator.batchSummary.committedCount == 1)
        #expect(coordinator.batchSummary.failedPreparationCount == 1)
        coordinator.cancelBatch()
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

        let outcome = try #require(coordinator.items.first?.outcome)
        #expect(coordinator.items.first?.phase == .completed)
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

        #expect(coordinator.items.first?.phase == .cancelled)
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
    var nextCommitResult: ImportEngineResult?
    private(set) var prepareCallCount = 0
    private(set) var commitCallCount = 0
    private(set) var activePreparationCount = 0
    private(set) var maximumConcurrentPreparationCount = 0
    private(set) var passwordCancellationCount = 0
    private(set) var cancelledPreparationIDs: [UUID] = []
    private(set) var operationIDs: [UUID] = []
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
        operationIDs.append(operationID)
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
        let result = nextCommitResult ?? ImportEngineResult(
                fileName: "opaque",
                transactionCount: 0,
                validationPassed: true,
                persisted: true,
                errorMessage: nil
            )
        nextCommitResult = nil
        return ImportOutcomePresentation(result: result)
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
