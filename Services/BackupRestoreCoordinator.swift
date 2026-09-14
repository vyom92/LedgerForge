import Combine
import Foundation
#if DEBUG
import AppKit
import Darwin
#endif

@MainActor
final class BackupRestoreCoordinator: ObservableObject {
    static let shared = BackupRestoreCoordinator()
    @Published private(set) var message = "Create a verified copy of Current Database, or restore a saved backup."
    @Published private(set) var isBusy = false
    @Published private(set) var canCancel = false
    @Published private(set) var isReplacing = false
    @Published private(set) var candidateManifest: BackupManifest?
    @Published private(set) var lastBackupURL: URL?
    @Published private(set) var restoredReceipt: RestoreOperation?
    @Published private(set) var canCreateNewLedger = false
    private var candidateID: UUID?
    private var verifiedGeneration: ProviderGenerationToken?
    private var targetChangeCounter: Int64?
    private var needsRelaunchConfirmation = false
    private(set) var ownsStartupGate = false
    private var task: Task<Void, Never>?
    private(set) var layout: RestoreLayout?

#if DEBUG
    enum FailurePoint: Hashable { case afterPreservation, candidateOpen, hydration, activationRecord, rollbackOpen, interruptBeforeCommit, interruptAfterCommit }
    var failuresForTesting: Set<FailurePoint> = []
    private var testProvider: SQLiteRepositoryProvider?
    private var isIsolatedTest = false
    private var exitsOnInterruptionForTesting = false
    private var didRunProcessProbe = false
    init(testingAt url: URL) { layout = RestoreLayout(current: url); isIsolatedTest = true }
    func installTestProvider(_ provider: SQLiteRepositoryProvider) { testProvider = provider }

    /// Bounded executable drill, compiled out of Release. It can run only on
    /// the existing DEBUG namespace mechanism with an operation-owned source.
    /// Ordinary Current Database cannot satisfy these guards.
    func runProcessProbeIfRequested() async {
        let environment = ProcessInfo.processInfo.environment
        guard !didRunProcessProbe, let mode = environment["LEDGERFORGE_S93_RECOVERY_PROBE"],
              let namespace = environment[DevelopmentDatabaseIdentity.namespaceEnvironmentKey],
              namespace.hasPrefix("s93-recovery-"), let layout,
              layout.parent.lastPathComponent == namespace,
              layout.parent.deletingLastPathComponent().lastPathComponent == "Namespaces" else { return }
        didRunProcessProbe = true
        switch mode {
        case "before-commit": failuresForTesting = [.interruptBeforeCommit]; exitsOnInterruptionForTesting = true
        case "after-commit": failuresForTesting = [.interruptAfterCommit]; exitsOnInterruptionForTesting = true
        case "rollback": failuresForTesting = [.afterPreservation]
        case "candidate-open": failuresForTesting = [.candidateOpen]
        case "hydration": failuresForTesting = [.hydration]
        case "activation-record": failuresForTesting = [.activationRecord]
        case "rollback-unavailable": failuresForTesting = [.afterPreservation, .rollbackOpen]
        case "restore", "reopen": failuresForTesting = []
        default: return
        }
        if mode != "reopen" {
            await verifyRestore(from: layout.parent.appendingPathComponent("input.ledgerforgebackup"))
            if candidateID != nil { await replaceLedger() }
        }
        // Each explicitly requested fault is one-shot. The ordinary recovery
        // controls remain usable afterwards in this isolated process.
        failuresForTesting = []
        let receipt = try? layout.readReceipt()
        let result: [String: String] = ["mode": mode, "phase": receipt?.phase.rawValue ?? "none",
            "hydration": ApplicationAvailability.shared.permitsMutation ? "current" : "unavailable",
            "canonical": "isolated-current", "operation": receipt?.operationID.uuidString ?? "none"]
        if let bytes = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), let text = String(data: bytes, encoding: .utf8) {
            print("SPRINT93_RECOVERY_PROBE " + text); fflush(stdout)
        }
        if environment["LEDGERFORGE_S93_PROBE_QUIT"] == "1" { NSApplication.shared.terminate(nil) }
    }
#endif
    private init() {}

    /// File/hash/SQLite validation runs away from the main actor. Existing
    /// canonical hydration and final UI-store publication retain their actor.
    @concurrent nonisolated private static func work<T: Sendable>(_ operation: @Sendable () throws -> T) async throws -> T {
        try Task.checkCancellation()
        return try operation()
    }

    func configureTarget(_ current: URL) {
        let target = RestoreLayout(current: current)
        layout = target
        canCreateNewLedger = (try? target.permitsExplicitCreation()) == true
    }

    func startNewLedger() {
        guard !isBusy, candidateID == nil, canCreateNewLedger else { return }
        task = Task { await createNewLedger() }
    }

    func createNewLedger() async {
        guard let layout, !isBusy, candidateID == nil else { return }
        guard (try? layout.permitsExplicitCreation()) == true else {
            canCreateNewLedger = false
            message = "A ledger or recovery files are already present. A new ledger was not created."
            return
        }
        guard
              DatabaseActivityGate.shared.beginExclusive(allowUnavailable: true) else { return }
        isBusy = true; isReplacing = true; canCreateNewLedger = false
        defer { isBusy = false; isReplacing = false }
        do {
            let reserved = try await Self.work {
                guard try layout.permitsExplicitCreation() else { return false }
                if !BackupFiles.exists(layout.parent) {
                    try FileManager.default.createDirectory(at: layout.parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                    try BackupFiles.sync(layout.parent.deletingLastPathComponent(), directory: true)
                }
                try BackupFiles.reserveFile(layout.current)
                return true
            }
            guard reserved else {
                DatabaseActivityGate.shared.finishExclusive(providerChanged: false)
                message = "A ledger or recovery files are already present. A new ledger was not created."
                return
            }
            let provider = try SQLiteRepositoryProvider(path: layout.current.path, migrations: allMigrations)
            do {
                let runtime = DatabaseProvider.verifiedSQLite(provider)
                let hydrator = RepositoryStoreHydrator(databaseProvider: runtime, participatesInLifecycleGate: false)
                let snapshot = try hydrator.stageHydration()
                publish((provider, runtime, hydrator, snapshot))
                DatabaseActivityGate.shared.finishExclusive(providerChanged: true)
                message = "New ledger created."
            } catch { try? provider.database.closeChecked(); throw error }
        } catch { enterUnavailable() }
    }

    private func currentProvider() throws -> SQLiteRepositoryProvider? {
#if DEBUG
        if isIsolatedTest { return testProvider }
#endif
        return try LedgerForgeApp.currentSQLiteProviderForRecovery()
    }

    private func prepareRuntime(_ url: URL, readOnly: Bool) throws -> (SQLiteRepositoryProvider, DatabaseProvider, RepositoryStoreHydrator, RepositoryRuntimeSnapshot) {
        let sqlite = try SQLiteRepositoryProvider(path: url.path, migrations: allMigrations, access: readOnly ? .readOnlySnapshot : .existing)
        do {
            let runtime = DatabaseProvider.verifiedSQLite(sqlite)
            let hydrator = RepositoryStoreHydrator(databaseProvider: runtime, participatesInLifecycleGate: false)
            let snapshot = try hydrator.stageHydration()
            return (sqlite, runtime, hydrator, snapshot)
        } catch { try? sqlite.database.closeChecked(); throw error }
    }

    private func checkHydration(_ url: URL) throws {
        let staged = try prepareRuntime(url, readOnly: true)
        try staged.0.database.closeChecked()
    }

    private func publish(_ prepared: (SQLiteRepositoryProvider, DatabaseProvider, RepositoryStoreHydrator, RepositoryRuntimeSnapshot)) {
        canCreateNewLedger = false
#if DEBUG
        if isIsolatedTest {
            DatabaseProvider.shared.invalidateGeneration()
            DatabaseProvider.shared = prepared.1
            prepared.2.installSnapshotWithoutObservation(prepared.3)
            testProvider = prepared.0
            prepared.2.notifyObserversOfInstalledSnapshot()
            return
        }
#endif
        LedgerForgeApp.publishRecoveredCurrent(prepared.0, runtime: prepared.1, hydrator: prepared.2, snapshot: prepared.3)
    }

    func cancel() {
        guard canCancel else { return }
        task?.cancel()
        if !isBusy {
            task = Task { await discardCandidate() }
        }
    }
    func startBackup(to destination: URL) {
        guard !isBusy, candidateID == nil else { return }
        task = Task { await createBackup(to: destination) }
    }
    func startVerification(of source: URL) {
        guard !isBusy, candidateID == nil else { return }
        task = Task { await verifyRestore(from: source) }
    }
    func startReplacement() {
        guard !isBusy, candidateID != nil else { return }
        task = Task { await replaceLedger() }
    }

    func createBackup(to destination: URL) async {
        guard !isBusy, candidateID == nil, let layout else { return }
        isBusy = true; canCancel = true; message = "Creating a consistent backup…"
        defer { isBusy = false; canCancel = false }
        let access = destination.startAccessingSecurityScopedResource()
        defer { if access { destination.stopAccessingSecurityScopedResource() } }
        let id = UUID()
        var lease: DatabaseActivityLease?
        do {
            lease = try DatabaseActivityGate.shared.begin(.backup)
            guard let source = try currentProvider(), source.generationToken == DatabaseProvider.shared.generationToken,
                  source.databasePath == layout.current.path, DatabaseProvider.shared.persistenceState.isUsable else { throw BackupError.unavailableCurrent }
            let db = source.database
            try await Self.work {
                try BackupFiles.directory(destination)
                try BackupFiles.rejectGitDestination(destination)
                try layout.createOperation(id)
                try BackupFiles.createDirectory(layout.package(id))
                try db.withExclusiveAccess {
                    try BackupCompatibility.checkContents(db)
                    try db.createBackup(at: layout.package(id).appendingPathComponent("ledger.sqlite").path)
                }
            }
            lease?.finish(); lease = nil
            message = "Verifying the backup…"
            let payloadURL = layout.package(id).appendingPathComponent("ledger.sqlite")
            let app = BackupManifest.Application(identifier: Bundle.main.bundleIdentifier,
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            let manifest = try await Self.work {
                let snapshot = SQLiteDatabase(path: payloadURL.path)
                try snapshot.open(access: .readOnlySnapshot)
                do { try BackupCompatibility.verifyDatabase(snapshot); try snapshot.closeChecked() }
                catch { try? snapshot.closeChecked(); throw error }
                let payload = try BackupFiles.hash(payloadURL)
                return BackupManifest(formatVersion: 1, backupID: id,
                    createdAt: ISO8601DateFormatter().string(from: Date()), application: app,
                    database: .init(file: "ledger.sqlite", byteSize: payload.size, sha256: payload.sha256),
                    schemaVersion: BackupCompatibility.supportedSchemaVersion, migrations: BackupCompatibility.migrationIdentities,
                    contents: BackupManifest.contentDescription, exclusions: BackupManifest.excluded)
            }
            try checkHydration(payloadURL)
            try Task.checkCancellation()
            message = "Saving the verified backup…"
            let published = try await Self.work {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(manifest).write(to: layout.package(id).appendingPathComponent("manifest.json"), options: .withoutOverwriting)
                let stamp = manifest.createdAt.replacingOccurrences(of: ":", with: "-")
                let final = destination.appendingPathComponent("LedgerForge-\(stamp)-\(id.uuidString.prefix(8)).ledgerforgebackup", isDirectory: true)
                let staging = destination.appendingPathComponent(".LedgerForge-\(id.uuidString).partial", isDirectory: true)
                do {
                    try BackupFiles.copyPackage(layout.package(id), to: staging)
                    guard try BackupFiles.verifyPackage(staging) == manifest else { throw BackupError.damaged }
                    try BackupFiles.flushPackage(staging)
                    try Task.checkCancellation()
                    try BackupFiles.moveWithoutOverwrite(staging, final)
                    return final
                } catch {
                    if FileManager.default.fileExists(atPath: staging.path) {
                        do { try FileManager.default.removeItem(at: staging) }
                        catch { throw BackupError.cleanup }
                    }
                    throw error
                }
            }
            lastBackupURL = published
            message = "Backup created · integrity and compatibility verified.\n\(published.path)"
            do { try await Self.work { try layout.removeOperation(id) } }
            catch { message += "\nTemporary-file cleanup is pending." }
        } catch {
            lease?.finish()
            report(error, fallback: "Backup verification failed. Current Database is unchanged.")
            // Cancellation must not skip cleanup because the task is cancelled.
            do { try layout.removeOperation(id) } catch { message += " Temporary-file cleanup is pending." }
        }
    }

    func verifyRestore(from source: URL) async {
        guard !isBusy, candidateID == nil, let layout else { return }
        isBusy = true; canCancel = true; message = "Verifying the selected backup…"
        defer { isBusy = false }
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let id = UUID()
        let generation = DatabaseProvider.shared.generationToken
        do {
            let manifest = try await Self.work {
                try layout.createOperation(id)
                try BackupFiles.copyPackage(source, to: layout.package(id))
                return try BackupFiles.verifyPackage(layout.package(id))
            }
            try checkHydration(layout.package(id).appendingPathComponent("ledger.sqlite"))
            try Task.checkCancellation()
            guard generation == DatabaseProvider.shared.generationToken else { throw BackupError.candidateChanged }
            candidateID = id; candidateManifest = manifest; verifiedGeneration = generation
            let current = try currentProvider()
            targetChangeCounter = current.flatMap { try? $0.database.totalChangeCounter() }
            message = "Backup verified · compatible with this app. Restoring will replace current ledger data."
        } catch {
            canCancel = false
            candidateID = nil; candidateManifest = nil; verifiedGeneration = nil
            report(error, fallback: "Backup verification failed. Current Database is unchanged.")
            do { try layout.removeOperation(id) } catch { message += " Temporary-file cleanup is pending." }
        }
    }

    func discardCandidate() async {
        guard let id = candidateID, let layout else { return }
        candidateID = nil; candidateManifest = nil; verifiedGeneration = nil; canCancel = false
        do { try layout.removeOperation(id); message = "Restore cancelled. Current Database is unchanged." }
        catch { message = "Restore cancelled. Temporary-file cleanup is pending." }
    }

    func replaceLedger() async {
        guard !isBusy, let id = candidateID, let manifest = candidateManifest, let layout else { return }
        guard verifiedGeneration == DatabaseProvider.shared.generationToken,
              (try? currentProvider()?.database.totalChangeCounter()) == targetChangeCounter else {
            await discardCandidate()
            message = BackupError.candidateChanged.localizedDescription; return
        }
        let gate = DatabaseActivityGate.shared
        guard gate.beginExclusive(allowUnavailable: true) else {
            await discardCandidate(); message = BackupError.activeWork.localizedDescription; return
        }
        isBusy = true; isReplacing = true; canCancel = false; message = "Preserving the current ledger…"
        defer { isBusy = false; isReplacing = false }
        var record: RestoreOperation?
        var installed: SQLiteRepositoryProvider?
        var activationDecisionAttempted = false
        var preservationDecisionAttempted = false
        var currentClosed = false
        do {
            let reverified = try await Self.work { try BackupFiles.verifyPackage(layout.package(id)) }
            guard reverified == manifest else { throw BackupError.candidateChanged }
            let current = try currentProvider()
            let priorUsable = current != nil && DatabaseProvider.shared.persistenceState.isUsable && targetChangeCounter != nil
            if let current {
                let database = current.database
                try await Self.work {
                    if priorUsable { try database.checkpointAndClose() }
                    else { try database.closeChecked() }
                }
                currentClosed = true
            }
            DatabaseProvider.shared.invalidateGeneration()
            ApplicationAvailability.shared.begin()
            try await Self.work { try layout.retainOutstandingReceipt() }
            preservationDecisionAttempted = true
            let beginning = try await Self.work {
                let value = RestoreOperation(version: 1, operationID: id, backupID: manifest.backupID,
                    payloadSHA256: manifest.database.sha256, currentFile: layout.current.lastPathComponent,
                    priorFiles: try layout.existingFiles(), priorWasUsable: priorUsable, phase: .preserving)
                try layout.write(value)
                return value
            }
            record = beginning
            let preserved = try await Self.work { try layout.preserve(beginning) }
            record = preserved
#if DEBUG
            if failuresForTesting.contains(.interruptBeforeCommit) {
                if exitsOnInterruptionForTesting { _exit(93) }
                throw SimulatedRestoreInterruption()
            }
            if failuresForTesting.contains(.afterPreservation) { throw BackupError.damaged }
#endif
            message = "Installing and loading the verified ledger…"
            try await Self.work {
                try BackupFiles.moveWithoutOverwrite(layout.package(id).appendingPathComponent("ledger.sqlite"), layout.current)
                try BackupFiles.sync(layout.current)
            }
#if DEBUG
            if failuresForTesting.contains(.candidateOpen) { throw BackupError.damaged }
#endif
            let prepared = try prepareRuntime(layout.current, readOnly: false)
            installed = prepared.0
            let candidateDB = prepared.0.database
            try await Self.work { try BackupCompatibility.verifyDatabase(candidateDB) }
#if DEBUG
            if failuresForTesting.contains(.hydration) { throw BackupError.damaged }
            if failuresForTesting.contains(.activationRecord) { throw BackupError.durability }
#endif
            let activated: RestoreOperation = { var value = preserved; value.phase = .activated; return value }()
            activationDecisionAttempted = true
            try await Self.work { try layout.write(activated) }
            record = activated
            // From here the new database is durable authority. No throwing work
            // separates the final complete provider/store publication.
            publish(prepared)
            restoredReceipt = activated
            candidateID = nil; candidateManifest = nil
            gate.finishExclusive(providerChanged: true)
            message = priorUsable
                ? "Ledger restored. The previous ledger is retained until a successful relaunch."
                : "Ledger restored. Any prior recovery files are retained until a successful relaunch."
#if DEBUG
            if failuresForTesting.contains(.interruptAfterCommit) {
                if exitsOnInterruptionForTesting { _exit(94) }
                throw SimulatedRestoreInterruption()
            }
#endif
        } catch {
#if DEBUG
            if error is SimulatedRestoreInterruption {
                try? installed?.database.closeChecked()
                enterUnavailable(); return
            }
#endif
            try? installed?.database.closeChecked()
            // A failed activation-record flush may already have renamed the
            // decision. Preserve both sets and let startup interpret it.
            if activationDecisionAttempted { enterUnavailable(); return }
            if preservationDecisionAttempted && record == nil { enterUnavailable(); return }
            if let record {
                do {
                    let pending = try await Self.work { try layout.restorePrevious(record) }
#if DEBUG
                    if failuresForTesting.contains(.rollbackOpen) { throw BackupError.recoveryUnavailable }
#endif
                    let prior = try prepareRuntime(layout.current, readOnly: false)
                    var rolledBack = pending; rolledBack.phase = .rolledBack
                    do { try layout.write(rolledBack) }
                    catch { try? prior.0.database.closeChecked(); throw error }
                    publish(prior)
                    gate.finishExclusive(providerChanged: true)
                    candidateID = nil; candidateManifest = nil
                    message = BackupError.activationRolledBack.localizedDescription
                } catch { enterUnavailable() }
            } else {
                // Close or receipt preparation failed before preservation.
                // Reopen the still-present ledger, never create a replacement.
                do {
                    if currentClosed {
                        let prior = try prepareRuntime(layout.current, readOnly: false)
                        publish(prior)
                    }
                    gate.finishExclusive(providerChanged: currentClosed)
                    await discardCandidate()
                    report(error, fallback: "Restore could not begin. Your current ledger is unchanged.")
                } catch { enterUnavailable() }
            }
        }
    }

    /// Invoked before any creating/migrating provider open. No receipt means a
    /// verified legacy database remains usable; absence is handled by bootstrap.
    func recoverBeforeStartup() throws {
        guard let layout, let record = try layout.readReceipt() else { return }
        try layout.validateOwnership()
        switch record.phase {
        case .preserving, .preserved:
            guard DatabaseActivityGate.shared.beginExclusive(allowUnavailable: true) else { throw BackupError.activeWork }
            ownsStartupGate = true
            _ = try layout.restorePrevious(record)
            message = "An interrupted restore was rolled back. Loading the previous ledger…"
        case .activated, .relaunchConfirmed:
            try BackupFiles.regularFile(layout.current)
            guard DatabaseActivityGate.shared.beginExclusive(allowUnavailable: true) else { throw BackupError.activeWork }
            ownsStartupGate = true
            restoredReceipt = record; needsRelaunchConfirmation = true
        case .rolledBack:
            try BackupFiles.regularFile(layout.current)
        }
    }

    func startupDidFail() {
        guard ownsStartupGate else { return }
        ownsStartupGate = false
        enterUnavailable()
    }

    func startupDidHydrate() async {
        guard let layout else { return }
        guard ownsStartupGate else { return }
        isBusy = true; canCancel = false
        defer { isBusy = false }
        do {
            guard var record = try layout.readReceipt() else { throw BackupError.recoveryUnavailable }
            guard let provider = try currentProvider(), provider.generationToken == DatabaseProvider.shared.generationToken else {
                throw BackupError.recoveryUnavailable
            }
            let db = provider.database
            try await Self.work { try BackupCompatibility.verifyDatabase(db) }
            if record.phase == .preserved || record.phase == .preserving {
                record.phase = .rolledBack
                let finished = record
                try await Self.work { try layout.write(finished) }
                DatabaseActivityGate.shared.finishExclusive(providerChanged: true)
                ownsStartupGate = false
                message = "The previous ledger was recovered after an interrupted restore."
            } else if needsRelaunchConfirmation {
                record.phase = .relaunchConfirmed
                let finished = record
                try await Self.work { try layout.write(finished) }
                restoredReceipt = record; needsRelaunchConfirmation = false
                DatabaseActivityGate.shared.finishExclusive(providerChanged: true)
                ownsStartupGate = false
                do {
                    let retained = try await Self.work {
                        try layout.removeOperation(finished.operationID)
                        return try layout.hasRetainedOperations(excluding: finished.operationID)
                    }
                    message = retained
                        ? "Restored ledger reopened successfully. Earlier recovery assets remain retained."
                        : "Restored ledger reopened successfully. Recovery cleanup is complete."
                }
                catch { message = "Restored ledger reopened successfully. Recovery cleanup is pending." }
            }
        } catch {
            if ownsStartupGate { ownsStartupGate = false; enterUnavailable() }
            else { message = "The ledger reopened, but recovery receipt verification needs attention. Recovery files are retained." }
        }
    }

    private func enterUnavailable() {
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)
        DatabaseActivityGate.shared.enterUnavailable()
        let failure = RuntimeDiagnostic.failure(BackupError.recoveryUnavailable, operation: "restore", stage: "recovery", effect: "financial actions unavailable; recovery files retained")
        ApplicationAvailability.shared.didFail(failure, generation: nil)
        candidateID = nil; candidateManifest = nil; canCancel = false
        message = BackupError.recoveryUnavailable.localizedDescription
        RuntimeDiagnostic.record(failure, category: .database)
    }
    private func report(_ error: Error, fallback: String) {
        if error is CancellationError { message = "Cancelled. Current Database is unchanged." }
        else if let error = error as? BackupError { message = error.localizedDescription }
        else { message = fallback }
        if !(error is CancellationError) {
            RuntimeDiagnostic.record(RuntimeDiagnostic.failure(error, operation: "backup and restore", stage: "verification or publication"), category: .database)
        }
    }
}

#if DEBUG
private struct SimulatedRestoreInterruption: Error {}
#endif
