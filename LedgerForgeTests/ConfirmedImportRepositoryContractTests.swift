import Testing
import SQLite3
@testable import LedgerForge

struct ConfirmedImportRepositoryContractTests {
    @Test func sqliteBusyAndLockedErrorsAreRecognizedWithoutDiagnosticLeakage() {
        let busy = SQLiteExecutionError(primaryCode: SQLITE_BUSY, extendedCode: SQLITE_BUSY, operation: .transaction)
        let locked = SQLiteExecutionError(primaryCode: SQLITE_LOCKED, extendedCode: SQLITE_LOCKED, operation: .statement)

        #expect(busy.isRetryableContention)
        #expect(locked.isRetryableContention)
        #expect(!busy.description.contains("SELECT"))
    }

    @Test func sqliteUniqueConstraintIsRecognizedWithoutSQLInDescription() {
        let error = SQLiteExecutionError(
            primaryCode: SQLITE_CONSTRAINT,
            extendedCode: 2067,
            operation: .statement
        )

        #expect(error.isUniqueConstraint)
        #expect(!error.description.contains("identifier"))
        #expect(!error.description.contains("SELECT"))
    }

    @Test func confirmedImportResultsUsePrivacySafeDescriptions() {
        let results: [ConfirmedImportRepositoryResult] = [
            .exactDuplicate,
            .identifierOwnershipConflict,
            .retryableContention,
            .persistenceUnavailable
        ]

        for result in results {
            #expect(!result.description.lowercased().contains("sql"))
            #expect(!result.description.lowercased().contains("fingerprint"))
            #expect(!result.description.lowercased().contains("identifier"))
        }
    }
}
