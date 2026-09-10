import Foundation
import Synchronization
import Testing
@testable import LedgerForge

/// Nonfinancial process/SQLite mechanics, not confirmed-import or source
/// acceptance. Financial subprocess scenarios require authentic statements.
@MainActor
struct SQLiteSubprocessMechanicsTests {
    @Test func separateProcessesEnforceUniqueKeyAndRollBackLosingTransaction() throws {
        try runRace(scenario: "unique", expectedLoser: "unique-conflict")
    }

    @Test func subprocessClassifiesHeldSQLiteWriteLockAsRetryableContention() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = folder.appendingPathComponent("probe.sqlite").path
        try initialize(database: database)
        let testBundle = try #require(Bundle.allBundles.first { $0.bundleURL.lastPathComponent == "LedgerForgeTests.xctest" })
        let child = try ProbeChild(executable: try #require(testBundle.resourceURL?.appendingPathComponent("LedgerForgeSubprocessProbe")), databasePath: database, scenario: "unique", variant: "1")
        let lock = SQLiteDatabase(path: database)
        try lock.open()
        try lock.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        defer { try? lock.execute(sql: "ROLLBACK;"); lock.close() }
        try child.start()
        guard child.ready.wait(timeout: .now() + 5) == .success else {
            child.stopAndDrain()
            throw NSError(domain: "ConfirmedImportSubprocessTests", code: 1, userInfo: [NSLocalizedDescriptionKey: child.diagnostic])
        }
        try child.sendGo()
        guard child.waitForExit(timeout: 8) else {
            child.stopAndDrain()
            throw NSError(domain: "ConfirmedImportSubprocessTests", code: 3, userInfo: [NSLocalizedDescriptionKey: child.diagnostic])
        }
        child.finishDraining()
        try lock.execute(sql: "ROLLBACK;")
        lock.close()
        #expect(child.result?.result == "retryable-contention", Comment(rawValue: child.diagnostic))
        #expect(child.result?.slot == child.slot)
        #expect(child.result?.pid == child.recordedPID)
        let provider = try SQLiteRepositoryProvider(path: database, migrations: allMigrations)
        defer { provider.database.close() }
        #expect(try provider.database.queryInt("SELECT COUNT(*) FROM import_attempts;") == 0)
        #expect(try provider.database.queryInt("SELECT COUNT(*) FROM subprocess_mechanics_launches;") == 0)
        #expect(try provider.database.queryInt("SELECT COUNT(*) FROM subprocess_mechanics_keys;") == 0)
        #expect(try provider.database.queryInt("PRAGMA foreign_key_check;") == 0)
    }

    private func runRace(scenario: String, expectedLoser: String, iteration: Int = 1) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = folder.appendingPathComponent("probe.sqlite").path
        try initialize(database: database)
        let testBundle = try #require(Bundle.allBundles.first { $0.bundleURL.lastPathComponent == "LedgerForgeTests.xctest" })
        let executable = try #require(testBundle.resourceURL?.appendingPathComponent("LedgerForgeSubprocessProbe"))
        #expect(FileManager.default.isExecutableFile(atPath: executable.path))
        let children = try [
            ProbeChild(slot: "A", executable: executable, databasePath: database, scenario: scenario, variant: "1"),
            ProbeChild(slot: "B", executable: executable, databasePath: database, scenario: scenario, variant: "2"),
        ]
        do {
            for child in children { try child.start() }
        } catch {
            children.forEach { $0.stopAndDrain() }
            throw error
        }
        let launchedPIDs = children.map(\.recordedPID)
        guard launchedPIDs.allSatisfy({ $0 > 0 }), Set(launchedPIDs).count == 2 else {
            children.forEach { $0.stopAndDrain() }
            throw probeFailure(iteration: iteration, children: children, issue: "launch")
        }
        let allReady = children.allSatisfy { $0.ready.wait(timeout: .now() + 5) == .success }
        if !allReady {
            children.forEach { $0.stopAndDrain() }
            throw probeFailure(iteration: iteration, children: children, issue: "ready")
        }
        try children.forEach { try $0.sendGo() }
        guard children.allSatisfy({ $0.waitForExit(timeout: 8) }) else {
            children.forEach { $0.stopAndDrain() }
            throw probeFailure(iteration: iteration, children: children, issue: "termination-timeout")
        }
        children.forEach { $0.finishDraining() }
        let results = children.compactMap(\.result)
        let codes = results.map(\.result)
        guard results.count == 2 else { throw probeFailure(iteration: iteration, children: children, issue: "missing-result") }
        for child in children {
            guard let result = child.result, result.slot == child.slot, result.pid == child.recordedPID else {
                throw probeFailure(iteration: iteration, children: children, issue: "protocol-identity")
            }
        }
        #expect(codes.filter { $0 == "committed" }.count == 1, Comment(rawValue: "iteration=\(iteration),results=\(codes)"))
        #expect(codes.filter { $0 == expectedLoser }.count == 1, Comment(rawValue: "iteration=\(iteration),results=\(codes)"))
        try assertDurableState(database: database)
    }

    private func probeFailure(iteration: Int, children: [ProbeChild], issue: String) -> Error {
        NSError(domain: "ConfirmedImportSubprocessTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "iteration=\(iteration),issue=\(issue) | \(children.map(\.diagnostic).joined(separator: " | "))"])
    }

    private func initialize(database: String) throws {
        let provider = try SQLiteRepositoryProvider(path: database, migrations: allMigrations)
        try provider.database.execute(sql: """
            CREATE TABLE subprocess_mechanics_launches(slot TEXT PRIMARY KEY);
            CREATE TABLE subprocess_mechanics_keys(name TEXT UNIQUE NOT NULL,payload TEXT NOT NULL);
            """)
        provider.database.close()
    }

    private func assertDurableState(database: String) throws {
        let provider = try SQLiteRepositoryProvider(path: database, migrations: allMigrations)
        defer { provider.database.close() }
        let expected = [
            "subprocess_mechanics_launches": 1,
            "subprocess_mechanics_keys": 1,
            "workspaces": 0,
            "accounts": 0,
            "documents": 0,
            "import_sessions": 0,
            "transactions": 0,
            "import_attempts": 0,
        ]
        for (table, count) in expected {
            let observed = try provider.database.queryInt("SELECT COUNT(*) FROM \(table);")
            #expect(observed == count, "\(table) expected \(count), got \(observed)")
        }
        #expect(try provider.database.queryInt("PRAGMA foreign_key_check;") == 0)
    }
}

private struct ProbePayload: Decodable, Sendable {
    let slot: String
    let pid: Int32
    let result: String
}

private final class ProbeChild {
    let slot: String
    let process = Process()
    let input = Pipe()
    let output = Pipe()
    let error = Pipe()
    private let callbacks: ProbeCallbacks

    init(slot: String = "A", executable: URL, databasePath: String, scenario: String, variant: String) throws {
        self.slot = slot
        let callbacks = ProbeCallbacks(slot: slot)
        self.callbacks = callbacks
        process.executableURL = executable
        process.arguments = [databasePath, scenario, variant, slot]
        process.qualityOfService = .userInitiated
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error
        process.terminationHandler = { [callbacks] _ in callbacks.signalTermination() }
        output.fileHandleForReading.readabilityHandler = { [callbacks] handle in
            callbacks.enqueueStdout(handle.availableData)
        }
        error.fileHandleForReading.readabilityHandler = { [callbacks] handle in
            callbacks.enqueueStderr(handle.availableData)
        }
    }

    var ready: DispatchSemaphore { callbacks.ready }

    func start() throws {
        callbacks.recordLaunchAttempt()
        do {
            try process.run()
            callbacks.recordLaunchSucceeded(pid: process.processIdentifier)
        } catch {
            callbacks.recordLaunchError(error)
            throw error
        }
    }

    func sendGo() throws {
        try input.fileHandleForWriting.write(contentsOf: Data("GO\n".utf8))
        callbacks.recordGoSent()
    }

    var recordedPID: Int32 { callbacks.recordedPID }
    var result: ProbePayload? { callbacks.result }

    func waitForExit(timeout: TimeInterval) -> Bool {
        callbacks.waitForExit(timeout: timeout)
    }

    func stopAndDrain() {
        if process.isRunning { process.terminate() }
        if process.processIdentifier > 0 { _ = callbacks.terminated.wait(timeout: .now() + 2) }
        finishDraining()
    }

    func finishDraining() {
        callbacks.waitForDrain()
        output.fileHandleForReading.readabilityHandler = nil
        error.fileHandleForReading.readabilityHandler = nil
        callbacks.flushTrailingStdout()
    }

    var diagnostic: String {
        callbacks.diagnostic(
            status: process.terminationStatus,
            reason: process.terminationReason.rawValue
        )
    }
}

private final class ProbeCallbacks: Sendable {
    private struct State: Sendable {
        var pending = Data()
        var storedResult: ProbePayload?
        var stdout = Data()
        var stderr = Data()
        var launchAttempted = false
        var launchSucceeded = false
        var launchError: String?
        var pidAfterRun: Int32 = 0
        var readyObserved = false
        var goSent = false
        var timedOut = false
        var stdoutLines = 0
    }

    private let slot: String
    let ready = DispatchSemaphore(value: 0)
    let terminated = DispatchSemaphore(value: 0)
    private let stdoutEOF = DispatchSemaphore(value: 0)
    private let stderrEOF = DispatchSemaphore(value: 0)
    private let drainQueue: DispatchQueue
    private let state = Mutex(State())

    init(slot: String) {
        self.slot = slot
        drainQueue = DispatchQueue(
            label: "LedgerForgeTests.ProbeDrain.\(slot)",
            qos: .userInitiated
        )
    }

    func signalTermination() {
        terminated.signal()
    }

    func recordLaunchAttempt() {
        state.withLock { $0.launchAttempted = true }
    }

    func recordLaunchSucceeded(pid: Int32) {
        state.withLock {
            $0.launchSucceeded = true
            $0.pidAfterRun = pid
        }
    }

    func recordLaunchError(_ error: Error) {
        state.withLock {
            $0.launchError = String(describing: error).prefix(300).description
        }
    }

    func recordGoSent() {
        state.withLock { $0.goSent = true }
    }

    var recordedPID: Int32 { state.withLock { $0.pidAfterRun } }
    var result: ProbePayload? { state.withLock { $0.storedResult } }

    func waitForExit(timeout: TimeInterval) -> Bool {
        if terminated.wait(timeout: .now() + timeout) == .success { return true }
        state.withLock { $0.timedOut = true }
        return false
    }

    func enqueueStdout(_ data: Data) {
        drainQueue.async { [self] in consumeStdout(data) }
    }

    func enqueueStderr(_ data: Data) {
        drainQueue.async { [self] in consumeStderr(data) }
    }

    func waitForDrain() {
        _ = stdoutEOF.wait(timeout: .now() + 1)
        _ = stderrEOF.wait(timeout: .now() + 1)
    }

    func flushTrailingStdout() {
        state.withLock { Self.flushTrailingStdout(&$0) }
    }

    private func consumeStdout(_ data: Data) {
        state.withLock { state in
            if data.isEmpty {
                Self.flushTrailingStdout(&state)
                stdoutEOF.signal()
                return
            }
            state.stdout.append(data)
            state.pending.append(data)
            while let newline = state.pending.firstIndex(of: 10) {
                let line = state.pending.prefix(upTo: newline)
                state.pending.removeSubrange(...newline)
                state.stdoutLines += 1
                if line == Data("READY".utf8) {
                    state.readyObserved = true
                    ready.signal()
                    continue
                }
                if let decoded = try? JSONDecoder().decode(ProbePayload.self, from: line), state.storedResult == nil {
                    state.storedResult = decoded
                }
            }
        }
    }

    private func consumeStderr(_ data: Data) {
        state.withLock { state in
            if data.isEmpty {
                stderrEOF.signal()
                return
            }
            state.stderr.append(data.prefix(max(0, 1000 - state.stderr.count)))
        }
    }

    private static func flushTrailingStdout(_ state: inout State) {
        guard !state.pending.isEmpty else { return }
        if let decoded = try? JSONDecoder().decode(ProbePayload.self, from: state.pending), state.storedResult == nil {
            state.storedResult = decoded
        }
        state.pending.removeAll()
    }

    func diagnostic(status: Int32, reason: Int) -> String {
        let snapshot = state.withLock { $0 }
        return "slot=\(slot),launchAttempted=\(snapshot.launchAttempted),launchSucceeded=\(snapshot.launchSucceeded),launchError=\(snapshot.launchError ?? "nil"),pid=\(snapshot.pidAfterRun),ready=\(snapshot.readyObserved),go=\(snapshot.goSent),stdoutBytes=\(snapshot.stdout.count),stdoutLines=\(snapshot.stdoutLines),stdout=\(String(decoding: snapshot.stdout.prefix(1000), as: UTF8.self)),stderrBytes=\(snapshot.stderr.count),stderr=\(String(decoding: snapshot.stderr.prefix(1000), as: UTF8.self)),decoded=\(String(describing: snapshot.storedResult)),status=\(status),reason=\(reason),timedOut=\(snapshot.timedOut)"
    }
}
