#if DEBUG
import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct Sprint58ImportVerificationWorkspaceTests {

    @Test("Catalog IDs and order are stable and unique")
    func catalogIsDeterministic() {
        let fixtures = DebugImportFixtureCatalog.all

        #expect(fixtures.map(\.id) == [.axisNRESourceDerived, .axisNROSourceFaithful])
        #expect(Set(fixtures.map(\.id)).count == fixtures.count)
        #expect(fixtures.map(\.title) == [
            "Axis NRE bank-account CSV",
            "Axis NRO bank-account CSV"
        ])
    }

    @Test("Every listed fixture resolves only through its explicit approved resource")
    func approvedResourcesResolve() throws {
        for fixture in DebugImportFixtureCatalog.all {
            let url = try DebugImportFixtureCatalog.resolve(fixture) { resourceName in
                FixtureLocator.axisCSV(resourceName)
            }

            #expect(FixtureLocator.fileExists(at: url))
            #expect(url.lastPathComponent == fixture.resourceName)
        }
    }

    @Test("Missing resource returns a typed privacy-safe failure")
    func missingResourceFailsClosed() {
        let fixture = DebugImportFixtureCatalog.all[0]

        #expect(throws: DebugImportFixtureCatalogError.missingApprovedResource) {
            try DebugImportFixtureCatalog.resolve(fixture) { _ in nil }
        }

        let message = DebugImportFixtureCatalogError.missingApprovedResource.localizedDescription
        #expect(message == "The selected approved fixture is unavailable. No import was started.")
        #expect(!message.contains(fixture.resourceName))
        #expect(!message.contains("/"))
    }

    @Test("Catalog presentation is bounded and does not expose paths or source fragments")
    func catalogPresentationIsPrivacySafe() {
        let fixtures = DebugImportFixtureCatalog.all
        let presentation = fixtures
            .map(\.provenanceSummary)
            .joined(separator: "|")

        for fixture in fixtures {
            #expect(fixture.provenanceSummary.contains(fixture.institution))
            #expect(fixture.provenanceSummary.contains(fixture.documentFamily))
            #expect(fixture.provenanceSummary.contains(fixture.format))
            #expect(fixture.provenanceSummary.contains(fixture.sanitization))
        }

        #expect(!presentation.contains("/"))
        #expect(!presentation.contains("Statement of Account No"))
        #expect(!presentation.contains("UPI/"))
        #expect(!presentation.contains("password"))
        #expect(!presentation.contains("account number"))
    }

    @Test("Launcher calls the URL-driven preparation seam and does not confirm")
    func launcherUsesProductionPreparationSeam() async throws {
        let expectedURL = URL(fileURLWithPath: "/tmp/approved-fixture.csv")
        var capturedURL: URL?
        let launcher = DebugImportFixtureLauncher(
            resourceResolver: { _ in expectedURL },
            prepare: { url, _, _ in
                capturedURL = url
                throw LauncherProbeError.reachedPreparationSeam
            }
        )

        do {
            _ = try await launcher.prepare(DebugImportFixtureCatalog.all[0], requestID: UUID())
            Issue.record("Expected the preparation seam probe to stop before confirmation.")
        } catch let error as LauncherProbeError {
            #expect(error == .reachedPreparationSeam)
        }

        #expect(capturedURL == expectedURL)
    }

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

private enum LauncherProbeError: Error, Equatable {
    case reachedPreparationSeam
}
#endif
