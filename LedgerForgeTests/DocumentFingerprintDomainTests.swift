import Foundation
import Testing
@testable import LedgerForge

let packet2RawDigest = String(repeating: "1", count: 64)
let packet2SourceDigest = String(repeating: "2", count: 64)

struct Packet2FingerprintSpec {
    let id: String
    let algorithm: String
    let digest: String
    let isAuthority: Bool
    var documentID: String?
    var sessionID: String?
}

func packet2Plan(
    generationToken: ProviderGenerationToken,
    suffix: String,
    specs: [Packet2FingerprintSpec],
    accountChoice: ConfirmedImportAccountChoiceDTO = .createProposedAccount,
    identifier: String? = nil
) -> ConfirmedImportPlanDTO {
    let base = confirmedImportPlan(
        generationToken: generationToken,
        accountChoice: accountChoice,
        identifier: identifier ?? "packet2-\(suffix)",
        fingerprint: packet2RawDigest,
        suffix: suffix
    )
    let oldHistory = base.historyTemplate
    let oldDocument = oldHistory.document
    let document = ImportedDocumentDTO(
        id: oldDocument.id,
        workspaceId: oldDocument.workspaceId,
        importSessionId: oldDocument.importSessionId,
        filename: oldDocument.filename,
        mimeType: oldDocument.mimeType,
        sizeBytes: oldDocument.sizeBytes,
        legacyRawTextSHA256: packet2RawDigest,
        createdAtISO: oldDocument.createdAtISO
    )
    let fingerprints = specs.map {
        DocumentFingerprintDTO(
            id: $0.id,
            documentId: $0.documentID ?? document.id,
            importSessionId: $0.sessionID ?? oldHistory.importSession.id,
            algorithm: $0.algorithm,
            fingerprint: $0.digest,
            fingerprintData: nil,
            isDuplicateAuthority: $0.isAuthority,
            createdAtISO: oldHistory.completedAtISO
        )
    }
    let history = ConfirmedImportHistoryTemplateDTO(
        document: document,
        fingerprints: fingerprints,
        importSession: oldHistory.importSession,
        completedAtISO: oldHistory.completedAtISO,
        successfulAttempt: oldHistory.successfulAttempt,
        normalizedDocument: oldHistory.normalizedDocument,
        normalizedRows: oldHistory.normalizedRows
    )
    return ConfirmedImportPlanDTO(
        providerGeneration: base.providerGeneration,
        workspace: base.workspace,
        proposedAccount: base.proposedAccount,
        accountChoice: base.accountChoice,
        advisoryIdentity: base.advisoryIdentity,
        identifiers: base.identifiers,
        historyTemplate: history,
        transactionTemplates: base.transactionTemplates,
        declaredStatementStartISO: base.declaredStatementStartISO,
        declaredStatementEndISO: base.declaredStatementEndISO,
        openingBalanceMinor: base.openingBalanceMinor,
        openingBalanceDecimal: base.openingBalanceDecimal,
        closingBalanceMinor: base.closingBalanceMinor,
        closingBalanceDecimal: base.closingBalanceDecimal
    )
}

func packet2RawAuthority(id: String = "fingerprint-raw", digest: String = packet2RawDigest) -> Packet2FingerprintSpec {
    Packet2FingerprintSpec(
        id: id,
        algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm,
        digest: digest,
        isAuthority: true
    )
}

func packet2SourceSecondary(id: String = "fingerprint-source", digest: String = packet2SourceDigest) -> Packet2FingerprintSpec {
    Packet2FingerprintSpec(
        id: id,
        algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
        digest: digest,
        isAuthority: false
    )
}

private func packet2ReviewedDigest(_ plan: ConfirmedImportPlanDTO) -> String {
    ReviewedPartialImportPlanDTO(
        id: "reviewed-packet2",
        basePlan: plan,
        existingAccountId: "existing-account",
        rows: [],
        sourceRowCount: 0,
        recognizedCount: 0,
        importedCount: 0,
        blockedCount: 0
    ).digest
}

struct DocumentFingerprintDomainTests {
    @Test func oneRawTextAuthorityIsValid() throws {
        let provider = InMemoryRepositoryProvider()
        let plan = packet2Plan(generationToken: provider.generationToken, suffix: "domain-one", specs: [packet2RawAuthority()])

        try plan.historyTemplate.validateFingerprints()
        #expect(plan.historyTemplate.duplicateAuthorityFingerprint?.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm)
    }

    @Test func rawTextAndSourceBytesWithOneAuthorityAreValidAndSorted() throws {
        let provider = InMemoryRepositoryProvider()
        let plan = packet2Plan(
            generationToken: provider.generationToken,
            suffix: "domain-two",
            specs: [packet2SourceSecondary(), packet2RawAuthority()]
        )

        try plan.historyTemplate.validateFingerprints()
        #expect(plan.historyTemplate.fingerprints.map(\.algorithm) == [
            DocumentFingerprintDTO.rawTextSHA256Algorithm,
            DocumentFingerprintDTO.sourceBytesSHA256Algorithm
        ])
    }

    @Test(arguments: [
        [Packet2FingerprintSpec(id: "raw", algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm, digest: packet2RawDigest, isAuthority: false)],
        [packet2RawAuthority(), Packet2FingerprintSpec(id: "source", algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, digest: packet2SourceDigest, isAuthority: true)]
    ])
    func invalidAuthorityCountsReject(_ specs: [Packet2FingerprintSpec]) {
        let provider = InMemoryRepositoryProvider()
        let plan = packet2Plan(generationToken: provider.generationToken, suffix: UUID().uuidString, specs: specs)
        #expect(throws: DocumentFingerprintValidationError.invalidAuthorityCount) {
            try plan.historyTemplate.validateFingerprints()
        }
    }

    @Test func duplicateAlgorithmsReject() {
        let provider = InMemoryRepositoryProvider()
        let plan = packet2Plan(generationToken: provider.generationToken, suffix: "duplicate-algorithm", specs: [
            packet2RawAuthority(id: "raw-a"),
            Packet2FingerprintSpec(id: "raw-b", algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm, digest: String(repeating: "3", count: 64), isAuthority: false)
        ])
        #expect(throws: DocumentFingerprintValidationError.duplicateAlgorithm) {
            try plan.historyTemplate.validateFingerprints()
        }
    }

    @Test func duplicateIdentifiersReject() {
        let provider = InMemoryRepositoryProvider()
        let plan = packet2Plan(generationToken: provider.generationToken, suffix: "duplicate-id", specs: [
            packet2RawAuthority(id: "same"),
            packet2SourceSecondary(id: "same")
        ])
        #expect(throws: DocumentFingerprintValidationError.duplicateIdentifier) {
            try plan.historyTemplate.validateFingerprints()
        }
    }

    @Test func malformedAlgorithmAndDigestErrorsDoNotExposeDigest() {
        let provider = InMemoryRepositoryProvider()
        let privateValue = "PRIVATE-DIGEST-VALUE"
        let malformedAlgorithm = packet2Plan(generationToken: provider.generationToken, suffix: "bad-algorithm", specs: [
            Packet2FingerprintSpec(id: "bad", algorithm: "sha256", digest: privateValue, isAuthority: true)
        ])
        let malformedDigest = packet2Plan(generationToken: provider.generationToken, suffix: "bad-digest", specs: [
            packet2RawAuthority(digest: privateValue)
        ])

        do {
            try malformedAlgorithm.historyTemplate.validateFingerprints()
            Issue.record("Expected unsupported algorithm rejection.")
        } catch {
            #expect(error as? DocumentFingerprintValidationError == .unsupportedAlgorithm)
            #expect(!error.localizedDescription.contains(privateValue))
        }
        do {
            try malformedDigest.historyTemplate.validateFingerprints()
            Issue.record("Expected malformed digest rejection.")
        } catch {
            #expect(error as? DocumentFingerprintValidationError == .malformedDigest)
            #expect(!error.localizedDescription.contains(privateValue))
        }
    }

    @Test func reviewedPlanDigestIsOrderIndependentAndCoversEveryFingerprintField() {
        let provider = InMemoryRepositoryProvider()
        let originalSpecs = [packet2RawAuthority(), packet2SourceSecondary()]
        let original = packet2Plan(generationToken: provider.generationToken, suffix: "digest", specs: originalSpecs)
        let reversed = packet2Plan(generationToken: provider.generationToken, suffix: "digest", specs: Array(originalSpecs.reversed()))
        let baseline = packet2ReviewedDigest(original)

        #expect(baseline == packet2ReviewedDigest(reversed))

        let variants: [[Packet2FingerprintSpec]] = [
            [packet2RawAuthority(id: "changed-id"), packet2SourceSecondary()],
            [Packet2FingerprintSpec(id: "fingerprint-raw", algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, digest: packet2RawDigest, isAuthority: true), Packet2FingerprintSpec(id: "fingerprint-source", algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm, digest: packet2SourceDigest, isAuthority: false)],
            [packet2RawAuthority(digest: String(repeating: "4", count: 64)), packet2SourceSecondary()],
            [Packet2FingerprintSpec(id: "fingerprint-raw", algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm, digest: packet2RawDigest, isAuthority: false), Packet2FingerprintSpec(id: "fingerprint-source", algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, digest: packet2SourceDigest, isAuthority: true)],
            [Packet2FingerprintSpec(id: "fingerprint-raw", algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm, digest: packet2RawDigest, isAuthority: true, documentID: "other-document"), packet2SourceSecondary()],
            [Packet2FingerprintSpec(id: "fingerprint-raw", algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm, digest: packet2RawDigest, isAuthority: true, sessionID: "other-session"), packet2SourceSecondary()]
        ]
        for specs in variants {
            #expect(packet2ReviewedDigest(packet2Plan(generationToken: provider.generationToken, suffix: "digest", specs: specs)) != baseline)
        }
    }
}
