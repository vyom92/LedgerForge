import Testing
@testable import LedgerForge

#if DEBUG
@Suite("Development profile acknowledgement", .serialized)
@MainActor
struct DevelopmentProfileAcknowledgementTests {
    @Test
    func currentProfileRequiresNoAcknowledgement() {
        let generation = ProviderGenerationToken()
        var state = DevelopmentProfileAcknowledgementState(
            providerGeneration: generation,
            profileKind: .current
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })

        #expect(gate.authorization(for: .importPreparation, providerGeneration: generation) == .allowed)
        state = DevelopmentProfileAcknowledgementState(
            providerGeneration: ProviderGenerationToken(),
            profileKind: .current
        )
        #expect(gate.authorization(for: .categoryCreate, providerGeneration: state.providerGeneration) == .allowed)
    }

    @Test
    func firstProtectedActionRequiresAcknowledgementOncePerGeneration() throws {
        let generation = ProviderGenerationToken()
        let state = DevelopmentProfileAcknowledgementState(
            providerGeneration: generation,
            profileKind: .persistentDebug
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })

        let challenge: DevelopmentProfileAcknowledgementChallenge
        switch gate.authorization(for: .importPreparation, providerGeneration: generation) {
        case .acknowledgementRequired(let value):
            challenge = value
        default:
            Issue.record("Expected acknowledgement requirement")
            return
        }

        #expect(!gate.isActiveGenerationAcknowledgedForTesting)
        #expect(gate.acknowledge(challenge) == .granted)
        #expect(gate.isActiveGenerationAcknowledgedForTesting)
        #expect(gate.authorization(for: .accountDisplayNameMutation, providerGeneration: generation) == .allowed)
        #expect(gate.authorization(for: .transactionCategoryClear, providerGeneration: generation) == .allowed)
    }

    @Test
    func generationChangeClearsGrantAndRejectsStaleChallenge() {
        let firstGeneration = ProviderGenerationToken()
        var state = DevelopmentProfileAcknowledgementState(
            providerGeneration: firstGeneration,
            profileKind: .temporarySession
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })

        guard case .acknowledgementRequired(let firstChallenge) = gate.authorization(
            for: .categoryRename,
            providerGeneration: firstGeneration
        ) else {
            Issue.record("Expected first-generation challenge")
            return
        }
        #expect(gate.acknowledge(firstChallenge) == .granted)

        let secondGeneration = ProviderGenerationToken()
        state = DevelopmentProfileAcknowledgementState(
            providerGeneration: secondGeneration,
            profileKind: .temporarySession
        )

        #expect(gate.acknowledge(firstChallenge) == .staleGeneration)
        #expect(!gate.isActiveGenerationAcknowledgedForTesting)
        guard case .acknowledgementRequired = gate.authorization(
            for: .categoryRename,
            providerGeneration: secondGeneration
        ) else {
            Issue.record("Expected a fresh challenge after generation change")
            return
        }
    }

    @Test
    func lifecyclePublicationExplicitlyClearsExistingGrant() {
        let generation = ProviderGenerationToken()
        let state = DevelopmentProfileAcknowledgementState(
            providerGeneration: generation,
            profileKind: .persistentDebug
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })

        guard case .acknowledgementRequired(let challenge) = gate.authorization(
            for: .importPreparation,
            providerGeneration: generation
        ) else {
            Issue.record("Expected acknowledgement requirement")
            return
        }
        #expect(gate.acknowledge(challenge) == .granted)

        gate.noteCommittedGenerationChange()

        guard case .acknowledgementRequired = gate.authorization(
            for: .importPreparation,
            providerGeneration: generation
        ) else {
            Issue.record("Expected lifecycle publication to clear acknowledgement")
            return
        }
    }

    @Test
    func cancellationLeavesGenerationUnacknowledgedAndPresentationIsBounded() {
        let generation = ProviderGenerationToken()
        let state = DevelopmentProfileAcknowledgementState(
            providerGeneration: generation,
            profileKind: .migrationSandbox
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })

        guard case .acknowledgementRequired = gate.authorization(
            for: .categoryDelete,
            providerGeneration: generation
        ) else {
            Issue.record("Expected acknowledgement requirement")
            return
        }

        #expect(!gate.isActiveGenerationAcknowledgedForTesting)
        let text = [
            DevelopmentProfileAcknowledgementPresentation.title,
            DevelopmentProfileAcknowledgementPresentation.approvalLabel,
            DevelopmentProfileAcknowledgementPresentation.message,
            DevelopmentProfileAcknowledgementPresentation.accessibilityText
        ].joined(separator: " ")
        #expect(!text.contains("/"))
        #expect(!text.lowercased().contains("uuid"))
        #expect(!text.lowercased().contains("token"))
        #expect(!text.lowercased().contains("sqlite"))
    }
}
#endif
