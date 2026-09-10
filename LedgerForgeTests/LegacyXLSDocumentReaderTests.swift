import Dispatch
import Foundation
import Synchronization
import Testing
@testable import LedgerForge

@MainActor
struct LegacyXLSDocumentReaderTests {
    @Test func readerSupportsExactlyXLS() {
        #expect(LegacyXLSDocumentReader().supportedFileExtensions == ["xls"])
    }

    @Test func readerCopiesAuthenticXLSBeforeSnapshotInvalidation() async throws {
        let sourceURL = try authenticXLSURL()
        let request = ImportRequest(fileURL: sourceURL)
        let snapshot = SourceContentSnapshot(bytes: try Data(contentsOf: sourceURL))
        let recorder = LegacyXLSEventRecorder()
        let reader = LegacyXLSDocumentReader { recorder.record(reader: "only", event: $0) }

        let document = try await reader.read(
            request: request, snapshot: snapshot, password: nil
        )
        snapshot.invalidate()

        guard case .tabular(let sheet) = document.content else {
            Issue.record("Expected copied tabular XLS content.")
            return
        }
        #expect(!sheet.rows.isEmpty)
        #expect(sheet.columnCount > 0)
        #expect(!sheet.name.isEmpty)
        #expect(!document.searchableText.isEmpty)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try snapshot.withBytes { $0.count }
        }
        #expect(recorder.events(for: "only") == [
            .waitingForOwner, .enteredOwner, .openedDocument, .closedDocument, .finishedRead
        ])
    }

    @Test func distinctReadersSerializeTheWholeLibXLSLifetime() async throws {
        let sourceURL = try authenticXLSURL()
        let request = ImportRequest(fileURL: sourceURL)
        let recorder = LegacyXLSEventRecorder()
        let firstGate = LegacyXLSBoundedGate()
        let firstSnapshot = SourceContentSnapshot(bytes: try Data(contentsOf: sourceURL))
        let secondSnapshot = SourceContentSnapshot(bytes: try Data(contentsOf: sourceURL))
        defer {
            firstGate.release()
            firstSnapshot.invalidate()
            secondSnapshot.invalidate()
        }
        let firstReader = LegacyXLSDocumentReader { event in
            recorder.record(reader: "first", event: event)
            if event == .openedDocument { firstGate.holdUntilReleased() }
        }
        let secondReader = LegacyXLSDocumentReader { event in
            recorder.record(reader: "second", event: event)
        }

        let first = Task.detached {
            try await firstReader.read(
                request: request, snapshot: firstSnapshot, password: nil
            )
        }
        try await waitUntil { firstGate.hasOpened }
        let second = Task.detached {
            try await secondReader.read(
                request: request, snapshot: secondSnapshot, password: nil
            )
        }
        try await waitUntil {
            recorder.events(for: "second").contains(.waitingForOwner)
        }
        #expect(!recorder.events(for: "second").contains(.enteredOwner))

        firstGate.release()
        _ = try await first.value
        _ = try await second.value
        let events = recorder.events
        let firstFinished = try #require(events.firstIndex { $0.reader == "first" && $0.event == .finishedRead })
        let secondEntered = try #require(events.firstIndex { $0.reader == "second" && $0.event == .enteredOwner })
        #expect(firstFinished < secondEntered)
        #expect(recorder.maximumActiveOwnerCount == 1)
        #expect(!firstGate.didTimeOut)
    }

    @Test func readerCancellationChecksAdmissionQueueAndCompletedCSpan() async throws {
        let sourceURL = try authenticXLSURL()
        let request = ImportRequest(fileURL: sourceURL)

        let start = LegacyXLSBoundedGate()
        let beforeRecorder = LegacyXLSEventRecorder()
        let beforeReader = LegacyXLSDocumentReader { beforeRecorder.record(reader: "before", event: $0) }
        let beforeSnapshot = SourceContentSnapshot(bytes: try Data(contentsOf: sourceURL))
        defer { beforeSnapshot.invalidate() }
        let before = Task.detached {
            start.holdUntilReleased()
            return try await beforeReader.read(
                request: request, snapshot: beforeSnapshot, password: nil
            )
        }
        before.cancel()
        start.release()
        await expectCancellation(before)
        #expect(beforeRecorder.events.isEmpty)
        #expect(!start.didTimeOut)

        let holderGate = LegacyXLSBoundedGate()
        let holderSnapshot = SourceContentSnapshot(bytes: try Data(contentsOf: sourceURL))
        let waitingSnapshot = SourceContentSnapshot(bytes: try Data(contentsOf: sourceURL))
        let waitingRecorder = LegacyXLSEventRecorder()
        defer {
            holderGate.release()
            holderSnapshot.invalidate()
            waitingSnapshot.invalidate()
        }
        let holderReader = LegacyXLSDocumentReader { event in
            if event == .openedDocument { holderGate.holdUntilReleased() }
        }
        let waitingReader = LegacyXLSDocumentReader { event in
            waitingRecorder.record(reader: "waiting", event: event)
        }
        let holder = Task.detached {
            try await holderReader.read(
                request: request, snapshot: holderSnapshot, password: nil
            )
        }
        try await waitUntil { holderGate.hasOpened }
        let waiting = Task.detached {
            try await waitingReader.read(
                request: request, snapshot: waitingSnapshot, password: nil
            )
        }
        try await waitUntil {
            waitingRecorder.events(for: "waiting").contains(.waitingForOwner)
        }
        waiting.cancel()
        holderGate.release()
        _ = try await holder.value
        await expectCancellation(waiting)
        #expect(waitingRecorder.events(for: "waiting") == [.waitingForOwner])
        #expect(!holderGate.didTimeOut)

        let openedGate = LegacyXLSBoundedGate()
        let openedSnapshot = SourceContentSnapshot(bytes: try Data(contentsOf: sourceURL))
        let openedRecorder = LegacyXLSEventRecorder()
        defer {
            openedGate.release()
            openedSnapshot.invalidate()
        }
        let openedReader = LegacyXLSDocumentReader { event in
            openedRecorder.record(reader: "opened", event: event)
            if event == .openedDocument { openedGate.holdUntilReleased() }
        }
        let opened = Task.detached {
            try await openedReader.read(
                request: request, snapshot: openedSnapshot, password: nil
            )
        }
        try await waitUntil { openedGate.hasOpened }
        opened.cancel()
        openedGate.release()
        await expectCancellation(opened)
        #expect(openedRecorder.events(for: "opened") == [
            .waitingForOwner, .enteredOwner, .openedDocument, .closedDocument, .finishedRead
        ])
        #expect(!openedGate.didTimeOut)
    }

    @Test func readerRejectsInvalidAndTruncatedOLE2() async throws {
        let invalidURL = URL(fileURLWithPath: "/tmp/invalid.xls")
        await expectFailure(
            requestURL: invalidURL,
            bytes: Data("not an OLE container".utf8),
            expected: .invalidDocument(message: "XLS workbook is malformed or unsupported.")
        )

        let source = try Data(contentsOf: FixtureLocator.fixturesRoot.appendingPathComponent("LegacyXLS/formula_cell.xls"))
        await expectInvalidDocument(
            requestURL: URL(fileURLWithPath: "/tmp/truncated.xls"),
            bytes: source.prefix(source.count / 3)
        )
    }

    @Test func readerFailsClosedForEncryptedMultiSheetHiddenFormulaAndBooleanWorkbooks() async throws {
        let fixtures: [(String, ImportError)] = [
            ("unsupported_encryption.xls", .unsupportedStatement(message: "Encrypted XLS workbooks are unsupported.")),
            ("multiple_worksheets.xls", .unsupportedStatement(message: "XLS workbooks must contain exactly one worksheet.")),
            ("hidden_worksheet.xls", .unsupportedStatement(message: "Hidden XLS worksheets are unsupported.")),
            ("formula_cell.xls", .unsupportedStatement(message: "Formula cells are unsupported in XLS imports.")),
            ("boolean_cell.xls", .unsupportedStatement(message: "Boolean and error cells are unsupported in XLS imports."))
        ]
        for (name, expected) in fixtures {
            let url = FixtureLocator.fixturesRoot
                .appendingPathComponent("LegacyXLS")
                .appendingPathComponent(name)
            await expectFailure(
                requestURL: url,
                bytes: try Data(contentsOf: url),
                expected: expected
            )
        }
    }

    @Test func readerRejectsNonXLSExtensionsBeforeOpeningSnapshot() async throws {
        let snapshot = SourceContentSnapshot(bytes: Data([0]))
        do {
            _ = try await LegacyXLSDocumentReader().read(
                request: ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/source.xlsx")),
                snapshot: snapshot,
                password: nil
            )
            Issue.record("Expected XLSX rejection.")
        } catch let error as ImportError {
            #expect(error == .unsupportedFile(extension: "xlsx"))
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func rejectedXLSPreparationsLeaveZeroAcceptedRepositoryResidue() async throws {
        let workspaceID = "workspace-rejected-generic-xls"
        let provider = DatabaseProvider(inMemory: true)
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: workspaceID,
                workspaceName: "Rejected Generic XLS"
            )
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate:
                DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )
        for name in [
            "unsupported_encryption.xls",
            "multiple_worksheets.xls",
            "hidden_worksheet.xls",
            "formula_cell.xls",
            "boolean_cell.xls"
        ] {
            let url = FixtureLocator.fixturesRoot
                .appendingPathComponent("LegacyXLS")
                .appendingPathComponent(name)
            do {
                let unexpected = try await engine.prepareImport(from: url)
                engine.cancelPreparedImport(unexpected)
                Issue.record("Expected \(name) to fail during preparation.")
            } catch {
                // Expected: the reader fails closed before confirmation exists.
            }
            #expect(try provider.workspaceRepo.workspace(id: workspaceID) == nil)
            #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
            #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspaceID).isEmpty)
        }
    }

    private func expectFailure(
        requestURL: URL,
        bytes: Data,
        expected: ImportError
    ) async {
        let snapshot = SourceContentSnapshot(bytes: bytes)
        defer { snapshot.invalidate() }
        do {
            _ = try await LegacyXLSDocumentReader().read(
                request: ImportRequest(fileURL: requestURL),
                snapshot: snapshot,
                password: nil
            )
            Issue.record("Expected XLS reader failure.")
        } catch let error as ImportError {
            #expect(error == expected)
        } catch {
            Issue.record("Expected bounded ImportError, got \(error).")
        }
    }

    private func expectInvalidDocument(requestURL: URL, bytes: Data) async {
        let snapshot = SourceContentSnapshot(bytes: bytes)
        defer { snapshot.invalidate() }
        do {
            _ = try await LegacyXLSDocumentReader().read(
                request: ImportRequest(fileURL: requestURL),
                snapshot: snapshot,
                password: nil
            )
            Issue.record("Expected invalid XLS rejection.")
        } catch let error as ImportError {
            guard case .invalidDocument = error else {
                Issue.record("Expected invalidDocument, got \(error).")
                return
            }
        } catch {
            Issue.record("Expected bounded ImportError, got \(error).")
        }
    }

    private func authenticXLSURL() throws -> URL {
        try AuthenticSourceTestSupport.axisBankCSV()
            .deletingPathExtension()
            .appendingPathExtension("xls")
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while !condition() {
            guard clock.now < deadline else { throw LegacyXLSTestError.timedOut }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    private func expectCancellation(_ task: Task<RawDocument, Error>) async {
        do {
            _ = try await task.value
            Issue.record("Expected cancellation.")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, got \(error).")
        }
    }

}

private enum LegacyXLSTestError: Error {
    case timedOut
}

private struct LegacyXLSEventRecord: Equatable, Sendable {
    let reader: String
    let event: LegacyXLSDocumentReader.Event
}

private final class LegacyXLSEventRecorder: Sendable {
    private struct State: Sendable {
        var events: [LegacyXLSEventRecord] = []
        var activeOwnerCount = 0
        var maximumActiveOwnerCount = 0
    }

    private let state = Mutex(State())

    func record(reader: String, event: LegacyXLSDocumentReader.Event) {
        state.withLock { state in
            state.events.append(LegacyXLSEventRecord(reader: reader, event: event))
            switch event {
            case .enteredOwner:
                state.activeOwnerCount += 1
                state.maximumActiveOwnerCount = max(state.maximumActiveOwnerCount, state.activeOwnerCount)
            case .finishedRead:
                state.activeOwnerCount -= 1
            case .waitingForOwner, .openedDocument, .closedDocument:
                break
            }
        }
    }

    var events: [LegacyXLSEventRecord] { state.withLock { $0.events } }
    var maximumActiveOwnerCount: Int { state.withLock { $0.maximumActiveOwnerCount } }

    func events(for reader: String) -> [LegacyXLSDocumentReader.Event] {
        state.withLock { state in
            state.events.filter { $0.reader == reader }.map(\.event)
        }
    }
}

private final class LegacyXLSBoundedGate: Sendable {
    private let releaseSignal = DispatchSemaphore(value: 0)
    private let opened = Mutex(false)
    private let timedOut = Mutex(false)

    var hasOpened: Bool { opened.withLock { $0 } }
    var didTimeOut: Bool { timedOut.withLock { $0 } }

    func holdUntilReleased() {
        opened.withLock { $0 = true }
        if releaseSignal.wait(timeout: .now() + 5) == .timedOut {
            timedOut.withLock { $0 = true }
        }
    }

    func release() {
        releaseSignal.signal()
    }
}
