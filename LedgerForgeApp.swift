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
#if DEBUG
        DatabaseProvider.shared.invalidateGeneration()
#endif
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)
        sqliteProvider = nil
        do {
            _ = try installSQLiteProvider(path: path)
            DeveloperConsole.shared.info(.database, "Persistence bootstrap verified")
            return true
        } catch {
            let reason = PersistenceFailureClassifier.classify(error)
            DatabaseProvider.shared = .unavailable(reason: reason)
            DeveloperConsole.shared.error(
                .database,
                "Persistence bootstrap unavailable",
                metadata: ["reason": reason.rawValue]
            )
            return false
        }
    }

    static func configureInMemoryPersistenceForTesting() {
        sqliteProvider?.database.close()
        DatabaseProvider.shared = .intentionalNonDurable(.testMemory)
        sqliteProvider = nil
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
        sqliteProvider = provider
#if DEBUG
        DevelopmentDatabaseLifecycleCoordinator.shared.installInitialProvider(provider)
#else
        DatabaseProvider.shared = .verifiedSQLite(provider)
#endif
        return provider
    }
}
