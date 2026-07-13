import Testing
@testable import LedgerForge

@Suite("ImportSessionStore", .serialized)
@MainActor
struct ImportSessionStoreTests {

    @Test func replacesBoundedHydratedSessionState() {
        let store = ImportSessionStore()
        let session = RepositoryImportSession(
            id: "session-store",
            workspaceId: "workspace-store",
            sourceDocumentName: "statement.csv",
            startedAtISO: "2026-07-13T00:00:00Z",
            completedAtISO: nil,
            validationStatus: "passed",
            parserVersion: "Axis"
        )

        store.replaceImportSessions([session])

        #expect(store.importSessions == [session])
    }
}
