import Testing
@testable import LedgerForge

/// Pure value-semantics checks for transient fingerprint envelopes. No source,
/// statement, persistence DTO, or financial fact is constructed here.
struct DocumentFingerprintDomainTests {
    private let rawAlgorithm = "ledgerforge.raw-text.sha256.v1"
    private let sourceAlgorithm = "ledgerforge.source-bytes.sha256.v1"
    private let rawDigest = String(repeating: "1", count: 64)
    private let sourceDigest = String(repeating: "2", count: 64)

    @Test
    func fingerprintsAreDeterministicallySortedAndExposeExactlyOneAuthority() throws {
        let source = VersionedDocumentFingerprint(
            algorithm: sourceAlgorithm,
            digest: sourceDigest,
            byteCount: 20
        )
        let raw = VersionedDocumentFingerprint(
            algorithm: rawAlgorithm,
            digest: rawDigest,
            byteCount: 10,
            isDuplicateAuthority: true
        )

        let set = PreparedDocumentFingerprintSet(fingerprints: [source, raw])

        #expect(set.isValid)
        #expect(set.fingerprints.map(\.algorithm) == [rawAlgorithm, sourceAlgorithm])
        #expect(set.duplicateAuthority == raw)
    }

    @Test(arguments: [
        [
            VersionedDocumentFingerprint(
                algorithm: "ledgerforge.raw-text.sha256.v1",
                digest: String(repeating: "1", count: 64),
                byteCount: 1
            )
        ],
        [
            VersionedDocumentFingerprint(
                algorithm: "ledgerforge.raw-text.sha256.v1",
                digest: String(repeating: "1", count: 64),
                byteCount: 1,
                isDuplicateAuthority: true
            ),
            VersionedDocumentFingerprint(
                algorithm: "ledgerforge.source-bytes.sha256.v1",
                digest: String(repeating: "2", count: 64),
                byteCount: 2,
                isDuplicateAuthority: true
            )
        ]
    ])
    func invalidAuthorityCountsFailClosed(_ fingerprints: [VersionedDocumentFingerprint]) {
        let set = PreparedDocumentFingerprintSet(fingerprints: fingerprints)

        #expect(!set.isValid)
        #expect(set.duplicateAuthority == nil)
    }

    @Test
    func duplicateAlgorithmsFailClosed() {
        let set = PreparedDocumentFingerprintSet(fingerprints: [
            VersionedDocumentFingerprint(
                algorithm: rawAlgorithm,
                digest: rawDigest,
                byteCount: 10,
                isDuplicateAuthority: true
            ),
            VersionedDocumentFingerprint(
                algorithm: rawAlgorithm,
                digest: sourceDigest,
                byteCount: 20
            )
        ])

        #expect(!set.isValid)
        #expect(set.duplicateAuthority == nil)
    }

    @Test(arguments: [
        VersionedDocumentFingerprint(
            algorithm: "ledgerforge.raw-text.sha256.v1",
            digest: String(repeating: "F", count: 64),
            byteCount: 1,
            isDuplicateAuthority: true
        ),
        VersionedDocumentFingerprint(
            algorithm: "ledgerforge.raw-text.sha256.v1",
            digest: String(repeating: "0", count: 63),
            byteCount: 1,
            isDuplicateAuthority: true
        ),
        VersionedDocumentFingerprint(
            algorithm: "ledgerforge.raw-text.sha256.v1",
            digest: String(repeating: "0", count: 64),
            byteCount: -1,
            isDuplicateAuthority: true
        )
    ])
    func malformedDigestOrByteCountFailsClosed(_ fingerprint: VersionedDocumentFingerprint) {
        #expect(!fingerprint.isValid)
        #expect(!PreparedDocumentFingerprintSet(fingerprints: [fingerprint]).isValid)
    }
}
