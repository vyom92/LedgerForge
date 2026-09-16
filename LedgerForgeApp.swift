//
//  LedgerForgeApp.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//

import SwiftUI

private final class LedgerForgeTerminationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            if BackupRestoreCoordinator.shared.isBusy || DatabaseActivityGate.shared.hasActiveOperations || DatabaseActivityGate.shared.hasExclusiveOperation {
                return .terminateCancel
            }
            return .terminateNow
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
#if DEBUG
            DevelopmentDatabaseLifecycleCoordinator.shared.closeOwnedProvider()
#else
            LedgerForgeApp.closeProductionProvider()
#endif
        }
    }
}

@main
struct LedgerForgeApp: App {
    @NSApplicationDelegateAdaptor(LedgerForgeTerminationDelegate.self) private var terminationDelegate
    @StateObject private var alDarReferenceSession = AlDarReferenceSession(enabled: {
        let environment = ProcessInfo.processInfo.environment
        if environment["LEDGERFORGE_TEST_HOST"] == "1" { return false }
#if DEBUG
        if environment["LEDGERFORGE_AL_DAR_NETWORK_DISABLED"] == "1" { return false }
#endif
        return true
    }())
    @StateObject private var transactionViewModel = TransactionListViewModel()
    @State private var transactionAmountMeasurement = TransactionAmountWidthMeasurement()
#if !DEBUG
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
            ContentView(transactionViewModel: transactionViewModel, transactionAmountMeasurement: transactionAmountMeasurement, alDarReferenceSession: alDarReferenceSession)
        }
        .windowStyle(.hiddenTitleBar)
    }

    @discardableResult
    static func configurePersistence(path: String? = nil) -> Bool {
#if DEBUG
        DevelopmentDatabaseLifecycleCoordinator.shared.closeOwnedProvider()
#else
        sqliteProvider?.database.close()
        sqliteProvider = nil
#endif
        ApplicationAvailability.shared.begin()
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)
        do {
            try installSQLiteProvider(path: path)
            DeveloperConsole.shared.info(.database, "Persistence bootstrap verified", metadata: ["code": "startup.provider_verified", "stage": "provider activation", "requested_target": RuntimeDiagnostic.logicalTarget(), "build_identity": BuildIdentity.read().label, "provider_kind": "verified SQLite"])
            return true
        } catch {
            let reason = PersistenceFailureClassifier.classify(error)
            let failure = RuntimeDiagnostic.failure(error, operation: "startup", stage: "provider initialization")
            DatabaseProvider.shared = .unavailable(reason: reason, context: failure)
            ApplicationAvailability.shared.didFail(failure, generation: nil)
            RuntimeDiagnostic.record(failure, category: .database)
            BackupRestoreCoordinator.shared.startupDidFail()
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
        ApplicationAvailability.shared.begin()
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
        let target = try path.map { URL(fileURLWithPath: $0) } ?? SQLiteRepositoryProvider.canonicalDBURL()
        let parentExisted = FileManager.default.fileExists(atPath: target.deletingLastPathComponent().path)
        let recovery = BackupRestoreCoordinator.shared
        recovery.configureTarget(target)
        if parentExisted { try recovery.recoverBeforeStartup() }
        let exists = FileManager.default.fileExists(atPath: target.path)
        // Parent absence cannot distinguish first use from a lost ledger.
        // Production creation requires the explicit first-use Settings action.
        guard exists || (path != nil && usesIsolatedTestPersistence()) else { throw BackupError.recoveryUnavailable }
        if !parentExisted { try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true) }
        // Resolve receipt ownership first, then permit only the explicitly
        // approved exact V17/V18/V19→current existing-ledger bridge under the recovery gate.
        let isRecoveryOpen = try recovery.layout?.readReceipt() != nil
        if isRecoveryOpen {
            let database = SQLiteDatabase(path: target.path)
            try database.open(access: .existing)
            do {
                try BackupCompatibility.upgradeSupportedCandidateIfNeeded(database)
                try database.checkpointAndClose()
            } catch { try? database.closeChecked(); throw error }
        }
        let provider = try SQLiteRepositoryProvider(path: target.path, migrations: allMigrations,
            access: exists ? .existing : .createIfMissing, migrateExisting: !isRecoveryOpen)
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

    static func currentSQLiteProviderForRecovery() throws -> SQLiteRepositoryProvider? {
#if DEBUG
        return try DevelopmentDatabaseLifecycleCoordinator.shared.currentProviderForRecovery()
#else
        return sqliteProvider
#endif
    }

    static func publishRecoveredCurrent(_ provider: SQLiteRepositoryProvider, runtime: DatabaseProvider,
                                        hydrator: RepositoryStoreHydrator, snapshot: RepositoryRuntimeSnapshot) {
#if DEBUG
        DevelopmentDatabaseLifecycleCoordinator.shared.publishRecoveredCurrent(provider, runtime: runtime, hydrator: hydrator, snapshot: snapshot)
#else
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = runtime
        hydrator.installSnapshotWithoutObservation(snapshot)
        sqliteProvider = provider
        hydrator.notifyObserversOfInstalledSnapshot()
#endif
    }
#if !DEBUG
    static func closeProductionProvider() {
        do { try sqliteProvider?.database.checkpointAndClose() }
        catch { RuntimeDiagnostic.record(RuntimeDiagnostic.failure(error, operation: "termination", stage: "checked close"), category: .database) }
    }
#endif
}
