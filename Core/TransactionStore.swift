//
//  TransactionStore.swift
//  LedgerForge
//
//  Created by Copilot on 06/07/26.
//

import Foundation
import Combine

/// TransactionStore is the single owner of imported Transaction objects.
/// Responsibilities:
/// - publish transactions
/// - replace transactions after a successful import
/// - store validation metadata
/// - provide simple filtering/search helpers
final class TransactionStore: ObservableObject {

    static let shared = TransactionStore()

    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var lastValidation: ImportValidationResult?

    private init() {}

    // Replace all transactions after a successful import and store validation result.
    func replaceTransactions(_ transactions: [Transaction], validation: ImportValidationResult? = nil) {
        let update = {
            self.transactions = transactions
            self.lastValidation = validation
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }
    
    // Simple search by description, account, file, or bank (case-insensitive)
    func search(_ text: String) -> [Transaction] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return transactions }
        return transactions.filter {
            $0.description.localizedCaseInsensitiveContains(trimmedText) ||
            $0.account.localizedCaseInsensitiveContains(trimmedText) ||
            $0.sourceFile.localizedCaseInsensitiveContains(trimmedText) ||
            $0.sourceBank.localizedCaseInsensitiveContains(trimmedText)
        }
    }

    // Filter transactions using a predicate
    func filter(_ predicate: (Transaction) -> Bool) -> [Transaction] {
        transactions.filter(predicate)
    }

    // Transactions for a specific account name
    func transactions(forAccount name: String) -> [Transaction] {
        transactions.filter { $0.account == name }
    }

    // Find a transaction by id
    func transaction(id: UUID) -> Transaction? {
        transactions.first { $0.id == id }
    }
}
