import Combine
import Foundation

@MainActor
final class IBKRFlexSyncSession: ObservableObject {
    @Published private(set) var accountID: String?
    @Published private(set) var queryID: String?
    @Published private(set) var expiry: String?
    @Published private(set) var isBusy = false
    @Published private(set) var canCancel = false
    @Published private(set) var message: String?
    @Published private(set) var lastSuccessfulFetch: Date?
    @Published private(set) var reportDate: String?
    @Published private(set) var positionCount = 0
    @Published private(set) var completedConnectionID: UUID?
    private let enabled: Bool
    private let keychain: IBKRFlexCredentialStore
    private let client: IBKRFlexClient
    private var snapshot: InvestmentSnapshot = .empty
    private var generation: ProviderGenerationToken?
    private var operation: Task<Void, Never>?
    private var credentialMutationInProgress = false
    private var epoch = UUID()
    private var started = false

    init(enabled: Bool = true, keychain: IBKRFlexCredentialStore = .init(), client: IBKRFlexClient = .init()) {
        self.enabled = enabled; self.keychain = keychain; self.client = client
    }
    var isConnectionAvailable: Bool { enabled }
    var connectionSummary: String {
        if isBusy { return "Fetching IBKR holdings…" }
        return accountID == nil ? "Connect with Flex token and query" : "Connected · IBKR Flex"
    }

    func start(store: InvestmentStore = .shared) {
        guard !started else { return }
        started = true; store.ibkrSession = self
        installWithoutObservation(store.snapshot, generation: store.generation)
        notifyInstalledValue()
        guard enabled else { return }
        let keychain = keychain.forbiddingInteraction(), token = epoch
        Task { [weak self] in
            do {
                let saved = try await Task.detached { try keychain.load() }.value
                guard let self, self.epoch == token else { return }
                if let saved { self.installCredentialMetadata(saved) }
            } catch {
                guard let self, self.epoch == token else { return }
                self.message = "Use Refresh now to authorize the saved connection, or enter a replacement token."
            }
        }
    }

    func installWithoutObservation(_ snapshot: InvestmentSnapshot, generation: ProviderGenerationToken?) {
        if self.generation != generation { cancel(silent: true) }
        self.snapshot = snapshot; self.generation = generation
    }
    func notifyInstalledValue() {
        let source = snapshot.latestIBKRFlex
        lastSuccessfulFetch = source?.fetchedAt; reportDate = source?.reportDate
        positionCount = source?.positionCount ?? 0
    }
    func sharedRefreshState(busy: Bool, message: String?) {
        guard operation == nil else { return }
        isBusy = busy; canCancel = false; self.message = message
    }
    private func installCredentialMetadata(_ credentials: IBKRFlexCredentials) {
        accountID = credentials.expectedAccountID; queryID = credentials.queryID; expiry = credentials.ownerReportedExpiry
    }

    func connect(_ credentials: IBKRFlexCredentials) { perform(.entered(credentials)) }
    func useSavedProofToken() { perform(.proof) }
    func refresh() { perform(.saved) }
    private enum Mode { case entered(IBKRFlexCredentials), proof, saved }

    private func perform(_ mode: Mode) {
        guard enabled else { message = "Online connections are disabled in this app session."; return }
        guard !isBusy else { return }
        guard ApplicationAvailability.shared.state.permitsMutation, let generation,
              generation == DatabaseProvider.shared.generationToken else {
            message = "The ledger is not available for an update."; return
        }
        let baseline = snapshot, client = client, keychain = keychain, token = UUID()
        epoch = token; isBusy = true; canCancel = true; message = "Requesting the latest IBKR report…"
        operation = Task { [weak self] in
            defer {
                if let self, self.epoch == token { self.operation = nil; self.isBusy = false; self.canCancel = false }
            }
            do {
                let jobLease: BackgroundJobLease?
                if let sqlite = DatabaseProvider.shared.sqliteProvider {
                    guard let acquired = try BackgroundJobLease.acquire(path: sqlite.databasePath, kind: .ibkrFlex) else {
                        throw IBKRFlexClientError.inFlight
                    }
                    jobLease = acquired
                } else { jobLease = nil }
                defer { withExtendedLifetime(jobLease) {} }
                let credentials: IBKRFlexCredentials
                switch mode {
                case .entered(let entered):
                    if entered.token.isEmpty {
                        guard let saved = try await Task.detached(operation: { try keychain.load() }).value else {
                            throw IBKRFlexSourceError.invalidConfiguration
                        }
                        credentials = try IBKRFlexCredentials(token: saved.token, queryID: entered.queryID,
                            expectedAccountID: entered.expectedAccountID, ownerReportedExpiry: entered.ownerReportedExpiry,
                            summaryUnfilteredOwnerConfirmed: entered.summaryUnfilteredOwnerConfirmed).validated()
                    } else { credentials = try entered.validated() }
                case .proof:
                    guard let saved = try await Task.detached(operation: { try keychain.loadSavedProofToken() }).value else {
                        throw IBKRFlexCredentialError.invalidProofItem
                    }
                    credentials = saved
                case .saved:
                    guard let saved = try await Task.detached(operation: { try keychain.load() }).value else {
                        throw IBKRFlexSourceError.invalidConfiguration
                    }
                    credentials = saved
                }
                let source = try await client.fetch(credentials: credentials)
                try Task.checkCancellation()
                guard let self, self.epoch == token, self.generation == generation,
                      DatabaseProvider.shared.generationToken == generation else { return }
                let workspaceID = baseline.containers.first?.workspaceID ?? "default-workspace"
                let workspace = try DatabaseProvider.shared.workspaceRepo.workspace(id: workspaceID)
                    ?? WorkspaceDTO(id: workspaceID, name: "Default", createdAtISO: Date().formatted(.iso8601))
                let plan = IBKRFlexHoldingsPlan(providerGeneration: generation, workspace: workspace, baseline: baseline, source: source)
                // Verify account binding and freshness before replacing a token.
                _ = try plan.applying(to: DatabaseProvider.shared.investmentRepo.snapshot(workspaceID: workspaceID), now: Date())
                // Security writes cannot be cancelled once started. Complete their
                // connection state truthfully before allowing another user action.
                self.canCancel = false
                do {
                    self.credentialMutationInProgress = true
                    defer { self.credentialMutationInProgress = false }
                    switch mode {
                    case .proof: _ = try await Task.detached { try keychain.copySavedProofToken(verified: credentials) }.value
                    case .entered: try await Task.detached { try keychain.save(credentials) }.value
                    case .saved: break
                    }
                }
                self.installCredentialMetadata(credentials)
                try Task.checkCancellation()
                guard self.epoch == token, self.generation == generation,
                      DatabaseProvider.shared.generationToken == generation else { return }
                let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
                defer { lease.finish() }
                let result = DatabaseProvider.shared.investmentRepo.saveIBKRFlexHoldings(plan)
                guard result == .saved else {
                    if case .rejected(let error) = result { throw error }
                    throw InvestmentError.staleReview
                }
                self.installCredentialMetadata(credentials)
                do {
                    _ = try RepositoryStoreHydrator(workspaceId: workspaceID).hydrateIfNeeded(forceRefresh: true)
                    self.message = "IBKR updated · \(source.positionCount) holdings · report dated \(InvestmentPriceDates.display(source.reportDate))."
                } catch {
                    self.message = "IBKR holdings were saved. Reopen the ledger to reload the view."
                }
                self.lastSuccessfulFetch = source.fetchedAt; self.reportDate = source.reportDate; self.positionCount = source.positionCount
                if case .saved = mode {} else { self.completedConnectionID = token }
                BackgroundUpdateExecutor.publishHint()
            } catch {
                guard let self, self.epoch == token else { return }
                self.message = BackgroundUpdateExecutor.ibkrFailureMessage(error)
            }
        }
    }

    func cancel(silent: Bool = false) {
        // Provider replacement invalidates financial publication through the
        // generation check, but must not release ownership of a Keychain write.
        guard !credentialMutationInProgress else { return }
        guard silent || canCancel else { return }
        epoch = UUID(); operation?.cancel(); operation = nil; isBusy = false; canCancel = false
        Task { await client.cancel() }
        if !silent { message = "Cancelled. Previous IBKR holdings are retained." }
    }
    func disconnect() {
        guard !isBusy else { return }
        let keychain = keychain, token = UUID(); epoch = token; isBusy = true; canCancel = false
        credentialMutationInProgress = true
        operation = Task { [weak self] in
            defer {
                self?.credentialMutationInProgress = false
                if let self, self.epoch == token { self.operation = nil; self.isBusy = false }
            }
            do {
                try await Task.detached { try keychain.disconnect() }.value
                guard let self, self.epoch == token else { return }
                self.accountID = nil; self.queryID = nil; self.expiry = nil
                self.message = "Disconnected. Last fetched holdings are retained."
            } catch { self?.message = BackgroundUpdateExecutor.ibkrFailureMessage(error) }
        }
    }
    deinit { operation?.cancel() }
}
