import Foundation
import Testing
@testable import LedgerForge

struct ConfirmedImportSubprocessTests {
    @Test func separateProcessesProduceOneAcceptedProbeResult() throws {
        try runRace(scenario: "exact", expectedLoser: "exact-duplicate")
    }

    @Test func separateProcessesRejectCompetingIdentifierOwnership() throws {
        for iteration in 1...20 {
            try runRace(scenario: "identifier", expectedLoser: "identifier-ownership-conflict", iteration: iteration)
        }
    }

    @Test func separateProcessesRejectRepeatedAccountScopedEvent() throws {
        try runRace(scenario: "event", expectedLoser: "existing-event-duplicate", seedExistingAccount: true)
    }

    @Test func separateProcessesRejectConflictingProposedAccountGraph() throws {
        try runRace(scenario: "account", expectedLoser: "repository-integrity-conflict")
    }

    @Test func subprocessClassifiesHeldSQLiteWriteLockAsRetryableContention() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = folder.appendingPathComponent("probe.sqlite").path
        try initialize(database: database, seedExistingAccount: false)
        let testBundle = try #require(Bundle.allBundles.first { $0.bundleURL.lastPathComponent == "LedgerForgeTests.xctest" })
        let child = try ProbeChild(executable: try #require(testBundle.resourceURL?.appendingPathComponent("LedgerForgeSubprocessProbe")), databasePath: database, scenario: "exact", variant: "1")
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
        #expect(try provider.database.queryInt("PRAGMA foreign_key_check;") == 0)
    }

    private func runRace(scenario: String, expectedLoser: String, seedExistingAccount: Bool = false, iteration: Int = 1) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = folder.appendingPathComponent("probe.sqlite").path
        try initialize(database: database, seedExistingAccount: seedExistingAccount)
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
        try assertDurableState(database: database, scenario: scenario, seededAccount: seedExistingAccount)
    }

    private func probeFailure(iteration: Int, children: [ProbeChild], issue: String) -> Error {
        NSError(domain: "ConfirmedImportSubprocessTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "iteration=\(iteration),issue=\(issue) | \(children.map(\.diagnostic).joined(separator: " | "))"])
    }

    private func initialize(database: String, seedExistingAccount: Bool) throws {
        let provider = try SQLiteRepositoryProvider(path: database, migrations: allMigrations)
        try validateIdentifierOwnershipV5Schema(provider.database)
        if seedExistingAccount {
            let now = "2026-07-20T00:00:00Z"
            _ = try provider.workspaceRepo.upsertWorkspace(WorkspaceDTO(id: "probe-workspace", name: "Probe", createdAtISO: now))
            _ = try provider.accountRepo.upsertAccount(AccountDTO(id: "probe-existing-account", workspaceId: "probe-workspace", name: "Probe", nativeCurrency: "INR", createdAtISO: now))
        }
        provider.database.close()
    }

    private func assertDurableState(database: String, scenario: String, seededAccount: Bool) throws {
        let provider = try SQLiteRepositoryProvider(path: database, migrations: allMigrations)
        defer { provider.database.close() }
        let expectedAccounts = seededAccount ? 1 : 1
        let expected = [
            "workspaces": 1,
            "accounts": expectedAccounts,
            "account_identifiers": scenario == "event" ? 0 : 1,
            "account_identifier_observations": scenario == "event" ? 0 : 1,
            "documents": 1,
            "document_fingerprints": 1,
            "import_sessions": 1,
            "transactions": 1,
            "transaction_event_identities": scenario == "event" ? 1 : 0,
            "import_attempts": 1,
        ]
        for (table, count) in expected {
            let observed = try provider.database.queryInt("SELECT COUNT(*) FROM \(table);")
            #expect(observed == count, "\(table) expected \(count), got \(observed)")
        }
        #expect(try provider.database.queryInt("PRAGMA foreign_key_check;") == 0)
    }
}

private struct ProbePayload: Decodable {
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
    let ready = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var pending = Data()
    private var storedResult: ProbePayload?
    private var stdout = Data()
    private var stderr = Data()
    private var launchAttempted = false
    private var launchSucceeded = false
    private var launchError: String?
    private var pidAfterRun: Int32 = 0
    private var readyObserved = false
    private var goSent = false
    private var timedOut = false
    private var stdoutLines = 0
    private let terminated = DispatchSemaphore(value: 0)
    private let stdoutEOF = DispatchSemaphore(value: 0)
    private let stderrEOF = DispatchSemaphore(value: 0)
    private let drainQueue: DispatchQueue

    init(slot: String = "A", executable: URL, databasePath: String, scenario: String, variant: String) throws {
        self.slot = slot
        self.drainQueue = DispatchQueue(label: "LedgerForgeTests.ProbeDrain.\(slot)", qos: .userInitiated)
        process.executableURL = executable
        process.arguments = [databasePath, scenario, variant, slot]
        process.qualityOfService = .userInitiated
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error
        process.terminationHandler = { [weak self] _ in self?.terminated.signal() }
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            self?.drainQueue.async { [weak self] in self?.consumeStdout(data) }
        }
        error.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            self?.drainQueue.async { [weak self] in self?.consumeStderr(data) }
        }
    }

    func start() throws {
        lock.lock(); launchAttempted = true; lock.unlock()
        do {
            try process.run()
            lock.lock(); launchSucceeded = true; pidAfterRun = process.processIdentifier; lock.unlock()
        } catch {
            lock.lock(); launchError = String(describing: error).prefix(300).description; lock.unlock()
            throw error
        }
    }
    func sendGo() throws {
        try input.fileHandleForWriting.write(contentsOf: Data("GO\n".utf8))
        lock.lock(); goSent = true; lock.unlock()
    }

    var recordedPID: Int32 { lock.withLock { pidAfterRun } }
    var result: ProbePayload? { lock.withLock { storedResult } }

    func waitForExit(timeout: TimeInterval) -> Bool {
        if terminated.wait(timeout: .now() + timeout) == .success { return true }
        lock.lock(); timedOut = true; lock.unlock()
        return false
    }

    func stopAndDrain() {
        if process.isRunning { process.terminate() }
        if process.processIdentifier > 0 { _ = terminated.wait(timeout: .now() + 2) }
        finishDraining()
    }

    func finishDraining() {
        _ = stdoutEOF.wait(timeout: .now() + 1)
        _ = stderrEOF.wait(timeout: .now() + 1)
        output.fileHandleForReading.readabilityHandler = nil
        error.fileHandleForReading.readabilityHandler = nil
        lock.lock(); flushTrailingStdout(); lock.unlock()
    }

    private func consumeStdout(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        if data.isEmpty { flushTrailingStdout(); stdoutEOF.signal(); return }
        stdout.append(data)
        pending.append(data)
        while let newline = pending.firstIndex(of: 10) {
            let line = pending.prefix(upTo: newline)
            pending.removeSubrange(...newline)
            stdoutLines += 1
            if line == Data("READY".utf8) { readyObserved = true; ready.signal(); continue }
            if let decoded = try? JSONDecoder().decode(ProbePayload.self, from: line), storedResult == nil { storedResult = decoded }
        }
    }

    private func consumeStderr(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        if data.isEmpty { stderrEOF.signal(); return }
        stderr.append(data.prefix(max(0, 1000 - stderr.count)))
    }

    private func flushTrailingStdout() {
        guard !pending.isEmpty else { return }
        if let decoded = try? JSONDecoder().decode(ProbePayload.self, from: pending), storedResult == nil { storedResult = decoded }
        pending.removeAll()
    }

    var diagnostic: String {
        lock.withLock {
            "slot=\(slot),launchAttempted=\(launchAttempted),launchSucceeded=\(launchSucceeded),launchError=\(launchError ?? "nil"),pid=\(pidAfterRun),ready=\(readyObserved),go=\(goSent),stdoutBytes=\(stdout.count),stdoutLines=\(stdoutLines),stdout=\(String(decoding: stdout.prefix(1000), as: UTF8.self)),stderrBytes=\(stderr.count),stderr=\(String(decoding: stderr.prefix(1000), as: UTF8.self)),decoded=\(String(describing: storedResult)),status=\(process.terminationStatus),reason=\(process.terminationReason.rawValue),timedOut=\(timedOut)"
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T { lock(); defer { unlock() }; return body() }
}
