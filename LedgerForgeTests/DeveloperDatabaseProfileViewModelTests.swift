import Foundation
import Testing
@testable import LedgerForge

#if DEBUG
@Suite("Developer database profile view model", .serialized)
@MainActor
struct DeveloperDatabaseProfileViewModelTests {
    @Test(.globalRuntimeStateIsolation)
    func launchStartsWithModeOffCurrentActiveAndRememberedSelectionInactive() throws {
        let setup = try makeProfileViewModelSetup(
            name: "Launch",
            rememberedProfile: .migrationSandbox,
            sourceVersion: 4
        )
        defer { setup.coordinator.closeOwnedProvider() }
        defer { try? FileManager.default.removeItem(at: setup.root) }

        #expect(!setup.viewModel.developerModeEnabled)
        #expect(setup.viewModel.selectedProfileKind == .migrationSandbox)
        #expect(setup.viewModel.selectedMigrationSourceVersion == 4)
        #expect(setup.viewModel.activeProfile?.kind == .current)
        #expect(setup.viewModel.activeProfileLabel == "Current Database")
    }

    @Test(.globalRuntimeStateIsolation)
    func enablingModeDoesNotSwitchAndExplicitActivationPublishesCommittedState() throws {
        let setup = try makeProfileViewModelSetup(name: "Activate")
        defer { setup.coordinator.closeOwnedProvider() }
        defer { try? FileManager.default.removeItem(at: setup.root) }
        let initialEpoch = setup.viewModel.publicationEpoch

        setup.viewModel.setDeveloperModeEnabled(true)
        #expect(setup.viewModel.developerModeEnabled)
        #expect(setup.viewModel.activeProfile?.kind == .current)

        setup.viewModel.selectProfile(.persistentDebug)
        #expect(setup.viewModel.selectedProfileKind == .persistentDebug)
        #expect(setup.viewModel.activeProfile?.kind == .current)

        setup.viewModel.activateSelectedProfile()
        #expect(setup.viewModel.activeProfile?.kind == .persistentDebug)
        #expect(setup.viewModel.publicationEpoch == initialEpoch + 1)
        #expect(setup.viewModel.operationState == .activationSucceeded)
    }

    @Test(.globalRuntimeStateIsolation)
    func disablingModeReturnsToCurrentOnlyAfterCommittedActivation() throws {
        let setup = try makeProfileViewModelSetup(name: "Disable")
        defer { setup.coordinator.closeOwnedProvider() }
        defer { try? FileManager.default.removeItem(at: setup.root) }

        setup.viewModel.setDeveloperModeEnabled(true)
        setup.viewModel.selectProfile(.temporarySession)
        setup.viewModel.activateSelectedProfile()
        #expect(setup.viewModel.activeProfile?.kind == .temporarySession)

        setup.viewModel.setDeveloperModeEnabled(false)
        #expect(!setup.viewModel.developerModeEnabled)
        #expect(setup.viewModel.activeProfile?.kind == .current)
        #expect(setup.coordinator.committedRuntimeState?.activeProfile.kind == .current)
    }

    @Test(.globalRuntimeStateIsolation)
    func blockedReturnToCurrentLeavesModeEnabledAndProfileTruthful() throws {
        let setup = try makeProfileViewModelSetup(name: "Blocked")
        defer { setup.coordinator.closeOwnedProvider() }
        defer { try? FileManager.default.removeItem(at: setup.root) }

        setup.viewModel.setDeveloperModeEnabled(true)
        setup.viewModel.selectProfile(.persistentDebug)
        setup.viewModel.activateSelectedProfile()
        let lease = try setup.activityGate.begin(.repositoryWrite)
        defer { lease.finish() }

        setup.viewModel.setDeveloperModeEnabled(false)

        #expect(setup.viewModel.developerModeEnabled)
        #expect(setup.viewModel.activeProfile?.kind == .persistentDebug)
        #expect(setup.viewModel.operationState == .activationBlocked)
    }

    @Test(.globalRuntimeStateIsolation)
    func sandboxResetRecreatesFromSelectedHistoricalSource() throws {
        let setup = try makeProfileViewModelSetup(name: "SandboxReset")
        defer { setup.coordinator.closeOwnedProvider() }
        defer { try? FileManager.default.removeItem(at: setup.root) }

        setup.viewModel.setDeveloperModeEnabled(true)
        setup.viewModel.selectProfile(.migrationSandbox)
        setup.viewModel.selectMigrationSourceVersion(3)
        setup.viewModel.activateSelectedProfile()
        #expect(setup.viewModel.activeProfile?.migrationSourceVersion == 3)

        setup.viewModel.selectMigrationSourceVersion(6)
        let activeEpoch = setup.viewModel.publicationEpoch
        setup.viewModel.resetActiveProfile()

        #expect(setup.viewModel.operationState == .resetSucceeded)
        #expect(setup.viewModel.activeProfile?.kind == .migrationSandbox)
        #expect(setup.viewModel.activeProfile?.migrationSourceVersion == 6)
        #expect(setup.viewModel.publicationEpoch == activeEpoch + 1)
    }
}

@MainActor
private final class TestProfilePreferences: DevelopmentDatabaseProfilePreferenceAuthority {
    var rememberedDevelopmentProfile: RememberedDevelopmentDatabaseProfile
    var rememberedMigrationSourceVersion: Int

    init(
        profile: RememberedDevelopmentDatabaseProfile,
        sourceVersion: Int
    ) {
        rememberedDevelopmentProfile = profile
        rememberedMigrationSourceVersion = sourceVersion
    }
}

@MainActor
private func makeProfileViewModelSetup(
    name: String,
    rememberedProfile: RememberedDevelopmentDatabaseProfile = .persistentDebug,
    sourceVersion: Int? = nil
) throws -> (
    root: URL,
    coordinator: DevelopmentDatabaseLifecycleCoordinator,
    activityGate: DevelopmentDatabaseActivityGate,
    viewModel: DeveloperDatabaseProfileViewModel
) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForge-ProfileVM-\(name)-\(UUID().uuidString)", isDirectory: true)
    let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
    let activityGate = DevelopmentDatabaseActivityGate()
    let coordinator = DevelopmentDatabaseLifecycleCoordinator(
        identity: identity,
        activityGate: activityGate
    )
    let preferences = TestProfilePreferences(
        profile: rememberedProfile,
        sourceVersion: sourceVersion ?? DevelopmentDatabaseProfile.defaultHistoricalSourceVersion
    )
    coordinator.loadRememberedSelection(from: preferences)
    try FileManager.default.createDirectory(
        at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let provider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
    _ = try coordinator.installInitialProvider(provider)
    let viewModel = DeveloperDatabaseProfileViewModel(
        lifecycleCoordinator: coordinator,
        preferences: preferences
    )
    return (root, coordinator, activityGate, viewModel)
}
#endif
