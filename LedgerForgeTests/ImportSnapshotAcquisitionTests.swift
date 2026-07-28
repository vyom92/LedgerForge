import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct ImportSnapshotAcquisitionTests {
    @Test(.globalRuntimeStateIsolation)
    func engineAcquiresOnceAndCoordinatorReadsThoseExactBytes() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let sourceURL = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let sourceBytes = try Data(contentsOf: sourceURL)
        let sourceText = try #require(String(data: sourceBytes, encoding: .utf8))
        let acquirer = SnapshotAcquirerProbe(bytes: sourceBytes)
        let coordinator = SnapshotTextCoordinator(text: sourceText)
        let engine = makeEngine(coordinator: coordinator, acquirer: acquirer.acquire)

        let prepared = try await engine.prepareImport(from: sourceURL)
        defer { engine.cancelPreparedImport(prepared) }

        #expect(acquirer.acquisitionCount == 1)
        #expect(coordinator.invocationCount == 1)
        #expect(coordinator.receivedBytes == sourceBytes)
    }

    @Test(.globalRuntimeStateIsolation)
    func acquisitionFailureStopsBeforeCoordinatorInvocationWithBoundedError() async {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let coordinator = FailingSnapshotCoordinator()
        let sourceURL = URL(fileURLWithPath: "/private/source/that-must-not-appear.csv")
        let engine = ImportEngine(
            importCoordinator: coordinator,
            sourceSnapshotAcquirer: { _ in throw SnapshotAcquisitionProbeError.failed },
            importPersistenceCoordinator: SnapshotPreparationPersistenceCoordinator(),
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { ProviderGenerationToken() }
        )

        do {
            _ = try await engine.prepareImport(from: sourceURL)
            Issue.record("Expected source acquisition to fail before coordination.")
        } catch let error as SourceContentSnapshotError {
            #expect(error == .acquisitionFailed)
            #expect(error.localizedDescription == "The selected source document could not be read.")
            #expect(!error.localizedDescription.contains(sourceURL.path))
        } catch {
            Issue.record("Expected a bounded SourceContentSnapshotError.")
        }

        #expect(coordinator.invocationCount == 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func readerFailureInvalidatesSnapshot() async {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let snapshot = SourceContentSnapshot(bytes: Data("reader failure".utf8))
        let acquirer = SnapshotAcquirerProbe(snapshot: snapshot)
        let coordinator = FailingSnapshotCoordinator()
        let engine = makeEngine(coordinator: coordinator, acquirer: acquirer.acquire)

        await #expect(throws: ImportError.readerFailure(message: "Reader rejected snapshot.")) {
            try await engine.prepareImport(from: URL(fileURLWithPath: "/snapshot-only/statement.csv"))
        }

        #expect(coordinator.invocationCount == 1)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try snapshot.withBytes { $0 }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func cancellationInvalidatesAcquiredSnapshot() async {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let snapshot = SourceContentSnapshot(bytes: Data("cancelled source".utf8))
        let acquirer = SnapshotAcquirerProbe(snapshot: snapshot)
        let coordinator = CancellationSnapshotCoordinator()
        let engine = makeEngine(coordinator: coordinator, acquirer: acquirer.acquire)
        let task = Task {
            try await engine.prepareImport(
                from: URL(fileURLWithPath: "/snapshot-only/statement.csv")
            )
        }

        await coordinator.waitUntilInvoked()
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected preparation cancellation.")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError after cancelling preparation.")
        }
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try snapshot.withBytes { $0 }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func successfulPreparationRetainsSnapshotUntilPreviewCancellation() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let sourceURL = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let bytes = try Data(contentsOf: sourceURL)
        let text = try #require(String(data: bytes, encoding: .utf8))
        let snapshot = SourceContentSnapshot(bytes: bytes)
        let acquirer = SnapshotAcquirerProbe(snapshot: snapshot)
        let engine = makeEngine(
            coordinator: SnapshotTextCoordinator(text: text),
            acquirer: acquirer.acquire
        )

        let prepared = try await engine.prepareImport(from: sourceURL)
        #expect(prepared.validation.passed)
        #expect(try snapshot.withBytes { $0 } == bytes)

        engine.cancelPreparedImport(prepared)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try snapshot.withBytes { $0 }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func currentRawTextFingerprintAndPreparedFinancialResultRemainUnchanged() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let sourceURL = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let expectedText = try CSVReader().read(from: sourceURL)
        let engine = ImportEngine(
            importPersistenceCoordinator: SnapshotPreparationPersistenceCoordinator(),
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { ProviderGenerationToken() }
        )

        let prepared = try await engine.prepareImport(from: sourceURL)
        defer { engine.cancelPreparedImport(prepared) }

        #expect(prepared.rawContents == expectedText)
        #expect(prepared.fingerprint == ExactStatementFingerprint(text: expectedText))
        #expect(prepared.transactionCount == 81)
        #expect(prepared.validation.passed)
    }

    private func makeEngine(
        coordinator: any ImportFramework.ImportCoordinator,
        acquirer: @escaping (URL) throws -> SourceContentSnapshot
    ) -> ImportEngine {
        ImportEngine(
            importCoordinator: coordinator,
            sourceSnapshotAcquirer: acquirer,
            importPersistenceCoordinator: SnapshotPreparationPersistenceCoordinator(),
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { ProviderGenerationToken() }
        )
    }
}

private enum SnapshotAcquisitionProbeError: Error {
    case failed
}

private final class SnapshotAcquirerProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let snapshot: SourceContentSnapshot
    private var count = 0

    init(bytes: Data) {
        self.snapshot = SourceContentSnapshot(bytes: bytes)
    }

    init(snapshot: SourceContentSnapshot) {
        self.snapshot = snapshot
    }

    var acquisitionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func acquire(from url: URL) throws -> SourceContentSnapshot {
        lock.lock()
        count += 1
        lock.unlock()
        return snapshot
    }
}

private final class SnapshotTextCoordinator: ImportFramework.ImportCoordinator, @unchecked Sendable {
    private let lock = NSLock()
    private let text: String
    private var count = 0
    private var bytes: Data?

    init(text: String) {
        self.text = text
    }

    var invocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    var receivedBytes: Data? {
        lock.lock()
        defer { lock.unlock() }
        return bytes
    }

    func importDocument(
        _ request: ImportRequest,
        snapshot: SourceContentSnapshot
    ) async -> ImportResult {
        do {
            let received = try snapshot.withBytes { $0 }
            record(received)
            return .success(
                request: request,
                rawDocument: RawDocument(
                    sourceURL: request.fileURL,
                    fileName: request.fileName,
                    fileExtension: request.fileExtension,
                    content: .text(text)
                )
            )
        } catch {
            return .failure(request: request, error: .readerFailure(message: "Snapshot unavailable."))
        }
    }

    private func record(_ received: Data) {
        lock.lock()
        count += 1
        bytes = received
        lock.unlock()
    }
}

private final class FailingSnapshotCoordinator: ImportFramework.ImportCoordinator, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var invocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func importDocument(
        _ request: ImportRequest,
        snapshot: SourceContentSnapshot
    ) async -> ImportResult {
        lock.lock()
        count += 1
        lock.unlock()
        return .failure(
            request: request,
            error: .readerFailure(message: "Reader rejected snapshot.")
        )
    }
}

private actor CancellationSnapshotCoordinator: ImportFramework.ImportCoordinator {
    private var invoked = false
    private var invocationContinuation: CheckedContinuation<Void, Never>?

    func importDocument(
        _ request: ImportRequest,
        snapshot: SourceContentSnapshot
    ) async -> ImportResult {
        invoked = true
        invocationContinuation?.resume()
        invocationContinuation = nil

        do {
            try await Task.sleep(for: .seconds(60))
            return .failure(request: request, error: .readerFailure(message: "Unexpected completion."))
        } catch {
            return .failure(request: request, error: .cancelled)
        }
    }

    func waitUntilInvoked() async {
        guard !invoked else { return }
        await withCheckedContinuation { continuation in
            invocationContinuation = continuation
        }
    }
}

private final class SnapshotPreparationPersistenceCoordinator: ImportPersistenceCoordinating {
    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        nil
    }
}
