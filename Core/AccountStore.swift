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
        let update = {
            self.accounts = accounts
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
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

        // Determine the latest known balance from transactions without assuming array order.
        let latestBalance = Self.latestKnownBalance(from: transactions)

        // Create or update account
        if let existing = findAccount(institution: institutionName, name: accountName) {
            // Update balance and lastImport
            var updated = existing
            if let latestBalance = latestBalance {
                updated.currentBalance = latestBalance
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
                currentBalance: latestBalance ?? .zero,
                includeInNetWorth: true,
                lastImport: importSession.importedAt
            )
        }
    }

    // MARK: - Balance updates

    nonisolated private static func latestKnownBalance(from transactions: [Transaction]) -> Decimal? {
        let transactionsWithBalance: [(offset: Int, date: Date?, balance: Decimal)] = transactions
            .enumerated()
            .compactMap { offset, transaction in
                guard let balance = transaction.balance else { return nil }
                return (offset: offset, date: transaction.date, balance: balance)
            }

        if let latestWithBalance = transactionsWithBalance.sorted(by: isNewer).first {
            return latestWithBalance.balance
        }

        return transactions
            .enumerated()
            .sorted { lhs, rhs in
                isNewer(
                    lhs: (offset: lhs.offset, date: lhs.element.date, balance: lhs.element.amount),
                    rhs: (offset: rhs.offset, date: rhs.element.date, balance: rhs.element.amount)
                )
            }
            .first?.element.amount
    }

    nonisolated private static func isNewer(
        lhs: (offset: Int, date: Date?, balance: Decimal),
        rhs: (offset: Int, date: Date?, balance: Decimal)
    ) -> Bool {
        switch (lhs.date, rhs.date) {
        case let (left?, right?) where left != right:
            return left > right
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return lhs.offset > rhs.offset
        }
    }

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
