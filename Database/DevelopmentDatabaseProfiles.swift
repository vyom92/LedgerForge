// LedgerForge
// DevelopmentDatabaseProfiles.swift

#if DEBUG
import Foundation

enum DevelopmentDatabaseProfileKind: String, CaseIterable, Equatable, Hashable {
    case current
    case persistentDebug
    case temporarySession
    case migrationSandbox

    var displayName: String {
        switch self {
        case .current: return "Current Database"
        case .persistentDebug: return "Persistent Debug Database"
        case .temporarySession: return "Temporary Session"
        case .migrationSandbox: return "Migration Sandbox"
        }
    }

    var rememberedProfile: RememberedDevelopmentDatabaseProfile? {
        switch self {
        case .current: return nil
        case .persistentDebug: return .persistentDebug
        case .temporarySession: return .temporarySession
        case .migrationSandbox: return .migrationSandbox
        }
    }
}

enum DevelopmentDatabaseProfilePersistenceClassification: String, Equatable {
    case stableCurrent
    case stableDevelopment
    case processOwnedTemporary
    case processOwnedMigrationSandbox
}

enum RememberedDevelopmentDatabaseProfile: String, CaseIterable, Equatable {
    case persistentDebug
    case temporarySession
    case migrationSandbox

    var profileKind: DevelopmentDatabaseProfileKind {
        switch self {
        case .persistentDebug: return .persistentDebug
        case .temporarySession: return .temporarySession
        case .migrationSandbox: return .migrationSandbox
        }
    }

    var selection: DevelopmentDatabaseProfileSelection {
        switch self {
        case .persistentDebug:
            return .persistentDebug
        case .temporarySession:
            return .temporarySession
        case .migrationSandbox:
            return .migrationSandbox(sourceVersion: DevelopmentDatabaseProfile.defaultHistoricalSourceVersion)
        }
    }
}

enum DevelopmentDatabaseProfileSelection: Equatable {
    case current
    case persistentDebug
    case temporarySession
    case migrationSandbox(sourceVersion: Int)

    var kind: DevelopmentDatabaseProfileKind {
        switch self {
        case .current: return .current
        case .persistentDebug: return .persistentDebug
        case .temporarySession: return .temporarySession
        case .migrationSandbox: return .migrationSandbox
        }
    }
}

enum DevelopmentDatabaseProfileDomainError: Error, Equatable {
    case invalidMigrationSourceVersion
}

/// Process-local profile identity. Filesystem locations remain owned by
/// `DevelopmentDatabaseIdentity` and are never presentation data.
struct DevelopmentDatabaseProfile: Equatable {
    let kind: DevelopmentDatabaseProfileKind
    let migrationSourceVersion: Int?
    let ownershipID: UUID?

    static var currentSchemaVersion: Int {
        allMigrations.last?.version ?? 0
    }

    static var registeredHistoricalSourceVersions: [Int] {
        Array(allMigrations.dropLast().map(\.version))
    }

    static var defaultHistoricalSourceVersion: Int {
        registeredHistoricalSourceVersions.last ?? 1
    }

    static func resolve(
        _ selection: DevelopmentDatabaseProfileSelection,
        makeOwnershipID: () -> UUID = UUID.init
    ) throws -> DevelopmentDatabaseProfile {
        switch selection {
        case .current:
            return DevelopmentDatabaseProfile(kind: .current, migrationSourceVersion: nil, ownershipID: nil)
        case .persistentDebug:
            return DevelopmentDatabaseProfile(kind: .persistentDebug, migrationSourceVersion: nil, ownershipID: nil)
        case .temporarySession:
            return DevelopmentDatabaseProfile(
                kind: .temporarySession,
                migrationSourceVersion: nil,
                ownershipID: makeOwnershipID()
            )
        case .migrationSandbox(let sourceVersion):
            guard registeredHistoricalSourceVersions.contains(sourceVersion) else {
                throw DevelopmentDatabaseProfileDomainError.invalidMigrationSourceVersion
            }
            return DevelopmentDatabaseProfile(
                kind: .migrationSandbox,
                migrationSourceVersion: sourceVersion,
                ownershipID: makeOwnershipID()
            )
        }
    }

    func descriptor(verifiedCurrentSchemaVersion: Int) -> DevelopmentDatabaseProfileDescriptor {
        let persistence: DevelopmentDatabaseProfilePersistenceClassification
        let canReset: Bool
        switch kind {
        case .current:
            persistence = .stableCurrent
            canReset = false
        case .persistentDebug:
            persistence = .stableDevelopment
            canReset = true
        case .temporarySession:
            persistence = .processOwnedTemporary
            canReset = true
        case .migrationSandbox:
            persistence = .processOwnedMigrationSandbox
            canReset = true
        }
        return DevelopmentDatabaseProfileDescriptor(
            kind: kind,
            displayName: kind.displayName,
            persistenceClassification: persistence,
            canReset: canReset,
            migrationSourceVersion: migrationSourceVersion,
            verifiedCurrentSchemaVersion: verifiedCurrentSchemaVersion
        )
    }
}

/// Privacy-safe profile state suitable for later Packet B presentation.
struct DevelopmentDatabaseProfileDescriptor: Equatable {
    let kind: DevelopmentDatabaseProfileKind
    let displayName: String
    let persistenceClassification: DevelopmentDatabaseProfilePersistenceClassification
    let canReset: Bool
    let migrationSourceVersion: Int?
    let verifiedCurrentSchemaVersion: Int

    var sourceSchemaLabel: String? {
        migrationSourceVersion.map { "V\($0)" }
    }

    var currentSchemaLabel: String {
        "V\(verifiedCurrentSchemaVersion)"
    }

    var resetActionLabel: String? {
        switch kind {
        case .current:
            return nil
        case .persistentDebug:
            return "Reset Debug Database"
        case .temporarySession:
            return "Start Fresh Temporary Session"
        case .migrationSandbox:
            return "Recreate Sandbox from selected source version"
        }
    }
}

/// One immutable process-local association for the provider generation,
/// privacy-safe profile metadata, and complete runtime projection installed by
/// a successful development database lifecycle commit.
struct DevelopmentDatabaseCommittedRuntimeState {
    let publicationEpoch: UInt64
    let providerGeneration: ProviderGenerationToken
    let activeProfile: DevelopmentDatabaseProfileDescriptor
    let runtimeSnapshot: RepositoryRuntimeSnapshot
}

struct DevelopmentPreparedImportInvalidationResult: Equatable {
    let invalidatedCount: Int

    static let none = DevelopmentPreparedImportInvalidationResult(invalidatedCount: 0)
}

struct DevelopmentDatabaseProfileActivation: Equatable {
    let profile: DevelopmentDatabaseProfileDescriptor
    let hydration: RepositoryStoreHydrationResult
    let preparedImportInvalidation: DevelopmentPreparedImportInvalidationResult
}

enum DevelopmentDatabaseProfileActivationResult: Equatable, CustomStringConvertible {
    case activated(DevelopmentDatabaseProfileActivation)
    case alreadyActive(DevelopmentDatabaseProfileDescriptor)
    case invalidProfile
    case invalidMigrationSourceVersion
    case activityBlocked
    case candidateCreationFailed
    case migrationFailed
    case stagedHydrationFailed
    case publicationFailedBeforeCommit
    case committedButPriorCleanupFailed(DevelopmentDatabaseProfileActivation)
    case resetNotPermitted
    case lifecycleUnavailable

    var description: String {
        switch self {
        case .activated: return "activated"
        case .alreadyActive: return "already-active"
        case .invalidProfile: return "invalid-profile"
        case .invalidMigrationSourceVersion: return "invalid-migration-source-version"
        case .activityBlocked: return "activity-blocked"
        case .candidateCreationFailed: return "candidate-creation-failed"
        case .migrationFailed: return "migration-failed"
        case .stagedHydrationFailed: return "staged-hydration-failed"
        case .publicationFailedBeforeCommit: return "publication-failed-before-commit"
        case .committedButPriorCleanupFailed: return "committed-prior-cleanup-failed"
        case .resetNotPermitted: return "reset-not-permitted"
        case .lifecycleUnavailable: return "lifecycle-unavailable"
        }
    }
}
#endif
