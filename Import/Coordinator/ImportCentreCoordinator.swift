import Combine
import Foundation

protocol ImportCentrePreparation: Identifiable where ID == UUID {}

extension PreparedImport: ImportCentrePreparation {}

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
    }

    struct Dependencies {
        let prepare: @MainActor (
            _ sourceURL: URL,
            _ operationID: UUID,
            _ progress: @escaping (ImportProgress) -> Void
        ) async throws -> Preparation
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
        let cancelPreparation: @MainActor (_ preparation: Preparation) -> Void
        let cancelPasswordChallenge: @MainActor () -> Void
        let failureSummary: @MainActor (_ error: Error) -> ImportFailureSummary
        let isRetryablePreparationFailure: @MainActor (_ error: Error) -> Bool
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
        fileprivate(set) var partialReview: PartialImportReviewResult
        fileprivate(set) var outcome: ImportOutcomePresentation?
        fileprivate(set) var completionDisposition: CompletionDisposition?
        fileprivate(set) var failureMessage: String?
        fileprivate(set) var retrySourceURL: URL?
        fileprivate(set) var recoveryContext: ConfirmedImportRecoveryContext?
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
    private var preparationTask: Task<Void, Never>?
    private var activePreparation: (itemID: UUID, operationID: UUID)?
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
            skippedCount: items.filter { $0.phase == .skipped }.count,
            cancelledOrNotProcessedCount: items.filter { $0.phase == .cancelled }.count,
            reconciliationRequiredCount: items.filter {
                $0.completionDisposition == .reconciliationRequired
            }.count,
            isComplete: hasTerminalOutcomesForEntireBatch && activeItemID == nil
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
        guard let item = currentItem, !preparationIsActive else { return false }
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

    @discardableResult
    func selectSource(_ sourceURL: URL) -> Bool {
        enqueueSources([sourceURL])
    }

    @discardableResult
    func enqueueSources(_ sourceURLs: [URL]) -> Bool {
        guard !sourceURLs.isEmpty, permitsSourceSelection else { return false }

        selectionFailureMessage = nil
        recoveryActionRequestID = nil
        batchCancellationRequested = false
        batchID = UUID()
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
                partialReview: .ordinaryFullImport,
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
        return startPreparation(for: firstItemID)
    }

    func attachPresentationOwner(_ ownerID: UUID) {
        hasAttachedPresentationOwner = true
        presentationOwnerIDs.insert(ownerID)
    }

    func detachPresentationOwner(_ ownerID: UUID) {
        guard presentationOwnerIDs.remove(ownerID) != nil,
              presentationOwnerIDs.isEmpty else { return }
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
        selectionFailureMessage = nil
        switch item.phase {
        case .preparing, .awaitingReview:
            dependencies.cancelPasswordChallenge()
            preparationTask?.cancel()
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
            $0.partialReview = .ordinaryFullImport
            $0.recoveryContext = nil
            $0.outcome = nil
            $0.completionDisposition = nil
        }
        guard activePreparation == nil else { return }
        advanceToNextPending(after: item.id)
    }

    func skipCurrent() {
        guard let item = currentItem, permitsSkip else { return }
        selectionFailureMessage = nil
        switch item.phase {
        case .preparing, .awaitingReview:
            dependencies.cancelPasswordChallenge()
            preparationTask?.cancel()
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
            $0.partialReview = .ordinaryFullImport
            $0.recoveryContext = nil
            $0.outcome = nil
            $0.completionDisposition = nil
        }
        guard activePreparation == nil else { return }
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
        if let preparation = item.preparation {
            dependencies.cancelPreparation(preparation)
            mutateItem(item.id) { $0.preparation = nil }
        }
        advanceToNextPending(after: item.id)
        return true
    }

    func cancelBatch() {
        guard permitsBatchCancellation else { return }
        batchCancellationRequested = true
        selectionFailureMessage = nil

        guard let item = currentItem else {
            cancelPendingItems()
            completeBatchCancellation()
            return
        }
        if item.phase == .committing {
            return
        }

        switch item.phase {
        case .preparing, .awaitingReview:
            dependencies.cancelPasswordChallenge()
            preparationTask?.cancel()
            if let preparation = item.preparation {
                dependencies.cancelPreparation(preparation)
            }
            markItemCancelled(item.id)
            cancelPendingItems()
            if activePreparation == nil {
                completeBatchCancellation()
            }
        case .awaitingConfirmation:
            if let preparation = item.preparation {
                dependencies.cancelPreparation(preparation)
            }
            markItemCancelled(item.id)
            cancelPendingItems()
            completeBatchCancellation()
        case .validationFailed, .completed, .failed:
            if let preparation = item.preparation {
                dependencies.cancelPreparation(preparation)
                mutateItem(item.id) { $0.preparation = nil }
            }
            cancelPendingItems()
            completeBatchCancellation()
        case .pending, .skipped, .cancelled:
            cancelPendingItems()
            completeBatchCancellation()
        case .committing:
            break
        }
    }

    @discardableResult
    func reset() -> Bool {
        guard currentItem?.phase != .committing else { return false }
        if activePreparation != nil {
            dependencies.cancelPasswordChallenge()
            preparationTask?.cancel()
        } else {
            disposeAllPreparations()
        }
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
            do {
                $0.partialReview = try dependencies.refreshPartialReview(preparation, choice)
            } catch {
                $0.partialReview = .unsupportedEvidence
            }
        }
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
            if Set(item.cardSectionDraftChoices.keys) == Set(requiredSectionIDs) {
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
    }

    func confirmCurrent(expectedPreparationID: UUID? = nil) async {
        guard let item = currentItem,
              item.phase == .awaitingConfirmation,
              let preparation = item.preparation,
              expectedPreparationID == nil || preparation.id == expectedPreparationID else { return }

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
        if disposition == .committed {
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

            let review: ImportCentreReviewState
            do {
                review = try dependencies.review(preparation)
            } catch {
                dependencies.cancelPreparation(preparation)
                throw error
            }
            guard isCurrentPreparation(itemID: itemID, operationID: operationID),
                  !Task.isCancelled,
                  item(withID: itemID)?.phase == .awaitingReview else {
                dependencies.cancelPreparation(preparation)
                return
            }
            mutateItem(itemID) {
                $0.preparationOperationID = nil
                $0.identityReview = review.identityReview
                $0.accountChoice = review.initialAccountChoice
                $0.partialReview = review.partialReview
                $0.phase = review.validationPassed ? .awaitingConfirmation : .validationFailed
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
                $0.partialReview = .ordinaryFullImport
                $0.failureMessage = summary.displayText
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
        activePreparation?.itemID == itemID
            && activePreparation?.operationID == operationID
            && activeItemID == itemID
            && item(withID: itemID)?.preparationOperationID == operationID
    }

    private func releasePreparationSlot(itemID: UUID, operationID: UUID) {
        guard activePreparation?.itemID == itemID,
              activePreparation?.operationID == operationID else { return }
        activePreparation = nil
        preparationTask = nil
        preparationIsActive = false
        if batchCancellationRequested {
            cancelPendingItems()
            completeBatchCancellation()
            return
        }
        guard let item = item(withID: itemID), activeItemID == itemID else { return }
        if item.phase == .cancelled || item.phase == .skipped {
            advanceToNextPending(after: itemID)
        }
    }

    @discardableResult
    private func startPreparation(for itemID: UUID) -> Bool {
        guard activeItemID == itemID,
              let item = item(withID: itemID),
              item.phase == .pending || item.phase == .failed,
              activePreparation == nil,
              !preparationIsActive,
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
            $0.partialReview = .ordinaryFullImport
            $0.outcome = nil
            $0.completionDisposition = nil
            $0.failureMessage = nil
            $0.retrySourceURL = nil
            $0.recoveryContext = nil
        }
        activePreparation = (itemID, operationID)
        preparationIsActive = true
        preparationTask = Task { [weak self] in
            await self?.runPreparation(
                sourceURL: item.sourceURL,
                itemID: itemID,
                operationID: operationID
            )
        }
        return true
    }

    private func advanceToNextPending(after itemID: UUID) {
        guard activeItemID == itemID else { return }
        activeItemID = nil
        guard let nextItemID = items.first(where: { $0.phase == .pending })?.id else {
            presentedItemID = itemID
            return
        }
        activeItemID = nextItemID
        presentedItemID = nextItemID
        _ = startPreparation(for: nextItemID)
    }

    private func cancelPendingItems() {
        let pendingIDs = items.filter { $0.phase == .pending }.map(\.id)
        for itemID in pendingIDs {
            markItemCancelled(itemID)
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
            $0.partialReview = .ordinaryFullImport
            $0.outcome = nil
            $0.completionDisposition = nil
            $0.failureMessage = nil
            $0.retrySourceURL = nil
            $0.recoveryContext = nil
        }
    }

    private func completeBatchCancellation() {
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
                review: { preparation in
                    let mayReview = preparation.validation.passed
                        && preparation.advisoryPreviousImport == nil
                    let identityReview = mayReview
                        ? try engine.reviewPreparedImport(preparation)
                        : .unavailable
                    let partialReview = mayReview
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
                cancelPreparation: { engine.cancelPreparedImport($0) },
                cancelPasswordChallenge: {
                    StatementPasswordChallengeController.shared.cancel()
                },
                failureSummary: { ImportFailureSummary.from($0) },
                isRetryablePreparationFailure: { error in
                    guard let importError = error as? ImportError else { return false }
                    switch importError {
                    case .readerFailure, .unknown:
                        return true
                    case .unsupportedFile, .passwordRequired, .incorrectPassword,
                            .readerUnavailable, .invalidDocument, .unsupportedStatement,
                            .cancelled:
                        return false
                    }
                }
            )
        )
    }
}
