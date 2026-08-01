//
// LedgerForge
// AxisBankAccountSourceEvidence.swift
// Version: 0.1.0
//

import Foundation

enum AxisBankAccountSourceEvidenceError: Error, Equatable {
    case malformedAccountIdentifier
    case malformedDeclaredStatementPeriod
}

/// Shared financial semantics for the approved Axis bank-account profiles.
///
/// Source-format grammar remains owned by the CSV and PDF implementations.
/// This helper only converts already-recognized source evidence into canonical
/// parser-owned domain values.
enum AxisBankAccountSourceEvidence {

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
        let components = narration.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count >= 4, components[0] == "UPI" else { return nil }

        let operation: AxisUPITransactionEventEvidence.Operation
        switch components[1] {
        case "P2A":
            operation = .p2a
        case "P2M":
            operation = .p2m
        default:
            return nil
        }

        let reference = String(components[2])
        guard reference.count == 12,
              reference.unicodeScalars.allSatisfy({
                  $0.value >= UnicodeScalar("0").value &&
                  $0.value <= UnicodeScalar("9").value
              }) else {
            return nil
        }

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
