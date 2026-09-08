//
// LedgerForge
// AxisBankAccountSourceEvidence.swift
// Version: 0.1.0
//

import CryptoKit
import Foundation

enum AxisBankAccountSourceEvidenceError: Error, Equatable {
    case malformedAccountIdentifier
    case malformedDeclaredStatementPeriod
    case malformedNumericReference
}

/// Shared financial semantics for the approved Axis bank-account profiles.
///
/// Source-format grammar remains owned by the CSV and PDF implementations.
/// This helper only converts already-recognized source evidence into canonical
/// parser-owned domain values.
enum AxisBankAccountSourceEvidence {

    /// Canonical source-owned cheque/reference evidence shared by the three
    /// authentic Axis bank carriers. Surrounding cell whitespace is inert;
    /// digit width is financial source data and is never a profile boundary.
    static func numericReference(
        _ sourceValue: String
    ) throws -> (value: String?, digest: String?) {
        guard !sourceValue.contains(where: \.isNewline) else {
            throw AxisBankAccountSourceEvidenceError.malformedNumericReference
        }
        let canonical = sourceValue.trimmingCharacters(in: .whitespaces)
        guard !canonical.isEmpty, canonical != "-" else {
            return (nil, nil)
        }
        guard canonical.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) else {
            throw AxisBankAccountSourceEvidenceError.malformedNumericReference
        }
        let digest = SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return (canonical, digest)
    }

    static func verifiedAccountIdentifier(
        _ sourceValue: String
    ) throws -> FinancialIdentifier {
        guard !sourceValue.isEmpty,
              sourceValue.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw AxisBankAccountSourceEvidenceError.malformedAccountIdentifier
        }

        do {
            return try FinancialIdentifier(
                kind: .institutionAccountId,
                rawValue: sourceValue,
                verificationState: .verified,
                provenance: .institutionStructuredField
            )
        } catch {
            throw AxisBankAccountSourceEvidenceError.malformedAccountIdentifier
        }
    }

    static func declaredStatementPeriod(
        startText: String,
        endText: String
    ) throws -> DeclaredStatementPeriod {
        do {
            return try DeclaredStatementPeriod(
                start: StatementDate.axisNRE(startText),
                end: StatementDate.axisNRE(endText)
            )
        } catch {
            throw AxisBankAccountSourceEvidenceError.malformedDeclaredStatementPeriod
        }
    }

    static func transactionEventEvidence(
        narration: String,
        direction: TransactionType
    ) -> AxisUPITransactionEventEvidence? {
        let canonicalNarration = narration.uppercased()
        guard let expression = try? NSRegularExpression(
            pattern: #"(?<![A-Z0-9])P2([AM])/?([0-9]{12})(?![0-9])"#
        ) else { return nil }
        let sourceRange = NSRange(canonicalNarration.startIndex..., in: canonicalNarration)
        let matches = expression.matches(in: canonicalNarration, range: sourceRange)
        guard !matches.isEmpty else {
            return nil
        }
        var candidates = Set<String>()
        for match in matches {
            guard let operationRange = Range(match.range(at: 1), in: canonicalNarration),
                  let referenceRange = Range(match.range(at: 2), in: canonicalNarration) else {
                return nil
            }
            candidates.insert(
                "\(canonicalNarration[operationRange])|\(canonicalNarration[referenceRange])"
            )
        }
        guard candidates.count == 1,
              let candidate = candidates.first else { return nil }
        let components = candidate.split(separator: "|", omittingEmptySubsequences: false)
        guard components.count == 2 else { return nil }
        let operation: AxisUPITransactionEventEvidence.Operation
        switch components[0] {
        case "A": operation = .p2a
        case "M": operation = .p2m
        default: return nil
        }
        let reference = String(components[1])

        let subtype: AxisUPITransactionEventEvidence.LedgerSubtype
        switch direction {
        case .debit:
            subtype = .posting
        case .credit:
            subtype = .creditAdjustment
        }

        return AxisUPITransactionEventEvidence(
            operation: operation,
            reference: reference,
            subtype: subtype
        )
    }
}
