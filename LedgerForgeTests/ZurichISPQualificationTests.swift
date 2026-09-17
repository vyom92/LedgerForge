import CryptoKit
import Darwin
import Foundation
import Testing
@testable import LedgerForge

/// This is intentionally an opt-in, live qualification. It makes one native
/// account read, keeps that response sequence in RAM, and replays that same
/// sequence for all subsequent acceptance, cancellation, and failure checks.
/// It never writes a response, credential, synthetic financial DTO, or oracle
/// fixture to disk.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LEDGERFORGE_S97_ZIO_QUALIFY"] == "1"))
@MainActor
struct ZurichISPQualificationTests {
    fileprivate nonisolated enum QualificationError: Error {
        case missingEnvironment
        case missingCredentials
        case independentOracle
        case timeout
    }

    @Test(.globalRuntimeStateIsolation)
    func liveAccountQualificationReplayAndV22Persistence() async throws {
        let directory = try isolatedDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = try copiedQualifiedLedger(into: directory.appendingPathComponent("ledger.sqlite"))
        defer { provider.database.close() }

        let baseline = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        let expectedPolicyIDs = Set(baseline.containers.filter { $0.institution == "Zurich ISP" }.map(\.identity))
        guard expectedPolicyIDs.count == 3 else { throw QualificationError.missingEnvironment }
        #expect(baseline.containers.allSatisfy { $0.zioSource == nil })
        #expect(baseline.holdings.allSatisfy { $0.zioObservationID == nil })
        try BackupCompatibility.verifyDatabase(provider.database)
        let nonISPBefore = nonISP(from: baseline)
        let historyBefore = try historyCounts(provider.database)

        let captured = try await LiveCapture.shared.fetch(expectedPolicyIDs: expectedPolicyIDs)
        #expect(captured.source.policies.count == 3)
        #expect(captured.labels.count == captured.records.count && !captured.labels.isEmpty)
        #expect(captured.records.allSatisfy { $0.statusCode >= 200 && $0.statusCode < 300 && $0.body.count <= 2 * 1024 * 1024 })

        let now = Date()
        let parsed = try ZurichISPAccountSnapshot.parse(captured.source, expectedPolicyIDs: expectedPolicyIDs, now: now)
        #expect(parsed.policyIDs == expectedPolicyIDs && parsed.positionCount == 7)
        #expect(parsed.policies.reduce(0) { $0 + $1.regularStrategy.count } == 7)

        // Python reads the original captured response bodies independently. Its
        // stdout has only digest and count metadata, never source values.
        let oracle = try independentOracle(records: captured.records)
        #expect(oracle.policyCount == 3 && oracle.positionCount == 7 && oracle.regularCount == 7)
        #expect(oracle.digest == digest(of: parsed))
        let reported = try #require(InvestmentOverview.build(holdings: baseline.holdings, valuations: [:], legs: [:], ispAccount: parsed).ispReported)
        let summaryTokens = try [reported.contributions, reported.growth, reported.vested].map { amounts in
            let usd = try #require(amounts.first { $0.currency == "USD" })
            return try InvestmentRatioFormatter.rounded(numerator: usd.numerator, denominator: usd.denominator, places: 0)
        }
        let summaryDigest = SHA256.hash(data: Data(summaryTokens.joined(separator: "|").utf8)).map { String(format: "%02x", $0) }.joined()
        #expect(summaryDigest == oracle.usdSummaryDigest)

        try await compareDirectPolicies(parsed)
        let workspace = try provider.workspaceRepo.workspace(id: "default-workspace")
            ?? WorkspaceDTO(id: "default-workspace", name: "Default", createdAtISO: ISO8601DateFormatter().string(from: now))
        let plan = ZurichISPHoldingsPlan(providerGeneration: provider.generationToken, workspace: workspace,
                                         baseline: baseline, source: parsed)
        let originalHoldingIDs = zioHoldingIDs(in: baseline)
        #expect(provider.investmentRepo.saveZurichHoldings(plan) == .saved)
        let accepted = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        #expect(accepted.latestZioAccount == parsed)
        #expect(nonISP(from: accepted) == nonISPBefore)
        #expect(try historyCounts(provider.database) == historyBefore)
        try comparePersistedFunds(accepted, source: parsed, expectedPolicyIDs: expectedPolicyIDs, originalHoldingIDs: originalHoldingIDs)

        // Same native source content may be accepted again without duplicate
        // holdings/history. A stale original baseline and a wrong provider token
        // must both refuse publication.
        let replayPlan = ZurichISPHoldingsPlan(providerGeneration: provider.generationToken, workspace: workspace,
                                               baseline: accepted, source: parsed)
        #expect(provider.investmentRepo.saveZurichHoldings(replayPlan) == .saved)
        let replayed = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        #expect(try historyCounts(provider.database) == historyBefore)
        try comparePersistedFunds(replayed, source: parsed, expectedPolicyIDs: expectedPolicyIDs, originalHoldingIDs: originalHoldingIDs)
        #expect(provider.investmentRepo.saveZurichHoldings(plan) == .rejected(.staleReview))
        let wrongGeneration = ZurichISPHoldingsPlan(providerGeneration: ProviderGenerationToken(), workspace: workspace,
                                                     baseline: replayed, source: parsed)
        #expect(provider.investmentRepo.saveZurichHoldings(wrongGeneration) == .staleProviderGeneration)

        try await replayAndFailureRetention(captured, expectedPolicyIDs: expectedPolicyIDs, provider: provider,
                                            workspaceID: workspace.id, accepted: replayed)
        try await sessionFailureRetention(captured, provider: provider, accepted: replayed)
        try await backupRestoreAndReopen(provider: provider, databaseURL: directory.appendingPathComponent("ledger.sqlite"), expected: replayed)
        print("S97 ZIO live coverage: 3 policies, 7 positions, 7 Regular entries; native response replay, direct V22 persistence, stale/generation refusal, backup/reopen covered.")
    }

    @Test func authenticClosingCSVExercisesTheOrdinaryParserInMemoryAndSQLite() async throws {
        let sources = try closingCSVSources()
        #expect(sources.count == 3)
        let directory = try isolatedDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sqlite = try SQLiteRepositoryProvider(path: directory.appendingPathComponent("ordinary.sqlite").path)
        defer { sqlite.database.close() }
        for provider in [DatabaseProvider(inMemory: true), DatabaseProvider.verifiedSQLite(sqlite)] {
            let engine = importEngine(provider)
            for source in sources {
                let prepared = try await engine.prepareImport(from: source)
                guard let snapshot = prepared.investmentReview?.snapshot else {
                    engine.cancelPreparedImport(prepared)
                    throw QualificationError.missingEnvironment
                }
                let result = await engine.commitPreparedImport(prepared)
                #expect(result.succeeded)
                #expect(try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == snapshot)
            }
            let current = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
            let expectedPolicyIDs = Set(current.containers.filter { $0.institution == "Zurich ISP" }.map(\.identity))
            #expect(expectedPolicyIDs.count == 3)
            let captured = try await LiveCapture.shared.fetch(expectedPolicyIDs: expectedPolicyIDs)
            let direct = try ZurichISPAccountSnapshot.parse(captured.source, expectedPolicyIDs: expectedPolicyIDs, now: Date())
            let workspace = try provider.workspaceRepo.workspace(id: "default-workspace")
                ?? WorkspaceDTO(id: "default-workspace", name: "Default", createdAtISO: ISO8601DateFormatter().string(from: Date()))
            #expect(provider.investmentRepo.saveZurichHoldings(.init(providerGeneration: provider.generationToken,
                workspace: workspace, baseline: current, source: direct)) == .saved)
            let updated = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
            #expect(updated.latestZioAccount == direct)
            try comparePersistedFunds(updated, source: direct, expectedPolicyIDs: expectedPolicyIDs,
                                      originalHoldingIDs: zioHoldingIDs(in: current))
        }
    }

    private func replayAndFailureRetention(_ captured: Captured, expectedPolicyIDs: Set<String>,
                                            provider: SQLiteRepositoryProvider, workspaceID: String,
                                            accepted: InvestmentSnapshot) async throws {
        let credentials = try await LiveCapture.shared.credentials()
        let replay = FIFOReplay(records: captured.records)
        let replayClient = ZurichISPClient(transport: { request, _ in try await replay.response(for: request) })
        let replayed = try await replayClient.fetch(credentials: credentials, expectedPolicyIDs: expectedPolicyIDs, status: { _ in })
        #expect(try ZurichISPAccountSnapshot.parse(replayed, expectedPolicyIDs: expectedPolicyIDs, now: Date()).policyIDs == expectedPolicyIDs)

        let failing = FIFOReplay(records: captured.records, failAt: max(1, captured.records.count - 1))
        let failedClient = ZurichISPClient(transport: { request, _ in try await failing.response(for: request) })
        do {
            _ = try await failedClient.fetch(credentials: credentials, expectedPolicyIDs: expectedPolicyIDs, status: { _ in })
            Issue.record("Expected a replayed network interruption.")
        } catch let error as ZurichISPClientError {
            #expect(error == .network)
        }
        #expect(try provider.investmentRepo.snapshot(workspaceID: workspaceID) == accepted)

        let blocking = BlockingReplay(records: captured.records)
        let cancelledClient = ZurichISPClient(transport: { request, _ in try await blocking.response(for: request) })
        let task = Task { try await cancelledClient.fetch(credentials: credentials, expectedPolicyIDs: expectedPolicyIDs, status: { _ in }) }
        try await until { await blocking.isWaiting }
        await cancelledClient.cancel()
        await blocking.release()
        let result = await task.result
        guard case .failure(let error) = result else { Issue.record("Expected a cancelled replay."); return }
        #expect((error as? ZurichISPClientError) == .cancelled)
        #expect(try provider.investmentRepo.snapshot(workspaceID: workspaceID) == accepted)
        // A parser-negative replay is deliberately not fabricated: mutating an
        // authentic source response would create forbidden synthetic evidence.
    }

    private func copiedQualifiedLedger(into destination: URL) throws -> SQLiteRepositoryProvider {
        guard let path = ProcessInfo.processInfo.environment["LEDGERFORGE_S97_QUALIFIED_LEDGER"],
              path.contains("/Namespaces/"), path.hasSuffix("/input.ledgerforgebackup/ledger.sqlite") else {
            throw QualificationError.missingEnvironment
        }
        let source = SQLiteDatabase(path: path)
        try source.open(access: .readOnlySnapshot)
        try source.createBackup(at: destination.path)
        source.close()
        return try SQLiteRepositoryProvider(path: destination.path, migrations: allMigrations, access: .existing, migrateExisting: true)
    }

    private func sessionFailureRetention(_ capture: Captured, provider: SQLiteRepositoryProvider,
                                         accepted: InvestmentSnapshot) async throws {
        let previous = DatabaseProvider.shared
        let installed = DatabaseProvider.verifiedSQLite(provider)
        DatabaseProvider.shared = installed
        defer { DatabaseProvider.shared = previous }
        ApplicationAvailability.shared.begin()
        _ = try RepositoryStoreHydrator(databaseProvider: installed, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
        let failing = FIFOReplay(records: capture.records, failAt: 5)
        let session = ZurichISPSyncSession(client: .init(transport: { request, _ in try await failing.response(for: request) }))
        session.installWithoutObservation(accepted, generation: installed.generationToken)
        session.notifyInstalledValue()
        let success = session.lastSuccessfulFetch
        session.fetchHoldings(); session.fetchHoldings()
        try await until { !session.isBusy }
        #expect(try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == accepted)
        #expect(session.lastSuccessfulFetch == success && session.message != nil)

        let blocking = BlockingReplay(records: capture.records)
        let cancelled = ZurichISPSyncSession(client: .init(transport: { request, _ in try await blocking.response(for: request) }))
        cancelled.installWithoutObservation(accepted, generation: installed.generationToken)
        cancelled.notifyInstalledValue()
        cancelled.fetchHoldings()
        try await until { await blocking.isWaiting }
        cancelled.cancel()
        await blocking.release()
        for _ in 0..<10 { await Task.yield() }
        #expect(!cancelled.isBusy && cancelled.lastSuccessfulFetch == success)
        #expect(cancelled.message == "Cancelled. Previous ISP holdings are retained.")
        #expect(try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == accepted)
    }

    private func originalRoot() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["LEDGERFORGE_PRIVATE_ORIGINALS_DIRECTORY"], !path.isEmpty else {
            throw QualificationError.missingEnvironment
        }
        return URL(fileURLWithPath: path)
    }

    private func closingCSVSources() throws -> [URL] {
        let directory = try originalRoot().appendingPathComponent("Investments/ZurichISP")
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { $0.pathExtension.lowercased() == "csv" }
            .filter { (try? String(contentsOf: $0, encoding: .utf8).contains("FundName2")) == true }
            .sorted { $0.path < $1.path }
        guard urls.count == 3 else { throw QualificationError.missingEnvironment }
        return urls
    }

    private func compareDirectPolicies(_ snapshot: ZurichISPAccountSnapshot) async throws {
        let reader = DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry())
        var closing: [String: InvestmentScopeEvidence] = [:]
        for url in try closingCSVSources() {
            let bytes = try Data(contentsOf: url)
            let result = await reader.importDocument(ImportRequest(fileURL: url), snapshot: SourceContentSnapshot(bytes: bytes))
            guard let raw = result.rawDocument else { throw QualificationError.missingEnvironment }
            let evidence = try InvestmentStatementParser().parse(raw).investmentStatementEvidence
            for scope in evidence?.scopes ?? [] { closing[scope.identity] = scope }
        }
        for policy in snapshot.policies {
            guard let scope = closing[policy.policyID] else { throw QualificationError.missingEnvironment }
            for position in scope.positions where position.units.value > 0 {
                let definitions = InvestmentPriceRegistry.definitions.filter {
                    $0.parserProfile == "zurich.isp.closing.csv" && $0.sourceIdentity == position.instrumentIdentity
                }
                guard definitions.count == 1, let definition = definitions.first else { throw QualificationError.missingEnvironment }
                let rows = policy.funds.filter { $0.code == definition.mapping.code && $0.currency == position.currency && $0.units.value == position.units.value }
                #expect(rows.count == 1, "Closing CSV and direct FE-code units disagree.")
            }
        }
    }

    private func comparePersistedFunds(_ snapshot: InvestmentSnapshot, source: ZurichISPAccountSnapshot,
                                       expectedPolicyIDs: Set<String>, originalHoldingIDs: [String: String]) throws {
        let containers = Dictionary(uniqueKeysWithValues: snapshot.containers.map { ($0.id, $0) })
        for policy in source.policies {
            let matchingContainers = snapshot.containers.filter { $0.institution == "Zurich ISP" && $0.identity == policy.policyID }
            guard matchingContainers.count == 1 else { throw QualificationError.missingEnvironment }
            let holdingRows = snapshot.holdings.filter { $0.containerID == matchingContainers[0].id }
            for fund in policy.funds where fund.units.value > 0 {
                let matches = holdingRows.filter { $0.priceMapping?.provider == "fe" && $0.priceMapping?.code == fund.code && $0.units.value == fund.units.value }
                #expect(matches.count == 1 && matches[0].zioObservationID == policy.observationID)
                #expect(matches.first.map { originalHoldingIDs[policy.policyID + "|" + fund.code] == $0.id } ?? false)
            }
        }
        #expect(Set(snapshot.containers.filter { $0.institution == "Zurich ISP" }.map(\.identity)) == expectedPolicyIDs)
        #expect(snapshot.holdings.allSatisfy { containers[$0.containerID] != nil })
    }

    private func nonISP(from snapshot: InvestmentSnapshot) -> InvestmentSnapshot {
        let ids = Set(snapshot.containers.filter { $0.institution != "Zurich ISP" }.map(\.id))
        return .init(containers: snapshot.containers.filter { ids.contains($0.id) }, holdings: snapshot.holdings.filter { ids.contains($0.containerID) })
    }

    private func zioHoldingIDs(in snapshot: InvestmentSnapshot) -> [String: String] {
        let containers = Dictionary(uniqueKeysWithValues: snapshot.containers.map { ($0.id, $0) })
        return Dictionary(uniqueKeysWithValues: snapshot.holdings.compactMap { holding in
            guard let policyID = containers[holding.containerID]?.identity,
                  containers[holding.containerID]?.institution == "Zurich ISP",
                  let code = (holding.priceMapping ?? InvestmentPriceRegistry.confirmedMapping(for: holding))?.code else { return nil }
            return (policyID + "|" + code, holding.id)
        })
    }

    private func historyCounts(_ db: SQLiteDatabase) throws -> [Int] {
        try ["documents", "import_sessions", "normalized_documents"].map { table in
            Int(try db.query(sql: "SELECT COUNT(*) FROM \(table);") { $0.int64(at: 0) ?? 0 }.first ?? 0)
        }
    }

    private func backupRestoreAndReopen(provider: SQLiteRepositoryProvider, databaseURL: URL, expected: InvestmentSnapshot) async throws {
        let previous = DatabaseProvider.shared
        DatabaseProvider.shared = .verifiedSQLite(provider)
        defer { DatabaseProvider.shared = previous }
        let coordinator = BackupRestoreCoordinator(testingAt: databaseURL)
        coordinator.installTestProvider(provider)
        defer { try? coordinator.closeTestProvider() }
        let destination = databaseURL.deletingLastPathComponent().appendingPathComponent("backups")
        try BackupFiles.createDirectory(destination)
        await coordinator.createBackup(to: destination)
        guard let package = coordinator.lastBackupURL else { throw QualificationError.missingEnvironment }
        #expect((try BackupFiles.verifyPackage(package)).schemaVersion == 22)
        await coordinator.verifyRestore(from: package)
        await coordinator.replaceLedger()
        #expect(try DatabaseProvider.shared.investmentRepo.snapshot(workspaceID: "default-workspace") == expected)
        try coordinator.closeTestProvider()
        let reopened = try SQLiteRepositoryProvider(path: databaseURL.path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        #expect(try reopened.investmentRepo.snapshot(workspaceID: "default-workspace") == expected)
        try BackupCompatibility.verifyDatabase(reopened.database)
    }

    private func importEngine(_ provider: DatabaseProvider) -> ImportEngine {
        let hydrator = RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo, investmentRepo: provider.investmentRepo,
            accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(), cardStore: CardStore(),
            salaryStore: SalaryStore(), fundingPlanStore: FundingPlanStore(), investmentStore: InvestmentStore(),
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(), persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken, participatesInLifecycleGate: false)
        return ImportEngine(importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {})
    }

    private func isolatedDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s97-zio-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    private func until(_ predicate: () async -> Bool) async throws {
        for _ in 0..<100 { if await predicate() { return }; try await Task.sleep(for: .milliseconds(20)) }
        throw QualificationError.timeout
    }

}

private actor LiveCapture {
    static let shared = LiveCapture()
    private var cached: Captured?
    private var savedCredentials: ZurichISPCredentials?

    func credentials() throws -> ZurichISPCredentials {
        guard let savedCredentials else { throw ZurichISPQualificationTests.QualificationError.missingCredentials }
        return savedCredentials
    }

    func fetch(expectedPolicyIDs: Set<String>) async throws -> Captured {
        if let cached { return cached }
        let store = ZurichISPCredentialStore()
        guard let credentials = try store.load() ?? store.loadPilot() else { throw ZurichISPQualificationTests.QualificationError.missingCredentials }
        let labels = ResponseLabels(), transport = NativeCaptureTransport()
        let client = ZurichISPClient(observer: { endpoint, _ in labels.append(endpoint) }, transport: { request, session in
            try await transport.fetch(request, session: session)
        })
        let source = try await client.fetch(credentials: credentials, expectedPolicyIDs: expectedPolicyIDs, status: { _ in })
        let captured = Captured(source: source, records: transport.records(), labels: labels.values())
        savedCredentials = credentials; cached = captured
        return captured
    }
}

private nonisolated struct Captured: Sendable {
    let source: ZurichISPSourceAccount
    let records: [ResponseRecord]
    let labels: [String]
}

private nonisolated struct ResponseRecord: Sendable {
    let url: URL
    let statusCode: Int
    let body: Data
}

private nonisolated final class ResponseLabels: @unchecked Sendable {
    private let lock = NSLock(); private var labels: [String] = []
    func append(_ label: String) { lock.lock(); labels.append(label); lock.unlock() }
    func values() -> [String] { lock.lock(); defer { lock.unlock() }; return labels }
}

private nonisolated final class NativeCaptureTransport: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ResponseRecord] = []
    func fetch(_ request: URLRequest, session: URLSession) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, let url = http.url else { throw URLError(.badServerResponse) }
        record(.init(url: url, statusCode: http.statusCode, body: data))
        return (data, http)
    }
    private func record(_ value: ResponseRecord) { lock.lock(); defer { lock.unlock() }; values.append(value) }
    func records() -> [ResponseRecord] { lock.lock(); defer { lock.unlock() }; return values }
}

private actor FIFOReplay {
    private let records: [ResponseRecord]
    private let failAt: Int?
    private var index = 0
    init(records: [ResponseRecord], failAt: Int? = nil) { self.records = records; self.failAt = failAt }
    func response(for request: URLRequest) throws -> (Data, HTTPURLResponse) {
        guard index < records.count else { throw URLError(.badServerResponse) }
        defer { index += 1 }
        if index == failAt { throw URLError(.networkConnectionLost) }
        let record = records[index]
        guard let response = HTTPURLResponse(url: record.url, statusCode: record.statusCode, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badServerResponse)
        }
        return (record.body, response)
    }
}

private actor BlockingReplay {
    private let records: [ResponseRecord]
    private var continuation: CheckedContinuation<Void, Never>?
    private var index = 0
    init(records: [ResponseRecord]) { self.records = records }
    var isWaiting: Bool { continuation != nil }
    func response(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if index == 0 { await withCheckedContinuation { continuation = $0 } }
        guard index < records.count else { throw URLError(.badServerResponse) }
        defer { index += 1 }
        let record = records[index]
        guard let response = HTTPURLResponse(url: record.url, statusCode: record.statusCode, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badServerResponse)
        }
        return (record.body, response)
    }
    func release() { continuation?.resume(); continuation = nil }
}

private nonisolated struct OracleMetadata: Decodable { let policyCount: Int; let positionCount: Int; let regularCount: Int; let digest: String; let usdSummaryDigest: String }

private nonisolated func independentOracle(records: [ResponseRecord]) throws -> OracleMetadata {
    let script = #"""
import base64,hashlib,json,re,sys,urllib.parse,html
from decimal import Decimal, ROUND_HALF_UP
from html.parser import HTMLParser
records=json.load(sys.stdin)
def balanced(s,start):
 d=json.JSONDecoder(parse_float=str,parse_int=str); return d.raw_decode(s[start:])
def fund(text):
 out=[]
 for m in re.finditer(r'\bvar\s+dt\s*=\s*\[',text,re.I):
  start=m.end()-1; row,end=balanced(text,start); tail=text[start+end:]
  if re.match(r'\s*;?\s*makeFundValuePieChart\s*\(\s*dt\s*,\s*[\"\']Fund values[\"\']\s*,\s*[\"\']FundValueChart[\"\']\s*\)',tail,re.I): out.append(row)
 if len(out)!=1: raise ValueError('fund_shape')
 return out[0]
def regular(text):
 out=[]
 for m in re.finditer(r'makeDonutChartWithLegend',text,re.I):
  n=text.find('[',m.end())
  if n<0: continue
  row,end=balanced(text,n); close=text.find(')',n+end)
  if close>=0 and re.search(r',\s*[\"\']RegularStrategyChart[\"\']\s*$',text[n+end:close],re.I): out.append(row)
 if len(out)!=1: raise ValueError('regular_shape')
 return out[0]
def table(text):
 out={}
 for row in re.findall(r'<tr\b[^>]*>(.*?)</tr\s*>',text,re.I|re.S):
  cells=[html.unescape(re.sub(r'<[^>]+>',' ',cell)).strip() for cell in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]\s*>',row,re.I|re.S)]
  if len(cells)==2:
   key=re.sub(r'\s+',' ',cells[0]); value=re.sub(r'\s+',' ',cells[1])
   if key not in ('Policy type','Status','Start date','Maturity date','Plan currency','Total contributions','Contributions','Value','Growth','Vested value'): continue
   if key in out: raise ValueError('duplicate_table_key')
   out[key]=value
 return out
def amount(value):
 v=value.strip()
 for prefix in ('USD','US$','$'):
  if v.startswith(prefix): v=v[len(prefix):].strip(); break
 return Decimal(v.replace(',',''))
def cents(value): return value.quantize(Decimal('.01'),rounding=ROUND_HALF_UP)
parts=[]; policies={}; regulars={}; summaries={}; contributions={}
for r in records:
 text=base64.b64decode(r['body']).decode('utf-8')
 u=urllib.parse.urlparse(r['url']); q=urllib.parse.parse_qs(u.query); policy=q.get('policynumber',[None])[0]
 if u.path.endswith('PolicyValuePartial'):
  if not policy: raise ValueError('missing_policy')
  date=re.search(r'<label[^>]*for=[\"\']?ValuationDate[^>]*>.*?</label>\s*<[^>]+>(.*?)</',text,re.I|re.S)
  if not date: raise ValueError('date_shape')
  values=fund(text); policies[policy]=(re.sub('<[^>]+>',' ',date.group(1)).strip(),values)
 if u.path.endswith('InvestementStrategyPartial'):
  if not policy: raise ValueError('missing_policy')
  regulars[policy]=regular(text)
 if u.path.endswith('PolicySummaryPartial'):
  if not policy: raise ValueError('missing_policy')
  summaries[policy]=table(text)
 if u.path.endswith('ContributionsPartial'):
  if not policy: raise ValueError('missing_policy')
  contributions[policy]=table(text)
if not (set(policies)==set(regulars)==set(summaries)==set(contributions)) or len(policies)!=3: raise ValueError('policy_shape')
for policy in sorted(policies):
 date,values=policies[policy]; regs=regulars[policy]; summary=summaries[policy]; contrib=contributions[policy]
 required_summary=('Policy type','Status','Start date','Maturity date','Plan currency','Total contributions','Value','Growth')
 required_contrib=('Contributions','Value','Growth')
 if any(key not in summary for key in required_summary) or any(key not in contrib for key in required_contrib): raise ValueError('table_shape')
 if summary['Plan currency'].strip() not in ('USD','US Dollar','US Dollars'): raise ValueError('currency')
 if amount(summary['Total contributions'])!=amount(contrib['Contributions']) or amount(summary['Value'])!=amount(contrib['Value']) or amount(summary['Growth'])!=amount(contrib['Growth']): raise ValueError('table_controls')
 if ('Vested value' in summary) != ('Vested value' in contrib): raise ValueError('vested_shape')
 if 'Vested value' in summary and amount(summary['Vested value'])!=amount(contrib['Vested value']): raise ValueError('vested_control')
 total=amount(contrib['Value'])
 if total<=0 or cents(sum(Decimal(str(row['Value'])) for row in values))!=cents(total): raise ValueError('fund_total')
 if cents(sum(Decimal(str(row['Percentage'])) for row in values))!=Decimal('100.00'): raise ValueError('allocation_total')
 for row in values:
  if Decimal(str(row['FXRate']))!=Decimal('1'): raise ValueError('fx_rate')
  if cents(Decimal(str(row['Percentage'])))!=cents(Decimal(str(row['Value']))/total*Decimal('100')): raise ValueError('allocation_control')
 if sum(Decimal(str(row['FundPercentage'])) for row in regs)!=Decimal('100'): raise ValueError('strategy_total')
 parts.append(policy+'|'+date)
 for key in sorted(set(required_summary+('Vested value',)) & set(summary)): parts.append('S|'+key+'|'+summary[key])
 for key in sorted(set(required_contrib+('Vested value',)) & set(contrib)): parts.append('C|'+key+'|'+contrib[key])
 for row in sorted(values,key=lambda x:x['FundCode']): parts.append('|'.join([row.get(k,'') if row.get(k) is not None else '' for k in ('FundCode','FundName','FundCurrency','FXRate','Percentage','Price','Units','Value','VestedValue')]))
 for row in sorted(regs,key=lambda x:(x['FundCode'],x['StrategySequence'])):
  if row['StrategyType']!='R': raise ValueError('single_strategy')
  parts.append('|'.join([row.get(k,'') if row.get(k) is not None else '' for k in ('StrategyType','EffectiveDate','StrategySequence','FundCode','FundDescription','FundPercentage')]))
totals=[]
for key in ('Contributions','Growth','Vested value'):
 total=sum(amount(row[key]) for row in contributions.values() if key in row).quantize(Decimal('1'),rounding=ROUND_HALF_UP)
 totals.append(format(total if total else Decimal(0),'f'))
print(json.dumps({'policyCount':len(policies),'positionCount':sum(len(v[1]) for v in policies.values()),'regularCount':sum(len(v) for v in regulars.values()),'digest':hashlib.sha256('\n'.join(parts).encode()).hexdigest(),'usdSummaryDigest':hashlib.sha256('|'.join(totals).encode()).hexdigest()}))
"""#
    let body = try JSONSerialization.data(withJSONObject: records.map { ["url": $0.url.absoluteString, "body": $0.body.base64EncodedString()] })
    let process = Process(), input = Pipe(), output = Pipe(), errors = Pipe()
    _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
    guard let python = ProcessInfo.processInfo.environment["LEDGERFORGE_S97_PYTHON"] else { throw ZurichISPQualificationTests.QualificationError.missingEnvironment }
    process.executableURL = URL(fileURLWithPath: python); process.arguments = ["-c", script]
    process.standardInput = input; process.standardOutput = output; process.standardError = errors
    try process.run(); try input.fileHandleForWriting.write(contentsOf: body); try input.fileHandleForWriting.close()
    let result = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw ZurichISPQualificationTests.QualificationError.independentOracle }
    return try JSONDecoder().decode(OracleMetadata.self, from: result)
}

private nonisolated func digest(of snapshot: ZurichISPAccountSnapshot) -> String {
    var parts: [String] = []
    for policy in snapshot.policies.sorted(by: { $0.policyID < $1.policyID }) {
        parts.append(policy.policyID + "|" + policy.valuationDateText)
        for key in policy.summaryFields.keys.sorted() { parts.append("S|" + key + "|" + (policy.summaryFields[key] ?? "")) }
        var contributionFields = [
            "Contributions": policy.contributions.sourceText,
            "Value": policy.value.sourceText,
            "Growth": policy.growth.sourceText
        ]
        if let vested = policy.vestedValue { contributionFields["Vested value"] = vested.sourceText }
        for key in contributionFields.keys.sorted() { parts.append("C|" + key + "|" + (contributionFields[key] ?? "")) }
        for row in policy.funds.sorted(by: { $0.code < $1.code }) {
            parts.append([row.code,row.name,row.currency,row.fxRate.sourceText,row.allocation.sourceText,row.price.sourceText,row.units.sourceText,row.value.sourceText,row.vestedValue?.sourceText ?? ""].joined(separator: "|"))
        }
        for row in policy.regularStrategy.sorted(by: {
            $0.code == $1.code ? $0.sequence.sourceText < $1.sequence.sourceText : $0.code < $1.code
        }) {
            parts.append([row.strategyType,row.effectiveDateText,row.sequence.sourceText,row.code,row.name,row.percentage.sourceText].joined(separator: "|"))
        }
    }
    return SHA256.hash(data: Data(parts.joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
}
