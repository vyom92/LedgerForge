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
        DispatchQueue.main.async {
            self.transactions = transactions
            self.lastValidation = validation
        }
    }

    // ...existing code...
    
    // Simple search by description (case-insensitive)
    func search(_ text: String) -> [Transaction] {
        guard !text.isEmpty else { return transactions }
        return transactions.filter {
            $0.description.localizedCaseInsensitiveContains(text) ||
            $0.sourceFile.localizedCaseInsensitiveContains(text) ||
            $0.sourceBank.localizedCaseInsensitiveContains(text)
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
