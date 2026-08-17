//
// LedgerForge
// SignatureInstitutionDetector.swift
// Version: 0.1.0
//

import Foundation

struct InstitutionDetectionResult: Equatable, Sendable {
    let metadata: DocumentMetadata
    let reasons: [String]

    var importCandidate: ImportInstitutionCandidate {
        ImportInstitutionCandidate(
            institutionCode: metadata.institution == .unknown ? nil : metadata.institution.rawValue,
            confidence: metadata.confidence,
            reasons: reasons
        )
    }
}

struct SignatureInstitutionDetector: ImportFramework.InstitutionDetector {
    private let rules: [InstitutionDetectionRule]

    init(
        rules: [InstitutionDetectionRule] = [
            .hdfcBankAccountPDF,
            .hdfcBankAccountXLS,
            .cbqCurrentAccountXLS,
            .axisBankAccount
        ]
    ) {
        self.rules = rules
    }

    func detect(from text: String) -> InstitutionDetectionResult {
        let normalizedText = Self.normalized(text)

        for rule in rules {
            if let result = rule.detect(in: normalizedText) {
                return result
            }
        }

        return InstitutionDetectionResult(
            metadata: DocumentMetadata(
                institution: .unknown,
                documentType: .unknown,
                fileFormat: .unknown,
                confidence: 0.0
            ),
            reasons: ["No institution signatures matched."]
        )
    }

    func detectInstitution(in document: RawDocument) async throws -> ImportInstitutionCandidate {
        guard case .data = document.content else {
            return detect(from: document.searchableText).importCandidate
        }
        return ImportInstitutionCandidate(
            institutionCode: nil,
            confidence: 0.0,
            reasons: ["RawDocument did not contain extracted text."]
        )
    }

    private static func normalized(_ text: String) -> String {
        text
            .uppercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct InstitutionDetectionRule: Equatable, Sendable {
    let institution: Institution
    let documentType: DocumentType
    let confidence: Double
    let requiredMatchCount: Int
    let signatures: [InstitutionSignature]

    func detect(in normalizedText: String) -> InstitutionDetectionResult? {
        let matchedReasons = signatures.compactMap { signature -> String? in
            normalizedText.contains(signature.normalizedToken) ? signature.reason : nil
        }

        guard matchedReasons.count >= requiredMatchCount else {
            return nil
        }

        return InstitutionDetectionResult(
            metadata: DocumentMetadata(
                institution: institution,
                documentType: documentType,
                fileFormat: .unknown,
                confidence: confidence
            ),
            reasons: matchedReasons
        )
    }

    static let axisBankAccount = InstitutionDetectionRule(
        institution: .axis,
        documentType: .bankAccount,
        confidence: 0.98,
        requiredMatchCount: 1,
        signatures: [
            InstitutionSignature(token: "AXIS BANK", reason: "Matched Axis Bank name."),
            InstitutionSignature(token: "UTIB", reason: "Matched Axis Bank IFSC prefix."),
            InstitutionSignature(token: "STATEMENT OF AXIS ACCOUNT", reason: "Matched Axis account statement title.")
        ]
    )

    static let hdfcBankAccountPDF = InstitutionDetectionRule(
        institution: .hdfc,
        documentType: .bankAccount,
        confidence: 0.99,
        requiredMatchCount: 3,
        signatures: [
            InstitutionSignature(
                token: "HDFC BANK LIMITED",
                reason: "Matched the exact HDFC PDF bank name."
            ),
            InstitutionSignature(
                token: "STATEMENT OF ACCOUNT",
                reason: "Matched the exact HDFC PDF account-statement title."
            ),
            InstitutionSignature(
                token: "DATE NARRATION CHQ./REF.NO. VALUE DT WITHDRAWAL AMT. DEPOSIT AMT. CLOSING BALANCE",
                reason: "Matched the exact HDFC bank-statement header."
            )
        ]
    )

    static let hdfcBankAccountXLS = InstitutionDetectionRule(
        institution: .hdfc,
        documentType: .bankAccount,
        confidence: 0.99,
        requiredMatchCount: 3,
        signatures: [
            InstitutionSignature(
                token: "HDFC BANK LTD.",
                reason: "Matched HDFC Bank name."
            ),
            InstitutionSignature(
                token: "STATEMENT OF ACCOUNTS",
                reason: "Matched HDFC account-statement title."
            ),
            InstitutionSignature(
                token: "DATE NARRATION CHQ./REF.NO. VALUE DT WITHDRAWAL AMT. DEPOSIT AMT. CLOSING BALANCE",
                reason: "Matched the exact HDFC bank-statement header."
            )
        ]
    )

    static let cbqCurrentAccountXLS = InstitutionDetectionRule(
        institution: .cbq,
        documentType: .bankAccount,
        confidence: 0.99,
        requiredMatchCount: 3,
        signatures: [
            InstitutionSignature(
                token: "TRANSACTION HISTORY",
                reason: "Matched the exact CBQ transaction-history title."
            ),
            InstitutionSignature(
                token: "CURRENT ACCOUNT-RETAIL",
                reason: "Matched the exact CBQ current-account product evidence."
            ),
            InstitutionSignature(
                token: "DATE DETAILS AMOUNT BALANCE",
                reason: "Matched the exact CBQ current-account transaction header."
            )
        ]
    )
}

struct InstitutionSignature: Equatable, Sendable {
    let token: String
    let reason: String

    var normalizedToken: String {
        token.uppercased()
    }
}
