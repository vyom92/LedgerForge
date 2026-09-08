import Foundation
import Testing
@testable import LedgerForge

/// An authentic carrier for source-snapshot and orchestration boundary tests.
/// Financial source support is established by the separate complete-corpus
/// oracle campaigns, never by these single-carrier transport checks.
enum AuthenticSourceTestSupport {
    @MainActor
    struct PreparedImportOwner {
        let preparedImport: PreparedImport
        private let engine: ImportEngine

        fileprivate init(preparedImport: PreparedImport, engine: ImportEngine) {
            self.preparedImport = preparedImport
            self.engine = engine
        }

        func cancel() {
            engine.cancelPreparedImport(preparedImport)
        }
    }

    /// Full ordinary preparation of a registered source for transport and UI
    /// mechanics. The returned owner must remain alive through use and receive
    /// `cancel()` on scope exit. No financial fields, source bytes, or validation
    /// are authored.
    @MainActor
    static func preparedAxisBankCSV(
        providerGeneration: ProviderGenerationToken? = nil,
        alternatePeriod: Bool = false
    ) async throws -> PreparedImportOwner {
        let resolvedGeneration = providerGeneration ?? DatabaseProvider.shared.generationToken
        let provider = DatabaseProvider(inMemory: true)
        let engine = ImportEngine(
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { resolvedGeneration }
        )
        let preparedImport = try await engine.prepareImport(from: axisBankCSV(alternatePeriod: alternatePeriod))
        return PreparedImportOwner(preparedImport: preparedImport, engine: engine)
    }

    static func axisBankCSV(alternatePeriod: Bool = false) throws -> URL {
        let root = try #require(
            ProcessInfo.processInfo.environment["LEDGERFORGE_PRIVATE_ORIGINALS_DIRECTORY"],
            "Authentic-source tests require LEDGERFORGE_PRIVATE_ORIGINALS_DIRECTORY; missing corpus is not a passing test."
        )
        let url = URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent(alternatePeriod
                ? "Axis/Bank Accounts/Axis NRE FY26-27.csv"
                : "Axis/Bank Accounts/Axis NRE FY25-26.csv")
        try #require(FileManager.default.fileExists(atPath: url.path), "Required authentic Axis CSV is missing.")
        return url
    }
}
