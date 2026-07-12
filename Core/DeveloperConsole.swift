// LedgerForge
// DeveloperConsole.swift
// Version: 0.0.3

import Foundation
import Combine

struct DeveloperConsoleSnapshot: Equatable {
    let providerState: String
    let hydrationStatus: String
    let latestRefreshResult: String
    let accountCount: Int
    let transactionCount: Int
    let databasePath: String?
}

final class DeveloperConsole: ObservableObject {

    static let shared = DeveloperConsole()

    @Published private(set) var messages: [String] = []

    private init() {}

    var completeLogText: String {
        Self.logText(from: messages)
    }

    func log(_ message: String) {
        let update = {
            self.messages.append(message)
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    func clear() {
        let update = {
            self.messages.removeAll()
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    func filteredMessages(matching searchText: String) -> [String] {
        Self.filteredMessages(messages, matching: searchText)
    }

    static func filteredMessages(_ messages: [String], matching searchText: String) -> [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return messages }
        return messages.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    static func logText(from messages: [String]) -> String {
        messages.joined(separator: "\n")
    }

    static func runtimeSnapshot(
        providerState: String,
        databasePath: String?,
        hydrationStatus: String,
        latestRefreshResult: String,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared
    ) -> DeveloperConsoleSnapshot {
        DeveloperConsoleSnapshot(
            providerState: providerState,
            hydrationStatus: hydrationStatus,
            latestRefreshResult: latestRefreshResult,
            accountCount: accountStore.accounts.count,
            transactionCount: transactionStore.transactions.count,
            databasePath: databasePath
        )
    }
}
