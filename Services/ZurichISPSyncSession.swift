import AppKit
import Combine
import Foundation

nonisolated enum ZurichISPMonthlySchedule {
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    static func dueDate(inMonthOf date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = 5
        return calendar.date(from: components)!
    }
    static func isDue(at now: Date, lastSuccess: Date?) -> Bool {
        let due = dueDate(inMonthOf: now)
        return now >= due && (lastSuccess.map { $0 < due } ?? true)
    }
    static func nextDate(after now: Date) -> Date {
        let due = dueDate(inMonthOf: now)
        if now < due { return due }
        return calendar.date(byAdding: .month, value: 1, to: due)!
    }
}

/// One app-owned authenticated connection. Settings sends commands; only the
/// monthly calendar and launch/wake catch-up can trigger automatic holdings reads.
@MainActor
final class ZurichISPSyncSession: ObservableObject {
    @Published private(set) var username: String?
    @Published private(set) var credentialLabel: String?
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var lastSuccessfulFetch: Date?
    @Published private(set) var sourceValuationDates: [String] = []
    @Published private(set) var requiresReconnect = false
    private let enabled: Bool
    private let keychain: ZurichISPCredentialStore
    private let client: ZurichISPClient
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private weak var store: InvestmentStore?
    private var snapshot: InvestmentSnapshot = .empty
    private var generation: ProviderGenerationToken?
    private var operation: Task<Void, Never>?
    private var monthlyTimer: Task<Void, Never>?
    private var wakeObservation: AnyCancellable?
    private var gateObservation: AnyCancellable?
    private var epoch = UUID()
    private var timerEpoch = UUID()
    private var started = false
    private var pendingDueCheck = false

    init(enabled: Bool = true, keychain: ZurichISPCredentialStore = .init(), client: ZurichISPClient = .init(),
         now: @escaping @Sendable () -> Date = { Date() },
         sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.enabled = enabled; self.keychain = keychain; self.client = client; self.now = now; self.sleep = sleep
    }

    var connectionSummary: String {
        if isBusy { return "Checking ISP account…" }
        if requiresReconnect { return "Reconnect to resume automatic updates" }
        return username == nil ? "Not connected · statement import available" : "Connected · monthly on the 5th, UTC"
    }

    func start(store: InvestmentStore = .shared) {
        guard enabled, !started else { return }
        started = true; self.store = store; store.ispSession = self
        installWithoutObservation(store.snapshot, generation: store.generation)
        notifyInstalledValue()
        gateObservation = DatabaseActivityGate.shared.didBecomeAvailable.sink { [weak self] in self?.notifyInstalledValue() }
        wakeObservation = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.checkMonthlyDue(); self?.scheduleNextMonth() }
            }
        pendingDueCheck = true
        let keychain = keychain
        Task { [weak self] in
            do {
                let credentials = try await Task.detached { try keychain.load() }.value
                self?.username = credentials?.username
                self?.credentialLabel = try await Task.detached { try keychain.label() }.value
                self?.checkMonthlyDue()
            } catch { self?.message = error.localizedDescription }
        }
        scheduleNextMonth()
    }

    func installWithoutObservation(_ snapshot: InvestmentSnapshot, generation: ProviderGenerationToken?) {
        if self.generation != generation { cancel(silent: true) }
        self.generation = generation; self.snapshot = snapshot
    }

    func notifyInstalledValue() {
        let sources = snapshot.latestZioAccount?.policies ?? []
        lastSuccessfulFetch = snapshot.latestZioAccount?.fetchedAt
        sourceValuationDates = Array(Set(sources.map(\.valuationDay))).sorted()
        if pendingDueCheck { Task { [weak self] in self?.checkMonthlyDue() } }
    }

    func checkMonthlyDue() {
        guard enabled, started else { return }
        guard ApplicationAvailability.shared.state.permitsMutation, generation != nil,
              !DatabaseActivityGate.shared.hasExclusiveOperation else { pendingDueCheck = true; return }
        guard operation == nil else { pendingDueCheck = true; return }
        pendingDueCheck = false
        guard username != nil, !requiresReconnect,
              ZurichISPMonthlySchedule.isDue(at: now(), lastSuccess: lastSuccessfulFetch) else { return }
        fetchHoldings()
    }

    func fetchHoldings() { perform(mode: .holdings) }
    func checkConnection() { perform(mode: .check) }
    func connect(_ credentials: ZurichISPCredentials) { perform(mode: .connect(credentials)) }
    func replaceCredentials(_ credentials: ZurichISPCredentials) { perform(mode: .replace(credentials)) }
    func usePilotConnection() { perform(mode: .pilot) }

    private enum Mode { case holdings, check, connect(ZurichISPCredentials), replace(ZurichISPCredentials), pilot }

    private func perform(mode: Mode) {
        guard enabled, operation == nil else { return }
        guard ApplicationAvailability.shared.state.permitsMutation, let generation,
              generation == DatabaseProvider.shared.generationToken else {
            message = ZurichISPSnapshotError.unavailable.localizedDescription; return
        }
        let baseline = snapshot, keychain = keychain, client = client, now = now
        let expected = Set(baseline.containers.filter { $0.institution == "Zurich ISP" }.map(\.identity))
        let token = UUID(); epoch = token; isBusy = true; message = "Connecting to Zurich…"
        operation = Task { [weak self] in
            defer {
                if let self, self.epoch == token {
                    self.operation = nil; self.isBusy = false
                    if self.pendingDueCheck { Task { [weak self] in self?.checkMonthlyDue() } }
                }
            }
            do {
                let credentials: ZurichISPCredentials
                var pilotMoveToken: ZurichISPCredentialStore.PilotMoveToken?
                switch mode {
                case .connect(let entered): credentials = entered
                case .replace(let entered):
                    guard let saved = try await Task.detached(operation: { try keychain.load() }).value else { throw ZurichISPCredentialError.invalid }
                    credentials = .init(username: entered.username.isEmpty ? saved.username : entered.username,
                        password: entered.password.isEmpty ? saved.password : entered.password,
                        memorablePIN: entered.memorablePIN.isEmpty ? saved.memorablePIN : entered.memorablePIN)
                case .pilot:
                    guard let saved = try await Task.detached(operation: { try keychain.preparePilotMove() }).value else { throw ZurichISPCredentialError.noPilot }
                    credentials = saved.0; pilotMoveToken = saved.1
                case .holdings, .check:
                    guard let saved = try await Task.detached(operation: { try keychain.load() }).value else { throw ZurichISPCredentialError.invalid }
                    credentials = saved
                }
                let receiver = self
                let source = try await client.fetch(credentials: credentials, expectedPolicyIDs: expected) { status in
                    Task { @MainActor in
                        guard let receiver, receiver.epoch == token else { return }
                        receiver.message = status
                    }
                }
                var accepted = try await Task.detached { try ZurichISPAccountSnapshot.parse(source, expectedPolicyIDs: expected, now: now()) }.value
                try Task.checkCancellation()
                guard let self, self.epoch == token, self.generation == generation,
                      DatabaseProvider.shared.generationToken == generation else { return }
                switch mode {
                case .connect, .replace, .pilot:
                    try await Task.detached { try keychain.save(credentials) }.value
                    try Task.checkCancellation()
                    guard self.epoch == token else { return }
                default: break
                }
                if case .pilot = mode {
                    self.message = "Verifying the saved LedgerForge connection…"
                    guard let reloaded = try await Task.detached(operation: { try keychain.load() }).value,
                          reloaded == credentials else { throw ZurichISPCredentialError.unavailable }
                    await client.reset()
                    let verifiedSource = try await client.fetch(credentials: reloaded, expectedPolicyIDs: expected) { status in
                        Task { @MainActor in
                            guard let receiver, receiver.epoch == token else { return }
                            receiver.message = status
                        }
                    }
                    accepted = try await Task.detached { try ZurichISPAccountSnapshot.parse(verifiedSource, expectedPolicyIDs: expected, now: now()) }.value
                    try Task.checkCancellation()
                    guard self.epoch == token, self.generation == generation else { return }
                    guard let moveToken = pilotMoveToken else { throw ZurichISPCredentialError.unavailable }
                    try await Task.detached { try keychain.finishPilotMove(verified: reloaded, token: moveToken) }.value
                    try Task.checkCancellation()
                }
                self.username = credentials.username; self.requiresReconnect = false
                self.credentialLabel = try await Task.detached { try keychain.label() }.value
                if case .check = mode {
                    self.message = "Connection verified · \(accepted.policies.count) policies · \(accepted.positionCount) positions. Holdings were not changed."
                } else {
                    let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
                    defer { lease.finish() }
                    let workspaceID = baseline.containers.first?.workspaceID ?? "default-workspace"
                    let workspace = try DatabaseProvider.shared.workspaceRepo.workspace(id: workspaceID)
                        ?? WorkspaceDTO(id: workspaceID, name: "Default", createdAtISO: now().formatted(.iso8601))
                    let result = DatabaseProvider.shared.investmentRepo.saveZurichHoldings(.init(
                        providerGeneration: generation, workspace: workspace, baseline: baseline, source: accepted))
                    guard result == .saved else {
                        if case .rejected(let error) = result { throw error }
                        throw ZurichISPSnapshotError.unavailable
                    }
                    do {
                        _ = try RepositoryStoreHydrator(workspaceId: workspaceID).hydrateIfNeeded(forceRefresh: true)
                        self.message = "ISP holdings updated · \(accepted.policies.count) policies · \(accepted.positionCount) positions."
                    } catch {
                        self.message = "ISP holdings were saved, but the view could not reload. Reopen the ledger to see the saved update."
                    }
                    self.lastSuccessfulFetch = accepted.fetchedAt
                    self.sourceValuationDates = Array(Set(accepted.policies.map(\.valuationDay))).sorted()
                }
            } catch {
                guard let self, self.epoch == token else { return }
                if let error = error as? ZurichISPClientError,
                   [.rejectedSignIn, .rejectedPIN, .unsupportedSignIn, .sessionExpired].contains(error) { self.requiresReconnect = true }
                self.message = (error as? LocalizedError)?.errorDescription ?? "The ISP update failed. Previous holdings are retained."
            }
        }
    }

    func cancel(silent: Bool = false) {
        epoch = UUID(); operation?.cancel(); operation = nil; isBusy = false; pendingDueCheck = false
        Task { await client.cancel() }
        if !silent { message = "Cancelled. Previous ISP holdings are retained." }
    }

    func disconnect() {
        cancel(silent: true)
        let keychain = keychain
        Task { [weak self] in
            do {
                try await Task.detached { try keychain.disconnect() }.value
                self?.username = nil; self?.requiresReconnect = false
                self?.credentialLabel = nil
                self?.message = "Disconnected. Existing holdings and statement import remain available."
            } catch { self?.message = error.localizedDescription }
        }
    }

    func renameCredential(to label: String) {
        guard !isBusy else { return }
        let keychain = keychain
        Task { [weak self] in
            do {
                try await Task.detached { try keychain.rename(to: label) }.value
                self?.credentialLabel = try await Task.detached { try keychain.label() }.value
                self?.message = "Saved credential renamed."
            } catch { self?.message = error.localizedDescription }
        }
    }

    private func scheduleNextMonth() {
        monthlyTimer?.cancel(); timerEpoch = UUID()
        let token = timerEpoch, due = ZurichISPMonthlySchedule.nextDate(after: now()), sleep = sleep
        let delay = max(0, due.timeIntervalSince(now()))
        monthlyTimer = Task { @concurrent [weak self] in
            do { try await sleep(delay) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.monthReached(token)
        }
    }

    private func monthReached(_ token: UUID) {
        guard token == timerEpoch else { return }
        checkMonthlyDue(); scheduleNextMonth()
    }

    deinit { operation?.cancel(); monthlyTimer?.cancel() }
}
