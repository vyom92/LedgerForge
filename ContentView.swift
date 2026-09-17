//
// LedgerForge
// ContentView.swift
// Version: 0.0.9
//

import SwiftUI

enum SettingsCompletedImportsPresentation: Equatable {
    case available(Int, partialCount: Int = 0)
    case unavailable

    var displayValue: String {
        switch self {
        case .available(let count, _):
            return "\(count)"
        case .unavailable:
            return "Unavailable"
        }
    }

    var secondaryValue: String? {
        guard case .available(_, let partialCount) = self else { return nil }
        return "\(partialCount) partial"
    }
}

enum SettingsPresentation {
    static func completedImports(
        from attempts: [RepositoryImportAttempt],
        persistenceState: PersistenceState
    ) -> SettingsCompletedImportsPresentation {
        guard persistenceState.isDurable else {
            return .unavailable
        }

        let completedAttempts = attempts.filter {
            [$0.outcomeCode].contains(where: {
                $0 == ImportAttemptOutcome.successfulImport.rawValue ||
                $0 == ImportAttemptOutcome.partialImportCommitted.rawValue
            }) &&
            $0.persistenceCode == ImportAttemptPersistence.committed.rawValue &&
            $0.importSessionId != nil &&
            $0.documentId != nil
        }
        let completedSessionIDs = Set(completedAttempts.compactMap(\.importSessionId))
        let partialSessionIDs = Set(completedAttempts.compactMap {
            $0.outcomeCode == ImportAttemptOutcome.partialImportCommitted.rawValue
                ? $0.importSessionId
                : nil
        })
        return .available(completedSessionIDs.count, partialCount: partialSessionIDs.count)
    }

    static func applicationVersion(infoDictionary: [String: Any]?) -> String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String
        let build = infoDictionary?["CFBundleVersion"] as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "\(version) (\(build))"
        case let (.some(version), nil):
            return version
        case let (nil, .some(build)):
            return "Build \(build)"
        case (nil, nil):
            return "Unavailable"
        }
    }
}
import UniformTypeIdentifiers

private enum SettingsSubsection: String {
    case appearance = "Appearance"
    case liveFX = "Live FX"
    case ispAccount = "ISP Account"
    case backup = "Backup & Restore"
    case categories = "Categories"

    var systemImage: String {
        switch self {
        case .appearance: "paintpalette"
        case .liveFX: "arrow.triangle.2.circlepath"
        case .ispAccount: "link"
        case .backup: "externaldrive"
        case .categories: "tag"
        }
    }
}

enum AppShellSection: String, CaseIterable {
    case dashboard = "Dashboard"
    case accounts = "Accounts"
    case investments = "Investments"
    case transactions = "Transactions"
    case imports = "Import"
    case salary = "Budget Planning"
    case settings = "Settings"
    case developer = "Developer Console"

    static let ordinaryNavigation: [AppShellSection] = [
        .dashboard,
        .accounts,
        .investments,
        .salary,
        .transactions,
        .imports,
        .settings
    ]

    static func developerConsoleVisible(developerModeEnabled: Bool) -> Bool {
#if DEBUG
        return developerModeEnabled
#else
        return false
#endif
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "house"
        case .accounts:
            return "wallet.pass"
        case .investments:
            return "chart.pie"
        case .transactions:
            return "arrow.left.arrow.right.square"
        case .imports:
            return "square.and.arrow.down"
        case .salary:
            return "banknote"
        case .settings:
            return "gearshape"
        case .developer:
            return "arrow.up.left.and.arrow.down.right"
        }
    }
}

#if DEBUG
private enum ProtectedImportIntent {
    case presentFileImporter
    case prepareURLs([URL])
    case retryPreparation
    case prepareRecoveryURL(
        URL,
        contextID: UUID,
        route: ConfirmedImportRecoveryRoute
    )
    case confirm(PreparedImport)

    var protectedAction: DevelopmentProtectedAction {
        switch self {
        case .presentFileImporter, .prepareURLs, .retryPreparation, .prepareRecoveryURL:
            return .importPreparation
        case .confirm:
            return .importConfirmation
        }
    }
}
#endif

enum ImportPresentationState {
    case idle
    case preparing(fileName: String, phase: ImportProgressPhase)
    case previewReady(PreparedImport)
    case validationFailed(PreparedImport)
    case committing(PreparedImport)
    case completed(ImportOutcomePresentation)
    case skipped(fileName: String)
    case cancelled(fileName: String)
    case failed(fileName: String, message: String, retrySourceURL: URL?)
}

enum ImportFooterPresentation {
    enum Kind: Equatable {
        case confirmation
        case importing
        case retryPreparation
        case viewTransactions
        case none
    }

    case confirmation(PreparedImport)
    case importing
    case retryPreparation(URL)
    case viewTransactions
    case none

    static func presentation(for state: ImportPresentationState) -> Self {
        switch state {
        case .previewReady(let preparedImport):
            return .confirmation(preparedImport)
        case .committing:
            return .importing
        case .failed(_, _, let retrySourceURL?):
            return .retryPreparation(retrySourceURL)
        case .completed(let outcome) where outcome.allowsViewingTransactions:
            return .viewTransactions
        default:
            return .none
        }
    }

    var kind: Kind {
        switch self {
        case .confirmation:
            return .confirmation
        case .importing:
            return .importing
        case .retryPreparation:
            return .retryPreparation
        case .viewTransactions:
            return .viewTransactions
        case .none:
            return .none
        }
    }
}

enum ValidationReviewPresentation {
    enum Kind: Equatable {
        case noStatementPrepared
        case validationResults
        case completedOutcome
    }

    case noStatementPrepared
    case validationResults(PreparedImport)
    case completedOutcome(ImportOutcomePresentation)

    static func presentation(for state: ImportPresentationState) -> Self {
        switch state {
        case .previewReady(let preparedImport),
             .validationFailed(let preparedImport),
             .committing(let preparedImport):
            return .validationResults(preparedImport)
        case .completed(let outcome):
            return .completedOutcome(outcome)
        default:
            return .noStatementPrepared
        }
    }

    var kind: Kind {
        switch self {
        case .noStatementPrepared:
            return .noStatementPrepared
        case .validationResults:
            return .validationResults
        case .completedOutcome:
            return .completedOutcome
        }
    }
}

private extension ImportPresentationState {
    var isTerminal: Bool {
        switch self {
        case .completed, .skipped, .cancelled, .failed:
            return true
        default:
            return false
        }
    }

    var showsPreConfirmationNoWriteMessage: Bool {
        switch self {
        case .completed:
            return false
        default:
            return true
        }
    }
}

enum ImportOutcomeTone: Equatable {
    case success
    case warning
    case danger

    var color: Color {
        switch self {
        case .success:
            return LFTheme.success
        case .warning:
            return LFTheme.warning
        case .danger:
            return LFTheme.danger
        }
    }
}

enum ConfirmedImportRecoveryAction: Equatable, Sendable {
    case prepareAgain
    case retryCanonicalReconciliation
    case retryCanonicalReconciliationThenPrepareAgain

    var label: String {
        switch self {
        case .prepareAgain:
            return "Prepare Again"
        case .retryCanonicalReconciliation,
                .retryCanonicalReconciliationThenPrepareAgain:
            return "Retry Reconciliation"
        }
    }

    var requiresSourceURL: Bool {
        switch self {
        case .prepareAgain, .retryCanonicalReconciliationThenPrepareAgain:
            return true
        case .retryCanonicalReconciliation:
            return false
        }
    }
}

struct ConfirmedImportRecoveryPresentation: Equatable {
    let title: String
    let explanation: String
    let primaryAction: ConfirmedImportRecoveryAction?
    let iconName: String
    let tone: ImportOutcomeTone

    var primaryActionLabel: String? {
        primaryAction?.label
    }

    var accessibilityText: String {
        [title, explanation, primaryActionLabel]
            .compactMap { $0 }
            .joined(separator: ". ")
    }

    func availablePrimaryAction(hasSourceURL: Bool) -> ConfirmedImportRecoveryAction? {
        guard let primaryAction else { return nil }
        return primaryAction.requiresSourceURL && !hasSourceURL ? nil : primaryAction
    }
}

enum ConfirmedImportRecoveryPresentationMapper {
    static func presentation(
        for route: ConfirmedImportRecoveryRoute
    ) -> ConfirmedImportRecoveryPresentation? {
        switch route {
        case .none:
            return nil
        case .prepareAgain(let reason):
            return prepareAgainPresentation(for: reason)
        case .retryCanonicalReconciliation:
            return ConfirmedImportRecoveryPresentation(
                title: "Saved — Reconciliation Required",
                explanation: "The import was saved, but the current view could not be refreshed. Retrying reconciliation refreshes from durable state and does not import again.",
                primaryAction: .retryCanonicalReconciliation,
                iconName: "arrow.triangle.2.circlepath.circle.fill",
                tone: .warning
            )
        case .retryCanonicalReconciliationThenPrepareAgain:
            return ConfirmedImportRecoveryPresentation(
                title: "Not Saved — Reconciliation Required",
                explanation: "An earlier saved import still needs reconciliation, so no new import was saved. Retry Reconciliation refreshes durable state first; only after success, it starts a wholly fresh preparation from the retained source. A new confirmation is still required.",
                primaryAction: .retryCanonicalReconciliationThenPrepareAgain,
                iconName: "arrow.triangle.2.circlepath.circle.fill",
                tone: .warning
            )
        case .reviewRequired(let reason):
            return reviewPresentation(for: reason)
        case .unavailable:
            return ConfirmedImportRecoveryPresentation(
                title: "Recovery Unavailable",
                explanation: "Recovery is unavailable because this state cannot safely authorize another operation.",
                primaryAction: nil,
                iconName: "questionmark.circle.fill",
                tone: .warning
            )
        }
    }

    private static func prepareAgainPresentation(
        for reason: ConfirmedImportRecoveryReason
    ) -> ConfirmedImportRecoveryPresentation {
        let reasonCopy: (title: String, explanation: String, iconName: String)
        switch reason {
        case .sourceSnapshotIntegrityFailed:
            reasonCopy = (
                "Source Verification Changed",
                "The prepared source evidence could not be verified.",
                "checkmark.shield.trianglebadge.exclamationmark"
            )
        case .staleProviderGeneration:
            reasonCopy = (
                "Preparation Out of Date",
                "Persistence changed after the preparation was created.",
                "arrow.triangle.2.circlepath"
            )
        case .reviewedPartialPlanStale:
            reasonCopy = (
                "Reviewed Plan Out of Date",
                "The reviewed partial-import plan is no longer current.",
                "clock.badge.exclamationmark.fill"
            )
        case .persistenceContention:
            reasonCopy = (
                "Persistence Temporarily Busy",
                "The confirmed write did not obtain exclusive persistence access.",
                "hourglass"
            )
        case .persistenceUnavailable:
            reasonCopy = (
                "Persistence Unavailable",
                "Durable persistence was unavailable for the confirmed operation.",
                "externaldrive.badge.exclamationmark"
            )
        case .validationFailed, .exactStatementDuplicate, .transactionEventBlock,
                .accountChoiceRequired, .accountChoiceStale, .identityAmbiguous,
                .identityConflict, .identifierOwnershipConflict,
                .repositoryIntegrityConflict:
            return unavailablePresentationForMismatchedReason()
        }

        return ConfirmedImportRecoveryPresentation(
            title: reasonCopy.title,
            explanation: "\(reasonCopy.explanation) No new financial history was written. Prepare Again reads the selected source again, creates new source evidence, binds the preparation to current persistence, repeats validation, duplicate, identity, and account-choice review, and requires a new explicit confirmation.",
            primaryAction: .prepareAgain,
            iconName: reasonCopy.iconName,
            tone: .warning
        )
    }

    private static func reviewPresentation(
        for reason: ConfirmedImportRecoveryReason
    ) -> ConfirmedImportRecoveryPresentation {
        switch reason {
        case .validationFailed:
            return reviewPresentation(
                title: "Validation Review Required",
                explanation: "The prepared content did not pass validation. Review the validation findings before beginning a separate import.",
                iconName: "checkmark.shield.trianglebadge.exclamationmark"
            )
        case .exactStatementDuplicate:
            return reviewPresentation(
                title: "Already Imported",
                explanation: "The statement matches a prior completed import. Review the prior import; no new import was saved.",
                iconName: "doc.on.doc.fill"
            )
        case .transactionEventBlock:
            return reviewPresentation(
                title: "Transaction Review Required",
                explanation: "Supported transaction-event checks blocked this statement. Review the bounded conflict before beginning a separate import.",
                iconName: "arrow.left.arrow.right.circle.fill"
            )
        case .accountChoiceRequired:
            return reviewPresentation(
                title: "Account Choice Required",
                explanation: "The prepared import needs an explicit eligible account decision. Review the account choices before beginning a separate import.",
                iconName: "person.crop.circle.badge.questionmark"
            )
        case .accountChoiceStale:
            return reviewPresentation(
                title: "Account Choice Out of Date",
                explanation: "The reviewed account choice is no longer available or eligible. Begin a separate preparation before choosing again.",
                iconName: "person.crop.circle.badge.exclamationmark"
            )
        case .identityAmbiguous:
            return reviewPresentation(
                title: "Account Identity Ambiguous",
                explanation: "Verified identity evidence does not resolve to one account. Review the account decision before beginning a separate import.",
                iconName: "person.crop.circle.badge.questionmark"
            )
        case .identityConflict:
            return reviewPresentation(
                title: "Account Identity Conflict",
                explanation: "Verified identity evidence conflicts with existing account ownership. Review the account decision before beginning a separate import.",
                iconName: "person.crop.circle.badge.exclamationmark"
            )
        case .identifierOwnershipConflict:
            return reviewPresentation(
                title: "Identifier Ownership Conflict",
                explanation: "Verified identifier ownership conflicts with the reviewed account decision. Review the account decision before beginning a separate import.",
                iconName: "person.text.rectangle"
            )
        case .repositoryIntegrityConflict:
            return reviewPresentation(
                title: "Integrity Review Required",
                explanation: "Repository integrity checks blocked the operation. Review the recorded outcome before beginning a separate import.",
                iconName: "exclamationmark.shield.fill"
            )
        case .sourceSnapshotIntegrityFailed, .staleProviderGeneration,
                .reviewedPartialPlanStale, .persistenceContention,
                .persistenceUnavailable:
            return unavailablePresentationForMismatchedReason()
        }
    }

    private static func reviewPresentation(
        title: String,
        explanation: String,
        iconName: String
    ) -> ConfirmedImportRecoveryPresentation {
        ConfirmedImportRecoveryPresentation(
            title: title,
            explanation: explanation,
            primaryAction: nil,
            iconName: iconName,
            tone: .warning
        )
    }

    private static func unavailablePresentationForMismatchedReason()
        -> ConfirmedImportRecoveryPresentation {
        ConfirmedImportRecoveryPresentation(
            title: "Recovery Unavailable",
            explanation: "Recovery is unavailable because this state cannot safely authorize another operation.",
            primaryAction: nil,
            iconName: "questionmark.circle.fill",
            tone: .warning
        )
    }
}

enum ConfirmedImportRecoveryActionExecutionResult: Equatable {
    case unavailable
    case preparationRequested
    case reconciliationSucceeded
    case reconciliationFailed
}

final class ConfirmedImportRecoveryActionExecutor {
    @MainActor private(set) var activeOperationID: UUID?

    @MainActor
    func execute(
        _ action: ConfirmedImportRecoveryAction,
        sourceURL: URL?,
        retryCanonicalReconciliation: () async -> Bool,
        requestOrdinaryPreparation: (URL) async -> Bool
    ) async -> ConfirmedImportRecoveryActionExecutionResult {
        guard activeOperationID == nil else { return .unavailable }
        if action.requiresSourceURL && sourceURL == nil {
            return .unavailable
        }

        let operationID = UUID()
        activeOperationID = operationID
        defer {
            if activeOperationID == operationID {
                activeOperationID = nil
            }
        }

        switch action {
        case .prepareAgain:
            guard let sourceURL else { return .unavailable }
            return await requestOrdinaryPreparation(sourceURL)
                ? .preparationRequested
                : .unavailable
        case .retryCanonicalReconciliation:
            return await retryCanonicalReconciliation()
                ? .reconciliationSucceeded
                : .reconciliationFailed
        case .retryCanonicalReconciliationThenPrepareAgain:
            guard let sourceURL else { return .unavailable }
            guard await retryCanonicalReconciliation() else {
                return .reconciliationFailed
            }
            return await requestOrdinaryPreparation(sourceURL)
                ? .preparationRequested
                : .unavailable
        }
    }
}

struct ConfirmedImportRecoveryContext {
    let id = UUID()
    let route: ConfirmedImportRecoveryRoute
    let sourceURL: URL?
}

extension ImportAccountOutcomePresentation {
    var accessibilityText: String {
        "\(label). \(explanation)"
    }
}

struct ImportAccountOutcomeView: View {
    @Environment(\.lfTheme) private var theme
    let presentation: ImportAccountOutcomePresentation
    let iconName: String
    let tone: ImportOutcomeTone

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(tone.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.label)
                    .font(theme.typography.formBody.weight(.semibold))
                Text(presentation.explanation)
                    .font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tone.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityText)
    }
}

struct ImportIdentityReviewUIProjection: Equatable {
    let presentation: ImportAccountOutcomePresentation?
    let iconName: String?
    let tone: ImportOutcomeTone
    let matchedAccountID: String?
    let eligibleAccountIDs: [String]

    init(review: ImportIdentityReview) {
        switch review {
        case .unavailable:
            presentation = nil
            iconName = nil
            tone = .warning
            matchedAccountID = nil
            eligibleAccountIDs = []
        case .matchedExisting(let accountID):
            presentation = ImportAccountOutcomePresentationMapper.presentation(for: .matchedExisting)
            iconName = "person.crop.circle.badge.checkmark"
            tone = .success
            matchedAccountID = accountID
            eligibleAccountIDs = []
        case .choiceRequired(let eligibleAccountIDs):
            presentation = ImportAccountOutcomePresentationMapper.presentation(for: .choiceRequired)
            iconName = "person.crop.circle.badge.questionmark"
            tone = .warning
            matchedAccountID = nil
            self.eligibleAccountIDs = eligibleAccountIDs
        case .liabilityAccountChoiceRequired(let eligibleLiabilityAccountIDs):
            presentation = ImportAccountOutcomePresentation(
                label: "Choose a liability account",
                explanation: "This Axis credit-card statement has no instrument sections. Choose an eligible existing liability account or create a separate one."
            )
            iconName = "creditcard.badge.questionmark"
            tone = .warning
            matchedAccountID = nil
            self.eligibleAccountIDs = eligibleLiabilityAccountIDs
        case .cardChoiceRequired(let eligibleLiabilityAccountIDs):
            presentation = ImportAccountOutcomePresentationMapper.presentation(for: .choiceRequired)
            iconName = "creditcard.badge.questionmark"
            tone = .warning
            matchedAccountID = nil
            self.eligibleAccountIDs = eligibleLiabilityAccountIDs
        case .ambiguous:
            presentation = ImportAccountOutcomePresentationMapper.presentation(for: .identityAmbiguous)
            iconName = "person.crop.circle.badge.questionmark"
            tone = .warning
            matchedAccountID = nil
            eligibleAccountIDs = []
        case .conflict:
            presentation = ImportAccountOutcomePresentationMapper.presentation(for: .identityConflict)
            iconName = "person.crop.circle.badge.exclamationmark"
            tone = .warning
            matchedAccountID = nil
            eligibleAccountIDs = []
        }
    }
}

enum ImportAccountConfirmationPolicy {
    static func initialChoice(for _: ImportIdentityReview) -> ImportAccountChoice? {
        nil
    }

    static func allowsConfirmation(
        review: ImportIdentityReview,
        choice: ImportAccountChoice?,
        requiredCardSectionIDs: [String]? = nil,
        requiresNamedCreation: Bool = false
    ) -> Bool {
        if let name = choice?.proposedAccountDisplayName,
           name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        switch (review, choice) {
        case (.matchedExisting, _):
            return true
        case (.unavailable, let choice):
            guard requiresNamedCreation else { return true }
            if case .createNewAccount = choice { return true }
            return false
        case let (.choiceRequired(eligibleAccountIDs), .some(.useExistingAccount(accountID))):
            return eligibleAccountIDs.contains(accountID)
        case (.choiceRequired, .some(.createNewAccount)):
            return true
        case let (.liabilityAccountChoiceRequired(eligibleAccountIDs), .some(.useExistingAccount(accountID))):
            return eligibleAccountIDs.contains(accountID)
        case (.liabilityAccountChoiceRequired, .some(.createNewAccount)):
            return true
        case let (.cardChoiceRequired(eligibleAccountIDs), .some(.useExistingCardLiabilityAccount(accountID, instrumentChoice))):
            return eligibleAccountIDs.contains(accountID) && instrumentChoice.isComplete &&
                (requiredCardSectionIDs == nil || requiredCardSectionIDs?.count == 1)
        case let (.cardChoiceRequired(eligibleAccountIDs), .some(.useExistingCardLiabilityAccountSections(accountID, sectionChoices))):
            return eligibleAccountIDs.contains(accountID) && sectionChoices.values.allSatisfy(\.isComplete) &&
                (requiredCardSectionIDs.map { Set($0) == Set(sectionChoices.keys) } ?? !sectionChoices.isEmpty)
        case (.cardChoiceRequired, .some(.createNewCardLiabilityAccountAndInstrument)):
            return true
        case (.choiceRequired, _), (.liabilityAccountChoiceRequired, _),
                (.cardChoiceRequired, _), (.ambiguous, _), (.conflict, _):
            return false
        }
    }
}

enum DurableImportAccountOutcomeSection {
    static func presentation(
        for attempt: RepositoryImportAttempt
    ) -> ImportAccountOutcomePresentation? {
        presentation(
            outcomeCode: attempt.outcomeCode,
            accountDecisionCode: attempt.accountDecisionCode
        )
    }

    static func presentation(
        outcomeCode: String,
        accountDecisionCode: String
    ) -> ImportAccountOutcomePresentation? {
        if let outcome = ImportAttemptOutcome(rawValue: outcomeCode) {
            switch outcome {
            case .successfulImport, .cbqSourceOverlapCommitted, .partialImportCommitted, .accountChoiceRequired,
                    .identifierOwnershipConflict, .identityAmbiguity, .identityConflict,
                    .staleAccountChoice, .staleProviderGeneration:
                return ImportAccountOutcomePresentationMapper.presentation(
                    outcomeCode: outcomeCode,
                    accountDecisionCode: accountDecisionCode
                )
            case .equivalentSourceRecorded, .statementEquivalenceConflict,
                    .statementEquivalenceEvidenceUnavailable, .equivalentFormatAlreadyRecorded,
                    .reviewedPartialPlanStale, .partialImportUnsupportedEvidence,
                    .validationFailure, .persistenceFailure, .exactStatementDuplicate,
                    .existingEligibleAxisUPIEvent, .repeatedEligibleIncomingEvidence,
                    .transactionEventOwnershipConflict, .repositoryIntegrityConflict,
                    .sqliteContention, .sourceSnapshotAcquisitionFailed,
                    .sourceSnapshotIntegrityFailed:
                return nil
            }
        }

        guard let decision = ImportAttemptAccountDecision(rawValue: accountDecisionCode) else {
            return nil
        }
        switch decision {
        case .matchedExisting, .userSelectedExisting, .createdNew,
                .resolvedOrCreated, .selectedExisting:
            return ImportAccountOutcomePresentationMapper.presentation(
                outcomeCode: outcomeCode,
                accountDecisionCode: accountDecisionCode
            )
        case .noFinancialMutation, .sideEffectsMayExist:
            return nil
        }
    }
}

struct DurableImportPresentationValue: Equatable {
    let label: String
    let explanation: String
    let iconName: String
    let tone: ImportOutcomeTone
}

struct DurableImportAttemptPresentation: Equatable {
    let outcome: DurableImportPresentationValue
    let coverage: String
    let guidance: String

    init(attempt: RepositoryImportAttempt) {
        outcome = Self.outcome(
            code: attempt.outcomeCode,
            transactionCount: attempt.transactionCount
        )
        coverage = Self.coverage(code: attempt.coverageCode)
        guidance = Self.guidance(code: attempt.guidanceCode)
    }

    nonisolated static func outcome(
        code: String,
        transactionCount: Int
    ) -> DurableImportPresentationValue {
        guard let outcome = ImportAttemptOutcome(rawValue: code) else {
            return DurableImportPresentationValue(
                label: "Outcome unavailable",
                explanation: "A durable import outcome is unavailable",
                iconName: "questionmark.circle.fill",
                tone: .warning
            )
        }

        switch outcome {
        case .successfulImport:
            return DurableImportPresentationValue(
                label: "Import completed",
                explanation: transactionCount == 0 ? "Statement data saved" : "Persisted \(transactionCount) transaction(s)",
                iconName: "checkmark.circle.fill",
                tone: .success
            )
        case .equivalentSourceRecorded:
            return DurableImportPresentationValue(
                label: "Equivalent source recorded",
                explanation: "Recorded equivalent source evidence and persisted 0 additional transactions",
                iconName: "checkmark.seal.fill",
                tone: .success
            )
        case .cbqSourceOverlapCommitted:
            return DurableImportPresentationValue(
                label: "CBQ source recorded",
                explanation: "Recorded exact CBQ source lineage and persisted \(transactionCount) new transaction(s)",
                iconName: "checkmark.seal.fill",
                tone: .success
            )
        case .statementEquivalenceConflict:
            return DurableImportPresentationValue(
                label: "Statement equivalence conflict",
                explanation: "The same statement period differs financially across formats. No new financial history was written",
                iconName: "exclamationmark.triangle.fill",
                tone: .danger
            )
        case .statementEquivalenceEvidenceUnavailable:
            return DurableImportPresentationValue(
                label: "Equivalence evidence unavailable",
                explanation: "Existing overlapping history lacks exact projection evidence. No new financial history was written",
                iconName: "questionmark.diamond.fill",
                tone: .warning
            )
        case .equivalentFormatAlreadyRecorded:
            return DurableImportPresentationValue(
                label: "Format already recorded",
                explanation: "This source format is already represented for the statement period. No new financial history was written",
                iconName: "doc.on.doc.fill",
                tone: .warning
            )
        case .partialImportCommitted:
            return DurableImportPresentationValue(
                label: "Partial import completed",
                explanation: "Persisted \(transactionCount) new transaction(s) from a reviewed partial statement",
                iconName: "checkmark.circle.fill",
                tone: .success
            )
        case .reviewedPartialPlanStale:
            return DurableImportPresentationValue(
                label: "Partial review out of date",
                explanation: "Repository truth changed after review. No new financial history was written",
                iconName: "arrow.triangle.2.circlepath",
                tone: .warning
            )
        case .partialImportUnsupportedEvidence:
            return DurableImportPresentationValue(
                label: "Partial import unavailable",
                explanation: "The complete statement does not meet the supported partial-import evidence boundary",
                iconName: "exclamationmark.triangle.fill",
                tone: .warning
            )
        case .validationFailure:
            return DurableImportPresentationValue(
                label: "Validation failed",
                explanation: "Validation failed before persistence",
                iconName: "xmark.octagon.fill",
                tone: .danger
            )
        case .persistenceFailure:
            return DurableImportPresentationValue(
                label: "Persistence failed",
                explanation: "Persistence failed after validation",
                iconName: "exclamationmark.triangle.fill",
                tone: .warning
            )
        case .exactStatementDuplicate:
            return DurableImportPresentationValue(
                label: "Previously imported",
                explanation: "The exact statement was already imported. No new financial history was written",
                iconName: "doc.on.doc.fill",
                tone: .warning
            )
        case .existingEligibleAxisUPIEvent:
            return DurableImportPresentationValue(
                label: "Supported transaction event blocked",
                explanation: "A supported transaction event already exists. No new financial history was written",
                iconName: "exclamationmark.triangle.fill",
                tone: .warning
            )
        case .repeatedEligibleIncomingEvidence:
            return DurableImportPresentationValue(
                label: "Repeated incoming evidence",
                explanation: "Supported transaction evidence repeats within this import. No new financial history was written",
                iconName: "exclamationmark.triangle.fill",
                tone: .warning
            )
        case .transactionEventOwnershipConflict:
            return DurableImportPresentationValue(
                label: "Transaction-event ownership conflict",
                explanation: "Supported transaction-event ownership conflicts. No new financial history was written",
                iconName: "exclamationmark.triangle.fill",
                tone: .warning
            )
        case .repositoryIntegrityConflict:
            return DurableImportPresentationValue(
                label: "Repository integrity conflict",
                explanation: "Repository integrity prevented confirmation. No new financial history was written",
                iconName: "exclamationmark.triangle.fill",
                tone: .warning
            )
        case .accountChoiceRequired:
            return DurableImportPresentationValue(
                label: "Choose an account",
                explanation: "No existing account owns this verified identifier. Choose an eligible account or create a new one.",
                iconName: "person.crop.circle.badge.questionmark",
                tone: .warning
            )
        case .identifierOwnershipConflict:
            return DurableImportPresentationValue(
                label: "Identifier ownership conflict",
                explanation: "Verified identifier ownership changed or conflicted before confirmation. No financial history was written.",
                iconName: "person.crop.circle.badge.exclamationmark",
                tone: .warning
            )
        case .identityAmbiguity:
            return DurableImportPresentationValue(
                label: "Account identity ambiguous",
                explanation: "Account identity could not be resolved unambiguously. No new financial history was written",
                iconName: "person.crop.circle.badge.questionmark",
                tone: .warning
            )
        case .identityConflict:
            return DurableImportPresentationValue(
                label: "Account identity conflict",
                explanation: "Account identity conflicts across accounts. No new financial history was written",
                iconName: "person.crop.circle.badge.exclamationmark",
                tone: .warning
            )
        case .staleAccountChoice:
            return DurableImportPresentationValue(
                label: "Account choice out of date",
                explanation: "The prepared account choice is no longer current. No new financial history was written",
                iconName: "clock.badge.exclamationmark.fill",
                tone: .warning
            )
        case .staleProviderGeneration:
            return DurableImportPresentationValue(
                label: "Persistence changed",
                explanation: "Persistence changed after preparation. No new financial history was written",
                iconName: "arrow.triangle.2.circlepath",
                tone: .warning
            )
        case .sqliteContention:
            return DurableImportPresentationValue(
                label: "Persistence busy",
                explanation: "Confirmation did not win persistence contention. No new financial history was written",
                iconName: "hourglass",
                tone: .warning
            )
        case .sourceSnapshotAcquisitionFailed:
            return DurableImportPresentationValue(
                label: "Source could not be read",
                explanation: "Source snapshot acquisition failed. No financial history was written",
                iconName: "doc.badge.exclamationmark",
                tone: .warning
            )
        case .sourceSnapshotIntegrityFailed:
            return DurableImportPresentationValue(
                label: "Prepared source could not be verified",
                explanation: "Source snapshot integrity verification failed. No financial history was written",
                iconName: "checkmark.shield.trianglebadge.exclamationmark",
                tone: .warning
            )
        }
    }

    nonisolated static func coverage(code: String) -> String {
        guard let coverage = ImportAttemptCoverage(rawValue: code) else {
            return "Coverage unavailable"
        }
        switch coverage {
        case .evaluatedSupportedOnly:
            return "Supported transaction-event checks evaluated"
        case .allRowsSupportedAxisUPIReviewed:
            return "Every row reviewed with supported account-scoped Axis UPI evidence"
        case .unsupportedOrUnevaluated:
            return "Some transaction-event families unsupported or not evaluated"
        }
    }

    nonisolated static func guidance(code: String) -> String {
        guard let guidance = ImportAttemptGuidance(rawValue: code) else {
            return "Guidance unavailable"
        }
        switch guidance {
        case .importCompleted:
            return "Import completed"
        case .equivalentSourceRecorded:
            return "Equivalent source evidence recorded; no additional transactions were created"
        case .partialImportCompleted:
            return "Reviewed partial import completed"
        case .reviewPriorImport:
            return "Review the prior import"
        case .supportedEventBlocked:
            return "Review the supported transaction-event block"
        case .correctValidationAndRetry:
            return "Correct validation issues before retrying"
        case .persistenceUnavailable:
            return "Persistence is unavailable"
        case .integrityReviewRequired:
            return "Review required"
        case .prepareAgain:
            return "Prepare the import again"
        case .retryConfirmation:
            return "Retry confirmation"
        }
    }
}

struct ImportOutcomePresentation: Equatable {
    var fileName: String
    let transactionCount: Int
    let persisted: Bool
    let validationPassed: Bool
    let validationStatus: String
    var persistenceStatus: String
    var message: String?
    var allowsViewingTransactions: Bool
    var iconName: String
    var tone: ImportOutcomeTone
    let accountId: String?
    let importSessionId: String?
    let importAttemptID: String?
    let redactedIdentifier: String?
    let previousImportCompletedAtISO: String?
    let previousAccountDisplayName: String?
    let isPreviouslyImported: Bool
    let transactionEventBlock: TransactionEventBlock?
    var recoveryRoute: ConfirmedImportRecoveryRoute
    let isPartialImport: Bool
    let isEquivalentSupportingSource: Bool
    let isSalaryImport: Bool
    let isInvestmentImport: Bool
    let sourceRowCount: Int?
    let recognizedExistingRowCount: Int?
    let accountOutcomePresentation: ImportAccountOutcomePresentation?
    var recoveryContextID: UUID?

    init(result: ImportEngineResult) {
        fileName = result.fileName
        transactionCount = result.transactionCount
        persisted = result.persisted
        validationPassed = result.validationPassed
        validationStatus = result.validationPassed ? "Validation Passed" : "Validation Failed"
        allowsViewingTransactions = Self.provesCommittedSuccess(result)
            && !result.isEquivalentSupportingSource
            && !result.isSalaryImport
            && !result.isInvestmentImport
            && (result.recoveryRoute == .none || result.recoveryRoute == .unavailable)
        accountId = result.accountId
        importSessionId = result.importSessionId
        importAttemptID = result.importAttemptId
        redactedIdentifier = result.redactedIdentifier
        previousImportCompletedAtISO = result.previousImport?.completedAtISO
        previousAccountDisplayName = result.previousImport?.accountDisplayName
        isPreviouslyImported = result.previousImport != nil
        transactionEventBlock = result.transactionEventBlock
        recoveryRoute = result.recoveryRoute
        isPartialImport = result.isPartialImport
        isEquivalentSupportingSource = result.isEquivalentSupportingSource
        isSalaryImport = result.isSalaryImport
        isInvestmentImport = result.isInvestmentImport
        sourceRowCount = result.sourceRowCount
        recognizedExistingRowCount = result.recognizedExistingRowCount
        accountOutcomePresentation = result.accountOutcome == .unavailable
            ? nil
            : ImportAccountOutcomePresentationMapper.presentation(for: result.accountOutcome)
        recoveryContextID = nil

        if result.recoveryRoute == .unavailable && !result.persisted {
            let failure = result.validationPassed ? "Import persistence failed." : "Import validation failed."
            let history = result.importAttemptId != nil
                ? "The failure was added to Import History."
                : "The failure could not be added to Import History."
            message = "\(failure) \(history)"
        } else {
            message = nil
        }

        switch result.recoveryRoute {
        case .retryCanonicalReconciliation:
            persistenceStatus = "Saved — Reconciliation Required"
            iconName = "arrow.triangle.2.circlepath.circle.fill"
            tone = .warning
        case .retryCanonicalReconciliationThenPrepareAgain:
            persistenceStatus = "Not Saved — Reconciliation Required"
            iconName = "arrow.triangle.2.circlepath.circle.fill"
            tone = .warning
        case .prepareAgain:
            persistenceStatus = "Not Saved — Fresh Preparation Required"
            iconName = "arrow.clockwise.circle.fill"
            tone = .warning
        case .reviewRequired(.exactStatementDuplicate):
            persistenceStatus = "Previously Imported"
            iconName = "checkmark.circle.fill"
            tone = .warning
        case .reviewRequired(.transactionEventBlock):
            persistenceStatus = "Statement Blocked"
            iconName = "exclamationmark.triangle.fill"
            tone = .warning
        case .reviewRequired(.validationFailed):
            persistenceStatus = "Not Persisted"
            iconName = "xmark.octagon.fill"
            tone = .danger
        case .reviewRequired:
            persistenceStatus = "Review Required"
            iconName = "exclamationmark.triangle.fill"
            tone = .warning
        case .none:
            if Self.provesCommittedSuccess(result) {
                persistenceStatus = result.isEquivalentSupportingSource
                    ? "Equivalent Source Recorded"
                    : (result.isPartialImport ? "Partial Import Succeeded" : "Persistence Succeeded")
                iconName = "checkmark.circle.fill"
                tone = .success
            } else {
                persistenceStatus = "Outcome Unavailable"
                iconName = "questionmark.circle.fill"
                tone = .warning
            }
        case .unavailable:
            if Self.provesCommittedSuccess(result) {
                persistenceStatus = result.isEquivalentSupportingSource
                    ? "Equivalent Source Recorded"
                    : (result.isPartialImport ? "Partial Import Succeeded" : "Persistence Succeeded")
                iconName = "checkmark.circle.fill"
                tone = .success
            } else if !result.validationPassed {
                persistenceStatus = "Not Persisted"
                iconName = "xmark.octagon.fill"
                tone = .danger
            } else if !result.persisted {
                persistenceStatus = "Persistence Failed"
                iconName = "exclamationmark.triangle.fill"
                tone = .warning
            } else {
                persistenceStatus = "Outcome Unavailable"
                iconName = "questionmark.circle.fill"
                tone = .warning
            }
        }
    }

    var requiresReconciliation: Bool {
        recoveryRoute == .retryCanonicalReconciliation
    }

    var recoveryPresentation: ConfirmedImportRecoveryPresentation? {
        ConfirmedImportRecoveryPresentationMapper.presentation(for: recoveryRoute)
    }

    var fileSubtitle: String {
        switch recoveryRoute {
        case .retryCanonicalReconciliation:
            return "Import saved; the current view needs reconciliation"
        case .retryCanonicalReconciliationThenPrepareAgain:
            return "No new import was saved"
        case .prepareAgain:
            return "No new financial history was written"
        case .reviewRequired(.exactStatementDuplicate):
            return "Previously imported — no new data written"
        case .reviewRequired:
            return "No new import was saved"
        case .none, .unavailable:
            break
        }
        if isPartialImport {
            return "Partial import — \(transactionCount) new, \(recognizedExistingRowCount ?? 0) already represented, \(sourceRowCount ?? transactionCount) source rows"
        }
        if isEquivalentSupportingSource {
            return "Equivalent source evidence recorded — 0 additional transactions"
        }
        if isInvestmentImport && persisted { return "Current holdings updated — available in Investments" }
        if isSalaryImport && persistenceStatus.hasPrefix("Persistence") {
            return "Imported Salary actual — source truth is available in Salary History"
        }
        if allowsViewingTransactions {
            return "Imported \(transactionCount) transaction(s)"
        }

        return "Processed \(transactionCount) transaction(s)"
    }

    func markingReconciled() -> ImportOutcomePresentation {
        guard recoveryRoute == .retryCanonicalReconciliation else { return self }
        var copy = self
        copy.recoveryRoute = .none
        copy.recoveryContextID = nil
        copy.allowsViewingTransactions = !isSalaryImport && !isInvestmentImport
        copy.persistenceStatus = isPartialImport ? "Partial Import Succeeded" : "Persistence Succeeded"
        copy.message = nil
        copy.iconName = "checkmark.circle.fill"
        copy.tone = .success
        return copy
    }

    private static func provesCommittedSuccess(_ result: ImportEngineResult) -> Bool {
        guard result.validationPassed,
              result.persisted,
              result.hydrationOutcome == .committedAndHydrated,
              result.errorMessage == nil,
              result.previousImport == nil,
              result.transactionEventBlock == nil else {
            return false
        }
        switch result.accountOutcome {
        case .matchedExisting, .userSelectedExisting, .createdNew, .unavailable:
            return true
        case .choiceRequired, .identityAmbiguous, .identityConflict,
                .identifierOwnershipConflict, .staleAccountChoice,
                .staleProviderGeneration:
            return false
        }
    }
}

struct ImportActivityPresentation: Equatable {
    let title: String
    let subtitle: String
    let status: String
    let iconName: String
    let tone: ImportOutcomeTone
    let recordedAtText: String?

    private init(
        title: String,
        subtitle: String,
        status: String,
        iconName: String,
        tone: ImportOutcomeTone,
        recordedAtText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.iconName = iconName
        self.tone = tone
        self.recordedAtText = recordedAtText
    }

    init(importState: ImportPresentationState, latestDurableAttempt: RepositoryImportAttempt?, completedAttempt: RepositoryImportAttempt? = nil) {
        switch importState {
        case .idle:
            if let latestDurableAttempt {
                self.init(durableAttempt: latestDurableAttempt)
            } else {
                self.init(
                    title: "No recent import",
                    subtitle: "No durable import activity",
                    status: "Idle",
                    iconName: "tray",
                    tone: .warning
                )
            }
        case .preparing(let fileName, let phase):
            self.init(
                title: fileName,
                subtitle: phase.userFacingTitle,
                status: "Preparing",
                iconName: "hourglass",
                tone: .warning
            )
        case .previewReady(let preparedImport):
            self.init(
                title: preparedImport.fileName,
                subtitle: "Prepared for confirmation",
                status: "Ready to Import",
                iconName: "doc.text.magnifyingglass",
                tone: .warning
            )
        case .validationFailed(let preparedImport):
            self.init(
                title: preparedImport.fileName,
                subtitle: "Validation failed before persistence",
                status: "Validation Failed",
                iconName: "xmark.octagon.fill",
                tone: .danger
            )
        case .committing(let preparedImport):
            self.init(
                title: preparedImport.fileName,
                subtitle: "Persisting confirmed financial data",
                status: "Persisting",
                iconName: "arrow.triangle.2.circlepath",
                tone: .warning
            )
        case .completed(let outcome):
            self.init(
                title: outcome.fileName,
                subtitle: outcome.fileSubtitle,
                status: outcome.persistenceStatus,
                iconName: outcome.iconName,
                tone: outcome.tone,
                recordedAtText: ImportInstantFormatting.display(completedAttempt?.createdAtISO)
            )
        case .skipped(let fileName):
            self.init(
                title: fileName,
                subtitle: "Statement skipped. No data was written.",
                status: "Skipped",
                iconName: "forward.fill",
                tone: .warning
            )
        case .cancelled(let fileName):
            self.init(
                title: fileName,
                subtitle: "Preparation cancelled. No data was written.",
                status: "Cancelled",
                iconName: "xmark.circle.fill",
                tone: .warning
            )
        case .failed(let fileName, _, _):
            self.init(
                title: fileName,
                subtitle: "Import preparation failed",
                status: "Preparation Failed",
                iconName: "exclamationmark.triangle.fill",
                tone: .danger
            )
        }
    }

    nonisolated static func latestDurableAttempt(from attempts: [RepositoryImportAttempt]) -> RepositoryImportAttempt? {
        guard !attempts.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let wholeSeconds = ISO8601DateFormatter()
        let dated = attempts.map { attempt in
            (attempt: attempt, date: fractional.date(from: attempt.createdAtISO) ?? wholeSeconds.date(from: attempt.createdAtISO))
        }
        return dated.max { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (left?, right?) where left != right: return left < right
            case (.some, nil): return false
            case (nil, .some): return true
            default: return lhs.attempt.id < rhs.attempt.id
            }
        }?.attempt
    }

    private init(durableAttempt: RepositoryImportAttempt) {
        let presentation = DurableImportAttemptPresentation(attempt: durableAttempt)
        self.init(
            title: "Latest durable import",
            subtitle: presentation.outcome.explanation,
            status: presentation.outcome.label,
            iconName: presentation.outcome.iconName,
            tone: presentation.outcome.tone,
            recordedAtText: ImportInstantFormatting.display(durableAttempt.createdAtISO)
        )
    }
}

struct ContentView: View {
    // Inject inside the established root so WindowGroup keeps its saved identity.
    @StateObject private var appearance = LFAppearanceStore.shared
    @ObservedObject private var backupRecovery = BackupRestoreCoordinator.shared
    private var theme: LFTheme { appearance.theme }
    @Environment(\.appearsActive) private var appearsActive

    @State private var showingImporter = false
    @State private var pendingBatchSourceURLs: [URL] = []
    @State private var statementPassword = ""
    @State private var statementDropIsTargeted = false
    @State private var statementDropRequestGate = StatementDropRequestGate()
    @StateObject private var statementPasswordChallenges = StatementPasswordChallengeController.shared
    @ObservedObject private var importCentre = ProductionImportCentre.shared
    @State private var confirmedImportRecoveryActionExecutor = ConfirmedImportRecoveryActionExecutor()
    @State private var importCentrePresentationOwnerID = UUID()
    @State private var importValidationContentHeight: CGFloat = 0
    @ObservedObject private var availability = ApplicationAvailability.shared
    @ObservedObject private var alDarReferenceSession: AlDarReferenceSession
    @ObservedObject private var investmentPriceSession: InvestmentPriceSession
    @ObservedObject private var ispSyncSession: ZurichISPSyncSession
    @State private var settingsSubsection: SettingsSubsection?
    @StateObject private var salaryViewModel = SalaryWorkspaceViewModel()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @ObservedObject private var transactionViewModel: TransactionListViewModel
    private let transactionAmountMeasurement: TransactionAmountWidthMeasurement
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var importHistoryViewModel = ImportHistoryViewModel()
    @ObservedObject private var importAttemptStore: ImportAttemptStore = .shared
    @ObservedObject private var cardStore: CardStore = .shared
    @ObservedObject private var fundingPlanStore: FundingPlanStore = .shared
    @ObservedObject private var investmentStore: InvestmentStore = .shared
    @ObservedObject private var categoryStore: CategoryStore = .shared
    @State private var selectedSection: AppShellSection = .dashboard
    @State private var sidebarRailOverride: Bool?
    @State private var shellPresentationWidth: CGFloat = 1440
    @State private var didStartRepositoryHydration = false
#if DEBUG
    @StateObject private var developerDatabaseProfileViewModel = DeveloperDatabaseProfileViewModel()
    @State private var pendingProtectedImportIntent: ProtectedImportIntent?
    @State private var developmentAcknowledgementChallenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var developmentActionMessage: String?
#endif

    private var displayedImportItem: ImportCentreCoordinator<PreparedImport>.Item? {
        importCentre.currentItem
            ?? (importCentre.batchSummary.isComplete ? importCentre.presentedItem : nil)
    }

    private var selectedFile: String {
        displayedImportItem?.displayFileName
            ?? (importCentre.selectionFailureMessage == nil ? "No statement imported" : "Import failed")
    }

    private var importState: ImportPresentationState {
        guard let item = displayedImportItem else {
            if let message = importCentre.selectionFailureMessage {
                return .failed(fileName: "Import failed", message: message, retrySourceURL: nil)
            }
            return .idle
        }
        switch item.phase {
        case .pending, .preparing, .awaitingReview:
            return .preparing(fileName: item.displayFileName, phase: item.progress.phase)
        case .awaitingConfirmation:
            guard let preparation = item.preparation else { return .idle }
            return .previewReady(preparation)
        case .validationFailed:
            guard let preparation = item.preparation else { return .idle }
            return .validationFailed(preparation)
        case .committing:
            guard let preparation = item.preparation else { return .idle }
            return .committing(preparation)
        case .completed:
            guard let outcome = item.outcome else { return .idle }
            return .completed(outcome)
        case .skipped:
            return .skipped(fileName: item.displayFileName)
        case .cancelled:
            return .cancelled(fileName: item.displayFileName)
        case .failed:
            return .failed(
                fileName: item.displayFileName,
                message: item.failureMessage ?? "The statement could not be prepared.",
                retrySourceURL: item.retrySourceURL
            )
        }
    }

    private var importIdentityReview: ImportIdentityReview {
        importCentre.currentItem?.identityReview ?? .unavailable
    }

    private var importAccountChoice: ImportAccountChoice? {
        importCentre.currentItem?.accountChoice
    }

    private var cardSectionDraftAccountID: String? {
        importCentre.currentItem?.cardSectionDraftAccountID
    }

    private var cardSectionDraftChoices: [String: ImportCardInstrumentChoice] {
        importCentre.currentItem?.cardSectionDraftChoices ?? [:]
    }

    private var partialImportReview: PartialImportReviewResult {
        importCentre.currentItem?.partialReview ?? .ordinaryFullImport
    }

    private var confirmedImportRecoveryContext: ConfirmedImportRecoveryContext? {
        importCentre.currentItem?.recoveryContext
    }

    private var confirmedImportRecoveryActionRequestID: UUID? {
        importCentre.recoveryActionRequestID
    }

    private var activeStatementPasswordChallenge: StatementPasswordChallenge? {
        guard let challenge = statementPasswordChallenges.challenge,
              let item = importCentre.currentItem,
              item.phase == .preparing,
              item.preparationOperationID == challenge.id else { return nil }
        return challenge
    }

    private var importBatchQueueItems: [ImportBatchQueueItemPresentation] {
        let summaryIsComplete = importCentre.batchSummary.isComplete
        return importCentre.items.map {
            ImportBatchQueueItemPresentation(
                item: $0,
                total: importCentre.items.count,
                activeItemID: importCentre.activeItemID,
                presentedItemID: importCentre.presentedItemID,
                permitsOutcomeNavigation: summaryIsComplete
            )
        }
    }

    init(transactionViewModel: TransactionListViewModel? = nil,
         transactionAmountMeasurement: TransactionAmountWidthMeasurement? = nil,
         alDarReferenceSession: AlDarReferenceSession? = nil,
         investmentPriceSession: InvestmentPriceSession? = nil,
         ispSyncSession: ZurichISPSyncSession? = nil) {
        self.alDarReferenceSession = alDarReferenceSession ?? AlDarReferenceSession(enabled: false)
        self.investmentPriceSession = investmentPriceSession ?? InvestmentPriceSession(enabled: false)
        self.ispSyncSession = ispSyncSession ?? ZurichISPSyncSession(enabled: false)
        self.transactionViewModel = transactionViewModel ?? TransactionListViewModel()
        self.transactionAmountMeasurement = transactionAmountMeasurement ?? TransactionAmountWidthMeasurement()
    }

    var body: some View {
        AppShellView(
            selectedSection: selectedSection,
            availabilityState: availability.state,
            permitsMutation: availability.permitsMutation,
            sidebar: {
                let usesRail = sidebarRailOverride ?? (
                    selectedSection == .dashboard
                        ? AppShellSizing.dashboardUsesRail(at: shellPresentationWidth)
                        : shellPresentationWidth < 1280
                )
                AppShellSidebar(
                    selectedSection: selectedSection,
                    developerConsoleVisible: developerConsoleVisible,
                    latestImportActivity: importActivityPresentation,
                    selectSection: { selectedSection = $0 },
                    isCollapsed: usesRail,
                    allowsCollapse: true,
                    toggleCollapsed: { sidebarRailOverride = !usesRail }
                )
            },
            toolbar: {
                AppShellToolbar(
                    section: selectedSection,
                    subtitle: toolbarSubtitle,
                    accessory: selectedSection == .dashboard
                        ? AnyView(DashboardLiveFXHeaderAccessory(session: alDarReferenceSession))
                        : nil
                )
            },
            profileWarning: { profileWarning },
            availabilityBanner: { availabilityBanner },
            destination: { destinationContent }
        )
        .environment(\.lfTheme, theme)
        .onReceive(availability.$state) { state in
            transactionViewModel.synchronizePresentation(generation: availability.generation, availabilityState: state)
        }
        .font(theme.typography.secondary)
        .tint(theme.palette.accent)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            shellPresentationWidth = size.width
#if DEBUG
            AppShellSizing.recordWindowGeometry(for: selectedSection)
#endif
        }
#if DEBUG
        .onChange(of: selectedSection) { _, section in
            AppShellSizing.recordWindowGeometry(for: section)
        }
#endif
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: StatementImportFileTypes.allowed,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                stageSelectedBatch(urls)
            case .failure(let error):
                importCentre.recordSelectionFailure(error)
                selectedSection = .imports
            }
        }
        .disabled(backupRecovery.isReplacing)
        .onChange(of: selectedSection) { _, section in
            if section == .settings { settingsSubsection = nil }
        }
        .task {
            await hydrateDashboardOnce()
#if DEBUG
            await BackupRestoreCoordinator.shared.runProcessProbeIfRequested()
#endif
        }
        .onAppear {
            importCentre.attachPresentationOwner(importCentrePresentationOwnerID)
            DatabaseActivityGate.shared.registerDraftOwner(salaryViewModel) { [weak model = salaryViewModel] in
                model?.hasUnsavedDrafts == true
            }
            DatabaseActivityGate.shared.registerDraftOwner(accountsViewModel) { [weak model = accountsViewModel] in
                model?.isEditingDisplayName == true
            }
        }
        .onDisappear {
            statementPassword = ""
            statementDropRequestGate.invalidate()
            statementDropIsTargeted = false
            importCentre.detachPresentationOwner(importCentrePresentationOwnerID)
        }
        .onChange(of: statementPasswordChallenges.challenge?.id) { _, _ in
            statementPassword = ""
        }
#if DEBUG
        .confirmationDialog(
            DevelopmentProfileAcknowledgementPresentation.title,
            isPresented: Binding(
                get: { developmentAcknowledgementChallenge != nil && pendingProtectedImportIntent != nil },
                set: { if !$0 { cancelDevelopmentProfileAcknowledgement() } }
            ),
            titleVisibility: .visible
        ) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                approveDevelopmentProfileAcknowledgement()
            }
            Button("Cancel", role: .cancel) {
                cancelDevelopmentProfileAcknowledgement()
            }
        } message: {
            Text(DevelopmentProfileAcknowledgementPresentation.message)
        }
        .confirmationDialog(
            DevelopmentProfileAcknowledgementPresentation.title,
            isPresented: Binding(
                get: { accountsViewModel.requiresDevelopmentProfileAcknowledgement },
                set: { if !$0 { accountsViewModel.cancelDevelopmentProfileAcknowledgement() } }
            ),
            titleVisibility: .visible
        ) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                accountsViewModel.approveDevelopmentProfileAcknowledgement()
            }
            Button("Cancel", role: .cancel) {
                accountsViewModel.cancelDevelopmentProfileAcknowledgement()
            }
        } message: {
            Text(DevelopmentProfileAcknowledgementPresentation.message)
        }
        .onChange(of: developerDatabaseProfileViewModel.publicationEpoch) { _, _ in
            clearStaleImportPresentationAfterProfileChange()
        }
#endif
    }

    @ViewBuilder
    private var profileWarning: some View {
#if DEBUG
        if let activeProfile = developerDatabaseProfileViewModel.activeProfile,
           let warning = DeveloperDatabaseProfileWarningView(profile: activeProfile) {
            warning
        }
#else
        EmptyView()
#endif
    }

    private var developerConsoleVisible: Bool {
#if DEBUG
        AppShellSection.developerConsoleVisible(
            developerModeEnabled: developerDatabaseProfileViewModel.developerModeEnabled
        )
#else
        false
#endif
    }

    private var destinationContent: some View {
        AppDestinationContainer(
            selectedSection: selectedSection,
            dashboard: { dashboardContent },
            accounts: { accountsContent },
            investments: { InvestmentListView(store: investmentStore, prices: investmentPriceSession, availabilityState: availability.state) { selectedSection = .imports } },
            transactions: {
                TransactionListView(viewModel: transactionViewModel, amountMeasurement: transactionAmountMeasurement,
                                    generation: availability.generation, availabilityState: availability.state)
            },
            imports: { importWizardContent },
            salary: { SalaryView(viewModel: salaryViewModel, referenceSession: alDarReferenceSession) },
            settings: { settingsContent },
            developer: {
#if DEBUG
                DeveloperConsoleView(profileViewModel: developerDatabaseProfileViewModel)
#else
                DeveloperConsoleView()
#endif
            }
        )
    }

    private var dashboardContent: some View {
        GeometryReader { viewport in
            let contentWidth = min(1320, max(0, viewport.size.width - theme.spacing.pagePadding * 2))
            let usesColumns = contentWidth >= 640 + dashboardSupportingColumnWidth + theme.spacing.majorModuleGap
            let layout = usesColumns
                ? AnyLayout(HStackLayout(alignment: .top, spacing: theme.spacing.majorModuleGap))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.majorModuleGap))
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    dashboardPositionHeading
                    dashboardPositionPanel(availableWidth: contentWidth)
                    // Select from the viewport instead of measuring two complete
                    // Dashboard trees during AppKit's initial window sizing.
                    layout {
                        dashboardPrimaryContent
                            .frame(minWidth: usesColumns ? 640 : 0, maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: theme.spacing.majorModuleGap) {
                            salaryDashboardSummary
                            DashboardInvestmentSnapshotCard(overview: investmentPriceSession.overview) {
                                selectedSection = .investments
                            }
                            .frame(maxWidth: dashboardSupportingColumnWidth, alignment: .leading)
                            importActivityCard
                        }
                        .frame(width: usesColumns ? dashboardSupportingColumnWidth : nil, alignment: .leading)
                    }
                    if let attention = dashboardAttention {
                        LFPanel(title: "Attention") {
                            Label(attention.title, systemImage: attention.iconName)
                                .foregroundStyle(attention.tone.color)
                            Text(attention.explanation)
                                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        }
                    }
                }
                .frame(maxWidth: 1320, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(theme.spacing.pagePadding)
                .font(theme.typography.body)
            }
        }
    }

    private var dashboardPrimaryContent: some View {
        VStack(alignment: .leading, spacing: theme.spacing.majorModuleGap) {
            DashboardActivityComparisonView(
                comparison: dashboardViewModel.activityComparison,
                state: dashboardViewModel.recentActivityState
            )
            recentTransactionsCard
        }
    }

    private var dashboardAttention: ConfirmedImportRecoveryPresentation? {
        guard case .completed(let outcome) = importState else { return nil }
        return DashboardAttentionProjection.presentation(for: outcome.recoveryRoute)
    }

    private var dashboardPositionHeading: some View {
        HStack(spacing: theme.spacing.small) {
            Text("Position by native currency")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
            if dashboardViewModel.positions.count == 1, let group = dashboardViewModel.positions.first {
                Text(group.currency.code)
                    .font(theme.typography.secondary.weight(.medium))
            }
        }
    }

    private func dashboardPositionPanel(availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            switch dashboardViewModel.positionState {
            case .loading:
                dashboardState("Loading financial position…", loading: true)
            case .empty:
                dashboardState("No bank or card accounts available.")
            case .unavailable:
                dashboardState("Data unavailable", detail: "Current bank and card positions are unavailable.")
            case .populated:
                if dashboardViewModel.positions.count == 1, let group = dashboardViewModel.positions.first {
                    dashboardCurrencyGroup(group, availableWidth: availableWidth, allowsHorizontalDomains: true)
                } else {
                    let count = dashboardViewModel.positions.count
                    let horizontal = count <= 2
                        && availableWidth >= CGFloat(count) * 304 + CGFloat(count - 1) * theme.spacing.sectionGap
                    let groupWidth = horizontal
                        ? (availableWidth - CGFloat(count - 1) * theme.spacing.sectionGap) / CGFloat(count)
                        : availableWidth
                    let layout = horizontal
                        ? AnyLayout(HStackLayout(alignment: .top, spacing: theme.spacing.sectionGap))
                        : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.sectionGap))
                    layout {
                        ForEach(dashboardViewModel.positions) { group in
                            dashboardCurrencyGroup(group, availableWidth: groupWidth)
                                .frame(minWidth: horizontal ? 304 : 0, maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func dashboardCurrencyGroup(_ group: DashboardCurrencyPosition, availableWidth: CGFloat, allowsHorizontalDomains: Bool = false) -> some View {
        let bankWidth = dashboardDomainMinimumWidth("Bank balances", total: group.bankTotal)
        let cardWidth = dashboardDomainMinimumWidth("Card liabilities", total: group.cardTotal)
        let horizontal = allowsHorizontalDomains && availableWidth >= bankWidth + cardWidth + theme.spacing.sectionGap
        let layout = horizontal
            ? AnyLayout(HStackLayout(alignment: .top, spacing: theme.spacing.sectionGap))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.sectionGap))
        return VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            if !allowsHorizontalDomains {
                Text(group.currency.code)
                    .font(theme.typography.secondary.weight(.medium))
            }
            layout {
                dashboardDomain("Bank balances", icon: "building.columns", positions: group.banks, total: group.bankTotal, availableWidth: horizontal ? bankWidth : availableWidth)
                    .frame(minWidth: horizontal ? bankWidth : 0, maxWidth: .infinity)
                dashboardDomain("Card liabilities", icon: "creditcard", positions: group.cards, total: group.cardTotal, availableWidth: horizontal ? cardWidth : availableWidth)
                    .frame(minWidth: horizontal ? cardWidth : 0, maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dashboardDomain(
        _ title: String,
        icon: String,
        positions: [DashboardAccountPosition],
        total: Money?,
        availableWidth: CGFloat
    ) -> some View {
        let detailWidth = max(0, availableWidth - 2 * theme.spacing.panelPadding - 36 - theme.spacing.controlGap)
        let amountWidth = positions.map {
            dashboardTextWidth(dashboardMoneyText($0.amount), role: .body, tabular: true)
        }.max() ?? 0
        let identityWidth = positions.count == 1 ? detailWidth : max(0, detailWidth - amountWidth - theme.spacing.valueGutter)
        return LFPanel(contentSpacing: theme.spacing.controlGap) {
            HStack(spacing: theme.spacing.controlGap) {
                Image(systemName: icon)
                    .font(theme.typography.domainIcon)
                    .frame(width: 36, height: 36)
                    .foregroundStyle(theme.palette.secondaryText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    Text(title)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.palette.secondaryText)
                    if !positions.isEmpty { dashboardMoney(total) }
                }
            }
            if positions.isEmpty {
                Text(title == "Bank balances" ? "No bank accounts" : "No card accounts")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            } else {
                if positions.count > 1, total == nil {
                    Text("Incomplete: a member position is unavailable.")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }
                Group {
                    if positions.count == 1 {
                        ForEach(positions) { position in
                            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                                // The sole account's full amount is the domain headline.
                                dashboardAccountIdentity(position, availableWidth: identityWidth)
                                dashboardAccountContext(position, domain: title)
                            }
                        }
                    } else {
                        LFLabelValueGroup(rows: positions, rowSpacing: theme.spacing.controlGap, valueRole: .body) { position in
                            dashboardAccountIdentity(position, availableWidth: identityWidth)
                        } value: { position in
                            dashboardAccountAmount(position)
                        } context: { position in
                            dashboardAccountContext(position, domain: title)
                        }
                    }
                }
                .padding(.leading, 36 + theme.spacing.controlGap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dashboardAccountName(_ position: DashboardAccountPosition) -> some View {
        Text(position.displayName)
            .font(theme.typography.body)
            .foregroundStyle(theme.palette.primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func dashboardAccountIdentity(_ position: DashboardAccountPosition, availableWidth: CGFloat) -> some View {
        let inlineWidth = dashboardTextWidth(position.displayName, role: .body)
            + theme.spacing.controlGap
            + dashboardTextWidth(dashboardSourceContextText(position), role: .caption)
        let layout = inlineWidth <= availableWidth
            ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.micro))
        return layout {
            dashboardAccountName(position)
            if position.amount != nil { dashboardSourceContext(position) }
        }
    }

    private func dashboardAccountAmount(_ position: DashboardAccountPosition) -> some View {
        Text(position.amount.map { MoneyFormatting.display($0) } ?? "Data unavailable")
            .font(theme.typography.font(.body, tabularDigits: true))
            .fixedSize(horizontal: true, vertical: false)
    }

    private func dashboardAccountContext(_ position: DashboardAccountPosition, domain: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            if domain == "Card liabilities", let money = position.amount, money.amount < .zero {
                Text("Card credit balance").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private func dashboardSourceContextText(_ position: DashboardAccountPosition) -> String {
        DashboardAccountPosition.asOfLabel(for: position.asOf)
            + (position.sourceContext.map { " · \($0)" } ?? "")
    }

    private func dashboardSourceContext(_ position: DashboardAccountPosition) -> some View {
        Text(dashboardSourceContextText(position))
        .font(theme.typography.caption)
        .foregroundStyle(theme.palette.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func dashboardMoneyText(_ money: Money?) -> String {
        money.map { MoneyFormatting.display($0) } ?? "Data unavailable"
    }

    private func dashboardTextWidth(_ text: String, role: LFFontRole, tabular: Bool = false) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: theme.typography.nativeFont(role, tabularDigits: tabular)]).width)
    }

    private func dashboardDomainMinimumWidth(_ title: String, total: Money?) -> CGFloat {
        let valueWidth = dashboardTextWidth(dashboardMoneyText(total), role: total == nil ? .body : .headlineMoney, tabular: true)
        let labelWidth = dashboardTextWidth(title, role: .secondary)
        return max(304, max(valueWidth, labelWidth) + 36 + theme.spacing.controlGap + 2 * theme.spacing.panelPadding)
    }

    private func dashboardMoney(_ money: Money?) -> some View {
        let role: LFFontRole = money == nil ? .body : .headlineMoney
        return LFCompleteValue(lineHeight: theme.typography.lineHeight(role)) {
            Text(dashboardMoneyText(money))
                .font(theme.typography.font(role, tabularDigits: true))
        }
    }

    private func dashboardFundingText(_ metric: DashboardFundingMetric) -> String {
        metric.money(in: dashboardViewModel.fundingCalculation).map { MoneyFormatting.display($0) }
            ?? "\(metric.currencyCode) Unavailable"
    }

    private var dashboardSupportingColumnWidth: CGFloat {
        // FX lives in the page header; rate-string changes must not resize the
        // planning/investment column underneath it.
        let minimumWidth: CGFloat = 336
        guard dashboardViewModel.fundingState != .empty else { return minimumWidth }
        let valueWidth = DashboardFundingMetric.allCases.map {
            dashboardTextWidth(dashboardFundingText($0), role: .body, tabular: true)
        }.max() ?? 0
        let labelWidth = DashboardFundingMetric.allCases.map {
            dashboardTextWidth($0.rawValue, role: .secondary)
        }.max() ?? 0
        return max(minimumWidth, labelWidth + theme.spacing.valueGutter + valueWidth + 2 * theme.spacing.panelPadding)
    }

    private var salaryDashboardSummary: some View {
        LFPanel(contentSpacing: theme.spacing.controlGap) {
            if dashboardViewModel.fundingState == .empty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: theme.spacing.sectionGap) {
                        dashboardMissingPlanMessage
                        Spacer(minLength: theme.spacing.sectionGap)
                        dashboardRouteButton(.salary)
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                        dashboardMissingPlanMessage
                        dashboardRouteButton(.salary)
                    }
                }
            } else {
                dashboardSupportingHeading("\(dashboardViewModel.fundingMonthTitle) Budget Planning", icon: "calendar", font: theme.typography.body.weight(.medium))
                if dashboardViewModel.fundingState == .loading {
                    dashboardState("Loading Salary / Funding…", loading: true)
                } else {
                    Text("Planning estimates · saved \(dashboardViewModel.fundingMonthTitle) plan")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    LFLabelValueGroup(rows: DashboardFundingMetric.allCases, rowSpacing: theme.spacing.controlGap, valueRole: .body) { metric in
                        Text(metric.rawValue)
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.palette.secondaryText)
                    } value: { metric in
                        Text(dashboardFundingText(metric))
                            .font(theme.typography.font(.body, tabularDigits: true))
                            .foregroundStyle(theme.palette.primaryText)
                    } context: { _ in
                        EmptyView()
                    }
                    if dashboardViewModel.fundingState == .unavailable {
                        Text("Data unavailable").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    } else if let calculation = dashboardViewModel.fundingCalculation,
                              !calculation.incompleteReasons.isEmpty {
                        Text("Missing required input. Affected outputs are unavailable.")
                            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    }
                }
                dashboardRouteButton(.salary)
            }
        }
    }

    private var dashboardMissingPlanMessage: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            dashboardSupportingHeading("\(dashboardViewModel.fundingMonthTitle) Budget Planning", icon: "calendar", font: theme.typography.secondary.weight(.medium))
            Text("No saved plan for \(dashboardViewModel.fundingMonthTitle).")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dashboardSupportingHeading(_ title: String, icon: String, font: Font? = nil) -> some View {
        HStack(spacing: theme.spacing.small) {
            Image(systemName: icon)
                .font(theme.typography.sectionIcon)
                .foregroundStyle(theme.palette.secondaryText)
                .accessibilityHidden(true)
            Text(title)
                .font(font ?? theme.typography.rowTitle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dashboardState(_ title: String, detail: String? = nil, loading: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if loading { ProgressView().controlSize(.small) }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                if let detail { Text(detail).font(theme.typography.secondary) }
            }
            .foregroundStyle(theme.palette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    private func dashboardRouteButton(_ route: DashboardRoute) -> some View {
        Button { selectedSection = route.destination } label: {
            HStack(spacing: theme.spacing.controlGap) {
                Text(route.rawValue)
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }
            .font(theme.typography.secondary.weight(.medium))
            .padding(.vertical, theme.spacing.micro)
        }
        .lfSecondaryAction()
        .controlSize(.regular)
        .accessibilityLabel(route.rawValue)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var accountsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    ForEach(accountsViewModel.nativeBalanceSummaries) { summary in
                        accountMetric("\(summary.money.currency.code) Balance", value: MoneyFormatting.display(summary.money), detail: "Native total across \(accountsViewModel.accounts.count) account(s)", icon: "wallet.pass")
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    LFPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            accountTableHeader

                            if accountsViewModel.accounts.isEmpty {
                                LFEmptyState(
                                    title: "No accounts found",
                                    message: "Trusted repository-backed accounts appear here after import.",
                                    actionTitle: "Import Statement",
                                    systemImage: "wallet.pass"
                                ) {
                                    requestFileSelection()
                                }
                            } else {
                                ForEach(accountsViewModel.accounts) { account in
                                    accountRow(account)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    accountDetailPanel
                        .frame(width: 344)
                }
            }
            .padding(theme.spacing.pagePadding)
        }
    }

    private var importWizardContent: some View {
        VStack(spacing: 18) {
            if !importCentre.showsAutomaticBatchProgress { importStepper }

#if DEBUG
            if let developmentActionMessage {
                Text(developmentActionMessage)
                    .font(theme.typography.formCaption)
                    .foregroundStyle(LFTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LFTheme.warning.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
#endif

            if importCentre.showsAutomaticBatchProgress {
                ImportBatchRunView(
                    total: importCentre.items.count,
                    completed: importCentre.terminalItems.count,
                    currentPosition: importCentre.currentItem.map { $0.queuePosition + 1 },
                    currentFileName: importCentre.currentItem?.displayFileName ?? "",
                    statusText: "Preparing and importing validated statements. Review appears only when a decision is needed.",
                    importedCount: importCentre.batchSummary.committedCount,
                    duplicateCount: importCentre.batchSummary.exactDuplicateCount
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transaction { $0.animation = nil }
            } else {
            GeometryReader { geometry in
                let prepared = preparedTransactionPreview
                let columns = prepared.map(previewColumns)
                let minimumLeft = max(380, theme.typography.size(.formBody) * 27) + 2 * theme.spacing.panelPadding
                let minimumRight = (columns?.minimumWidth ?? 0) + 2 * theme.spacing.panelPadding
                let rightWidth = max(minimumRight, (geometry.size.width - 18) * 0.53)
                let useRightPreview = prepared != nil && geometry.size.width >= minimumLeft + rightWidth + 18 &&
                    previewCanShareValidation(prepared, height: geometry.size.height)
                VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                LFPanel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Import Statements")
                                .font(theme.typography.formSection.weight(.semibold))
                            Text("Choose statements, then start the batch once. LedgerForge imports each validated statement and pauses when it needs your decision.")
                                .font(theme.typography.formBody)
                                .foregroundStyle(theme.palette.secondaryText)

                            if !importCentre.items.isEmpty {
                                ImportBatchProgressView(
                                    activePosition: importCentre.currentItem.map { $0.queuePosition + 1 },
                                    total: importCentre.items.count,
                                    terminalCount: importCentre.terminalItems.count
                                )
                            }

                            Button {
                                requestFileSelection()
                            } label: {
                                VStack(spacing: 14) {
                                    Image(systemName: "folder")
                                        .font(theme.typography.dropTargetIcon)
                                        .foregroundStyle(theme.palette.accentHover)
                                    Text("Choose or drop statements")
                                        .font(theme.typography.formHeading)
                                    Text("Browse Files")
                                        .font(theme.typography.formBody.weight(.semibold))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 9)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(theme.palette.accent, lineWidth: 1)
                                        )
                                }
                                .frame(maxWidth: .infinity, minHeight: 210)
                                .background(
                                    theme.palette.accent.opacity(statementDropIsTargeted ? 0.15 : 0.05)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            statementDropIsTargeted
                                                ? theme.palette.accentHover
                                                : theme.palette.accent.opacity(0.75),
                                            lineWidth: statementDropIsTargeted ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(LFPlainActionStyle())
                            .disabled(importSelectionDisabled || statementDropRequestGate.isActive)
                            .onDrop(
                                of: [.fileURL],
                                isTargeted: $statementDropIsTargeted,
                                perform: receiveStatementDrop
                            )
                            .accessibilityLabel("Add statements")
                            .accessibilityHint("Opens the file picker. You can also drop supported statement files here.")

                            if !pendingBatchSourceURLs.isEmpty {
                                selectedBatchReview
                            }

                            if !importCentre.items.isEmpty {
                                ImportBatchQueueView(items: importBatchQueueItems) { itemID in
                                    importCentre.presentItem(itemID)
                                }
                            }

                            importResultPanel

                            if importCentre.hasTerminalOutcomesForEntireBatch {
                                ImportBatchSummaryView(
                                    summary: ImportBatchSummaryPresentation(importCentre.batchSummary)
                                )
                            }

                            importAttemptHistoryPanel

                            if importCentre.items.isEmpty && importState.showsPreConfirmationNoWriteMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(LFTheme.info)
                                    Text("No data is written until you select Prepare and import batch.")
                                        .font(theme.typography.formCaption)
                                        .foregroundStyle(theme.palette.secondaryText)
                                    Spacer()
                                }
                                .padding(12)
                                .background(LFTheme.info.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LFTheme.info.opacity(0.25), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                LFPanel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("Validation Review")
                                    .font(theme.typography.formSection.weight(.semibold))
                                validationReviewPanel
                            }
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                importValidationContentHeight = $0
                            }
                            if useRightPreview, let prepared, let columns {
                                transactionPreviewPanel(prepared, columns: columns)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(minWidth: useRightPreview ? rightWidth : nil,
                       maxWidth: useRightPreview ? rightWidth : .infinity,
                       maxHeight: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity)
                    if !useRightPreview, let prepared, let columns {
                        LFPanel {
                            ScrollView([.horizontal, .vertical]) {
                                transactionPreviewPanel(prepared, columns: columns)
                                    .frame(minWidth: max(columns.minimumWidth, geometry.size.width - 2 * theme.spacing.panelPadding - 20))
                            }
                        }
                        .frame(height: max(160, min(320, geometry.size.height * 0.44)))
                    }
                }
            }

            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.controlGap) { importFooterControls }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .trailing, spacing: theme.spacing.controlGap) { importFooterControls }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(theme.spacing.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var importFooterControls: some View {
        if importCentre.showsAutomaticBatchProgress {
            Button("Cancel batch") {
                statementPassword = ""
                importCentre.cancelBatch()
            }
            .lfSecondaryAction()
            .help("If a statement is being saved, it finishes before the remaining batch is cancelled.")
        } else {
        if case .committing = importState {
            Label("Current commit cannot be cancelled", systemImage: "lock.fill")
                .font(theme.typography.formCaption.weight(.semibold))
                .foregroundStyle(theme.palette.secondaryText)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(theme.palette.controlSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        if canCancelPreparation {
            Button("Cancel Current", action: cancelPreparedImport)
                .buttonStyle(ImportFooterButtonStyle())
        }

        if importCentre.permitsSkip {
            Button("Skip") {
                statementPassword = ""
                importCentre.skipCurrent()
            }
            .buttonStyle(ImportFooterButtonStyle())
        }

        if importCentre.permitsContinue {
            Button("Continue") {
                importCentre.continueAfterCurrent()
            }
            .buttonStyle(ImportFooterButtonStyle())
        }

        if importCentre.permitsBatchCancellation {
            Button(
                importCentre.batchLifecycle == .committing
                    ? "Cancel Remaining After Current Import"
                    : "Cancel Batch"
            ) {
                statementPassword = ""
                importCentre.cancelBatch()
            }
            .buttonStyle(ImportFooterButtonStyle())
            .disabled(importCentre.batchCancellationRequested)
        }

        if importCentre.batchSummary.isComplete {
            Button("Start New Batch", action: startNewImportBatch)
                .buttonStyle(ImportFooterButtonStyle())
        }

        if !pendingBatchSourceURLs.isEmpty { selectedBatchActions }
        else { importFooterAction }
        }
    }

    private var settingsContent: some View {
        let completedImports = SettingsPresentation.completedImports(
            from: importAttemptStore.attempts,
            persistenceState: DatabaseProvider.shared.persistenceState
        )

        return GeometryReader { geometry in
            let width = min(1320, max(0, geometry.size.width - theme.spacing.pagePadding * 2))
            let informationLayout = width >= max(900, theme.typography.size(.secondary) * 60)
                ? AnyLayout(HStackLayout(alignment: .top, spacing: theme.spacing.sectionGap))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.sectionGap))
            VStack(alignment: .leading, spacing: 0) {
                if settingsSubsection != nil {
                    HStack(spacing: theme.spacing.controlGap) {
                        Button("Settings", systemImage: "chevron.left") { settingsSubsection = nil }
                            .lfSecondaryAction()
                            .accessibilityHint("Returns to the Settings overview")
                        Spacer()
                    }
                    .padding(.horizontal, theme.spacing.pagePadding)
                    .padding(.vertical, theme.spacing.sectionGap)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                        if settingsSubsection == .appearance {
                            LFAppearanceIntroduction(appearance: appearance)
                            LFAppearanceControls(appearance: appearance, availableWidth: width)
                        } else if settingsSubsection == .liveFX {
                            LiveFXSettingsView(rates: alDarReferenceSession, prices: investmentPriceSession)
                        } else if settingsSubsection == .ispAccount {
                            ZurichISPSettingsView(session: ispSyncSession)
                        } else if settingsSubsection == .backup {
                            BackupRestoreSettingsSection()
                        } else if settingsSubsection == .categories {
                            CategoryManagementView()
                        } else {
                        settingsDestinations

                        LFPanel(title: "Application & data", systemImage: "info.circle") {
                            informationLayout {
#if DEBUG
                                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                                    Text("Application").font(theme.typography.rowTitle)
                                    Toggle("Developer Mode", isOn: Binding(
                                        get: { developerDatabaseProfileViewModel.developerModeEnabled },
                                        set: { updateDeveloperMode($0) }
                                    ))
                                    .toggleStyle(.switch)
                                    .font(theme.typography.secondary)
                                    if let message = developerDatabaseProfileViewModel.operationState.message {
                                        Text(message)
                                            .font(theme.typography.caption)
                                            .foregroundStyle(LFTheme.warning)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
#endif
                                VStack(alignment: .leading, spacing: theme.spacing.small) {
                                    Text("System information").font(theme.typography.rowTitle)
                                    LFInfoRow(title: "Version", value: SettingsPresentation.applicationVersion(infoDictionary: Bundle.main.infoDictionary), textRole: .secondary)
                                    LFInfoRow(title: "Persistence", value: DatabaseProvider.shared.persistenceState.displayName, textRole: .secondary)
                                    Text(DatabaseProvider.shared.persistenceState.statusMessage)
                                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                                    if let guidance = DatabaseProvider.shared.persistenceState.recoveryGuidance {
                                        Text(guidance).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                                    }
                                    LFInfoRow(title: "Runtime state", value: dashboardViewModel.presentationState.message, textRole: .secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                VStack(alignment: .leading, spacing: theme.spacing.small) {
                                    Text("Data summary").font(theme.typography.rowTitle)
                                    LFInfoRow(title: "Accounts", value: "\(dashboardViewModel.accounts.count)", textRole: .secondary)
                                    LFInfoRow(title: "Transactions", value: "\(dashboardViewModel.transactionCount)", textRole: .secondary)
                                    LFInfoRow(title: "Completed imports", value: completedImports.displayValue, textRole: .secondary)
                                    if let partialValue = completedImports.secondaryValue {
                                        LFInfoRow(title: "Partial imports", value: partialValue, textRole: .secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        }
                    }
                    .frame(maxWidth: 1320, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, theme.spacing.pagePadding)
                    .padding(.top, settingsSubsection == nil ? theme.spacing.sectionGap : 0)
                    .padding(.bottom, theme.spacing.pagePadding)
                }
            }
        }
    }

    private var settingsDestinations: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                    appearanceAndLiveFXCards
                    backupAndCategoryCards
                }
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    appearanceAndLiveFXCards
                    backupAndCategoryCards
                }
            }
        }
    }

    private var appearanceAndLiveFXCards: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            settingsDestinationCard(
                title: SettingsSubsection.appearance.rawValue,
                summary: appearance.overrides.isEmpty ? "Dark · Default appearance" : "Dark · Custom appearance",
                systemImage: SettingsSubsection.appearance.systemImage,
                destination: .appearance
            )
            settingsDestinationCard(
                title: SettingsSubsection.liveFX.rawValue,
                summary: liveFXSummary,
                systemImage: SettingsSubsection.liveFX.systemImage,
                destination: .liveFX
            )
            settingsDestinationCard(
                title: SettingsSubsection.ispAccount.rawValue,
                summary: ispSyncSession.connectionSummary,
                systemImage: SettingsSubsection.ispAccount.systemImage,
                destination: .ispAccount
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backupAndCategoryCards: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            settingsDestinationCard(
                title: SettingsSubsection.backup.rawValue,
                summary: backupRecovery.isBusy ? "Backup or restore in progress" : "Create or restore a verified ledger backup",
                systemImage: SettingsSubsection.backup.systemImage,
                destination: .backup
            )
            settingsDestinationCard(
                title: SettingsSubsection.categories.rawValue,
                summary: categorySummary,
                systemImage: SettingsSubsection.categories.systemImage,
                destination: .categories
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsDestinationCard(
        title: String,
        summary: String,
        systemImage: String,
        destination: SettingsSubsection
    ) -> some View {
        Button { settingsSubsection = destination } label: {
            LFPanel(contentSpacing: theme.spacing.small) {
                HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                    Image(systemName: systemImage)
                        .font(theme.typography.sectionIcon)
                        .foregroundStyle(theme.palette.accentHover)
                        .frame(width: 24, alignment: .center)
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        Text(title).font(theme.typography.rowTitle)
                        Text(summary)
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: theme.spacing.small)
                    Label("Open", systemImage: "chevron.right")
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.palette.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Open \(title)")
        .accessibilityHint(summary)
    }

    private var categorySummary: String {
        let active = categoryStore.activeCategories.count
        let archived = categoryStore.archivedCategories.count
        if active == 0 && archived == 0 { return "No categories created yet" }
        if archived == 0 { return "\(active) active \(active == 1 ? "category" : "categories")" }
        return "\(active) active · \(archived) archived"
    }

    private var liveFXSummary: String {
        if !alDarReferenceSession.refreshing.isEmpty || !investmentPriceSession.refreshing.isEmpty {
            return "Refreshing currency rates and investment prices"
        }
        let currencyStatus = alDarReferenceSession.legs.count == AlDarCurrency.allCases.count
            ? "Currency rates ready"
            : alDarReferenceSession.legs.isEmpty ? "Currency rates need a refresh" : "Some currency rates available"
        let investmentStatus = investmentPriceSession.rows.isEmpty
            ? "No investment holdings"
            : investmentPriceSession.quotes.isEmpty ? "Investment prices need a refresh" : "Investment prices available"
        return "\(currencyStatus) · \(investmentStatus)"
    }

    private var importActivityCard: some View {
        LFPanel(contentSpacing: theme.spacing.controlGap) {
            dashboardSupportingHeading("Import Activity", icon: "square.and.arrow.down")
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                if availability.state == .loading {
                    dashboardState("Loading import activity…", loading: true)
                } else if availability.state == .unavailable || availability.state == .retainedNonCurrent {
                    dashboardState("Data unavailable", detail: "Current import activity is unavailable.")
                } else {
                    let activity = importActivityPresentation
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Text(activity.title)
                            .font(theme.typography.secondary.weight(.medium))
                        Label(activity.status, systemImage: activity.iconName)
                            .font(theme.typography.secondary)
                            .foregroundStyle(activity.tone.color)
                        Text(activity.subtitle)
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if let recordedAtText = activity.recordedAtText {
                            Text(recordedAtText).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                        }
                    }
                }
                dashboardRouteButton(.imports)
            }
        }
    }

    private var recentTransactionsCard: some View {
        LFPanel(contentSpacing: theme.spacing.controlGap) {
            dashboardSupportingHeading("Recent Activity", icon: "clock")
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                switch dashboardViewModel.recentActivityState {
                case .loading:
                    dashboardState("Loading recent activity…", loading: true)
                case .empty:
                    dashboardState("No recent activity", detail: "Transactions appear here once imported.")
                case .unavailable:
                    dashboardState("Data unavailable", detail: "Current transaction activity is unavailable.")
                case .populated:
                    LFLabelValueGroup(rows: dashboardViewModel.recentActivity, rowSpacing: theme.spacing.controlGap) { row in
                        Text(row.transaction.description).font(theme.typography.body)
                    } value: { row in
                        Text(MoneyFormatting.display(row.transaction.money))
                            .font(theme.typography.font(.rowTitle, tabularDigits: true))
                            .foregroundStyle(theme.financialEffectColor(row.effect))
                    } context: { row in
                        dashboardRecentContext(row)
                    }
                    Text("Showing \(dashboardViewModel.recentActivity.count) of \(dashboardViewModel.transactionCount) transactions")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
                dashboardRouteButton(.transactions)
            }
        }
    }

    private func dashboardRecentContext(_ row: TransactionPresentationRow) -> some View {
        Text("\(row.sourceCivilDate?.presentation ?? "Date unavailable") · \(row.accountDisplayName) · \(row.currentCategoryDisplayName)")
            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var accountDetailPanel: some View {
        LFPanel(variant: .inspector) {
            VStack(alignment: .leading, spacing: 18) {
                if let account = accountsViewModel.selectedAccount {
                    HStack(spacing: 12) {
                        accountIcon(account.institution)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            if accountsViewModel.isEditingDisplayName {
                                TextField("Display name", text: $accountsViewModel.displayNameDraft)
                                    .lfTextField()
                            } else {
                                Text(account.displayName)
                                    .font(theme.typography.formHeading)
                            }
                            Text(account.institution)
                                .font(theme.typography.formCaption)
                                .foregroundStyle(theme.palette.secondaryText)
                        }
                        Spacer()
                    }

                    if accountsViewModel.isEditingDisplayName {
                        HStack(spacing: 10) {
                            Button("Save") {
                                accountsViewModel.saveDisplayName()
                            }
                            .lfPrimaryAction()
                            Button("Cancel") {
                                accountsViewModel.cancelDisplayNameEdit()
                            }
                            .lfSecondaryAction()
                        }
                    } else {
                        Button("Edit display name") {
                            accountsViewModel.beginDisplayNameEdit()
                        }
                        .lfSecondaryAction()
                    }

                    if let message = accountsViewModel.presentationState.message {
                        Text(message)
                            .font(theme.typography.formCaption)
                            .foregroundStyle(LFTheme.warning)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(account.currentBalanceLabel)
                            .font(theme.typography.formCaption)
                            .foregroundStyle(theme.palette.secondaryText)
                        Text(formatCurrency(account.currentBalance, currencyCode: account.currencyCode))
                            .font(theme.typography.formTitle.weight(.semibold))
                            .foregroundStyle(account.currentBalance >= .zero ? theme.financialPositive : theme.financialNegative)
                            .monospacedDigit()
                    }

                    LFInfoRow(title: "Institution", value: account.institution)
                    LFInfoRow(title: "Account Type", value: account.accountTypeLabel)
                    LFInfoRow(title: "Currency", value: account.currencyCode)
                    LFInfoRow(title: "Transactions", value: "\(accountsViewModel.transactionCount)")
                    if let period = account.latestStatementPeriod {
                        LFInfoRow(title: "Latest Statement", value: period)
                    }
                    if let dueDate = account.dueDate {
                        LFInfoRow(title: "Due Date", value: dueDate)
                    }
                    if let count = account.cardInstrumentCount {
                        LFInfoRow(title: "Card Instruments", value: "\(count)")
                    }

                    Divider().overlay(theme.palette.divider)

                    Text("Recent Activity")
                        .font(theme.typography.formHeading)

                    if accountsViewModel.recentActivity.isEmpty {
                        LFCompactEmptyState(message: "No trusted activity for this account")
                    }

                    ForEach(accountsViewModel.recentActivity) { transaction in
                        HStack {
                            Image(systemName: transaction.cardLiabilityEffect == .decreasesAmountOwed || transaction.credit != nil ? "arrow.down" : "arrow.up")
                                .foregroundStyle(transaction.cardLiabilityEffect == .decreasesAmountOwed || transaction.credit != nil ? theme.financialPositive : theme.financialNegative)
                                .frame(width: 28, height: 28)
                                .background((transaction.cardLiabilityEffect == .decreasesAmountOwed || transaction.credit != nil ? theme.financialPositive : theme.financialNegative).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(transaction.description)
                                .lineLimit(1)
                            Spacer()
                            Text(transaction.signedAmountDisplay)
                                .foregroundStyle(transaction.cardLiabilityEffect == .decreasesAmountOwed || transaction.credit != nil ? theme.financialPositive : theme.financialNegative)
                                .monospacedDigit()
                        }
                        .font(theme.typography.formCaption)
                    }

                    Divider().overlay(theme.palette.divider)

                    Text("Verified Financial Identity")
                        .font(theme.typography.formHeading)
                    if account.identitySummaries.isEmpty {
                        LFCompactEmptyState(message: "No verified strong identifiers")
                    } else {
                        ForEach(account.identitySummaries) { identifier in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(identifier.kind) · \(identifier.redactedValue)")
                                    .font(theme.typography.formCaption.weight(.semibold))
                                Text("\(identifier.strength) · \(identifier.verificationState) · \(identifier.provenance)")
                                    .font(theme.typography.finePrint)
                                    .foregroundStyle(theme.palette.secondaryText)
                            }
                        }
                    }

                    Divider().overlay(theme.palette.divider)

                    Text("Import History")
                        .font(theme.typography.formHeading)
                    if accountsViewModel.importHistory.isEmpty {
                        LFCompactEmptyState(message: "No trusted import history for this account")
                    } else {
                        ForEach(accountsViewModel.importHistory) { session in
                            Button {
                                accountsViewModel.selectImportSession(id: session.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.sourceDocumentName ?? "Imported statement")
                                        .font(theme.typography.formCaption.weight(.semibold))
                                    Text(session.isPartialImport
                                         ? "\(session.validationStatus) · Partial: \(session.transactionCount) new, \(session.recognizedExistingRowCount ?? 0) represented"
                                         : "\(session.validationStatus) · \(session.transactionCount) transaction(s)")
                                        .font(theme.typography.finePrint)
                                        .foregroundStyle(theme.palette.secondaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(LFPlainActionStyle())
                        }
                    }

                    if let session = accountsViewModel.selectedImportSession {
                        Divider().overlay(theme.palette.divider)
                        HStack {
                            Text("Import Detail")
                                .font(theme.typography.formHeading)
                            Spacer()
                            Button("Close") {
                                accountsViewModel.clearSelectedImportSession()
                            }
                            .lfSecondaryAction()
                        }
                        LFInfoRow(title: "Source", value: session.sourceDocumentName ?? "Imported statement")
                        LFInfoRow(title: "Status", value: session.validationStatus)
                        LFInfoRow(title: "Transactions", value: "\(session.transactionCount)")
                        if session.isPartialImport {
                            LFInfoRow(title: "Import Type", value: "Reviewed partial import")
                            LFInfoRow(title: "Source Rows", value: "\(session.sourceRowCount ?? 0)")
                            LFInfoRow(title: "Already Represented", value: "\(session.recognizedExistingRowCount ?? 0)")
                        }
                        if let parserVersion = session.parserVersion {
                            LFInfoRow(title: "Parser", value: parserVersion)
                        }
                    }
                } else {
                    LFCompactEmptyState(message: "Select an account after importing trusted data")
                }
            }
        }
    }

    private var importStepper: some View {
        HStack(spacing: 14) {
            wizardStep(1, title: "Choose files", subtitle: "Select statements", active: importStep >= 1)
            stepLine(active: importStep >= 2)
            wizardStep(2, title: "Start batch", subtitle: "Confirm once", active: importStep >= 2)
            stepLine(active: importStep >= 3)
            wizardStep(3, title: "Prepare", subtitle: "Read and validate", active: importStep >= 3)
            stepLine(active: importStep >= 4)
            wizardStep(4, title: "Review", subtitle: "Only if needed", active: importStep >= 4)
            stepLine(active: importStep >= 5)
            wizardStep(5, title: "Import", subtitle: "Complete import", active: importStep >= 5)
        }
        .padding(.vertical, 10)
    }

    private var importStep: Int {
        switch importState {
        case .idle:
            return pendingBatchSourceURLs.isEmpty ? 1 : 2
        case .preparing:
            return 3
        case .previewReady, .validationFailed:
            return importCentre.currentItemWillAutomaticallyCommit ? 5 : 4
        case .committing:
            return 5
        case .completed:
            return 5
        case .failed:
            return 4
        case .skipped, .cancelled:
            return 1
        }
    }

    private var importSelectionDisabled: Bool {
        !pendingBatchSourceURLs.isEmpty || !importCentre.permitsSourceSelection
    }

    private var canCancelPreparation: Bool {
        importCentre.permitsCancellation
    }

    private var totalAccountBalance: Decimal {
        accountsViewModel.accounts.reduce(.zero) { $0 + $1.currentBalance }
    }

    private var accountTableHeader: some View {
        HStack(spacing: 12) {
            Text("Account Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Institution")
                .frame(width: 160, alignment: .leading)
            Text("Type")
                .frame(width: 100, alignment: .leading)
            Text("Balance")
                .frame(width: 140, alignment: .trailing)
        }
        .font(theme.typography.formCaption)
        .foregroundStyle(theme.palette.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func metricCard(title: String, value: String, trend: String, trendColor: Color, systemImage: String) -> some View {
        LFPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(theme.typography.formBody.weight(.medium))
                    Spacer()
                    Image(systemName: systemImage)
                        .foregroundStyle(theme.palette.accentHover)
                }
                Text(value)
                    .font(.system(size: 25, weight: .semibold))
                    .monospacedDigit()
                Text(trend)
                    .font(theme.typography.formCaption)
                    .foregroundStyle(trendColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accountMetric(_ title: String, value: String, detail: String, icon: String, tint: Color? = nil) -> some View {
        let tint = tint ?? theme.palette.accent
        return LFPanel {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(theme.typography.formSection)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(theme.typography.formBody.weight(.medium))
                    Text(value)
                        .font(theme.typography.formTitle.weight(.semibold))
                        .foregroundStyle(tint == LFTheme.danger ? LFTheme.danger : theme.palette.primaryText)
                        .monospacedDigit()
                    Text(detail)
                        .font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accountRow(_ account: AccountsAccountPresentation) -> some View {
        Button {
            accountsViewModel.selectAccount(repositoryAccountID: account.id)
        } label: {
            HStack(spacing: 12) {
                accountIcon(account.institution)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(theme.typography.formBody.weight(.semibold))
                    Text(account.currencyCode)
                        .font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(account.institution)
                    .frame(width: 160, alignment: .leading)

                Text(account.accountTypeLabel)
                    .font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.primaryText)
                    .padding(.horizontal, theme.spacing.small)
                    .padding(.vertical, theme.spacing.micro)
                    .background(theme.interaction.dataBadge, in: RoundedRectangle(cornerRadius: theme.radius.control))
                    .frame(width: 100, alignment: .leading)

                Text(formatCurrency(account.currentBalance, currencyCode: account.currencyCode))
                    .foregroundStyle(account.currentBalance >= .zero ? theme.financialPositive : theme.financialNegative)
                    .monospacedDigit()
                    .frame(width: 140, alignment: .trailing)
            }
            .font(theme.typography.formCaption)
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .background(
                accountsViewModel.selectedRepositoryAccountID == account.id
                    ? theme.interaction.dataRow(selected: true, active: appearsActive)
                    : theme.palette.contentSurface
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(LFPlainActionStyle())
    }

    private func accountIcon(_ institution: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(institution.localizedCaseInsensitiveContains("axis") ? theme.palette.institutionMark : theme.palette.accent.opacity(0.55))
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: institution.localizedCaseInsensitiveContains("axis") ? "a.square.fill" : "building.columns.fill")
                    .foregroundStyle(.white)
            }
    }

    private func importedFileRow(name: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(theme.typography.formBody.weight(.semibold))
                Text(subtitle)
                    .font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
            Spacer()
            Image(systemName: name == "No statement imported" ? "circle" : "checkmark.circle.fill")
                .foregroundStyle(name == "No statement imported" ? theme.palette.secondaryText : LFTheme.success)
        }
        .padding(14)
        .background(theme.palette.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var importResultPanel: some View {
        Group {
            switch importState {
            case .idle:
                importedFileRow(
                    name: selectedFile,
                    subtitle: "No file selected",
                    icon: "doc.text",
                    color: LFTheme.info
                )
            case .preparing(let fileName, let phase):
                VStack(alignment: .leading, spacing: 12) {
                    importedFileRow(
                        name: fileName,
                        subtitle: phase.userFacingTitle,
                        icon: "hourglass",
                        color: LFTheme.warning
                    )
                    ProgressView()
                        .controlSize(.small)
                    Text("Preparing a read-only preview. You can cancel before confirmation.")
                        .font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText)
                    if let challenge = activeStatementPasswordChallenge {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Password required")
                                .font(theme.typography.formBody.weight(.semibold))
                            if let item = importCentre.currentItem {
                                Text("Statement \(item.queuePosition + 1) of \(importCentre.items.count): \(challenge.fileName)")
                                    .font(theme.typography.formCaption.weight(.semibold))
                            }
                            Text("Enter the statement password to unlock this PDF. It will be remembered in macOS Keychain only after the institution is verified.")
                                .font(theme.typography.formCaption)
                                .foregroundStyle(theme.palette.secondaryText)
                            SecureField("Statement password", text: $statementPassword)
                                .lfTextField()
                                .onSubmit {
                                    submitStatementPassword(challenge)
                                }
                            HStack {
                                Button("Cancel") {
                                    statementPassword = ""
                                    statementPasswordChallenges.cancel(challengeID: challenge.id)
                                }
                                .lfSecondaryAction()
                                Spacer()
                                Button("Unlock") {
                                    submitStatementPassword(challenge)
                                }
                                .lfPrimaryAction()
                                .disabled(statementPassword.isEmpty)
                            }
                        }
                        .padding(12)
                        .background(theme.palette.contentSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            case .previewReady(let preparedImport), .validationFailed(let preparedImport), .committing(let preparedImport):
                VStack(alignment: .leading, spacing: 10) {
                    preparedImportPreview(preparedImport, displayName: selectedFile)
                    if case .committing = importState {
                        Text("Importing confirmed financial data. This write cannot be cancelled safely.")
                            .font(theme.typography.formCaption.weight(.semibold))
                            .foregroundStyle(LFTheme.warning)
                    }
                }
            case .completed(let outcome):
                VStack(alignment: .leading, spacing: 12) {
                    importedFileRow(
                        name: outcome.fileName,
                        subtitle: outcome.fileSubtitle,
                        icon: outcome.iconName,
                        color: outcome.tone.color
                    )

                    HStack(spacing: 8) {
                        LFStatusBadge(
                            title: outcome.validationStatus,
                            color: outcome.validationStatus == "Validation Passed" ? LFTheme.success : LFTheme.danger
                        )
                        LFStatusBadge(title: outcome.persistenceStatus, color: outcome.tone.color)
                    }

                    if let recovery = outcome.recoveryPresentation {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: recovery.iconName)
                                    .foregroundStyle(recovery.tone.color)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(recovery.title)
                                        .font(theme.typography.formBody.weight(.semibold))
                                    Text(recovery.explanation)
                                        .font(theme.typography.formCaption)
                                        .foregroundStyle(theme.palette.secondaryText)
                                }
                                Spacer(minLength: 0)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(recovery.accessibilityText)

                            if let action = availableConfirmedImportRecoveryAction(for: outcome) {
                                Button {
                                    performConfirmedImportRecoveryAction(action, for: outcome)
                                } label: {
                                    Label(action.label, systemImage: "arrow.clockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .lfSecondaryAction()
                                .disabled(
                                    confirmedImportRecoveryActionRequestID != nil
                                        || importCentre.isPreparationDraining
                                )
                            }
                        }
                        .padding(12)
                        .background(recovery.tone.color.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let accountPresentation = outcome.accountOutcomePresentation {
                        ImportAccountOutcomeView(
                            presentation: accountPresentation,
                            iconName: outcome.tone == .success
                                ? "person.crop.circle.badge.checkmark"
                                : "person.crop.circle.badge.exclamationmark",
                            tone: outcome.tone
                        )
                    }

                    if !outcome.isInvestmentImport {
                        LFInfoRow(title: "Transactions", value: "\(outcome.transactionCount)")
                    }

                    if outcome.isEquivalentSupportingSource {
                        Text("LedgerForge recorded this document as a supporting equivalent source. The previously accepted source remains authoritative and no additional financial history was written.")
                            .font(theme.typography.formCaption)
                            .foregroundStyle(theme.palette.secondaryText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(LFTheme.success.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if outcome.isPreviouslyImported {
                        if let completedAtISO = outcome.previousImportCompletedAtISO {
                            LFInfoRow(title: "Prior Import", value: ImportInstantFormatting.display(completedAtISO))
                        }
                        if let accountName = outcome.previousAccountDisplayName {
                            LFInfoRow(title: "Account", value: accountName)
                        }
                        Text("This exact statement was imported previously. LedgerForge did not write another document, import session, transaction, account, or identifier.")
                            .font(theme.typography.formCaption)
                            .foregroundStyle(theme.palette.secondaryText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(LFTheme.warning.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let message = outcome.message {
                        Text(message)
                            .font(theme.typography.formCaption)
                            .foregroundStyle(theme.palette.secondaryText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.palette.controlSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if outcome.allowsViewingTransactions {
                        if let accountId = outcome.accountId,
                           let account = accountsViewModel.accounts.first(where: { $0.id == accountId }) {
                            LFInfoRow(title: "Verified Account", value: account.displayName)
                        }
                        if let redactedIdentifier = outcome.redactedIdentifier {
                            LFInfoRow(title: "Verified Identifier", value: redactedIdentifier)
                        }
                        if outcome.importSessionId != nil {
                            LFInfoRow(title: "Import Session", value: "Persisted")
                        }
                    }

                    if outcome.allowsViewingTransactions || outcome.isPreviouslyImported || outcome.isEquivalentSupportingSource {
                        if let accountId = outcome.accountId,
                           accountsViewModel.accounts.contains(where: { $0.id == accountId }) {
                            Button {
                                accountsViewModel.selectAccount(repositoryAccountID: accountId)
                                selectedSection = .accounts
                            } label: {
                                Label("View Account", systemImage: "person.crop.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .lfSecondaryAction()
                        }
                        if outcome.allowsViewingTransactions {
                            Button {
                                selectedSection = .transactions
                            } label: {
                                Label("View Transactions", systemImage: "list.bullet")
                                    .frame(maxWidth: .infinity)
                            }
                            .lfPrimaryAction()
                        }
                    }
                }
            case .skipped(let fileName):
                importedFileRow(
                    name: fileName,
                    subtitle: "Statement skipped. No data was written.",
                    icon: "forward.fill",
                    color: LFTheme.warning
                )
            case .cancelled(let fileName):
                importedFileRow(
                    name: fileName,
                    subtitle: "Preparation cancelled. No data was written.",
                    icon: "xmark.circle.fill",
                    color: theme.palette.secondaryText
                )
            case .failed(let fileName, let message, let retrySourceURL):
                VStack(alignment: .leading, spacing: 10) {
                    importedFileRow(
                        name: fileName,
                        subtitle: message,
                        icon: "exclamationmark.triangle.fill",
                        color: LFTheme.danger
                    )
                    if retrySourceURL != nil {
                        Text("The source could not be read. You can retry from the beginning.")
                            .font(theme.typography.formCaption)
                            .foregroundStyle(theme.palette.secondaryText)
                    }
                }
            }
        }
    }

    private var importAttemptHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Import History").font(theme.typography.formHeading)
                Spacer()
                Text("\(importHistoryViewModel.attempts.count)").font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            }
            if importHistoryViewModel.attempts.isEmpty {
                Text("Supported import outcomes appear here after processing.")
                    .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            } else {
                ForEach(importHistoryViewModel.attempts.prefix(8)) { attempt in
                    let presentation = DurableImportAttemptPresentation(attempt: attempt)
                    Button { importHistoryViewModel.select(id: attempt.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(presentation.outcome.label).font(theme.typography.formBody.weight(.semibold))
                                Text(ImportInstantFormatting.display(attempt.createdAtISO)).font(theme.typography.finePrint).foregroundStyle(theme.palette.secondaryText)
                            }
                            Spacer()
                            Text(attempt.outcomeCode == ImportAttemptOutcome.partialImportCommitted.rawValue
                                 ? "\(attempt.importedTransactionCount ?? attempt.transactionCount) new · partial"
                                 : "\(attempt.transactionCount) transactions")
                                .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                        }
                        .padding(9).background(theme.palette.contentSurface).clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(LFPlainActionStyle())
                    .accessibilityLabel("\(presentation.outcome.label). \(presentation.outcome.explanation)")
                }
            }
            if let attempt = importHistoryViewModel.selectedAttempt {
                let presentation = DurableImportAttemptPresentation(attempt: attempt)
                Divider()
                HStack { Text("Attempt Detail").font(theme.typography.formBody.weight(.semibold)); Spacer(); Button("Close") { importHistoryViewModel.clearSelection() }.lfSecondaryAction() }
                LFInfoRow(title: "Outcome", value: presentation.outcome.label)
                LFInfoRow(title: "Coverage", value: presentation.coverage)
                LFInfoRow(title: "Guidance", value: presentation.guidance)
                if let accountPresentation = DurableImportAccountOutcomeSection.presentation(for: attempt) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account Outcome")
                            .font(theme.typography.formCaption.weight(.semibold))
                            .foregroundStyle(theme.palette.secondaryText)
                        ImportAccountOutcomeView(
                            presentation: accountPresentation,
                            iconName: durableAccountOutcomeIcon(outcomeCode: attempt.outcomeCode),
                            tone: durableAccountOutcomeTone(outcomeCode: attempt.outcomeCode)
                        )
                    }
                }
                if let sourceCount = attempt.sourceRowCount {
                    LFInfoRow(title: "Source Rows", value: "\(sourceCount)")
                    LFInfoRow(title: "Imported", value: "\(attempt.importedTransactionCount ?? 0)")
                    LFInfoRow(title: "Already Represented", value: "\(attempt.recognizedExistingRowCount ?? 0)")
                    LFInfoRow(title: "Blocked", value: "\(attempt.blockedRowCount ?? 0)")
                }
                if let accountID = attempt.accountId, accountsViewModel.accounts.contains(where: { $0.id == accountID }) {
                    Button("View Account") { accountsViewModel.selectAccount(repositoryAccountID: accountID); selectedSection = .accounts }
                        .font(theme.typography.formCaption.weight(.semibold)).buttonStyle(LFPlainActionStyle()).foregroundStyle(theme.palette.accentHover)
                }
            }
        }
        .padding(12).background(theme.palette.contentSurface).clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func durableAccountOutcomeTone(outcomeCode: String) -> ImportOutcomeTone {
        switch ImportAttemptOutcome(rawValue: outcomeCode) {
        case .successfulImport, .partialImportCommitted:
            return .success
        default:
            return .warning
        }
    }

    private func durableAccountOutcomeIcon(outcomeCode: String) -> String {
        durableAccountOutcomeTone(outcomeCode: outcomeCode) == .success
            ? "person.crop.circle.badge.checkmark"
            : "person.crop.circle.badge.exclamationmark"
    }

    private func preparedImportPreview(_ preparedImport: PreparedImport, displayName: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            importedFileRow(
                name: displayName ?? preparedImport.fileName,
                subtitle: preparedImport.validation.passed ? "Prepared for confirmation" : "Validation failed before persistence",
                icon: preparedImport.validation.passed ? "doc.text.magnifyingglass" : "xmark.octagon.fill",
                color: preparedImport.validation.passed ? LFTheme.success : LFTheme.danger
            )

            if preparedImport.financialDocument.investmentStatementEvidence != nil {
                InvestmentImportReviewView(preparation: preparedImport) { importCentre.updateInvestmentChoices($0) }
            } else {
            HStack(spacing: 8) {
                LFStatusBadge(title: preparedImport.detectedInstitution.rawValue, color: theme.palette.accent)
                LFStatusBadge(title: preparedImport.detectedDocumentType.rawValue, color: LFTheme.info)
                LFStatusBadge(title: preparedImport.parserName, color: theme.palette.secondaryText)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                LFInfoRow(title: "Transactions", value: "\(preparedImport.transactionCount)")
                LFInfoRow(title: "Currency", value: preparedImport.detectedCurrency ?? "Unknown")
                LFInfoRow(title: "Account", value: preparedImport.accountMetadata ?? "Unknown")
                LFInfoRow(title: "Statement Period", value: statementPeriodText(preparedImport.statementPeriod))
                LFInfoRow(title: "Opening Balance", value: balanceText(preparedImport.validation.openingBalance, currency: preparedImport.detectedCurrency))
                LFInfoRow(title: "Closing Balance", value: balanceText(preparedImport.validation.closingBalance, currency: preparedImport.detectedCurrency))
            }

            importIdentityReviewPanel(preparedImport)

            switch preparedImport.statementEquivalenceReview {
            case .equivalent:
                VStack(alignment: .leading, spacing: 6) {
                    Label("Equivalent statement source", systemImage: "checkmark.seal.fill")
                        .font(theme.typography.formBody.weight(.semibold))
                        .foregroundStyle(LFTheme.success)
                    Text("This PDF/XLS statement is financially identical to an accepted source. Confirmation records durable supporting evidence, preserves the existing source as authoritative, and writes 0 additional transactions.")
                        .font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
                .padding(12)
                .background(LFTheme.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            case .conflict:
                statementEquivalenceBlockingPanel(
                    title: "Statement equivalence conflict",
                    explanation: "An accepted source for this account and statement period differs financially. Confirmation is blocked and no new financial history can be written.",
                    tone: .danger
                )
            case .evidenceUnavailable:
                statementEquivalenceBlockingPanel(
                    title: "Equivalence evidence unavailable",
                    explanation: "Overlapping accepted history cannot be proved equivalent with the exact projection contract. Confirmation is blocked for integrity review.",
                    tone: .warning
                )
            case .formatAlreadyRecorded:
                statementEquivalenceBlockingPanel(
                    title: "Source format already represented",
                    explanation: "This statement period already has an accepted source in the same format. Confirmation is blocked.",
                    tone: .warning
                )
            case .notApplicable, .firstAcceptedSource:
                EmptyView()
            }

            if case .eligible(let plan) = partialImportReview {
                partialImportReviewPanel(plan, preparedImport: preparedImport)
            }
            }


        }
    }

    @ViewBuilder
    private func importIdentityReviewPanel(_ preparedImport: PreparedImport) -> some View {
        let projection = ImportIdentityReviewUIProjection(review: importIdentityReview)
        if let presentation = projection.presentation,
           let iconName = projection.iconName {
            VStack(alignment: .leading, spacing: 10) {
                ImportAccountOutcomeView(
                    presentation: presentation,
                    iconName: iconName,
                    tone: projection.tone
                )

                if let matchedAccountID = projection.matchedAccountID,
                   let account = accountsViewModel.accounts.first(where: { $0.id == matchedAccountID }) {
                    VStack(alignment: .leading, spacing: 6) {
                        LFInfoRow(title: "Destination Account", value: account.displayName)
                        LFInfoRow(title: "Institution", value: account.institution)
                    }
                }

                if case .choiceRequired = importIdentityReview {
                    ForEach(accountsViewModel.accounts) { account in
                        let eligible = projection.eligibleAccountIDs.contains(account.id)
                        Button {
                            importCentre.updateAccountChoice(.useExistingAccount(accountId: account.id))
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(account.displayName)
                                    Text(account.institution)
                                        .font(theme.typography.formCaption)
                                        .foregroundStyle(theme.palette.secondaryText)
                                    if !eligible {
                                        Text(accountMatchUnavailableReason(account, for: preparedImport))
                                            .font(theme.typography.formCaption)
                                            .foregroundStyle(theme.palette.secondaryText)
                                    }
                                }
                                Spacer()
                                Image(systemName: importAccountChoice == .useExistingAccount(accountId: account.id) ? "checkmark.circle.fill" : "circle")
                            }
                            .padding(10)
                            .background(theme.palette.controlSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(LFPlainActionStyle())
                        .foregroundStyle(theme.palette.primaryText)
                        .disabled(!eligible)
                    }
                    newAccountCreationChoice(preparedImport, instrumentAware: false)
                }
                if case .liabilityAccountChoiceRequired = importIdentityReview {
                    ForEach(accountsViewModel.accounts.filter { projection.eligibleAccountIDs.contains($0.id) }) { account in
                        Button {
                            importCentre.updateAccountChoice(.useExistingAccount(accountId: account.id))
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Use existing liability account")
                                        .font(theme.typography.formBody.weight(.semibold))
                                    Text(account.displayName)
                                    Text(account.institution)
                                        .font(theme.typography.formCaption)
                                        .foregroundStyle(theme.palette.secondaryText)
                                }
                                Spacer()
                                Image(systemName: importAccountChoice == .useExistingAccount(accountId: account.id) ? "checkmark.circle.fill" : "circle")
                            }
                            .padding(10)
                            .background(theme.palette.controlSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(LFPlainActionStyle())
                        .foregroundStyle(theme.palette.primaryText)
                    }
                    newAccountCreationChoice(preparedImport, instrumentAware: false)
                }
                if case .cardChoiceRequired = importIdentityReview {
                    let sections = preparedImport.financialDocument.cardStatementEvidence?.instrumentSections ?? []
                    let sectionIDs = sections.map(\.documentScopedSectionID)
                    Text("Liability account")
                        .font(theme.typography.formBody.weight(.semibold))
                    ForEach(accountsViewModel.accounts.filter { projection.eligibleAccountIDs.contains($0.id) }) { account in
                        let selected = cardSectionDraftAccountID == account.id
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                importCentre.selectCardLiabilityAccount(accountID: account.id, requiredSectionIDs: sectionIDs)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(account.displayName)
                                        Text(account.institution).font(theme.typography.formCaption)
                                            .foregroundStyle(theme.palette.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                }
                            }
                            .buttonStyle(LFPlainActionStyle())
                            if selected {
                                let instruments = cardStore.snapshot.instruments.filter { $0.liabilityAccountID == account.id }
                                ForEach(sections, id: \.documentScopedSectionID) { section in
                                    cardSectionSelection(section: section, allSectionIDs: sectionIDs,
                                                         accountID: account.id, instruments: instruments)
                                }
                                if sections.isEmpty {
                                    Text("This statement contains no card sections to assign.")
                                        .font(theme.typography.formCaption)
                                        .foregroundStyle(theme.palette.secondaryText)
                                }
                            }
                        }
                        .padding(10)
                        .background(theme.palette.controlSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    newAccountCreationChoice(preparedImport, instrumentAware: true)
                }
            }
            .padding(12)
            .background(theme.palette.accent.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if case .unavailable = importIdentityReview,
                  preparedImport.detectedDocumentType == .bankAccount {
            newAccountCreationChoice(preparedImport, instrumentAware: false)
                .onChange(of: preparedImport.id, initial: true) { _, _ in
                    if importAccountChoice == nil {
                        importCentre.updateAccountChoice(.createNewAccount(displayName: proposedAccountName(preparedImport)))
                    }
                }
        }
    }

    private func accountMatchUnavailableReason(_ account: AccountsAccountPresentation, for prepared: PreparedImport) -> String {
        let expectedType: AccountType = prepared.detectedDocumentType == .creditCard ? .creditCard : .bank
        if account.accountType != expectedType {
            return "Different account type: " + account.accountTypeLabel + "."
        }
        if account.currencyCode != prepared.detectedCurrency {
            return "Different account currency: " + account.currencyCode + "."
        }
        if account.institution != prepared.detectedInstitution.rawValue {
            return "This statement belongs to a different institution."
        }
        if !account.identitySummaries.isEmpty {
            return "An account identifier is already recorded; this statement is not a verified match."
        }
        return "Not compatible with this statement’s account evidence."
    }

    private func proposedAccountName(_ prepared: PreparedImport) -> String {
        let sourceName = prepared.accountMetadata?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let sourceName, !sourceName.isEmpty,
           sourceName != prepared.detectedInstitution.rawValue { return sourceName }
        return ImportPersistenceMapper.displayAccountName(
            institutionName: prepared.detectedInstitution.rawValue,
            documentType: prepared.detectedDocumentType,
            currency: prepared.detectedCurrency,
            fallbackFileName: prepared.fileName
        )
    }

    private func newAccountCreationChoice(_ prepared: PreparedImport, instrumentAware: Bool) -> some View {
        let isCard = prepared.detectedDocumentType == .creditCard
        let selected = importAccountChoice?.proposedAccountDisplayName != nil
        let makeChoice: (String) -> ImportAccountChoice = { name in
            instrumentAware ? .createNewCardLiabilityAccountAndInstrument(displayName: name)
                : .createNewAccount(displayName: name)
        }
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                importCentre.updateAccountChoice(makeChoice(proposedAccountName(prepared)))
            } label: {
                HStack {
                    Text(isCard ? "Create separate credit card account" : "Create new bank account")
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                }
            }
            .buttonStyle(LFPlainActionStyle())
            if selected {
                LabeledContent("Display name") {
                    TextField("Account display name", text: Binding(
                        get: { importAccountChoice?.proposedAccountDisplayName ?? proposedAccountName(prepared) },
                        set: { importCentre.updateAccountChoice(makeChoice($0)) }
                    ))
                    .lfTextField()
                    .accessibilityIdentifier("import.newAccountDisplayName")
                }
                LFInfoRow(title: "Account type", value: isCard ? "Credit Card" : "Bank")
                LFInfoRow(title: "Currency", value: prepared.detectedCurrency ?? "Unavailable")
                if isCard { LFInfoRow(title: "Treatment", value: "Credit-card liability") }
                Text("The account is created only when you confirm this import.")
                    .font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.secondaryText)
                if importAccountChoice?.proposedAccountDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                    Text("Enter an account display name.")
                        .font(theme.typography.formCaption).foregroundStyle(LFTheme.warning)
                }
            }
        }
        .font(theme.typography.formBody)
        .padding(10)
        .background(theme.palette.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private enum CardSelection: Hashable {
        case pending, new, existing(String)
    }

    private func cardLabel(_ instrument: CardInstrument) -> String {
        let statements = cardStore.snapshot.statements.filter { $0.instrumentIDs.contains(instrument.id) }
        let sections = statements.flatMap(\.sections).filter { $0.instrumentID == instrument.id }
        let holders = Set(sections.compactMap(\.holderLabel)).sorted()
        let identifiers = Set((instrument.sourceObservations + sections.flatMap(\.sourceObservations)).map(\.value)).sorted()
        let parts = holders + identifiers
        let dates = Set(statements.compactMap(\.statementDate)).sorted()
        let context: String
        if let first = dates.first, let last = dates.last {
            context = first == last ? "Statement \(formatDate(first))" : "Statements \(formatDate(first)) – \(formatDate(last))"
        } else { context = "Statement date unavailable" }
        return (parts.isEmpty ? "Card details unavailable" : parts.joined(separator: " · ")) + " · " + context
    }

    private func cardSectionSelection(
        section: CardInstrumentSectionEvidence, allSectionIDs: [String],
        accountID: String, instruments: [CardInstrument]
    ) -> some View {
        let draft = cardSectionDraftChoices[section.documentScopedSectionID]
        let selection: CardSelection = switch draft {
        case .reuseExistingInstrument(let id): .existing(id)
        case .createNewInstrument: .new
        case nil: .pending
        }
        let update: (ImportCardInstrumentChoice) -> Void = { choice in
            importCentre.updateCardSectionChoice(accountID: accountID, sectionID: section.documentScopedSectionID,
                                                 choice: choice, requiredSectionIDs: allSectionIDs)
        }
        let labels = instruments.map(cardLabel)
        let ambiguousLabels = Set(Dictionary(grouping: labels, by: { $0 }).filter { $0.value.count > 1 }.keys)
        return VStack(alignment: .leading, spacing: 9) {
            Text(section.holderLabel ?? "Card section \(section.sourceOrdinal)")
                .font(theme.typography.formBody.weight(.semibold))
            if let observed = section.sourceIdentityObservations.first?.value {
                Text(observed).font(theme.typography.formCaption.monospaced())
                    .foregroundStyle(theme.palette.secondaryText)
            }
            Picker("Card", selection: Binding(get: { selection }, set: { choice in
                switch choice {
                case .existing(let id): update(.reuseExistingInstrument(instrumentId: id))
                case .new: update(.createNewInstrument())
                case .pending: break
                }
            })) {
                Text("Choose a card").tag(CardSelection.pending)
                ForEach(instruments) { instrument in
                    Text("Reuse · " + cardLabel(instrument)).tag(CardSelection.existing(instrument.id))
                        .disabled(ambiguousLabels.contains(cardLabel(instrument)))
                }
                Text("Create new card").tag(CardSelection.new)
            }
            if Set(labels).count != labels.count {
                Text("Some recorded cards have indistinguishable source details. They need your identification before reuse or a relationship can be selected; those choices are unavailable.")
                    .font(theme.typography.formCaption).foregroundStyle(LFTheme.warning)
            }
            if case .createNewInstrument(let relationship, let relatedID) = draft, !instruments.isEmpty {
                Picker("Relationship", selection: Binding<CardInstrumentRelationshipKind?>(
                    get: { relationship },
                    set: { update(.createNewInstrument(relationship: $0, relatedInstrumentId: $0 == nil ? nil : relatedID)) }
                )) {
                    Text("No relationship asserted").tag(Optional<CardInstrumentRelationshipKind>.none)
                    ForEach(CardInstrumentRelationshipKind.allCases, id: \.rawValue) { kind in
                        Text(cardRelationshipTitle(kind)).tag(Optional(kind))
                    }
                }
                if relationship != nil {
                    Picker("Related card", selection: Binding<String?>(
                        get: { relatedID },
                        set: { update(.createNewInstrument(relationship: relationship, relatedInstrumentId: $0)) }
                    )) {
                        Text("Choose the related card").tag(Optional<String>.none)
                        ForEach(instruments) { instrument in
                            Text(cardLabel(instrument)).tag(Optional(instrument.id))
                                .disabled(ambiguousLabels.contains(cardLabel(instrument)))
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(theme.palette.contentSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func cardRelationshipTitle(_ relationship: CardInstrumentRelationshipKind) -> String {
        switch relationship {
        case .additionalConcurrent: return "additional/concurrent"
        case .replacement: return "replacement"
        case .renewal: return "renewal"
        case .upgrade: return "upgrade"
        case .unspecified: return "unspecified relationship"
        }
    }

    private var importConfirmationLabel: String {
        if case .previewReady(let preparedImport) = importState,
           case .equivalent = preparedImport.statementEquivalenceReview {
            return "Record Equivalent Source"
        }
        if case .eligible(let plan) = partialImportReview {
            return "Import \(plan.importedCount) new transaction\(plan.importedCount == 1 ? "" : "s")"
        }
        return "Confirm Import"
    }

    private func statementEquivalenceBlockingPanel(
        title: String,
        explanation: String,
        tone: ImportOutcomeTone
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(theme.typography.formBody.weight(.semibold))
                .foregroundStyle(tone.color)
            Text(explanation)
                .font(theme.typography.formCaption)
                .foregroundStyle(theme.palette.secondaryText)
        }
        .padding(12)
        .background(tone.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statementEquivalenceBlocksConfirmation(_ preparedImport: PreparedImport) -> Bool {
        switch preparedImport.statementEquivalenceReview {
        case .conflict, .evidenceUnavailable, .formatAlreadyRecorded:
            return true
        case .notApplicable, .firstAcceptedSource, .equivalent:
            return false
        }
    }

    private var partialReviewBlocksConfirmation: Bool {
        switch partialImportReview {
        case .fullSupportedOverlap, .repeatedIncomingEvidence, .ownershipConflict,
                .repositoryIntegrityConflict:
            return true
        case .ordinaryFullImport, .eligible, .unsupportedEvidence:
            return false
        }
    }

    private func partialImportReviewPanel(
        _ plan: ReviewedPartialImportPlanDTO,
        preparedImport: PreparedImport
    ) -> some View {
        let selectedAccount = accountsViewModel.accounts.first { $0.id == plan.existingAccountId }
        let uniqueMinor = plan.rows
            .filter { $0.disposition == .importedUnique }
            .reduce(Int64.zero) { partial, row in
                let result = partial.addingReportingOverflow(row.amountMinor)
                return result.overflow ? partial : result.partialValue
            }
        let uniqueImpact = (try? Money(
            amount: Decimal(uniqueMinor) / Decimal(100),
            currency: plan.basePlan.proposedAccount.nativeCurrency
        )).map { MoneyFormatting.display($0) } ?? "Unavailable"
        let transactionsByOrdinal = Dictionary(
            uniqueKeysWithValues: preparedImport.financialDocument.transactions.compactMap {
                transaction in transaction.documentScopedSourceOrder.map { ($0.ordinal, transaction) }
            }
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("Reviewed Partial Import")
                .font(theme.typography.formHeading)
            Text("Parser-verified, account-scoped Axis UPI evidence recognizes the earlier rows. LedgerForge will preserve the complete statement and import only the reviewed later rows.")
                .font(theme.typography.formCaption)
                .foregroundStyle(theme.palette.secondaryText)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                LFInfoRow(title: "Declared Period", value: "\(plan.basePlan.declaredStatementStartISO ?? "Unknown") – \(plan.basePlan.declaredStatementEndISO ?? "Unknown")")
                LFInfoRow(title: "Selected Account", value: selectedAccount?.displayName ?? "Existing account")
                LFInfoRow(title: "Source Rows", value: "\(plan.sourceRowCount)")
                LFInfoRow(title: "Already Represented", value: "\(plan.recognizedCount)")
                LFInfoRow(title: "New Transactions", value: "\(plan.importedCount)")
                LFInfoRow(title: "Blocked", value: "\(plan.blockedCount)")
                LFInfoRow(title: "Opening Balance Evidence", value: "\(plan.basePlan.proposedAccount.nativeCurrency) \(plan.basePlan.openingBalanceDecimal ?? "Unavailable")")
                LFInfoRow(title: "Closing Balance Evidence", value: "\(plan.basePlan.proposedAccount.nativeCurrency) \(plan.basePlan.closingBalanceDecimal ?? "Unavailable")")
                LFInfoRow(title: "New Native-Currency Impact", value: uniqueImpact)
            }
            VStack(spacing: 0) {
                ForEach(plan.rows, id: \.sourceOrdinal) { row in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transactionsByOrdinal[row.sourceOrdinal]?.description ?? "Statement transaction")
                                .lineLimit(1)
                            Text("\(row.statementDateISO) · \(row.nativeCurrency) \(row.amountDecimal)")
                                .font(theme.typography.finePrint)
                                .foregroundStyle(theme.palette.secondaryText)
                        }
                        Spacer()
                        Text(row.disposition == .recognizedExisting ? "Already represented" : "Will import")
                            .font(theme.typography.formCaption.weight(.semibold))
                            .foregroundStyle(row.disposition == .recognizedExisting ? theme.palette.secondaryText : LFTheme.success)
                    }
                    .padding(.vertical, 7)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Statement row \(row.sourceOrdinal). \(row.disposition == .recognizedExisting ? "Already represented" : "Will import").")
                    if row.sourceOrdinal != plan.rows.last?.sourceOrdinal { Divider() }
                }
            }
            Text("Repository truth is rechecked atomically at confirmation. If it changes, no part of this reviewed plan will be imported.")
                .font(theme.typography.formCaption)
                .foregroundStyle(LFTheme.warning)
        }
        .padding(12)
        .background(theme.palette.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reviewed partial import. \(plan.recognizedCount) already represented. \(plan.importedCount) will import. Zero blocked.")
    }

    private var preparedTransactionPreview: PreparedImport? {
        switch importState {
        case .previewReady(let prepared), .validationFailed(let prepared), .committing(let prepared):
            return prepared.financialDocument.salaryStatementEvidence == nil && prepared.financialDocument.investmentStatementEvidence == nil ? prepared : nil
        default: return nil
        }
    }

    private struct PreviewColumns {
        let date: CGFloat, description: CGFloat, currency: CGFloat, effect: CGFloat, amount: CGFloat, balance: CGFloat
        var minimumWidth: CGFloat { date + description + currency + effect + amount + balance + 70 }
        var widths: [CGFloat?] { [date, nil, currency, effect, amount, balance] }
    }

    private func previewEffect(_ transaction: Transaction) -> String {
        transaction.cardLiabilityEffect == .increasesAmountOwed ? "Charge" :
            transaction.cardLiabilityEffect == .decreasesAmountOwed ? "Payment/Credit" :
            transaction.credit != nil ? "Credit" : "Debit"
    }

    private func previewColumns(_ prepared: PreparedImport) -> PreviewColumns {
        let rows = Array(prepared.financialDocument.transactions.prefix(12))
        let font = theme.typography.nativeFont(.formCaption)
        let moneyFont = theme.typography.nativeFont(.formCaption, tabularDigits: true)
        func width(_ header: String, _ values: [String], money: Bool = false) -> CGFloat {
            ceil(([header] + values).map {
                ($0 as NSString).size(withAttributes: [.font: money ? moneyFont : font]).width
            }.max() ?? 0) + 8
        }
        return PreviewColumns(
            date: width("Date", rows.map { formatDate($0.statementDate) }),
            description: max(width("Description", []), font.pointSize * 13),
            currency: width("Currency", rows.map(\.currency)),
            effect: width("Type", rows.map(previewEffect)),
            amount: width("Amount", rows.map(\.signedAmountDisplay), money: true),
            balance: width("Balance", rows.map { balanceText($0.balance, currency: $0.currency) }, money: true)
        )
    }

    private func previewCanShareValidation(_ prepared: PreparedImport?, height: CGFloat) -> Bool {
        guard let prepared, importValidationContentHeight > 0 else { return false }
        let font = theme.typography.nativeFont(.formCaption)
        let rowHeight = font.pointSize * 1.4 + 16 +
            (prepared.financialDocument.cardStatementEvidence == nil ? 0 : theme.typography.nativeFont(.finePrint).pointSize * 1.4 + 2)
        let previewHeaderHeight = theme.typography.nativeFont(.formBody).pointSize * 1.4 + font.pointSize * 2.8 + 44
        // Use the rendered review height, including its controls and empty-state
        // spacing. Keep at least three rows visible before sharing the column.
        return height >= importValidationContentHeight + 2 * theme.spacing.panelPadding + 18 +
            previewHeaderHeight + CGFloat(min(3, prepared.transactionCount)) * (rowHeight + 8)
    }

    private func transactionPreviewPanel(_ prepared: PreparedImport, columns: PreviewColumns) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transaction Preview").font(theme.typography.formBody.weight(.semibold))
            if prepared.transactionCount > 12 {
                Text("First 12 of \(prepared.transactionCount) transactions · source order")
                    .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            }
            HStack(spacing: 14) {
                ForEach(Array(["Date", "Description", "Currency", "Type", "Amount", "Balance"].enumerated()), id: \.offset) { index, title in
                    Text(title)
                        .frame(minWidth: index == 1 ? columns.description : nil,
                               maxWidth: index == 1 ? .infinity : nil, alignment: index >= 4 ? .trailing : .leading)
                        .frame(width: columns.widths[index], alignment: index >= 4 ? .trailing : .leading)
                }
            }
            .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            .padding(.vertical, 10)
            ForEach(prepared.financialDocument.transactions.prefix(12)) { transaction in
                previewTransactionRow(transaction, columns: columns,
                                      cardEvidence: prepared.financialDocument.cardStatementEvidence)
            }
            if prepared.transactionCount == 0 {
                Text("This statement has no transaction rows.")
                    .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            }
        }
        .frame(minWidth: columns.minimumWidth, maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("import.transactionPreview")
    }

    private func previewTransactionRow(
        _ transaction: Transaction,
        columns: PreviewColumns,
        cardEvidence: CardStatementEvidence? = nil
    ) -> some View {
        HStack(spacing: 14) {
            Text(formatDate(transaction.statementDate))
                .frame(width: columns.date, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .lineLimit(1)
                if let scope = cardTransactionScopeLabel(transaction, evidence: cardEvidence) {
                    Text(scope)
                        .font(theme.typography.finePrint)
                        .foregroundStyle(theme.palette.secondaryText)
                }
            }
                .frame(minWidth: columns.description, maxWidth: .infinity, alignment: .leading)
            Text(transaction.currency)
                .foregroundStyle(theme.palette.secondaryText)
                .frame(width: columns.currency, alignment: .leading)
            Text(previewEffect(transaction))
                .foregroundStyle(transaction.cardLiabilityEffect == .decreasesAmountOwed || transaction.credit != nil ? theme.financialPositive : theme.financialNegative)
                .frame(width: columns.effect, alignment: .leading)
            Text(transaction.signedAmountDisplay)
                .foregroundStyle(transaction.cardLiabilityEffect == .decreasesAmountOwed || transaction.credit != nil ? theme.financialPositive : theme.financialNegative)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: columns.amount, alignment: .trailing)
            Text(balanceText(transaction.balance, currency: transaction.currency))
                .foregroundStyle(theme.palette.secondaryText)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: columns.balance, alignment: .trailing)
        }
        .font(theme.typography.formCaption)
        .padding(.vertical, 8)
    }

    private func cardTransactionScopeLabel(
        _ transaction: Transaction,
        evidence: CardStatementEvidence?
    ) -> String? {
        guard let annotation = evidence?.annotation(for: transaction) else { return nil }
        switch annotation.financialScope {
        case .accountLevel:
            return "Liability-account activity"
        case .instrument:
            let sectionID = annotation.documentScopedSectionID
            let ordinal = evidence?.instrumentSections.first(where: {
                $0.documentScopedSectionID == sectionID
            })?.sourceOrdinal
            return ordinal.map { "Card section \($0) activity" } ?? "Card-instrument activity"
        }
    }

    private var importFooterAction: some View {
        Group {
        if importCentre.currentItemWillAutomaticallyCommit {
            Label("Importing validated statement…", systemImage: "arrow.down.doc")
                .font(theme.typography.formBody)
                .foregroundStyle(theme.palette.secondaryText)
        } else {
        ImportCentreFooterRenderer(
            importState: importState,
            confirmationLabel: importConfirmationLabel,
            confirmationIsDisabled: { preparedImport in
                (preparedImport.financialDocument.salaryStatementEvidence == nil &&
                    preparedImport.financialDocument.investmentStatementEvidence == nil &&
                    !ImportAccountConfirmationPolicy.allowsConfirmation(
                        review: importIdentityReview,
                        choice: importAccountChoice,
                        requiredCardSectionIDs: preparedImport.financialDocument.cardStatementEvidence?.instrumentSections.map(\.documentScopedSectionID),
                        requiresNamedCreation: preparedImport.detectedDocumentType == .bankAccount
                    )) ||
                    preparedImport.investmentConfirmationBlocked ||
                    partialReviewBlocksConfirmation ||
                    statementEquivalenceBlocksConfirmation(preparedImport)
            },
            confirm: { preparedImport in
#if DEBUG
                requestProtectedImportAction(.confirm(preparedImport))
#else
                Task {
                    await confirmPreparedImport(preparedImport)
                }
#endif
            },
            retryPreparation: {
#if DEBUG
                requestProtectedImportAction(.retryPreparation)
#else
                retryCurrentPreparation()
#endif
            },
            viewTransactions: { selectedSection = .transactions }
        )
        }
        }
    }

    private var validationReviewPanel: some View {
        Group {
            switch ValidationReviewPresentation.presentation(for: importState) {
            case .validationResults(let preparedImport):
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        LFStatusBadge(
                            title: preparedImport.validation.passed ? "Validation Passed" : "Validation Failed",
                            color: preparedImport.validation.passed ? LFTheme.success : LFTheme.danger
                        )
                        LFStatusBadge(
                            title: "\(preparedImport.validation.issues.count) issue(s)",
                            color: preparedImport.validation.issues.isEmpty ? LFTheme.success : LFTheme.warning
                        )
                    }

                    if let investment = preparedImport.financialDocument.investmentStatementEvidence {
                        LFInfoRow(title: "Closing positions read", value: "\(investment.scopes.reduce(0) { $0 + $1.positions.count })")
                        Text("Quantity and source cost are applied together after confirmation.")
                            .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                    } else if let salary = preparedImport.financialDocument.salaryStatementEvidence {
                        LFStatusBadge(title: "Imported Source Truth", color: LFTheme.info)
                        LFInfoRow(title: "Document Kind", value: salary.kind.displayName)
                        LFInfoRow(title: "Pay Period", value: salary.financialPeriod.canonical)
                        LFInfoRow(title: "Print Date", value: salary.printDate?.canonical ?? "Not printed")
                        LFInfoRow(title: "Earnings", value: formatCurrency(salary.printedEarningsTotal.amount, currencyCode: "QAR"))
                        LFInfoRow(title: "Deductions", value: salary.printedDeductionsTotal.map { formatCurrency($0.amount, currencyCode: "QAR") } ?? "Not printed")
                        LFInfoRow(title: "Payment Total", value: formatCurrency(salary.printedPaymentTotal.amount, currencyCode: "QAR"))
                        Text("\(salary.earnings.count) earning line(s) and \(salary.deductions.count) deduction line(s), preserved in source order.")
                            .font(theme.typography.formCaption)
                            .foregroundStyle(theme.palette.secondaryText)
                    } else {
                        LFInfoRow(title: "Rows Read", value: "\(preparedImport.validation.rowsRead)")
                        LFInfoRow(title: "Transactions Parsed", value: "\(preparedImport.validation.transactionsParsed)")
                        LFInfoRow(title: "Debit Total", value: balanceText(preparedImport.validation.debitTotal, currency: preparedImport.detectedCurrency))
                        LFInfoRow(title: "Credit Total", value: balanceText(preparedImport.validation.creditTotal, currency: preparedImport.detectedCurrency))
                    }

                    Text("No data has been written.")
                        .font(theme.typography.formCaption.weight(.semibold))
                        .foregroundStyle(LFTheme.info)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LFTheme.info.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if preparedImport.validation.issues.isEmpty {
                        LFCompactEmptyState(message: "No validation issues")
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Validation Issues")
                                .font(theme.typography.formBody.weight(.semibold))
                            ForEach(preparedImport.validation.issues) { issue in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: validationIssueIcon(issue.severity))
                                        .foregroundStyle(validationIssueColor(issue.severity))
                                        .frame(width: 18)
                                    Text(issue.message)
                                        .font(theme.typography.formCaption)
                                        .foregroundStyle(theme.palette.secondaryText)
                                }
                            }
                        }
                    }
                }
            case .completedOutcome(let outcome):
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    Label(outcome.persistenceStatus, systemImage: outcome.iconName)
                        .font(theme.typography.formHeading)
                        .foregroundStyle(outcome.tone.color)
                    Text(outcome.fileSubtitle)
                        .font(theme.typography.formBody)
                        .foregroundStyle(theme.palette.secondaryText)
                    Text("See the import outcome for this statement’s result and any available recovery action.")
                        .font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
            case .noStatementPrepared:
                LFEmptyState(
                    title: "No statement prepared",
                    message: "Choose a statement file to see validation results.",
                    systemImage: "doc.text"
                )
            }
        }
    }

    private func settingsToggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(theme.palette.secondaryText)
                .frame(width: 22)
            Text(title)
                .font(theme.typography.formBody)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 11)
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(LFPlainActionStyle())
            .font(theme.typography.formCaption)
            .foregroundStyle(theme.palette.accentHover)
    }

    private var importActivityPresentation: ImportActivityPresentation {
        let completedAttempt: RepositoryImportAttempt?
        if case .completed(let outcome) = importState, let attemptID = outcome.importAttemptID {
            completedAttempt = importHistoryViewModel.attempts.first { $0.id == attemptID }
        } else {
            completedAttempt = nil
        }
        return ImportActivityPresentation(
            importState: importState,
            latestDurableAttempt: importHistoryViewModel.latestDurableAttempt,
            completedAttempt: completedAttempt
        )
    }

    private func importActivityRow(
        title: String,
        subtitle: String,
        status: String,
        iconName: String = "doc.text",
        tone: ImportOutcomeTone = .warning
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(tone.color)
                .frame(width: 34, height: 34)
                .background(tone.color.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(theme.typography.formCaption.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(theme.typography.finePrint)
                    .foregroundStyle(theme.palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            LFStatusBadge(title: status, color: tone.color)
        }
    }

    private func legendRow(_ title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(theme.typography.formCaption)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private func wizardStep(_ number: Int, title: String, subtitle: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(theme.typography.formHeading.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(active ? AnyShapeStyle(theme.palette.primaryAction) : AnyShapeStyle(theme.palette.controlSurface))
                .overlay(Circle().stroke(active ? theme.palette.accentHover : theme.palette.border, lineWidth: 1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.formBody.weight(.medium))
                    .foregroundStyle(active ? theme.palette.accentHover : theme.palette.primaryText)
                Text(subtitle)
                    .font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private func stepLine(active: Bool) -> some View {
        Rectangle()
            .fill(active ? theme.palette.accent : theme.palette.border)
            .frame(maxWidth: .infinity, maxHeight: 2)
    }

    private var toolbarSubtitle: String {
        switch selectedSection {
        case .dashboard:
            return "Here's your financial overview"
        case .accounts:
            return "All your financial accounts in one place"
        case .investments:
            return investmentStore.snapshot.latestZioAccount == nil
                ? "Current positions from your statements"
                : "Current holdings from statements and connected accounts"
        case .transactions:
            return "All your transactions, in one place"
        case .imports:
            return "Import statements in a few simple steps"
        case .salary:
            return "Monthly estimates · \(salaryViewModel.planMonthTitle)"
        case .settings:
            return "Configure LedgerForge to work the way you do"
        case .developer:
            return "Advanced diagnostics and inspection"
        }
    }

    private var availabilityBanner: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(availability.state == .retainedNonCurrent ? "Retained data is not current" : availability.state == .loading ? "Loading data" : "Persistence unavailable").font(theme.typography.formHeading)
                if let failure = availability.failure {
                    Text(failure.summary + ". " + failure.nextAction).font(theme.typography.formCaption)
                }
            }
            Spacer()
            if availability.state != .loading {
                Button("Diagnostics") { selectedSection = .developer }
                    .lfSecondaryAction()
                if DatabaseProvider.shared.persistenceState.isUsable {
                    Button("Reload data") { Task { await hydrateDashboard(force: true) } }
                        .lfSecondaryAction()
                }
            }
        }.padding().background(LFTheme.warning.opacity(0.12))
    }

    private func hydrateDashboardOnce() async {
        guard !didStartRepositoryHydration else { return }
        didStartRepositoryHydration = true
        await hydrateDashboard(force: false)
    }

    private func hydrateDashboard(force: Bool) async {
        await ApplicationHydrationWorkflow(
            dashboardViewModel: dashboardViewModel,
            availability: availability
        )
        .hydrateDashboard(force: force)
    }

    private func requestFileSelection() {
        guard availability.permitsMutation,
              !importSelectionDisabled else { return }
        selectedSection = .imports
        showingImporter = true
    }

#if DEBUG
    private func updateDeveloperMode(_ requestedValue: Bool) {
        developerDatabaseProfileViewModel.setDeveloperModeEnabled(requestedValue)
        if !developerDatabaseProfileViewModel.developerModeEnabled,
           selectedSection == .developer {
            selectedSection = .settings
        }
    }

    private func requestProtectedImportAction(_ intent: ProtectedImportIntent) {
        guard availability.permitsMutation else { return }
        developmentActionMessage = nil
        switch DevelopmentProfileAcknowledgementGate.shared.authorization(
            for: intent.protectedAction
        ) {
        case .allowed:
            executeProtectedImportIntent(intent)
        case .acknowledgementRequired(let challenge):
            pendingProtectedImportIntent = intent
            developmentAcknowledgementChallenge = challenge
        case .developmentDatabaseUnavailable:
            developmentActionMessage = "The development database is unavailable."
            selectedSection = .imports
        }
    }

    private func executeProtectedImportIntent(_ intent: ProtectedImportIntent) {
        guard availability.permitsMutation else { return }
        switch intent {
        case .presentFileImporter:
            showingImporter = true
            selectedSection = .imports
        case .prepareURLs(let urls):
            beginImportBatch(from: urls)
        case .retryPreparation:
            retryCurrentPreparation()
        case .prepareRecoveryURL(let url, let contextID, let route):
            beginRecoveryPreparation(
                from: url,
                contextID: contextID,
                route: route
            )
        case .confirm(let preparedImport):
            Task { await confirmPreparedImport(preparedImport) }
        }
    }

    private func approveDevelopmentProfileAcknowledgement() {
        guard let challenge = developmentAcknowledgementChallenge,
              let intent = pendingProtectedImportIntent else { return }
        switch DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge) {
        case .granted, .noAcknowledgementRequired:
            pendingProtectedImportIntent = nil
            developmentAcknowledgementChallenge = nil
            executeProtectedImportIntent(intent)
        case .staleGeneration, .developmentDatabaseUnavailable:
            pendingProtectedImportIntent = nil
            developmentAcknowledgementChallenge = nil
            developmentActionMessage = "The active development database changed. Start the action again."
            selectedSection = .imports
        }
    }

    private func cancelDevelopmentProfileAcknowledgement() {
        pendingProtectedImportIntent = nil
        developmentAcknowledgementChallenge = nil
    }

    private func clearStaleImportPresentationAfterProfileChange() {
        guard importCentre.reset() else { return }
        statementPassword = ""
        statementDropRequestGate.invalidate()
        statementDropIsTargeted = false
        pendingProtectedImportIntent = nil
        developmentAcknowledgementChallenge = nil
    }
#endif

    private func availableConfirmedImportRecoveryAction(
        for outcome: ImportOutcomePresentation
    ) -> ConfirmedImportRecoveryAction? {
        guard let context = confirmedImportRecoveryContext,
              context.route == outcome.recoveryRoute,
              outcome.recoveryContextID == context.id,
              let recoveryPresentation = outcome.recoveryPresentation else {
            return nil
        }
        return recoveryPresentation.availablePrimaryAction(
            hasSourceURL: context.sourceURL != nil
        )
    }

    private func performConfirmedImportRecoveryAction(
        _ action: ConfirmedImportRecoveryAction,
        for outcome: ImportOutcomePresentation
    ) {
        guard confirmedImportRecoveryActionRequestID == nil,
              !importCentre.isPreparationDraining,
              case .completed(let currentOutcome) = importState,
              currentOutcome.recoveryRoute == outcome.recoveryRoute,
              currentOutcome.recoveryContextID == outcome.recoveryContextID,
              let context = confirmedImportRecoveryContext,
              context.route == outcome.recoveryRoute,
              outcome.recoveryContextID == context.id,
              availableConfirmedImportRecoveryAction(for: outcome) == action else {
            return
        }
#if DEBUG
        guard pendingProtectedImportIntent == nil,
              developmentAcknowledgementChallenge == nil else {
            return
        }
#endif

        guard let requestID = importCentre.beginRecoveryAction(contextID: context.id) else { return }
        Task { @MainActor in
            defer {
                importCentre.finishRecoveryAction(requestID)
            }

            let execution = await confirmedImportRecoveryActionExecutor.execute(
                action,
                sourceURL: context.sourceURL,
                retryCanonicalReconciliation: {
                    guard importCentre.isCurrentRecoveryContext(context.id, route: context.route) else {
                        return false
                    }
                    return ImportEngine.shared.retryCanonicalHydration()
                },
                requestOrdinaryPreparation: { url in
                    guard importCentre.isCurrentRecoveryContext(context.id, route: context.route) else {
                        return false
                    }
#if DEBUG
                    requestProtectedImportAction(
                        .prepareRecoveryURL(
                            url,
                            contextID: context.id,
                            route: context.route
                        )
                    )
                    if case .preparing = importState {
                        return true
                    }
                    return pendingProtectedImportIntent != nil
                        && developmentAcknowledgementChallenge != nil
#else
                    beginRecoveryPreparation(
                        from: url,
                        contextID: context.id,
                        route: context.route
                    )
                    if case .preparing = importState {
                        return true
                    }
                    return false
#endif
                }
            )

            guard execution == .reconciliationSucceeded else { return }
            importCentre.markCurrentOutcomeReconciled(contextID: context.id)
        }
    }

    private func beginRecoveryPreparation(
        from url: URL,
        contextID: UUID,
        route: ConfirmedImportRecoveryRoute
    ) {
        guard let context = confirmedImportRecoveryContext,
              context.sourceURL == url,
              importCentre.isCurrentRecoveryContext(contextID, route: route) else {
            return
        }
        guard availability.permitsMutation,
              importCentre.reprepareCurrentRecovery(
                contextID: contextID,
                route: route,
                sourceURL: url
              ) else { return }
        selectedSection = .imports
    }

    private func beginImportBatch(from urls: [URL]) {
        guard availability.permitsMutation,
              urls == pendingBatchSourceURLs,
              importCentre.startConfirmedBatch(urls) else { return }
        pendingBatchSourceURLs = []
        selectedSection = .imports
    }

    private func stageSelectedBatch(_ urls: [URL]) {
        guard availability.permitsMutation, !importSelectionDisabled, !urls.isEmpty else { return }
        pendingBatchSourceURLs = urls
        selectedSection = .imports
    }

    private var selectedBatchReview: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text("\(pendingBatchSourceURLs.count) statement\(pendingBatchSourceURLs.count == 1 ? "" : "s") selected")
                .font(theme.typography.formHeading)
            ForEach(Array(pendingBatchSourceURLs.enumerated()), id: \.offset) { index, url in
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.small) {
                    Text("\(index + 1).")
                        .foregroundStyle(theme.palette.secondaryText)
                    Text(url.lastPathComponent)
                        .lineLimit(2)
                        .help(url.lastPathComponent)
                }
                .font(theme.typography.formBody)
            }
            Text("Import in this order. If an account choice, password or other review is needed, you can resolve it or skip that statement.")
                .font(theme.typography.formCaption)
                .foregroundStyle(theme.palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var selectedBatchActions: some View {
        Button("Clear selection") { pendingBatchSourceURLs = [] }
            .lfSecondaryAction()
        Button("Prepare and import batch", systemImage: "square.and.arrow.down") {
#if DEBUG
            requestProtectedImportAction(.prepareURLs(pendingBatchSourceURLs))
#else
            beginImportBatch(from: pendingBatchSourceURLs)
#endif
        }
        .lfPrimaryAction()
        .disabled(!availability.permitsMutation)
    }

    private func receiveStatementDrop(_ providers: [NSItemProvider]) -> Bool {
        guard availability.permitsMutation,
              !importSelectionDisabled,
              let requestID = statementDropRequestGate.begin() else { return false }

        selectedSection = .imports
        StatementDropIntakeAdapter().resolve(
            providers.map { StatementDropItemProvider($0) }
        ) { result in
            guard statementDropRequestGate.finish(requestID) else { return }
            switch result {
            case .success(let urls):
                stageSelectedBatch(urls)
            case .failure(let error):
                importCentre.recordSelectionFailure(error.importError)
            }
        }
        return true
    }

    private func startNewImportBatch() {
        guard importCentre.batchSummary.isComplete,
              importCentre.reset() else { return }
        pendingBatchSourceURLs = []
        statementDropRequestGate.invalidate()
        statementDropIsTargeted = false
        requestFileSelection()
    }

    private func retryCurrentPreparation() {
        guard availability.permitsMutation,
              importCentre.retryCurrent() else { return }
        selectedSection = .imports
    }

    @MainActor
    private func confirmPreparedImport(_ preparedImport: PreparedImport) async {
        guard availability.permitsMutation else { return }
        await importCentre.confirmCurrent(expectedPreparationID: preparedImport.id)
    }

    private func cancelPreparedImport() {
        statementPassword = ""
        importCentre.cancelCurrent()
    }

    private func submitStatementPassword(_ challenge: StatementPasswordChallenge) {
        guard !statementPassword.isEmpty else { return }
        let password = statementPassword
        statementPassword = ""
        statementPasswordChallenges.submit(password, challengeID: challenge.id)
    }

    private func statementPeriodText(_ period: ClosedRange<StatementDate>?) -> String {
        guard let period else { return "Unknown" }
        if period.lowerBound == period.upperBound {
            return formatDate(period.lowerBound)
        }
        return "\(formatDate(period.lowerBound)) - \(formatDate(period.upperBound))"
    }

    private func balanceText(_ value: Decimal?, currency: String?) -> String {
        guard let value else { return "Unknown" }
        return formatCurrency(value, currencyCode: currency ?? "INR")
    }

    private func validationIssueIcon(_ severity: ValidationSeverity) -> String {
        switch severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }

    private func validationIssueColor(_ severity: ValidationSeverity) -> Color {
        switch severity {
        case .info:
            return LFTheme.info
        case .warning:
            return LFTheme.warning
        case .error:
            return LFTheme.danger
        }
    }

    private func formatDate(_ date: StatementDate?) -> String { date?.presentation ?? "—" }

    private func formatCurrency(_ value: Decimal, currencyCode: String = "INR") -> String {
        guard let money = try? Money(amount: value, currency: currencyCode) else {
            return "\(currencyCode) \(value)"
        }
        return MoneyFormatting.display(money)
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
