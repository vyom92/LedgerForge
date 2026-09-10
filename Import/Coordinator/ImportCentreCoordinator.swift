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
            case preparing
            case awaitingReview
            case awaitingConfirmation
            case validationFailed
            case committing
            case completed
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
        fileprivate(set) var failureMessage: String?
        fileprivate(set) var retrySourceURL: URL?
        fileprivate(set) var recoveryContext: ConfirmedImportRecoveryContext?
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var selectionFailureMessage: String?
    @Published private(set) var recoveryActionRequestID: UUID?
    @Published private(set) var preparationIsActive = false

    private let dependencies: Dependencies
    private var preparationTask: Task<Void, Never>?
    private var activePreparation: (itemID: UUID, operationID: UUID)?
    private var presentationOwnerIDs: Set<UUID> = []
    private var hasAttachedPresentationOwner = false

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    var currentItem: Item? { items.first }
    var isPreparationDraining: Bool { preparationIsActive }
    var presentationOwnerCount: Int { presentationOwnerIDs.count }

    var permitsSourceSelection: Bool {
        !preparationIsActive && currentItem?.phase != .committing
    }

    var permitsCancellation: Bool {
        guard let phase = currentItem?.phase else { return false }
        switch phase {
        case .preparing, .awaitingReview, .awaitingConfirmation, .validationFailed:
            return true
        case .committing, .completed, .cancelled, .failed:
            return false
        }
    }

    @discardableResult
    func selectSource(_ sourceURL: URL) -> Bool {
        guard permitsSourceSelection else { return false }
        disposeCurrentPreparationIfNeeded()

        selectionFailureMessage = nil
        recoveryActionRequestID = nil
        let itemID = UUID()
        let operationID = UUID()
        let progress = ImportProgress(
            requestId: operationID,
            phase: .openingSource,
            completedUnitCount: 0,
            totalUnitCount: 0
        )
        items = [
            Item(
                id: itemID,
                sourceURL: sourceURL,
                displayFileName: sourceURL.lastPathComponent,
                queuePosition: 0,
                preparationOperationID: operationID,
                progress: progress,
                phase: .preparing,
                preparation: nil,
                identityReview: .unavailable,
                accountChoice: nil,
                cardSectionDraftAccountID: nil,
                cardSectionDraftChoices: [:],
                partialReview: .ordinaryFullImport,
                outcome: nil,
                failureMessage: nil,
                retrySourceURL: nil,
                recoveryContext: nil
            )
        ]
        activePreparation = (itemID, operationID)
        preparationIsActive = true
        preparationTask = Task { [weak self] in
            await self?.runPreparation(
                sourceURL: sourceURL,
                itemID: itemID,
                operationID: operationID
            )
        }
        return true
    }

    func attachPresentationOwner(_ ownerID: UUID) {
        hasAttachedPresentationOwner = true
        presentationOwnerIDs.insert(ownerID)
    }

    func detachPresentationOwner(_ ownerID: UUID) {
        guard presentationOwnerIDs.remove(ownerID) != nil,
              presentationOwnerIDs.isEmpty else { return }
        _ = reset()
    }

    func recordSelectionFailure(_ error: Error) {
        guard currentItem == nil, !preparationIsActive else { return }
        recoveryActionRequestID = nil
        selectionFailureMessage = dependencies.failureSummary(error).displayText
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
        case .committing, .completed, .cancelled, .failed:
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
        }
    }

    @discardableResult
    func reset() -> Bool {
        guard currentItem?.phase != .committing else { return false }
        if activePreparation != nil {
            dependencies.cancelPasswordChallenge()
            preparationTask?.cancel()
        } else {
            disposeCurrentPreparationIfNeeded()
        }
        items = []
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
        guard let current = currentItem,
              current.id == itemID,
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
        mutateItem(itemID) {
            $0.phase = .completed
            $0.preparation = nil
            $0.outcome = outcome
            $0.recoveryContext = recoveryContext
        }
        if hasAttachedPresentationOwner && presentationOwnerIDs.isEmpty {
            items = []
            recoveryActionRequestID = nil
        }
    }

    func beginRecoveryAction(contextID: UUID) -> UUID? {
        guard recoveryActionRequestID == nil,
              let item = currentItem,
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
        guard let item = currentItem else { return false }
        return item.phase == .completed
            && item.recoveryContext?.id == contextID
            && item.recoveryContext?.route == route
            && item.outcome?.recoveryContextID == contextID
            && item.outcome?.recoveryRoute == route
    }

    @discardableResult
    func markCurrentOutcomeReconciled(contextID: UUID) -> Bool {
        guard let item = currentItem,
              isCurrentRecoveryContext(contextID, route: .retryCanonicalReconciliation),
              let outcome = item.outcome else { return false }
        mutateItem(item.id) {
            $0.outcome = outcome.markingReconciled()
            $0.recoveryContext = nil
        }
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
                  currentItem?.phase == .preparing else {
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
                  currentItem?.phase == .awaitingReview else {
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
              currentItem?.phase == .preparing else { return }
        mutateItem(itemID) { $0.progress = progress }
    }

    private func preserveCancelledState(itemID: UUID, operationID: UUID) {
        guard isCurrentPreparation(itemID: itemID, operationID: operationID),
              let item = currentItem,
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
            && currentItem?.id == itemID
            && currentItem?.preparationOperationID == operationID
    }

    private func releasePreparationSlot(itemID: UUID, operationID: UUID) {
        guard activePreparation?.itemID == itemID,
              activePreparation?.operationID == operationID else { return }
        activePreparation = nil
        preparationTask = nil
        preparationIsActive = false
    }

    private func disposeCurrentPreparationIfNeeded() {
        guard let preparation = currentItem?.preparation else { return }
        dependencies.cancelPreparation(preparation)
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
        let engine = ImportEngine.shared
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
