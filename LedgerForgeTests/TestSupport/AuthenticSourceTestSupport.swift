import Foundation
import Darwin
import Testing
@testable import LedgerForge

/// Explicit authentic-source and populated-ledger integration prerequisites.
/// Ordinary mechanics use MechanicsTestSupport instead.
enum AuthenticSourceTestSupport {
    /// Explicit integration nominations may use a regular file or the retained
    /// FIFO transport. Neither transport is a routine test prerequisite.
    static func ramNomination(_ environmentKey: String) throws -> Data {
        let path = try #require(ProcessInfo.processInfo.environment[environmentKey])
        var metadata = stat()
        try #require(lstat(path, &metadata) == 0 && [S_IFIFO, S_IFREG].contains(metadata.st_mode & S_IFMT))
        let input = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? input.close() }
        let data = try #require(try input.readToEnd())
        try #require(data.count < 1_000_000)
        return data
    }

    /// An explicitly nominated, already populated isolated qualification ledger
    /// can supply presentation regressions without opening ordinary Current.
    /// It is read-only below and must not resolve to the Current database.
    @MainActor
    static func presentationDatabaseURL() throws -> URL {
        let path = try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_PRESENTATION_DATABASE"],
            "Select an isolated presentation database explicitly for integration qualification.")
        let selected = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
        let current = try DevelopmentDatabaseIdentity.applicationOwned(environment: [:]).canonicalDevelopmentURL
            .resolvingSymlinksInPath().standardizedFileURL
        guard selected != current, FileManager.default.fileExists(atPath: selected.path) else {
            throw RepositoryError.persistenceUnavailable
        }
        return selected
    }

    /// Presentation checks read the nominated schema without attempting
    /// a candidate migration. Its complete registered prefix is verified first;
    /// both connections enforce read-only access before any repository exists.
    @MainActor
    static func readOnlyRegisteredProvider(at url: URL) throws -> SQLiteRepositoryProvider {
        let database = SQLiteDatabase(path: url.path)
        try database.open(access: .readOnlySnapshot)
        defer { database.close() }
        let history = try database.validatedMigrationHistory(against: allMigrations, requiresCompleteChain: false)
        guard !history.isEmpty else { throw RepositoryError.persistenceUnavailable }
        return try SQLiteRepositoryProvider(path: url.path,
            migrations: Array(allMigrations.prefix(history.count)), access: .readOnlySnapshot)
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
