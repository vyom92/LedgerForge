import Combine
import Foundation

protocol ImportCentrePreparation: Identifiable where ID == UUID {}

extension PreparedImport: @MainActor ImportCentrePreparation {}

struct ImportCentreReviewState {
    let identityReview: ImportIdentityReview
    let initialAccountChoice: ImportAccountChoice?
    let partialReview: PartialImportReviewResult
    let validationPassed: Bool
}

@MainActor
final class ImportCentreCoordinator<Preparation: ImportCentrePreparation>: ObservableObject {
    enum CompletionDisposition: Equatable {
        case committed
        case reconciliationRequired
        case exactDuplicate
        case transactionEventBlocked
        case rejected
    }

    enum BatchLifecycle: Equatable {
        case idle
        case processing
        case awaitingUserAction
        case committing
        case cancelling
        case completed
    }

    struct BatchSummary: Equatable {
        let totalSelected: Int
        let committedCount: Int
        let exactDuplicateCount: Int
        let transactionEventBlockedCount: Int
        let rejectedCount: Int
        let failedPreparationCount: Int
        let skippedCount: Int
        let cancelledOrNotProcessedCount: Int
        let reconciliationRequiredCount: Int
        let isComplete: Bool
        var noUpdateNeededCount: Int = 0
    }

    struct Dependencies {
        let prepare: @MainActor (
            _ sourceURL: URL,
            _ operationID: UUID,
            _ progress: @escaping (ImportProgress) -> Void
        ) async throws -> Preparation
        var refreshQueuedPreparation: @MainActor (Preparation) throws -> Preparation = { $0 }
        let review: @MainActor (_ preparation: Preparation) throws -> ImportCentreReviewState
        let refreshPartialReview: @MainActor (
            _ preparation: Preparation,
            _ accountChoice: ImportAccountChoice?
        ) throws -> PartialImportReviewResult
        let commit: @MainActor (
            _ preparation: Preparation,
            _ accountChoice: ImportAccountChoice?,
            _ reviewedPartialPlan: ReviewedPartialImportPlanDTO?
        ) async -> ImportOutcomePresentation
        let acknowledgeValidationFailure: @MainActor (_ preparation: Preparation) -> ImportOutcomePresentation
        let cancelPreparation: @MainActor (_ preparation: Preparation) -> Void
        let cancelPasswordChallenge: @MainActor (_ operationID: UUID?) -> Void
        let failureSummary: @MainActor (_ error: Error) -> ImportFailureSummary
        let isRetryablePreparationFailure: @MainActor (_ error: Error) -> Bool
        /// A process-local, batch-scoped UI decision only. The production closure
        /// must mirror ordinary confirmation readiness; it cannot waive engine or
        /// provider confirmation-time validation.
        let isAutomaticallyCommittable: @MainActor (
            _ preparation: Preparation,
            _ review: ImportCentreReviewState
        ) -> Bool
        var retainsNewerHoldingsWithoutImport: @MainActor (Preparation) -> Bool = { _ in false }
        var requiredCardSectionIDs: @MainActor (Preparation) -> [String]? = { _ in nil }
    }

    struct Item: Identifiable {
        enum Phase: Equatable {
            case pending
            case preparing
            case awaitingReview
            case awaitingConfirmation
            case validationFailed
            case committing
            case completed
            case skipped
            case cancelled
            case failed
        }

        let id: UUID
        let sourceURL: URL
        let displayFileName: String
        let queuePosition: Int
        fileprivate(set) var preparationOperationID: UUID?
        fileprivate(set) var progress: ImportProgress
        fileprivate(set) var phase: Phase
        fileprivate(set) var preparation: Preparation?
        fileprivate(set) var identityReview: ImportIdentityReview
        fileprivate(set) var accountChoice: ImportAccountChoice?
        fileprivate(set) var cardSectionDraftAccountID: String?
        fileprivate(set) var cardSectionDraftChoices: [String: ImportCardInstrumentChoice]
        fileprivate(set) var bankSectionDraftChoices: [String: ImportBankSectionChoice]
        fileprivate(set) var partialReview: PartialImportReviewResult
        fileprivate(set) var validationPassed: Bool
        fileprivate(set) var outcome: ImportOutcomePresentation?
        fileprivate(set) var completionDisposition: CompletionDisposition?
        fileprivate(set) var failureMessage: String?
        fileprivate(set) var preparationFailure: ImportFailureSummary? = nil
        fileprivate(set) var retrySourceURL: URL?
        fileprivate(set) var recoveryContext: ConfirmedImportRecoveryContext?
        fileprivate(set) var retainedNewerHoldings = false
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var selectionFailureMessage: String?
    @Published private(set) var recoveryActionRequestID: UUID?
    @Published private(set) var preparationIsActive = false
    @Published private(set) var batchID: UUID?
    @Published private(set) var activeItemID: UUID?
    @Published private(set) var presentedItemID: UUID?
    @Published private(set) var batchCancellationRequested = false

    private let dependencies: Dependencies
    private var preparationTasks: [UUID: Task<Void, Never>] = [:]
    private var activePreparations: [UUID: UUID] = [:]
    private var preparationLimit = 1
    /// Exists only for one coordinator queue and is cleared by every batch drain.
    /// It is deliberately not durable and does not replace PreparedImport's
    /// exact-source, generation, or provider-owned commit checks.
    private var confirmedBatchID: UUID?
    private var automaticCommitTask: Task<Void, Never>?
    private var automaticCommitRequestID: UUID?
    private var presentationOwnerIDs: Set<UUID> = []
    private var hasAttachedPresentationOwner = false

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    var currentItem: Item? {
        guard let activeItemID else { return nil }
        return item(withID: activeItemID)
    }

    var presentedItem: Item? {
        guard let presentedItemID else { return currentItem }
        return item(withID: presentedItemID)
    }

    var pendingItems: [Item] {
        items.filter { $0.phase == .pending }
    }

    var terminalItems: [Item] {
        items.filter { Self.isTerminal($0.phase) }
    }

    var hasTerminalOutcomesForEntireBatch: Bool {
        !items.isEmpty && terminalItems.count == items.count
    }

    var batchLifecycle: BatchLifecycle {
        guard !items.isEmpty else { return .idle }
        if batchCancellationRequested { return .cancelling }
        guard let phase = currentItem?.phase else {
            return terminalItems.count == items.count ? .completed : .processing
        }
        switch phase {
        case .pending, .preparing, .awaitingReview:
            return .processing
        case .awaitingConfirmation, .validationFailed, .completed, .failed:
            return .awaitingUserAction
        case .committing:
            return .committing
        case .skipped, .cancelled:
            return preparationIsActive ? .processing : .awaitingUserAction
        }
    }

    var batchSummary: BatchSummary {
        BatchSummary(
            totalSelected: items.count,
            committedCount: items.filter {
                $0.completionDisposition == .committed
                    || $0.completionDisposition == .reconciliationRequired
            }.count,
            exactDuplicateCount: items.filter { $0.completionDisposition == .exactDuplicate }.count,
            transactionEventBlockedCount: items.filter {
                $0.completionDisposition == .transactionEventBlocked
            }.count,
            rejectedCount: items.filter {
                $0.completionDisposition == .rejected || $0.phase == .validationFailed
            }.count,
            failedPreparationCount: items.filter { $0.phase == .failed }.count,
            skippedCount: items.filter { $0.phase == .skipped && !$0.retainedNewerHoldings }.count,
            cancelledOrNotProcessedCount: items.filter { $0.phase == .cancelled }.count,
            reconciliationRequiredCount: items.filter {
                $0.completionDisposition == .reconciliationRequired
            }.count,
            isComplete: hasTerminalOutcomesForEntireBatch && activeItemID == nil,
            noUpdateNeededCount: items.filter { $0.phase == .skipped && $0.retainedNewerHoldings }.count
        )
    }

    var isPreparationDraining: Bool { preparationIsActive }
    var presentationOwnerCount: Int { presentationOwnerIDs.count }

    var permitsSourceSelection: Bool {
        items.isEmpty && !preparationIsActive && activeItemID == nil
    }

    var permitsCancellation: Bool {
        guard let phase = currentItem?.phase else { return false }
        switch phase {
        case .preparing, .awaitingReview, .awaitingConfirmation, .validationFailed:
            return true
        case .pending, .committing, .completed, .skipped, .cancelled, .failed:
            return false
        }
    }

    var permitsSkip: Bool {
        guard let phase = currentItem?.phase else { return false }
        switch phase {
        case .preparing, .awaitingReview, .awaitingConfirmation, .validationFailed:
            return true
        case .pending, .committing, .completed, .skipped, .cancelled, .failed:
            return false
        }
    }

    var permitsRetry: Bool {
        guard let item = currentItem else { return false }
        return item.phase == .failed
            && item.retrySourceURL != nil
            && !preparationIsActive
            && !batchCancellationRequested
    }

    var permitsContinue: Bool {
        guard let item = currentItem,
              activePreparations[item.id] == nil,
              !batchCancellationRequested else { return false }
        switch item.phase {
        case .failed, .validationFailed:
            return true
        case .completed:
            guard let disposition = item.completionDisposition else { return false }
            switch disposition {
            case .exactDuplicate, .transactionEventBlocked, .rejected:
                return true
            case .committed, .reconciliationRequired:
                return false
            }
        case .pending, .preparing, .awaitingReview, .awaitingConfirmation,
                .committing, .skipped, .cancelled:
            return false
        }
    }

    var permitsBatchCancellation: Bool {
        !items.isEmpty && batchLifecycle != .completed
    }

    /// Presentation-only indicator for suppressing the obsolete per-item action
    /// while an explicitly confirmed batch is about to commit a ready item.
    var currentItemWillAutomaticallyCommit: Bool {
        guard let item = currentItem, let preparation = item.preparation else { return false }
        return isAutomaticCommitEligible(item, preparation: preparation)
    }

    /// Keep one progress surface mounted across automatic preparation, the
    /// transient ready state, commit and next-item handoff. Only a real owner
    /// decision or a terminal batch replaces it with review/results.
    var showsAutomaticBatchProgress: Bool {
        guard confirmedBatchID != nil, confirmedBatchID == batchID,
              !batchCancellationRequested, let item = currentItem else { return false }
        switch item.phase {
        case .pending, .preparing, .awaitingReview, .committing:
            return true
        case .awaitingConfirmation:
            // Look-ahead preparation must not hide a decision for this item.
            return currentItemWillAutomaticallyCommit
        case .completed:
            return item.completionDisposition == .committed || item.completionDisposition == .exactDuplicate
        case .validationFailed, .failed, .skipped, .cancelled:
            return false
        }
    }

    /// Password entry is an owner decision even while preparation is suspended.
    /// A look-ahead or obsolete challenge must not replace this item's surface.
    func showsAutomaticBatchProgress(passwordChallengeID: UUID?) -> Bool {
        if let passwordChallengeID, let item = currentItem,
           item.phase == .preparing,
           item.preparationOperationID == passwordChallengeID {
            return false
        }
        return showsAutomaticBatchProgress
    }

    @discardableResult
    func selectSource(_ sourceURL: URL) -> Bool {
        enqueueSources([sourceURL])
    }

    /// Existing/manual queue entry. It deliberately retains per-item confirmation.
    @discardableResult
    func enqueueSources(_ sourceURLs: [URL]) -> Bool {
        startBatch(sourceURLs, confirmedForAutomaticCommit: false)
    }

    /// The sole entry point for the owner-approved one-confirmation workflow.
    /// The caller invokes this only after displaying the selected source count and
    /// the explicit “Prepare and import batch” action.
    @discardableResult
    func startConfirmedBatch(_ sourceURLs: [URL], preparationLimit: Int = 1) -> Bool {
        startBatch(sourceURLs, confirmedForAutomaticCommit: true, preparationLimit: preparationLimit)
    }

    @discardableResult
    private func startBatch(
        _ sourceURLs: [URL],
        confirmedForAutomaticCommit: Bool,
        preparationLimit: Int = 1
    ) -> Bool {
        guard !sourceURLs.isEmpty, permitsSourceSelection else { return false }

        self.preparationLimit = confirmedForAutomaticCommit ? min(2, max(1, preparationLimit)) : 1
        selectionFailureMessage = nil
        recoveryActionRequestID = nil
        batchCancellationRequested = false
        automaticCommitTask?.cancel()
        automaticCommitTask = nil
        automaticCommitRequestID = nil
        let newBatchID = UUID()
        batchID = newBatchID
        confirmedBatchID = confirmedForAutomaticCommit ? newBatchID : nil
        items = sourceURLs.enumerated().map { queuePosition, sourceURL in
            Item(
                id: UUID(),
                sourceURL: sourceURL,
                displayFileName: sourceURL.lastPathComponent,
                queuePosition: queuePosition,
                preparationOperationID: nil,
                progress: Self.openingProgress(operationID: UUID()),
                phase: .pending,
                preparation: nil,
                identityReview: .unavailable,
                accountChoice: nil,
                cardSectionDraftAccountID: nil,
                cardSectionDraftChoices: [:],
                bankSectionDraftChoices: [:],
                partialReview: .ordinaryFullImport,
                validationPassed: false,
                outcome: nil,
                completionDisposition: nil,
                failureMessage: nil,
                retrySourceURL: nil,
                recoveryContext: nil
            )
        }
        guard let firstItemID = items.first?.id else { return false }
        activeItemID = firstItemID
        presentedItemID = firstItemID
        let started = startPreparation(for: firstItemID)
        fillPreparationWindow()
        return started
    }

    func attachPresentationOwner(_ ownerID: UUID) {
        hasAttachedPresentationOwner = true
        presentationOwnerIDs.insert(ownerID)
    }

    func detachPresentationOwner(_ ownerID: UUID) {
        guard presentationOwnerIDs.remove(ownerID) != nil,
              presentationOwnerIDs.isEmpty else { return }
        confirmedBatchID = nil
        automaticCommitTask?.cancel()
        automaticCommitTask = nil
        automaticCommitRequestID = nil
        if currentItem?.phase == .committing {
            batchCancellationRequested = true
        } else {
            _ = reset()
        }
    }

    func recordSelectionFailure(_ error: Error) {
        guard items.isEmpty, !preparationIsActive else { return }
        recoveryActionRequestID = nil
        selectionFailureMessage = dependencies.failureSummary(error).displayText
    }

    func presentItem(_ itemID: UUID) {
        guard item(withID: itemID) != nil else { return }
        presentedItemID = itemID
    }

    func cancelCurrent() {
        guard let item = currentItem, permitsCancellation else { return }
        // Cancelling is a withdrawal of the batch-scoped automatic consent.
        confirmedBatchID = nil
        automaticCommitTask?.cancel()
        automaticCommitTask = nil
        automaticCommitRequestID = nil
        selectionFailureMessage = nil
        switch item.phase {
        case .preparing, .awaitingReview:
            dependencies.cancelPasswordChallenge(item.preparationOperationID)
            preparationTasks[item.id]?.cancel()
            if let preparation = item.preparation {
                dependencies.cancelPreparation(preparation)
            }
        case .awaitingConfirmation, .validationFailed:
            if let preparation = item.preparation {
                dependencies.cancelPreparation(preparation)
            }
        case .pending, .committing, .completed, .skipped, .cancelled, .failed:
            return
        }
        mutateItem(item.id) {
            $0.phase = .cancelled
            $0.preparationOperationID = nil
            $0.preparation = nil
            $0.identityReview = .unavailable
            $0.accountChoice = nil
            $0.cardSectionDraftAccountID = nil
            $0.cardSectionDraftChoices = [:]
            $0.bankSectionDraftChoices = [:]
            $0.partialReview = .ordinaryFullImport
            $0.recoveryContext = nil
            $0.outcome = nil
            $0.completionDisposition = nil
        }
        guard activePreparations[item.id] == nil else { return }
        advanceToNextPending(after: item.id)
    }

    func skipCurrent() {
        guard let item = currentItem, permitsSkip else { return }
        selectionFailureMessage = nil
        switch item.phase {
        case .preparing, .awaitingReview:
            dependencies.cancelPasswordChallenge(item.preparationOperationID)
            preparationTasks[item.id]?.cancel()
            if let preparation = item.preparation {
                dependencies.cancelPreparation(preparation)
            }
        case .awaitingConfirmation, .validationFailed:
            if let preparation = item.preparation {
                dependencies.cancelPreparation(preparation)
            }
        case .pending, .committing, .completed, .skipped, .cancelled, .failed:
            return
        }
        mutateItem(item.id) {
            $0.phase = .skipped
            $0.preparationOperationID = nil
            $0.preparation = nil
            $0.identityReview = .unavailable
            $0.accountChoice = nil
            $0.cardSectionDraftAccountID = nil
            $0.cardSectionDraftChoices = [:]
            $0.bankSectionDraftChoices = [:]
            $0.partialReview = .ordinaryFullImport
            $0.recoveryContext = nil
            $0.outcome = nil
            $0.completionDisposition = nil
        }
        guard activePreparations[item.id] == nil else { return }
        advanceToNextPending(after: item.id)
    }

    @discardableResult
    func retryCurrent() -> Bool {
        guard let item = currentItem, permitsRetry else { return false }
        return startPreparation(for: item.id)
    }

    @discardableResult
    func reprepareCurrentRecovery(
        contextID: UUID,
        route: ConfirmedImportRecoveryRoute,
        sourceURL: URL
    ) -> Bool {
        guard !preparationIsActive,
              !batchCancellationRequested,
              let item = item(withRecoveryContextID: contextID),
              activeItemID == item.id,
              presentedItemID == item.id,
              item.phase == .completed,
              item.sourceURL == sourceURL,
              item.recoveryContext?.route == route,
              item.recoveryContext?.sourceURL == sourceURL,
              item.outcome?.recoveryContextID == contextID,
              item.outcome?.recoveryRoute == route,
              item.outcome?.recoveryPresentation?.primaryAction?.requiresSourceURL == true else {
            return false
        }
        mutateItem(item.id) { $0.phase = .pending }
        return startPreparation(for: item.id)
    }

    @discardableResult
    func continueAfterCurrent() -> Bool {
        guard let item = currentItem, permitsContinue else { return false }
        if item.phase == .validationFailed, let preparation = item.preparation {
            // Continue acknowledges this terminal rejection. Preparation, Cancel
            // and Skip remain write-free for validation failures.
            var outcome = dependencies.acknowledgeValidationFailure(preparation)
            outcome.fileName = item.displayFileName
            outcome.message = outcome.importAttemptID == nil
                ? "The statement failed validation. The failure could not be added to Import History. No financial data was saved."
                : "The statement failed validation. The failure was added to Import History. No financial data was saved."
            mutateItem(item.id) {
                $0.phase = .completed
                $0.preparation = nil
                $0.outcome = outcome
                $0.completionDisposition = .rejected
            }
        } else if let preparation = item.preparation {
            dependencies.cancelPreparation(preparation)
            mutateItem(item.id) { $0.preparation = nil }
        }
        advanceToNextPending(after: item.id)
        return true
    }

    func cancelBatch() {
        guard permitsBatchCancellation else { return }
        confirmedBatchID = nil
        automaticCommitTask?.cancel()
        automaticCommitTask = nil
        automaticCommitRequestID = nil
        batchCancellationRequested = true
        selectionFailureMessage = nil
        dependencies.cancelPasswordChallenge(nil)
        cancelPendingItems()
        completeBatchCancellation()
    }

    @discardableResult
    func reset() -> Bool {
        guard currentItem?.phase != .committing else { return false }
        if !activePreparations.isEmpty {
            dependencies.cancelPasswordChallenge(nil)
            for task in preparationTasks.values { task.cancel() }
        }
        disposeAllPreparations()
        automaticCommitTask?.cancel()
        automaticCommitTask = nil
        automaticCommitRequestID = nil
        confirmedBatchID = nil
        items = []
        activeItemID = nil
        presentedItemID = nil
        batchID = nil
        batchCancellationRequested = false
        selectionFailureMessage = nil
        recoveryActionRequestID = nil
        return true
    }

    func updateAccountChoice(_ choice: ImportAccountChoice?) {
        guard let item = currentItem,
              item.phase == .awaitingConfirmation,
              let preparation = item.preparation else { return }
        mutateItem(item.id) {
            $0.accountChoice = choice
            $0.cardSectionDraftAccountID = nil
            $0.cardSectionDraftChoices = [:]
            $0.bankSectionDraftChoices = [:]
            do {
                $0.partialReview = try dependencies.refreshPartialReview(preparation, choice)
            } catch {
                $0.partialReview = .unsupportedEvidence
            }
        }
        scheduleAutomaticCommitIfEligible(for: item.id)
    }

    func selectCardLiabilityAccount(accountID: String, requiredSectionIDs: [String]) {
        guard let item = currentItem, item.phase == .awaitingConfirmation else { return }
        updateAccountChoice(nil)
        mutateItem(item.id) {
            $0.cardSectionDraftAccountID = accountID
            if requiredSectionIDs.isEmpty {
                $0.accountChoice = .useExistingCardLiabilityAccountSections(
                    accountId: accountID, sectionChoices: [:]
                )
            }
        }
        scheduleAutomaticCommitIfEligible(for: item.id)
    }

    func updateCardSectionChoice(
        accountID: String,
        sectionID: String,
        choice: ImportCardInstrumentChoice,
        requiredSectionIDs: [String]
    ) {
        guard let item = currentItem,
              item.phase == .awaitingConfirmation,
              let preparation = item.preparation else { return }
        mutateItem(item.id) { item in
            if item.cardSectionDraftAccountID != accountID {
                item.cardSectionDraftAccountID = accountID
                item.cardSectionDraftChoices = [:]
            }
            item.cardSectionDraftChoices[sectionID] = choice
            if Set(item.cardSectionDraftChoices.keys) == Set(requiredSectionIDs),
               item.cardSectionDraftChoices.values.allSatisfy(\.isComplete),
               ImportCardInstrumentChoice.hasDistinctExistingDestinations(item.cardSectionDraftChoices) {
                item.accountChoice = .useExistingCardLiabilityAccountSections(
                    accountId: accountID,
                    sectionChoices: item.cardSectionDraftChoices
                )
            } else {
                item.accountChoice = nil
            }
            do {
                item.partialReview = try dependencies.refreshPartialReview(preparation, item.accountChoice)
            } catch {
                item.partialReview = .unsupportedEvidence
            }
        }
        scheduleAutomaticCommitIfEligible(for: item.id)
    }

    /// Stores a section decision in the in-memory review draft. A confirmed
    /// batch can proceed only after every required section has a complete choice;
    /// the provider rechecks the whole parent before any accepted write.
    func updateBankSectionChoice(
        sectionID: String,
        choice: ImportBankSectionChoice
    ) {
        guard let item = currentItem,
              item.phase == .awaitingConfirmation,
              let preparation = item.preparation else { return }
        mutateItem(item.id) { item in
            item.cardSectionDraftAccountID = nil
            item.cardSectionDraftChoices = [:]
            item.bankSectionDraftChoices[sectionID] = choice
            item.accountChoice = .bankSections(item.bankSectionDraftChoices)
            do {
                item.partialReview = try dependencies.refreshPartialReview(preparation, item.accountChoice)
            } catch {
                item.partialReview = .unsupportedEvidence
            }
        }
        scheduleAutomaticCommitIfEligible(for: item.id)
    }

    func confirmCurrent(
        expectedPreparationID: UUID? = nil,
        automaticallyConfirmed: Bool = false
    ) async {
        guard let item = currentItem,
              item.phase == .awaitingConfirmation,
              let preparation = item.preparation,
              expectedPreparationID == nil || preparation.id == expectedPreparationID,
              !automaticallyConfirmed || isAutomaticCommitEligible(item, preparation: preparation) else { return }

        // Keep the source and review draft open if separate printed sections
        // were assigned to the same recorded card, including direct callers.
        guard ImportCardInstrumentChoice.hasDistinctExistingDestinations(item.cardSectionDraftChoices) else { return }
        if case .useExistingCardLiabilityAccountSections(_, let choices) = item.accountChoice,
           !ImportCardInstrumentChoice.hasDistinctExistingDestinations(choices) { return }
        guard cardChoiceIsReady(item) else { return }

        let itemID = item.id
        let preparationID = preparation.id
        let accountChoice = item.accountChoice
        let reviewedPartialPlan: ReviewedPartialImportPlanDTO?
        if case .eligible(let plan) = item.partialReview {
            reviewedPartialPlan = plan
        } else {
            reviewedPartialPlan = nil
        }
        mutateItem(itemID) { $0.phase = .committing }

        var outcome = await dependencies.commit(preparation, accountChoice, reviewedPartialPlan)
        guard let current = self.item(withID: itemID),
              activeItemID == itemID,
              current.phase == .committing,
              current.preparation?.id == preparationID else { return }

        outcome.fileName = current.displayFileName
        let recoveryContext: ConfirmedImportRecoveryContext?
        if let action = outcome.recoveryPresentation?.primaryAction {
            let context = ConfirmedImportRecoveryContext(
                route: outcome.recoveryRoute,
                sourceURL: action.requiresSourceURL ? current.sourceURL : nil
            )
            outcome.recoveryContextID = context.id
            recoveryContext = context
        } else {
            recoveryContext = nil
        }
        let disposition = Self.completionDisposition(for: outcome)
        mutateItem(itemID) {
            $0.phase = .completed
            $0.preparation = nil
            $0.outcome = outcome
            $0.completionDisposition = disposition
            $0.recoveryContext = recoveryContext
        }

        if hasAttachedPresentationOwner && presentationOwnerIDs.isEmpty {
            cancelPendingItems()
            clearBatchState()
            return
        }
        if batchCancellationRequested {
            cancelPendingItems()
            completeBatchCancellation()
            return
        }
        if disposition == .committed
            || (automaticallyConfirmed && disposition == .exactDuplicate) {
            advanceToNextPending(after: itemID)
        }
    }

    func beginRecoveryAction(contextID: UUID) -> UUID? {
        guard recoveryActionRequestID == nil,
              let item = item(withRecoveryContextID: contextID),
              activeItemID == item.id,
              presentedItemID == item.id,
              item.phase == .completed,
              item.recoveryContext?.id == contextID else { return nil }
        let requestID = UUID()
        recoveryActionRequestID = requestID
        return requestID
    }

    func finishRecoveryAction(_ requestID: UUID) {
        guard recoveryActionRequestID == requestID else { return }
        recoveryActionRequestID = nil
    }

    func isCurrentRecoveryContext(_ contextID: UUID, route: ConfirmedImportRecoveryRoute) -> Bool {
        guard let item = item(withRecoveryContextID: contextID) else { return false }
        return activeItemID == item.id
            && presentedItemID == item.id
            && item.phase == .completed
            && item.recoveryContext?.id == contextID
            && item.recoveryContext?.route == route
            && item.outcome?.recoveryContextID == contextID
            && item.outcome?.recoveryRoute == route
    }

    @discardableResult
    func markCurrentOutcomeReconciled(contextID: UUID) -> Bool {
        guard let item = item(withRecoveryContextID: contextID),
              isCurrentRecoveryContext(contextID, route: .retryCanonicalReconciliation),
              let outcome = item.outcome else { return false }
        mutateItem(item.id) {
            $0.outcome = outcome.markingReconciled()
            $0.completionDisposition = .committed
            $0.recoveryContext = nil
        }
        advanceToNextPending(after: item.id)
        return true
    }

    private func runPreparation(sourceURL: URL, itemID: UUID, operationID: UUID) async {
        defer { releasePreparationSlot(itemID: itemID, operationID: operationID) }
        do {
            let preparation = try await dependencies.prepare(sourceURL, operationID) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.acceptProgress(progress, itemID: itemID, operationID: operationID)
                }
            }
            guard isCurrentPreparation(itemID: itemID, operationID: operationID),
                  !Task.isCancelled,
                  item(withID: itemID)?.phase == .preparing else {
                dependencies.cancelPreparation(preparation)
                return
            }
            mutateItem(itemID) {
                $0.phase = .awaitingReview
                $0.preparation = preparation
            }

        } catch is CancellationError {
            preserveCancelledState(itemID: itemID, operationID: operationID)
        } catch let error as ImportError where error == .cancelled {
            preserveCancelledState(itemID: itemID, operationID: operationID)
        } catch {
            guard isCurrentPreparation(itemID: itemID, operationID: operationID),
                  !Task.isCancelled else { return }
            let summary = dependencies.failureSummary(error)
            mutateItem(itemID) {
                $0.preparationOperationID = nil
                $0.phase = .failed
                $0.preparation = nil
                $0.identityReview = .unavailable
                $0.accountChoice = nil
                $0.cardSectionDraftAccountID = nil
                $0.cardSectionDraftChoices = [:]
                $0.bankSectionDraftChoices = [:]
                $0.partialReview = .ordinaryFullImport
                $0.failureMessage = summary.displayText
                $0.preparationFailure = summary
                $0.retrySourceURL = dependencies.isRetryablePreparationFailure(error) ? sourceURL : nil
            }
            DeveloperConsole.shared.error(
                .`import`,
                "Import preparation failed",
                metadata: ["stage": summary.stage.rawValue, "family": summary.family.rawValue]
            )
        }
    }

    private func acceptProgress(_ progress: ImportProgress, itemID: UUID, operationID: UUID) {
        guard progress.requestId == operationID,
              isCurrentPreparation(itemID: itemID, operationID: operationID),
              item(withID: itemID)?.phase == .preparing else { return }
        mutateItem(itemID) { $0.progress = progress }
    }

    private func preserveCancelledState(itemID: UUID, operationID: UUID) {
        guard isCurrentPreparation(itemID: itemID, operationID: operationID),
              let item = item(withID: itemID),
              item.phase != .cancelled else { return }
        mutateItem(itemID) {
            $0.phase = .cancelled
            $0.preparationOperationID = nil
            $0.preparation = nil
        }
    }

    private func isCurrentPreparation(itemID: UUID, operationID: UUID) -> Bool {
        activePreparations[itemID] == operationID
            && item(withID: itemID)?.preparationOperationID == operationID
    }

    private func reviewQueuedItem(_ itemID: UUID) {
        guard activeItemID == itemID, let item = item(withID: itemID),
              item.phase == .awaitingReview, let original = item.preparation else { return }
        do {
            let preparation = try dependencies.refreshQueuedPreparation(original)
            let review = try dependencies.review(preparation)
            if review.validationPassed, dependencies.retainsNewerHoldingsWithoutImport(preparation) {
                // Release the verified source snapshot without invoking commit.
                // No receipt, financial row or current holding is written.
                dependencies.cancelPreparation(preparation)
                mutateItem(itemID) {
                    $0.preparation = nil
                    $0.preparationOperationID = nil
                    $0.validationPassed = true
                    $0.retainedNewerHoldings = true
                    $0.phase = .skipped
                }
                advanceToNextPending(after: itemID)
                return
            }
            mutateItem(itemID) {
                $0.preparation = preparation
                $0.preparationOperationID = nil
                $0.identityReview = review.identityReview
                $0.accountChoice = review.initialAccountChoice
                $0.bankSectionDraftChoices = [:]
                $0.partialReview = review.partialReview
                $0.validationPassed = review.validationPassed
                $0.phase = review.validationPassed ? .awaitingConfirmation : .validationFailed
            }
        } catch {
            dependencies.cancelPreparation(original)
            let summary = dependencies.failureSummary(error)
            mutateItem(itemID) {
                $0.preparation = nil; $0.preparationOperationID = nil
                $0.phase = .failed; $0.failureMessage = summary.displayText
                $0.preparationFailure = summary
                $0.retrySourceURL = dependencies.isRetryablePreparationFailure(error) ? item.sourceURL : nil
            }
        }
    }

    private func releasePreparationSlot(itemID: UUID, operationID: UUID) {
        guard activePreparations[itemID] == operationID else { return }
        activePreparations.removeValue(forKey: itemID)
        preparationTasks.removeValue(forKey: itemID)
        preparationIsActive = !activePreparations.isEmpty
        if batchCancellationRequested {
            cancelPendingItems()
            completeBatchCancellation()
            return
        }
        guard let item = item(withID: itemID), activeItemID == itemID else { return }
        if item.phase == .cancelled || item.phase == .skipped {
            advanceToNextPending(after: itemID)
            return
        }
        reviewQueuedItem(itemID)
        scheduleAutomaticCommitIfEligible(for: itemID)
    }

    private func fillPreparationWindow() {
        guard preparationLimit > 1, confirmedBatchID == batchID, confirmedBatchID != nil,
              !batchCancellationRequested,
              let activeIndex = items.firstIndex(where: { $0.id == activeItemID }),
              !items[activeIndex...].contains(where: { $0.phase == .failed }) else { return }
        while activePreparations.count + items.filter({ $0.preparation != nil && activePreparations[$0.id] == nil }).count < preparationLimit {
            guard let next = items.first(where: { $0.phase == .pending }), startPreparation(for: next.id) else { break }
        }
    }

    private func automaticReviewState(for item: Item) -> ImportCentreReviewState {
        ImportCentreReviewState(
            identityReview: item.identityReview,
            initialAccountChoice: item.accountChoice,
            partialReview: item.partialReview,
            validationPassed: item.validationPassed
        )
    }

    private func cardChoiceIsReady(_ item: Item) -> Bool {
        if item.cardSectionDraftAccountID != nil && item.accountChoice == nil { return false }
        guard case .cardChoiceRequired = item.identityReview else { return true }
        // Completeness comes from the retained preparation, never from the
        // submitted dictionary. A genuine zero-section preparation returns [].
        let sectionIDs = item.preparation.flatMap { dependencies.requiredCardSectionIDs($0) }
        return ImportAccountConfirmationPolicy.allowsConfirmation(
            review: item.identityReview, choice: item.accountChoice, requiredCardSectionIDs: sectionIDs
        )
    }

    private func isAutomaticCommitEligible(
        _ item: Item,
        preparation: Preparation
    ) -> Bool {
        guard confirmedBatchID != nil,
              confirmedBatchID == batchID,
              !batchCancellationRequested,
              activePreparations[item.id] == nil,
              activeItemID == item.id,
              item.phase == .awaitingConfirmation,
              item.preparation?.id == preparation.id else { return false }
        guard ImportCardInstrumentChoice.hasDistinctExistingDestinations(item.cardSectionDraftChoices) else { return false }
        if case .useExistingCardLiabilityAccountSections(_, let choices) = item.accountChoice,
           !ImportCardInstrumentChoice.hasDistinctExistingDestinations(choices) { return false }
        guard cardChoiceIsReady(item) else { return false }
        return dependencies.isAutomaticallyCommittable(
            preparation,
            automaticReviewState(for: item)
        )
    }

    private func scheduleAutomaticCommitIfEligible(for itemID: UUID) {
        guard automaticCommitTask == nil,
              let item = item(withID: itemID),
              let preparation = item.preparation,
              isAutomaticCommitEligible(item, preparation: preparation) else { return }
        let preparationID = preparation.id
        let requestID = UUID()
        automaticCommitRequestID = requestID
        automaticCommitTask = Task { [weak self] in
            // Give synchronous cancellation/reset actions an opportunity to
            // withdraw consent before this begins provider work.
            await Task.yield()
            guard !Task.isCancelled else { return }
            guard let self, self.automaticCommitRequestID == requestID else { return }
            // Release the queued-action slot before awaiting the provider. The
            // next preparation may finish before this task is resumed.
            self.automaticCommitTask = nil
            self.automaticCommitRequestID = nil
            await self.confirmCurrent(
                expectedPreparationID: preparationID,
                automaticallyConfirmed: true
            )
        }
    }

    @discardableResult
    private func startPreparation(for itemID: UUID) -> Bool {
        guard activeItemID == itemID || preparationLimit > 1,
              let item = item(withID: itemID),
              item.phase == .pending || item.phase == .failed,
              activePreparations[itemID] == nil,
              activePreparations.count < preparationLimit,
              !batchCancellationRequested else { return false }

        let operationID = UUID()
        mutateItem(itemID) {
            $0.preparationOperationID = operationID
            $0.progress = Self.openingProgress(operationID: operationID)
            $0.phase = .preparing
            $0.preparation = nil
            $0.identityReview = .unavailable
            $0.accountChoice = nil
            $0.cardSectionDraftAccountID = nil
            $0.cardSectionDraftChoices = [:]
            $0.bankSectionDraftChoices = [:]
            $0.partialReview = .ordinaryFullImport
            $0.validationPassed = false
            $0.outcome = nil
            $0.completionDisposition = nil
            $0.failureMessage = nil
            $0.preparationFailure = nil
            $0.retrySourceURL = nil
            $0.recoveryContext = nil
        }
        activePreparations[itemID] = operationID
        preparationIsActive = true
        preparationTasks[itemID] = Task { [weak self] in
            await self?.runPreparation(
                sourceURL: item.sourceURL,
                itemID: itemID,
                operationID: operationID
            )
        }
        return true
    }

    private func advanceToNextPending(after itemID: UUID) {
        guard activeItemID == itemID,
              let completedIndex = items.firstIndex(where: { $0.id == itemID }) else { return }
        activeItemID = nil
        // A look-ahead failure still owns its place in the review lane. Once
        // explicitly continued, its retained failure must not be selected again.
        guard let nextItemID = items.dropFirst(completedIndex + 1).first(where: {
            [.pending, .preparing, .awaitingReview, .failed].contains($0.phase)
        })?.id else {
            // The explicit consent cannot outlive the completed source list.
            confirmedBatchID = nil
            presentedItemID = itemID
            return
        }
        activeItemID = nextItemID
        presentedItemID = nextItemID
        if item(withID: nextItemID)?.phase == .pending { _ = startPreparation(for: nextItemID) }
        else { reviewQueuedItem(nextItemID); scheduleAutomaticCommitIfEligible(for: nextItemID) }
        fillPreparationWindow()
    }

    private func cancelPendingItems() {
        // A suspended password prompt does not observe Task cancellation on its
        // own. Resume it before cancelling look-ahead preparation tasks so every
        // slot can reach its defer and drain after batch/presentation teardown.
        dependencies.cancelPasswordChallenge(nil)
        for item in items where item.phase != .committing {
            preparationTasks[item.id]?.cancel()
            if let preparation = item.preparation {
                dependencies.cancelPreparation(preparation)
                mutateItem(item.id) { $0.preparation = nil }
            }
            if !Self.isTerminal(item.phase) { markItemCancelled(item.id) }
        }
    }

    private func markItemCancelled(_ itemID: UUID) {
        mutateItem(itemID) {
            $0.phase = .cancelled
            $0.preparationOperationID = nil
            $0.preparation = nil
            $0.identityReview = .unavailable
            $0.accountChoice = nil
            $0.cardSectionDraftAccountID = nil
            $0.cardSectionDraftChoices = [:]
            $0.bankSectionDraftChoices = [:]
            $0.partialReview = .ordinaryFullImport
            $0.outcome = nil
            $0.completionDisposition = nil
            $0.failureMessage = nil
            $0.retrySourceURL = nil
            $0.recoveryContext = nil
        }
    }

    private func completeBatchCancellation() {
        guard activePreparations.isEmpty, currentItem?.phase != .committing else { return }
        if currentItem?.phase != .committing {
            activeItemID = nil
        }
        batchCancellationRequested = false
    }

    private func disposeAllPreparations() {
        for preparation in items.compactMap(\.preparation) {
            dependencies.cancelPreparation(preparation)
        }
    }

    private func clearBatchState() {
        automaticCommitTask?.cancel()
        automaticCommitTask = nil
        automaticCommitRequestID = nil
        confirmedBatchID = nil
        items = []
        activeItemID = nil
        presentedItemID = nil
        batchID = nil
        batchCancellationRequested = false
        selectionFailureMessage = nil
        recoveryActionRequestID = nil
    }

    private func item(withID itemID: UUID) -> Item? {
        items.first { $0.id == itemID }
    }

    private func item(withRecoveryContextID contextID: UUID) -> Item? {
        items.first { $0.recoveryContext?.id == contextID }
    }

    private static func openingProgress(operationID: UUID) -> ImportProgress {
        ImportProgress(
            requestId: operationID,
            phase: .openingSource,
            completedUnitCount: 0,
            totalUnitCount: 0
        )
    }

    private static func isTerminal(_ phase: Item.Phase) -> Bool {
        switch phase {
        case .validationFailed, .completed, .skipped, .cancelled, .failed:
            return true
        case .pending, .preparing, .awaitingReview, .awaitingConfirmation, .committing:
            return false
        }
    }

    private static func completionDisposition(
        for outcome: ImportOutcomePresentation
    ) -> CompletionDisposition {
        if outcome.persisted {
            return outcome.requiresReconciliation ? .reconciliationRequired : .committed
        }
        if outcome.isPreviouslyImported {
            return .exactDuplicate
        }
        if outcome.transactionEventBlock != nil {
            return .transactionEventBlocked
        }
        return .rejected
    }

    private func mutateItem(_ id: UUID, mutation: (inout Item) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutation(&items[index])
    }
}

@MainActor
enum ProductionImportCentre {
    static let shared = ImportCentreCoordinator<PreparedImport>.production()
}

extension ImportCentreCoordinator where Preparation == PreparedImport {
    static func isRetryablePreparationFailure(_ error: Error) -> Bool {
        if let snapshotError = error as? SourceContentSnapshotError {
            return snapshotError == .acquisitionFailed
        }
        guard let importError = error as? ImportError else { return false }
        switch importError {
        case .readerFailure, .unknown, .passwordRequired, .incorrectPassword:
            return true
        case .unsupportedFile, .readerUnavailable, .invalidDocument,
                .unsupportedStatement, .cancelled:
            return false
        }
    }

    func updateInvestmentChoices(_ choices: InvestmentImportChoices) {
        guard let item = currentItem, item.phase == .awaitingConfirmation,
              var preparation = item.preparation, preparation.investmentPlan != nil else { return }
        preparation.updateInvestmentChoices(choices)
        mutateItem(item.id) { $0.preparation = preparation }
        scheduleAutomaticCommitIfEligible(for: item.id)
    }

    static func production() -> ImportCentreCoordinator<PreparedImport> {
        production(using: ImportEngine.shared)
    }

    static func production(using engine: ImportEngine) -> ImportCentreCoordinator<PreparedImport> {
        return ImportCentreCoordinator(
            dependencies: Dependencies(
                prepare: { sourceURL, operationID, progress in
                    try await engine.prepareImport(
                        from: sourceURL,
                        requestId: operationID,
                        progress: progress
                    )
                },
                refreshQueuedPreparation: { try engine.refreshQueuedPreparation($0) },
                review: { preparation in
                    // A known duplicate still receives identity review so a
                    // bank/card duplicate can reach the repository's truthful
                    // duplicate result without inventing an account choice. Its
                    // partial review remains unnecessary and may itself require
                    // current mutable account state.
                    let mayReviewIdentity = preparation.validation.passed
                    let mayReviewPartial = preparation.validation.passed
                        && preparation.advisoryPreviousImport == nil
                    let identityReview = mayReviewIdentity
                        ? try engine.reviewPreparedImport(preparation)
                        : .unavailable
                    let partialReview = mayReviewPartial
                        ? try engine.reviewPreparedPartialImport(preparation)
                        : .ordinaryFullImport
                    return ImportCentreReviewState(
                        identityReview: identityReview,
                        initialAccountChoice: ImportAccountConfirmationPolicy.initialChoice(
                            for: identityReview
                        ),
                        partialReview: partialReview,
                        validationPassed: preparation.validation.passed
                    )
                },
                refreshPartialReview: { preparation, accountChoice in
                    try engine.reviewPreparedPartialImport(
                        preparation,
                        accountChoice: accountChoice
                    )
                },
                commit: { preparation, accountChoice, reviewedPartialPlan in
                    ImportOutcomePresentation(
                        result: await engine.commitPreparedImport(
                            preparation,
                            accountChoice: accountChoice,
                            reviewedPartialPlan: reviewedPartialPlan
                        )
                    )
                },
                acknowledgeValidationFailure: {
                    ImportOutcomePresentation(result: engine.acknowledgeValidationFailure($0))
                },
                cancelPreparation: { engine.cancelPreparedImport($0) },
                cancelPasswordChallenge: { operationID in
                    StatementPasswordChallengeController.shared.cancel(challengeID: operationID)
                },
                failureSummary: { ImportFailureSummary.from($0) },
                isRetryablePreparationFailure: { isRetryablePreparationFailure($0) },
                isAutomaticallyCommittable: { preparation, review in
                    guard review.validationPassed else { return false }
                    let isSalaryOrInvestment = preparation.financialDocument.salaryStatementEvidence != nil
                        || preparation.financialDocument.investmentStatementEvidence != nil
                    let hasResolvedAccountPath = ImportAccountConfirmationPolicy.allowsConfirmation(
                        review: review.identityReview,
                        choice: review.initialAccountChoice,
                        requiredCardSectionIDs: preparation.financialDocument.cardStatementEvidence?.instrumentSections.map(\.documentScopedSectionID),
                        requiresNamedCreation: preparation.detectedDocumentType == .bankAccount
                    )
                    // A known exact source duplicate is submitted only through the
                    // normal engine path. Salary/investment repositories detect it
                    // before normal mutation review; bank/card duplicates additionally
                    // need an existing resolved account path because the generic plan
                    // builder runs before its repository duplicate check.
                    if preparation.advisoryPreviousImport != nil {
                        return isSalaryOrInvestment || hasResolvedAccountPath
                    }
                    if !isSalaryOrInvestment, !hasResolvedAccountPath { return false }
                    guard !preparation.investmentConfirmationBlocked else { return false }
                    switch preparation.statementEquivalenceReview {
                    case .conflict, .evidenceUnavailable, .formatAlreadyRecorded:
                        return false
                    case .notApplicable, .firstAcceptedSource, .equivalent:
                        break
                    }
                    switch review.partialReview {
                    case .ordinaryFullImport, .eligible, .unsupportedEvidence:
                        return true
                    case .fullSupportedOverlap, .repeatedIncomingEvidence,
                            .ownershipConflict, .repositoryIntegrityConflict:
                        return false
                    }
                },
                retainsNewerHoldingsWithoutImport: { $0.retainsNewerHoldingsWithoutImport },
                requiredCardSectionIDs: { $0.financialDocument.cardStatementEvidence?.instrumentSections.map(\.documentScopedSectionID) }
            )
        )
    }
}
