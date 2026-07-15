//
//  Transaction.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//

import Foundation

struct AxisUPITransactionEventEvidence: Equatable, Sendable {
    enum Operation: String, Equatable, Sendable {
        case p2a
        case p2m
    }

    enum LedgerSubtype: String, Equatable, Sendable {
        case posting
        case creditAdjustment = "credit-adjustment"
    }

    let operation: Operation
    let reference: String
    let subtype: LedgerSubtype
}

struct Transaction: Identifiable {

    let id = UUID()

    var date: Date?

    var description: String

    var debit: Decimal?

    var credit: Decimal?

    var amount: Decimal

    var balance: Decimal?

    var currency: String

    var account: String

    var sourceBank: String

    var sourceFile: String

    /// Immutable persistence references retained exclusively through repository hydration.
    var repositoryAccountId: String? = nil
    var repositoryImportSessionId: String? = nil
    var verifiedAxisUPIEventEvidence: AxisUPITransactionEventEvidence? = nil
}
