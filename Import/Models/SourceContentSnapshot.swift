// Import/Models/SourceContentSnapshot.swift
// Transient, immutable source-byte authority for one import preparation.

import CryptoKit
import Foundation

nonisolated struct VersionedDocumentFingerprint: Equatable, Hashable, Sendable {
    let algorithm: String
    let digest: String
    let byteCount: Int64
    let isDuplicateAuthority: Bool

    init(
        algorithm: String,
        digest: String,
        byteCount: Int64,
        isDuplicateAuthority: Bool = false
    ) {
        self.algorithm = algorithm
        self.digest = digest
        self.byteCount = byteCount
        self.isDuplicateAuthority = isDuplicateAuthority
    }

    var isValid: Bool {
        byteCount >= 0
            && digest.count == 64
            && digest.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

/// Transient confirmation-time representation of every digest derived from one
/// acquired source. Byte counts remain in memory; persistence receives only the
/// algorithm, digest, and duplicate-authority role.
nonisolated struct PreparedDocumentFingerprintSet: Equatable, Sendable {
    let fingerprints: [VersionedDocumentFingerprint]

    init(fingerprints: [VersionedDocumentFingerprint]) {
        self.fingerprints = fingerprints.sorted {
            if $0.algorithm != $1.algorithm { return $0.algorithm < $1.algorithm }
            return $0.digest < $1.digest
        }
    }

    init(rawText: ExactStatementFingerprint, sourceBytes: VersionedDocumentFingerprint) {
        self.init(fingerprints: [
            VersionedDocumentFingerprint(
                algorithm: rawText.algorithm,
                digest: rawText.digest,
                byteCount: rawText.byteCount,
                isDuplicateAuthority: true
            ),
            VersionedDocumentFingerprint(
                algorithm: sourceBytes.algorithm,
                digest: sourceBytes.digest,
                byteCount: sourceBytes.byteCount,
                isDuplicateAuthority: false
            )
        ])
    }

    var isValid: Bool {
        !fingerprints.isEmpty
            && Set(fingerprints.map(\.algorithm)).count == fingerprints.count
            && fingerprints.allSatisfy(\.isValid)
            && fingerprints.filter(\.isDuplicateAuthority).count == 1
    }

    var duplicateAuthority: VersionedDocumentFingerprint? {
        guard isValid else { return nil }
        return fingerprints.first(where: \.isDuplicateAuthority)
    }
}

nonisolated enum SourceContentSnapshotError: Error, Equatable, LocalizedError, Sendable {
    case acquisitionFailed
    case invalidated

    var errorDescription: String? {
        switch self {
        case .acquisitionFailed:
            return "The selected source document could not be read."
        case .invalidated:
            return "The source content snapshot is no longer available."
        }
    }
}

public nonisolated final class SourceContentSnapshot: @unchecked Sendable {
    static let algorithm = "ledgerforge.source-bytes.sha256.v1"

    let id: UUID
    let byteCount: Int64
    let sourceByteFingerprint: VersionedDocumentFingerprint

    private final class Storage {
        let bytes: Data

        init(bytes: Data) {
            self.bytes = bytes
        }
    }

    private let lock = NSLock()
    private var storage: Storage?

    init(id: UUID = UUID(), bytes: Data) {
        self.id = id
        self.byteCount = Int64(bytes.count)
        self.sourceByteFingerprint = Self.fingerprint(for: bytes)
        self.storage = Storage(bytes: bytes)
    }

    deinit {
        invalidate()
    }

    func withBytes<T>(_ body: (Data) throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }

        guard let storage else {
            throw SourceContentSnapshotError.invalidated
        }
        return try body(storage.bytes)
    }

    func recomputedSourceByteFingerprint() throws -> VersionedDocumentFingerprint {
        try withBytes { Self.fingerprint(for: $0) }
    }

    func invalidate() {
        lock.lock()
        storage = nil
        lock.unlock()
    }

    private static func fingerprint(for bytes: Data) -> VersionedDocumentFingerprint {
        VersionedDocumentFingerprint(
            algorithm: algorithm,
            digest: SHA256.hash(data: bytes)
                .map { String(format: "%02x", $0) }
                .joined(),
            byteCount: Int64(bytes.count),
            isDuplicateAuthority: false
        )
    }
}
