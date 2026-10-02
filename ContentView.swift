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
                $0 == ImportAttemptOutcome.cbqSourceOverlapCommitted.rawValue ||
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
    case ibkrAccount = "IBKR"
    case emailStatements = "Email Statements"
    case backgroundUpdates = "Background Updates"
    case backup = "Backup & Restore"
    case categories = "Categories"

    var systemImage: String {
        switch self {
        case .appearance: "paintpalette"
        case .liveFX: "arrow.triangle.2.circlepath"
        case .ispAccount, .ibkrAccount: "link"
        case .emailStatements: "envelope"
        case .backgroundUpdates: "clock.arrow.circlepath"
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
    case skipped(fileName: String, retainedNewerHoldings: Bool = false)
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
                .repositoryIntegrityConflict, .bankSourceOverlapHeld:
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
        case .bankSourceOverlapHeld:
            return reviewPresentation(
                title: "Bank Source Review Required",
                explanation: "An account section has unresolved or conflicting transaction evidence. The whole statement remains held. Review the recorded source finding before importing it again.",
                iconName: "doc.text.magnifyingglass"
            )
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
                explanation: "Choose the account for this Axis card statement. Its printed card number will retain your confirmed account association."
            )
            iconName = "creditcard.badge.questionmark"
            tone = .warning
            matchedAccountID = nil
            self.eligibleAccountIDs = eligibleLiabilityAccountIDs
        case .cardChoiceRequired(let eligibleLiabilityAccountIDs, let matchedLiabilityAccountID):
            presentation = matchedLiabilityAccountID == nil
                ? ImportAccountOutcomePresentationMapper.presentation(for: .choiceRequired)
                : ImportAccountOutcomePresentation(label: "Review card sections",
                    explanation: "The statement belongs to an existing liability account. Review the card sections within that account before importing.")
            iconName = "creditcard.badge.questionmark"
            tone = .warning
            matchedAccountID = matchedLiabilityAccountID
            self.eligibleAccountIDs = eligibleLiabilityAccountIDs
        case .bankSections:
            presentation = ImportAccountOutcomePresentation(
                label: "Review bank account sections",
                explanation: "Each source account needs its own destination decision before this relationship statement can be confirmed."
            )
            iconName = "building.columns.badge.questionmark"
            tone = .warning
            matchedAccountID = nil
            eligibleAccountIDs = []
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
        if case .useExistingCardLiabilityAccountSections(_, let choices) = choice,
           !ImportCardInstrumentChoice.hasDistinctExistingDestinations(choices) { return false }
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
        case let (.cardChoiceRequired(eligibleAccountIDs, matchedAccountID), .some(.useExistingCardLiabilityAccount(accountID, instrumentChoice))):
            return eligibleAccountIDs.contains(accountID) && (matchedAccountID == nil || matchedAccountID == accountID) && instrumentChoice.isComplete &&
                (requiredCardSectionIDs == nil || requiredCardSectionIDs?.count == 1)
        case let (.cardChoiceRequired(eligibleAccountIDs, matchedAccountID), .some(.useExistingCardLiabilityAccountSections(accountID, sectionChoices))):
            return eligibleAccountIDs.contains(accountID) && (matchedAccountID == nil || matchedAccountID == accountID) && sectionChoices.values.allSatisfy(\.isComplete) &&
                (requiredCardSectionIDs.map { Set($0) == Set(sectionChoices.keys) } ?? !sectionChoices.isEmpty)
        case let (.cardChoiceRequired(_, matchedAccountID), .some(.createNewCardLiabilityAccountAndInstrument)):
            return matchedAccountID == nil
        case (.bankSections(let sections), let choice):
            let choices: [String: ImportBankSectionChoice]
            switch choice {
            case .bankSections(let selected): choices = selected
            case nil: choices = [:]
            default: return false
            }
            return bankSectionChoicesAreComplete(sections: sections, choices: choices)
        case (.choiceRequired, _), (.liabilityAccountChoiceRequired, _),
                (.cardChoiceRequired, _), (.ambiguous, _), (.conflict, _):
            return false
        }
    }

    /// The atomic parent planner reuses these account-decision rules and
    /// rechecks identity and occurrence evidence inside the provider transaction.
    static func bankSectionChoicesAreComplete(
        sections: [BankSectionIdentityReview],
        choices: [String: ImportBankSectionChoice]
    ) -> Bool {
        guard !sections.isEmpty, Set(sections.map(\.sectionID)).count == sections.count else { return false }
        var destinationByDistinctSource = [String: String]()
        for section in sections {
            let destination: String?
            switch section.identityReview {
            case .matchedExisting(let accountID):
                destination = accountID
            case .choiceRequired(let eligibleAccountIDs):
                guard let choice = choices[section.sectionID], choice.isComplete else { return false }
                switch choice {
                case .useExistingAccount(let accountID):
                    guard eligibleAccountIDs.contains(accountID) else { return false }
                    destination = accountID
                case .createNewAccount:
                    destination = nil
                }
            case .unavailable, .liabilityAccountChoiceRequired, .ambiguous,
                    .conflict, .cardChoiceRequired, .bankSections:
                return false
            }
            if let destination, let existingSource = destinationByDistinctSource[destination],
               existingSource != section.sourceAccountLabel {
                return false
            }
            if let destination {
                destinationByDistinctSource[destination] = section.sourceAccountLabel
            }
        }
        let unresolvedIDs = Set(sections.compactMap { section -> String? in
            if case .choiceRequired = section.identityReview { return section.sectionID }
            return nil
        })
        return Set(choices.keys) == unresolvedIDs
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
            case .equivalentSourceRecorded, .bankSourceOverlapHeld, .statementEquivalenceConflict,
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
        case .bankSourceOverlapHeld:
            return DurableImportPresentationValue(
                label: "Bank statement held",
                explanation: "An account section has unresolved or conflicting source evidence. No account section was imported",
                iconName: "doc.text.magnifyingglass",
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
    let bankSections: [BankImportReceiptDTO.Section]
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
        bankSections = result.bankSections
        accountOutcomePresentation = result.accountOutcome == .unavailable
            ? nil
            : ImportAccountOutcomePresentationMapper.presentation(for: result.accountOutcome)
        recoveryContextID = nil

        if result.recoveryRoute == .reviewRequired(.bankSourceOverlapHeld) {
            // This route carries the bounded provider finding and source row,
            // so the owner can distinguish a balance conflict from ambiguity.
            message = result.errorMessage
        } else if result.recoveryRoute == .unavailable && !result.persisted {
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
        copy.allowsViewingTransactions = !isEquivalentSupportingSource && !isSalaryImport && !isInvestmentImport
        copy.persistenceStatus = isEquivalentSupportingSource
            ? "Equivalent Source Recorded"
            : (isPartialImport ? "Partial Import Succeeded" : "Persistence Succeeded")
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
        case .skipped(let fileName, let retainedNewerHoldings):
            self.init(
                title: fileName,
                subtitle: retainedNewerHoldings ? "Newer current holdings retained. No financial data was written." : "Statement skipped. No data was written.",
                status: retainedNewerHoldings ? "No update needed" : "Skipped",
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
            title: "Last import attempt",
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
    @State private var showsImportQueue = false
    @State private var statementDropRequestGate = StatementDropRequestGate()
    @StateObject private var statementPasswordChallenges = StatementPasswordChallengeController.shared
    @ObservedObject private var importCentre = ProductionImportCentre.shared
    @ObservedObject private var emailIntake = GmailIntakeSession.shared
    @State private var confirmedImportRecoveryActionExecutor = ConfirmedImportRecoveryActionExecutor()
    @State private var importCentrePresentationOwnerID = UUID()
    @ObservedObject private var availability = ApplicationAvailability.shared
    @ObservedObject private var alDarReferenceSession: AlDarReferenceSession
    @ObservedObject private var investmentPriceSession: InvestmentPriceSession
    @ObservedObject private var ispSyncSession: ZurichISPSyncSession
    @ObservedObject private var ibkrFlexSession: IBKRFlexSyncSession
    @ObservedObject private var backgroundUpdates = BackgroundUpdatesSession.shared
    @State private var settingsSubsection: SettingsSubsection?
    @ObservedObject private var salaryViewModel: SalaryWorkspaceViewModel
    @StateObject private var dashboardViewModel: DashboardViewModel
    @State private var netWorthShowsZeroBalances = false
    @State private var dashboardSelectedReportRow: String?
    @State private var dashboardDetailedAccount: String?
    @State private var dashboardShowsPlanDetails = false
    @ObservedObject private var transactionViewModel: TransactionListViewModel
    private let transactionAmountMeasurement: TransactionAmountWidthMeasurement
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var confirmsCardHistoryOnly = false
    @StateObject private var importHistoryViewModel = ImportHistoryViewModel()
    @ObservedObject private var importAttemptStore: ImportAttemptStore = .shared
    @ObservedObject private var cardStore: CardStore = .shared
    @ObservedObject private var fundingPlanStore: FundingPlanStore = .shared
    @ObservedObject private var investmentStore: InvestmentStore = .shared
    @ObservedObject private var categoryStore: CategoryStore = .shared
    @State private var selectedSection: AppShellSection = .dashboard
    @State private var planningReturnFilter: TransactionPresentationFilterSpec?
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
            return .skipped(fileName: item.displayFileName, retainedNewerHoldings: item.retainedNewerHoldings)
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

    private var bankSectionDraftChoices: [String: ImportBankSectionChoice] {
        importCentre.currentItem?.bankSectionDraftChoices ?? [:]
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
        guard let item = importCentre.currentItem,
              item.phase == .preparing,
              let operationID = item.preparationOperationID else { return nil }
        return statementPasswordChallenges.challenge(for: operationID)
    }

    private var showsAutomaticImportProgress: Bool {
        importCentre.showsAutomaticBatchProgress(
            passwordChallengeID: activeStatementPasswordChallenge?.id
        )
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

    private var sidebarPendingImportStatus: String? {
        if !importCentre.items.isEmpty, !importCentre.batchSummary.isComplete {
            let remaining = importCentre.items.count - importCentre.terminalItems.count
            switch importCentre.batchLifecycle {
            case .cancelling: return "Finishing the current batch…"
            case .awaitingUserAction: return "Batch needs attention · \(max(1, remaining)) remaining"
            default: return "Batch in progress · \(remaining) of \(importCentre.items.count) remaining"
            }
        }
        if !pendingBatchSourceURLs.isEmpty {
            return "\(pendingBatchSourceURLs.count) selected for import"
        }
        let pendingEmails = emailIntake.batchSources.count
        return pendingEmails > 0 ? "\(pendingEmails) email originals awaiting import" : nil
    }

    private var dashboardActionableImportStatus: String? {
        if !importCentre.items.isEmpty, !importCentre.batchSummary.isComplete,
           importCentre.batchLifecycle != .awaitingUserAction { return nil }
        return sidebarPendingImportStatus
    }

    init(transactionViewModel: TransactionListViewModel? = nil,
         transactionAmountMeasurement: TransactionAmountWidthMeasurement? = nil,
         salaryViewModel: SalaryWorkspaceViewModel? = nil,
         alDarReferenceSession: AlDarReferenceSession? = nil,
         investmentPriceSession: InvestmentPriceSession? = nil,
         ispSyncSession: ZurichISPSyncSession? = nil, ibkrFlexSession: IBKRFlexSyncSession? = nil) {
        let rates = alDarReferenceSession ?? AlDarReferenceSession(enabled: false)
        let prices = investmentPriceSession ?? InvestmentPriceSession(enabled: false)
        let planner = salaryViewModel ?? SalaryWorkspaceViewModel()
        self.alDarReferenceSession = rates
        self.investmentPriceSession = prices
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(reportingRates: rates, reportingPrices: prices,
            fundingMonth: planner.month, fundingWorkspace: planner))
        self.ispSyncSession = ispSyncSession ?? ZurichISPSyncSession(enabled: false)
        self.ibkrFlexSession = ibkrFlexSession ?? IBKRFlexSyncSession(enabled: false)
        self.transactionViewModel = transactionViewModel ?? TransactionListViewModel()
        self.salaryViewModel = planner
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
                    pendingImportStatus: selectedSection == .dashboard && sidebarPendingImportStatus != nil
                        ? nil : sidebarPendingImportStatus,
                    selectSection: { section in
#if DEBUG
                        let timing = section == .transactions ? GmailQualificationTiming.begin(.navigationTransactions) : nil
                        defer { GmailQualificationTiming.end(.navigationTransactions, started: timing) }
#endif
                        selectedSection = section
                    },
                    isCollapsed: usesRail,
                    allowsCollapse: true,
                    toggleCollapsed: { sidebarRailOverride = !usesRail }
                )
            },
            toolbar: {
                if selectedSection != .salary && selectedSection != .investments && selectedSection != .transactions && selectedSection != .settings && selectedSection != .developer {
                AppShellToolbar(
                    section: selectedSection,
                    subtitle: toolbarSubtitle,
                    accessory: selectedSection == .dashboard
                        ? AnyView(DashboardLiveFXHeaderAccessory(session: alDarReferenceSession))
                        : nil
                )
                }
            },
            profileWarning: { profileWarning },
            availabilityBanner: { availabilityBanner },
            destination: { destinationContent }
        )
        .environment(\.lfTheme, theme)
        .onReceive(salaryViewModel.$month) { month in
            dashboardViewModel.selectFundingMonth(month)
        }
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
            emailIntake.bindImportCentre()
            await emailIntake.reloadInbox()
#if DEBUG
            await BackupRestoreCoordinator.shared.runProcessProbeIfRequested()
#endif
        }
        .onReceive(DatabaseActivityGate.shared.didBecomeAvailable) { _ in
            Task { await emailIntake.reloadInbox() }
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
        .onChange(of: activeStatementPasswordChallenge?.id) { _, _ in
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
                                    generation: availability.generation, availabilityState: availability.state,
                                    returnToPlanning: planningReturnFilter == nil ? nil : {
                                        transactionViewModel.presentationFilter = planningReturnFilter ?? .empty
                                        planningReturnFilter = nil; selectedSection = .salary
                                    })
            },
            imports: { importWizardContent },
            salary: { SalaryView(viewModel: salaryViewModel, referenceSession: alDarReferenceSession, onTransactions: { ids in
                planningReturnFilter = transactionViewModel.presentationFilter
                transactionViewModel.presentationFilter = .empty
                transactionViewModel.presentationFilter.canonicalTransactionIDs = ids
                transactionViewModel.presentationFilter.accountIDs = Set(transactionViewModel.allPresentationRows.compactMap { row in
                    row.transaction.repositoryTransactionId.map(ids.contains) == true ? row.accountID : nil
                })
                selectedSection = .transactions
            }) },
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
            let contentWidth = max(0, viewport.size.width - theme.spacing.pagePadding * 2)
            let usesColumns = contentWidth >= max(1160, theme.typography.nativeFont(.body).pointSize * 72)
            let investmentWidth = usesColumns ? (contentWidth - theme.spacing.sectionGap) * 0.58 : contentWidth
            let columns = usesColumns
                ? AnyLayout(HStackLayout(alignment: .top, spacing: theme.spacing.sectionGap))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.sectionGap))
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    DashboardNetWorthCard(report: dashboardViewModel.netWorthReport,
                        workspaceID: "default-workspace", permitsMutation: availability.permitsMutation,
                        selectedRow: $dashboardSelectedReportRow, showsZeroBalances: $netWorthShowsZeroBalances)
                    columns {
                        DashboardInvestmentSnapshotCard(overview: investmentPriceSession.overview,
                            report: dashboardViewModel.netWorthReport, selectedRow: $dashboardSelectedReportRow) {
                            selectedSection = .investments
                        }
                        .frame(width: usesColumns ? investmentWidth : nil)
                        salaryDashboardSummary
                    }
                    columns {
                        dashboardAccountPanel(isCard: false)
                            .frame(width: usesColumns ? investmentWidth : nil)
                        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                            dashboardAccountPanel(isCard: true)
                            importActivityCard
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(theme.spacing.pagePadding)
                .font(theme.typography.body)
            }
        }
    }

    private var dashboardAttention: ConfirmedImportRecoveryPresentation? {
        guard case .completed(let outcome) = importState else { return nil }
        return DashboardAttentionProjection.presentation(for: outcome.recoveryRoute)
    }

    /// Hide only source-proven zero values. Totals and current eligibility are
    /// unchanged; unavailable balances are still part of the visible scope.
    private var dashboardVisiblePositions: [DashboardCurrencyPosition] {
        return dashboardViewModel.positions.compactMap { group in
            let banks = group.banks.filter { $0.amount?.amount != 0 }
            let cards = group.cards.filter { $0.amount?.amount != 0 }
            guard !banks.isEmpty || !cards.isEmpty else { return nil }
            return .init(currency: group.currency, banks: banks, cards: cards,
                         bankTotal: group.bankTotal, cardTotal: group.cardTotal)
        }
    }

    private func dashboardAccountPanel(isCard: Bool) -> some View {
        let groups = dashboardVisiblePositions.filter { !(isCard ? $0.cards : $0.banks).isEmpty }
        let positions = groups.flatMap { isCard ? $0.cards : $0.banks }
        return LFPanel(contentSpacing: theme.spacing.small) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sectionGap) {
                    Text(isCard ? "Credit cards" : "Bank accounts").font(theme.typography.sectionTitle)
                    Spacer(minLength: theme.spacing.small)
                    dashboardAccountSummary(groups, isCard: isCard)
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    Text(isCard ? "Credit cards" : "Bank accounts").font(theme.typography.sectionTitle)
                    dashboardAccountSummary(groups, isCard: isCard)
                }
            }
            switch dashboardViewModel.positionState {
            case .loading:
                dashboardState("Loading recorded balances…", loading: true)
            case .empty:
                dashboardState(isCard ? "No card accounts available." : "No bank accounts available.")
            case .unavailable:
                dashboardState("Recorded balances unavailable")
            case .populated:
                if positions.isEmpty {
                    dashboardState(isCard ? "No non-zero card balances." : "No non-zero bank balances.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(positions) { position in
                            Divider().overlay(theme.palette.divider)
                            dashboardAccountRow(position, isCard: isCard)
                                .padding(.vertical, theme.spacing.small)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func dashboardAccountSummary(_ groups: [DashboardCurrencyPosition], isCard: Bool) -> some View {
        if isCard {
            Text("Amount owed").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        } else if dashboardViewModel.positionState == .populated {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                    ForEach(groups) { dashboardNativeTotal($0) }
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    ForEach(groups) { dashboardNativeTotal($0) }
                }
            }
        }
    }

    private func dashboardNativeTotal(_ group: DashboardCurrencyPosition) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(group.currency.code).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            Text(dashboardMoneyText(group.bankTotal)).font(theme.typography.tableMoney).monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func dashboardAccountRow(_ position: DashboardAccountPosition, isCard: Bool) -> some View {
        let credit = isCard && (position.amount?.amount ?? 0) < 0
        let kind = credit ? "Card credit" : isCard ? "Card" : "Bank"
        return Button { dashboardDetailedAccount = position.id } label: {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                Image(systemName: isCard ? "creditcard" : "building.columns")
                    .font(theme.typography.rowTitle).foregroundStyle(theme.palette.secondaryText)
                    .frame(width: 28).padding(.top, theme.spacing.micro)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.small) {
                        Text(position.displayName).font(theme.typography.body.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: theme.spacing.small)
                        Text(dashboardMoneyText(position.amount)).font(theme.typography.font(.body, tabularDigits: true).weight(.semibold))
                            .foregroundStyle(isCard && !credit && position.amount != nil ? theme.financialNegative : theme.palette.primaryText)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    Text((credit ? "Credit balance · " : "") + dashboardSourceContextText(position))
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(LFPlainActionStyle())
        .accessibilityLabel(position.displayName + ", " + kind + ", " + dashboardMoneyText(position.amount) + ", " + dashboardSourceContextText(position) + ". Show source details")
        .accessibilityIdentifier("dashboard.account." + position.id)
        .help("Show exact balance and source dates")
        .popover(isPresented: Binding(get: { dashboardDetailedAccount == position.id },
            set: { if !$0 { dashboardDetailedAccount = nil } })) {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                HStack {
                    Text(position.displayName).font(theme.typography.rowTitle)
                    Spacer()
                    Button("Close details", systemImage: "xmark") { dashboardDetailedAccount = nil }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                }
                Text(position.institution + " · " + kind).font(theme.typography.secondary)
                Text(dashboardMoneyText(position.amount)).font(theme.typography.headlineMoney).monospacedDigit()
                if let date = position.asOf {
                    Text("Statement balance as of " + date.presentation)
                } else if let date = position.sourcePeriodEnd {
                    Text("Statement period ends " + date.presentation)
                    Text("Exact balance date unavailable")
                } else { Text("Balance date unavailable") }
                if let context = position.sourceContext { Text(context) }
            }
            .font(theme.typography.body).padding(theme.spacing.panelPadding).frame(width: 430)
        }
    }

    private func dashboardSourceContextText(_ position: DashboardAccountPosition) -> String {
        if position.asOf == nil, let periodEnd = position.sourcePeriodEnd {
            return "Statement · " + DashboardAccountPosition.asOfLabel(for: periodEnd)
        }
        if position.asOf == nil, let sourceContext = position.sourceContext {
            return sourceContext
        }
        return DashboardAccountPosition.asOfLabel(for: position.asOf)
            + (position.sourceContext.map { " · \($0)" } ?? "")
    }

    private func dashboardMoneyText(_ money: Money?) -> String {
        money.map { MoneyFormatting.display($0) } ?? "Unavailable"
    }

    private var salaryDashboardSummary: some View {
        LFPanel(contentSpacing: theme.spacing.controlGap) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.controlGap) {
                    Text(dashboardViewModel.fundingPlanTitle).font(theme.typography.sectionTitle)
                    Spacer(minLength: theme.spacing.small)
                    dashboardRouteButton(.salary)
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    Text(dashboardViewModel.fundingPlanTitle).font(theme.typography.sectionTitle)
                    dashboardRouteButton(.salary)
                }
            }
            switch dashboardViewModel.fundingState {
            case .empty:
                dashboardState("No plan for \(dashboardViewModel.fundingMonthTitle).")
            case .loading:
                dashboardState("Loading monthly plan…", loading: true)
            case .unavailable:
                dashboardState(dashboardViewModel.fundingMessage ?? "Monthly plan unavailable")
            case .populated:
                let calculation = dashboardViewModel.fundingCalculation
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                        dashboardBudgetMetric("Expected pay", calculation?.expectedNet, secondary: true)
                        dashboardBudgetMetric("Available to transfer", calculation?.transferablePrincipal)
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        dashboardBudgetMetric("Expected pay", calculation?.expectedNet, secondary: true)
                        dashboardBudgetMetric("Available to transfer", calculation?.transferablePrincipal)
                    }
                }
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                        dashboardIndiaRequirement(calculation)
                        dashboardBudgetMetric("Left after funding India", calculation?.finalQARBuffer, emphasize: true)
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        dashboardIndiaRequirement(calculation)
                        dashboardBudgetMetric("Left after funding India", calculation?.finalQARBuffer, emphasize: true)
                    }
                }
                dashboardFundingAllocation(calculation)
                HStack {
                    Text("Planning estimates").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    Spacer(minLength: theme.spacing.small)
                    Button("Rate details") { dashboardShowsPlanDetails.toggle() }
                        .buttonStyle(.link).font(theme.typography.caption)
                        .accessibilityIdentifier("dashboard.planRateDetails")
                        .popover(isPresented: $dashboardShowsPlanDetails) {
                            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                                Text(dashboardViewModel.fundingMonthTitle + " plan").font(theme.typography.rowTitle)
                                Text(dashboardViewModel.fundingRateDetail ?? "Plan rate unavailable.")
                                Text("These are planning amounts, not completed payments. The India equivalent and remaining amount use this plan’s rate, even when Live FX has a newer reference.")
                                Text("Available transfer capacity reserves the configured fee. When no India transfer is needed, the unused fee stays in the remaining balance.")
                                Button("Close") { dashboardShowsPlanDetails = false }.lfSecondaryAction()
                            }
                            .font(theme.typography.secondary).padding(theme.spacing.panelPadding).frame(width: 420)
                        }
                }
                if let calculation, !calculation.incompleteReasons.isEmpty {
                    Text("Complete missing plan entries to see all amounts.")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
            }
        }
    }

    private func dashboardIndiaRequirement(_ calculation: FundingPlanCalculation?) -> some View {
        dashboardBudgetMetric("India still to fund", calculation?.indiaFundingShortfall,
            note: calculation?.requiredQARPrincipal.map { MoneyFormatting.display($0) } ?? "QAR equivalent unavailable")
    }

    private func dashboardBudgetMetric(_ title: String, _ amount: Money?, note: String? = nil,
                                       emphasize: Bool = false, secondary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(title).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(dashboardMoneyText(amount))
                .font(theme.typography.font(secondary ? .tableMoney : .headlineMoney, tabularDigits: true))
                .foregroundStyle(emphasize && amount != nil
                    ? ((amount?.amount ?? 0) < 0 ? theme.financialNegative : theme.financialPositive)
                    : secondary ? theme.palette.secondaryText : theme.palette.primaryText)
                .fixedSize(horizontal: true, vertical: false)
            if let note {
                Text(note).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func dashboardFundingAllocation(_ calculation: FundingPlanCalculation?) -> some View {
        if let available = calculation?.transferablePrincipal,
           let india = calculation?.requiredQARPrincipal,
           let left = calculation?.finalQARBuffer,
           available.currency.code == "QAR", india.currency == available.currency, left.currency == available.currency {
            if india.amount == 0 {
                Text("No India transfer needed")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            } else if left.amount < 0 {
                Text("Available transfer does not cover the planned funding.")
                    .font(theme.typography.caption).foregroundStyle(theme.financialNegative)
            } else if available.amount > 0, india.amount > 0, (try? india + left) == available {
                let fraction = NSDecimalNumber(decimal: india.amount / available.amount).doubleValue
                if fraction.isFinite, (0...1).contains(fraction) {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Text("Available transfer allocation · QAR")
                            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                Rectangle().fill(theme.palette.accent)
                                    .frame(width: geometry.size.width * CGFloat(fraction))
                                Rectangle().fill(theme.financialPositive)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
                        }
                        .frame(height: 16)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Planned transfer allocation")
                        .accessibilityValue(dashboardMoneyText(india) + " for India; " + dashboardMoneyText(left) + " left")
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                Text(dashboardMoneyText(india) + " → India")
                                Spacer(minLength: theme.spacing.small)
                                Text(dashboardMoneyText(left) + " left").foregroundStyle(theme.financialPositive)
                            }
                            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                                Text(dashboardMoneyText(india) + " → India")
                                Text(dashboardMoneyText(left) + " left").foregroundStyle(theme.financialPositive)
                            }
                        }
                        .font(theme.typography.caption).monospacedDigit().foregroundStyle(theme.palette.secondaryText)
                    }
                    .accessibilityIdentifier("dashboard.transferAllocation")
                }
            } else {
                Text("Transfer allocation unavailable")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
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

    @State private var expandedAccountHistory: Set<String> = []

    private var accountsContent: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - theme.spacing.pagePadding * 2
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Current totals exclude history-only accounts")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    accountSummaryStrip(width: width)
                    if accountsViewModel.accounts.isEmpty {
                        LFEmptyState(title: "No accounts found", message: "Your accounts appear here after importing statements.",
                            actionTitle: "Import Statement", systemImage: "wallet.pass") { requestFileSelection() }
                    } else {
                        let layout = width >= 1120 ? AnyLayout(HStackLayout(alignment: .top, spacing: 18))
                            : AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
                        layout {
                            accountGroups(width: width >= 1120 ? width - 362 : width)
                                .frame(maxWidth: .infinity)
                            accountDetailPanel.frame(width: width >= 1120 ? 344 : nil)
                        }
                    }
                }
                .padding(theme.spacing.pagePadding)
            }
        }
    }

    private func accountSummaryStrip(width: CGFloat) -> some View {
        let layout = width >= 820 ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
        return LFPanel {
            layout {
                accountSummaryGroup(cards: false)
                if width >= 820 { Divider() }
                else { Divider().overlay(theme.palette.divider) }
                accountSummaryGroup(cards: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func accountSummaryGroup(cards: Bool) -> some View {
        let summaries = accountsViewModel.nativeBalanceSummaries.filter { cards ? !$0.cards.isEmpty : !$0.banks.isEmpty }
        return VStack(alignment: .leading, spacing: 12) {
            Text(cards ? "Card amounts owed" : "Bank balances").font(theme.typography.rowTitle)
            if summaries.isEmpty {
                Text(cards ? "No current card accounts" : "No current bank accounts")
                    .font(theme.typography.body).foregroundStyle(theme.palette.secondaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], alignment: .leading, spacing: 14) {
                    ForEach(summaries) { summary in
                        let total = cards ? summary.cardTotal : summary.bankTotal
                        VStack(alignment: .leading, spacing: 5) {
                            Text(summary.currency.code).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                            Text(total.map { MoneyFormatting.number($0) } ?? "Unavailable")
                                .font(theme.typography.headlineMoney.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(cards && (total?.amount ?? 0) > 0 ? theme.financialNegative : theme.palette.primaryText)
                                .fixedSize(horizontal: true, vertical: false)
                                .accessibilityLabel(summary.currency.code + " " + (total.map { MoneyFormatting.number($0) } ?? "Unavailable"))
                            if total == nil {
                                Text("Missing balance evidence").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                            }
                        }
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accountGroups(width: CGFloat) -> some View {
        let layout = width >= 735 ? AnyLayout(HStackLayout(alignment: .top, spacing: 18))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
        return VStack(alignment: .leading, spacing: 18) {
            layout {
                accountGroup(title: "Bank accounts", icon: "building.columns", types: [.bank], key: "banks")
                accountGroup(title: "Credit cards", icon: "creditcard", types: [.creditCard], key: "cards")
            }
            if accountsViewModel.accounts.contains(where: { ![AccountType.bank, .creditCard].contains($0.accountType) }) {
                accountGroup(title: "Other accounts", icon: "wallet.pass", types: [.investment, .cash, .loan], key: "other")
            }
        }
    }

    private func accountGroup(title: String, icon: String, types: Set<AccountType>, key: String) -> some View {
        let accounts = accountsViewModel.accounts.filter { types.contains($0.accountType) }
        let current = accounts.filter { !$0.isHistoryOnly }, historical = accounts.filter(\.isHistoryOnly)
        return LFPanel(contentSpacing: 14) {
            Label(title, systemImage: icon).font(theme.typography.sectionTitle)
            HStack {
                Text(types == [.creditCard] ? "Card" : "Account")
                Spacer()
                Text(types == [.creditCard] ? "Current amount owed" : "Recorded balance")
            }.font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Divider().overlay(theme.palette.divider)
            if current.isEmpty {
                Text("No current accounts").font(theme.typography.body).foregroundStyle(theme.palette.secondaryText)
            }
            ForEach(current) { account in
                accountRow(account)
                if account.id != current.last?.id { Divider().overlay(theme.palette.divider) }
            }
            if !historical.isEmpty {
                Divider().overlay(theme.palette.divider)
                DisclosureGroup(isExpanded: Binding(get: { expandedAccountHistory.contains(key) }, set: { expanded in
                    if expanded { expandedAccountHistory.insert(key) } else { expandedAccountHistory.remove(key) }
                })) {
                    VStack(spacing: 6) {
                        ForEach(historical) { account in accountRow(account) }
                    }.padding(.top, 8)
                } label: {
                    HStack {
                        Text("History only").font(theme.typography.rowTitle)
                        Spacer()
                        Text("Excluded from totals").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }
                }.tint(theme.palette.primaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var importWizardContent: some View {
        VStack(spacing: 18) {
            if !showsAutomaticImportProgress { importStepper }

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

            if showsAutomaticImportProgress {
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
            HStack(alignment: .top, spacing: 18) {
                LFPanel {
                    Text(importCentre.items.isEmpty ? "Import Statements" : "Current statement")
                        .font(theme.typography.formSection.weight(.semibold))
                    if !importCentre.items.isEmpty {
                        ImportBatchProgressView(
                            activePosition: importCentre.currentItem.map { $0.queuePosition + 1 },
                            total: importCentre.items.count,
                            terminalCount: importCentre.terminalItems.count
                        )
                        importCurrentFileHeader
                    }
                    ScrollViewReader { scroll in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if importCentre.items.isEmpty {
                                    Text("Choose statements, then start the batch once. LedgerForge imports each validated statement and pauses when it needs your decision.")
                                        .font(theme.typography.formBody)
                                        .foregroundStyle(theme.palette.secondaryText)
                                }

                                if importCentre.items.isEmpty && !emailIntake.sources.isEmpty {
                                    EmailInboxQueueView(session: emailIntake)
                                }

                                if !importCentre.items.isEmpty {
                                    importResultPanel
                                        .id("import-current-result")
                                }

                                if importCentre.items.isEmpty {
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
                                }

                                if !pendingBatchSourceURLs.isEmpty {
                                    selectedBatchReview
                                }

                                if !importCentre.items.isEmpty {
                                    DisclosureGroup("Batch queue · \(importCentre.items.count) statements", isExpanded: $showsImportQueue) {
                                        ImportBatchQueueView(items: importBatchQueueItems) { itemID in
                                            importCentre.presentItem(itemID)
                                        }
                                    }
                                    .font(theme.typography.formBody)
                                }

                                if importCentre.items.isEmpty {
                                    importResultPanel
                                }

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
                                        Text("Start a batch to import financial records from your statements.")
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
                        .onChange(of: displayedImportItem?.id) { _, _ in
                            scroll.scrollTo("import-current-result", anchor: .top)
                        }
                        .onChange(of: displayedImportItem?.phase) { _, _ in
                            scroll.scrollTo("import-current-result", anchor: .top)
                        }
                        .onChange(of: activeStatementPasswordChallenge?.id) { _, _ in
                            scroll.scrollTo("import-current-result", anchor: .top)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                LFPanel {
                    Text("Validation Review")
                        .font(theme.typography.formSection.weight(.semibold))
                    ScrollViewReader { scroll in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                validationReviewPanel
                                    .id("import-validation-start")
                                if let prepared = preparedTransactionPreview {
                                    ScrollView(.horizontal) {
                                        transactionPreviewPanel(prepared, columns: previewColumns(prepared))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .onChange(of: displayedImportItem?.id) { _, _ in
                            scroll.scrollTo("import-validation-start", anchor: .top)
                        }
                        .onChange(of: displayedImportItem?.phase) { _, _ in
                            scroll.scrollTo("import-validation-start", anchor: .top)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity)

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
        .onChange(of: importCentre.currentItem?.id) { _, _ in showsImportQueue = false }
    }

    @ViewBuilder
    private var importFooterControls: some View {
        if showsAutomaticImportProgress {
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
        else {
            if importCentre.permitsSourceSelection && !emailIntake.sources.isEmpty {
                if emailIntake.selectedSource != nil {
                    Button("Import selected") { _ = emailIntake.startSelectedEmailImport() }
                        .lfSecondaryAction()
                        .disabled(!emailIntake.isReconciled || emailIntake.isCollecting || emailIntake.selectedSource?.acquisition != .available || emailIntake.selectedSource?.dismissed == true)
                    Button("Dismiss selected", action: emailIntake.dismissSelected).lfSecondaryAction()
                        .disabled(emailIntake.isCollecting)
                    Button("Revisit selected", action: emailIntake.revisitSelected).lfSecondaryAction()
                        .disabled(emailIntake.isCollecting)
                }
                Button("Prepare and import email batch") { _ = emailIntake.startConfirmedEmailBatch() }
                    .buttonStyle(ImportFooterButtonStyle())
                    .disabled(emailIntake.batchSources.isEmpty || emailIntake.isCollecting)
            } else { importFooterAction }
        }
        }
    }

    private var settingsContent: some View {
        GeometryReader { geometry in
            let width = min(1320, max(0, geometry.size.width - theme.spacing.pagePadding * 2))
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    if settingsSubsection != nil {
                        Button("Settings", systemImage: "chevron.left") { settingsSubsection = nil }
                            .buttonStyle(.borderless)
                            .font(theme.typography.secondary)
                            .tint(theme.palette.secondaryText)
                            .accessibilityHint("Returns to the Settings overview")
                    }
                    if settingsSubsection == .appearance {
                        LFAppearanceIntroduction(appearance: appearance)
                        LFAppearanceControls(appearance: appearance, availableWidth: width)
                    } else if settingsSubsection == .liveFX {
                        LiveFXSettingsView(rates: alDarReferenceSession, prices: investmentPriceSession,
                                           backgroundUpdates: backgroundUpdates, availableWidth: width)
                    } else if settingsSubsection == .ispAccount {
                        ZurichISPSettingsView(session: ispSyncSession, backgroundUpdates: backgroundUpdates,
                                              availableWidth: width)
                    } else if settingsSubsection == .ibkrAccount {
                        IBKRFlexSettingsView(session: ibkrFlexSession, backgroundUpdates: backgroundUpdates,
                                             availableWidth: width)
                    } else if settingsSubsection == .emailStatements {
                        EmailStatementsSettingsView(session: emailIntake, availableWidth: width) {
                            selectedSection = .imports
                        }
                    } else if settingsSubsection == .backgroundUpdates {
                        BackgroundUpdatesSettingsView(session: backgroundUpdates, availableWidth: width)
                    } else if settingsSubsection == .backup {
                        BackupRestoreSettingsSection(availableWidth: width)
                    } else if settingsSubsection == .categories {
                        CategoryManagementView()
                    } else {
                        LFSettingsPageHeader("Settings", subtitle: "Preferences, connections and your ledger.")
                        settingsOverview(availableWidth: width)
                    }
                }
                .frame(maxWidth: 1320, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(theme.spacing.pagePadding)
            }
        }
    }

    private func settingsOverview(availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            LFSettingsColumns(availableWidth: availableWidth, leadingFraction: 0.44) {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    settingsDestinationGroup("Workspace", destinations: [.appearance, .backup, .categories])
                    settingsApplicationPanel
                }
            } trailing: {
                settingsDestinationGroup("Connections & updates", destinations: [
                    .liveFX, .ispAccount, .ibkrAccount, .emailStatements, .backgroundUpdates
                ])
            }
            settingsDataPanel(availableWidth: availableWidth)
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                Text(DatabaseProvider.shared.persistenceState.statusMessage)
                if let guidance = DatabaseProvider.shared.persistenceState.recoveryGuidance { Text(guidance) }
                Text(dashboardViewModel.presentationState.message)
            }
            .font(theme.typography.secondary)
            .foregroundStyle(theme.palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settingsApplicationPanel: some View {
        LFPanel(title: "Application") {
#if DEBUG
            Toggle("Developer Mode", isOn: Binding(
                get: { developerDatabaseProfileViewModel.developerModeEnabled },
                set: { updateDeveloperMode($0) }
            ))
            .toggleStyle(.switch)
            .font(theme.typography.body)
            if let message = developerDatabaseProfileViewModel.operationState.message {
                Text(message).font(theme.typography.caption).foregroundStyle(LFTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(theme.palette.divider)
#endif
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                    settingsVersion
                    Spacer(minLength: theme.spacing.small)
                    settingsPersistence
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    settingsVersion
                    settingsPersistence
                }
            }
        }
    }

    private var settingsVersion: some View {
        Text("Version " + SettingsPresentation.applicationVersion(infoDictionary: Bundle.main.infoDictionary))
            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
    }

    private var settingsPersistence: some View {
        Text(DatabaseProvider.shared.persistenceState.displayName)
            .font(theme.typography.secondary.weight(.semibold))
            .foregroundStyle(DatabaseProvider.shared.persistenceState.isDurable ? LFTheme.success : LFTheme.warning)
    }

    private func settingsDataPanel(availableWidth: CGFloat) -> some View {
        let imports = SettingsPresentation.completedImports(
            from: importAttemptStore.attempts, persistenceState: DatabaseProvider.shared.persistenceState)
        let partial: String
        if case .available(_, let count) = imports { partial = count.formatted() }
        else { partial = "Unavailable" }
        let columns = availableWidth >= max(800, theme.typography.size(.headlineMoney) * 28) ? 4 : 2
        return LFPanel(title: "Your data") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: columns),
                      alignment: .leading, spacing: theme.spacing.sectionGap) {
                settingsDataValue("Accounts", value: dashboardViewModel.accounts.count.formatted())
                settingsDataValue("Transactions", value: dashboardViewModel.storedTransactionCount.formatted())
                settingsDataValue("Completed imports", value: imports.displayValue)
                settingsDataValue("Partial imports", value: partial)
            }
        }
    }

    private func settingsDataValue(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(value).font(theme.typography.headlineMoney).monospacedDigit()
            Text(title).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func settingsDestinationGroup(_ title: String, destinations: [SettingsSubsection]) -> some View {
        LFPanel(title: title, contentSpacing: theme.spacing.small) {
            ForEach(destinations, id: \.self) { destination in
                if destination != destinations.first { Divider().overlay(theme.palette.divider) }
                settingsDestinationRow(destination)
            }
        }
    }

    private func settingsDestinationRow(_ destination: SettingsSubsection) -> some View {
        let summary: String
        switch destination {
        case .appearance:
            summary = appearance.overrides.isEmpty ? "Dark · Default appearance" : "Dark · Custom appearance"
        case .backup:
            summary = backupRecovery.isBusy ? "Backup or restore in progress" : "Create or restore a verified ledger backup"
        case .liveFX: summary = liveFXSummary
        case .categories: summary = categorySummary
        case .ispAccount: summary = ispSyncSession.connectionSummary
        case .emailStatements: summary = emailIntake.connectionSummary
        case .ibkrAccount: summary = ibkrFlexSession.connectionSummary
        case .backgroundUpdates: summary = backgroundUpdates.status
        }
        let needsAttention: Bool
        switch destination {
        case .ispAccount: needsAttention = !ispSyncSession.isConnectionAvailable
        case .emailStatements: needsAttention = emailIntake.account != nil && !emailIntake.isConnected
        case .backgroundUpdates: needsAttention = backgroundUpdates.configuration.enabled && !backgroundUpdates.activeSchedule
        default: needsAttention = false
        }
        return Button { settingsSubsection = destination } label: {
            HStack(spacing: theme.spacing.controlGap) {
                Image(systemName: destination.systemImage)
                    .font(theme.typography.sectionIcon)
                    .foregroundStyle(theme.palette.secondaryText)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    Text(destination.rawValue).font(theme.typography.rowTitle)
                    Text(summary).font(theme.typography.secondary)
                        .foregroundStyle(needsAttention ? LFTheme.warning : theme.palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: theme.spacing.small)
                Image(systemName: "chevron.right")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, theme.spacing.controlGap)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(LFPlainActionStyle())
        .accessibilityLabel("Open \(destination.rawValue)")
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
        LFPanel(contentSpacing: theme.spacing.small) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.controlGap) {
                    Text(dashboardImportTitle).font(theme.typography.rowTitle)
                    Spacer(minLength: theme.spacing.small)
                    dashboardRouteButton(.imports)
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    Text(dashboardImportTitle).font(theme.typography.rowTitle)
                    dashboardRouteButton(.imports)
                }
            }
            if availability.state == .loading {
                dashboardState("Loading import activity…", loading: true)
            } else if availability.state == .unavailable || availability.state == .retainedNonCurrent {
                dashboardState("Import activity unavailable")
            } else if let pending = sidebarPendingImportStatus {
                Label(pending, systemImage: "tray.full")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .accessibilityIdentifier("dashboard.pendingImports")
            } else if let attention = dashboardAttention {
                Label(attention.title, systemImage: attention.iconName)
                    .font(theme.typography.body).foregroundStyle(attention.tone.color)
                    .help(attention.explanation).accessibilityHint(attention.explanation)
            } else if dashboardShowsCurrentImport {
                let current = importActivityPresentation
                Label(current.status, systemImage: current.iconName)
                    .font(theme.typography.body).foregroundStyle(current.tone.color)
                Text(current.title).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    .lineLimit(2).help(current.title + " · " + current.subtitle)
                if let timestamp = current.recordedAtText {
                    Text(timestamp).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
            } else if let saved = dashboardLastCompletedImport {
                let outcome = DurableImportAttemptPresentation(attempt: saved).outcome
                Label(outcome.label, systemImage: outcome.iconName)
                    .font(theme.typography.body).foregroundStyle(outcome.tone.color)
                Text(ImportInstantFormatting.display(saved.createdAtISO))
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            } else {
                Text("No completed imports yet")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private var dashboardImportTitle: String {
        if dashboardActionableImportStatus != nil { return "Import needs attention" }
        if sidebarPendingImportStatus != nil { return "Import in progress" }
        if dashboardAttention != nil { return "Import needs attention" }
        if dashboardShowsCurrentImport {
            return importActivityPresentation.tone == .danger ? "Import needs attention" : "Latest import"
        }
        return "Last completed import"
    }

    private var dashboardShowsCurrentImport: Bool {
        switch importState {
        case .preparing, .previewReady, .validationFailed, .committing, .failed: return true
        case .completed(let outcome): return outcome.tone != .success
        case .idle:
            return importHistoryViewModel.latestDurableAttempt.map {
                DurableImportAttemptPresentation(attempt: $0).outcome.tone == .danger
            } ?? false
        case .skipped, .cancelled: return false
        }
    }

    /// Reuse accepted outcome codes and timestamp ordering. A newer attempt
    /// never borrows a date or a completed label from an earlier persisted result.
    private var dashboardLastCompletedImport: RepositoryImportAttempt? {
        let persisted = importHistoryViewModel.attempts.filter {
            [.successfulImport, .partialImportCommitted, .cbqSourceOverlapCommitted].contains(ImportAttemptOutcome(rawValue: $0.outcomeCode))
        }
        return ImportActivityPresentation.latestDurableAttempt(from: persisted)
    }

    private var accountDetailPanel: some View {
        LFPanel(variant: .inspector) {
            VStack(alignment: .leading, spacing: 18) {
                if let account = accountsViewModel.selectedAccount {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            if accountsViewModel.isEditingDisplayName {
                                TextField("Display name", text: $accountsViewModel.displayNameDraft)
                                    .lfTextField()
                            } else {
                                Text(account.displayName)
                                    .font(theme.typography.sectionTitle)
                            }
                            Text(accountContext(account))
                                .font(theme.typography.secondary)
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
                        if account.isHistoryOnly {
                            Button("Make current") { accountsViewModel.markAccountCurrent(accountID: account.id) }
                                .lfSecondaryAction()
                                .help("Include this account in current views and totals again.")
                                .accessibilityIdentifier("accounts.makeCurrent")
                        } else {
                            Button("Keep as history only…") {
                                confirmsCardHistoryOnly = true
                            }
                            .lfSecondaryAction()
                            .confirmationDialog(account.accountType == .creditCard
                                                ? "Is this card closed and fully settled?"
                                                : "Keep this account for history only?",
                                                isPresented: $confirmsCardHistoryOnly,
                                                titleVisibility: .visible) {
                                Button("Keep history only") {
                                    accountsViewModel.markAccountHistoryOnly(accountID: account.id)
                                }
                                Button("Cancel", role: .cancel) { }
                            } message: {
                                Text("This account will be excluded from default views and totals. Select it explicitly to review its history. You can make it current again here.")
                            }
                        }
                    }

                    if let message = accountsViewModel.presentationState.message {
                        Text(message)
                            .font(theme.typography.secondary)
                            .foregroundStyle(LFTheme.warning)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(account.currentBalanceLabel)
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.palette.secondaryText)
                        Text(account.currentBalance.map { formatCurrency($0, currencyCode: account.currencyCode) } ?? "Unavailable")
                            .font(theme.typography.headlineMoney.weight(.semibold))
                            .foregroundStyle(accountBalanceColor(account))
                            .monospacedDigit()
                    }

                    if account.isHistoryOnly {
                        Text("History only · excluded from default views and totals.")
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LFInfoRow(title: "Account Type", value: account.accountTypeLabel, textRole: .body)
                    LFInfoRow(title: "Transactions", value: "\(accountsViewModel.transactionCount)", textRole: .body)
                    if let period = account.latestStatementPeriod {
                        LFInfoRow(title: "Latest Statement", value: period, textRole: .body)
                    }
                    if let dueDate = account.dueDate {
                        LFInfoRow(title: account.isHistoryOnly ? "Historical Due Date" : "Due Date", value: dueDate, textRole: .body)
                    }
                    if let count = account.cardInstrumentCount {
                        LFInfoRow(title: "Cards", value: "\(count)", textRole: .body)
                    }

                    Divider().overlay(theme.palette.divider)

                    DisclosureGroup("Recent activity") {

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
                        .font(theme.typography.secondary)
                    }

                    }.font(theme.typography.body).tint(theme.palette.primaryText)

                    Divider().overlay(theme.palette.divider)

                    DisclosureGroup("Verified financial identity") {
                    if account.identitySummaries.isEmpty {
                        LFCompactEmptyState(message: "No verified strong identifiers")
                    } else {
                        ForEach(account.identitySummaries) { identifier in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(identifier.kind) · \(identifier.redactedValue)")
                                    .font(theme.typography.secondary.weight(.semibold))
                                Text("\(identifier.strength) · \(identifier.verificationState) · \(identifier.provenance)")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.palette.secondaryText)
                            }
                        }
                    }

                    }.font(theme.typography.body).tint(theme.palette.primaryText)

                    Divider().overlay(theme.palette.divider)

                    DisclosureGroup("Import history") {
                    if accountsViewModel.importHistory.isEmpty {
                        LFCompactEmptyState(message: "No trusted import history for this account")
                    } else {
                        ForEach(accountsViewModel.importHistory) { session in
                            Button {
                                accountsViewModel.selectImportSession(id: session.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.sourceDocumentName ?? "Imported statement")
                                        .font(theme.typography.secondary.weight(.semibold))
                                    Text((session.recognizedExistingRowCount ?? 0) > 0
                                         ? "\(session.validationStatus) · \(session.transactionCount) new, \(session.recognizedExistingRowCount ?? 0) already recorded"
                                         : "\(session.validationStatus) · \(session.transactionCount) transaction(s)")
                                        .font(theme.typography.caption)
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
                                .font(theme.typography.rowTitle)
                            Spacer()
                            Button("Close") {
                                accountsViewModel.clearSelectedImportSession()
                            }
                            .lfSecondaryAction()
                        }
                        LFInfoRow(title: "Source", value: session.sourceDocumentName ?? "Imported statement", textRole: .body)
                        LFInfoRow(title: "Status", value: session.validationStatus, textRole: .body)
                        LFInfoRow(title: "Transactions", value: "\(session.transactionCount)", textRole: .body)
                        if (session.recognizedExistingRowCount ?? 0) > 0 {
                            LFInfoRow(title: "Import Type", value: session.transactionCount == 0 ? "Supporting source" : "New and already recorded activity", textRole: .body)
                            LFInfoRow(title: "Source Rows", value: "\(session.sourceRowCount ?? 0)", textRole: .body)
                            LFInfoRow(title: "Already Represented", value: "\(session.recognizedExistingRowCount ?? 0)", textRole: .body)
                        }
                        if let parserVersion = session.parserVersion {
                            LFInfoRow(title: "Parser", value: parserVersion, textRole: .body)
                        }
                    }
                    }.font(theme.typography.body).tint(theme.palette.primaryText)
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

    private func accountBalanceColor(_ account: AccountsAccountPresentation) -> Color {
        guard let value = account.currentBalance, !account.isHistoryOnly else { return theme.palette.secondaryText }
        let adverse = account.accountType == .creditCard ? value > .zero : value < .zero
        return adverse ? theme.financialNegative : theme.financialPositive
    }

    private var accountTableHeader: some View {
        HStack(spacing: 12) {
            Text("Account Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Account number")
                .frame(width: 125, alignment: .leading)
            Text("Institution")
                .frame(width: 160, alignment: .leading)
            Text("Type")
                .frame(width: 100, alignment: .leading)
            Text("Balance")
                .frame(width: 140, alignment: .trailing)
        }
        .font(theme.typography.secondary)
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
                    .font(theme.typography.sectionTitle)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(theme.typography.body.weight(.medium))
                    Text(value)
                        .font(theme.typography.headlineMoney.weight(.semibold))
                        .foregroundStyle(tint == LFTheme.danger ? LFTheme.danger : theme.palette.primaryText)
                        .monospacedDigit()
                    Text(detail)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accountRow(_ account: AccountsAccountPresentation) -> some View {
        let selected = accountsViewModel.selectedRepositoryAccountID == account.id
        return Button {
            accountsViewModel.selectAccount(repositoryAccountID: account.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(account.displayName).font(theme.typography.body.weight(selected ? .semibold : .regular))
                        .foregroundStyle(account.isHistoryOnly && !selected ? theme.palette.secondaryText : theme.palette.primaryText)
                    Text(accountContext(account)).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if account.isHistoryOnly {
                    if selected { Text("Selected").font(theme.typography.secondary).foregroundStyle(theme.palette.accentHover) }
                } else {
                    Text(account.currentBalance.map { formatCurrency($0, currencyCode: account.currencyCode) } ?? "Unavailable")
                        .font(theme.typography.rowTitle).monospacedDigit()
                        .foregroundStyle(account.accountType == .creditCard ? accountBalanceColor(account) : theme.palette.primaryText)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(selected ? theme.interaction.dataRow(selected: true, active: appearsActive) : Color.clear,
                in: RoundedRectangle(cornerRadius: theme.radius.control))
            .overlay(RoundedRectangle(cornerRadius: theme.radius.control)
                .strokeBorder(selected ? theme.palette.accent.opacity(0.7) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(LFPlainActionStyle())
        .accessibilityIdentifier("accounts.row." + account.id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func accountContext(_ account: AccountsAccountPresentation) -> String {
        [account.institution, account.accountNumberLabel, account.currencyCode].compactMap { $0 }.joined(separator: " · ")
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
                    .textSelection(.enabled)
                Text(subtitle)
                    .font(theme.typography.formBody)
                    .foregroundStyle(theme.palette.secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(theme.palette.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var importCurrentFileHeader: some View {
        let presentation = ImportActivityPresentation(importState: importState, latestDurableAttempt: nil)
        return importedFileRow(
            name: activeStatementPasswordChallenge?.fileName ?? selectedFile,
            subtitle: importCurrentReviewMessage ?? presentation.subtitle,
            icon: activeStatementPasswordChallenge == nil ? presentation.iconName : "lock.doc",
            color: presentation.tone.color
        )
        .id(displayedImportItem?.id)
    }

    private var importCurrentReviewMessage: String? {
        if activeStatementPasswordChallenge != nil { return "Password required to continue" }
        switch importState {
        case .failed(_, let message, _):
            return message
        case .previewReady(let prepared):
            if prepared.investmentConfirmationBlocked { return "Holdings update needs review" }
            switch prepared.statementEquivalenceReview {
            case .conflict: return "Statement equivalence conflict — import is blocked"
            case .evidenceUnavailable: return "Overlapping history needs review — import is blocked"
            case .formatAlreadyRecorded: return "This source format is already recorded"
            default: break
            }
            if partialReviewBlocksConfirmation { return "Review transaction selection before importing" }
            return ImportIdentityReviewUIProjection(review: importIdentityReview).presentation?.label
        default:
            return nil
        }
    }

    private var importResultPanel: some View {
        Group {
            if importCentre.items.isEmpty { importCurrentFileHeader }
            switch importState {
            case .idle:
                EmptyView()
            case .preparing:
                VStack(alignment: .leading, spacing: 12) {
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
                            LFPasswordField("Statement password", text: $statementPassword)
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
                    preparedImportPreview(preparedImport)
                    if case .committing = importState {
                        Text("Importing confirmed financial data. This write cannot be cancelled safely.")
                            .font(theme.typography.formCaption.weight(.semibold))
                            .foregroundStyle(LFTheme.warning)
                    }
                }
            case .completed(let outcome):
                VStack(alignment: .leading, spacing: 12) {
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

                    ForEach(outcome.bankSections, id: \.sectionID) { section in
                        let accountName = accountsViewModel.accounts.first { $0.id == section.accountID }?.displayName ?? "Bank account"
                        LFInfoRow(title: accountName, value: section.sourceRowCount == 0
                            ? "No transactions in this account section"
                            : "\(section.sourceRowCount) transaction(s) · \(section.importedTransactionCount) new · \(section.sourceRowCount - section.importedTransactionCount) already recorded")
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
            case .skipped, .cancelled:
                EmptyView()
            case .failed(_, _, let retrySourceURL):
                VStack(alignment: .leading, spacing: 10) {
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

    private func preparedImportPreview(_ preparedImport: PreparedImport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if preparedImport.financialDocument.investmentStatementEvidence != nil {
                InvestmentImportReviewView(preparation: preparedImport) { importCentre.updateInvestmentChoices($0) }
            } else {
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

                importIdentityReviewPanel(preparedImport)

                if case .eligible(let plan) = partialImportReview {
                    partialImportReviewPanel(plan, preparedImport: preparedImport)
                }

                HStack(spacing: 8) {
                    LFStatusBadge(title: AccountDisplayText.shortened(preparedImport.detectedInstitution.rawValue), color: theme.palette.accent)
                    LFStatusBadge(title: preparedImport.detectedDocumentType.rawValue, color: LFTheme.info)
                    LFStatusBadge(title: preparedImport.parserName, color: theme.palette.secondaryText)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    LFInfoRow(title: "Transactions", value: "\(preparedImport.transactionCount)")
                    LFInfoRow(title: "Currency", value: preparedImport.detectedCurrency ?? "Unknown")
                    if preparedImport.financialDocument.bankStatementEvidence == nil {
                        LFInfoRow(title: "Account", value: preparedImport.accountMetadata ?? "Unknown")
                        LFInfoRow(title: "Statement Period", value: statementPeriodText(preparedImport.statementPeriod))
                        LFInfoRow(title: "Opening Balance", value: balanceText(preparedImport.validation.openingBalance, currency: preparedImport.detectedCurrency))
                        LFInfoRow(title: "Closing Balance", value: balanceText(preparedImport.validation.closingBalance, currency: preparedImport.detectedCurrency))
                    }
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

                if let number = preparedImport.financialDocument.cardStatementEvidence?
                    .accountSourceIdentityObservations.first(where: { $0.kind == .axisPrimaryMaskedCardNumber })?.value {
                    LFInfoRow(title: "Printed card number", value: number)
                }

                if let matchedAccountID = projection.matchedAccountID,
                   let account = accountsViewModel.accounts.first(where: { $0.id == matchedAccountID }) {
                    VStack(alignment: .leading, spacing: 6) {
                        LFInfoRow(title: "Destination Account", value: account.displayName)
                        LFInfoRow(title: "Institution", value: account.institution)
                    }
                }

                if case .bankSections(let sections) = importIdentityReview {
                    ForEach(sections, id: \.sectionID) { section in
                        bankSectionIdentityReview(section, preparedImport: preparedImport)
                    }
                    Text("Confirming imports all account sections together. An unresolved account or conflicting source row holds the whole statement.")
                        .font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText)
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
                    if importIdentityReview.matchedCardLiabilityAccountId == nil {
                        newAccountCreationChoice(preparedImport, instrumentAware: true)
                    }
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
        if account.canonicalInstitutionID != prepared.detectedInstitution.rawValue {
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
           sourceName != prepared.detectedInstitution.rawValue { return AccountDisplayText.shortened(sourceName) }
        return AccountDisplayText.shortened(ImportPersistenceMapper.displayAccountName(
            institutionName: prepared.detectedInstitution.rawValue,
            documentType: prepared.detectedDocumentType,
            currency: prepared.detectedCurrency,
            fallbackFileName: prepared.fileName
        ))
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

    @ViewBuilder
    private func bankSectionIdentityReview(
        _ section: BankSectionIdentityReview,
        preparedImport: PreparedImport
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.product)
                .font(theme.typography.formBody.weight(.semibold))
            LFInfoRow(title: "Source account", value: section.sourceAccountLabel)
            if let period = section.period {
                LFInfoRow(title: "Statement period", value: "\(period.start.presentation) – \(period.end.presentation)")
            }
            LFInfoRow(title: "Transactions", value: "\(section.transactionCount)")

            switch section.identityReview {
            case .matchedExisting(let accountID):
                if let account = accountsViewModel.accounts.first(where: { $0.id == accountID }) {
                    LFInfoRow(title: "Destination account", value: account.displayName)
                    LFInfoRow(title: "Institution", value: account.institution)
                } else {
                    Text("Matched destination account is unavailable in this review presentation.")
                        .font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
            case .choiceRequired(let eligibleAccountIDs):
                Text("Destination account")
                    .font(theme.typography.formCaption.weight(.semibold))
                ForEach(accountsViewModel.accounts.filter { eligibleAccountIDs.contains($0.id) }) { account in
                    let selectedAccountID: String? = {
                        guard case .useExistingAccount(let accountID) = bankSectionDraftChoices[section.sectionID] else {
                            return nil
                        }
                        return accountID
                    }()
                    let isSelected = selectedAccountID == account.id
                    Button {
                        importCentre.updateBankSectionChoice(
                            sectionID: section.sectionID,
                            choice: .useExistingAccount(accountId: account.id)
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.displayName)
                                Text(account.institution)
                                    .font(theme.typography.formCaption)
                                    .foregroundStyle(theme.palette.secondaryText)
                            }
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    .buttonStyle(LFPlainActionStyle())
                    .foregroundStyle(theme.palette.primaryText)
                }
                bankSectionNewAccountChoice(section, preparedImport: preparedImport)
            case .ambiguous, .conflict:
                let projection = ImportIdentityReviewUIProjection(review: section.identityReview)
                if let presentation = projection.presentation, let iconName = projection.iconName {
                    ImportAccountOutcomeView(presentation: presentation, iconName: iconName, tone: projection.tone)
                }
            case .unavailable:
                Text("This section has no eligible destination account decision.")
                    .font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.secondaryText)
            case .liabilityAccountChoiceRequired, .cardChoiceRequired, .bankSections:
                Text("This section has an unsupported account-review shape.")
                    .font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
        .padding(10)
        .background(theme.palette.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func bankSectionNewAccountChoice(
        _ section: BankSectionIdentityReview,
        preparedImport: PreparedImport
    ) -> some View {
        let selectedName: String?
        if case .createNewAccount(let name) = bankSectionDraftChoices[section.sectionID] {
            selectedName = name
        } else {
            selectedName = nil
        }
        let proposedName = proposedBankSectionAccountName(section, preparedImport: preparedImport)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                importCentre.updateBankSectionChoice(
                    sectionID: section.sectionID,
                    choice: .createNewAccount(displayName: proposedName)
                )
            } label: {
                HStack {
                    Text("Create separate bank account")
                    Spacer()
                    Image(systemName: selectedName == nil ? "circle" : "checkmark.circle.fill")
                }
            }
            .buttonStyle(LFPlainActionStyle())
            if let selectedName {
                LabeledContent("Display name") {
                    TextField("Account display name", text: Binding(
                        get: { selectedName },
                        set: {
                            importCentre.updateBankSectionChoice(
                                sectionID: section.sectionID,
                                choice: .createNewAccount(displayName: $0)
                            )
                        }
                    ))
                    .lfTextField()
                }
                if selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Enter an account display name.")
                        .font(theme.typography.formCaption)
                        .foregroundStyle(LFTheme.warning)
                }
            }
        }
        .font(theme.typography.formBody)
    }

    private func proposedBankSectionAccountName(
        _ section: BankSectionIdentityReview,
        preparedImport: PreparedImport
    ) -> String {
        let product = section.product.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !product.isEmpty else { return proposedAccountName(preparedImport) }
        return "\(AccountDisplayText.shortened(preparedImport.detectedInstitution.rawValue)) \(product)"
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

    private func cardNumbers(_ group: CardInstrumentLineage.Group) -> [String] {
        let members = Set(group.members)
        let observations = cardStore.snapshot.instruments.filter { members.contains($0.id) }.flatMap(\.sourceObservations)
            + cardStore.snapshot.statements.flatMap(\.sections).filter { members.contains($0.instrumentID) }.flatMap(\.sourceObservations)
        return Set(observations.map(\.value)).sorted()
    }

    private func continuingCardLabel(_ group: CardInstrumentLineage.Group, printed: String?) -> String {
        let numbers = cardNumbers(group)
        let labels = numbers.sorted { left, right in
            if (left == printed) != (right == printed) { return left == printed }
            return left < right
        }.map { AccountDisplayText.maskedNumber($0) ?? $0 }
        return labels.isEmpty ? "Card details unavailable" : "Card " + labels.joined(separator: " · ")
    }

    private func cardSectionSelection(
        section: CardInstrumentSectionEvidence, allSectionIDs: [String],
        accountID: String, instruments: [CardInstrument]
    ) -> some View {
        let observation = section.sourceIdentityObservations.first
        let groups = cardStore.snapshot.continuingCardGroups(accountID: accountID)
        let draft = cardSectionDraftChoices[section.documentScopedSectionID]
        let selection: CardSelection = switch draft {
        case .reuseExistingInstrument(let id): .existing(groups.first { $0.members.contains(id) }?.id ?? id)
        case .createNewInstrument: .new
        case nil: .pending
        }
        let update: (ImportCardInstrumentChoice) -> Void = { choice in
            importCentre.updateCardSectionChoice(accountID: accountID, sectionID: section.documentScopedSectionID,
                                                 choice: choice, requiredSectionIDs: allSectionIDs)
        }
        let labels = instruments.map(cardLabel)
        let ambiguousLabels = Set(Dictionary(grouping: labels, by: { $0 }).filter { $0.value.count > 1 }.keys)
        let usedElsewhere = Set(cardSectionDraftChoices.compactMap { id, choice -> String? in
            guard id != section.documentScopedSectionID,
                  case .reuseExistingInstrument(let instrumentID) = choice else { return nil }
            return instrumentID
        })
        var choices = groups.compactMap { group -> (group: CardInstrumentLineage.Group, instrumentID: String, title: String)? in
            guard let id = cardStore.snapshot.instrumentForSelection(group: group, observation: observation) else { return nil }
            return (group, id, continuingCardLabel(group, printed: observation?.value))
        }
        let shortCollisions = Set(Dictionary(grouping: choices, by: \.title).filter { $0.value.count > 1 }.keys)
        choices = choices.map { choice in
            guard shortCollisions.contains(choice.title) else { return choice }
            let exact = cardNumbers(choice.group).joined(separator: " / ")
            return (choice.group, choice.instrumentID, exact.isEmpty ? choice.title : exact)
        }
        let ambiguousChoices = Set(Dictionary(grouping: choices, by: \.title).filter { $0.value.count > 1 }.keys)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Card printed on this statement")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                Text(observation?.value ?? "Card number unavailable")
                    .font(theme.typography.sectionTitle).monospaced()
                    .textSelection(.enabled)
                    .accessibilityIdentifier("import.printedCard." + section.documentScopedSectionID)
                if let holder = section.holderLabel { Text(holder).font(theme.typography.body) }
            }
            Picker("Use saved card", selection: Binding(get: { selection }, set: { choice in
                switch choice {
                case .existing(let id):
                    if let choice = choices.first(where: { $0.group.id == id }) {
                        update(.reuseExistingInstrument(instrumentId: choice.instrumentID))
                    }
                case .new: update(.createNewInstrument())
                case .pending: break
                }
            })) {
                Text("Choose a card").tag(CardSelection.pending)
                ForEach(choices, id: \.group.id) { choice in
                    Text(choice.title + (cardNumbers(choice.group).contains(observation?.value ?? "") ? " · Number matches statement" : ""))
                        .tag(CardSelection.existing(choice.group.id))
                        .disabled(ambiguousChoices.contains(choice.title) || usedElsewhere.contains(choice.instrumentID))
                }
                Text("Add a different card or replacement").tag(CardSelection.new)
            }
            if case .reuseExistingInstrument(let id) = draft,
               let group = groups.first(where: { $0.members.contains(id) }) {
                Text("Known numbers: " + cardNumbers(group).joined(separator: " · "))
                    .font(theme.typography.body).fixedSize(horizontal: false, vertical: true)
                if group.members.count > 1 {
                    Text("Includes the replacement history you confirmed.")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }
            }
            if case .reuseExistingInstrument(let id) = draft, usedElsewhere.contains(id) {
                Text("This recorded card is selected for another section. Choose a different card, or create a new card for this section.")
                    .font(theme.typography.formBody).foregroundStyle(LFTheme.warning)
            }
            if !ambiguousChoices.isEmpty {
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
                LFInfoRow(title: "Declared Period", value: "\(AppDateDisplay.civil(plan.basePlan.declaredStatementStartISO)) – \(AppDateDisplay.civil(plan.basePlan.declaredStatementEndISO))")
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
                            Text("\(AppDateDisplay.civil(row.statementDateISO)) · \(row.nativeCurrency) \(row.amountDecimal)")
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
                                        .font(theme.typography.formBody)
                                        .foregroundStyle(theme.palette.primaryText)
                                }
                            }
                        }
                    }

                    if let investment = preparedImport.financialDocument.investmentStatementEvidence {
                        LFInfoRow(title: "Closing positions read", value: "\(investment.scopes.reduce(0) { $0 + $1.positions.count })")
                        Text("Quantity and source cost are applied together after confirmation.")
                            .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                    } else if let salary = preparedImport.financialDocument.salaryStatementEvidence {
                        LFStatusBadge(title: "Imported Source Truth", color: LFTheme.info)
                        LFInfoRow(title: "Document Kind", value: salary.kind.displayName)
                        LFInfoRow(title: "Pay Period", value: AppDateDisplay.month(salary.financialPeriod.canonical))
                        LFInfoRow(title: "Print Date", value: salary.printDate?.presentation ?? "Not printed")
                        LFInfoRow(title: "Earnings", value: formatCurrency(salary.printedEarningsTotal.amount, currencyCode: "QAR"))
                        LFInfoRow(title: "Deductions", value: salary.printedDeductionsTotal.map { formatCurrency($0.amount, currencyCode: "QAR") } ?? "Not printed")
                        LFInfoRow(title: "Payment Total", value: formatCurrency(salary.printedPaymentTotal.amount, currencyCode: "QAR"))
                        Text("\(salary.earnings.count) earning line(s) and \(salary.deductions.count) deduction line(s), preserved in source order.")
                            .font(theme.typography.formCaption)
                            .foregroundStyle(theme.palette.secondaryText)
                    } else {
                        LFInfoRow(title: "Rows Read", value: "\(preparedImport.validation.rowsRead)")
                        LFInfoRow(title: "Transactions Parsed", value: "\(preparedImport.validation.transactionsParsed)")
                        if preparedImport.financialDocument.bankStatementEvidence == nil {
                            LFInfoRow(title: "Debit Total", value: balanceText(preparedImport.validation.debitTotal, currency: preparedImport.detectedCurrency))
                            LFInfoRow(title: "Credit Total", value: balanceText(preparedImport.validation.creditTotal, currency: preparedImport.detectedCurrency))
                        }
                    }

                    Text("No data has been written.")
                        .font(theme.typography.formCaption.weight(.semibold))
                        .foregroundStyle(LFTheme.info)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LFTheme.info.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))


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
