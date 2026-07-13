//
//  Transaction.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//

import Foundation

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
}
