import Foundation

/// A receipt for one restoration, not permanent ledger identity. Every location
/// is derived from a canonical target and UUID, never an arbitrary decoded path.
nonisolated struct RestoreOperation: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable { case preserving, preserved, activated, relaunchConfirmed, rolledBack }
    let version: Int
    let operationID: UUID
    let backupID: UUID
    let payloadSHA256: String
    let currentFile: String
    let priorFiles: [String]
    let priorWasUsable: Bool
    var phase: Phase

    func validate(for layout: RestoreLayout) throws {
        guard version == 1, currentFile == layout.current.lastPathComponent,
              Set(priorFiles).count == priorFiles.count,
              Set(priorFiles).isSubset(of: Set(layout.databaseNames)),
              payloadSHA256.count == 64, payloadSHA256.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw BackupError.recoveryUnavailable
        }
    }
}

nonisolated struct RestoreLayout: Sendable {
    let current: URL
    var parent: URL { current.deletingLastPathComponent() }
    var root: URL { parent.appendingPathComponent(".ledgerforge-recovery", isDirectory: true) }
    var receipt: URL { parent.appendingPathComponent("restore-operation.json") }
    var databaseNames: [String] { [current.lastPathComponent, current.lastPathComponent + "-wal", current.lastPathComponent + "-shm"] }
    func operation(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    func package(_ id: UUID) -> URL { operation(id).appendingPathComponent("candidate.ledgerforgebackup", isDirectory: true) }
    func previous(_ id: UUID) -> URL { operation(id).appendingPathComponent("previous", isDirectory: true) }

    func permitsExplicitCreation() throws -> Bool {
        guard !databaseNames.contains(where: { BackupFiles.exists(parent.appendingPathComponent($0)) }),
              !BackupFiles.exists(receipt) else { return false }
        if BackupFiles.exists(parent) { try BackupFiles.directory(parent) }
        if BackupFiles.exists(root) {
            try BackupFiles.directory(root)
            guard try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty else { return false }
        }
        return true
    }

    func validateOwnership() throws {
        // Canonical app support may contain symlinked user ancestors; the owned
        // database parent and recovery locations themselves must be real dirs.
        try BackupFiles.directory(parent)
        if FileManager.default.fileExists(atPath: root.path) { try BackupFiles.directory(root) }
    }
    func createOperation(_ id: UUID) throws {
        // Recovery on a new/lost installation needs staging directories, but
        // this never creates the canonical SQLite file.
        if !BackupFiles.exists(parent) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try BackupFiles.sync(parent.deletingLastPathComponent(), directory: true)
        }
        try validateOwnership()
        if !FileManager.default.fileExists(atPath: root.path) {
            try BackupFiles.createDirectory(root)
            try BackupFiles.sync(parent, directory: true)
        }
        try BackupFiles.createDirectory(operation(id))
        try BackupFiles.sync(root, directory: true)
    }
    func readReceipt() throws -> RestoreOperation? {
        guard FileManager.default.fileExists(atPath: receipt.path) else { return nil }
        try BackupFiles.regularFile(receipt)
        let data = try Data(contentsOf: receipt)
        guard data.count <= 65_536 else { throw BackupError.recoveryUnavailable }
        let result = try JSONDecoder().decode(RestoreOperation.self, from: data)
        try result.validate(for: self)
        return result
    }
    func validateOperation(_ id: UUID) throws {
        try validateOwnership()
        try BackupFiles.directory(operation(id))
    }
    /// Keep an earlier unresolved receipt with its original recovery assets.
    /// This is a single operation's recovery asset, not a backup-history store.
    func retainOutstandingReceipt() throws {
        guard let previousRecord = try readReceipt() else { return }
        let previousDirectory = operation(previousRecord.operationID)
        if !FileManager.default.fileExists(atPath: previousDirectory.path), previousRecord.phase == .relaunchConfirmed {
            return
        }
        try validateOperation(previousRecord.operationID)
        let retained = previousDirectory.appendingPathComponent("retained-operation.json")
        let original = try Data(contentsOf: receipt)
        if FileManager.default.fileExists(atPath: retained.path) {
            try BackupFiles.regularFile(retained)
            guard try Data(contentsOf: retained) == original else { throw BackupError.recoveryUnavailable }
        } else { try original.write(to: retained, options: .withoutOverwriting) }
        try BackupFiles.sync(retained)
        try BackupFiles.sync(previousDirectory, directory: true)
    }
    func write(_ record: RestoreOperation) throws {
        try record.validate(for: self)
        try BackupFiles.writeRecord(record, to: receipt)
    }
    func existingFiles() throws -> [String] {
        try databaseNames.filter { name in
            let url = parent.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { return false }
            try BackupFiles.regularFile(url)
            return true
        }
    }
    func preserve(_ record: RestoreOperation) throws -> RestoreOperation {
        try record.validate(for: self)
        try validateOperation(record.operationID)
        let old = previous(record.operationID)
        if !FileManager.default.fileExists(atPath: old.path) { try BackupFiles.createDirectory(old) }
        try BackupFiles.directory(old)
        // With phase preserving, candidate placement has not started. This
        // completes an interrupted per-member move before any rollback copy.
        for name in record.priorFiles {
            let from = parent.appendingPathComponent(name)
            let to = old.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: to.path) {
                try BackupFiles.regularFile(to)
                guard !FileManager.default.fileExists(atPath: from.path) else { throw BackupError.recoveryUnavailable }
            } else {
                try BackupFiles.regularFile(from)
                try BackupFiles.moveWithoutOverwrite(from, to)
            }
        }
        for name in record.priorFiles { try BackupFiles.sync(old.appendingPathComponent(name)) }
        try BackupFiles.sync(old, directory: true)
        var preserved = record; preserved.phase = .preserved
        try write(preserved)
        return preserved
    }
    func restorePrevious(_ record: RestoreOperation) throws -> RestoreOperation {
        try record.validate(for: self)
        try validateOperation(record.operationID)
        let preserved = record.phase == .preserving ? try preserve(record) : record
        guard preserved.phase == .preserved, preserved.priorWasUsable,
              preserved.priorFiles.contains(current.lastPathComponent) else { throw BackupError.recoveryUnavailable }
        let old = previous(record.operationID)
        try BackupFiles.directory(old)
        for name in preserved.priorFiles { try BackupFiles.regularFile(old.appendingPathComponent(name)) }
        // The entire previous set remains untouched. Repeating this after an
        // interruption is safe; no database is opened until all members land.
        for name in try existingFiles() { try FileManager.default.removeItem(at: parent.appendingPathComponent(name)) }
        for name in preserved.priorFiles {
            let target = parent.appendingPathComponent(name)
            try FileManager.default.copyItem(at: old.appendingPathComponent(name), to: target)
            try BackupFiles.regularFile(target)
            try BackupFiles.sync(target)
        }
        try BackupFiles.sync(parent, directory: true)
        return preserved
    }
    func removeOperation(_ id: UUID) throws {
        try validateOwnership()
        let directory = operation(id)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try BackupFiles.directory(directory)
        try FileManager.default.removeItem(at: directory)
        try BackupFiles.sync(root, directory: true)
    }

    func hasRetainedOperations(excluding id: UUID) throws -> Bool {
        guard FileManager.default.fileExists(atPath: root.path) else { return false }
        try BackupFiles.directory(root)
        return try FileManager.default.contentsOfDirectory(atPath: root.path).contains {
            $0 != id.uuidString && UUID(uuidString: $0) != nil
        }
    }
}
