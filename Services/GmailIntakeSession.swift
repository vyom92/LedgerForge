import Combine
import Foundation

/// Inbox and ledger reconciliation belong to the same provider generation.
/// Consumers must not combine a retained inbox from one ledger with another.
struct GmailIntakeCoverage {
    let generation: ProviderGenerationToken
    let inbox: GmailInboxState?
    let importedSourceIDs: Set<String>
}

@MainActor
final class GmailIntakeSession: ObservableObject {
    static let shared = GmailIntakeSession()
    private static let savedAccountKey = "LedgerForge.EmailStatements.account"

    @Published private(set) var account: String?
    @Published private(set) var isConnected = false
    @Published private(set) var isChecking = false
    @Published private(set) var isCollecting = false
    @Published private(set) var needsClientConfiguration = false
    @Published private(set) var needsAuthorization = false
    @Published private(set) var message: String?
    @Published private(set) var inbox: GmailInboxState?
    @Published private(set) var importedSourceIDs: Set<String> = []
    @Published private(set) var coverage: GmailIntakeCoverage?
    @Published private(set) var progress = GmailCollectionProgress()
    @Published var fromDate = Date()
    @Published var throughDate = Date()
    @Published var timeZoneIdentifier = "UTC"
    @Published var allHistory = false
    @Published var selectedSourceID: String?
    @Published var selectedSenderAddress: String?

    private let tokens: GmailTokenBroker
    private let collector = GmailCollector()
    private let preferences: UserDefaults
    private var client: GmailClient?
    private var task: Task<Void, Never>?
    private var observation: AnyCancellable?

    init(tokens: GmailTokenBroker = GmailTokenBroker(), preferences: UserDefaults = .standard) {
        self.tokens = tokens; self.preferences = preferences
        account = preferences.string(forKey: Self.savedAccountKey)
    }

    var connectionSummary: String {
        if isChecking { return "Checking saved connection…" }
        if isCollecting { return "Collecting email originals…" }
        if isConnected { return "Connected · Read-only Gmail" }
        return account == nil ? "Connect Gmail and collect statement originals" : "Saved inbox · Check connection to collect"
    }
    var sources: [GmailInboxSource] { inbox?.orderedSources ?? [] }
    var batchSources: [GmailInboxSource] {
        sources.filter { !$0.dismissed && !importedSourceIDs.contains($0.id) && $0.acquisition == .available
            && [.pending, .review, .skipped].contains($0.attention) }
    }
    var selectedSource: GmailInboxSource? { selectedSourceID.flatMap { inbox?.sources[$0] } }
    var senderRules: [GmailSenderRule] { inbox?.configuredSenders ?? GmailSenderRule.initial }
    var selectedSenders: Set<String> { Set(senderRules.filter(\.isSelected).map(\.address)) }
    var completedThroughForSelection: Date? { inbox?.completedThrough(senders: selectedSenders) }
    var canEditSenders: Bool {
        account != nil && !isCollecting && DatabaseProvider.shared.persistenceState.isUsable
    }
    var canStartCollection: Bool { canCollect && !selectedSenders.isEmpty }
    var canCollect: Bool {
        isConnected && !isChecking && !isCollecting && DatabaseProvider.shared.persistenceState.isUsable
            && ProductionImportCentre.shared.permitsSourceSelection
    }

    func connect(configuration: Data? = nil, reauthorize: Bool = false) {
        guard !isChecking, !isCollecting else { return }
        isChecking = true; message = nil
        task = Task { [weak self] in
            guard let self else { return }
            defer { isChecking = false; task = nil }
            do {
                if let configuration { try await tokens.configureExistingClient(configuration) }
                if reauthorize { try await tokens.reauthorizeExistingConnection() }
                let selectedAccount = try await tokens.savedAccount()
                let connection = GmailClient(expectedAccount: selectedAccount, tokens: tokens)
                try await connection.verifyAccount()
                try Task.checkCancellation()
                client = connection; account = selectedAccount; isConnected = true; needsClientConfiguration = false
                needsAuthorization = false
                preferences.set(selectedAccount, forKey: Self.savedAccountKey)
                message = "Connected with read-only access. Collection does not import financial data."
                await reloadInbox()
            } catch {
                isConnected = false
                needsClientConfiguration = (error as? GmailIntakeError) == .configurationRequired
                needsAuthorization = (error as? GmailIntakeError) == .unauthorized
                message = Self.message(for: error)
            }
        }
    }

    func collectSelectedRange(replaceIncomplete: Bool = false) {
        do {
            let now = Date()
            let interval: GmailCollectionInterval
            if allHistory {
                interval = try .init(from: nil, until: now, timeZoneIdentifier: timeZoneIdentifier, senders: selectedSenders)
            } else {
                guard let zone = TimeZone(identifier: timeZoneIdentifier) else { throw GmailIntakeError.invalidInterval }
                interval = try .calendarDays(from: fromDate, through: throughDate, timeZone: zone, now: now, senders: selectedSenders)
            }
            collect(interval: interval, replaceIncomplete: replaceIncomplete)
        } catch { message = Self.message(for: error) }
    }

    func collectIncremental() {
        guard let through = completedThroughForSelection else { return }
        do { collect(interval: try .init(from: through, until: Date(), timeZoneIdentifier: timeZoneIdentifier, senders: selectedSenders)) }
        catch { message = Self.message(for: error) }
    }

    func resumeCollection() { collect(interval: nil) }

    func collect(interval: GmailCollectionInterval?, replaceIncomplete: Bool = false) {
        guard canCollect, let client else { return }
        let provider = DatabaseProvider.shared
        let repository = provider.gmailInboxRepo
        let generation = provider.generationToken
        isCollecting = true; message = nil; progress = .init()
        task = Task { [weak self] in
            guard let self else { return }
            defer { isCollecting = false; task = nil }
            do {
                let jobLease: BackgroundJobLease?
                if let sqlite = provider.sqliteProvider {
                    guard let acquired = try BackgroundJobLease.acquire(path: sqlite.databasePath, kind: .gmailCollection) else { throw GmailIntakeError.busy }
                    jobLease = acquired
                } else { jobLease = nil }
                defer { withExtendedLifetime(jobLease) {} }
                let result = try await collector.collect(client: client, inbox: repository, interval: interval,
                                                         replaceIncomplete: replaceIncomplete) { [weak self] value in
                    await MainActor.run {
                        guard DatabaseProvider.shared.generationToken == generation else { return }
                        self?.progress = value
                    }
                }
                guard DatabaseProvider.shared.generationToken == generation else { throw GmailIntakeError.staleProvider }
                progress = result
                message = "Collection complete. Review originals in Import Centre when you are ready to import."
                BackgroundUpdateExecutor.publishHint()
            } catch is CancellationError {
                message = "Collection stopped. Saved originals are retained; resume the incomplete interval when ready."
            } catch { message = Self.message(for: error) }
            await reloadInbox()
        }
    }

    func cancelCollection() { task?.cancel() }

    func saveSender(_ input: String, replacing oldAddress: String?) throws {
        let address = try GmailSenderRule.validatedAddress(input)
        try updateSenderRules { rules in
            guard !rules.contains(where: { $0.address == address && $0.address != oldAddress }) else {
                throw GmailIntakeError.duplicateSender
            }
            if let oldAddress {
                guard let index = rules.firstIndex(where: { $0.address == oldAddress }) else { throw GmailIntakeError.invalidSender }
                rules[index].address = address
            } else { rules.append(.init(address: address, isSelected: true)) }
            rules.sort { $0.address < $1.address }
        }
        selectedSenderAddress = address
    }

    func removeSelectedSender() {
        guard let address = selectedSenderAddress else { return }
        do {
            try updateSenderRules { $0.removeAll { $0.address == address } }
            selectedSenderAddress = nil
        } catch { message = Self.message(for: error) }
    }

    func selectSender(_ address: String, selected: Bool) {
        do {
            try updateSenderRules { rules in
                guard let index = rules.firstIndex(where: { $0.address == address }) else { throw GmailIntakeError.invalidSender }
                rules[index].isSelected = selected
            }
        } catch { message = Self.message(for: error) }
    }

    private func updateSenderRules(_ update: (inout [GmailSenderRule]) throws -> Void) throws {
        guard canEditSenders, let account else { throw GmailIntakeError.busy }
        let repository = DatabaseProvider.shared.gmailInboxRepo
        var state = try repository.load(account: account)
        var rules = state.configuredSenders
        try update(&rules)
        state.senderRules = rules
        inbox = try repository.save(state, originals: [:], expectedRevision: state.revision)
        republishLocalCoverage()
    }

    func bindImportCentre() {
        guard observation == nil else { return }
        observation = ProductionImportCentre.shared.$items.sink { [weak self] items in
            self?.recordAttention(items)
        }
    }

    /// Called only after ordinary recovery/initial hydration. It reads metadata
    /// off the main actor and never launches a mailbox history scan at startup.
    func reloadInbox() async {
        coverage = nil
        guard DatabaseProvider.shared.persistenceState.isUsable else { return }
        let provider = DatabaseProvider.shared
        let repository = provider.gmailInboxRepo
        let generation = provider.generationToken
        let preferredAccount = account
        do {
            let state = try await Task { @concurrent in
                let accounts = try repository.storedAccounts()
                let selected: String?
                if accounts.count == 1 { selected = accounts[0] }
                else if let preferredAccount, accounts.isEmpty || accounts.contains(preferredAccount) { selected = preferredAccount }
                else if accounts.isEmpty { selected = nil }
                else { throw GmailIntakeError.accountMismatch }
                return try selected.map { try repository.load(account: $0) }
            }.value
            guard DatabaseProvider.shared.generationToken == generation else { return }
            if let state {
                account = state.account
                preferences.set(state.account, forKey: Self.savedAccountKey)
                if let client, client.expectedAccount != state.account {
                    self.client = nil; isConnected = false
                }
            }
            inbox = state
            try await reconcileImportedSources(generation: generation)
        } catch { message = Self.message(for: error) }
    }

    func startConfirmedEmailBatch() -> Bool {
        guard !isCollecting, ProductionImportCentre.shared.permitsSourceSelection else { return false }
        let urls = batchSources.compactMap(\.importURL)
        guard !urls.isEmpty, urls.count == batchSources.count else { return false }
        return ProductionImportCentre.shared.startConfirmedBatch(urls, preparationLimit: 2)
    }

    func startSelectedEmailImport() -> Bool {
        guard !isCollecting, ProductionImportCentre.shared.permitsSourceSelection,
              let source = selectedSource, !source.dismissed, source.acquisition == .available,
              let url = source.importURL else { return false }
        return ProductionImportCentre.shared.startConfirmedBatch([url], preparationLimit: 2)
    }

    func dismissSelected() { updateSelected(dismissed: true) }
    func revisitSelected() { updateSelected(dismissed: false) }

    private func updateSelected(dismissed: Bool) {
        guard !isCollecting, ProductionImportCentre.shared.permitsSourceSelection,
              let account, let id = selectedSourceID else { return }
        do {
            let repository = DatabaseProvider.shared.gmailInboxRepo
            var state = try repository.load(account: account)
            guard state.sources[id] != nil else { return }
            state.sources[id]?.dismissed = dismissed
            if !dismissed { state.sources[id]?.attention = .pending }
            inbox = try repository.save(state, originals: [:], expectedRevision: state.revision)
            republishLocalCoverage()
        } catch { message = Self.message(for: error) }
    }

    func status(for source: GmailInboxSource) -> String {
        if importedSourceIDs.contains(source.id) { return "Imported in this ledger" }
        if source.dismissed { return "Dismissed" }
        switch source.acquisition {
        case .pending: return "Awaiting collection"
        case .unavailable: return "Original unavailable · Collect again"
        case .sizeLimit: return "Held · Original exceeds intake size"
        case .available: break
        }
        switch source.attention {
        case .pending: return "Ready to prepare"
        case .review: return "Needs review"
        case .password: return "Needs password"
        case .unsupported: return "Held · Unsupported source"
        case .invalid: return "Held · Validation needs attention"
        case .failed: return "Held · Preparation failed"
        case .skipped: return "Skipped · Available for another batch"
        }
    }

    private func recordAttention(_ items: [ImportCentreCoordinator<PreparedImport>.Item]) {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.inboxAttention, count: items.count)
        defer { GmailQualificationTiming.end(.inboxAttention, started: timing, count: items.count) }
#endif
        guard !isCollecting, let account, DatabaseProvider.shared.persistenceState.isUsable else { return }
        let emailItems = items.filter { $0.sourceURL.scheme == GmailImportSource.scheme }
        guard !emailItems.isEmpty else { return }
        do {
            let repository = DatabaseProvider.shared.gmailInboxRepo
            var state = try repository.load(account: account)
            var changed = false
            for item in emailItems {
                guard item.sourceURL.pathComponents.count == 3,
                      let source = state.sources[item.sourceURL.pathComponents[1]], source.importURL == item.sourceURL else { continue }
                let attention: GmailInboxSource.Attention?
                switch item.phase {
                case .awaitingReview, .awaitingConfirmation: attention = .review
                case .validationFailed: attention = .invalid
                case .failed:
                    switch item.preparationFailure?.family {
                    case .unsupportedInput, .unsupportedStatement: attention = .unsupported
                    case .credentials: attention = .password
                    case .invalidDocument: attention = .invalid
                    default: attention = .failed
                    }
                case .skipped: attention = .skipped
                case .completed:
                    attention = item.completionDisposition == .rejected || item.completionDisposition == .transactionEventBlocked ? .review : .pending
                case .pending, .preparing, .committing, .cancelled: attention = nil
                }
                if let attention, attention != source.attention {
                    state.sources[source.id]?.attention = attention
                    changed = true
                }
            }
            guard changed else { return }
            state = try repository.save(state, originals: [:], expectedRevision: state.revision)
            coverage = nil
            inbox = state
            let generation = DatabaseProvider.shared.generationToken
            Task { [weak self] in try? await self?.reconcileImportedSources(generation: generation) }
        } catch { message = Self.message(for: error) }
    }

    private func reconcileImportedSources(generation: ProviderGenerationToken) async throws {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.inboxReconciliation, count: sources.count)
        defer { GmailQualificationTiming.end(.inboxReconciliation, started: timing, count: sources.count) }
#endif
        var imported: Set<String> = []
        var byDigest: [String: Bool] = [:]
        let snapshot = inbox
        for (index, source) in (snapshot?.orderedSources ?? []).enumerated() {
            guard DatabaseProvider.shared.generationToken == generation else { return }
            if let sha = source.sha256 {
                let isImported: Bool
                if let known = byDigest[sha] { isImported = known }
                else {
                    isImported = try DatabaseProvider.shared.importSessionRepo.successfulImportContainsFingerprint(
                        algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, fingerprint: sha)
                    byDigest[sha] = isImported
                }
                if isImported { imported.insert(source.id) }
            }
            if index % 20 == 0 { await Task.yield() }
        }
        guard DatabaseProvider.shared.generationToken == generation,
              inbox?.account == snapshot?.account, inbox?.revision == snapshot?.revision else { return }
        importedSourceIDs = imported
        coverage = .init(generation: generation, inbox: snapshot, importedSourceIDs: imported)
    }

    /// Sender and dismissal edits change inbox metadata, not accepted imports.
    /// Reuse reconciliation only when it already belongs to this ledger.
    private func republishLocalCoverage() {
        guard let previous = coverage, previous.generation == DatabaseProvider.shared.generationToken else {
            coverage = nil
            return
        }
        coverage = .init(generation: previous.generation, inbox: inbox, importedSourceIDs: previous.importedSourceIDs)
    }

    private static func message(for error: Error) -> String {
        if let error = error as? GmailIntakeError { return error.localizedDescription }
        if let repositoryError = error as? RepositoryError, case .staleProviderGeneration = repositoryError {
            return GmailIntakeError.staleProvider.localizedDescription
        }
        return GmailIntakeError.storageUnavailable.localizedDescription
    }
}
