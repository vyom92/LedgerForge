// LedgerForge
// DevelopmentProfileAcknowledgementGate.swift

#if DEBUG
import Foundation

/// Bounded action families that require one process-local acknowledgement for
/// each non-current provider generation.
enum DevelopmentProtectedAction: nonisolated Equatable {
    case importPreparation
    case importConfirmation
    case accountDisplayNameMutation
    case categoryCreate
    case categoryRename
    case categoryArchive
    case categoryRestore
    case categoryDelete
    case transactionCategoryAssignment
    case transactionCategoryClear
}

/// Opaque process-local proof for the exact provider generation that prompted
/// the user. Its provider token and action are intentionally not presentation
/// data.
struct DevelopmentProfileAcknowledgementChallenge: nonisolated Equatable {
    fileprivate let providerGeneration: ProviderGenerationToken
    fileprivate let action: DevelopmentProtectedAction
}

struct DevelopmentProfileAcknowledgementState {
    let providerGeneration: ProviderGenerationToken
    let profileKind: DevelopmentDatabaseProfileKind
}

enum DevelopmentProfileAuthorizationResult: nonisolated Equatable {
    case allowed
    case acknowledgementRequired(DevelopmentProfileAcknowledgementChallenge)
    case developmentDatabaseUnavailable
}

enum DevelopmentProfileAcknowledgementGrantResult: nonisolated Equatable {
    case granted
    case noAcknowledgementRequired
    case staleGeneration
    case developmentDatabaseUnavailable
}

enum DevelopmentProtectedActionOutcome: nonisolated Equatable {
    case acknowledgementRequired
    case staleGeneration
    case developmentDatabaseUnavailable
}

enum DevelopmentProfileAcknowledgementError: Error, nonisolated Equatable, LocalizedError {
    case acknowledgementRequired(DevelopmentProfileAcknowledgementChallenge)
    case staleGeneration
    case developmentDatabaseUnavailable

    var errorDescription: String? {
        switch self {
        case .acknowledgementRequired:
            return "Acknowledge the active development database profile before continuing."
        case .staleGeneration:
            return "The active development database changed. Start the action again."
        case .developmentDatabaseUnavailable:
            return "The development database is unavailable."
        }
    }
}

enum DevelopmentProfileAcknowledgementPresentation {
    static let title = "Continue with Development Profile?"
    static let approvalLabel = "Acknowledge and Continue"
    static let message = "This action will affect the active development database profile. Review the profile warning before continuing."
    static let accessibilityText = "Confirmation required before changing the active development database profile."
}

/// The sole process-local acknowledgement authority. It stores only opaque
/// generation equality state and never persists or presents provider identity.
@MainActor
final class DevelopmentProfileAcknowledgementGate {
    static let shared = DevelopmentProfileAcknowledgementGate()

    private let stateProvider: @MainActor () -> DevelopmentProfileAcknowledgementState?
    private var observedGeneration: ProviderGenerationToken?
    private var acknowledgedGeneration: ProviderGenerationToken?

    convenience init() {
        self.init(stateProvider: {
            DevelopmentDatabaseLifecycleCoordinator.shared.committedRuntimeState.map {
                DevelopmentProfileAcknowledgementState(
                    providerGeneration: $0.providerGeneration,
                    profileKind: $0.activeProfile.kind
                )
            }
        })
    }

    init(
        stateProvider: @escaping @MainActor () -> DevelopmentProfileAcknowledgementState?
    ) {
        self.stateProvider = stateProvider
    }

    func authorization(
        for action: DevelopmentProtectedAction,
        providerGeneration: ProviderGenerationToken? = nil
    ) -> DevelopmentProfileAuthorizationResult {
        // Providers outside the Debug lifecycle (for example isolated unit-test
        // memory providers) are not non-current database profiles.
        guard let state = stateProvider() else {
            clearObservedGeneration()
            return .allowed
        }

        let requestedGeneration = providerGeneration ?? state.providerGeneration
        synchronize(to: state.providerGeneration)
        guard state.providerGeneration == requestedGeneration else {
            return .developmentDatabaseUnavailable
        }
        guard state.profileKind != .current else {
            return .allowed
        }
        guard acknowledgedGeneration == state.providerGeneration else {
            return .acknowledgementRequired(
                DevelopmentProfileAcknowledgementChallenge(
                    providerGeneration: state.providerGeneration,
                    action: action
                )
            )
        }
        return .allowed
    }

    func acknowledge(
        _ challenge: DevelopmentProfileAcknowledgementChallenge
    ) -> DevelopmentProfileAcknowledgementGrantResult {
        guard let state = stateProvider() else {
            clearObservedGeneration()
            return .developmentDatabaseUnavailable
        }
        synchronize(to: state.providerGeneration)
        guard state.providerGeneration == challenge.providerGeneration else {
            return .staleGeneration
        }
        guard state.profileKind != .current else {
            return .noAcknowledgementRequired
        }
        acknowledgedGeneration = state.providerGeneration
        return .granted
    }

    func requireAuthorization(
        for action: DevelopmentProtectedAction,
        providerGeneration: ProviderGenerationToken? = nil
    ) throws {
        switch authorization(for: action, providerGeneration: providerGeneration) {
        case .allowed:
            return
        case .acknowledgementRequired(let challenge):
            throw DevelopmentProfileAcknowledgementError.acknowledgementRequired(challenge)
        case .developmentDatabaseUnavailable:
            throw DevelopmentProfileAcknowledgementError.developmentDatabaseUnavailable
        }
    }

    /// Lifecycle publication calls this before publishing a new committed
    /// epoch so no grant can survive activation or reset.
    func noteCommittedGenerationChange() {
        clearObservedGeneration()
    }

    func resetForTesting() {
        clearObservedGeneration()
    }

    var isActiveGenerationAcknowledgedForTesting: Bool {
        guard let state = stateProvider() else { return false }
        return acknowledgedGeneration == state.providerGeneration
    }

    private func synchronize(to generation: ProviderGenerationToken) {
        guard observedGeneration != generation else { return }
        observedGeneration = generation
        acknowledgedGeneration = nil
    }

    private func clearObservedGeneration() {
        observedGeneration = nil
        acknowledgedGeneration = nil
    }
}
#endif
