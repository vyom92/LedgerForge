import AppKit
import Combine
import Foundation

/// Foreground adapter for the same durable executor used by the helper.
/// Settings owns a separate value draft; incoming status never rewrites it.
@MainActor
final class BackgroundUpdatesSession: ObservableObject {
    static let shared = BackgroundUpdatesSession()
    @Published private(set) var configuration = BackgroundScheduleConfiguration()
    @Published private(set) var status = "Off · foreground updates available"
    @Published private(set) var message: String?
    @Published private(set) var available = false
    @Published private(set) var isSaving = false
    @Published private(set) var activeSchedule = false
    @Published private(set) var nextUpdate: Date?
    @Published private(set) var jobRecords: [BackgroundJobKind: BackgroundJobRecord] = [:]
    private let service = BackgroundWorkerService()
    private let enrollmentStore = BackgroundEnrollmentStore()
    private let workerControl = BackgroundWorkerControlClient()
    private var provider: SQLiteRepositoryProvider?
    private var executor: BackgroundUpdateExecutor?
    private var executorEnrollmentRevision: UUID?
    private var unavailableHelperRevision: UUID?
    private var publicRequests = BackgroundPublicControlQueue()
    private var busyPublicScopes: BackgroundPublicControlScopes = []
    private var executionID = UUID()
    private weak var rates: AlDarReferenceSession?
    private weak var prices: InvestmentPriceSession?
    private weak var isp: ZurichISPSyncSession?
    private weak var online: OnlineRefreshCoordinator?
    private var observations: [AnyCancellable] = []
    private var automaticTask: Task<Void, Never>?
    private var publicTask: Task<Void, Never>?
    private var ispTask: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?
    private var reloadInProgress = false
    private var started = false
    private let networkEnabled: Bool

    init(networkEnabled: Bool = ProcessInfo.processInfo.environment["LEDGERFORGE_TEST_HOST"] != "1") {
#if DEBUG
        self.networkEnabled = networkEnabled && ProcessInfo.processInfo.environment["LEDGERFORGE_BACKGROUND_NETWORK_DISABLED"] != "1"
#else
        self.networkEnabled = networkEnabled
#endif
    }

    func start(rates: AlDarReferenceSession, prices: InvestmentPriceSession,
               isp: ZurichISPSyncSession, online: OnlineRefreshCoordinator) {
        guard !started else { return }
        started = true; self.rates = rates; self.prices = prices; self.isp = isp; self.online = online
        observations = [
            DistributedNotificationCenter.default().publisher(for: BackgroundUpdateExecutor.didPublishNotification)
                .receive(on: DispatchQueue.main).sink { [weak self] _ in self?.queueReload() },
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
                .receive(on: DispatchQueue.main).sink { [weak self] _ in self?.queueReload() },
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in self?.queueReload() },
            DatabaseActivityGate.shared.didBecomeAvailable.sink { [weak self] in self?.queueReload() }
        ]
        observations.append(FinancialIntelligenceStore.shared.$snapshot.dropFirst().removeDuplicates().sink { [weak self] _ in self?.queueReload() })
        reload()
        isp.start()
    }

    private func queueReload() {
        guard reloadTask == nil, !reloadInProgress else { return }
        reloadTask = Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            self.reloadTask = nil; self.reload()
        }
    }

    func reload() {
        guard !reloadInProgress, !isSaving else { return }
        reloadInProgress = true
        defer { reloadInProgress = false }
        do {
            guard let current = DatabaseProvider.shared.sqliteProvider else {
                clearExecutor(); installSharedHandlers(false)
                available = false; useForegroundFallback(); return
            }
            let changed = provider?.generationToken != current.generationToken
            if changed {
                clearExecutor()
                unavailableHelperRevision = nil
                provider = current
            }
            configuration = try current.backgroundScheduleRepo.configuration()
            available = DatabaseProvider.shared.persistenceState.isDurable
            let activation = try current.database.validatedActivationStamp()
            let enrolled = try enrollmentStore.load()
            let matching = enrolled?.enabled == true && enrolled?.databasePath == current.databasePath && enrolled?.activation == activation
            let managed = available && configuration.enabled && matching && service.status() == .enabled
                && enrolled?.revision != unavailableHelperRevision
            let revision = managed ? enrolled?.revision : nil
            if changed || activeSchedule != managed || executor == nil || executorEnrollmentRevision != revision {
                cancelExecution()
                executor = BackgroundUpdateExecutor(provider: current, activation: activation, workspaceID: "default-workspace",
                    enrollment: managed ? enrolled : nil)
                executorEnrollmentRevision = revision
            }
            installSharedHandlers(true)
            activeSchedule = managed
            if managed {
                online?.stop(); isp?.setBackgroundScheduleActive(true)
                status = "On · updates can run while LedgerForge is closed"
            } else { useForegroundFallback() }
            if changed, let rates, let prices {
                try current.backgroundPublicCacheRepo.mergeSeed(alDarLegs: rates.legs, investmentQuotes: prices.quotes, now: Date())
            }
            installSharedState(current)
            if ApplicationAvailability.shared.permitsMutation, !DatabaseActivityGate.shared.hasExclusiveOperation {
                let saved = try current.investmentRepo.snapshot(workspaceID: "default-workspace")
                let intelligence = try current.intelligenceRepo.snapshot(workspaceID: "default-workspace")
                if InvestmentStore.shared.generation == current.generationToken,
                   InvestmentStore.shared.snapshot != saved || FinancialIntelligenceStore.shared.snapshot != intelligence {
                    _ = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
                }
                Task { await GmailIntakeSession.shared.reloadInbox() }
                if managed {
                    requestAutomatic()
                    if let revision { workerControl.requestReschedule(enrollmentRevision: revision) { _ in } }
                }
            }
            if !managed { armTimer() }
        } catch {
            clearExecutor(); installSharedHandlers(false)
            available = false; message = "Background state could not be loaded. Foreground updates remain available."
            useForegroundFallback()
        }
    }

    private func useForegroundFallback() {
        activeSchedule = false
        isp?.setBackgroundScheduleActive(false)
        if configuration.enabled {
            status = service.status() == .requiresApproval ? "Needs approval in System Settings · foreground fallback active" : "Not active for this ledger · foreground fallback active"
        } else { status = "Off · foreground updates available" }
        // Starting the legacy clock consumes its launch opportunity. Wait for
        // hydration/recovery before starting, so a blocked launch is not lost.
        if networkEnabled, ApplicationAvailability.shared.permitsMutation, let rates, let prices {
            online?.start(rates: rates, prices: prices)
        }
    }

    private func installSharedHandlers(_ installed: Bool) {
        if installed {
            rates?.sharedRefresh = { [weak self] manual in self?.requestPublic(rates: true, prices: false, manual: manual) }
            rates?.sharedRefreshAll = { [weak self] manual in self?.requestPublic(rates: true, prices: true, manual: manual) }
            prices?.sharedRefresh = { [weak self] in self?.requestPublic(rates: false, prices: true, manual: true) }
            isp?.sharedHoldingsRefresh = { [weak self] manual in self?.requestISP(manual: manual) }
        } else {
            rates?.sharedRefresh = nil; rates?.sharedRefreshAll = nil
            prices?.sharedRefresh = nil; isp?.sharedHoldingsRefresh = nil
        }
    }

    private func cancelExecution() {
        executionID = UUID()
        automaticTask?.cancel(); publicTask?.cancel(); ispTask?.cancel(); timer?.cancel()
        automaticTask = nil; publicTask = nil; ispTask = nil; timer = nil; nextUpdate = nil
        publicRequests = BackgroundPublicControlQueue()
        busyPublicScopes = []
        isp?.sharedRefreshState(busy: false, message: nil)
    }

    private func clearExecutor() {
        cancelExecution()
        executor = nil; provider = nil; executorEnrollmentRevision = nil
    }

    private func installSharedState(_ current: SQLiteRepositoryProvider) {
        guard let snapshot = try? current.backgroundPublicCacheRepo.snapshot(now: Date()),
              let progress = try? BackgroundPublicProgressStore(database: current.database).load() else { return }
        let rateFailures = Set(AlDarCurrency.allCases.filter { progress["aldar:" + $0.rawValue]?.failure != nil })
        let quoteFailures = Dictionary(uniqueKeysWithValues: progress.values.filter { !$0.identity.hasPrefix("aldar:") && $0.failure != nil }.map { ($0.identity, InvestmentPriceError.unavailable) })
        rates?.installShared(snapshot.alDarLegs, failures: rateFailures, busy: publicTask != nil,
            busyCurrencies: Set(AlDarCurrency.allCases.filter { busyPublicScopes.contains(.currency($0)) }))
        prices?.installShared(snapshot.investmentQuotes, failures: quoteFailures, busy: publicTask != nil,
            busyProviders: Set(InvestmentPriceRegistry.providerOrder.filter { busyPublicScopes.contains(.provider($0)) }))
        jobRecords = Dictionary(uniqueKeysWithValues: BackgroundJobKind.allCases.compactMap { kind in
            (try? current.backgroundJobRepo.jobRecord(kind)).map { (kind, $0) }
        })
    }

    private func requestAutomatic(target: Date? = nil) {
        guard networkEnabled, activeSchedule, automaticTask == nil, let executor,
              ApplicationAvailability.shared.permitsMutation else { return }
        let value = configuration, enrollmentRevision = executorEnrollmentRevision, executionID = executionID
        automaticTask = Task { [weak self] in
            guard let self else { return }
            if let enrollmentRevision,
               value.alDarCurrencyRatesEnabled || value.investmentPublicPricesEnabled {
                let status = await self.requestHelperPublic(enrollmentRevision: enrollmentRevision,
                                                            scopes: .init(rates: value.alDarCurrencyRatesEnabled,
                                                                          prices: value.investmentPublicPricesEnabled),
                                                            manual: false)
                guard self.executionID == executionID else { return }
                await self.handleHelperStatus(status, fallbackConfiguration: value, manual: false)
            } else {
                _ = await executor.refreshPublic(configuration: value, manual: false, scheduledTarget: target)
            }
            if self.activeSchedule { await executor.runAutomaticNonPublic(configuration: value) }
            guard self.executionID == executionID else { return }
            self.automaticTask = nil
            if let provider = self.provider { self.installSharedState(provider) }
        }
    }

    private func requestPublic(rates: Bool, prices: Bool, manual: Bool, retryOnly: Bool = false) {
        let scopes = BackgroundPublicControlScopes(
            rates: rates && (manual || !activeSchedule || configuration.alDarCurrencyRatesEnabled),
            prices: prices && (manual || !activeSchedule || configuration.investmentPublicPricesEnabled))
        let force = !retryOnly && (manual || !activeSchedule)
        requestPublic(scopes: scopes, manual: force)
    }

    func refreshCurrency(_ currency: AlDarCurrency) {
        requestPublic(scopes: .currency(currency), manual: true)
    }

    func refreshPrices(provider: String) {
        requestPublic(scopes: .provider(provider), manual: true)
    }

    private func requestPublic(scopes: BackgroundPublicControlScopes, manual: Bool) {
        guard networkEnabled, let executor,
              ApplicationAvailability.shared.permitsMutation,
              publicRequests.enqueue(scopes: scopes, manual: manual) == .accepted else { return }
        busyPublicScopes.formUnion(scopes)
        if let provider { installSharedState(provider) }
        guard publicTask == nil else { return }
        let executionID = executionID
        publicTask = Task { [weak self] in
            guard let self else { return }
            while self.executionID == executionID, let request = self.publicRequests.next() {
                var value = self.activeSchedule ? self.configuration : BackgroundScheduleConfiguration()
                value.enabled = true
                value.alDarCurrencyRatesEnabled = !request.scopes.intersection(.rates).isEmpty
                value.investmentPublicPricesEnabled = !request.scopes.intersection(.prices).isEmpty
                value.gmailCollectionEnabled = false; value.zurichISPHoldingsEnabled = false
                if self.activeSchedule, let enrollmentRevision = self.executorEnrollmentRevision {
                    let status = await self.requestHelperPublic(enrollmentRevision: enrollmentRevision,
                                                                scopes: request.scopes,
                                                                manual: request.manual)
                    guard self.executionID == executionID else { return }
                    await self.handleHelperStatus(status, fallbackConfiguration: value,
                                                  manual: request.manual, scopes: request.scopes)
                } else {
                    let outcome = await executor.refreshPublic(configuration: value, manual: request.manual, scopes: request.scopes)
                    if outcome == .alreadyRunning || outcome == .authorityRefused {
                        self.message = "This refresh could not start. Try again after the current update finishes."
                    }
                }
            }
            guard self.executionID == executionID else { return }
            self.publicTask = nil
            self.publicRequests = BackgroundPublicControlQueue()
            self.busyPublicScopes = []
            if let provider = self.provider { self.installSharedState(provider) }
            if !self.activeSchedule { self.armTimer() }
        }
        if let provider { installSharedState(provider) }
    }

    /// Await acknowledgement, then its read-only drain status without blocking
    /// the UI. Acceptance alone must not clear the selected row's busy state.
    private func requestHelperPublic(enrollmentRevision: UUID, scopes: BackgroundPublicControlScopes,
                                     manual: Bool) async -> BackgroundWorkerControlStatus {
        let acknowledgement = await withCheckedContinuation { continuation in
            workerControl.requestPublic(enrollmentRevision: enrollmentRevision, scopes: scopes, manual: manual) {
                continuation.resume(returning: $0)
            }
        }
        return await BackgroundPublicCompletion.wait(after: acknowledgement) { [workerControl] in
            await withCheckedContinuation { continuation in
                workerControl.publicRequestStatus(enrollmentRevision: enrollmentRevision) {
                    continuation.resume(returning: $0)
                }
            }
        }
    }

    /// A positive error before the helper replies has ambiguous delivery. It
    /// therefore runs only a normal due/retry check under the durable lease;
    /// successful helper work cannot be overwritten or manually duplicated.
    private func handleHelperStatus(_ status: BackgroundWorkerControlStatus,
                                    fallbackConfiguration: BackgroundScheduleConfiguration, manual: Bool,
                                    scopes: BackgroundPublicControlScopes = .all) async {
        switch status {
        case .accepted:
            message = "Background helper accepted the public update."
        case .alreadyRunning:
            message = "Public update is already running in the background helper."
        case .completed:
            message = nil
        case .failed:
            message = "The background refresh could not finish. Try again after the current update finishes."
        case .refused, .unavailable, .indeterminate:
            message = status == .indeterminate
                ? "Helper delivery could not be confirmed. Foreground fallback is checking shared update state."
                : "Background helper is unavailable for this request. Foreground fallback is active."
            unavailableHelperRevision = executorEnrollmentRevision
            useForegroundFallback()
            // Unknown delivery never forces a repeat of a successful leg.
            // The normal due check and OS lease arbitrate with accepted work.
            let executionID = executionID
            _ = await executor?.refreshPublic(configuration: fallbackConfiguration,
                                             manual: manual && status != .indeterminate, scopes: scopes)
            guard self.executionID == executionID else { return }
            armTimer()
        }
    }

    private func requestISP(manual: Bool, salaryCheck: Bool = false) {
        guard networkEnabled, ispTask == nil, let executor, ApplicationAvailability.shared.permitsMutation else { return }
        var value = configuration
        if !activeSchedule { value.zurichISPRule = .monthly(daysUTC: [5], timesUTC: [0]) }
        let executionID = executionID
        isp?.sharedRefreshState(busy: true, message: "Updating ISP holdings…")
        ispTask = Task { [weak self] in
            let outcome = await executor.refreshISP(configuration: value, manual: manual, salaryCheck: salaryCheck)
            if case .ispFailed(let explanation) = outcome {
                DeveloperConsole.shared.error(.runtime, explanation)
            }
            guard let self, self.executionID == executionID else { return }
            self.ispTask = nil
            self.isp?.sharedRefreshState(busy: false, message: Self.summary(outcome))
            self.reload()
        }
    }

    private func armTimer() {
        timer?.cancel()
        nextUpdate = nil
        guard networkEnabled, let executor, let provider else { return }
        let value = configuration, active = activeSchedule, executionID = executionID
        timer = Task { [weak self] in
            do {
                let target: Date?
                if active { target = try await executor.nextAutomaticTarget(configuration: value) }
                else {
                    let publicTarget = try BackgroundPublicProgressStore(database: provider.database).load().values
                        .filter { !$0.succeeded && $0.attempts < 2 }.compactMap(\.retryAt).min()
                    let salaryTarget = try await executor.nextSalaryISPCheck()
                    target = [publicTarget, salaryTarget].compactMap { $0 }.min()
                }
                guard let target, !Task.isCancelled, let self, self.executionID == executionID else { return }
                self.nextUpdate = target
                try await Task.sleep(for: .seconds(max(0, target.timeIntervalSinceNow)))
                guard !Task.isCancelled, self.executionID == executionID else { return }
                if active { self.requestAutomatic(target: target) }
                else {
                    self.requestPublic(rates: true, prices: true, manual: false, retryOnly: true)
                    self.requestISP(manual: false, salaryCheck: true)
                }
            } catch { }
        }
    }

    func save(_ value: BackgroundScheduleConfiguration, replacing baseline: BackgroundScheduleConfiguration,
              authorizeConnections: Bool = false) {
        guard !isSaving, available, let provider else { return }
        isSaving = true; message = nil
        Task { [weak self] in
            guard let self else { return }
            defer { self.isSaving = false; self.reload() }
            var settingsSaved = false
            do {
                _ = try value.validated()
                let activation = try provider.database.validatedActivationStamp()
                if value.enabled {
                    guard try provider.workspaceRepo.workspace(id: "default-workspace") != nil else {
                        self.message = "Import into this ledger before enrolling it for background updates."; return
                    }
                }
                // Revoke publication authority before awaiting process teardown.
                let disabled = BackgroundEnrollment(revision: UUID(), databasePath: provider.databasePath,
                    workspaceID: "default-workspace", activation: activation, enabled: false)
                try provider.database.withExclusiveAccess {
                    guard try provider.backgroundScheduleRepo.configuration() == baseline else { throw LedgerAccessError.staleActivation }
                    try self.enrollmentStore.save(disabled)
                    try provider.backgroundScheduleRepo.saveConfiguration(value)
                }
                settingsSaved = true
                if [.enabled, .requiresApproval].contains(self.service.status()) {
                    try await self.service.unregisterFromForegroundAction()
                }
                guard DatabaseProvider.shared.generationToken == provider.generationToken else { throw LedgerAccessError.staleActivation }
                if value.enabled {
                    let enrolled = BackgroundEnrollment(revision: UUID(), databasePath: provider.databasePath,
                        workspaceID: "default-workspace", activation: try provider.database.validatedActivationStamp(), enabled: true,
                        authorizationRequestedAt: authorizeConnections ? Date() : nil)
                    try self.enrollmentStore.save(enrolled)
                    try self.service.registerFromForegroundAction()
                }
                self.configuration = value
                self.message = value.enabled ? "Background settings saved for this ledger." : "Background helper disabled. Foreground ISP updates use the fifth of the month in UTC."
            } catch {
                self.message = settingsSaved
                    ? "Settings were saved, but the helper could not be activated: \(error.localizedDescription)"
                    : "Background settings could not be saved: \(error.localizedDescription)"
            }
        }
    }

    static func summary(_ outcome: BackgroundUpdateExecutor.Outcome) -> String {
        switch outcome {
        case .alreadyRunning: "This update is already running. The view will refresh when it finishes."
        case .notDue: "Already up to date for this schedule."
        case .authorityRefused: "The ledger changed or is unavailable. Previous data is retained."
        case .ispFailed(let message): message
        case .completed(.committedCurrentHoldings): "ISP holdings updated."
        case .completed(.refusedCredentialInteraction): "Saved connection needs authorization. Open its Settings page or authorize the helper."
        case .completed(.refusedNoCoverage): "Collect a complete interval in Email Statements before automatic collection."
        case .completed(.failedFinal): "Update failed. Previous successful data is retained."
        case .completed(.retryPending): "Successful updates saved. Failed public updates will retry once after 60 seconds."
        case .completed(.collectedNativeReceipts): "Email originals collected. Start a batch in Import Centre to import them."
        case .completed(.installedCache): "Public rates and prices updated."
        }
    }
}
