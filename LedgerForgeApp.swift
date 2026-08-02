//
//  LedgerForgeApp.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//

import SwiftUI

#if DEBUG
private final class DevelopmentDatabaseTerminationDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            DevelopmentDatabaseLifecycleCoordinator.shared.closeOwnedProvider()
        }
    }
}
#endif

@main
struct LedgerForgeApp: App {
#if DEBUG
    @NSApplicationDelegateAdaptor(DevelopmentDatabaseTerminationDelegate.self) private var terminationDelegate
#else
    private static var sqliteProvider: SQLiteRepositoryProvider?
#endif

    init() {
        if let isolatedPurpose = Self.isolatedPersistencePurpose() {
            Self.configureInMemoryPersistence(for: isolatedPurpose)
        } else {
            Self.configurePersistence()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    @discardableResult
    static func configurePersistence(path: String? = nil) -> Bool {
#if DEBUG
        DevelopmentDatabaseLifecycleCoordinator.shared.closeOwnedProvider()
#else
        sqliteProvider?.database.close()
        sqliteProvider = nil
#endif
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)
        do {
            try installSQLiteProvider(path: path)
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
        configureInMemoryPersistence(for: .testMemory)
    }

    private static func configureInMemoryPersistence(for purpose: PersistenceNonDurablePurpose) {
#if DEBUG
        DevelopmentDatabaseLifecycleCoordinator.shared.closeOwnedProvider()
#else
        sqliteProvider?.database.close()
#endif
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = .intentionalNonDurable(purpose)
#if !DEBUG
        sqliteProvider = nil
#endif
    }

    static func isolatedPersistencePurpose(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PersistenceNonDurablePurpose? {
#if DEBUG
        if environment["LEDGERFORGE_TEST_HOST"] == "1" {
            return .testMemory
        }
        if environment["LEDGERFORGE_RUN_HOST"] == "1" {
            return .debugMemory
        }
        return nil
#else
        nil
#endif
    }

    static func usesIsolatedTestPersistence(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        isolatedPersistencePurpose(environment: environment) == .testMemory
    }

    static func usesIsolatedRunPersistence(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        isolatedPersistencePurpose(environment: environment) == .debugMemory
    }

#if DEBUG
    static func startTemporaryEmptySession() -> DevelopmentDatabaseLifecycleResult {
        DevelopmentDatabaseLifecycleCoordinator.shared.startTemporaryEmptySession()
    }

    static func resetDevelopmentDatabase() -> DevelopmentDatabaseLifecycleResult {
        DevelopmentDatabaseLifecycleCoordinator.shared.resetDevelopmentDatabase()
    }
#endif

    private static func installSQLiteProvider(path: String? = nil) throws {
#if DEBUG
        guard path == nil || usesIsolatedTestPersistence() else {
            throw DevelopmentDatabaseProfileIdentityError.invalidProfile
        }
#endif
        let provider = try SQLiteRepositoryProvider(path: path)
#if DEBUG
        let coordinator = DevelopmentDatabaseLifecycleCoordinator.shared
        coordinator.loadRememberedSelection(from: DevelopmentDatabaseProfilePreferences())
        try coordinator.installInitialProvider(
            provider,
            allowsTaskOwnedTestPath: usesIsolatedTestPersistence()
        )
#else
        sqliteProvider = provider
        DatabaseProvider.shared = .verifiedSQLite(provider)
#endif
    }
}
