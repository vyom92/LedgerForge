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

        let readTask = Task.detached {
            try snapshot.withBytes { bytes in
                readEntered.signal()
                releaseRead.wait()
                return bytes
            }
        }
        readEntered.wait()

        let invalidationTask = Task.detached {
            invalidationStarted.signal()
            snapshot.invalidate()
        }
        invalidationStarted.wait()
        releaseRead.signal()

        #expect(try await readTask.value == expected)
        await invalidationTask.value
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
}
