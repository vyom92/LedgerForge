import Foundation

/// The visible foreground ISP request shares MainActor with its synchronous
/// commit entry. Cancel therefore either closes that entry or sees its saved
/// result; it never promises to undo an already-committed holdings snapshot.
@MainActor
final class ZurichISPRefreshRequest {
    private(set) var isCancelled = false
    private(set) var didCommit = false

    /// False means the synchronous publication already saved the holdings.
    @discardableResult
    func cancel() -> Bool {
        guard !didCommit else { return false }
        isCancelled = true
        return true
    }

    func publish(_ operation: () throws -> ZurichISPHoldingsResult) throws -> ZurichISPHoldingsResult {
        try Task.checkCancellation()
        guard !isCancelled else { throw CancellationError() }
        let result = try operation()
        if result == .saved { didCommit = true }
        return result
    }

    func resolved(_ outcome: BackgroundUpdateExecutor.Outcome) -> BackgroundUpdateExecutor.Outcome {
        if didCommit { return .completed(.committedCurrentHoldings) }
        if isCancelled { return .cancelled }
        return outcome
    }
}

/// Existing clients and native publication paths share one process-independent
/// job lease. Network work never holds a SQLite or thread lock across await.
actor BackgroundUpdateExecutor {
    nonisolated static let didPublishNotification = Notification.Name("com.vyom.LedgerForge.background-update-published")
    nonisolated static let didReleaseNotification = Notification.Name("com.vyom.LedgerForge.background-lease-released")
    private let provider: SQLiteRepositoryProvider
    private let activation: LedgerActivationStamp
    private let workspaceID: String
    private let enrollment: BackgroundEnrollment?
    private let enrollmentStore: BackgroundEnrollmentStore
    private let prices: InvestmentPriceClient
    private let fetchRate: @Sendable (AlDarCurrency) async throws -> AlDarUnitReference
    private let gmailTokens: GmailTokenBroker
    private let ispClient: ZurichISPClient
    private let ispCredentials: @Sendable () throws -> ZurichISPCredentials?
    private let ibkrClient = IBKRFlexClient()
    private let origin: BackgroundJobOrigin

    init(provider: SQLiteRepositoryProvider, activation: LedgerActivationStamp, workspaceID: String,
         enrollment: BackgroundEnrollment? = nil, enrollmentStore: BackgroundEnrollmentStore = .init(),
         prices: InvestmentPriceClient = .init(), rates: AlDarCurrentReferenceProvider = .init(),
         gmailTokens: GmailTokenBroker = .init(store: GmailKeychainGrantStore(interaction: .forbidden)),
         ispClient: ZurichISPClient = .init(), origin: BackgroundJobOrigin = .foreground,
         fetchRate: (@Sendable (AlDarCurrency) async throws -> AlDarUnitReference)? = nil,
         ispCredentials: @escaping @Sendable () throws -> ZurichISPCredentials? = {
             try ZurichISPCredentialStore(interaction: .forbidden).load()
         }) {
        self.provider = provider; self.activation = activation; self.workspaceID = workspaceID
        self.enrollment = enrollment; self.enrollmentStore = enrollmentStore
        self.prices = prices; self.fetchRate = fetchRate ?? { try await rates.fetchUnit(currency: $0) }
        self.gmailTokens = gmailTokens; self.ispClient = ispClient; self.origin = origin; self.ispCredentials = ispCredentials
    }

    enum Outcome: Equatable, Sendable {
        case alreadyRunning, notDue, completed(BackgroundJobCompletion), authorityRefused, cancelled
        case ispFailed(String), ibkrFailed(String)
    }

    func runAutomatic(configuration: BackgroundScheduleConfiguration, scheduledTarget: Date? = nil) async {
        guard configuration.enabled else { return }
        _ = await refreshPublic(configuration: configuration, manual: false, scheduledTarget: scheduledTarget)
        await runAutomaticNonPublic(configuration: configuration)
    }

    /// The managed foreground delegates the public legs to the bundled helper,
    /// while Gmail and ISP retain their established executor paths. Keeping
    /// this split here prevents the foreground from racing a helper-owned
    /// public retry after the app closes.
    @discardableResult
    func runAutomaticNonPublic(configuration: BackgroundScheduleConfiguration, recoverInterruptedGmail: Bool = false,
                               recoverInterruptedISP: Bool = false) async -> Bool {
        guard configuration.enabled else { return false }
        // One event belongs to this interrupted receipt, never to a new failure
        // produced by the same pass's monthly or salary-linked attempt.
        let interrupted = recoverInterruptedISP ? try? withAuthority { try provider.backgroundJobRepo.jobRecord(.zurichISP) } : nil
        let claimID = interrupted?.outcome == .retryPending ? interrupted?.claimID : nil
        if configuration.gmailCollectionEnabled {
            _ = await collectGmail(configuration: configuration, manual: false, recoverInterrupted: recoverInterruptedGmail)
        }
        var ispBusy = false
        if configuration.zurichISPHoldingsEnabled {
            ispBusy = await refreshISP(configuration: configuration, manual: false, recovering: claimID) == .alreadyRunning
        }
        let salary = await refreshISP(configuration: configuration, manual: false, salaryCheck: true, recovering: claimID)
        ispBusy = ispBusy || salary == .alreadyRunning
        if configuration.ibkrFlexHoldingsEnabled { _ = await refreshIBKR(configuration: configuration, manual: false) }
        guard recoverInterruptedISP, ispBusy, let interrupted,
              let latest = try? withAuthority({ try provider.backgroundJobRepo.jobRecord(.zurichISP) }),
              latest.claimID == interrupted.claimID else { return false }
        return latest.completedAt == nil || latest.outcome == .retryPending
    }

    private func withAuthority<T>(_ operation: () throws -> T) throws -> T {
        try Task.checkCancellation()
        return try provider.database.withExclusiveAccess {
            guard try provider.database.validatedActivationStamp() == activation else { throw LedgerAccessError.staleActivation }
            if let enrollment { return try enrollmentStore.withValid(enrollment, operation) }
            return try operation()
        }
    }

    private func finish(_ claim: BackgroundJobRecord, _ outcome: BackgroundJobCompletion) -> Outcome {
        do {
            try withAuthority { try provider.backgroundJobRepo.finish(claim, outcome: outcome, now: Date()) }
            Self.publishHint()
            return .completed(outcome)
        } catch { return .authorityRefused }
    }

    private func priceDefinitions() async throws -> [InvestmentPriceDefinition] {
        let provider = provider, workspaceID = workspaceID
        let snapshot = try await MainActor.run { try provider.investmentRepo.snapshot(workspaceID: workspaceID) }
        let mappings = Set(snapshot.holdings.compactMap { holding -> InvestmentPriceMapping? in
            guard let confirmed = InvestmentPriceRegistry.confirmedMapping(for: holding,
                container: snapshot.containers.first { $0.id == holding.containerID }),
                  holding.priceMapping == nil || holding.priceMapping == confirmed else { return nil }
            return confirmed
        })
        return mappings.compactMap { InvestmentPriceRegistry.definition(for: $0) }.sorted { $0.mapping.identity < $1.mapping.identity }
    }

    private func publicIdentities(_ configuration: BackgroundScheduleConfiguration,
                                  progress: [String: BackgroundPublicLegProgress]) async throws -> [String] {
        var identities = AlDarCurrency.allCases.map { "aldar:" + $0.rawValue }.filter {
            configuration.alDarCurrencyRatesEnabled || progress[$0]?.pendingManualRetry == true
        }
        if configuration.investmentPublicPricesEnabled || progress.values.contains(where: { !$0.identity.hasPrefix("aldar:") && $0.pendingManualRetry }) {
            identities += try await priceDefinitions().map { $0.mapping.identity }.filter {
                configuration.investmentPublicPricesEnabled || progress[$0]?.pendingManualRetry == true
            }
        }
        return identities
    }

    /// A retained retry can outlive the holding or its public-price mapping.
    /// Only identities the current executor can service may wake foreground
    /// fallback; otherwise an obsolete past retry repeatedly fires immediately.
    func nextPublicRetry() async throws -> Date? {
        let progress = try withAuthority { try BackgroundPublicProgressStore(database: provider.database).load() }
        let identities = Set(try await publicIdentities(BackgroundScheduleConfiguration(), progress: progress))
        return progress.values.filter {
            identities.contains($0.identity) && !$0.succeeded && $0.attempts < 2 && $0.waitingForConnectivity != true
        }.compactMap(\.retryAt).min()
    }

    enum ConnectivityRelease: Equatable, Sendable {
        case released(BackgroundPublicControlScopes), nothingEligible, busy, authorityRefused
    }

    /// Called only for a real network-available recovery event. The same OS
    /// lease prevents release from racing a helper's in-flight result.
    func releaseInterruptedPublic(configuration: BackgroundScheduleConfiguration, now: Date = Date()) async -> ConnectivityRelease {
        do {
            var lease = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .publicReferences)
            guard lease != nil else { return .busy }
            defer { withExtendedLifetime(lease) {}; lease = nil; Self.releaseHint(.publicReferences) }
            let store = BackgroundPublicProgressStore(database: provider.database)
            let progress = try withAuthority { try store.load() }
            var eligible = configuration
            if !configuration.enabled { eligible.alDarCurrencyRatesEnabled = false; eligible.investmentPublicPricesEnabled = false }
            let identities = Set(try await publicIdentities(eligible, progress: progress))
            var scopes: BackgroundPublicControlScopes = []
            try withAuthority {
                try provider.database.execute(sql: "BEGIN IMMEDIATE;")
                do {
                    for var value in progress.values where identities.contains(value.identity) &&
                        value.waitingForConnectivity == true && !value.succeeded && value.attempts < 2 {
                        value.waitingForConnectivity = false; value.retryAt = now
                        try store.save(value)
                        if value.identity == "aldar:INR" { scopes.insert(.inr) }
                        else if value.identity == "aldar:USD" { scopes.insert(.usd) }
                        else { scopes.formUnion(.provider(String(value.identity.split(separator: "|").first ?? ""))) }
                    }
                    try provider.database.execute(sql: "COMMIT;")
                } catch { try? provider.database.execute(sql: "ROLLBACK;"); throw error }
            }
            return scopes.isEmpty ? .nothingEligible : .released(scopes)
        } catch { return .authorityRefused }
    }

    /// Attempts suppress repeated failures within a slot. Native durable
    /// receipts remain the authority for successful publication after a crash.
    private func simpleDue(_ kind: BackgroundJobKind, slot: Date, nativeSuccess: Date?, recoverInterrupted: Bool = false,
                           recoveringClaim: UUID? = nil) throws -> Bool {
        let receipt = try provider.backgroundJobRepo.jobRecord(kind)
        if kind == .zurichISP, let receipt, receipt.completedAt != nil,
           recoveringClaim == receipt.claimID, receipt.outcome == .retryPending,
           nativeSuccess.map({ $0 < receipt.claimedAt }) ?? true { return true }
        if let nativeSuccess, nativeSuccess >= slot { return false }
        if let receipt, receipt.completedAt != nil,
           receipt.claimedAt >= slot {
            if kind == .gmailCollection, recoverInterrupted, receipt.outcome == .retryPending { return true }
            // A helper denied its own Keychain authorization cannot suppress
            // an already-authorized foreground identity for the whole slot.
            return origin == .foreground && receipt.origin == .helper && receipt.outcome == .refusedCredentialInteraction
        }
        return true
    }

    func refreshPublic(configuration: BackgroundScheduleConfiguration, manual: Bool,
                       scheduledTarget: Date? = nil, scopes: BackgroundPublicControlScopes = .all) async -> Outcome {
        do {
            guard scopes.isValid else { return .authorityRefused }
            var lease = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .publicReferences)
            // An explicit scope may be absent from the current automatic run.
            // Retain it while waiting asynchronously for that run's lease.
            if manual {
                for _ in 0..<120 where lease == nil {
                    try await Task.sleep(for: .seconds(1))
                    try Task.checkCancellation()
                    lease = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .publicReferences)
                }
            }
            guard lease != nil else { return .alreadyRunning }
            defer {
                withExtendedLifetime(lease) {}
                lease = nil
                Self.releaseHint(.publicReferences)
            }
            let now = Date()
            guard let slot = BackgroundSchedule.latestOccurrence(of: configuration.publicReferencesRule, at: now) else { return .notDue }
            let progressStore = BackgroundPublicProgressStore(database: provider.database)
            let existing = try withAuthority { try progressStore.load() }
            let manualRetries = manual ? [] : Set(existing.values.filter(\.pendingManualRetry).map(\.identity))
            let definitions = configuration.investmentPublicPricesEnabled || manualRetries.contains(where: { !$0.hasPrefix("aldar:") })
                ? try await priceDefinitions().filter {
                    scopes.includes(provider: $0.mapping.provider) &&
                    (configuration.investmentPublicPricesEnabled || manualRetries.contains($0.mapping.identity))
                } : []
            let currencies = AlDarCurrency.allCases.filter {
                scopes.contains(.currency($0)) &&
                (configuration.alDarCurrencyRatesEnabled || manualRetries.contains("aldar:" + $0.rawValue))
            }
            let identities = currencies.map { "aldar:" + $0.rawValue } + definitions.map { $0.mapping.identity }
            func automaticallyEnabled(_ identity: String) -> Bool {
                identity.hasPrefix("aldar:") ? configuration.alDarCurrencyRatesEnabled : configuration.investmentPublicPricesEnabled
            }
            let due = identities.filter { identity in
                if manual { return true }
                if let progress = existing[identity], progress.waitingForConnectivity == true,
                   progress.slot == slot || !automaticallyEnabled(identity) { return false }
                if manualRetries.contains(identity), let retryAt = existing[identity]?.retryAt { return retryAt <= now }
                if let progress = existing[identity], progress.slot == slot {
                    return !progress.succeeded && progress.attempts < 2 && (progress.retryAt.map { $0 <= now } ?? true)
                }
                return BackgroundSchedule.publicOpportunity(now: now, lastCovered: nil,
                    rule: configuration.publicReferencesRule, scheduledTarget: scheduledTarget).map { $0 <= now } ?? false
            }
            guard !due.isEmpty else { return .notDue }
            guard let claim = try withAuthority({ try provider.backgroundJobRepo.claim(.publicReferences, activation: activation, origin: origin, now: now) }) else { return .alreadyRunning }
            var attempts: [String: BackgroundPublicLegProgress] = [:]
            for identity in due {
                let retainManual = manualRetries.contains(identity) && !automaticallyEnabled(identity)
                var value = !manual && (existing[identity]?.slot == slot || retainManual)
                    ? existing[identity]! : .init(identity: identity, slot: slot)
                if manual { value.manuallyRequested = true }
                value.attempts += 1; value.succeeded = false; value.retryAt = now.addingTimeInterval(60); value.failure = nil
                value.waitingForConnectivity = false
                try withAuthority { try progressStore.save(value) }
                attempts[identity] = value
            }
            for currency in currencies where due.contains("aldar:" + currency.rawValue) {
                let identity = "aldar:" + currency.rawValue
                var value = attempts[identity]!
                do {
                    let reference = try await fetchRate(currency)
                    value.checkedAt = Date()
                    try Task.checkCancellation()
                    try withAuthority {
                        let cache = SQLiteBackgroundPublicCacheRepository(database: provider.database)
                        let previous = try cache.snapshot(now: Date()).alDarLegs[currency]
                        guard reference.currency == currency, reference.fetchedAt <= Date(),
                              previous.map({ reference.fetchedAt >= $0.fetchedAt }) ?? true else { throw LedgerAccessError.unavailable }
                        value.succeeded = true; value.retryAt = nil
                        try cache.merge(alDarLegs: [currency: reference], investmentQuotes: [:], progress: value, now: Date())
                    }
                    Self.publishHint()
                } catch {
                    value.recordFailure("Rate unavailable", interrupted: ConnectivityInterruption.matches(error), at: Date())
                    try withAuthority { try progressStore.save(value) }
                }
            }
            let groups = Dictionary(grouping: definitions.filter { due.contains($0.mapping.identity) }, by: { $0.mapping.provider })
            for name in InvestmentPriceRegistry.providerOrder {
                guard let definitions = groups[name] else { continue }
                let batches = name == "nasdaq" ? definitions.map { [$0] } : [definitions]
                let client = prices
                let results = await withTaskGroup(of: [String: Swift.Result<InvestmentQuote, InvestmentPriceError>].self,
                    returning: [String: Swift.Result<InvestmentQuote, InvestmentPriceError>].self) { group in
                    var iterator = batches.makeIterator(), combined: [String: Swift.Result<InvestmentQuote, InvestmentPriceError>] = [:]
                    for _ in 0..<min(4, batches.count) { if let batch = iterator.next() { group.addTask { await client.fetch(batch) } } }
                    for await result in group {
                        combined.merge(result) { _, new in new }
                        if !Task.isCancelled, let batch = iterator.next() { group.addTask { await client.fetch(batch) } }
                    }
                    return combined
                }
                for definition in definitions {
                    let identity = definition.mapping.identity
                    var value = attempts[identity]!
                    value.checkedAt = Date()
                    do {
                        try Task.checkCancellation()
                        let quote = try (results[identity] ?? .failure(.unavailable)).get().validated()
                        try withAuthority {
                            let cache = SQLiteBackgroundPublicCacheRepository(database: provider.database)
                            let previous = try cache.snapshot(now: Date()).investmentQuotes[identity]
                            let incoming = quote.retainingUndatedObservation(previous)
                            guard incoming.mapping == definition.mapping, incoming.fetchedAt <= Date(), incoming.canReplace(previous) else { throw InvestmentPriceError.olderResponse }
                            value.succeeded = true; value.retryAt = nil
                            try cache.merge(alDarLegs: [:], investmentQuotes: [identity: incoming], progress: value, now: Date())
                        }
                        Self.publishHint()
                    } catch {
                        value.recordFailure("Price unavailable", interrupted: (error as? InvestmentPriceError) == .networkInterrupted, at: Date())
                        try withAuthority { try progressStore.save(value) }
                    }
                }
            }
            let final = try withAuthority { try progressStore.load() }
            let pending = due.contains { final[$0]?.retryAt != nil || final[$0]?.waitingForConnectivity == true }
            let failed = due.contains { final[$0]?.succeeded != true }
            return finish(claim, pending ? .retryPending : (failed ? .failedFinal : .installedCache))
        } catch { return .authorityRefused }
    }

    func collectGmail(configuration: BackgroundScheduleConfiguration, manual: Bool, recoverInterrupted: Bool = false) async -> Outcome {
        do {
            guard let lease = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .gmailCollection) else { return .alreadyRunning }
            defer { withExtendedLifetime(lease) {} }
            let now = Date()
            guard let slot = BackgroundSchedule.latestOccurrence(of: configuration.gmailRule, at: now) else { return .notDue }
            let stored = try withAuthority { try provider.gmailInboxRepo.storedAccounts() }
            let state = try stored.count == 1 ? provider.gmailInboxRepo.load(account: stored[0]) : nil
            let senders = Set(state?.configuredSenders.filter(\.isSelected).map(\.address) ?? [])
            if !manual, try !simpleDue(.gmailCollection, slot: slot, nativeSuccess: state?.completedThrough(senders: senders), recoverInterrupted: recoverInterrupted) { return .notDue }
            guard let claim = try withAuthority({ try provider.backgroundJobRepo.claim(.gmailCollection, activation: activation, origin: origin, now: now) }) else { return .alreadyRunning }
            guard let state, !senders.isEmpty, state.activeScan != nil || state.completedThrough(senders: senders) != nil else { return finish(claim, .refusedNoCoverage) }
            do {
                let account = try await gmailTokens.savedAccount()
                guard state.account == account else { throw GmailIntakeError.accountMismatch }
                let client = GmailClient(expectedAccount: account, tokens: gmailTokens)
                let inbox: any GmailInboxRepository = if let enrollment {
                    BackgroundGmailRepository(base: provider.gmailInboxRepo, database: provider.database, enrollment: enrollment, store: enrollmentStore)
                } else { provider.gmailInboxRepo }
                let collector = GmailCollector()
                if state.activeScan != nil { _ = try await collector.collect(client: client, inbox: inbox, interval: nil) }
                let current = try inbox.load(account: account)
                guard let through = current.completedThrough(senders: senders) else { return finish(claim, .refusedNoCoverage) }
                if through < now {
                    let interval = try GmailCollectionInterval(from: through, until: now, timeZoneIdentifier: "UTC", senders: senders)
                    _ = try await collector.collect(client: client, inbox: inbox, interval: interval)
                }
                return finish(claim, .collectedNativeReceipts)
            } catch {
                return finish(claim, Self.gmailFailure(error))
            }
        } catch { return .authorityRefused }
    }

    /// Preserve a resumable network interruption without repeatedly retrying
    /// credentials or treating every metadata reload as another opportunity.
    nonisolated static func gmailFailure(_ error: Error) -> BackgroundJobCompletion {
        switch error as? GmailIntakeError {
        case .keychainUnavailable: .refusedCredentialInteraction
        case .network, .timedOut: .retryPending
        default: .failedFinal
        }
    }

    func refreshISP(configuration: BackgroundScheduleConfiguration, manual: Bool, salaryCheck: Bool = false,
                    recovering claimID: UUID? = nil,
                    request: ZurichISPRefreshRequest? = nil) async -> Outcome {
        do {
            try Task.checkCancellation()
            var lease = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .zurichISP)
            guard lease != nil else { return .alreadyRunning }
            defer {
                withExtendedLifetime(lease) {}
                lease = nil
                Self.releaseHint(.zurichISP)
            }
            let now = Date(), provider = provider, workspaceID = workspaceID
            let baseline = try await MainActor.run { try provider.investmentRepo.snapshot(workspaceID: workspaceID) }
            let metadata = try await salaryMetadata()
            let interrupted = try withAuthority { try provider.backgroundJobRepo.jobRecord(.zurichISP) }
            let recovery = interrupted?.claimID == claimID && interrupted?.outcome == .retryPending ? interrupted : nil
            let pending: [SalaryAssistance]
            if let preferences = metadata?.preferences, preferences.salaryISPEnabled {
                pending = metadata!.salaries.filter { salary in
                    SalaryISPVerification.nextCheck(salary, preferences: preferences, now: now, latestFetch: baseline.latestZioAccount?.fetchedAt).map { $0 <= now } == true ||
                        Self.canRecoverSalary(salary, receipt: recovery, now: now, latestFetch: baseline.latestZioAccount?.fetchedAt)
                }
            } else { pending = [] }
            if salaryCheck {
                guard !pending.isEmpty else { return .notDue }
                // Consume an already-completed manual/monthly fetch before any network work.
                if let observed = baseline.latestZioAccount {
                    for salary in pending where SalaryISPVerification.creditDay(salary).map({ observed.fetchedAt >= $0 }) == true &&
                        SalaryISPVerification.hasUnconsumedFetch(observed.fetchedAt, receipt: salary.ispLastFetchAt) {
                        try await storeSalary(SalaryISPVerification.observation(observed, for: salary), replacing: salary)
                    }
                    let current = try await salaryMetadata()
                    guard let preferences = current?.preferences, preferences.salaryISPEnabled else { return .notDue }
                    if !current!.salaries.contains(where: {
                           SalaryISPVerification.nextCheck($0, preferences: preferences, now: now, latestFetch: observed.fetchedAt).map { $0 <= now } == true ||
                               Self.canRecoverSalary($0, receipt: recovery, now: now, latestFetch: observed.fetchedAt)
                       }) {
                        Self.publishHint(); return .notDue
                    }
                }
            }
            guard let slot = BackgroundSchedule.latestOccurrence(of: configuration.zurichISPRule, at: now) else { return .notDue }
            if !manual && !salaryCheck, try !simpleDue(.zurichISP, slot: slot, nativeSuccess: baseline.latestZioAccount?.fetchedAt, recoveringClaim: claimID) { return .notDue }
            let claim: BackgroundJobRecord
            switch try await admitISP(salaryCheck: salaryCheck, now: now, baseline: baseline, recovery: recovery) {
            case .notDue: return .notDue
            case .alreadyRunning: return .alreadyRunning
            case .claimed(let value): claim = value
            }
            do {
                guard let credentials = try ispCredentials() else { return finish(claim, .refusedCredentialInteraction) }
                let expected = Set(baseline.containers.filter { $0.institution == "Zurich ISP" }.map(\.identity))
                let raw = try await ispClient.fetch(credentials: credentials, expectedPolicyIDs: expected, status: { _ in })
                let source = try await Self.parseISP(raw, expected: expected)
                try Task.checkCancellation()
                let enrollment = enrollment, enrollmentStore = enrollmentStore, activation = activation
                let result = try await MainActor.run {
                    let publish = {
                        try provider.database.withExclusiveAccess {
                            guard try provider.database.validatedActivationStamp() == activation,
                                  let workspace = try provider.workspaceRepo.workspace(id: workspaceID) else { throw LedgerAccessError.staleActivation }
                            let save = { provider.investmentRepo.saveZurichHoldings(.init(providerGeneration: provider.generationToken,
                                workspace: workspace, baseline: baseline, source: source, backgroundJob: claim)) }
                            if let enrollment { return try enrollmentStore.withValid(enrollment, save) }
                            return save()
                        }
                    }
                    // This check is after the actor hop, at the actual synchronous
                    // commit entry. Task cancellation also protects helper work.
                    if let request { return try request.publish(publish) }
                    try Task.checkCancellation()
                    return try publish()
                }
                guard result == .saved else {
                    if case .rejected(let error) = result { throw error }
                    if result == .staleProviderGeneration { throw ZurichISPSnapshotError.stale }
                    throw ZurichISPSnapshotError.unavailable
                }
                // Holdings and their receipt are already committed atomically. A
                // metadata failure must never relabel or replay that financial save.
                if metadata?.preferences?.salaryISPEnabled == true {
                    for salary in (try? await salaryMetadata()?.salaries) ?? [] where ![.verified, .dismissed].contains(salary.ispState) {
                        try? await storeSalary(SalaryISPVerification.observation(source, for: salary), replacing: salary)
                    }
                }
                Self.publishHint()
                return .completed(.committedCurrentHoldings)
            } catch {
                // Cancellation leaves an unfinished claim for the next lease
                // owner. It is neither a holdings receipt nor a final failure.
                if Task.isCancelled || error is CancellationError || (error as? ZurichISPClientError) == .cancelled {
                    return .cancelled
                }
                if error is ZurichISPCredentialError { return finish(claim, .refusedCredentialInteraction) }
                if (error as? ZurichISPClientError) == .networkInterrupted { return finish(claim, .retryPending) }
                let outcome = finish(claim, .failedFinal)
                guard outcome == .completed(.failedFinal) else { return outcome }
                let message = Self.ispFailureMessage(error)
                return .ispFailed(message)
            }
        } catch {
            return Task.isCancelled || error is CancellationError ? .cancelled : .authorityRefused
        }
    }

    nonisolated static func canRecoverSalary(_ salary: SalaryAssistance, receipt: BackgroundJobRecord?,
                                             now: Date, latestFetch: Date?) -> Bool {
        guard ![.verified, .dismissed].contains(salary.ispState),
              let credit = SalaryISPVerification.creditDay(salary), credit <= now,
              let receipt, receipt.kind == .zurichISP, receipt.outcome == .retryPending,
              let completed = receipt.completedAt, completed <= now,
              let attempted = salary.ispLastAttemptAt.flatMap({ ISO8601DateFormatter().date(from: $0) }),
              // Salary metadata stores whole ISO seconds; compare at that precision.
              attempted.timeIntervalSince1970 == receipt.claimedAt.timeIntervalSince1970.rounded(.down),
              latestFetch.map({ $0 < receipt.claimedAt }) ?? true else { return false }
        return true
    }

    enum ISPAdmission: Sendable { case notDue, alreadyRunning, claimed(BackgroundJobRecord) }

    /// Read owner choices, admit the request and mark its attempts on MainActor
    /// without suspension. A stale preflight cannot authorize salary-only work.
    func admitISP(salaryCheck: Bool, now: Date, baseline: InvestmentSnapshot,
                  recovery: BackgroundJobRecord?) async throws -> ISPAdmission {
        let provider = provider, activation = activation, workspaceID = workspaceID
        let enrollment = enrollment, store = enrollmentStore, origin = origin
        return try await MainActor.run {
            try Task.checkCancellation()
            return try provider.database.withExclusiveAccess {
                guard try provider.database.validatedActivationStamp() == activation else { throw LedgerAccessError.staleActivation }
                let admit = { () throws -> ISPAdmission in
                    let metadata = try provider.intelligenceRepo.snapshot(workspaceID: workspaceID)
                    if salaryCheck {
                        guard let preferences = metadata?.preferences, preferences.salaryISPEnabled,
                              metadata!.salaries.contains(where: {
                                  SalaryISPVerification.nextCheck($0, preferences: preferences, now: now, latestFetch: baseline.latestZioAccount?.fetchedAt).map { $0 <= now } == true ||
                                  Self.canRecoverSalary($0, receipt: recovery, now: now, latestFetch: baseline.latestZioAccount?.fetchedAt)
                              }) else { return .notDue }
                    }
                    guard let claim = try provider.backgroundJobRepo.claim(.zurichISP, activation: activation, origin: origin, now: now) else { return .alreadyRunning }
                    if metadata?.preferences?.salaryISPEnabled == true {
                        for salary in metadata!.salaries where ![.verified, .dismissed].contains(salary.ispState) &&
                            SalaryISPVerification.creditDay(salary).map({ $0 <= now }) == true {
                            var attempted = salary
                            attempted.ispLastAttemptAt = ISO8601DateFormatter().string(from: now)
                            if attempted.ispBaseline == nil, let previous = baseline.latestZioAccount,
                               SalaryISPVerification.creditDay(salary).map({ previous.fetchedAt < $0 }) == true {
                                attempted.ispBaseline = previous
                                attempted.ispBaselineAsOf = previous.policies.map(\.valuationDay).max()
                            }
                            attempted.ispExplanation = "A shared ISP holdings check was attempted. Contribution verification remains pending."
                            try provider.intelligenceRepo.applyPlanning(.salary(attempted, replacing: salary))
                        }
                    }
                    return .claimed(claim)
                }
                if let enrollment { return try store.withValid(enrollment, admit) }
                return try admit()
            }
        }
    }

    func refreshIBKR(configuration: BackgroundScheduleConfiguration, manual: Bool) async -> Outcome {
        do {
            guard let lease = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .ibkrFlex) else { return .alreadyRunning }
            defer { withExtendedLifetime(lease) {} }
            let provider = provider, workspaceID = workspaceID
            let baseline = try await MainActor.run { try provider.investmentRepo.snapshot(workspaceID: workspaceID) }
            guard let slot = BackgroundSchedule.latestOccurrence(of: configuration.ibkrFlexRule, at: Date()) else { return .notDue }
            if !manual, try !simpleDue(.ibkrFlex, slot: slot, nativeSuccess: baseline.latestIBKRFlex?.fetchedAt) { return .notDue }
            guard let claim = try withAuthority({ try provider.backgroundJobRepo.claim(.ibkrFlex, activation: activation, origin: origin, now: Date()) }) else { return .alreadyRunning }
            do {
                guard let credentials = try IBKRFlexCredentialStore(interaction: .forbidden).load() else { return finish(claim, .refusedCredentialInteraction) }
                let source = try await ibkrClient.fetch(credentials: credentials)
                try Task.checkCancellation()
                let enrollment = enrollment, enrollmentStore = enrollmentStore, activation = activation
                let result = try await MainActor.run {
                    try provider.database.withExclusiveAccess {
                        guard try provider.database.validatedActivationStamp() == activation,
                              let workspace = try provider.workspaceRepo.workspace(id: workspaceID) else { throw LedgerAccessError.staleActivation }
                        let publish = { provider.investmentRepo.saveIBKRFlexHoldings(.init(providerGeneration: provider.generationToken,
                            workspace: workspace, baseline: baseline, source: source, backgroundJob: claim)) }
                        if let enrollment { return try enrollmentStore.withValid(enrollment, publish) }
                        return publish()
                    }
                }
                guard result == .saved else {
                    if case .rejected(let error) = result { throw error }
                    throw InvestmentError.staleReview
                }
                Self.publishHint()
                return .completed(.committedCurrentHoldings)
            } catch {
                if error is IBKRFlexCredentialError { return finish(claim, .refusedCredentialInteraction) }
                let outcome = finish(claim, .failedFinal)
                guard outcome == .completed(.failedFinal) else { return outcome }
                return .ibkrFailed(Self.ibkrFailureMessage(error))
            }
        } catch { return .authorityRefused }
    }

    nonisolated static func ibkrFailureMessage(_ error: Error) -> String {
        switch error {
        case let error as IBKRFlexSourceError: return error.localizedDescription
        case let error as IBKRFlexClientError: return error.localizedDescription
        case let error as IBKRFlexCredentialError: return error.localizedDescription
        case let error as InvestmentError: return error.localizedDescription
        default: return "The IBKR update failed. Previous holdings are retained."
        }
    }

    func nextIBKRTarget(configuration: BackgroundScheduleConfiguration, now: Date = Date()) async throws -> Date? {
        guard configuration.ibkrFlexHoldingsEnabled,
              let slot = BackgroundSchedule.latestOccurrence(of: configuration.ibkrFlexRule, at: now),
              let next = BackgroundSchedule.nextOccurrence(of: configuration.ibkrFlexRule, after: now) else { return nil }
        let provider = provider, workspaceID = workspaceID
        let last = try await MainActor.run { try provider.investmentRepo.snapshot(workspaceID: workspaceID).latestIBKRFlex?.fetchedAt }
        guard try simpleDue(.ibkrFlex, slot: slot, nativeSuccess: last) else { return next }
        let busy = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .ibkrFlex) == nil
        // Recheck a due slot after a concurrent request releases its lease;
        // contention must not defer a missed weekly update by another week.
        return busy ? min(now.addingTimeInterval(60), next) : now
    }

    // Only fixed, app-owned descriptions enter presentation and diagnostics.
    // Transport or database errors can contain private response/query content.
    nonisolated static func ispFailureMessage(_ error: Error) -> String {
        let description: String?
        switch error {
        case let error as ZurichISPClientError: description = error.errorDescription
        case let error as ZurichISPSnapshotError: description = error.errorDescription
        case let error as InvestmentError: description = error.errorDescription
        default: description = nil
        }
        return description ?? "The ISP update failed. Previous holdings are retained."
    }

    private func salaryMetadata() async throws -> FinancialIntelligenceSnapshot? {
        let provider = provider, activation = activation, workspaceID = workspaceID, enrollment = enrollment, store = enrollmentStore
        return try await MainActor.run {
            try provider.database.withExclusiveAccess {
                guard try provider.database.validatedActivationStamp() == activation else { throw LedgerAccessError.staleActivation }
                let read = { try provider.intelligenceRepo.snapshot(workspaceID: workspaceID) }
                if let enrollment { return try store.withValid(enrollment, read) }
                return try read()
            }
        }
    }

    private func storeSalary(_ value: SalaryAssistance, replacing previous: SalaryAssistance) async throws {
        let provider = provider, activation = activation, enrollment = enrollment, store = enrollmentStore
        try await MainActor.run {
            try provider.database.withExclusiveAccess {
                guard try provider.database.validatedActivationStamp() == activation else { throw LedgerAccessError.staleActivation }
                let write = {
                    guard try provider.intelligenceRepo.snapshot(workspaceID: value.workspaceID)?.preferences?.salaryISPEnabled == true else { return }
                    try provider.intelligenceRepo.applyPlanning(.salary(value, replacing: previous))
                }
                if let enrollment { try store.withValid(enrollment, write) } else { try write() }
            }
        }
    }

    func nextSalaryISPCheck(now: Date = Date()) async throws -> Date? {
        guard let metadata = try await salaryMetadata(), let preferences = metadata.preferences, preferences.salaryISPEnabled else { return nil }
        let provider = provider, workspaceID = workspaceID
        let latest = try await MainActor.run { try provider.investmentRepo.snapshot(workspaceID: workspaceID).latestZioAccount?.fetchedAt }
        guard let target = metadata.salaries.compactMap({ SalaryISPVerification.nextCheck($0, preferences: preferences, now: now, latestFetch: latest) }).min() else { return nil }
        if target <= now, try BackgroundJobLease.acquire(path: provider.databasePath, kind: .zurichISP) == nil { return now.addingTimeInterval(60) }
        return target
    }

    @concurrent private static func parseISP(_ raw: ZurichISPSourceAccount, expected: Set<String>) async throws -> ZurichISPAccountSnapshot {
        try ZurichISPAccountSnapshot.parse(raw, expectedPolicyIDs: expected, now: Date())
    }

    func nextAutomaticTarget(configuration: BackgroundScheduleConfiguration, now: Date = Date()) async throws -> Date? {
        guard configuration.enabled else { return nil }
        var targets: [Date] = []
        if let target = try await nextSalaryISPCheck(now: now) { targets.append(target) }
        let progress = try withAuthority { try BackgroundPublicProgressStore(database: provider.database).load() }
        let publicBusy = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .publicReferences) == nil
        for identity in try await publicIdentities(configuration, progress: progress) {
            let automaticallyEnabled = identity.hasPrefix("aldar:") ? configuration.alDarCurrencyRatesEnabled : configuration.investmentPublicPricesEnabled
            if !publicBusy, let current = progress[identity], current.pendingManualRetry, let retry = current.retryAt {
                targets.append(max(now, retry)); continue
            }
            // A completed manual-only request must not enable future clock
            // opportunities for a scope the owner switched off.
            if !automaticallyEnabled { continue }
            guard let slot = BackgroundSchedule.latestOccurrence(of: configuration.publicReferencesRule, at: now),
                  let next = BackgroundSchedule.nextOccurrence(of: configuration.publicReferencesRule, after: now) else { continue }
            if publicBusy { targets.append(next) }
            else if let current = progress[identity], current.slot == slot {
                if !current.succeeded && current.attempts < 2 && current.waitingForConnectivity != true { targets.append(max(now, current.retryAt ?? now)) }
                else { targets.append(next) }
            } else {
                targets.append(BackgroundSchedule.publicOpportunity(now: now, lastCovered: nil, rule: configuration.publicReferencesRule) ?? next)
            }
        }
        if configuration.gmailCollectionEnabled,
           let slot = BackgroundSchedule.latestOccurrence(of: configuration.gmailRule, at: now),
           let next = BackgroundSchedule.nextOccurrence(of: configuration.gmailRule, after: now) {
            let accounts = try provider.gmailInboxRepo.storedAccounts()
            let state = try accounts.count == 1 ? provider.gmailInboxRepo.load(account: accounts[0]) : nil
            let senders = Set(state?.configuredSenders.filter(\.isSelected).map(\.address) ?? [])
            let busy = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .gmailCollection) == nil
            targets.append(try !busy && simpleDue(.gmailCollection, slot: slot, nativeSuccess: state?.completedThrough(senders: senders)) ? now : next)
        }
        if configuration.zurichISPHoldingsEnabled,
           let slot = BackgroundSchedule.latestOccurrence(of: configuration.zurichISPRule, at: now),
           let next = BackgroundSchedule.nextOccurrence(of: configuration.zurichISPRule, after: now) {
            let provider = provider, workspaceID = workspaceID
            let last = try await MainActor.run { try provider.investmentRepo.snapshot(workspaceID: workspaceID).latestZioAccount?.fetchedAt }
            if try simpleDue(.zurichISP, slot: slot, nativeSuccess: last) {
                let busy = try BackgroundJobLease.acquire(path: provider.databasePath, kind: .zurichISP) == nil
                // Reuse the existing bounded ISP contention recheck. A connection
                // check holds this lease but produces no holdings completion.
                targets.append(busy ? min(now.addingTimeInterval(60), next) : now)
            } else {
                // Concurrent success and terminal failure still satisfy this slot.
                targets.append(next)
            }
        }
        if let ibkrTarget = try await nextIBKRTarget(configuration: configuration, now: now) { targets.append(ibkrTarget) }
        return targets.min()
    }

    nonisolated static func publishHint() {
        DistributedNotificationCenter.default().postNotificationName(didPublishNotification, object: nil, userInfo: nil, deliverImmediately: true)
    }
    nonisolated private static func releaseHint(_ kind: BackgroundJobKind) {
        DistributedNotificationCenter.default().postNotificationName(didReleaseNotification, object: kind.rawValue, userInfo: nil, deliverImmediately: true)
    }
}
