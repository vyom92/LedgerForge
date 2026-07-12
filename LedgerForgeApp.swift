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
            let provider = try installSQLiteProvider(path: path)
            DeveloperConsole.shared.log("Persistence bootstrap connected to SQLite.")
            DeveloperConsole.shared.log(provider.databasePath)
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

    @discardableResult
    static func resetDevelopmentDatabase(path: String? = nil) throws -> RepositoryStoreHydrationResult {
        let provider = try installSQLiteProvider(path: path ?? freshDevelopmentDatabasePath())
        DeveloperConsole.shared.log("Development database reset connected to fresh SQLite provider.")
        DeveloperConsole.shared.log(provider.databasePath)
        let result = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
        DeveloperConsole.shared.log("Development database reset hydrated \(result.accountCount) account(s), \(result.transactionCount) transaction(s).")
        return result
    }

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
        return provider
    }

    private static func freshDevelopmentDatabasePath() throws -> String {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = appSupport
            .appendingPathComponent("LedgerForge", isDirectory: true)
            .appendingPathComponent("Development Resets", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
            .appendingPathComponent("ledgerforge-reset-\(UUID().uuidString).sqlite")
            .path
    }
}
