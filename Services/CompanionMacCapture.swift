import Foundation

/// Value-only foreground observation basis for the read-only phone projection.
/// The monthly editor retains its separately captured durable dependency cache.
struct CompanionMacReadBasis {
    let alDarLegs: [AlDarCurrency: AlDarUnitReference]
    let investmentQuotes: [String: InvestmentQuote]
    let rateFailures: Set<AlDarCurrency>
    let priceFailures: Set<String>
}

/// One synchronous repository generation is captured before any cloud I/O.
/// This is a foreground publication boundary; it does not register a helper.
@MainActor
struct CompanionMacCapture {
    let runtime: RepositoryRuntimeSnapshot
    let publicCache: BackgroundPublicCacheSnapshot
    let publicProgress: [String: BackgroundPublicLegProgress]
    let scopeNotes: [String]
    let activationEpoch: String
    let capturedAt: Date

    static func take(provider: DatabaseProvider, workspaceID: String,
                     selectedGmailAccount: String?, now: Date) throws -> Self {
        guard let sqlite = provider.sqliteProvider else { throw LedgerAccessError.unavailable }
        return try provider.withConsistentSnapshot {
            let stamp = try sqlite.database.validatedActivationStamp()
            guard !stamp.transitioning else { throw LedgerAccessError.unavailable }
            let runtime = try RepositoryStoreHydrator(databaseProvider: provider,
                workspaceId: workspaceID, categoryReconciliationGate: nil,
                participatesInLifecycleGate: false).stageHydration()
            let cache = try sqlite.backgroundPublicCacheRepo.snapshot(now: now)
            let progress = try BackgroundPublicProgressStore(database: sqlite.database).load()
            let inbox = try selectedGmailAccount.map { try provider.gmailInboxRepo.load(account: $0) }
            var imported = Set<String>(), byDigest: [String: Bool] = [:]
            for source in inbox?.orderedSources ?? [] {
                guard let digest = source.sha256 else { continue }
                let accepted: Bool
                if let known = byDigest[digest] { accepted = known }
                else {
                    accepted = try provider.importSessionRepo.successfulImportContainsFingerprint(
                        algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, fingerprint: digest)
                    byDigest[digest] = accepted
                }
                if accepted { imported.insert(source.id) }
            }
            return Self(runtime: runtime, publicCache: cache, publicProgress: progress,
                scopeNotes: NetWorthProjection.scopeNotes(inbox: inbox, importedSourceIDs: imported),
                activationEpoch: stamp.epoch.uuidString, capturedAt: now)
        }
    }

    func projection(generation: UInt64, currencies: [ReportingCurrency],
                    readBasis: CompanionMacReadBasis) throws -> CompanionReadSnapshot {
        let positions = DashboardPositionProjection.make(accounts: runtime.accounts,
            transactions: runtime.transactions, cardSnapshot: runtime.cardSnapshot)
        let valuations = InvestmentPriceSession.makeValuations(snapshot: runtime.investments,
            quotes: readBasis.investmentQuotes)
        let overview = InvestmentOverview.build(holdings: runtime.investments.holdings,
            valuations: valuations, legs: readBasis.alDarLegs,
            containers: runtime.investments.containers, ispAccount: runtime.investments.latestZioAccount)
        let report = NetWorthProjection.make(accounts: runtime.accounts, positions: positions,
            investments: runtime.investments, valuations: valuations,
            membership: runtime.netWorthMembership, currencies: currencies,
            legs: readBasis.alDarLegs, rateFailures: readBasis.rateFailures, priceFailures: readBasis.priceFailures,
            scopeNotes: scopeNotes, now: capturedAt, generation: runtime.providerGeneration)
        return try CompanionMacProjectionBuilder.make(ledgerLineage: activationEpoch,
            publicationID: UUID().uuidString, generation: generation, publishedAt: capturedAt,
            report: report, positions: positions, investmentSnapshot: runtime.investments,
            overview: overview, valuations: valuations, investmentsAvailable: true,
            plannerPresentation: .init(alDarQuote: readBasis.alDarLegs[.inr].flatMap { try? $0.planningQuote() }))
    }
}
