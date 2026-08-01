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

enum StatementImportFileTypes {
    static let allowed: [UTType] = [
        .commaSeparatedText,
        .pdf,
        .spreadsheet
    ]
}

enum AppShellSection: String, CaseIterable {
    case dashboard = "Dashboard"
    case accounts = "Accounts"
    case transactions = "Transactions"
    case imports = "Import"
    case settings = "Settings"
    case developer = "Developer Console"

    static let ordinaryNavigation: [AppShellSection] = [
        .dashboard,
        .accounts,
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
        case .transactions:
            return "arrow.left.arrow.right.square"
        case .imports:
            return "square.and.arrow.down"
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
    case prepareURL(URL)
    case prepareRecoveryURL(
        URL,
        contextID: UUID,
        route: ConfirmedImportRecoveryRoute
    )
    case prepareFixture(DebugApprovedFixture)
    case confirm(PreparedImport)

    var protectedAction: DevelopmentProtectedAction {
        switch self {
        case .presentFileImporter, .prepareURL, .prepareRecoveryURL, .prepareFixture:
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
    case cancelled(fileName: String)
    case failed(fileName: String, message: String, retrySourceURL: URL?)
}

private extension ImportPresentationState {
    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed:
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

    fileprivate var requiresSourceURL: Bool {
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

private struct ConfirmedImportRecoveryContext {
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
                    .font(.subheadline.weight(.semibold))
                Text(presentation.explanation)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
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
        choice: ImportAccountChoice?
    ) -> Bool {
        switch (review, choice) {
        case (.matchedExisting, _), (.unavailable, _):
            return true
        case let (.choiceRequired(eligibleAccountIDs), .some(.useExistingAccount(accountID))):
            return eligibleAccountIDs.contains(accountID)
        case (.choiceRequired, .some(.createNewAccount)):
            return true
        case (.choiceRequired, nil), (.ambiguous, _), (.conflict, _):
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
            case .successfulImport, .partialImportCommitted, .accountChoiceRequired,
                    .identifierOwnershipConflict, .identityAmbiguity, .identityConflict,
                    .staleAccountChoice, .staleProviderGeneration:
                return ImportAccountOutcomePresentationMapper.presentation(
                    outcomeCode: outcomeCode,
                    accountDecisionCode: accountDecisionCode
                )
            case .reviewedPartialPlanStale, .partialImportUnsupportedEvidence,
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
                explanation: "Persisted \(transactionCount) transaction(s)",
                iconName: "checkmark.circle.fill",
                tone: .success
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
    let validationStatus: String
    var persistenceStatus: String
    var message: String?
    var allowsViewingTransactions: Bool
    var iconName: String
    var tone: ImportOutcomeTone
    let accountId: String?
    let importSessionId: String?
    let redactedIdentifier: String?
    let previousImportCompletedAtISO: String?
    let previousAccountDisplayName: String?
    let isPreviouslyImported: Bool
    let transactionEventBlock: TransactionEventBlock?
    var recoveryRoute: ConfirmedImportRecoveryRoute
    let isPartialImport: Bool
    let sourceRowCount: Int?
    let recognizedExistingRowCount: Int?
    let accountOutcomePresentation: ImportAccountOutcomePresentation?
    var recoveryContextID: UUID?

    init(result: ImportEngineResult) {
        fileName = result.fileName
        transactionCount = result.transactionCount
        validationStatus = result.validationPassed ? "Validation Passed" : "Validation Failed"
        allowsViewingTransactions = Self.provesCommittedSuccess(result)
            && (result.recoveryRoute == .none || result.recoveryRoute == .unavailable)
        accountId = result.accountId
        importSessionId = result.importSessionId
        redactedIdentifier = result.redactedIdentifier
        previousImportCompletedAtISO = result.previousImport?.completedAtISO
        previousAccountDisplayName = result.previousImport?.accountDisplayName
        isPreviouslyImported = result.previousImport != nil
        transactionEventBlock = result.transactionEventBlock
        recoveryRoute = result.recoveryRoute
        isPartialImport = result.isPartialImport
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
                persistenceStatus = result.isPartialImport
                    ? "Partial Import Succeeded"
                    : "Persistence Succeeded"
                iconName = "checkmark.circle.fill"
                tone = .success
            } else {
                persistenceStatus = "Outcome Unavailable"
                iconName = "questionmark.circle.fill"
                tone = .warning
            }
        case .unavailable:
            if Self.provesCommittedSuccess(result) {
                persistenceStatus = result.isPartialImport
                    ? "Partial Import Succeeded"
                    : "Persistence Succeeded"
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
        copy.allowsViewingTransactions = true
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

    private init(
        title: String,
        subtitle: String,
        status: String,
        iconName: String,
        tone: ImportOutcomeTone
    ) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.iconName = iconName
        self.tone = tone
    }

    init(importState: ImportPresentationState, latestDurableAttempt: RepositoryImportAttempt?) {
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
                tone: outcome.tone
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
        attempts.max(by: isEarlier)
    }

    private nonisolated static func isEarlier(_ lhs: RepositoryImportAttempt, _ rhs: RepositoryImportAttempt) -> Bool {
        switch (createdAt(from: lhs.createdAtISO), createdAt(from: rhs.createdAtISO)) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (.some, nil):
            return false
        case (nil, .some):
            return true
        default:
            return lhs.id < rhs.id
        }
    }

    private nonisolated static func createdAt(from value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractionalFormatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private init(durableAttempt: RepositoryImportAttempt) {
        let presentation = DurableImportAttemptPresentation(attempt: durableAttempt)
        self.init(
            title: "Latest durable import",
            subtitle: presentation.outcome.explanation,
            status: presentation.outcome.label,
            iconName: presentation.outcome.iconName,
            tone: presentation.outcome.tone
        )
    }
}

struct ContentView: View {

    @State private var showingImporter = false
    @State private var selectedFile = "No statement imported"
    @State private var importState: ImportPresentationState = .idle
    @State private var preparationOwner = ImportPreparationTaskOwner()
    @State private var importIdentityReview: ImportIdentityReview = .unavailable
    @State private var importAccountChoice: ImportAccountChoice?
    @State private var partialImportReview: PartialImportReviewResult = .ordinaryFullImport
    @State private var selectedImportSourceURL: URL?
    @State private var confirmedImportRecoveryContext: ConfirmedImportRecoveryContext?
    @State private var confirmedImportRecoveryActionRequestID: UUID?
    @State private var confirmedImportRecoveryActionExecutor = ConfirmedImportRecoveryActionExecutor()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var importHistoryViewModel = ImportHistoryViewModel()
    @ObservedObject private var importAttemptStore: ImportAttemptStore = .shared
    @State private var selectedSection: AppShellSection = .dashboard
    @State private var didStartRepositoryHydration = false
#if DEBUG
    @StateObject private var developerDatabaseProfileViewModel = DeveloperDatabaseProfileViewModel()
    @State private var pendingProtectedImportIntent: ProtectedImportIntent?
    @State private var developmentAcknowledgementChallenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var developmentActionMessage: String?
#endif

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(LFTheme.divider)
                .frame(width: 1)

            VStack(spacing: 0) {
                contextualToolbar

                Rectangle()
                    .fill(LFTheme.divider)
                    .frame(height: 1)

#if DEBUG
                if let activeProfile = developerDatabaseProfileViewModel.activeProfile,
                   let warning = DeveloperDatabaseProfileWarningView(profile: activeProfile) {
                    warning
                }
#endif

                content
            }
            .frame(minWidth: 900, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1180, minHeight: 760)
        .background(LFTheme.backgroundGradient)
        .foregroundStyle(LFTheme.text)
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: StatementImportFileTypes.allowed
        ) { result in
            switch result {
            case .success(let url):
#if DEBUG
                requestProtectedImportAction(.prepareURL(url))
#else
                beginPreparation(from: url)
#endif

            case .failure(let error):
                let summary = ImportFailureSummary.from(error)
                selectedImportSourceURL = nil
                confirmedImportRecoveryContext = nil
                selectedFile = "Import failed"
                importState = .failed(fileName: "Import failed", message: summary.displayText, retrySourceURL: nil)
                selectedSection = .imports
            }
        }
        .task {
            hydrateDashboardOnce()
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

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                appMark

                Text("LedgerForge")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 24)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LFTheme.primaryGradient)
                    .frame(width: 42, height: 42)
                    .overlay {
                        Text("VF")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Vyom")
                        .font(.subheadline.weight(.semibold))
                    Text("Personal")
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
            .padding(.bottom, 22)

            sidebarGroup(AppShellSection.ordinaryNavigation)

#if DEBUG
            if AppShellSection.developerConsoleVisible(
                developerModeEnabled: developerDatabaseProfileViewModel.developerModeEnabled
            ) {
                sidebarSeparator
                sidebarButton(.developer)
            }
#endif

            Spacer()

            sidebarFooter
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(width: 242)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x070B15), Color(hex: 0x091427)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var contextualToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSection.rawValue)
                    .font(.system(size: 27, weight: .semibold))
                Text(toolbarSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(LFTheme.textSecondary)
            }

            Spacer(minLength: 24)

            Button {
                requestFileSelection()
            } label: {
                Label("Import Statement", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minWidth: 176)
                    .background(LFTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(LFTheme.backgroundDeep.opacity(0.72))
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .dashboard:
            dashboardContent
        case .accounts:
            accountsContent
        case .transactions:
            TransactionListView()
        case .imports:
            importWizardContent
        case .settings:
            settingsContent
        case .developer:
#if DEBUG
            DeveloperConsoleView(profileViewModel: developerDatabaseProfileViewModel) { fixture in
                requestProtectedImportAction(.prepareFixture(fixture))
            }
#else
            DeveloperConsoleView()
#endif
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    ForEach(dashboardViewModel.nativeCurrencySummaries) { summary in
                        metricCard(title: "\(summary.currency.code) Balance", value: MoneyFormatting.display(summary.balance), trend: "Repository-backed native balance", trendColor: LFTheme.success, systemImage: "chart.line.uptrend.xyaxis")
                        metricCard(title: "\(summary.currency.code) Inflow", value: MoneyFormatting.display(summary.income), trend: "Credited transactions", trendColor: LFTheme.success, systemImage: "arrow.down.circle")
                        metricCard(title: "\(summary.currency.code) Outflow", value: MoneyFormatting.display(summary.expenses), trend: "Debited transactions", trendColor: LFTheme.danger, systemImage: "arrow.up.circle")
                        metricCard(title: "\(summary.currency.code) Net Transaction Flow", value: MoneyFormatting.display(summary.cashFlow), trend: "Credits minus debits", trendColor: LFTheme.info, systemImage: "arrow.left.arrow.right")
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    dashboardAccountsCard
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        importActivityCard
                        quickActionsCard
                    }
                    .frame(width: 324)
                }

                recentTransactionsCard
                    .frame(maxWidth: .infinity)
            }
            .padding(28)
        }
        .background(LFTheme.backgroundGradient)
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
            .padding(28)
        }
        .background(LFTheme.backgroundGradient)
    }

    private var importWizardContent: some View {
        VStack(spacing: 18) {
            importStepper

#if DEBUG
            if let developmentActionMessage {
                Text(developmentActionMessage)
                    .font(.caption)
                    .foregroundStyle(LFTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LFTheme.warning.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
#endif

            HStack(alignment: .top, spacing: 18) {
                LFPanel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Prepare Statement")
                                .font(.title3.weight(.semibold))
                            Text("Choose a file, review the parsed statement and confirm before LedgerForge writes financial data.")
                                .font(.subheadline)
                                .foregroundStyle(LFTheme.textSecondary)

                            Button {
                                requestFileSelection()
                            } label: {
                                VStack(spacing: 14) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 42, weight: .light))
                                        .foregroundStyle(LFTheme.primaryHover)
                                    Text("Choose a statement file")
                                        .font(.headline)
                                    Text("Browse Files")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 9)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(LFTheme.primary, lineWidth: 1)
                                        )
                                }
                                .frame(maxWidth: .infinity, minHeight: 210)
                                .background(LFTheme.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LFTheme.primary.opacity(0.75), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(importSelectionDisabled)

                            importResultPanel

                            importAttemptHistoryPanel

                            if importState.showsPreConfirmationNoWriteMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(LFTheme.info)
                                    Text("No data is written until Confirm Import is selected.")
                                        .font(.caption)
                                        .foregroundStyle(LFTheme.textSecondary)
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

                            HStack(spacing: 12) {
                                Image(systemName: "shield.checkered")
                                    .foregroundStyle(LFTheme.primaryHover)
                                Text("Files are processed locally. Repository persistence still requires successful validation.")
                                    .font(.caption)
                                    .foregroundStyle(LFTheme.textSecondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(LFTheme.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                LFPanel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Validation Review")
                                .font(.title3.weight(.semibold))

                            validationReviewPanel
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity)

            HStack {
                if case .committing = importState {
                    Label("Cancellation unavailable", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LFTheme.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(LFTheme.surface.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Button {
                        cancelPreparedImport()
                    } label: {
                        Text("Cancel")
                            .padding(.horizontal, 42)
                            .padding(.vertical, 13)
                            .background(LFTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCancelPreparation)
                }

                Spacer()

                importFooterAction
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LFTheme.backgroundGradient)
    }

    private var settingsContent: some View {
        let completedImports = SettingsPresentation.completedImports(
            from: importAttemptStore.attempts,
            persistenceState: DatabaseProvider.shared.persistenceState
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 18) {
#if DEBUG
                    VStack(spacing: 18) {
                        LFPanel(title: "Application") {
                            VStack(spacing: 0) {
                                settingsToggleRow(
                                    "Developer Mode",
                                    icon: "chevron.left.forwardslash.chevron.right",
                                    isOn: Binding(
                                        get: { developerDatabaseProfileViewModel.developerModeEnabled },
                                        set: { updateDeveloperMode($0) }
                                    )
                                )
                                if let message = developerDatabaseProfileViewModel.operationState.message {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(LFTheme.warning)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.bottom, 10)
                                }
                            }
                        }
                    }
                    .frame(width: 330)
#endif

                    VStack(spacing: 18) {
                        LFPanel(title: "System Information") {
                            LFInfoRow(title: "Version", value: SettingsPresentation.applicationVersion(infoDictionary: Bundle.main.infoDictionary))
                            LFInfoRow(title: "Persistence", value: DatabaseProvider.shared.persistenceState.displayName)
                            LFInfoRow(title: "Persistence Status", value: DatabaseProvider.shared.persistenceState.statusMessage)
                            if let guidance = DatabaseProvider.shared.persistenceState.recoveryGuidance {
                                LFInfoRow(title: "Recovery", value: guidance)
                            }
                            LFInfoRow(title: "Runtime State", value: dashboardViewModel.presentationState.message)
                        }

                        LFPanel(title: "Data Summary") {
                            LFInfoRow(title: "Accounts", value: "\(dashboardViewModel.accounts.count)")
                            LFInfoRow(title: "Transactions", value: "\(dashboardViewModel.transactionCount)")
                            LFInfoRow(title: "Completed Imports", value: completedImports.displayValue)
                            if let partialValue = completedImports.secondaryValue {
                                LFInfoRow(title: "Partial Imports", value: partialValue)
                            }
                        }
                    }
                    .frame(width: 330)
                }

                CategoryManagementView()
                    .frame(width: 678)
            }
            .padding(28)
        }
        .background(LFTheme.backgroundGradient)
    }

    private var dashboardAccountsCard: some View {
        LFPanel(title: "Accounts", trailing: AnyView(linkButton("View all") { selectedSection = .accounts })) {
            VStack(spacing: 0) {
                if dashboardViewModel.accountSummaries.isEmpty {
                    LFCompactEmptyState(message: "No repository-backed accounts")
                } else {
                    ForEach(dashboardViewModel.accountSummaries) { account in
                        HStack(spacing: 12) {
                            accountIcon(account.institution)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(account.institution) · \(account.currencyCode)")
                                    .font(.caption)
                                    .foregroundStyle(LFTheme.textSecondary)
                            }

                            Spacer()

                            Text(formatCurrency(account.currentBalance, currencyCode: account.currencyCode))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(LFTheme.textSecondary)
                        }
                        .padding(.vertical, 10)

                        if account.id != dashboardViewModel.accountSummaries.last?.id {
                            Divider().overlay(LFTheme.divider)
                        }
                    }
                }
            }
        }
    }

    private var importActivityCard: some View {
        let activity = importActivityPresentation
        return LFPanel(title: "Import Activity", trailing: AnyView(linkButton("View all imports") { selectedSection = .imports })) {
            VStack(spacing: 12) {
                importActivityRow(
                    title: activity.title,
                    subtitle: activity.subtitle,
                    status: activity.status,
                    iconName: activity.iconName,
                    tone: activity.tone
                )
                importActivityRow(title: "Repository Hydration", subtitle: dashboardViewModel.presentationState.message, status: dashboardHydrationStatus)
            }
        }
    }

    private var quickActionsCard: some View {
        LFPanel(title: "Quick Actions") {
            VStack(spacing: 4) {
                LFActionRow(title: "Import Statement", systemImage: "square.and.arrow.down") {
                    requestFileSelection()
                }
                LFActionRow(title: "View All Transactions", systemImage: "list.bullet") {
                    selectedSection = .transactions
                }
                LFActionRow(title: "Open Settings", systemImage: "gearshape") {
                    selectedSection = .settings
                }
            }
        }
    }

    private var recentTransactionsCard: some View {
        LFPanel(title: "Recent Transactions", trailing: AnyView(linkButton("View all transactions") { selectedSection = .transactions })) {
            VStack(spacing: 0) {
                tableHeader(["Date", "Description", "Account", "Type", "Amount", "Balance"])

                if dashboardViewModel.recentTransactionSummaries.isEmpty {
                    LFCompactEmptyState(message: "No repository-backed transactions")
                } else {
                    ForEach(dashboardViewModel.recentTransactionSummaries) { transaction in
                        HStack(spacing: 14) {
                            Text(formatDate(transaction.statementDate))
                                .frame(width: 84, alignment: .leading)
                            Text(transaction.description)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(transaction.currency)
                                .foregroundStyle(LFTheme.textSecondary)
                                .frame(width: 92, alignment: .leading)
                            Text(transaction.isCredit ? "Credit" : "Debit")
                                .foregroundStyle(transaction.isCredit ? LFTheme.success : LFTheme.danger)
                                .frame(width: 68, alignment: .leading)
                            Text(MoneyFormatting.signedDisplay(transaction.amount, isCredit: transaction.isCredit))
                                .foregroundStyle(transaction.isCredit ? LFTheme.success : LFTheme.danger)
                                .monospacedDigit()
                                .frame(width: 112, alignment: .trailing)
                            Text("—")
                                .foregroundStyle(LFTheme.textSecondary)
                                .frame(width: 86, alignment: .trailing)
                        }
                        .font(.caption)
                        .padding(.vertical, 12)

                        Divider().overlay(LFTheme.divider)
                    }
                }
            }
        }
    }

    private var accountDetailPanel: some View {
        LFPanel {
            VStack(alignment: .leading, spacing: 18) {
                if let account = accountsViewModel.selectedAccount {
                    HStack(spacing: 12) {
                        accountIcon(account.institution)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            if accountsViewModel.isEditingDisplayName {
                                TextField("Display name", text: $accountsViewModel.displayNameDraft)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Text(account.displayName)
                                    .font(.headline)
                            }
                            Text(account.institution)
                                .font(.caption)
                                .foregroundStyle(LFTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "star")
                            .foregroundStyle(LFTheme.warning)
                    }

                    if accountsViewModel.isEditingDisplayName {
                        HStack(spacing: 10) {
                            Button("Save") {
                                accountsViewModel.saveDisplayName()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Cancel") {
                                accountsViewModel.cancelDisplayNameEdit()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button("Edit display name") {
                            accountsViewModel.beginDisplayNameEdit()
                        }
                        .buttonStyle(.bordered)
                    }

                    if let message = accountsViewModel.presentationState.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(LFTheme.warning)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Balance")
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                        Text(formatCurrency(account.currentBalance, currencyCode: account.currencyCode))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(account.currentBalance >= .zero ? LFTheme.success : LFTheme.danger)
                            .monospacedDigit()
                    }

                    LFInfoRow(title: "Institution", value: account.institution)
                    LFInfoRow(title: "Account Type", value: account.accountTypeLabel)
                    LFInfoRow(title: "Currency", value: account.currencyCode)
                    LFInfoRow(title: "Transactions", value: "\(accountsViewModel.transactionCount)")

                    Divider().overlay(LFTheme.divider)

                    Text("Recent Activity")
                        .font(.headline)

                    if accountsViewModel.recentActivity.isEmpty {
                        LFCompactEmptyState(message: "No trusted activity for this account")
                    }

                    ForEach(accountsViewModel.recentActivity) { transaction in
                        HStack {
                            Image(systemName: transaction.credit != nil ? "arrow.down" : "arrow.up")
                                .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                                .frame(width: 28, height: 28)
                                .background((transaction.credit != nil ? LFTheme.success : LFTheme.danger).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(transaction.description)
                                .lineLimit(1)
                            Spacer()
                            Text(transaction.signedAmountDisplay)
                                .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }

                    Divider().overlay(LFTheme.divider)

                    Text("Verified Financial Identity")
                        .font(.headline)
                    if account.identitySummaries.isEmpty {
                        LFCompactEmptyState(message: "No verified strong identifiers")
                    } else {
                        ForEach(account.identitySummaries) { identifier in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(identifier.kind) · \(identifier.redactedValue)")
                                    .font(.caption.weight(.semibold))
                                Text("\(identifier.strength) · \(identifier.verificationState) · \(identifier.provenance)")
                                    .font(.caption2)
                                    .foregroundStyle(LFTheme.textSecondary)
                            }
                        }
                    }

                    Divider().overlay(LFTheme.divider)

                    Text("Import History")
                        .font(.headline)
                    if accountsViewModel.importHistory.isEmpty {
                        LFCompactEmptyState(message: "No trusted import history for this account")
                    } else {
                        ForEach(accountsViewModel.importHistory) { session in
                            Button {
                                accountsViewModel.selectImportSession(id: session.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.sourceDocumentName ?? "Imported statement")
                                        .font(.caption.weight(.semibold))
                                    Text(session.isPartialImport
                                         ? "\(session.validationStatus) · Partial: \(session.transactionCount) new, \(session.recognizedExistingRowCount ?? 0) represented"
                                         : "\(session.validationStatus) · \(session.transactionCount) transaction(s)")
                                        .font(.caption2)
                                        .foregroundStyle(LFTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let session = accountsViewModel.selectedImportSession {
                        Divider().overlay(LFTheme.divider)
                        HStack {
                            Text("Import Detail")
                                .font(.headline)
                            Spacer()
                            Button("Close") {
                                accountsViewModel.clearSelectedImportSession()
                            }
                            .buttonStyle(.bordered)
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
            wizardStep(1, title: "Choose File", subtitle: "Select statement", active: importStep >= 1)
            stepLine(active: importStep >= 2)
            wizardStep(2, title: "Prepare", subtitle: "Read and validate", active: importStep >= 2)
            stepLine(active: importStep >= 3)
            wizardStep(3, title: "Preview", subtitle: "Read-only review", active: importStep >= 3)
            stepLine(active: importStep >= 4)
            wizardStep(4, title: "Confirm", subtitle: "Explicit commit", active: importStep >= 4)
            stepLine(active: importStep >= 5)
            wizardStep(5, title: "Import", subtitle: "Complete import", active: importStep >= 5)
        }
        .padding(.vertical, 10)
    }

    private var importStep: Int {
        switch importState {
        case .idle:
            return 1
        case .preparing:
            return 2
        case .previewReady, .validationFailed:
            return 3
        case .committing:
            return 4
        case .completed:
            return 5
        case .failed:
            return 2
        case .cancelled:
            return 1
        }
    }

    private var importSelectionDisabled: Bool {
        switch importState {
        case .preparing, .committing:
            return true
        default:
            return false
        }
    }

    private var canCancelPreparation: Bool {
        switch importState {
        case .preparing, .previewReady, .validationFailed:
            return true
        default:
            return false
        }
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
        .font(.caption)
        .foregroundStyle(LFTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var appMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LFTheme.primaryGradient)
                .frame(width: 34, height: 34)
            Image(systemName: "hexagon.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.92))
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LFTheme.backgroundDeep)
        }
    }

    private var sidebarFooter: some View {
        let activity = importActivityPresentation
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Last import")
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
                Text(activity.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Label(activity.status, systemImage: activity.iconName)
                    .font(.caption2)
                    .foregroundStyle(activity.tone.color)
                    .lineLimit(2)
            }

            Divider().overlay(LFTheme.divider)

            Label("Collapse", systemImage: "chevron.left")
                .font(.subheadline)
                .foregroundStyle(LFTheme.textSecondary)
        }
        .padding(.bottom, 4)
    }

    private var sidebarSeparator: some View {
        Rectangle()
            .fill(LFTheme.divider)
            .frame(height: 1)
            .padding(.vertical, 14)
    }

    private func sidebarGroup(_ sections: [AppShellSection]) -> some View {
        VStack(spacing: 5) {
            ForEach(sections, id: \.self) { section in
                sidebarButton(section)
            }
        }
    }

    private func sidebarButton(_ section: AppShellSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22)
                Text(section.rawValue)
                    .font(.system(size: 14, weight: selectedSection == section ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedSection == section ? AnyShapeStyle(LFTheme.primaryGradient) : AnyShapeStyle(Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedSection == section ? .white : LFTheme.text)
        .accessibilityLabel(section.rawValue)
    }

    private func metricCard(title: String, value: String, trend: String, trendColor: Color, systemImage: String) -> some View {
        LFPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: systemImage)
                        .foregroundStyle(LFTheme.primaryHover)
                }
                Text(value)
                    .font(.system(size: 25, weight: .semibold))
                    .monospacedDigit()
                Text(trend)
                    .font(.caption)
                    .foregroundStyle(trendColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accountMetric(_ title: String, value: String, detail: String, icon: String, tint: Color = LFTheme.primary) -> some View {
        LFPanel {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(value)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(tint == LFTheme.danger ? LFTheme.danger : LFTheme.text)
                        .monospacedDigit()
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
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
                        .font(.subheadline.weight(.semibold))
                    Text(account.currencyCode)
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(account.institution)
                    .frame(width: 160, alignment: .leading)

                LFStatusBadge(title: account.accountTypeLabel, color: LFTheme.primary)
                    .frame(width: 100, alignment: .leading)

                Text(formatCurrency(account.currentBalance, currencyCode: account.currencyCode))
                    .foregroundStyle(account.currentBalance >= .zero ? LFTheme.success : LFTheme.danger)
                    .monospacedDigit()
                    .frame(width: 140, alignment: .trailing)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .background(
                accountsViewModel.selectedRepositoryAccountID == account.id
                    ? LFTheme.primary.opacity(0.16)
                    : LFTheme.surface.opacity(0.45)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func accountIcon(_ institution: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(institution.localizedCaseInsensitiveContains("axis") ? Color(hex: 0xB0165B) : LFTheme.primary.opacity(0.55))
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
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
            Spacer()
            Image(systemName: name == "No statement imported" ? "circle" : "checkmark.circle.fill")
                .foregroundStyle(name == "No statement imported" ? LFTheme.textSecondary : LFTheme.success)
        }
        .padding(14)
        .background(LFTheme.surface)
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
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
                }
            case .previewReady(let preparedImport), .validationFailed(let preparedImport), .committing(let preparedImport):
                VStack(alignment: .leading, spacing: 10) {
                    preparedImportPreview(preparedImport, displayName: selectedFile)
                    if case .committing = importState {
                        Text("Importing confirmed financial data. This write cannot be cancelled safely.")
                            .font(.caption.weight(.semibold))
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
                                        .font(.subheadline.weight(.semibold))
                                    Text(recovery.explanation)
                                        .font(.caption)
                                        .foregroundStyle(LFTheme.textSecondary)
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
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(LFTheme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(LFTheme.text)
                                .disabled(
                                    confirmedImportRecoveryActionRequestID != nil
                                        || preparationOwner.activeOperationID != nil
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

                    LFInfoRow(title: "Transactions", value: "\(outcome.transactionCount)")

                    if outcome.isPreviouslyImported {
                        if let completedAtISO = outcome.previousImportCompletedAtISO {
                            LFInfoRow(title: "Prior Import", value: completedAtISO)
                        }
                        if let accountName = outcome.previousAccountDisplayName {
                            LFInfoRow(title: "Account", value: accountName)
                        }
                        Text("This exact statement was imported previously. LedgerForge did not write another document, import session, transaction, account, or identifier.")
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(LFTheme.warning.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let message = outcome.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(LFTheme.surface)
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

                    if outcome.allowsViewingTransactions || outcome.isPreviouslyImported {
                        if let accountId = outcome.accountId,
                           accountsViewModel.accounts.contains(where: { $0.id == accountId }) {
                            Button {
                                accountsViewModel.selectAccount(repositoryAccountID: accountId)
                                selectedSection = .accounts
                            } label: {
                                Label("View Account", systemImage: "person.crop.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(LFTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(LFTheme.text)
                        }
                        if outcome.allowsViewingTransactions {
                            Button {
                                selectedSection = .transactions
                            } label: {
                                Label("View Transactions", systemImage: "list.bullet")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(LFTheme.primaryGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            case .cancelled(let fileName):
                importedFileRow(
                    name: fileName,
                    subtitle: "Preparation cancelled. No data was written.",
                    icon: "xmark.circle.fill",
                    color: LFTheme.textSecondary
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
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var importAttemptHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Import History").font(.headline)
                Spacer()
                Text("\(importHistoryViewModel.attempts.count)").font(.caption).foregroundStyle(LFTheme.textSecondary)
            }
            if importHistoryViewModel.attempts.isEmpty {
                Text("Supported import outcomes appear here after processing.")
                    .font(.caption).foregroundStyle(LFTheme.textSecondary)
            } else {
                ForEach(importHistoryViewModel.attempts.prefix(8)) { attempt in
                    let presentation = DurableImportAttemptPresentation(attempt: attempt)
                    Button { importHistoryViewModel.select(id: attempt.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(presentation.outcome.label).font(.subheadline.weight(.semibold))
                                Text(attempt.createdAtISO).font(.caption2).foregroundStyle(LFTheme.textSecondary)
                            }
                            Spacer()
                            Text(attempt.outcomeCode == ImportAttemptOutcome.partialImportCommitted.rawValue
                                 ? "\(attempt.importedTransactionCount ?? attempt.transactionCount) new · partial"
                                 : "\(attempt.transactionCount) transactions")
                                .font(.caption).foregroundStyle(LFTheme.textSecondary)
                        }
                        .padding(9).background(LFTheme.surface.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(presentation.outcome.label). \(presentation.outcome.explanation)")
                }
            }
            if let attempt = importHistoryViewModel.selectedAttempt {
                let presentation = DurableImportAttemptPresentation(attempt: attempt)
                Divider()
                HStack { Text("Attempt Detail").font(.subheadline.weight(.semibold)); Spacer(); Button("Close") { importHistoryViewModel.clearSelection() }.font(.caption) }
                LFInfoRow(title: "Outcome", value: presentation.outcome.label)
                LFInfoRow(title: "Coverage", value: presentation.coverage)
                LFInfoRow(title: "Guidance", value: presentation.guidance)
                if let accountPresentation = DurableImportAccountOutcomeSection.presentation(for: attempt) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account Outcome")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LFTheme.textSecondary)
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
                        .font(.caption.weight(.semibold)).buttonStyle(.plain).foregroundStyle(LFTheme.primaryHover)
                }
            }
        }
        .padding(12).background(LFTheme.surface.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 9))
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

            HStack(spacing: 8) {
                LFStatusBadge(title: preparedImport.detectedInstitution.rawValue, color: LFTheme.primary)
                LFStatusBadge(title: preparedImport.detectedDocumentType.rawValue, color: LFTheme.info)
                LFStatusBadge(title: preparedImport.parserName, color: LFTheme.textSecondary)
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

            if case .eligible(let plan) = partialImportReview {
                partialImportReviewPanel(plan, preparedImport: preparedImport)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Transaction Preview")
                    .font(.subheadline.weight(.semibold))
                tableHeader(["Date", "Description", "Currency", "Type", "Amount", "Balance"])
                ForEach(preparedImport.financialDocument.transactions.prefix(12)) { transaction in
                    previewTransactionRow(transaction)
                }
            }
            .padding(12)
            .background(LFTheme.surface.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    ForEach(accountsViewModel.accounts.filter { projection.eligibleAccountIDs.contains($0.id) }) { account in
                        Button {
                            importAccountChoice = .useExistingAccount(accountId: account.id)
                            refreshPartialImportReview(preparedImport)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(account.displayName)
                                    Text(account.institution)
                                        .font(.caption)
                                        .foregroundStyle(LFTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: importAccountChoice == .useExistingAccount(accountId: account.id) ? "checkmark.circle.fill" : "circle")
                            }
                            .padding(10)
                            .background(LFTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(LFTheme.text)
                    }
                    Button {
                        importAccountChoice = .createNewAccount
                        refreshPartialImportReview(preparedImport)
                    } label: {
                        HStack {
                            Text("Create New Account")
                            Spacer()
                            Image(systemName: importAccountChoice == .createNewAccount ? "checkmark.circle.fill" : "circle")
                        }
                        .padding(10)
                        .background(LFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(LFTheme.text)
                }
            }
            .padding(12)
            .background(LFTheme.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var importConfirmationLabel: String {
        if case .eligible(let plan) = partialImportReview {
            return "Import \(plan.importedCount) new transaction\(plan.importedCount == 1 ? "" : "s")"
        }
        return "Confirm Import"
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

    @MainActor
    private func refreshPartialImportReview(_ preparedImport: PreparedImport) {
        do {
            partialImportReview = try ImportEngine.shared.reviewPreparedPartialImport(
                preparedImport,
                accountChoice: importAccountChoice
            )
        } catch {
            partialImportReview = .unsupportedEvidence
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
                .font(.headline)
            Text("Parser-verified, account-scoped Axis UPI evidence recognizes the earlier rows. LedgerForge will preserve the complete statement and import only the reviewed later rows.")
                .font(.caption)
                .foregroundStyle(LFTheme.textSecondary)
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
                                .font(.caption2)
                                .foregroundStyle(LFTheme.textSecondary)
                        }
                        Spacer()
                        Text(row.disposition == .recognizedExisting ? "Already represented" : "Will import")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(row.disposition == .recognizedExisting ? LFTheme.textSecondary : LFTheme.success)
                    }
                    .padding(.vertical, 7)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Statement row \(row.sourceOrdinal). \(row.disposition == .recognizedExisting ? "Already represented" : "Will import").")
                    if row.sourceOrdinal != plan.rows.last?.sourceOrdinal { Divider() }
                }
            }
            Text("Repository truth is rechecked atomically at confirmation. If it changes, no part of this reviewed plan will be imported.")
                .font(.caption)
                .foregroundStyle(LFTheme.warning)
        }
        .padding(12)
        .background(LFTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reviewed partial import. \(plan.recognizedCount) already represented. \(plan.importedCount) will import. Zero blocked.")
    }

    private func previewTransactionRow(_ transaction: Transaction) -> some View {
        HStack(spacing: 14) {
            Text(formatDate(transaction.statementDate))
                .frame(width: 84, alignment: .leading)
            Text(transaction.description)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(transaction.currency)
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: 92, alignment: .leading)
            Text(transaction.credit != nil ? "Credit" : "Debit")
                .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                .frame(width: 68, alignment: .leading)
            Text(transaction.signedAmountDisplay)
                .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                .monospacedDigit()
                .frame(width: 112, alignment: .trailing)
            Text(balanceText(transaction.balance, currency: transaction.currency))
                .foregroundStyle(LFTheme.textSecondary)
                .monospacedDigit()
                .frame(width: 86, alignment: .trailing)
        }
        .font(.caption)
        .padding(.vertical, 8)
    }

    private var importFooterAction: some View {
        Group {
            switch importState {
            case .previewReady(let preparedImport):
                Button {
#if DEBUG
                    requestProtectedImportAction(.confirm(preparedImport))
#else
                    Task {
                        await confirmPreparedImport(preparedImport)
                    }
#endif
                } label: {
                    Label(importConfirmationLabel, systemImage: "checkmark.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .disabled(
                    !ImportAccountConfirmationPolicy.allowsConfirmation(
                        review: importIdentityReview,
                        choice: importAccountChoice
                    ) ||
                    partialReviewBlocksConfirmation
                )
            case .committing:
                Label("Importing", systemImage: "hourglass")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LFTheme.textSecondary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .background(LFTheme.surface.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .failed(_, _, let retrySourceURL) where retrySourceURL != nil:
                Button {
                    if let retrySourceURL {
#if DEBUG
                        requestProtectedImportAction(.prepareURL(retrySourceURL))
#else
                        beginPreparation(from: retrySourceURL)
#endif
                    }
                } label: {
                    Label("Retry Preparation", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            case .completed(let outcome) where outcome.allowsViewingTransactions:
                Button {
                    selectedSection = .transactions
                } label: {
                    Label("View Transactions", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            default:
                importFooterPendingAction
            }
        }
    }

    private var validationReviewPanel: some View {
        Group {
            switch importState {
            case .previewReady(let preparedImport), .validationFailed(let preparedImport), .committing(let preparedImport):
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

                    LFInfoRow(title: "Rows Read", value: "\(preparedImport.validation.rowsRead)")
                    LFInfoRow(title: "Transactions Parsed", value: "\(preparedImport.validation.transactionsParsed)")
                    LFInfoRow(title: "Debit Total", value: balanceText(preparedImport.validation.debitTotal, currency: preparedImport.detectedCurrency))
                    LFInfoRow(title: "Credit Total", value: balanceText(preparedImport.validation.creditTotal, currency: preparedImport.detectedCurrency))

                    Text("No data has been written.")
                        .font(.caption.weight(.semibold))
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
                                .font(.subheadline.weight(.semibold))
                            ForEach(preparedImport.validation.issues) { issue in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: validationIssueIcon(issue.severity))
                                        .foregroundStyle(validationIssueColor(issue.severity))
                                        .frame(width: 18)
                                    Text(issue.message)
                                        .font(.caption)
                                        .foregroundStyle(LFTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 12) {
                    settingsPendingRow("File Password", value: "Resolved by password provider", icon: "lock")
                    settingsPendingRow("Date Format", value: "DD MMM YYYY", icon: "calendar")
                    settingsPendingRow("Duplicate Handling", value: "Existing repository path", icon: "rectangle.on.rectangle")
                    settingsPendingRow("Create / Link Accounts", value: "Existing persistence mapper", icon: "link")
                }
            }
        }
    }

    private var importFooterPendingAction: some View {
        Label("Awaiting confirmation", systemImage: "arrow.right")
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(LFTheme.textSecondary)
            .padding(.horizontal, 32)
            .padding(.vertical, 13)
            .background(LFTheme.surface.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LFTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func settingsPendingRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
            Spacer()
            Text("Pending")
                .font(.caption2.weight(.medium))
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(LFTheme.surfaceRaised.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.vertical, 11)
    }

    private func settingsToggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 11)
    }

    private func tableHeader(_ titles: [String]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(title)
                    .frame(
                        maxWidth: index == 1 ? .infinity : nil,
                        alignment: index >= 4 ? .trailing : .leading
                    )
                    .frame(width: fixedHeaderWidth(index), alignment: index >= 4 ? .trailing : .leading)
            }
        }
        .font(.caption)
        .foregroundStyle(LFTheme.textSecondary)
        .padding(.vertical, 10)
    }

    private func fixedHeaderWidth(_ index: Int) -> CGFloat? {
        switch index {
        case 0:
            return 84
        case 2:
            return 92
        case 3:
            return 68
        case 4:
            return 112
        case 5:
            return 86
        default:
            return nil
        }
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(LFTheme.primaryHover)
    }

    private var importActivityPresentation: ImportActivityPresentation {
        ImportActivityPresentation(
            importState: importState,
            latestDurableAttempt: ImportActivityPresentation.latestDurableAttempt(from: importHistoryViewModel.attempts)
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
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(LFTheme.textSecondary)
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
                .font(.caption)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
        }
    }

    private func wizardStep(_ number: Int, title: String, subtitle: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.headline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(active ? AnyShapeStyle(LFTheme.primaryGradient) : AnyShapeStyle(LFTheme.surface))
                .overlay(Circle().stroke(active ? LFTheme.primaryHover : LFTheme.border, lineWidth: 1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(active ? LFTheme.primaryHover : LFTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
        }
    }

    private func stepLine(active: Bool) -> some View {
        Rectangle()
            .fill(active ? LFTheme.primary : LFTheme.border)
            .frame(maxWidth: .infinity, maxHeight: 2)
    }

    private var toolbarSubtitle: String {
        switch selectedSection {
        case .dashboard:
            return "Here's your financial overview"
        case .accounts:
            return "All your financial accounts in one place"
        case .transactions:
            return "All your transactions, in one place"
        case .imports:
            return "Import statements in a few simple steps"
        case .settings:
            return "Configure LedgerForge to work the way you do"
        case .developer:
            return "Advanced diagnostics and inspection"
        }
    }

    private var dashboardHydrationStatus: String {
        switch dashboardViewModel.presentationState {
        case .loaded:
            return "Loaded"
        case .loading:
            return "Loading"
        case .empty:
            return "Idle"
        case .failed:
            return "Review"
        }
    }

    private func hydrateDashboardOnce() {
        guard !didStartRepositoryHydration else { return }
        didStartRepositoryHydration = true
        dashboardViewModel.markHydrationStarted()

        do {
            let result = try RepositoryStoreHydrator().hydrateIfNeeded()
            dashboardViewModel.markHydrationCompleted(result)
        } catch {
            dashboardViewModel.markHydrationFailed(error)
            DeveloperConsole.shared.error(
                .runtime,
                "Dashboard hydration failed",
                metadata: ["outcome": "Unavailable"]
            )
        }
    }

    private func requestFileSelection() {
        selectedSection = .imports
#if DEBUG
        requestProtectedImportAction(.presentFileImporter)
#else
        showingImporter = true
#endif
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
        switch intent {
        case .presentFileImporter:
            showingImporter = true
            selectedSection = .imports
        case .prepareURL(let url):
            beginPreparation(from: url)
        case .prepareRecoveryURL(let url, let contextID, let route):
            beginRecoveryPreparation(
                from: url,
                contextID: contextID,
                route: route
            )
        case .prepareFixture(let fixture):
            beginPreparation(for: fixture)
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
        switch importState {
        case .committing:
            return
        case .preparing:
            preparationOwner.cancel()
        case .previewReady(let preparedImport), .validationFailed(let preparedImport):
            ImportEngine.shared.cancelPreparedImport(preparedImport)
        default:
            break
        }
        pendingProtectedImportIntent = nil
        developmentAcknowledgementChallenge = nil
        confirmedImportRecoveryActionRequestID = nil
        confirmedImportRecoveryContext = nil
        selectedImportSourceURL = nil
        importState = .idle
        selectedFile = "No statement imported"
        importIdentityReview = .unavailable
        importAccountChoice = nil
        partialImportReview = .ordinaryFullImport
    }
#endif

    private func consumePreparedImportBeforeSourceReplacement() -> Bool {
        switch importState {
        case .committing:
            return false
        case .previewReady(let preparedImport), .validationFailed(let preparedImport):
            ImportEngine.shared.cancelPreparedImport(preparedImport)
            return true
        default:
            return true
        }
    }

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
              preparationOwner.activeOperationID == nil,
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

        let requestID = UUID()
        confirmedImportRecoveryActionRequestID = requestID
        Task { @MainActor in
            defer {
                if confirmedImportRecoveryActionRequestID == requestID {
                    confirmedImportRecoveryActionRequestID = nil
                }
            }

            let execution = await confirmedImportRecoveryActionExecutor.execute(
                action,
                sourceURL: context.sourceURL,
                retryCanonicalReconciliation: {
                    guard confirmedImportRecoveryContext?.id == context.id,
                          case .completed(let currentOutcome) = importState,
                          currentOutcome.recoveryRoute == context.route,
                          currentOutcome.recoveryContextID == context.id else {
                        return false
                    }
                    return ImportEngine.shared.retryCanonicalHydration()
                },
                requestOrdinaryPreparation: { url in
                    guard confirmedImportRecoveryContext?.id == context.id,
                          case .completed(let currentOutcome) = importState,
                          currentOutcome.recoveryRoute == context.route,
                          currentOutcome.recoveryContextID == context.id else {
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

            guard execution == .reconciliationSucceeded,
                  confirmedImportRecoveryContext?.id == context.id,
                  case .completed(let reconciledOutcome) = importState,
                  reconciledOutcome.recoveryRoute == .retryCanonicalReconciliation,
                  reconciledOutcome.recoveryContextID == context.id else {
                return
            }
            confirmedImportRecoveryContext = nil
            selectedImportSourceURL = nil
            importState = .completed(reconciledOutcome.markingReconciled())
        }
    }

    private func beginRecoveryPreparation(
        from url: URL,
        contextID: UUID,
        route: ConfirmedImportRecoveryRoute
    ) {
        guard let context = confirmedImportRecoveryContext,
              context.id == contextID,
              context.route == route,
              context.sourceURL == url,
              case .completed(let outcome) = importState,
              outcome.recoveryRoute == route,
              outcome.recoveryContextID == contextID else {
            return
        }
        beginPreparation(from: url)
    }

    private func beginPreparation(from url: URL) {
        guard consumePreparedImportBeforeSourceReplacement() else { return }
        confirmedImportRecoveryContext = nil
        selectedImportSourceURL = url
        importAccountChoice = nil
        importIdentityReview = .unavailable
        partialImportReview = .ordinaryFullImport
        selectedFile = url.lastPathComponent
        importState = .preparing(fileName: url.lastPathComponent, phase: .openingSource)
        selectedSection = .imports
        _ = preparationOwner.start { operationID in
            await prepareImport(
                displayName: url.lastPathComponent,
                operationID: operationID,
                retrySourceURL: url
            ) { progress in
                try await ImportEngine.shared.prepareImport(
                    from: url,
                    requestId: operationID,
                    progress: progress
                )
            }
        }
    }

#if DEBUG
    private func beginPreparation(for fixture: DebugApprovedFixture) {
        guard consumePreparedImportBeforeSourceReplacement() else { return }
        confirmedImportRecoveryContext = nil
        selectedImportSourceURL = nil
        importAccountChoice = nil
        importIdentityReview = .unavailable
        partialImportReview = .ordinaryFullImport
        selectedFile = fixture.title
        importState = .preparing(fileName: fixture.title, phase: .openingSource)
        selectedSection = .imports
        _ = preparationOwner.start { operationID in
            await prepareImport(
                displayName: fixture.title,
                operationID: operationID,
                retrySourceURL: nil
            ) { progress in
                try await DebugImportFixtureLauncher().prepare(
                    fixture,
                    requestID: operationID,
                    progress: progress
                )
            }
        }
    }
#endif

    @MainActor
    private func prepareImport(
        displayName: String,
        operationID: UUID,
        retrySourceURL: URL?,
        loader: @escaping (@escaping (ImportProgress) -> Void) async throws -> PreparedImport
    ) async {
        do {
            let preparedImport = try await loader { progress in
                guard preparationOwner.isCurrent(operationID), !Task.isCancelled else {
                    return
                }
                importState = .preparing(fileName: displayName, phase: progress.phase)
            }
            guard preparationOwner.isCurrent(operationID), !Task.isCancelled else {
                ImportEngine.shared.cancelPreparedImport(preparedImport)
                return
            }
            let identityReview: ImportIdentityReview
            let preparedPartialReview: PartialImportReviewResult
            do {
                identityReview = preparedImport.validation.passed && preparedImport.advisoryPreviousImport == nil
                    ? (try ImportEngine.shared.reviewPreparedImport(preparedImport))
                    : .unavailable
                preparedPartialReview = preparedImport.validation.passed && preparedImport.advisoryPreviousImport == nil
                    ? (try ImportEngine.shared.reviewPreparedPartialImport(preparedImport))
                    : .ordinaryFullImport
            } catch {
                ImportEngine.shared.cancelPreparedImport(preparedImport)
                throw error
            }
            importIdentityReview = identityReview
            importAccountChoice = ImportAccountConfirmationPolicy.initialChoice(for: identityReview)
            partialImportReview = preparedPartialReview
            guard preparationOwner.isCurrent(operationID), !Task.isCancelled else {
                ImportEngine.shared.cancelPreparedImport(preparedImport)
                return
            }
            selectedFile = displayName
            importState = preparedImport.validation.passed ? .previewReady(preparedImport) : .validationFailed(preparedImport)
            releasePreparationOperation(operationID)
        } catch is CancellationError {
            guard preparationOwner.isCurrent(operationID) else {
                return
            }
            selectedFile = displayName
            importState = .cancelled(fileName: displayName)
            releasePreparationOperation(operationID)
        } catch let error as ImportError where error == .cancelled {
            guard preparationOwner.isCurrent(operationID) else {
                return
            }
            selectedFile = displayName
            importState = .cancelled(fileName: displayName)
            releasePreparationOperation(operationID)
        } catch {
            guard preparationOwner.isCurrent(operationID), !Task.isCancelled else {
                return
            }
            let summary = ImportFailureSummary.from(error)
            selectedFile = displayName
            importState = .failed(
                fileName: displayName,
                message: summary.displayText,
                retrySourceURL: isRetryablePreparationFailure(error) ? retrySourceURL : nil
            )
            DeveloperConsole.shared.error(
                .import,
                "Import preparation failed",
                metadata: [
                    "stage": summary.stage.rawValue,
                    "family": summary.family.rawValue
                ]
            )
            releasePreparationOperation(operationID)
        }
    }

    @MainActor
    private func confirmPreparedImport(_ preparedImport: PreparedImport) async {
        guard case .previewReady(let currentPreparedImport) = importState,
              currentPreparedImport.id == preparedImport.id else {
            return
        }

        let displayName = selectedFile
        importState = .committing(preparedImport)
        let result = await ImportEngine.shared.commitPreparedImport(
            preparedImport,
            accountChoice: importAccountChoice,
            reviewedPartialPlan: {
                if case .eligible(let plan) = partialImportReview { return plan }
                return nil
            }()
        )

        var outcome = ImportOutcomePresentation(result: result)
        outcome.fileName = displayName
        if let action = outcome.recoveryPresentation?.primaryAction {
            let context = ConfirmedImportRecoveryContext(
                route: outcome.recoveryRoute,
                sourceURL: action.requiresSourceURL ? selectedImportSourceURL : nil
            )
            outcome.recoveryContextID = context.id
            confirmedImportRecoveryContext = context
        } else {
            confirmedImportRecoveryContext = nil
        }
        selectedImportSourceURL = nil
        selectedFile = displayName
        importState = .completed(outcome)
    }

    private func cancelPreparedImport() {
        let fileName: String
        switch importState {
        case .preparing(let currentFileName, _):
            fileName = currentFileName
            preparationOwner.cancel()
        case .previewReady(let preparedImport), .validationFailed(let preparedImport):
            fileName = preparedImport.fileName
            ImportEngine.shared.cancelPreparedImport(preparedImport)
        default:
            return
        }
        importAccountChoice = nil
        importIdentityReview = .unavailable
        partialImportReview = .ordinaryFullImport
        selectedImportSourceURL = nil
        confirmedImportRecoveryContext = nil
        selectedFile = fileName
        importState = .cancelled(fileName: fileName)
    }

    @MainActor
    private func releasePreparationOperation(_ operationID: UUID) {
        preparationOwner.finish(operationID)
    }

    private func isRetryablePreparationFailure(_ error: Error) -> Bool {
        guard let importError = error as? ImportError else {
            return false
        }
        switch importError {
        case .readerFailure, .unknown:
            return true
        case .unsupportedFile, .passwordRequired, .incorrectPassword, .readerUnavailable,
                .invalidDocument, .unsupportedStatement, .cancelled:
            return false
        }
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
