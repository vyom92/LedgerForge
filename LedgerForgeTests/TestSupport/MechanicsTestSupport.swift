import Foundation
@testable import LedgerForge

/// Small synthetic input for repository, snapshot and lifecycle mechanics.
/// These invented values are not an institution-source acceptance oracle.
/// Every preparation still traverses the real reader, parser, validator and mapper;
/// mutable preparations/snapshots are never shared between tests.
@MainActor
enum MechanicsTestSupport {
    private static let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForge-MechanicsFixtures-\(UUID().uuidString)", isDirectory: true)

    static func axisBankCSV(alternatePeriod: Bool = false) throws -> URL {
        let month = alternatePeriod ? "02" : "01"
        let end = alternatePeriod ? "28" : "31"
        let text = """
        AXIS BANK
        Synthetic mechanics fixture
        Statement of Account No - 990000000000001 for the period (From : 01-\(month)-2026 To : \(end)-\(month)-2026)
        Currency :- INR
        Tran Date,CHQNO,PARTICULARS,DR,CR,BAL,SOL
        05-\(month)-2026,1001,Test income,1000.00,,2000.00,001
        06-\(month)-2026,1002,Test groceries,,25.00,1975.00,001
        07-\(month)-2026,1003,Test utilities,,75.00,1900.00,001
        08-\(month)-2026,1004,Test refund,10.00,,1910.00,001

        """
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("mechanics-\(month).csv")
        let expectedBytes = Data(text.utf8)
        if FileManager.default.fileExists(atPath: url.path) {
            guard try Data(contentsOf: url) == expectedBytes else {
                throw CocoaError(.fileReadCorruptFile)
            }
        } else {
            try expectedBytes.write(to: url, options: .atomic)
        }
        return url
    }

    @MainActor
    struct PreparedImportOwner {
        let preparedImport: PreparedImport
        private let engine: ImportEngine

        fileprivate init(preparedImport: PreparedImport, engine: ImportEngine) {
            self.preparedImport = preparedImport
            self.engine = engine
        }

        func cancel() { engine.cancelPreparedImport(preparedImport) }
    }

    static func preparedAxisBankCSV(
        providerGeneration: ProviderGenerationToken? = nil,
        alternatePeriod: Bool = false
    ) async throws -> PreparedImportOwner {
        let generation = providerGeneration ?? DatabaseProvider.shared.generationToken
        let provider = DatabaseProvider(inMemory: true)
        let engine = ImportEngine(
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { generation }
        )
        let prepared = try await engine.prepareImport(from: axisBankCSV(alternatePeriod: alternatePeriod))
        return PreparedImportOwner(preparedImport: prepared, engine: engine)
    }
}
