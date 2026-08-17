import Foundation
import Testing
@testable import LedgerForge

#if DEBUG
@MainActor
struct DeveloperDatabaseProfileTests {
    @Test func currentProfileUsesExistingCanonicalIdentityAndCannotResetOrCleanUp() throws {
        let root = try makeTemporaryDirectory("CurrentProfile")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let profile = try DevelopmentDatabaseProfile.resolve(.current)
        let target = try identity.target(for: profile)
        let descriptor = profile.descriptor(
            verifiedCurrentSchemaVersion: DevelopmentDatabaseProfile.currentSchemaVersion
        )

        #expect(target.databaseURL == identity.canonicalDevelopmentURL)
        #expect(!target.isCleanupOwned)
        #expect(!identity.authorizesCleanup(of: target))
        #expect(!identity.authorizesPersistentDebugReset(at: target.databaseURL))
        #expect(descriptor.kind == .current)
        #expect(descriptor.persistenceClassification == .stableCurrent)
        #expect(!descriptor.canReset)
    }

    @Test func persistentDebugIdentityIsStableAndSeparateFromCurrent() throws {
        let root = try makeTemporaryDirectory("PersistentProfile")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let first = try identity.target(for: DevelopmentDatabaseProfile.resolve(.persistentDebug))
        let second = try identity.target(for: DevelopmentDatabaseProfile.resolve(.persistentDebug))

        #expect(first == second)
        #expect(first.databaseURL == identity.persistentDebugURL)
        #expect(first.databaseURL != identity.canonicalDevelopmentURL)
        #expect(first.databaseURL.lastPathComponent == "ledgerforge-debug.sqlite")
        #expect(identity.authorizesPersistentDebugReset(at: first.databaseURL))
        #expect(!first.isCleanupOwned)
    }

    @Test func temporaryAndSandboxProfilesHaveFreshExactOwnedIdentities() throws {
        let root = try makeTemporaryDirectory("OwnedProfiles")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let temporaryOne = try identity.target(for: DevelopmentDatabaseProfile.resolve(.temporarySession))
        let temporaryTwo = try identity.target(for: DevelopmentDatabaseProfile.resolve(.temporarySession))
        let sandbox = try identity.target(
            for: DevelopmentDatabaseProfile.resolve(.migrationSandbox(sourceVersion: 4))
        )

        #expect(temporaryOne.databaseURL != temporaryTwo.databaseURL)
        #expect(temporaryOne.databaseURL.deletingLastPathComponent() == identity.temporaryDirectoryURL)
        #expect(sandbox.databaseURL.deletingLastPathComponent() == identity.migrationSandboxDirectoryURL)
        #expect(temporaryOne.isCleanupOwned)
        #expect(sandbox.isCleanupOwned)
        #expect(identity.authorizesCleanup(of: temporaryOne))
        #expect(identity.authorizesCleanup(of: sandbox))

        let forged = DevelopmentDatabaseProfileTarget(
            profile: temporaryOne.profile,
            databaseURL: root.appendingPathComponent("outside.sqlite")
        )
        #expect(!identity.authorizesCleanup(of: forged))
    }

    @Test func symlinkEscapesAreRejectedForStableAndOwnedProfileIdentities() throws {
        let root = try makeTemporaryDirectory("SymlinkAuthority")
        let externalRoot = try makeTemporaryDirectory("SymlinkExternal")
        defer { try? FileManager.default.removeItem(at: externalRoot) }
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(
            at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: identity.canonicalDevelopmentURL,
            withDestinationURL: externalRoot.appendingPathComponent("current.sqlite")
        )
        try FileManager.default.createSymbolicLink(
            at: identity.persistentDebugURL,
            withDestinationURL: externalRoot.appendingPathComponent("persistent.sqlite")
        )
        try FileManager.default.createSymbolicLink(
            at: identity.temporaryDirectoryURL,
            withDestinationURL: externalRoot
        )
        let temporary = try identity.target(
            for: DevelopmentDatabaseProfile.resolve(.temporarySession)
        )

        #expect(!identity.authorizesCurrentDatabaseIdentity(at: identity.canonicalDevelopmentURL))
        #expect(!identity.authorizesPersistentDebugReset(at: identity.persistentDebugURL))
        #expect(!identity.authorizesCleanup(of: temporary))
    }

    @Test(arguments: [0, 13, Int.max])
    func migrationSandboxRejectsNonHistoricalSourceVersions(_ version: Int) {
        #expect(throws: DevelopmentDatabaseProfileDomainError.invalidMigrationSourceVersion) {
            _ = try DevelopmentDatabaseProfile.resolve(.migrationSandbox(sourceVersion: version))
        }
    }

    @Test func profileDescriptorsAndResultsArePathFree() throws {
        let profile = try DevelopmentDatabaseProfile.resolve(
            .migrationSandbox(sourceVersion: DevelopmentDatabaseProfile.defaultHistoricalSourceVersion)
        )
        let descriptor = profile.descriptor(
            verifiedCurrentSchemaVersion: DevelopmentDatabaseProfile.currentSchemaVersion
        )

        #expect(descriptor.displayName == "Migration Sandbox")
        #expect(descriptor.migrationSourceVersion == 12)
        #expect(!String(describing: DevelopmentDatabaseProfileActivationResult.activityBlocked).contains("/"))
        #expect(!String(describing: DevelopmentDatabaseProfileActivationResult.migrationFailed).contains("sqlite"))
    }

    @Test func preferencesPersistOnlyTypedRememberedSelectionAndSource() throws {
        let suiteName = "LedgerForge.DBP01.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = DevelopmentDatabaseProfilePreferences(defaults: defaults)
        first.rememberedDevelopmentProfile = .persistentDebug
        first.rememberedMigrationSourceVersion = 3
        let reloaded = DevelopmentDatabaseProfilePreferences(defaults: defaults)

        #expect(reloaded.rememberedDevelopmentProfile == .persistentDebug)
        #expect(reloaded.rememberedMigrationSourceVersion == 3)
        #expect(Set(defaults.dictionaryRepresentation().keys).intersection([
            DevelopmentDatabaseProfilePreferences.rememberedProfileKey,
            DevelopmentDatabaseProfilePreferences.rememberedMigrationSourceVersionKey
        ]).count == 2)
        #expect(defaults.object(forKey: "developmentDatabase.activeProfile") == nil)
        #expect(defaults.object(forKey: "developmentDatabase.activeProviderGeneration") == nil)
        #expect(defaults.object(forKey: "developmentDatabase.developerModeEnabled") == nil)
    }

    @Test func malformedPreferencesFallBackWithoutReopeningOwnedProfiles() throws {
        let suiteName = "LedgerForge.DBP01.Malformed.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("temporary-invalid-location", forKey: DevelopmentDatabaseProfilePreferences.rememberedProfileKey)
        defaults.set(13, forKey: DevelopmentDatabaseProfilePreferences.rememberedMigrationSourceVersionKey)

        let preferences = DevelopmentDatabaseProfilePreferences(defaults: defaults)
        #expect(preferences.rememberedDevelopmentProfile == .persistentDebug)
        #expect(preferences.rememberedMigrationSourceVersion == 12)
    }

    @Test(.globalRuntimeStateIsolation)
    func bootstrapLoadsRememberedSelectionButAlwaysActivatesCurrent() throws {
        let root = try makeTemporaryDirectory("BootstrapCurrent")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(
            at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let provider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        let gate = DevelopmentDatabaseActivityGate()
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: gate)
        defer { coordinator.closeOwnedProvider() }

        let suiteName = "LedgerForge.DBP01.Bootstrap.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = DevelopmentDatabaseProfilePreferences(defaults: defaults)
        preferences.rememberedDevelopmentProfile = .persistentDebug
        preferences.rememberedMigrationSourceVersion = 5

        coordinator.loadRememberedSelection(from: preferences)
        _ = try coordinator.installInitialProvider(provider)

        #expect(coordinator.rememberedDevelopmentProfile == .persistentDebug)
        #expect(coordinator.rememberedMigrationSourceVersion == 5)
        #expect(coordinator.activeProfile?.kind == .current)
        #expect(coordinator.currentDatabaseURL == identity.canonicalDevelopmentURL)
        #expect(!FileManager.default.fileExists(atPath: identity.persistentDebugURL.path))
    }

    @Test func releaseAndDebugDefaultFilenamesRemainDistinct() throws {
        let root = try makeTemporaryDirectory("DefaultFilenames")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)

        #expect(identity.canonicalDevelopmentURL.lastPathComponent == "ledgerforge-development.sqlite")
        #expect(identity.nonDevelopmentURL.lastPathComponent == "ledgerforge.sqlite")
        #expect(identity.canonicalDevelopmentURL != identity.nonDevelopmentURL)
    }

    private func makeTemporaryDirectory(_ name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
#endif
