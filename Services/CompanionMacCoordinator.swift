import AppKit
import Combine
import Foundation

nonisolated private struct CompanionMacLocalState: Codable {
    var format = 1
    var sessionID: String?
    var phoneID: String?
    var activationEpoch: String?
    var connection: CompanionFolderConnection?
    var outgoing: CompanionEnvelope?
    var received: CompanionEnvelope?
    var lastPublishedAt: Date?
    var lastCheckedAt: Date?
    var reviewID: String?
    var reviewWriter: CompanionWriter?
    var reviewChoiceIDs: [String] = []
}

nonisolated struct CompanionMacRecoveryReview: Equatable, Identifiable {
    let priorSessionID: String
    let previousEpoch: String
    let currentEpoch: String
    let phoneID: String
    var id: String { priorSessionID + ":" + currentEpoch }
}

/// One foreground owner. Repository operations finish synchronously before folder I/O.
@MainActor
final class CompanionMacCoordinator: ObservableObject {
    static let shared = CompanionMacCoordinator()
    @Published private(set) var folderName: String?
    @Published private(set) var phoneID: String?
    @Published private(set) var status = "Not paired"
    @Published private(set) var message: String?
    @Published private(set) var isChecking = false
    @Published private(set) var lastPublishedAt: Date?
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var fileChoices: [CompanionFileChoice] = []
    @Published private(set) var reviewWriter: CompanionWriter?
    @Published private(set) var recoveryReview: CompanionMacRecoveryReview?
    private let transport = CompanionFolderTransport()
    private let workspaceID = "default-workspace"
    private var local: CompanionMacLocalState?
    private var directory: URL?
    private var restored = false
    private var timer: Timer?
    private var observations = Set<AnyCancellable>()

    private weak var reportingRates: AlDarReferenceSession?
    private weak var reportingPrices: InvestmentPriceSession?

    func start(rates: AlDarReferenceSession, prices: InvestmentPriceSession) {
        reportingRates = rates; reportingPrices = prices
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                guard NSApplication.shared.isActive else { return }
                await Self.shared.exchange()
            }
        }
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main).sink { _ in Task { await Self.shared.exchange() } }.store(in: &observations)
        do { try load(provider: .shared) } catch { fail(error) }
    }

    private func load(provider: DatabaseProvider) throws {
        guard let sqlite = provider.sqliteProvider else { throw CompanionSyncRepositoryError.unavailable }
        let nextDirectory = URL(fileURLWithPath: sqlite.databasePath).deletingLastPathComponent().appendingPathComponent("Companion", isDirectory: true)
        if directory == nextDirectory, local != nil { try refreshRecovery(provider: provider); return }
        // Never use a prior provider's cached state in a newly selected ledger.
        directory = nextDirectory; local = nil; restored = false; fileChoices = []
        let url = nextDirectory.appendingPathComponent("mac-state-v1.json")
        let value: CompanionMacLocalState
        if FileManager.default.fileExists(atPath: url.path) {
            guard let retained = try CompanionLocalFile.load(CompanionMacLocalState.self, at: url) else { throw CompanionSyncRepositoryError.invalidState }
            value = retained
            guard value.format == 1 else { throw CompanionPacketError.invalid("The saved companion state needs a newer app.") }
            if let out = value.outgoing {
                try out.validate()
                guard out.writer == .mac, out.sessionID == value.sessionID, out.activationEpoch == value.activationEpoch,
                      let phone = value.phoneID else { throw CompanionSyncRepositoryError.invalidState }
                _ = try CompanionMacPacket.decode(out, phoneID: phone)
            }
            if let incoming = value.received {
                try incoming.validate()
                guard incoming.writer == .phone, incoming.sessionID == value.sessionID,
                      incoming.activationEpoch == value.activationEpoch else { throw CompanionSyncRepositoryError.invalidState }
            }
        } else { value = .init() }
        local = value; display()
        try refreshRecovery(provider: provider)
        if value.reviewID != nil { fileChoices = try retainedChoices(value) }
    }
    private func refreshRecovery(provider: DatabaseProvider) throws {
        guard let session = local?.sessionID, let prior = local?.activationEpoch, let phone = local?.phoneID else {
            recoveryReview = nil; return
        }
        let current = try provider.fundingPlanRepo.companionActivationEpoch()
        recoveryReview = current == prior ? nil : .init(priorSessionID: session, previousEpoch: prior,
            currentEpoch: current, phoneID: phone)
    }

    /// Explicit owner recovery starts a new authority in a newly selected folder.
    /// The old database rows and exact local publications remain retained.
    func beginLedgerRecovery(reviewID: String, folder: URL) async {
        guard !isChecking else { return }
        isChecking = true; defer { isChecking = false }
        do {
            let provider = DatabaseProvider.shared
            try load(provider: provider)
            guard let review = recoveryReview, review.id == reviewID, let prior = local, let directory else {
                throw CompanionPacketError.invalid("The ledger comparison changed. Review it again before reconnecting.")
            }
            guard SalaryWorkspaceViewModel.prepareForCompanionReceive(provider: provider) else {
                throw CompanionPacketError.invalid("Keep the current Mac plan successfully before reconnecting.")
            }
            restored = false
            let connection = try await transport.select(folder)
            for writer in [CompanionWriter.mac, .phone] {
                do {
                    _ = try await transport.read(writer)
                    throw CompanionPacketError.invalid("Choose a new folder without companion publications. The previous folder is retained for review.")
                } catch {
                    let ns = error as NSError
                    guard ns.domain == NSCocoaErrorDomain && ns.code == NSFileReadNoSuchFileError else { throw error }
                }
            }
            guard provider.generationToken == DatabaseProvider.shared.generationToken,
                  local?.sessionID == prior.sessionID,
                  try provider.fundingPlanRepo.companionActivationEpoch() == review.currentEpoch else {
                throw RepositoryError.staleProviderGeneration
            }
            let archive = directory.appendingPathComponent("LedgerReviews/" + UUID().uuidString + ".json")
            try CompanionLocalFile.save(prior, to: archive)
            try provider.fundingPlanRepo.reconcileCompanionActivation()
            let active = try provider.fundingPlanRepo.companionSessions(workspaceID: workspaceID).first { $0.disposition == "active" }
            let paired: CompanionSyncSessionDTO
            if let active {
                // A previous attempt may have created its session before local retention failed.
                guard active.phoneID == review.phoneID, active.activationEpoch == review.currentEpoch else {
                    throw CompanionPacketError.invalid("Another pairing now owns this ledger. Review the current connection.")
                }
                paired = active
            } else {
                paired = .init(sessionID: UUID().uuidString, workspaceID: workspaceID,
                    activationEpoch: review.currentEpoch, phoneID: review.phoneID, protocolVersion: 1, disposition: "active")
                try provider.fundingPlanRepo.createCompanionSession(paired)
            }
            var next = CompanionMacLocalState()
            next.sessionID = paired.sessionID; next.phoneID = paired.phoneID
            next.activationEpoch = paired.activationEpoch; next.connection = connection
            try retain(next); recoveryReview = nil; restored = true
            try await performExchange(provider: provider, paired: paired)
            message = "The new Mac publication is ready in the selected folder. Choose that folder on the iPhone to compare and confirm its retained plans. Previous states remain retained."
        } catch { fail(error) }
    }
    private func retain(_ value: CompanionMacLocalState) throws {
        guard let directory else { throw CompanionSyncRepositoryError.unavailable }
        try CompanionLocalFile.save(value, to: directory.appendingPathComponent("mac-state-v1.json"))
        local = value; display()
    }
    private func display() {
        phoneID = local?.phoneID; folderName = local?.connection?.name
        lastPublishedAt = local?.lastPublishedAt; lastCheckedAt = local?.lastCheckedAt
        reviewWriter = local?.reviewWriter
        status = phoneID == nil ? "Not paired" : "Paired · foreground checking"
    }
    private func fail(_ error: Error) {
        status = "Needs attention"; message = error.localizedDescription
    }
    private func session(provider: DatabaseProvider) throws -> CompanionSyncSessionDTO {
        guard let local, let id = local.sessionID, let phone = local.phoneID, let epoch = local.activationEpoch else {
            throw CompanionPacketError.invalid("Pair this Mac with the iPhone first.")
        }
        try provider.fundingPlanRepo.reconcileCompanionActivation()
        guard let found = try provider.fundingPlanRepo.companionSessions(workspaceID: workspaceID).first(where: { $0.sessionID == id }),
              found.phoneID == phone, found.activationEpoch == epoch, found.disposition == "active",
              try provider.fundingPlanRepo.companionActivationEpoch() == epoch else {
            throw CompanionPacketError.invalid("The ledger activation changed. The old pairing and pending edits are retained for reconciliation.")
        }
        return found
    }
    private func requireCurrent(_ provider: DatabaseProvider, _ expected: CompanionSyncSessionDTO) throws {
        guard provider.generationToken == DatabaseProvider.shared.generationToken,
              try session(provider: provider) == expected else { throw RepositoryError.staleProviderGeneration }
    }

    func pair(phoneID: String, folder: URL) async {
        guard !isChecking else { return }
        isChecking = true; defer { isChecking = false }
        do {
            let provider = DatabaseProvider.shared
            try load(provider: provider)
            guard local?.sessionID == nil, UUID(uuidString: phoneID)?.uuidString == phoneID else {
                throw CompanionPacketError.invalid("An existing pairing must be reconciled before it can be replaced.")
            }
            guard SalaryWorkspaceViewModel.prepareForCompanionReceive(provider: provider) else {
                throw CompanionPacketError.invalid("The open Monthly Plan has an unsaved local change. Resolve its save error first.")
            }
            let epoch = try provider.fundingPlanRepo.companionActivationEpoch()
            restored = false
            let connection = try await transport.select(folder)
            guard provider.generationToken == DatabaseProvider.shared.generationToken,
                  try provider.fundingPlanRepo.companionActivationEpoch() == epoch else { throw RepositoryError.staleProviderGeneration }
            try provider.fundingPlanRepo.reconcileCompanionActivation()
            let existing = try provider.fundingPlanRepo.companionSessions(workspaceID: workspaceID)
            let paired: CompanionSyncSessionDTO
            if let old = existing.first(where: { $0.disposition == "active" }) {
                guard old.phoneID == phoneID, old.activationEpoch == epoch else {
                    throw CompanionPacketError.invalid("This ledger already has a retained pairing. Reconcile it before replacing it.")
                }
                paired = old
            } else {
                paired = .init(sessionID: UUID().uuidString, workspaceID: workspaceID, activationEpoch: epoch,
                    phoneID: phoneID, protocolVersion: 1, disposition: "active")
                try provider.fundingPlanRepo.createCompanionSession(paired)
            }
            var next = local ?? .init()
            next.sessionID = paired.sessionID; next.phoneID = phoneID; next.activationEpoch = epoch; next.connection = connection
            try retain(next); restored = true; message = nil
            try await performExchange(provider: provider, paired: paired)
        } catch { fail(error) }
    }
    func reconnect(folder: URL) async {
        guard !isChecking else { return }
        isChecking = true; defer { isChecking = false }
        do {
            let provider = DatabaseProvider.shared; try load(provider: provider)
            let paired = try session(provider: provider)
            restored = false
            let connection = try await transport.select(folder)
            try requireCurrent(provider, paired)
            guard var next = local else { return }; next.connection = connection
            try retain(next); restored = true
            try await performExchange(provider: provider, paired: paired)
        } catch { fail(error) }
    }
    func exchange() async {
        guard !isChecking else { return }
        isChecking = true; defer { isChecking = false }
        do {
            let provider = DatabaseProvider.shared; try load(provider: provider)
            guard local?.sessionID != nil, local?.connection != nil else { return }
            try await performExchange(provider: provider, paired: session(provider: provider))
        } catch { fail(error) }
    }

    private func performExchange(provider: DatabaseProvider, paired: CompanionSyncSessionDTO) async throws {
        guard let connection = local?.connection else { return }
        if !restored {
            let renewed = try await transport.restore(connection)
            try requireCurrent(provider, paired)
            guard var next = local else { return }; next.connection = renewed
            try retain(next); restored = true
        }
        guard SalaryWorkspaceViewModel.prepareForCompanionReceive(provider: provider) else {
            throw CompanionPacketError.invalid("The open Monthly Plan could not be retained. Phone changes are waiting safely.")
        }
        let read: CompanionFolderRead?
        do {
            read = try await transport.read(.phone)
        } catch {
            let ns = error as NSError
            // Only an absent transport file is expected before the first Mac publication.
            guard ns.domain == NSCocoaErrorDomain && ns.code == NSFileReadNoSuchFileError else { throw error }
            read = nil
        }
        try requireCurrent(provider, paired)
        guard SalaryWorkspaceViewModel.prepareForCompanionReceive(provider: provider) else {
            throw CompanionPacketError.invalid("The latest Mac edit could not be retained. Phone changes are waiting safely.")
        }
        if let read {
            try receive(read.envelope, provider: provider, paired: paired)
        }
        try requireCurrent(provider, paired)
        let outgoing = try makePublication(provider: provider, paired: paired)
        guard var next = local else { return }
        next.outgoing = outgoing; next.lastCheckedAt = Date()
        try retain(next)
        try await transport.publish(outgoing)
        try requireCurrent(provider, paired)
        guard var completed = local, completed.outgoing == outgoing else { throw RepositoryError.staleProviderGeneration }
        completed.lastPublishedAt = Date(); try retain(completed)
        message = "Published to the selected folder. Phone receipt is shown on the iPhone after delivery."
    }

    private func receive(_ envelope: CompanionEnvelope, provider: DatabaseProvider, paired: CompanionSyncSessionDTO) throws {
        guard envelope.sessionID == paired.sessionID, envelope.activationEpoch == paired.activationEpoch else {
            throw CompanionPacketError.invalid("The phone file belongs to a different ledger or pairing. Pending edits are retained.")
        }
        let packet = try JSONDecoder().decode(CompanionPhonePacket.self, from: envelope.payload)
        try packet.validate(envelope: envelope, expectedPhoneID: paired.phoneID, lineage: paired.activationEpoch)
        guard try envelope.validateSuccessor(of: local?.received) else { return }
        for proposal in packet.proposals {
            try apply(proposal, provider: provider, paired: paired)
        }
        // Hydrate before exposing acknowledgements. A failure leaves the incoming envelope unaccepted;
        // exact replay finds the already durable receipts on retry without rewriting the plan.
        _ = try RepositoryStoreHydrator(databaseProvider: provider).hydrateIfNeeded(forceRefresh: true)
        guard var next = local else { return }; next.received = envelope
        try retain(next)
    }

    private func apply(_ proposal: CompanionMerge.Proposal, provider: DatabaseProvider,
                       paired: CompanionSyncSessionDTO) throws {
        try provider.withConsistentSnapshot {
            guard let saved = try provider.fundingPlanRepo.companionMonth(sessionID: paired.sessionID, workspaceID: workspaceID, month: proposal.scope.month) else {
                throw CompanionPacketError.invalid("This Monthly Plan has not been prepared on the Mac.")
            }
            let stored = try saved.decodedEnvelope(session: paired)
            let expected = try Self.durableScratchpad(stored.current.scratchpad, provider: provider)
            let binding = try stored.current.binding(for: stored.kernel.scope)
            let transition = try stored.kernel.receiving(proposal)
            var scratch = stored.current.scratchpad
            var metadata = stored.current.metadata
            var canonical: FundingPlan?
            let changesEditor = transition.kind == .applied && transition.state.current != stored.kernel.current
            if changesEditor {
                let decoded = try MonthlyPlanSyncAdapter.decode(document: transition.state.current, against: binding)
                scratch = decoded.scratchpad; metadata = decoded.metadata
                if PlannerInputValidity.hasValidCalculation(plan: scratch.plan, fieldErrors: scratch.fieldErrors,
                    excludedHistoryAccountIDs: binding.excludedHistoryAccountIDs) {
                    scratch.plan.updatedAtISO = ISO8601DateFormatter().string(from: Date())
                    scratch.canonical = scratch.plan; canonical = scratch.plan
                }
            }
            let anchor = Self.replacing(stored.current, scratchpad: scratch, metadata: metadata)
            _ = try provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: paired.sessionID, workspaceID: workspaceID,
                month: proposal.scope.month, expectedActivationEpoch: paired.activationEpoch, expectedStateRevision: saved.stateRevision,
                expectedScratchpad: expected, editor: changesEditor ? try scratch.dto() : expected,
                canonical: try canonical?.persistenceDTO(), binding: binding, metadata: metadata,
                operation: .receive(proposal), currentAnchor: anchor))
        }
    }

    private func makePublication(provider: DatabaseProvider, paired: CompanionSyncSessionDTO) throws -> CompanionEnvelope {
        guard let reportingRates, let reportingPrices else {
            throw CompanionPacketError.invalid("The Mac financial view is not ready. The previous phone snapshot is retained.")
        }
        // This MainActor value capture, repository capture, and envelope encoding
        // have no suspension point. Later session updates cannot change the frozen
        // publication while cloud I/O awaits; the next exchange captures them.
        let readBasis = CompanionMacReadBasis(alDarLegs: reportingRates.legs,
            investmentQuotes: reportingPrices.quotes, rateFailures: reportingRates.failures,
            priceFailures: Set(reportingPrices.failures.keys))
        return try provider.withConsistentSnapshot {
            let capture = try CompanionMacCapture.take(provider: provider, workspaceID: workspaceID,
                selectedGmailAccount: GmailIntakeSession.shared.account, now: Date())
            guard capture.activationEpoch == paired.activationEpoch else { throw RepositoryError.staleProviderGeneration }
            var months: [String: CompanionMacMonthPacket] = [:]
            for scratch in capture.runtime.monthlyScratchpads where scratch.plan.workspaceID == workspaceID {
                let month = scratch.plan.month.canonical
                let expected = try Self.durableScratchpad(scratch, provider: provider)
                let existing = try provider.fundingPlanRepo.companionMonth(sessionID: paired.sessionID, workspaceID: workspaceID, month: month)
                let saved: CompanionMonthSyncDTO
                if let existing {
                    let old = try existing.decodedEnvelope(session: paired)
                    let fresh = try CompanionMacMonthContext.refreshed(old: old.current, runtime: capture.runtime, cache: capture.publicCache)
                    if fresh != old.current {
                        saved = try provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: paired.sessionID, workspaceID: workspaceID,
                            month: month, expectedActivationEpoch: paired.activationEpoch, expectedStateRevision: existing.stateRevision,
                            expectedScratchpad: expected, editor: expected, canonical: nil,
                            binding: old.current.binding(for: paired.scope(month: month)), metadata: old.current.metadata,
                            operation: .refreshDependencies, currentAnchor: fresh)).stored
                    } else { saved = existing }
                } else {
                    let initial = try SalaryWorkspaceViewModel.initialCompanionContext(workspaceID: workspaceID,
                        month: scratch.plan.month, provider: provider)
                    let initialMetadata = MonthlyPlanSyncAdapter.metadata(for: scratch,
                        lexicalContext: .init(defaultLocaleIdentifier: nil, localeIdentifiersByField: initial?.knownLocaleIdentifiers ?? [:]),
                        retaining: .init())
                    let draft = try CompanionMacMonthContext.make(scratchpad: scratch, metadata: initialMetadata,
                        runtime: capture.runtime, cache: capture.publicCache,
                        selectedHistoryAccountIDs: initial?.selectedHistoryAccountIDs ?? [])
                    let anchor = try Self.normalized(draft, scope: paired.scope(month: month))
                    let binding = try anchor.binding(for: paired.scope(month: month))
                    saved = try provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: paired.sessionID, workspaceID: workspaceID,
                        month: month, expectedActivationEpoch: paired.activationEpoch, expectedStateRevision: nil,
                        expectedScratchpad: expected, editor: expected, canonical: nil,
                        binding: binding, metadata: anchor.metadata, operation: .initialize(binding.baselineDocument), currentAnchor: anchor)).stored
                }
                months[month] = try saved.decodedEnvelope(session: paired).packet()
            }
            let previous = local?.outgoing?.generation ?? 0
            guard previous < UInt64.max else { throw CompanionSyncRepositoryError.exhaustedRevision }
            let generation = previous + 1
            let packet = CompanionMacPacket(format: 1, phoneID: paired.phoneID,
                snapshot: try capture.projection(generation: generation, currencies: ReportingCurrencyPreferences.shared.currencies,
                    readBasis: readBasis), months: months)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let envelope = try CompanionEnvelope(sessionID: paired.sessionID, activationEpoch: paired.activationEpoch, writer: .mac,
                generation: generation, payload: encoder.encode(packet))
            try packet.validate(envelope: envelope, expectedPhoneID: paired.phoneID)
            return envelope
        }
    }

    static func isPaired(workspaceID: String, month: SelectedStatementMonth, provider: DatabaseProvider) throws -> Bool {
        guard let active = try activeSession(workspaceID: workspaceID, provider: provider) else { return false }
        return try provider.fundingPlanRepo.companionMonth(sessionID: active.sessionID, workspaceID: workspaceID, month: month.canonical) != nil
    }
    static func lexicalContext(workspaceID: String, month: SelectedStatementMonth, provider: DatabaseProvider) throws -> PlannerLexicalContext? {
        guard let active = try activeSession(workspaceID: workspaceID, provider: provider),
              let saved = try provider.fundingPlanRepo.companionMonth(sessionID: active.sessionID, workspaceID: workspaceID, month: month.canonical) else { return nil }
        return try MonthlyPlanSyncAdapter.lexicalContext(from: saved.decodedEnvelope(session: active).current.metadata)
    }
    /// A local scratchpad write can be newer than the last hydrated store. Read
    /// retained content and lexical origin together before calling hydration a receipt.
    static func retainedEditorContext(workspaceID: String, month: SelectedStatementMonth, provider: DatabaseProvider) throws ->
        (scratchpad: MonthlyPlanScratchpad, lexicalContext: PlannerLexicalContext)? {
        try provider.withConsistentSnapshot {
            guard let active = try activeSession(workspaceID: workspaceID, provider: provider),
                  let saved = try provider.fundingPlanRepo.companionMonth(sessionID: active.sessionID, workspaceID: workspaceID, month: month.canonical) else { return nil }
            let current = try saved.decodedEnvelope(session: active).current
            _ = try durableScratchpad(current.scratchpad, provider: provider)
            return (current.scratchpad, MonthlyPlanSyncAdapter.lexicalContext(from: current.metadata))
        }
    }
    private static func activeSession(workspaceID: String, provider: DatabaseProvider) throws -> CompanionSyncSessionDTO? {
        // Older/in-memory providers without companion storage retain their ordinary planner behavior.
        guard provider.sqliteProvider != nil else { return nil }
        try provider.fundingPlanRepo.reconcileCompanionActivation()
        return try provider.fundingPlanRepo.companionSessions(workspaceID: workspaceID).first { $0.disposition == "active" }
    }
    static func saveLocal(_ scratchpad: MonthlyPlanScratchpad, canonical: FundingPlan?, provider: DatabaseProvider,
                          knownLocaleIdentifiers: [String: String], selectedHistoryAccountIDs: Set<String>) throws {
        try provider.withConsistentSnapshot {
            let workspace = scratchpad.plan.workspaceID, month = scratchpad.plan.month
            guard let paired = try activeSession(workspaceID: workspace, provider: provider),
                  let saved = try provider.fundingPlanRepo.companionMonth(sessionID: paired.sessionID, workspaceID: workspace, month: month.canonical) else {
                if let canonical { _ = try provider.fundingPlanRepo.savePlan(canonical.persistenceDTO(), retaining: scratchpad.dto()) }
                else { try provider.fundingPlanRepo.saveScratchpad(scratchpad.dto()) }
                return
            }
            let old = try saved.decodedEnvelope(session: paired)
            let expected = try durableScratchpad(old.current.scratchpad, provider: provider)
            let metadata = MonthlyPlanSyncAdapter.metadata(for: scratchpad,
                lexicalContext: .init(defaultLocaleIdentifier: nil, localeIdentifiersByField: knownLocaleIdentifiers),
                retaining: old.current.metadata, previousScratchpad: old.current.scratchpad)
            let draft = try CompanionMacMonthContextReader.read(scratchpad: scratchpad, metadata: metadata,
                provider: provider, selectedHistoryAccountIDs: selectedHistoryAccountIDs, now: Date())
            let anchor = try normalized(draft, scope: paired.scope(month: month.canonical))
            let newBinding = try anchor.binding(for: paired.scope(month: month.canonical))
            _ = try provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: paired.sessionID, workspaceID: workspace,
                month: month.canonical, expectedActivationEpoch: paired.activationEpoch, expectedStateRevision: saved.stateRevision,
                expectedScratchpad: expected, editor: try scratchpad.dto(), canonical: try canonical?.persistenceDTO(),
                binding: old.current.binding(for: paired.scope(month: month.canonical)), metadata: anchor.metadata,
                operation: .localEdit(newBinding.baselineDocument), currentAnchor: anchor))
        }
    }
    private static func durableScratchpad(_ scratchpad: MonthlyPlanScratchpad, provider: DatabaseProvider) throws -> MonthlyPlanScratchpadDTO {
        guard let stored = try provider.fundingPlanRepo.scratchpads(workspaceId: scratchpad.plan.workspaceID)
            .first(where: { $0.month == scratchpad.plan.month.canonical }),
            try MonthlyPlanScratchpad.decode(stored) == scratchpad else { throw CompanionSyncRepositoryError.staleScratchpad }
        return stored
    }
    private static func normalized(_ anchor: CompanionMonthAnchor, scope: CompanionMerge.SyncScope) throws -> CompanionMonthAnchor {
        let binding = try anchor.binding(for: scope)
        return replacing(anchor, scratchpad: anchor.scratchpad, metadata: binding.baselineMetadata)
    }
    private static func replacing(_ anchor: CompanionMonthAnchor, scratchpad: MonthlyPlanScratchpad,
                                  metadata: MonthlyPlanSyncAdapter.Metadata, excludedHistory: Set<String>? = nil) -> CompanionMonthAnchor {
        .init(scratchpad: scratchpad, metadata: metadata, bankCurrencies: anchor.bankCurrencies,
              fundingAccountIDs: anchor.fundingAccountIDs, excludedHistoryAccountIDs: excludedHistory ?? anchor.excludedHistoryAccountIDs,
              context: anchor.context)
    }

    func reviewVersions(_ writer: CompanionWriter) async {
        guard !isChecking else { return }; isChecking = true; defer { isChecking = false }
        do {
            let provider = DatabaseProvider.shared; try load(provider: provider)
            let paired = try session(provider: provider)
            guard let connection = local?.connection, let directory else { return }
            restored = false
            _ = try await transport.restore(connection); try requireCurrent(provider, paired); restored = true
            let choices = try await transport.conflictingChoices(writer); try requireCurrent(provider, paired)
            guard !choices.isEmpty else { fileChoices = []; message = "No unresolved file versions were reported."; return }
            let id = UUID().uuidString, folder = directory.appendingPathComponent("VersionReviews/" + id)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for choice in choices {
                let url = folder.appendingPathComponent(choice.id + ".json")
                try choice.bytes.write(to: url, options: .atomic)
                guard try Data(contentsOf: url) == choice.bytes else { throw CompanionTransportError.changedDuringReview }
            }
            guard var next = local else { return }; next.reviewID = id; next.reviewWriter = writer; next.reviewChoiceIDs = choices.map(\.id)
            try retain(next); fileChoices = try retainedChoices(next)
        } catch { fail(error) }
    }
    private func retainedChoices(_ value: CompanionMacLocalState) throws -> [CompanionFileChoice] {
        guard let directory, let id = value.reviewID, UUID(uuidString: id) != nil, let writer = value.reviewWriter else { return [] }
        return try value.reviewChoiceIDs.map { hash in
            guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else { throw CompanionTransportError.changedDuringReview }
            let url = directory.appendingPathComponent("VersionReviews/" + id).appendingPathComponent(hash + ".json")
            let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
            let bytes = try handle.read(upToCount: CompanionEnvelope.maximumBytes + 1) ?? Data()
            guard bytes.count <= CompanionEnvelope.maximumBytes, CompanionEnvelope.hash(bytes) == hash else { throw CompanionTransportError.changedDuringReview }
            do { return .init(id: hash, bytes: bytes, envelope: try CompanionEnvelope.decode(bytes, writer: writer), issue: nil) }
            catch { return .init(id: hash, bytes: bytes, envelope: nil, issue: error.localizedDescription) }
        }
    }
    func resolveVersion(id: String) async {
        guard !isChecking else { return }; isChecking = true; defer { isChecking = false }
        do {
            let provider = DatabaseProvider.shared; try load(provider: provider)
            let paired = try session(provider: provider)
            guard let saved = local, let writer = saved.reviewWriter else { return }
            let choices = try retainedChoices(saved)
            guard let selected = choices.first(where: { $0.id == id })?.envelope else { throw CompanionTransportError.changedDuringReview }
            if writer == .mac {
                guard selected == saved.outgoing else { throw CompanionPacketError.invalid("This Mac version does not match the retained publication. Keep both for reconciliation.") }
            } else {
                let packet = try JSONDecoder().decode(CompanionPhonePacket.self, from: selected.payload)
                try packet.validate(envelope: selected, expectedPhoneID: paired.phoneID, lineage: paired.activationEpoch)
                guard selected.sessionID == paired.sessionID, selected.activationEpoch == paired.activationEpoch else { throw CompanionSyncRepositoryError.invalidSession }
            }
            try await transport.resolveVersions(writer: writer, selectedID: id, retainedChoices: choices,
                lastAccepted: writer == .mac ? saved.outgoing : saved.received)
            try requireCurrent(provider, paired)
            guard var next = local, next.reviewID == saved.reviewID else { throw CompanionTransportError.changedDuringReview }
            next.reviewID = nil; next.reviewWriter = nil; next.reviewChoiceIDs = []
            try retain(next); fileChoices = []; message = "The selected version is retained. Check and publish to continue."
        } catch { fail(error) }
    }
}
