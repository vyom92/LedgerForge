// LedgerForge
// DeveloperDatabaseProfileViewModel.swift

#if DEBUG
import Combine
import Foundation

enum DeveloperDatabaseProfileOperationState: Equatable {
    case idle
    case activationSucceeded
    case activationSucceededWithCleanupWarning
    case activationBlocked
    case activationFailed
    case resetSucceeded
    case resetSucceededWithCleanupWarning
    case resetNotPermitted
    case resetFailed
    case developmentDatabaseUnavailable

    var message: String? {
        switch self {
        case .idle:
            return nil
        case .activationSucceeded:
            return "The selected database profile is active."
        case .activationSucceededWithCleanupWarning:
            return "The selected profile is active, but prior temporary cleanup could not finish."
        case .activationBlocked:
            return "Profile activation is blocked while database work is active."
        case .activationFailed:
            return "The selected database profile could not be activated."
        case .resetSucceeded:
            return "The active development profile was reset."
        case .resetSucceededWithCleanupWarning:
            return "The active profile was reset, but prior temporary cleanup could not finish."
        case .resetNotPermitted:
            return "Reset is not permitted for Current Database."
        case .resetFailed:
            return "The active development profile could not be reset."
        case .developmentDatabaseUnavailable:
            return "The development database is unavailable."
        }
    }
}

@MainActor
final class DeveloperDatabaseProfileViewModel: ObservableObject {
    @Published private(set) var developerModeEnabled = false
    @Published private(set) var selectedProfileKind: DevelopmentDatabaseProfileKind
    @Published private(set) var selectedMigrationSourceVersion: Int
    @Published private(set) var activeProfile: DevelopmentDatabaseProfileDescriptor?
    @Published private(set) var publicationEpoch: UInt64
    @Published private(set) var operationState: DeveloperDatabaseProfileOperationState = .idle

    private let lifecycleCoordinator: DevelopmentDatabaseLifecycleCoordinator
    private let preferences: DevelopmentDatabaseProfilePreferenceAuthority
    private var epochCancellable: AnyCancellable?

    convenience init() {
        self.init(
            lifecycleCoordinator: .shared,
            preferences: DevelopmentDatabaseProfilePreferences()
        )
    }

    init(
        lifecycleCoordinator: DevelopmentDatabaseLifecycleCoordinator,
        preferences: DevelopmentDatabaseProfilePreferenceAuthority
    ) {
        self.lifecycleCoordinator = lifecycleCoordinator
        self.preferences = preferences
        selectedProfileKind = lifecycleCoordinator.rememberedDevelopmentProfile.profileKind
        selectedMigrationSourceVersion = lifecycleCoordinator.rememberedMigrationSourceVersion
        publicationEpoch = lifecycleCoordinator.runtimePublicationEpoch
        activeProfile = lifecycleCoordinator.committedRuntimeState?.activeProfile

        epochCancellable = lifecycleCoordinator.$runtimePublicationEpoch.sink { [weak self] epoch in
            guard let self else { return }
            self.publicationEpoch = epoch
            self.activeProfile = lifecycleCoordinator.committedRuntimeState?.activeProfile
        }
    }

    var availableMigrationSourceVersions: [Int] {
        DevelopmentDatabaseProfile.registeredHistoricalSourceVersions
    }

    var activeProfileLabel: String {
        activeProfile?.displayName ?? "Unavailable"
    }

    var selectedProfileLabel: String {
        selectedProfileKind.displayName
    }

    var activeSourceSchemaLabel: String? {
        activeProfile?.sourceSchemaLabel
    }

    var currentSchemaLabel: String {
        activeProfile?.currentSchemaLabel ?? "Unavailable"
    }

    var resetActionLabel: String? {
        activeProfile?.resetActionLabel
    }

    var showsMigrationSourceSelection: Bool {
        selectedProfileKind == .migrationSandbox || activeProfile?.kind == .migrationSandbox
    }

    func selectProfile(_ kind: DevelopmentDatabaseProfileKind) {
        selectedProfileKind = kind
        operationState = .idle
        guard let rememberedProfile = kind.rememberedProfile else { return }
        preferences.rememberedDevelopmentProfile = rememberedProfile
    }

    func selectMigrationSourceVersion(_ version: Int) {
        guard availableMigrationSourceVersions.contains(version) else { return }
        selectedMigrationSourceVersion = version
        preferences.rememberedMigrationSourceVersion = version
        operationState = .idle
    }

    func setDeveloperModeEnabled(_ requestedValue: Bool) {
        if requestedValue {
            developerModeEnabled = true
            operationState = .idle
            return
        }

        let result = lifecycleCoordinator.activate(.current)
        refreshCommittedState()
        switch result {
        case .activated, .alreadyActive:
            developerModeEnabled = false
            operationState = .activationSucceeded
        case .committedButPriorCleanupFailed:
            developerModeEnabled = false
            operationState = .activationSucceededWithCleanupWarning
        case .activityBlocked:
            developerModeEnabled = true
            operationState = .activationBlocked
        case .lifecycleUnavailable:
            developerModeEnabled = true
            operationState = .developmentDatabaseUnavailable
        default:
            developerModeEnabled = true
            operationState = .activationFailed
        }
    }

    func activateSelectedProfile() {
        guard developerModeEnabled else {
            operationState = .activationFailed
            return
        }
        let result = lifecycleCoordinator.activate(selectedSelection)
        refreshCommittedState()
        switch result {
        case .activated, .alreadyActive:
            operationState = .activationSucceeded
        case .committedButPriorCleanupFailed:
            operationState = .activationSucceededWithCleanupWarning
        case .activityBlocked:
            operationState = .activationBlocked
        case .lifecycleUnavailable:
            operationState = .developmentDatabaseUnavailable
        default:
            operationState = .activationFailed
        }
    }

    func resetActiveProfile() {
        let result = lifecycleCoordinator.resetActiveProfile(
            migrationSandboxSourceVersion: activeProfile?.kind == .migrationSandbox
                ? selectedMigrationSourceVersion
                : nil
        )
        refreshCommittedState()
        switch result {
        case .activated, .alreadyActive:
            operationState = .resetSucceeded
        case .committedButPriorCleanupFailed:
            operationState = .resetSucceededWithCleanupWarning
        case .resetNotPermitted:
            operationState = .resetNotPermitted
        case .activityBlocked:
            operationState = .activationBlocked
        case .lifecycleUnavailable:
            operationState = .developmentDatabaseUnavailable
        default:
            operationState = .resetFailed
        }
    }

    private var selectedSelection: DevelopmentDatabaseProfileSelection {
        switch selectedProfileKind {
        case .current:
            return .current
        case .persistentDebug:
            return .persistentDebug
        case .temporarySession:
            return .temporarySession
        case .migrationSandbox:
            return .migrationSandbox(sourceVersion: selectedMigrationSourceVersion)
        }
    }

    private func refreshCommittedState() {
        publicationEpoch = lifecycleCoordinator.runtimePublicationEpoch
        activeProfile = lifecycleCoordinator.committedRuntimeState?.activeProfile
    }
}
#endif
