import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct StartupDiagnosticTests {
    @Test func mismatchCarriesExactConditionWithoutUntrustedStoredText() {
        let hostile = "A private account label\nforged event"
        let root = RuntimeDiagnostic.failure(SQLiteRepositoryProviderError.migrationIntegrityFailed(.persistedNameMismatch(17, expected: migrationV17.name, observed: hostile)), operation: "startup", stage: "provider initialization")
        #expect(root.code == "migration.persisted_name_mismatch")
        #expect(root.metadata["migration_version"] == "17")
        #expect(root.metadata["expected_name"] == migrationV17.name)
        #expect(root.metadata["observed_name_sha256"]?.count == 64)
        #expect(!root.metadata.values.contains(hostile))
        #expect(root.metadata["retry_eligible"] == "false")
        let dependent = RuntimeDiagnostic.failure(RepositoryStoreHydrationError.persistenceUnavailable, operation: "startup hydration", stage: "provider availability", relatedRoot: root)
        #expect(dependent.metadata["related_root_reference"] == root.reference)
        #expect(dependent.code == "hydration.provider_unavailable")
        #expect(dependent.nextAction == root.nextAction)
        #expect(dependent.metadata["hydration_stage"] == "provider availability")
    }

    @Test func copiedAndVisibleMetadataUseTheSameBoundedProjection() {
        let console = DeveloperConsole()
        console.error(.database, "Failure\nforged", metadata: ["operation": "Innocuous private label", "stage": "/Users/private", "file": "private.pdf", "root_reference": "fake", "sqlite_primary": "5", "expected_name": "private name"])
        let entry = console.entries[0]
        let copied = console.completeLogText
        #expect(copied.contains("UTC"))
        #expect(copied.contains("#1"))
        #expect(copied.contains(DeveloperConsole.metadataText(for: entry)!))
        for forbidden in ["Innocuous private label", "/Users/private", "private.pdf", "forged", "private name"] { #expect(!copied.contains(forbidden)) }
        #expect(entry.metadata?["sqlite_primary"] == "5")
        for _ in 0..<1100 { console.info(.application, "Bounded event") }
        #expect(console.entries.count == 1000)
        #expect(console.entries.first?.sequence == 102)
        console.clear(); console.info(.application, "New event")
        #expect(console.entries[0].sequence == 1102)
    }

    @Test func sqliteWrapperRetainsSafeCodesAndUnknownErrorsRemainUnknown() {
        let cause = SQLiteExecutionError(primaryCode: 5, extendedCode: 5, operation: .open)
        let failure = RuntimeDiagnostic.failure(SQLiteRepositoryProviderError.databaseOpenFailed(cause), operation: "startup", stage: "provider initialization")
        #expect(failure.metadata["sqlite_primary"] == "5")
        #expect(failure.metadata["cause"] == "SQLiteExecutionError")
        struct Unknown: Error {}
        let unknown = RuntimeDiagnostic.failure(Unknown(), operation: "plan save", stage: "repository transaction")
        #expect(unknown.code == "operation.unknown")
        #expect(unknown.metadata["effect"] == "durable outcome not established")
    }

    @Test func memoryOrIncompleteStartupCanNeverPassDurableAcceptance() {
        #expect(DurableStartupEvidence.accepts(persistence: .verifiedSQLite, hydrated: true, environment: [:]))
        #expect(!DurableStartupEvidence.accepts(persistence: .verifiedSQLite, hydrated: false, environment: [:]))
        #expect(!DurableStartupEvidence.accepts(persistence: .intentionalNonDurable(.debugMemory), hydrated: true, environment: [:]))
        for marker in ["LEDGERFORGE_RUN_HOST", "LEDGERFORGE_TEST_HOST", "LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE"] {
            #expect(!DurableStartupEvidence.accepts(persistence: .verifiedSQLite, hydrated: true, environment: [marker: "0"]))
        }
    }

    @Test func actualBundleBuildIdentityIsCapturedAndUnavailableStaysUnavailable() {
        let actual = BuildIdentity.read()
        #expect(actual.configuration == "Debug")
        #expect(actual.revision.count == 40)
        #expect(["clean", "dirty"].contains(actual.worktree))
        #expect(BuildIdentity.read(bundle: Bundle(for: NSObject.self)) == .unavailable)
    }

    @Test func unavailableAndRetainedStatesCannotAuthorizeMutation() {
        for state in [ApplicationDataState.loading, .unavailable, .retainedNonCurrent] { #expect(!state.permitsMutation) }
        #expect(ApplicationDataState.empty.permitsMutation)
        #expect(ApplicationDataState.current.permitsMutation)
    }
}
