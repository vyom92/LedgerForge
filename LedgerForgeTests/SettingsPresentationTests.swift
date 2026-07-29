import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct SettingsPresentationTests {

    @Test func completedImportsReportsZeroWhenCancellationCreatesNoDurableAttempt() {
        #expect(
            SettingsPresentation.completedImports(
                from: [],
                persistenceState: .verifiedSQLite
            ) == .available(0)
        )
    }

    @Test func completedImportsCountsOnlyNewlyPersistedSuccessfulAttempts() {
        let attempts = [
            attempt(id: "success-1", outcome: .successfulImport),
            attempt(id: "duplicate", outcome: .exactStatementDuplicate),
            attempt(id: "validation", outcome: .validationFailure),
            attempt(id: "persistence", outcome: .persistenceFailure),
            attempt(id: "rejected", outcome: .transactionEventOwnershipConflict),
            attempt(id: "success-2", outcome: .successfulImport)
        ]

        #expect(
            SettingsPresentation.completedImports(
                from: attempts,
                persistenceState: .verifiedSQLite
            ) == .available(2)
        )
    }

    @Test func completedImportsUsesHydratedHistoryRatherThanTransientFileSelection() {
        let hydratedAttempts = [attempt(id: "success", outcome: .successfulImport)]

        let original = SettingsPresentation.completedImports(
            from: hydratedAttempts,
            persistenceState: .verifiedSQLite
        )
        let relaunchEquivalent = SettingsPresentation.completedImports(
            from: hydratedAttempts,
            persistenceState: .verifiedSQLite
        )

        #expect(original == .available(1))
        #expect(relaunchEquivalent == .available(1))
    }

    @Test func completedImportsCountsUniqueFullAndPartialSessionsWithSeparatePartialSubset() {
        let attempts = [
            attempt(id: "full", outcome: .successfulImport),
            attempt(id: "partial", outcome: .partialImportCommitted),
            attempt(id: "partial-repeat", outcome: .partialImportCommitted, sessionID: "session-partial"),
            attempt(id: "duplicate", outcome: .exactStatementDuplicate),
            attempt(id: "failed", outcome: .persistenceFailure)
        ]

        #expect(
            SettingsPresentation.completedImports(
                from: attempts,
                persistenceState: .verifiedSQLite
            ) == .available(2, partialCount: 1)
        )
        #expect(
            SettingsPresentation.completedImports(
                from: attempts,
                persistenceState: .intentionalNonDurable(.testMemory)
            ) == .unavailable
        )
    }

    @Test func completedImportsReportsUnavailableWhenDurableHistoryCannotBeRead() {
        #expect(
            SettingsPresentation.completedImports(
                from: [attempt(id: "success", outcome: .successfulImport)],
                persistenceState: .unavailable(.migrationFailed)
            ) == .unavailable
        )
    }

    @Test func applicationVersionUsesBundleVersionAndBuildMetadata() {
        #expect(
            SettingsPresentation.applicationVersion(
                infoDictionary: [
                    "CFBundleShortVersionString": "2.4",
                    "CFBundleVersion": "24"
                ]
            ) == "2.4 (24)"
        )
    }

    @Test func applicationVersionHasDeterministicUnavailableFallback() {
        #expect(SettingsPresentation.applicationVersion(infoDictionary: nil) == "Unavailable")
    }

    @Test func confirmedImportRecoveryMappingIsClosedTypedAndActionBounded() throws {
        #expect(
            ConfirmedImportRecoveryPresentationMapper.presentation(for: .none) == nil
        )

        let prepareReasons: [ConfirmedImportRecoveryReason] = [
            .sourceSnapshotIntegrityFailed,
            .staleProviderGeneration,
            .reviewedPartialPlanStale,
            .persistenceContention,
            .persistenceUnavailable
        ]
        for reason in prepareReasons {
            let presentation = try #require(
                ConfirmedImportRecoveryPresentationMapper.presentation(
                    for: .prepareAgain(reason)
                )
            )
            #expect(presentation.primaryAction == .prepareAgain)
            #expect(presentation.primaryActionLabel == "Prepare Again")
            #expect(presentation.availablePrimaryAction(hasSourceURL: true) == .prepareAgain)
            #expect(presentation.availablePrimaryAction(hasSourceURL: false) == nil)
        }

        let committed = try #require(
            ConfirmedImportRecoveryPresentationMapper.presentation(
                for: .retryCanonicalReconciliation
            )
        )
        #expect(committed.primaryAction == .retryCanonicalReconciliation)
        #expect(committed.primaryActionLabel == "Retry Reconciliation")
        #expect(
            committed.availablePrimaryAction(hasSourceURL: false)
                == .retryCanonicalReconciliation
        )

        let blocked = try #require(
            ConfirmedImportRecoveryPresentationMapper.presentation(
                for: .retryCanonicalReconciliationThenPrepareAgain
            )
        )
        #expect(
            blocked.primaryAction
                == .retryCanonicalReconciliationThenPrepareAgain
        )
        #expect(blocked.primaryActionLabel == "Retry Reconciliation")
        #expect(
            blocked.availablePrimaryAction(hasSourceURL: true)
                == .retryCanonicalReconciliationThenPrepareAgain
        )
        #expect(blocked.availablePrimaryAction(hasSourceURL: false) == nil)

        let committedOutcome = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "Selected document",
                transactionCount: 1,
                validationPassed: true,
                persisted: true,
                errorMessage: "Bounded reconciliation required.",
                hydrationOutcome: .committedReconciliationRequired,
                recoveryRoute: .retryCanonicalReconciliation
            )
        )
        let blockedOutcome = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "Selected document",
                transactionCount: 1,
                validationPassed: true,
                persisted: false,
                errorMessage: "Bounded reconciliation required.",
                recoveryRoute: .retryCanonicalReconciliationThenPrepareAgain
            )
        )
        let prepareOutcome = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "Selected document",
                transactionCount: 1,
                validationPassed: true,
                persisted: false,
                errorMessage: nil,
                recoveryRoute: .prepareAgain(.persistenceContention)
            )
        )
        #expect(committedOutcome.persistenceStatus == "Saved — Reconciliation Required")
        #expect(committedOutcome.fileSubtitle == "Import saved; the current view needs reconciliation")
        #expect(blockedOutcome.persistenceStatus == "Not Saved — Reconciliation Required")
        #expect(blockedOutcome.fileSubtitle == "No new import was saved")
        #expect(prepareOutcome.persistenceStatus == "Not Saved — Fresh Preparation Required")
        #expect(prepareOutcome.fileSubtitle == "No new financial history was written")

        let reviewReasons: [ConfirmedImportRecoveryReason] = [
            .validationFailed,
            .exactStatementDuplicate,
            .transactionEventBlock,
            .accountChoiceRequired,
            .accountChoiceStale,
            .identityAmbiguous,
            .identityConflict,
            .identifierOwnershipConflict,
            .repositoryIntegrityConflict
        ]
        for reason in reviewReasons {
            let presentation = try #require(
                ConfirmedImportRecoveryPresentationMapper.presentation(
                    for: .reviewRequired(reason)
                )
            )
            #expect(presentation.primaryAction == nil)
            #expect(presentation.primaryActionLabel == nil)
            #expect(presentation.availablePrimaryAction(hasSourceURL: true) == nil)
        }

        let unavailable = try #require(
            ConfirmedImportRecoveryPresentationMapper.presentation(for: .unavailable)
        )
        #expect(unavailable.primaryAction == nil)
        #expect(unavailable.availablePrimaryAction(hasSourceURL: true) == nil)
    }

    @Test func confirmedImportRecoveryCopyIgnoresHostilePayloadsAndRemainsPrivate() throws {
        let hostileText = [
            "/Users/private/Documents/private-statement.csv",
            "private-statement.csv",
            "account-private-123",
            "fingerprint-private-456",
            "SQLITE_BUSY database is locked",
            "raw repository error",
            "identifier-private-789"
        ].joined(separator: " | ")
        let hostileOutcome = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: hostileText,
                transactionCount: 0,
                validationPassed: true,
                persisted: false,
                errorMessage: hostileText,
                recoveryRoute: .prepareAgain(.persistenceContention)
            )
        )
        let neutralOutcome = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "Selected document",
                transactionCount: 0,
                validationPassed: true,
                persisted: false,
                errorMessage: nil,
                recoveryRoute: .prepareAgain(.persistenceContention)
            )
        )

        #expect(hostileOutcome.recoveryPresentation == neutralOutcome.recoveryPresentation)
        #expect(hostileOutcome.message == nil)

        let routes: [ConfirmedImportRecoveryRoute] = [
            .prepareAgain(.sourceSnapshotIntegrityFailed),
            .prepareAgain(.staleProviderGeneration),
            .prepareAgain(.reviewedPartialPlanStale),
            .prepareAgain(.persistenceContention),
            .prepareAgain(.persistenceUnavailable),
            .retryCanonicalReconciliation,
            .retryCanonicalReconciliationThenPrepareAgain,
            .reviewRequired(.validationFailed),
            .reviewRequired(.exactStatementDuplicate),
            .reviewRequired(.transactionEventBlock),
            .reviewRequired(.accountChoiceRequired),
            .reviewRequired(.accountChoiceStale),
            .reviewRequired(.identityAmbiguous),
            .reviewRequired(.identityConflict),
            .reviewRequired(.identifierOwnershipConflict),
            .reviewRequired(.repositoryIntegrityConflict),
            .unavailable
        ]
        let presentedText = routes.compactMap {
            ConfirmedImportRecoveryPresentationMapper.presentation(for: $0)
        }.flatMap {
            [$0.title, $0.explanation, $0.primaryActionLabel, $0.accessibilityText]
                .compactMap { $0 }
        }.joined(separator: " | ")

        for prohibited in [
            "/Users/",
            "private-statement.csv",
            "account-private-123",
            "fingerprint-private-456",
            "SQLITE_BUSY",
            "database is locked",
            "raw repository error",
            "identifier-private-789"
        ] {
            #expect(!presentedText.localizedCaseInsensitiveContains(prohibited))
        }
    }

#if DEBUG
    @Test func developerProfileSettingsCopyIsBoundedAndCurrentHasNoResetAction() {
        let current = DevelopmentDatabaseProfileDescriptor(
            kind: .current,
            displayName: DevelopmentDatabaseProfileKind.current.displayName,
            persistenceClassification: .stableCurrent,
            canReset: false,
            migrationSourceVersion: nil,
            verifiedCurrentSchemaVersion: 9
        )
        let copy = [
            current.displayName,
            current.currentSchemaLabel,
            DeveloperDatabaseProfileOperationState.activationBlocked.message ?? ""
        ].joined(separator: " ")

        #expect(current.resetActionLabel == nil)
        #expect(!copy.contains("/"))
        #expect(!copy.lowercased().contains("sqlite"))
        #expect(!copy.lowercased().contains("uuid"))
        #expect(!copy.lowercased().contains("token"))
    }
#endif
}

private func attempt(
    id: String,
    outcome: ImportAttemptOutcome,
    sessionID: String? = nil
) -> RepositoryImportAttempt {
    RepositoryImportAttempt(
        ImportAttemptDTO(
            id: id,
            workspaceId: "settings-workspace",
            createdAtISO: "2026-07-20T00:00:00Z",
            outcomeCode: outcome.rawValue,
            coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
            accountDecisionCode: ImportAttemptAccountDecision.resolvedOrCreated.rawValue,
            guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
            persistenceCode: ImportAttemptPersistence.committed.rawValue,
            transactionCount: 1,
            importSessionId: sessionID ?? "session-\(id)",
            documentId: "document-\(id)"
        )
    )
}
