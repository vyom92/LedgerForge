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
            .americanExpressPlatinumQARPDF,
            .hdfcBankAccountPDF,
            .hdfcBankAccountXLS,
            .cbqCreditCardPDF,
            .cbqCurrentAccountMonthlyPDF,
            .cbqCurrentAccountHistoryPDF,
            .cbqCurrentAccountXLS,
            // Axis card signatures must precede the deliberately broad Axis
            // bank-account rule. Exact card identity and transaction-table
            // structure keep ordinary Axis account statements on their route.
            .axisCreditCard,
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

        return Self.unknownResult(reason: "No institution signatures matched.")
    }

    func detect(in document: RawDocument) -> InstitutionDetectionResult {
        guard case .data = document.content else {
            if AxisCreditCardAppStructuralSignature.matches(document) {
                return InstitutionDetectionResult(
                    metadata: DocumentMetadata(
                        institution: .axis,
                        documentType: .creditCard,
                        fileFormat: .unknown,
                        confidence: 0.995
                    ),
                    reasons: [
                        "Matched Axis source identity with the exact bank-app tagged transaction-table structure."
                    ]
                )
            }

            let applicableRules: [InstitutionDetectionRule]
            switch document.fileExtension {
            case "xls", "xlsx":
                applicableRules = rules.filter {
                    $0 != .hdfcBankAccountPDF
                        && $0 != .cbqCurrentAccountMonthlyPDF
                        && $0 != .cbqCurrentAccountHistoryPDF
                        && $0 != .cbqCreditCardPDF
                }
            case "pdf":
                applicableRules = rules.filter {
                    $0 != .hdfcBankAccountXLS
                        && $0 != .cbqCurrentAccountXLS
                }
            default:
                applicableRules = rules
            }
            return SignatureInstitutionDetector(rules: applicableRules)
                .detect(from: document.searchableText)
        }
        return Self.unknownResult(reason: "RawDocument did not contain extracted text.")
    }

    func detectInstitution(in document: RawDocument) async throws -> ImportInstitutionCandidate {
        detect(in: document).importCandidate
    }

    private static func unknownResult(reason: String) -> InstitutionDetectionResult {
        InstitutionDetectionResult(
            metadata: DocumentMetadata(
                institution: .unknown,
                documentType: .unknown,
                fileFormat: .unknown,
                confidence: 0.0
            ),
            reasons: [reason]
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

    static let axisCreditCard = InstitutionDetectionRule(
        institution: .axis,
        documentType: .creditCard,
        confidence: 0.995,
        requiredMatchCount: 3,
        signatures: [
            InstitutionSignature(token: "CREDIT CARD NUMBER", reason: "Matched the Axis card-number label."),
            InstitutionSignature(token: "TOTAL PAYMENT DUE", reason: "Matched the Axis card total-payment label."),
            InstitutionSignature(token: "DATE TRANSACTION DETAILS", reason: "Matched the Axis card transaction header."),
            InstitutionSignature(token: "AMOUNT (INR)", reason: "Matched the Axis INR card amount column."),
            InstitutionSignature(token: "DEBIT/CREDIT", reason: "Matched the Axis card liability direction column."),
            InstitutionSignature(token: "MERCHANT CATEGORY", reason: "Matched the Axis traditional card category column."),
            InstitutionSignature(token: "MINIMUM PAYMENT DUE", reason: "Matched the Axis card minimum-payment label.")
        ]
    )

    static let americanExpressPlatinumQARPDF = InstitutionDetectionRule(
        institution: .amex,
        documentType: .creditCard,
        confidence: 0.99,
        requiredMatchCount: 5,
        signatures: [
            InstitutionSignature(token: "THE PLATINUM CARD (QAR)", reason: "Matched the exact Amex Platinum QAR product."),
            InstitutionSignature(token: "STATEMENT OF ACCOUNT", reason: "Matched the Amex statement title."),
            InstitutionSignature(token: "AMEX (MIDDLE EAST) B.S.C. (C)", reason: "Matched the exact Amex Middle East issuer."),
            InstitutionSignature(token: "TRANSACTION DATE POSTING DATE DETAILS NON QAR SPENDING AMOUNT IN QAR", reason: "Matched the exact Amex financial header."),
            InstitutionSignature(token: "CARD ACCOUNT NUMBER:", reason: "Matched the Amex instrument-section identity label.")
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

    static let cbqCreditCardPDF = InstitutionDetectionRule(
        institution: .cbq,
        documentType: .creditCard,
        confidence: 0.99,
        requiredMatchCount: 5,
        signatures: [
            InstitutionSignature(
                token: "CARD ACCOUNT REFERENCE",
                reason: "Matched the exact CBQ card-account reference label."
            ),
            InstitutionSignature(
                token: "CARD NUMBER CARD HOLDER NAME PRODUCT CARD LIMIT",
                reason: "Matched the exact CBQ companion-card header."
            ),
            InstitutionSignature(
                token: "POST DATE PURCHASE DATE DESCRIPTION & REFERANCE FOREIGN CURRENCY AMOUNT IN QAR",
                reason: "Matched the exact CBQ card transaction header."
            ),
            InstitutionSignature(token: "DINERS CLUB", reason: "Matched the Diners companion section."),
            InstitutionSignature(token: "MASTERCARD PLATINUM", reason: "Matched the Mastercard companion section.")
        ]
    )

    static let cbqCurrentAccountHistoryPDF = InstitutionDetectionRule(
        institution: .cbq,
        documentType: .bankAccount,
        confidence: 0.99,
        requiredMatchCount: 2,
        signatures: [
            InstitutionSignature(
                token: "TRANSACTION HISTORY",
                reason: "Matched the exact CBQ PDF transaction-history title."
            ),
            InstitutionSignature(
                token: "CURRENT ACCOUNT-RETAIL",
                reason: "Matched the exact CBQ PDF current-account product evidence."
            )
        ]
    )

    static let cbqCurrentAccountMonthlyPDF = InstitutionDetectionRule(
        institution: .cbq,
        documentType: .bankAccount,
        confidence: 0.99,
        requiredMatchCount: 3,
        signatures: [
            InstitutionSignature(token: "ACCOUNT STATEMENT", reason: "Matched the exact CBQ monthly statement title."),
            InstitutionSignature(token: "ACCOUNT TYPE: CURRENT ACCOUNT-RETAIL", reason: "Matched the exact CBQ current-account product evidence."),
            InstitutionSignature(token: "POSTING DATE TRANSACTION DESCRIPTION TRANSACTION DATE DEBIT CREDIT BALANCE", reason: "Matched the exact CBQ monthly transaction header.")
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

/// Exact structural signature for the proven Axis bank-app credit-card PDF
/// presentation. The generic reader owns extraction; this detector consumes only
/// source identity plus the reader's tagged logical-table evidence.
/// Financial row interpretation remains in the Axis normalizer/parser.
enum AxisCreditCardAppStructuralSignature {
    private static let expectedHeader = [
        "DATE", "TRANSACTIONDETAILS", "AMOUNT(INR)", "DEBIT/CREDIT"
    ]

    static func matches(_ document: RawDocument) -> Bool {
        guard document.fileExtension == "pdf",
              let taggedTables = document.pdfTaggedTables,
              !taggedTables.isEmpty else { return false }

        let compactSource = document.searchableText
            .uppercased()
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        guard compactSource.contains("AXIS"), compactSource.contains("CREDITCARD") else {
            return false
        }

        let candidates = taggedTables.filter { table in
            guard table.rows.count > 1,
                  let header = table.rows.first,
                  header.cells.count == expectedHeader.count,
                  header.cells.allSatisfy({ $0.role == .header }) else { return false }
            let values = header.cells.compactMap(logicalCellText).map(compactHeader)
            return values == expectedHeader
        }
        return candidates.count == 1
    }

    nonisolated private static func logicalCellText(_ cell: RawPDFTaggedCellEvidence) -> String? {
        guard cell.children.count == 2,
              case .markedContent(let direct) = cell.children[0],
              case .structure(let nested) = cell.children[1],
              nested.role == "NonStruct",
              nested.markedContent.count == 1,
              let textEvidence = nested.markedContent.first,
              direct.pageNumber == textEvidence.pageNumber,
              direct.mcid != textEvidence.mcid,
              direct.rectangleCount > 0,
              direct.textBlocks.isEmpty,
              textEvidence.rectangleCount == 0,
              !textEvidence.textBlocks.isEmpty else { return nil }

        let blocks = textEvidence.textBlocks
            .map(normalizeWhitespace)
            .filter { !$0.isEmpty }
        guard blocks.count == textEvidence.textBlocks.count, !blocks.isEmpty else { return nil }
        return blocks.joined(separator: " ")
    }

    nonisolated private static func normalizeWhitespace(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func compactHeader(_ value: String) -> String {
        normalizeWhitespace(value)
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .uppercased()
    }
}
