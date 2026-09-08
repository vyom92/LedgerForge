#if DEBUG
import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct Sprint58ImportVerificationWorkspaceTests {

    @Test("Failure summaries are typed, deterministic and neutral for hostile values")
    func failureSummariesAreBounded() {
        let cases: [(Error, ImportFailureSummary.Stage, ImportFailureSummary.Family)] = [
            (ImportError.unsupportedFile(extension: "/private/statement.csv"), .sourceReading, .unsupportedInput),
            (ImportError.passwordRequired, .sourceReading, .credentials),
            (ImportError.readerFailure(message: "raw source /private/account-123"), .sourceReading, .sourceRead),
            (ImportError.invalidDocument(message: "SQLite password account-123"), .documentPreparation, .invalidDocument),
            (ImportError.unsupportedStatement(message: "private transaction text"), .documentPreparation, .unsupportedStatement),
            (PersistenceWorkflowError.unavailable, .persistenceAvailability, .persistenceUnavailable),
            (ImportError.cancelled, .cancellation, .cancelled),
            (ImportError.unknown(message: "raw SQL /private/secret.sqlite"), .unavailable, .unknown)
        ]

        for (error, stage, family) in cases {
            let summary = ImportFailureSummary.from(error)
            #expect(summary.stage == stage)
            #expect(summary.family == family)
            #expect(summary.displayText == ImportFailureSummary.from(error).displayText)
            #expect(summary.displayText.contains(summary.explanation))
            #expect(summary.displayText.contains(summary.guidance))
            for prohibited in ["/private/", "account-123", "SQLite", "transaction text", "secret.sqlite"] {
                #expect(!summary.displayText.localizedCaseInsensitiveContains(prohibited))
            }
        }
    }
}

#endif
