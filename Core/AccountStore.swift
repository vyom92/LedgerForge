//
//  AccountStore.swift
//  LedgerForge
//
//  Created by Copilot on 06/07/26.
//

import Foundation
import Combine

/// AccountStore owns all Account objects and exposes a simple API
/// for creating, finding, updating balances and archiving accounts.
final class AccountStore: ObservableObject {

    static let shared = AccountStore()

    @Published private(set) var accounts: [Account] = []

    private init() {}

    func replaceAccounts(_ accounts: [Account]) {
        if Thread.isMainThread {
            self.accounts = accounts
            return
        }

        DispatchQueue.main.async {
            self.accounts = accounts
        }
    }

    // MARK: - Querying

    /// Find an account by institution and name.
    func findAccount(institution: String, name: String) -> Account? {
        return accounts.first { $0.institution == institution && $0.name == name }
    }

    /// Find an account by id
    func account(id: UUID) -> Account? {
        return accounts.first { $0.id == id }
    }

    // MARK: - Creation

    /// Create and publish a new account. If an account with the same
    /// institution + name exists, it will be returned instead of creating a duplicate.
    @discardableResult
    func createAccount(
        institution: String,
        name: String,
        type: AccountType,
        currencyCode: String,
        currentBalance: Decimal = .zero,
        includeInNetWorth: Bool = true,
        lastImport: Date? = nil
    ) -> Account {

        if let existing = findAccount(institution: institution, name: name) {
            return existing
        }

        let account = Account(
            institution: institution,
            name: name,
            type: type,
            currencyCode: currencyCode,
            currentBalance: currentBalance,
            includeInNetWorth: includeInNetWorth,
            lastImport: lastImport
        )

        DispatchQueue.main.async {
            self.accounts.append(account)
        }

        return account
    }

    // MARK: - Import integration

    /// Integrate an import session and its transactions into the AccountStore.
    /// This will create or update a single account derived from the import metadata.
    /// Rules:
    /// - Account identity: institution name + import file name.
    /// - Balance: prefer the last transaction.balance if present, otherwise derive from last transaction.amount.
    func integrateImport(importSession: ImportSession, transactions: [Transaction]) {

        // Use institution string and file name to identify an account. Keep this deterministic and explainable.
        let institutionName = importSession.institution?.rawValue ?? "Unknown"
        let accountName = importSession.fileName

        // Determine account type from document type
        let type: AccountType
        switch importSession.documentType {
        case .bankAccount:
            type = .bank
        case .creditCard:
            type = .creditCard
        default:
            type = .bank
        }

        // Determine currency from first transaction if available
        let currency = transactions.first?.currency ?? "INR"

        // Determine most recent balance from transactions
        let lastBalance: Decimal?
        if let lastWithBalance = transactions.last(where: { $0.balance != nil }) {
            lastBalance = lastWithBalance.balance
        } else if let lastTransaction = transactions.last {
            // If no explicit balance column, use cumulative amount as a best-effort current balance.
            lastBalance = lastTransaction.amount
        } else {
            lastBalance = nil
        }

        // Create or update account
        if let existing = findAccount(institution: institutionName, name: accountName) {
            // Update balance and lastImport
            var updated = existing
            if let lastBalance = lastBalance {
                updated.currentBalance = lastBalance
            }
            updated.currencyCode = currency
            updated.lastImport = importSession.importedAt

            DispatchQueue.main.async {
                if let idx = self.accounts.firstIndex(where: { $0.id == updated.id }) {
                    self.accounts[idx] = updated
                }
            }
        } else {
            let _ = createAccount(
                institution: institutionName,
                name: accountName,
                type: type,
                currencyCode: currency,
                currentBalance: lastBalance ?? .zero,
                includeInNetWorth: true,
                lastImport: importSession.importedAt
            )
        }
    }

    // MARK: - Balance updates

    func updateBalance(for id: UUID, newBalance: Decimal, lastImport: Date? = nil) {
        DispatchQueue.main.async {
            guard let idx = self.accounts.firstIndex(where: { $0.id == id }) else { return }
            var updated = self.accounts[idx]
            updated.currentBalance = newBalance
            if let lastImport = lastImport {
                updated.lastImport = lastImport
            }
            self.accounts[idx] = updated
        }
    }

    // MARK: - Archiving

    func archiveAccount(id: UUID) {
        DispatchQueue.main.async {
            guard let idx = self.accounts.firstIndex(where: { $0.id == id }) else { return }
            var updated = self.accounts[idx]
            updated.status = .archived
            self.accounts[idx] = updated
        }
    }

}
