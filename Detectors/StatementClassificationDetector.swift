//
// LedgerForge
// StatementClassificationDetector.swift
// Version: 0.1.0
//

import Foundation

struct StatementClassificationDetector: ImportFramework.StatementClassifier {
    private let rules: [StatementClassificationRule]

    init(rules: [StatementClassificationRule] = [.bankStatement, .creditCardStatement]) {
        self.rules = rules
    }

    func classify(
        document: RawDocument,
        institution: ImportInstitutionCandidate?
    ) async throws -> StatementClassification {
        guard case .text(let text) = document.content else {
            return StatementClassification(
                documentType: .unknown,
                confidence: 0.0,
                reasons: ["RawDocument did not contain extracted text."]
            )
        }

        let normalizedText = Self.normalized(text)

        for rule in rules {
            if let classification = rule.classify(
                normalizedText: normalizedText,
                institution: institution
            ) {
                return classification
            }
        }

        return StatementClassification(
            documentType: .unknown,
            confidence: 0.0,
            reasons: ["No statement classification signatures matched."]
        )
    }

    private static func normalized(_ text: String) -> String {
        text
            .uppercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct StatementClassificationRule: Equatable, Sendable {
    let documentType: StatementDocumentType
    let confidence: Double
    let requiredMatchCount: Int
    let signatures: [StatementClassificationSignature]
    let supportingInstitutionCodes: [String]

    func classify(
        normalizedText: String,
        institution: ImportInstitutionCandidate?
    ) -> StatementClassification? {
        var reasons = signatures.compactMap { signature -> String? in
            normalizedText.contains(signature.normalizedToken) ? signature.reason : nil
        }

        if let institutionCode = institution?.institutionCode,
           supportingInstitutionCodes.contains(institutionCode) {
            reasons.append("Matched \(institutionCode) institution context.")
        }

        guard reasons.count >= requiredMatchCount else {
            return nil
        }

        return StatementClassification(
            documentType: documentType,
            confidence: confidence,
            reasons: reasons
        )
    }

    static let bankStatement = StatementClassificationRule(
        documentType: .bankStatement,
        confidence: 0.95,
        requiredMatchCount: 2,
        signatures: [
            StatementClassificationSignature(token: "STATEMENT OF ACCOUNT", reason: "Matched account statement title."),
            StatementClassificationSignature(token: "STATEMENT OF AXIS ACCOUNT", reason: "Matched Axis account statement title."),
            StatementClassificationSignature(token: "TRAN DATE", reason: "Matched transaction date column."),
            StatementClassificationSignature(token: "PARTICULARS", reason: "Matched transaction description column."),
            StatementClassificationSignature(token: "OPENING BALANCE", reason: "Matched opening balance label."),
            StatementClassificationSignature(token: "CLOSING BALANCE", reason: "Matched closing balance label.")
        ],
        supportingInstitutionCodes: [Institution.axis.rawValue]
    )

    static let creditCardStatement = StatementClassificationRule(
        documentType: .creditCardStatement,
        confidence: 0.90,
        requiredMatchCount: 2,
        signatures: [
            StatementClassificationSignature(token: "CREDIT CARD", reason: "Matched credit card statement phrase."),
            StatementClassificationSignature(token: "MINIMUM AMOUNT DUE", reason: "Matched minimum amount due label."),
            StatementClassificationSignature(token: "PAYMENT DUE DATE", reason: "Matched payment due date label."),
            StatementClassificationSignature(token: "TOTAL AMOUNT DUE", reason: "Matched total amount due label.")
        ],
        supportingInstitutionCodes: []
    )
}

struct StatementClassificationSignature: Equatable, Sendable {
    let token: String
    let reason: String

    var normalizedToken: String {
        token.uppercased()
    }
}

extension StatementDocumentType {
    var legacyDocumentType: DocumentType {
        switch self {
        case .bankStatement:
            return .bankAccount
        case .creditCardStatement:
            return .creditCard
        case .brokerageStatement:
            return .investment
        case .salaryStatement:
            return .salarySlip
        case .taxDocument:
            return .tax
        case .insuranceStatement, .unknown:
            return .unknown
        }
    }
}
