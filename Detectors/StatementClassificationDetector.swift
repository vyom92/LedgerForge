//
// LedgerForge
// StatementClassificationDetector.swift
// Version: 0.1.0
//

import Foundation

struct StatementClassificationDetector: ImportFramework.StatementClassifier {
    private let rules: [StatementClassificationRule]

    init(rules: [StatementClassificationRule] = [.creditCardStatement, .bankStatement]) {
        self.rules = rules
    }

    func classify(
        document: RawDocument,
        institution: ImportInstitutionCandidate?
    ) async throws -> StatementClassification {
        if case .data = document.content {
            return StatementClassification(
                documentType: .unknown,
                confidence: 0.0,
                reasons: ["RawDocument did not contain extracted text."]
            )
        }
        if institution?.institutionCode == Institution.axis.rawValue,
           AxisCreditCardAppStructuralSignature.matches(document) {
            return StatementClassification(
                documentType: .creditCardStatement,
                confidence: 0.90,
                reasons: [
                    "Matched exact Axis bank-app tagged transaction-table structure.",
                    "Matched \(Institution.axis.rawValue) institution context."
                ]
            )
        }
        let normalizedText = Self.normalized(document.searchableText)

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
            StatementClassificationSignature(token: "TRANSACTION HISTORY", reason: "Matched transaction-history title."),
            StatementClassificationSignature(token: "CURRENT ACCOUNT-RETAIL", reason: "Matched current-account product evidence."),
            StatementClassificationSignature(token: "TRAN DATE", reason: "Matched transaction date column."),
            StatementClassificationSignature(token: "PARTICULARS", reason: "Matched transaction description column."),
            StatementClassificationSignature(token: "OPENING BALANCE", reason: "Matched opening balance label."),
            StatementClassificationSignature(token: "CLOSING BALANCE", reason: "Matched closing balance label.")
        ],
        supportingInstitutionCodes: [Institution.axis.rawValue, Institution.cbq.rawValue]
    )

    static let creditCardStatement = StatementClassificationRule(
        documentType: .creditCardStatement,
        confidence: 0.90,
        requiredMatchCount: 2,
        signatures: [
            StatementClassificationSignature(token: "THE PLATINUM CARD (QAR)", reason: "Matched the exact Amex card product."),
            StatementClassificationSignature(token: "CARD ACCOUNT NUMBER:", reason: "Matched a card-instrument section."),
            StatementClassificationSignature(token: "NEW CREDITS", reason: "Matched card liability summary evidence."),
            StatementClassificationSignature(token: "CREDIT CARD", reason: "Matched credit card statement phrase."),
            StatementClassificationSignature(token: "DATE TRANSACTION DETAILS AMOUNT (INR) DEBIT/CREDIT", reason: "Matched an exact card transaction header."),
            StatementClassificationSignature(token: "DATE TRANSACTION DETAILS MERCHANT CATEGORY AMOUNT (RS.)", reason: "Matched an exact card transaction header."),
            StatementClassificationSignature(token: "MINIMUM AMOUNT DUE", reason: "Matched minimum amount due label."),
            StatementClassificationSignature(token: "PAYMENT DUE DATE", reason: "Matched payment due date label."),
            StatementClassificationSignature(token: "TOTAL AMOUNT DUE", reason: "Matched total amount due label."),
            StatementClassificationSignature(token: "CARD ACCOUNT REFERENCE", reason: "Matched the CBQ card-account reference label."),
            StatementClassificationSignature(token: "CARD NUMBER CARD HOLDER NAME PRODUCT CARD LIMIT", reason: "Matched the CBQ companion-card header."),
            StatementClassificationSignature(token: "POST DATE PURCHASE DATE DESCRIPTION & REFERANCE FOREIGN CURRENCY AMOUNT IN QAR", reason: "Matched the CBQ card transaction header.")
        ],
        supportingInstitutionCodes: [Institution.amex.rawValue, Institution.cbq.rawValue]
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
