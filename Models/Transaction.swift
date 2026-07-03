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

    var debit: Double?

    var credit: Double?

    var amount: Double

    var balance: Double?

    var currency: String

    var account: String

    var sourceBank: String

    var sourceFile: String
}
