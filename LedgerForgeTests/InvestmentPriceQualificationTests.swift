import Foundation
import Testing
@testable import LedgerForge

/// Explicit live qualification against the accepted, closed isolated ledger backup.
/// Originals, responses and independent numeric expectations remain in RAM. Only normal
/// isolated application databases/backups and the implemented public quote cache are written.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LEDGERFORGE_S97_QUALIFIED_LEDGER"] != nil))
@MainActor
struct InvestmentPriceQualificationTests {
    private enum QualificationError: Error { case missingLedger, timeout, oracle, missingPrices }

    @Test(.globalRuntimeStateIsolation)
    func genuineHoldingsMappingLivePricesCacheAndRecovery() async throws {
        guard let path = ProcessInfo.processInfo.environment["LEDGERFORGE_S97_QUALIFIED_LEDGER"],
              path.contains("/Namespaces/"), path.hasSuffix("/input.ledgerforgebackup/ledger.sqlite") else { throw QualificationError.missingLedger }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s97-qualification-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("ledger.sqlite")
        let source = SQLiteDatabase(path: path)
        try source.open(access: .readOnlySnapshot)
        try source.createBackup(at: databaseURL.path)
        source.close()
        let sqlite = try SQLiteRepositoryProvider(path: databaseURL.path, migrations: allMigrations, access: .existing, migrateExisting: true)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let original = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        #expect(!original.holdings.isEmpty)
        let allMapped = original.holdings.allSatisfy { InvestmentPriceRegistry.confirmedMapping(for: $0) != nil }
        #expect(allMapped, "Every genuine current identity must have one confirmed public mapping")
        DatabaseProvider.shared = provider
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, participatesInLifecycleGate: false)
        ApplicationAvailability.shared.begin()
        let name = "LedgerForge.s97-qualified-public-prices.\(UUID())", defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let transport = QualifiedPublicPriceTransport()
        async let inr = AlDarCurrentReferenceProvider().fetchUnit(currency: .inr)
        async let usd = AlDarCurrentReferenceProvider().fetchUnit(currency: .usd)
        let fx: [AlDarCurrency: AlDarUnitReference] = try await [.inr: inr, .usd: usd]
        AlDarReferenceCachePreferences(defaults: defaults).save(fx)
        let rates = AlDarReferenceSession(defaults: defaults, enabled: false)
        let session = InvestmentPriceSession(defaults: defaults,
            client: .init(transport: { try await transport.fetch($0) }), sleep: { await transport.recordRetry($0) })
        session.activate()
        session.observeRates(rates)
        session.refreshManually()
        guard DatabaseActivityGate.shared.beginExclusive() else { throw QualificationError.missingLedger }
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        // Real recovery may await verification after canonical publication, while still exclusive.
        for _ in 0..<5 { await Task.yield() }
        #expect(session.requestCount == 0)
        DatabaseActivityGate.shared.finishExclusive(providerChanged: false)
        try await until { session.unmappedCount == 0 }
        let mapped = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        let sourcePreserved = withoutMappings(mapped) == withoutMappings(original)
        #expect(sourcePreserved)
        let assignments = Dictionary(uniqueKeysWithValues: mapped.holdings.map { ($0.id, $0.priceMapping!) })
        let stalePlan = InvestmentPriceMappingPlan(providerGeneration: provider.generationToken,
            workspaceID: "default-workspace", baseline: original, assignments: assignments)
        #expect(provider.investmentRepo.savePriceMappings(stalePlan) == .staleSnapshot)
        let wrongGeneration = InvestmentPriceMappingPlan(providerGeneration: ProviderGenerationToken(),
            workspaceID: "default-workspace", baseline: mapped, assignments: assignments)
        #expect(provider.investmentRepo.savePriceMappings(wrongGeneration) == .staleProviderGeneration)

        try await until { session.requestCount > 0 }
        session.refreshManually()
        try await until { session.refreshing.isEmpty }
        let responses = await transport.records
        let requestCounts = Dictionary(grouping: responses, by: { $0.provider }).mapValues(\.count)
        let nasdaqCount = session.configuredMappings.filter { $0.provider == "nasdaq" }.count
        #expect(requestCounts["nasdaq"] == nasdaqCount)
        for provider in ["amfi", "fe", "fidelity", "blackrock"] { #expect(requestCounts[provider] == 1) }
        #expect(requestCounts["franklin"] == 2)
        #expect(await transport.maximumNasdaqConcurrent <= 4)
        print("S97 live coverage: \(session.rows.count) holdings, \(session.configuredMappings.count) mappings, \(session.quotes.count) quotes; requests \(requestCounts)")
        if !session.failures.isEmpty {
            print("S97 source failures: \(session.failures.map { $0.key + ":" + $0.value.rawValue }.sorted())")
            await transport.describeFranklinShape()
            throw QualificationError.missingPrices
        }
        #expect(session.quotes.count == session.configuredMappings.count)
        let oracle = try await independentOracle(snapshot: mapped, records: responses, fx: fx)
        for holding in mapped.holdings {
            guard let valuation = session.valuations[holding.id], let expected = oracle.holdings[holding.id] else { throw QualificationError.oracle }
            let valueMatches = valuation.currentValue.map(InvestmentArithmetic.text) == expected.value
            let gainMatches = valuation.gain.map(InvestmentArithmetic.text) == expected.gain
            let returnMatches = valuation.simpleReturn?.display == expected.simpleReturn
            let tokenMatches = valuation.quote?.price.canonical == expected.price
            let dateMatches = expected.day == nil || valuation.quote?.valuationDay == expected.day
            #expect(valueMatches && gainMatches && returnMatches && tokenMatches && dateMatches, "Independent response/decimal comparison failed")
        }
        #expect(session.overview.fxLegs == fx)
        try verifyOverview(session.overview, against: oracle)
        let usdLegOnly = InvestmentOverview.build(holdings: mapped.holdings, valuations: session.valuations, legs: [.usd: fx[.usd]!])
        let cbq = usdLegOnly.portfolios.first { $0.group == .cbq }!
        #expect(cbq.scope.lines.map(\.currency) == ["USD", "QAR"] && !cbq.scope.fxMissing)
        #expect(cbq.scope.lines.last?.value?.coverage == cbq.scope.holdingCount)
        #expect(usdLegOnly.total.fxMissing)
        let noFX = InvestmentOverview.build(holdings: mapped.holdings, valuations: session.valuations, legs: [:])
        #expect(noFX.total.fxMissing)
        #expect(noFX.total.priceCount == mapped.holdings.count)
        #expect(noFX.portfolios.allSatisfy { $0.capitalShare == nil && $0.profitShare == nil })
        for line in noFX.total.lines {
            let native = mapped.holdings.filter { $0.currency == line.currency }
            #expect(line.value?.coverage == native.count)
            #expect(line.value?.denominator == .one)
        }
        let cached = session.quotes
        #expect(InvestmentQuoteCache(defaults: defaults).load(now: .now) == cached)
        if let holding = mapped.holdings.first(where: { $0.totalCost != nil }) {
            var partial = session.valuations
            partial[holding.id] = InvestmentValuation(holding: holding, quote: nil)
            let overview = InvestmentOverview.build(holdings: mapped.holdings, valuations: partial, legs: fx)
            #expect(overview.total.priceCount == mapped.holdings.count - 1)
            #expect(overview.total.costCount == session.overview.total.costCount)
            #expect(overview.total.gainCount == session.overview.total.gainCount - 1)
            #expect(!overview.total.hasCompleteGain)
        }
        // A transport that returns after cancellation must not publish into another generation.
        await transport.holdReplays()
        session.refreshManually()
        try await until { await transport.waitingCount > 0 }
        session.installWithoutObservation(mapped, generation: ProviderGenerationToken())
        await transport.releaseReplays()
        try await until { await transport.waitingCount == 0 }
        for _ in 0..<5 { await Task.yield() }
        #expect(session.quotes == cached && session.refreshing.isEmpty)
        session.installWithoutObservation(mapped, generation: provider.generationToken)
        let reopened = try SQLiteRepositoryProvider(path: databaseURL.path, migrations: allMigrations, access: .existing)
        let reopenedExact = try reopened.investmentRepo.snapshot(workspaceID: "default-workspace") == mapped
        #expect(reopenedExact)
        reopened.database.close()

        // Generic transport failure, with actual successful observations already cached.
        await transport.failRequests()
        session.refreshManually(); session.refreshManually()
        try await until { session.refreshing.isEmpty }
        #expect(session.quotes == cached)
        #expect(await transport.retryDelays.count == session.configuredProviders.count)
        #expect(await transport.retryDelays.allSatisfy { $0 == 60 })
        let afterFailure = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        let unchangedOnFailure = afterFailure == mapped
        #expect(unchangedOnFailure)

        let coordinator = BackupRestoreCoordinator(testingAt: databaseURL)
        coordinator.installTestProvider(sqlite)
        defer { try? coordinator.closeTestProvider() }
        let destination = directory.appendingPathComponent("backups")
        try BackupFiles.createDirectory(destination)
        await coordinator.createBackup(to: destination)
        guard let package = coordinator.lastBackupURL else { throw QualificationError.missingLedger }
        let manifest = try BackupFiles.verifyPackage(package)
        #expect(manifest.schemaVersion == 22)
        await coordinator.verifyRestore(from: package)
        await coordinator.replaceLedger()
        let restored = try DatabaseProvider.shared.investmentRepo.snapshot(workspaceID: "default-workspace") == mapped
        #expect(restored)
        let restoredProjection = session.rows.count == mapped.holdings.count && session.quotes == cached
        #expect(restoredProjection)
        try coordinator.closeTestProvider()
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)
        let startup = BackupRestoreCoordinator(testingAt: databaseURL)
        try startup.recoverBeforeStartup()
        let fresh = try SQLiteRepositoryProvider(path: databaseURL.path, migrations: allMigrations, access: .existing)
        defer { fresh.database.close() }
        startup.installTestProvider(fresh)
        let freshProvider = DatabaseProvider.verifiedSQLite(fresh)
        DatabaseProvider.shared = freshProvider
        _ = try RepositoryStoreHydrator(databaseProvider: freshProvider, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
        await startup.startupDidHydrate()
        #expect(startup.restoredReceipt?.phase == .relaunchConfirmed)
        let freshExact = try fresh.investmentRepo.snapshot(workspaceID: "default-workspace") == mapped
        #expect(freshExact)
        try startup.closeTestProvider()
        print("S97 verified: source preservation, mapping reopen, independent live-response arithmetic and USD/INR overview, four portfolio comparisons, seven ISP positions/four funds, missing FX, shared quotes, failed-refresh cache retention, populated V22 backup/restore/relaunch")
    }

    private func verifyOverview(_ overview: InvestmentOverview, against oracle: OraclePacket) throws {
        try verifyScope(overview.total, against: oracle.total)
        #expect(overview.portfolios.count == 4 && overview.ispFunds.count == 4)
        #expect(overview.total.costCount == 34 && overview.total.gainCount == 34)
        for portfolio in overview.portfolios {
            guard let expected = oracle.portfolios[portfolio.group.rawValue] else { throw QualificationError.oracle }
            try verifyScope(portfolio.scope, against: expected)
            #expect(portfolio.capitalShare == expected.capitalShare)
            #expect(portfolio.profitShare == expected.profitShare)
            let expectedCount = portfolio.group == .isp || portfolio.group == .cbq ? 4 : 15
            #expect(portfolio.funds.count == expectedCount)
            for fund in portfolio.funds {
                guard let detail = oracle.funds[portfolio.group.rawValue + "|" + fund.code] else { throw QualificationError.oracle }
                try verifyScope(fund.scope, against: detail)
                #expect(fund.unitsText == detail.units && fund.holdingDates == detail.days)
                #expect(fund.capitalShareWithinPortfolio == detail.capitalShare)
                #expect(fund.profitShareWithinPortfolio == detail.profitShare)
            }
        }
        for fund in overview.ispFunds {
            guard let expected = oracle.funds["ISP|" + fund.code] else { throw QualificationError.oracle }
            try verifyScope(fund.scope, against: expected)
            #expect(fund.unitsText == expected.units)
            #expect(fund.holdingDates == expected.days)
            #expect(fund.holdingIDs.count == (fund.code == "B0280" ? 1 : 2))
            #expect(fund.scope.costCount == 0 && fund.scope.gainCount == 0)
            #expect(fund.capitalShareWithinPortfolio == nil && fund.profitShareWithinPortfolio == nil)
            #expect(fund.contributionStrategy != nil)
        }
    }

    private func verifyScope(_ actual: InvestmentOverviewScope, against expected: OracleScope) throws {
        #expect(Set(actual.lines.map(\.currency)) == Set(expected.lines.keys))
        #expect(actual.holdingCount == expected.holdingCount)
        #expect(actual.priceCount == expected.holdingCount)
        #expect(actual.costCount == expected.costCount && actual.gainCount == expected.costCount)
        #expect(actual.returnPercent == expected.simpleReturn)
        for line in actual.lines {
            guard let comparison = expected.lines[line.currency] else { throw QualificationError.oracle }
            let pairs: [(InvestmentConvertedAmount?, String?)] = [(line.cost, comparison.cost), (line.value, comparison.value), (line.gain, comparison.gain)]
            for (amount, token) in pairs {
                let text = try token.map { try MoneyFormatting.display(Money(amount: Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX"))!, currency: line.currency)) }
                let matches = amount?.display == text
                #expect(matches, "Independent exact FX/scope amount differs")
            }
        }
    }

    private func withoutMappings(_ snapshot: InvestmentSnapshot) -> InvestmentSnapshot {
        .init(containers: snapshot.containers, holdings: snapshot.holdings.map { holding in
            var source = holding; source.priceMapping = nil; return source
        })
    }
    private func until(_ predicate: () async -> Bool) async throws {
        for _ in 0..<1_000 {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw QualificationError.timeout
    }

    nonisolated private struct OracleValue: Decodable, Sendable {
        let value: String
        let gain: String?
        let simpleReturn: String?
        let price: String
        let day: String?
    }

    nonisolated private struct OraclePacket: Decodable, Sendable {
        let holdings: [String: OracleValue]
        let total: OracleScope
        let portfolios: [String: OracleScope]
        let funds: [String: OracleScope]
    }
    nonisolated private struct OracleScope: Decodable, Sendable {
        struct Line: Decodable, Sendable { let cost: String?; let value: String?; let gain: String? }
        let lines: [String: Line]
        let holdingCount: Int
        let costCount: Int
        let simpleReturn: String?
        let capitalShare: String?
        let profitShare: String?
        let units: String?
        let days: [String]?
    }

    @concurrent private func independentOracle(snapshot: InvestmentSnapshot, records: [QualifiedPublicPriceTransport.Record],
                                              fx: [AlDarCurrency: AlDarUnitReference]) async throws -> OraclePacket {
        // Python's csv, json/Decimal and HTMLParser are independent of the production readers and arithmetic.
        let script = #"""
import sys,json,base64,csv,re,decimal,datetime
from html.parser import HTMLParser
from fractions import Fraction as F
D=decimal.Decimal; decimal.getcontext().prec=160
p=json.load(sys.stdin); quotes={}
def day(s):
 for fmt in ['%Y-%m-%d','%d/%m/%Y','%d-%b-%Y','%d/%b/%Y','%b %d, %Y']:
  try:return datetime.datetime.strptime(s.replace('/Sept/','/Sep/'),fmt).strftime('%Y-%m-%d')
  except ValueError:pass
 raise ValueError('unrecognized source date')
class BlackRock(HTMLParser):
 def __init__(self):super().__init__();self.rows=[];self.row=None;self.cell=None
 def handle_starttag(self,t,a):
  a=dict(a)
  if t=='tr':self.row={}
  if t=='td' and self.row is not None:self.cell=a.get('class','');self.row[self.cell]=''
 def handle_data(self,s):
  if self.cell is not None:self.row[self.cell]+=s
 def handle_endtag(self,t):
  if t=='td':self.cell=None
  if t=='tr' and self.row is not None:self.rows.append(self.row);self.row=None
for rec in p['records']:
 source=rec['provider']; text=base64.b64decode(rec['data']).decode()
 if source=='amfi':
  for row in csv.reader(text.splitlines(),delimiter=';'):
   if len(row)==8 and row[0].isdigit():quotes['amfi|'+row[0]]=(row[6],day(row[7]))
 elif source=='blackrock':
  parser=BlackRock();parser.feed(text)
  for row in parser.rows:
   cells={k.strip():v.strip() for k,v in row.items()}
   if cells.get('colIsin')=='LU0122376428':quotes['blackrock|229918']=(cells['colNavAmount'],day(cells['colNavAsOfDate']))
 else:
  data=json.loads(text,parse_float=D)
  if source=='nasdaq':
   row=data['data'];raw=row['primaryData'];date=re.search(r'[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}',raw['lastTradeTimestamp']).group()
   quotes['nasdaq|'+row['symbol']]=(raw['lastSalePrice'].removeprefix('$').replace(',',''),day(date))
  elif source=='fe':
   for row in json.loads(data['Units'],parse_float=D)['DataList']:
    quotes['fe|'+str(row['Common'].get('FundCode_Customtable'))]=(str(row['Price']['Bid']['Amount']),None)
  elif source=='fidelity':
   for code in ['FAGAU/G','GTAAU/G']:
    nav=data['data'][code]['priceData']['nav'];quotes['fidelity|'+code]=(nav['value'],day(nav['date']))
  elif source=='franklin' and 'FundHeaderOverview' in rec['url']:
   for row in data['data']['Overview']['shareclass']:
    if row['identifiers']['shclcode']=='Z':quotes['franklin|4916']=(str(row['nav']['navvalue']).removeprefix('$'),day(row['nav']['navdate']))
def canon(value):
 if value==0:return '0'
 return format(value,'f').rstrip('0').rstrip('.') if '.' in format(value,'f') else format(value,'f')
out={}; positions=[]
for h in p['holdings']:
 mapping=h['priceMapping'];token,date=quotes[mapping['provider']+'|'+mapping['code']]
 units=D(h['units'].replace(',',''));value=units*D(token)
 cost=None
 if h.get('costCurrency')==h['currency']:
  if h.get('totalCost') is not None:cost=D(h['totalCost'].replace(',',''))
  elif h.get('averageCost') is not None:cost=units*D(h['averageCost'].replace(',',''))
 gain=value-cost if cost is not None else None
 ratio=None
 if cost is not None and cost>0:
  ratio=(gain/cost*100).quantize(D('.01'),rounding=decimal.ROUND_HALF_UP)
  if ratio==0:ratio=abs(ratio)
 out[h['id']]={'value':canon(value),'gain':None if gain is None else canon(gain),'simpleReturn':None if ratio is None else str(ratio)+'%','price':token,'day':date}
 group={'amfi':'Indian MF','fe':'ISP','nasdaq':'IBKR','fidelity':'CBQ Investments','blackrock':'CBQ Investments','franklin':'CBQ Investments'}[mapping['provider']]
 positions.append(dict(group=group,code=mapping['code'],currency=h['currency'],value=F(value),cost=None if cost is None else F(cost),gain=None if gain is None else F(gain),units=units,day=h['holdingsDate']))
cross=F(D(p['fx']['INR']))/F(D(p['fx']['USD']))
def converted(row,key,currency):
 amount=row[key]
 if amount is None:return None
 if currency=='QAR':return amount/F(D(p['fx'][row['currency']]))
 return amount if row['currency']==currency else amount*(cross if currency=='INR' else 1/cross)
def rounded(x,percent=False):
 if x is None:return None
 if percent:x*=100
 value=(D(x.numerator)/D(x.denominator)).quantize(D('.01') if percent else D('1'),rounding=decimal.ROUND_HALF_UP)
 if value==0:value=abs(value)
 return format(value,'.2f' if percent else '.0f')+('%' if percent else '')
def scope(rows,parent=None,currencies=('USD','INR')):
 amounts={c:{k:sum((converted(r,k,c) for r in rows if r[k] is not None),F(0)) if any(r[k] is not None for r in rows) else None for k in ['cost','value','gain']} for c in currencies}
 native=amounts['USD']; cost=native['cost'];gain=native['gain']
 result={'lines':{c:{k:rounded(v) for k,v in a.items()} for c,a in amounts.items()},'holdingCount':len(rows),'costCount':sum(r['cost'] is not None for r in rows),'simpleReturn':rounded(gain/cost,True) if gain is not None and cost is not None and cost>0 else None,'capitalShare':None,'profitShare':None}
 if parent:
  total=scope_amounts(parent)
  if cost is not None and total['cost'] is not None and total['cost']>0:result['capitalShare']=rounded(cost/total['cost'],True)
  if gain is not None and total['gain'] is not None and total['gain']!=0:result['profitShare']=rounded(gain/total['gain'],True)
 return result
def scope_amounts(rows):
 return {k:sum((converted(r,k,'USD') for r in rows if r[k] is not None),F(0)) if any(r[k] is not None for r in rows) else None for k in ['cost','gain']}
portfolios={g:scope([r for r in positions if r['group']==g],positions,('USD','QAR') if g=='CBQ Investments' else ('USD','INR')) for g in ['ISP','IBKR','Indian MF','CBQ Investments']}
funds={}
for group,code in sorted(set((r['group'],r['code']) for r in positions)):
 rows=[r for r in positions if r['group']==group and r['code']==code];key=group+'|'+code
 funds[key]=scope(rows,[r for r in positions if r['group']==group],('USD','QAR') if group=='CBQ Investments' else ('USD','INR'));funds[key]['units']=canon(sum(r['units'] for r in rows));funds[key]['days']=sorted(set(r['day'] for r in rows))
json.dump(dict(holdings=out,total=scope(positions),portfolios=portfolios,funds=funds),sys.stdout)
"""#
        let data = try JSONSerialization.data(withJSONObject: [
            "holdings": JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot.holdings)),
            "records": JSONSerialization.jsonObject(with: JSONEncoder().encode(records)),
            "fx": Dictionary(uniqueKeysWithValues: fx.map { ($0.key.rawValue, $0.value.returned.rawToken) })])
        let process = Process(), input = Pipe(), output = Pipe(), errors = Pipe()
        // A failed helper launch/import must become a test failure, not SIGPIPE in the host.
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        guard let python = ProcessInfo.processInfo.environment["LEDGERFORGE_S97_PYTHON"] else { throw QualificationError.oracle }
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = ["-c", script]
        process.standardInput = input; process.standardOutput = output; process.standardError = errors
        try process.run()
        do { try input.fileHandleForWriting.write(contentsOf: data) }
        catch {
            print("Independent oracle input failed: \(String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))")
            throw QualificationError.oracle
        }
        try input.fileHandleForWriting.close()
        let result = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            print("Independent oracle failed: \(String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))")
            throw QualificationError.oracle
        }
        return try JSONDecoder().decode(OraclePacket.self, from: result)
    }
}

private actor QualifiedPublicPriceTransport {
    struct Record: Codable, Sendable { let provider: String; let url: String; let data: Data }
    private(set) var records: [Record] = []
    private(set) var maximumNasdaqConcurrent = 0
    private var nasdaqConcurrent = 0
    private var failing = false
    private var holding = false
    private var replaying = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var waitingCount = 0
    private(set) var retryDelays: [TimeInterval] = []
    private let native = InvestmentPriceClient().transport
    func failRequests() { failing = true; holding = false }
    func holdReplays() { holding = true }
    func releaseReplays() { holding = false; replaying = true; let values = waiters; waiters = []; values.forEach { $0.resume() } }
    func recordRetry(_ seconds: TimeInterval) { retryDelays.append(seconds) }
    func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!.absoluteString
        let provider = url.contains("nasdaq") ? "nasdaq" : url.contains("amfi") ? "amfi" : url.contains("feprecision") ? "fe" : url.contains("fidelity") ? "fidelity" : url.contains("blackrock") ? "blackrock" : "franklin"
        if failing { throw URLError(.cannotConnectToHost) }
        if holding || replaying {
            if holding {
                waitingCount += 1
                await withCheckedContinuation { waiters.append($0) }
                waitingCount -= 1
            }
            guard let record = records.first(where: { $0.url == url || (provider == "fidelity" && $0.provider == provider) }),
                  let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil) else { throw URLError(.badServerResponse) }
            return (record.data, response)
        }
        if provider == "nasdaq" { nasdaqConcurrent += 1; maximumNasdaqConcurrent = max(maximumNasdaqConcurrent, nasdaqConcurrent) }
        defer { if provider == "nasdaq" { nasdaqConcurrent -= 1 } }
        let result = try await native(request)
        records.append(.init(provider: provider, url: url, data: result.0))
        return result
    }
    func describeFranklinShape() {
        for record in records where record.provider == "franklin" {
            if let object = try? JSONSerialization.jsonObject(with: record.data) as? [String: Any] {
                print("Franklin response top-level fields: \(object.keys.sorted())")
                if let errors = object["errors"] { print("Franklin GraphQL errors: \(errors)") }
                if let data = object["data"] as? [String: Any], let overview = data["Overview"] as? [String: Any],
                   let rows = overview["shareclass"] as? [[String: Any]], let row = rows.first {
                    print("Franklin selected public fields: \(row)")
                }
            }
        }
    }
}
