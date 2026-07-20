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
}

private func attempt(id: String, outcome: ImportAttemptOutcome) -> RepositoryImportAttempt {
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
            importSessionId: "session-\(id)",
            documentId: "document-\(id)"
        )
    )
}
