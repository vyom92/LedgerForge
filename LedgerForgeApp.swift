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
    private static var configuredProviderState = "In-memory repository provider"
    private static var configuredDatabasePath: String?

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
            _ = try installSQLiteProvider(path: path)
            DeveloperConsole.shared.log("Persistence bootstrap connected to SQLite.")
            return true
        } catch {
            DatabaseProvider.shared = DatabaseProvider(inMemory: true)
            sqliteProvider = nil
            configuredProviderState = "In-memory repository provider"
            configuredDatabasePath = nil
            DeveloperConsole.shared.log("Persistence bootstrap failed. Falling back to in-memory repositories.")
            DeveloperConsole.shared.log(error.localizedDescription)
            return false
        }
    }

    static func configureInMemoryPersistenceForTesting() {
        DatabaseProvider.shared = DatabaseProvider(inMemory: true)
        sqliteProvider = nil
        configuredProviderState = "In-memory repository provider"
        configuredDatabasePath = nil
    }

    static func currentProviderState() -> String {
        configuredProviderState
    }

    static func currentSQLiteDatabasePath() -> String? {
        configuredDatabasePath
    }

#if DEBUG
    static func startTemporaryEmptySession() -> DevelopmentDatabaseLifecycleResult {
        DevelopmentDatabaseLifecycleCoordinator.shared.startTemporaryEmptySession()
    }

    static func resetDevelopmentDatabase() -> DevelopmentDatabaseLifecycleResult {
        DevelopmentDatabaseLifecycleCoordinator.shared.resetDevelopmentDatabase()
    }
#endif

    @discardableResult
    private static func installSQLiteProvider(path: String? = nil) throws -> SQLiteRepositoryProvider {
        let provider = try SQLiteRepositoryProvider(path: path)
        DatabaseProvider.shared = DatabaseProvider(
            workspaceRepo: provider.workspaceRepo,
            transactionRepo: provider.transactionRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo
        )
        sqliteProvider = provider
        configuredProviderState = "SQLite repository provider"
        configuredDatabasePath = provider.databasePath
#if DEBUG
        DevelopmentDatabaseLifecycleCoordinator.shared.installInitialProvider(provider)
#endif
        return provider
    }
}
