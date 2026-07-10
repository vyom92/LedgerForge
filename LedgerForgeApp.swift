//
//  LedgerForgeApp.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//

import SwiftUI

@main
struct LedgerForgeApp: App {
    private static var sqliteProvider: SQLiteRepositoryProvider?

    init() {
        Self.configurePersistence()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    @discardableResult
    static func configurePersistence(path: String? = nil) -> Bool {
        do {
            let provider = try SQLiteRepositoryProvider(path: path)
            DatabaseProvider.shared = DatabaseProvider(
                workspaceRepo: provider.workspaceRepo,
                transactionRepo: provider.transactionRepo,
                accountRepo: provider.accountRepo,
                importSessionRepo: provider.importSessionRepo
            )
            sqliteProvider = provider
            DeveloperConsole.shared.log("Persistence bootstrap connected to SQLite.")
            DeveloperConsole.shared.log(provider.databasePath)
            return true
        } catch {
            DatabaseProvider.shared = DatabaseProvider(inMemory: true)
            sqliteProvider = nil
            DeveloperConsole.shared.log("Persistence bootstrap failed. Falling back to in-memory repositories.")
            DeveloperConsole.shared.log(error.localizedDescription)
            return false
        }
    }

    static func configureInMemoryPersistenceForTesting() {
        DatabaseProvider.shared = DatabaseProvider(inMemory: true)
        sqliteProvider = nil
    }
}
