import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Carrier/fingerprint mechanics use full registered originals. Source-family
/// support is separately qualified against every registered carrier and oracle.
@MainActor
struct ImportPersistenceFormatAuthorityMapperTests {
    @Test(.globalRuntimeStateIsolation)
    func authenticCarriersKeepExactFormatAndFingerprintAuthority() async throws {
        let sourceDirectory = try AuthenticSourceTestSupport.axisBankCSV().deletingLastPathComponent()
        let formats: [(FileFormat, String, String)] = [
            (.csv, "csv", "text/csv"),
            (.pdf, "pdf", "application/pdf"),
            (.xls, "xls", "application/vnd.ms-excel")
        ]
        for (format, ext, mime) in formats {
            let source = sourceDirectory.appendingPathComponent("Axis NRE FY25-26.\(ext)")
            let bytes = try Data(contentsOf: source)
            let sourceDigest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            let provider = DatabaseProvider(inMemory: true)
            let engine = ImportEngine(
                importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
                persistenceStateProvider: { provider.persistenceState },
                providerGenerationProvider: { provider.generationToken }
            )
            let prepared = try await engine.prepareImport(from: source)
            defer { engine.cancelPreparedImport(prepared) }
            #expect(prepared.validation.passed)
            #expect(prepared.financialDocument.metadata.fileFormat == format)
            let sourceFingerprint = try #require(prepared.fingerprintSet.fingerprints.first {
                $0.algorithm == DocumentFingerprintDTO.sourceBytesSHA256Algorithm
            })
            let rawFingerprint = try #require(prepared.fingerprintSet.fingerprints.first {
                $0.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm
            })
            #expect(sourceFingerprint.digest == sourceDigest)
            #expect(sourceFingerprint.byteCount == bytes.count)
            let expectedAuthority = format == .csv ? rawFingerprint : sourceFingerprint
            #expect(prepared.fingerprintSet.duplicateAuthority == expectedAuthority)

            let payload = try ImportPersistenceMapper().payload(
                financialDocument: prepared.financialDocument,
                importSession: prepared.importSession,
                validation: prepared.validation,
                accountId: "format-authority-account",
                fingerprintSet: prepared.fingerprintSet
            )
            #expect(payload.document.mimeType == mime)
            #expect(payload.document.sizeBytes == expectedAuthority.byteCount)
            #expect(payload.document.legacyRawTextSHA256 == rawFingerprint.digest)
            #expect(payload.fingerprint.algorithm == expectedAuthority.algorithm)
            #expect(payload.fingerprint.fingerprint == expectedAuthority.digest)
            #expect(payload.fingerprints.map(\.algorithm) == prepared.fingerprintSet.fingerprints.map(\.algorithm))
            #expect(payload.fingerprints.map(\.fingerprint) == prepared.fingerprintSet.fingerprints.map(\.digest))
            #expect(payload.fingerprints.allSatisfy { $0.fingerprintData == nil })
            #expect(try Data(contentsOf: source) == bytes)
        }
    }
}
