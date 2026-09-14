import CryptoKit
import Darwin
import Foundation

nonisolated enum BackupError: Error, LocalizedError, Equatable {
    case incompatible, damaged, excludedPayload, invalidStructure, unavailableCurrent
    case activeWork, candidateChanged, publication, durability, cleanup, recoveryUnavailable
    case activationRolledBack

    var errorDescription: String? {
        switch self {
        case .incompatible: "This backup is not compatible with this version of LedgerForge."
        case .damaged, .invalidStructure: "This backup is incomplete or damaged. Choose another verified backup."
        case .excludedPayload: "The ledger contains an unclassified attachment. Backup needs a content decision before continuing."
        case .unavailableCurrent: "Open Current Database before creating a backup. Restore remains available."
        case .activeWork: "Finish or cancel active imports, saves and unsaved edits before restoring."
        case .candidateChanged: "The database or selected candidate changed. Select and verify the backup again."
        case .publication: "The backup could not be published. Check the destination and try again."
        case .durability: "The recovery files could not be saved reliably. Keep them and try a local destination."
        case .cleanup: "Recovery completed, but temporary-file cleanup is pending."
        case .recoveryUnavailable: "The ledger is unavailable. Recovery files have been retained. Choose a verified backup to recover."
        case .activationRolledBack: "Restore failed. Your previous ledger was recovered and is current."
        }
    }
}

nonisolated struct BackupManifest: Codable, Equatable, Sendable {
    struct Application: Codable, Equatable, Sendable {
        let identifier: String?
        let version: String?
        let build: String?
    }
    struct MigrationIdentity: Codable, Equatable, Sendable {
        let version: Int
        let name: String
        let checksum: String
    }
    struct Payload: Codable, Equatable, Sendable {
        let file: String
        let byteSize: Int64
        let sha256: String
    }
    let formatVersion: Int
    let backupID: UUID
    let createdAt: String
    let application: Application
    let database: Payload
    let schemaVersion: Int
    let migrations: [MigrationIdentity]
    let contents: String
    let exclusions: [String]

    static let contentDescription = "Complete durable ledger, including stored provenance and import/validation records."
    static let excluded = ["external_statement_files", "credentials_and_keychain", "runtime_diagnostic_logs",
                           "appearance_window_profile_preferences", "private_screenshots", "development_artifacts"]

    func validate() throws {
        guard formatVersion == 1, schemaVersion == BackupCompatibility.supportedSchemaVersion,
              migrations == BackupCompatibility.migrationIdentities else { throw BackupError.incompatible }
        guard database.file == "ledger.sqlite", database.byteSize > 0,
              database.sha256.count == 64, database.sha256.allSatisfy({ "0123456789abcdef".contains($0) }),
              ISO8601DateFormatter().date(from: createdAt) != nil,
              contents == Self.contentDescription, exclusions == Self.excluded else { throw BackupError.damaged }
    }
}

/// This is the one backup compatibility policy. A future schema requires an
/// explicit policy decision here; the migration registry alone does not grant it.
nonisolated enum BackupCompatibility {
    static let supportedSchemaVersion = 17
    static var migrationIdentities: [BackupManifest.MigrationIdentity] {
        allMigrations.map { .init(version: $0.version, name: $0.name, checksum: $0.checksum) }
    }
    struct SchemaObject: Equatable, Sendable {
        let kind: String?
        let name: String?
        let table: String?
        let sql: String?
    }
    private static let expectedInventory: Result<[SchemaObject], Error> = Result {
        guard allMigrations.last?.version == supportedSchemaVersion else { throw BackupError.incompatible }
        // Empty, source-independent schema authority; no financial fixture/data.
        let schema = SQLiteDatabase(path: ":memory:")
        try schema.open()
        defer { schema.close() }
        try schema.runMigrations(allMigrations)
        let inventory = try schemaInventory(schema)
        try schema.closeChecked()
        return inventory
    }
    static func schemaInventory(_ db: SQLiteDatabase) throws -> [SchemaObject] {
        try db.query(sql: "SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name;") {
            SchemaObject(kind: $0.string(at: 0), name: $0.string(at: 1), table: $0.string(at: 2), sql: $0.string(at: 3))
        }
    }
    static func checkContents(_ db: SQLiteDatabase) throws {
        // The accepted current schema has one BLOB owner. Unknown/nonempty
        // attachments require an owner content decision, never row deletion.
        guard try db.queryInt("SELECT count(*) FROM attachments WHERE blob IS NOT NULL AND length(blob) > 0;") == 0 else {
            throw BackupError.excludedPayload
        }
    }
    static func verifyDatabase(_ db: SQLiteDatabase) throws {
        guard allMigrations.last?.version == supportedSchemaVersion else { throw BackupError.incompatible }
        do { _ = try db.validatedMigrationHistory(against: allMigrations, requiresCompleteChain: true) }
        catch { throw BackupError.incompatible }
        guard try schemaInventory(db) == expectedInventory.get() else { throw BackupError.incompatible }
        let integrity = try db.query(sql: "PRAGMA integrity_check;") { $0.string(at: 0) }
        guard integrity == ["ok"], try db.query(sql: "PRAGMA foreign_key_check;", map: { _ in true }).isEmpty else {
            throw BackupError.damaged
        }
        try checkContents(db)
    }
}

/// Filesystem work is synchronous on a worker executor. It handles only explicit
/// operation-owned paths, never copies external paths referenced by ledger rows.
nonisolated enum BackupFiles {
    static let members: Set<String> = ["ledger.sqlite", "manifest.json"]

    static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0 || errno != ENOENT
    }
    static func reserveFile(_ url: URL) throws {
        let fd = Darwin.open(url.path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw BackupError.publication }
        guard Darwin.close(fd) == 0 else { throw BackupError.durability }
    }

    static func regularFile(_ url: URL) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { throw BackupError.invalidStructure }
    }
    static func directory(_ url: URL) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR else { throw BackupError.invalidStructure }
    }
    static func validatePackage(_ url: URL) throws {
        try directory(url)
        let names = try FileManager.default.contentsOfDirectory(atPath: url.path)
        guard Set(names) == members else { throw BackupError.invalidStructure }
        for member in members { try regularFile(url.appendingPathComponent(member)) }
    }
    static func rejectGitDestination(_ url: URL) throws {
        var current = url.resolvingSymlinksInPath()
        while current.path != "/" {
            guard !FileManager.default.fileExists(atPath: current.appendingPathComponent(".git").path) else { throw BackupError.publication }
            current.deleteLastPathComponent()
        }
    }
    static func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        try directory(url)
    }
    static func sync(_ url: URL, directory: Bool = false) throws {
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | (directory ? O_DIRECTORY : 0))
        guard fd >= 0 else { throw BackupError.durability }
        defer { Darwin.close(fd) }
        guard fsync(fd) == 0 else { throw BackupError.durability }
        if !directory, fcntl(fd, F_FULLFSYNC) != 0 { throw BackupError.durability }
    }
    static func moveWithoutOverwrite(_ source: URL, _ destination: URL) throws {
        guard renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) == 0 else { throw BackupError.publication }
        try sync(source.deletingLastPathComponent(), directory: true)
        if source.deletingLastPathComponent() != destination.deletingLastPathComponent() {
            try sync(destination.deletingLastPathComponent(), directory: true)
        }
    }
    static func writeRecord<T: Encodable>(_ record: T, to url: URL) throws {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".receipt-\(UUID().uuidString).tmp")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(record).write(to: temporary, options: .withoutOverwriting)
        do {
            try sync(temporary)
            guard rename(temporary.path, url.path) == 0 else { throw BackupError.durability }
            try sync(url.deletingLastPathComponent(), directory: true)
        } catch {
            // A failed directory flush is ambiguous: the caller must retain all
            // recovery assets and resolve the durable decision at startup.
            throw error
        }
    }
    static func hash(_ url: URL) throws -> (size: Int64, sha256: String) {
        try regularFile(url)
        let file = try FileHandle(forReadingFrom: url)
        var digest = SHA256(); var size: Int64 = 0
        do {
            while let data = try file.read(upToCount: 1_048_576), !data.isEmpty {
                try Task.checkCancellation(); digest.update(data: data); size += Int64(data.count)
            }
            try file.close()
        } catch { try? file.close(); throw error }
        return (size, digest.finalize().map { String(format: "%02x", $0) }.joined())
    }
    static func copyPackage(_ source: URL, to destination: URL) throws {
        try validatePackage(source)
        try createDirectory(destination)
        for member in members.sorted() {
            try Task.checkCancellation()
            let origin = source.appendingPathComponent(member)
            try regularFile(origin)
            try FileManager.default.copyItem(at: origin, to: destination.appendingPathComponent(member))
            try regularFile(destination.appendingPathComponent(member))
        }
        try validatePackage(destination)
    }
    static func verifyPackage(_ url: URL) throws -> BackupManifest {
        try validatePackage(url)
        let manifestURL = url.appendingPathComponent("manifest.json")
        let metadata = try manifestURL.resourceValues(forKeys: [.fileSizeKey])
        guard let size = metadata.fileSize, size <= 65_536 else { throw BackupError.damaged }
        let manifest: BackupManifest
        do { manifest = try JSONDecoder().decode(BackupManifest.self, from: Data(contentsOf: manifestURL)) }
        catch { throw BackupError.damaged }
        try manifest.validate()
        let databaseURL = url.appendingPathComponent("ledger.sqlite")
        let payload = try hash(databaseURL)
        guard payload.size == manifest.database.byteSize, payload.sha256 == manifest.database.sha256 else { throw BackupError.damaged }
        let db = SQLiteDatabase(path: databaseURL.path)
        try db.open(access: .readOnlySnapshot)
        do { try BackupCompatibility.verifyDatabase(db); try db.closeChecked() }
        catch { try? db.closeChecked(); throw error }
        return manifest
    }
    static func flushPackage(_ url: URL) throws {
        for name in members { try sync(url.appendingPathComponent(name)) }
        try sync(url, directory: true)
    }
}
