import Foundation
import Testing
@testable import LedgerForge

struct SourceContentSnapshotTests {
    private let knownDigest = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

    @Test func knownBytesMatchIndependentSHA256OracleAndExactByteCount() throws {
        let snapshot = SourceContentSnapshot(bytes: Data("abc".utf8))

        #expect(snapshot.byteCount == 3)
        #expect(snapshot.sourceByteFingerprint == VersionedDocumentFingerprint(
            algorithm: "ledgerforge.source-bytes.sha256.v1",
            digest: knownDigest,
            byteCount: 3
        ))
        #expect(try snapshot.recomputedSourceByteFingerprint() == snapshot.sourceByteFingerprint)
    }

    @Test func equalBytesHaveEqualDigestsAndOneByteChangeDoesNot() {
        let first = SourceContentSnapshot(bytes: Data("abc".utf8))
        let second = SourceContentSnapshot(bytes: Data("abc".utf8))
        let changed = SourceContentSnapshot(bytes: Data("abd".utf8))

        #expect(first.sourceByteFingerprint == second.sourceByteFingerprint)
        #expect(first.sourceByteFingerprint.digest != changed.sourceByteFingerprint.digest)
    }

    @Test func invalidationIsIdempotentAndBlocksAccessAndRecomputation() {
        let snapshot = SourceContentSnapshot(bytes: Data("bounded source".utf8))

        snapshot.invalidate()
        snapshot.invalidate()

        #expect(throws: SourceContentSnapshotError.invalidated) {
            try snapshot.withBytes { $0.count }
        }
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try snapshot.recomputedSourceByteFingerprint()
        }
    }

    @Test func concurrentReadCompletesBeforeWaitingInvalidationWithoutCrashing() async throws {
        let expected = Data("concurrent source".utf8)
        let snapshot = SourceContentSnapshot(bytes: expected)
        let readEntered = DispatchSemaphore(value: 0)
        let releaseRead = DispatchSemaphore(value: 0)
        let invalidationStarted = DispatchSemaphore(value: 0)

        // Match the test runner's user-initiated waiter and the lock owner.
        let readTask = Task.detached(priority: .high) {
            try snapshot.withBytes { bytes in
                readEntered.signal()
                guard releaseRead.wait(timeout: .now() + 5) == .success else {
                    throw SourceContentSnapshotTestError.timedOutWaitingForSignal
                }
                return bytes
            }
        }
        var invalidationTask: Task<Void, Never>?

        do {
            try await awaitSignal(readEntered)

            let task = Task.detached(priority: .high) {
                invalidationStarted.signal()
                snapshot.invalidate()
            }
            invalidationTask = task
            try await awaitSignal(invalidationStarted)
            releaseRead.signal()

            #expect(try await readTask.value == expected)
            if let invalidationTask = invalidationTask {
                await invalidationTask.value
            }
        } catch {
            releaseRead.signal()
            _ = try? await readTask.value
            if let invalidationTask = invalidationTask {
                await invalidationTask.value
            }
            throw error
        }
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try snapshot.withBytes { $0 }
        }
    }

    @Test func boundedErrorsContainNeitherSourceBytesNorDigest() {
        let sourceText = "sensitive-source-fragment"
        let snapshot = SourceContentSnapshot(bytes: Data(sourceText.utf8))
        let digest = snapshot.sourceByteFingerprint.digest
        snapshot.invalidate()

        do {
            _ = try snapshot.withBytes { $0 }
            Issue.record("Expected invalidated snapshot access to fail.")
        } catch {
            let description = error.localizedDescription
            #expect(!description.contains(sourceText))
            #expect(!description.contains(digest))
            #expect(error as? SourceContentSnapshotError == .invalidated)
        }
    }

    private enum SourceContentSnapshotTestError: Error, Sendable {
        case timedOutWaitingForSignal
    }

    private func awaitSignal(_ semaphore: DispatchSemaphore) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .default).async {
                guard semaphore.wait(timeout: .now() + 5) == .success else {
                    continuation.resume(throwing: SourceContentSnapshotTestError.timedOutWaitingForSignal)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}
