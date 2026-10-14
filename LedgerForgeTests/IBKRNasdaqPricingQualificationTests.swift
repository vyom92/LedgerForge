import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Explicit qualification of the selected authentic backup. Raw public responses,
/// source facts and independent expectations remain in RAM. The only financial
/// disk output is a normal isolated application database under the approved root.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LEDGERFORGE_IBKR_NASDAQ_QUALIFY"] == "1" &&
    ProcessInfo.processInfo.environment["LEDGERFORGE_CATEGORY_AUTHENTIC_BACKUP"] != nil))
@MainActor
struct IBKRNasdaqPricingQualificationTests {
    private enum Failure: Error { case assertion(String) }
    private struct Row {
        let holding: InvestmentHolding
        let position: IBKRFlexPosition
        let definition: InvestmentPriceDefinition
        let units: Decimal
        let cost: Decimal
    }
    private struct Oracle {
        let price: Decimal
        let priceText: String
        let day: String
        let timestamp: String
        let instant: Date?
        let url: String
    }
    private struct Table {
        let name: String
        let columns: [String]
    }

    @Test(.globalRuntimeStateIsolation)
    func currentFlexPositionsUseNasdaqAcrossForegroundBackgroundAndReopen() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let sourcePath = environment["LEDGERFORGE_CATEGORY_AUTHENTIC_BACKUP"], !sourcePath.isEmpty,
              let rootPath = environment["LEDGERFORGE_CATEGORY_QUALIFICATION_ROOT"], !rootPath.isEmpty else {
            throw Failure.assertion("Authentic backup and approved qualification root are required")
        }
        var stage = "sealed backup"
        do {
            let source = URL(fileURLWithPath: sourcePath).standardizedFileURL.resolvingSymlinksInPath()
            let root = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
            try check(root.path != source.path && !root.path.hasPrefix(source.path + "/"), "Output overlaps the source backup")
            try BackupFiles.rejectGitDestination(root)
            let manifest = try BackupFiles.verifyPackage(source)
            let manifestSHA = try BackupFiles.hash(source.appendingPathComponent("manifest.json")).sha256
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let directory = root.appendingPathComponent("ibkr-nasdaq-qualification-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            let databaseURL = directory.appendingPathComponent("ledger.sqlite")
            let original = SQLiteDatabase(path: source.appendingPathComponent("ledger.sqlite").path)
            try original.open(access: .readOnlySnapshot)
            defer { original.close() }
            let oldTables = try inventory(original).filter { $0.name != "schema_migrations" }
            let oldGraph = try digest(original, tables: oldTables, excludingMigrationSequence: true)
            try original.createBackup(at: databaseURL.path)
            original.close()

            stage = "isolated migration and source preservation"
            let sqlite = try SQLiteRepositoryProvider(path: databaseURL.path, migrations: allMigrations,
                access: .existing, migrateExisting: true)
            defer { sqlite.database.close() }
            try BackupCompatibility.verifyDatabase(sqlite.database)
            try check(try digest(sqlite.database, tables: oldTables, excludingMigrationSequence: true) == oldGraph,
                      "Upgrade changed preexisting source or owner records")
            let workspaceIDs = try sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) ?? "" }
            try check(workspaceIDs.count == 1 && !workspaceIDs[0].isEmpty, "Selected backup must identify one workspace")
            let workspaceID = workspaceIDs[0]
            let provider = DatabaseProvider.verifiedSQLite(sqlite)
            let snapshot = try provider.investmentRepo.snapshot(workspaceID: workspaceID)
            let rows = try qualifiedRows(snapshot)
            let identities = Set(rows.map { $0.definition.mapping.identity })
            let preservedTables = try inventory(sqlite.database).filter {
                !["background_investment_quote_cache", "background_public_progress", "background_update_receipts"].contains($0.name)
            }
            let graph = try digest(sqlite.database, tables: preservedTables)
            let originalCache = try sqlite.backgroundPublicCacheRepo.snapshot(now: Date())
            let originalProgress = try BackgroundPublicProgressStore(database: sqlite.database).load()
            let unrelatedJobs = try otherJobs(sqlite)

            stage = "foreground mapping and missing public cache"
            let suite = "LedgerForge.ibkr-nasdaq-qualification." + UUID().uuidString
            guard let defaults = UserDefaults(suiteName: suite) else { throw Failure.assertion("Isolated preferences unavailable") }
            defer { defaults.removePersistentDomain(forName: suite) }
            let session = InvestmentPriceSession(defaults: defaults, enabled: false)
            let store = InvestmentStore()
            session.activate(store: store)
            let runtime = try RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspaceID,
                categoryReconciliationGate: nil, participatesInLifecycleGate: false).stageHydration()
            try check(runtime.investments == snapshot, "Canonical hydration changed the authentic positions")
            store.installWithoutObservation(runtime.investments, generation: runtime.providerGeneration)
            store.notifyInstalledValue()
            let configured = session.configuredMappings.filter { $0.provider == "nasdaq" }
            try check(configured.count == 15 && Set(configured.map(\.identity)) == identities,
                      "Foreground did not configure all current source-bound Nasdaq mappings")
            try verifyUnpriced(session.valuations, rows: rows)
            try verifyUnpriced(InvestmentPriceSession.makeValuations(snapshot: snapshot, quotes: [:]), rows: rows)

            stage = "genuine Nasdaq acquisition and independent oracle"
            let transport = IBKRNasdaqQualificationTransport(allowedSymbols: Set(rows.map { $0.position.symbol }))
            let client = InvestmentPriceClient(transport: { try await transport.fetch($0) })
            let liveQuotes = try await fetch(rows.map(\.definition), client: client)
            let responses = await transport.records
            let liveCounts = await transport.counts
            try check(responses.count == 15 && transportCounts(liveCounts, live: 15, replay: 0, failed: 0),
                      "Live acquisition did not cover exactly the selected Nasdaq cohort")
            var oracles: [String: Oracle] = [:]
            for row in rows {
                guard let record = responses[row.position.symbol] else { throw Failure.assertion("A genuine response is missing") }
                let oracle = try independentOracle(record, row: row)
                oracles[row.holding.id] = oracle
                try verifyQuote(liveQuotes[row.definition.mapping.identity], row: row, oracle: oracle)
            }
            session.installShared(liveQuotes, failures: [:], busy: false)
            try verifyValues(session.valuations, rows: rows, oracles: oracles)
            try verifyValues(InvestmentPriceSession.makeValuations(snapshot: snapshot, quotes: liveQuotes), rows: rows, oracles: oracles)
            let portfolio = session.overview.portfolios.first { $0.group == .ibkr }
            try check(portfolio?.scope.holdingCount == 15 && portfolio?.scope.priceCount == 15 && portfolio?.scope.costCount == 15,
                      "Foreground IBKR coverage does not reflect the complete priced cohort")

            stage = "background replay of the exact genuine bytes"
            await transport.replay()
            let executor = BackgroundUpdateExecutor(provider: sqlite,
                activation: try sqlite.database.validatedActivationStamp(), workspaceID: workspaceID,
                prices: client, origin: .foreground)
            let configuration = BackgroundScheduleConfiguration(enabled: true, alDarCurrencyRatesEnabled: false,
                investmentPublicPricesEnabled: true, gmailCollectionEnabled: false, zurichISPHoldingsEnabled: false)
            let installed = await executor.refreshPublic(configuration: configuration, manual: true, scopes: .nasdaq)
            try check(installed == .completed(.installedCache), "Scoped background replay did not install all Nasdaq prices")
            let replayCounts = await transport.counts
            try check(transportCounts(replayCounts, live: 15, replay: 15, failed: 0),
                      "Background did not reuse exactly the captured Nasdaq responses")
            let validCache = try sqlite.backgroundPublicCacheRepo.snapshot(now: Date())
            for row in rows { try verifyQuote(validCache.investmentQuotes[row.definition.mapping.identity], row: row, oracle: oracles[row.holding.id]!) }
            let progress = try BackgroundPublicProgressStore(database: sqlite.database).load()
            try check(identities.allSatisfy { progress[$0]?.succeeded == true && progress[$0]?.retryAt == nil },
                      "Background success state is incomplete")
            try check(validCache.alDarLegs == originalCache.alDarLegs &&
                      validCache.investmentQuotes.filter { !identities.contains($0.key) } == originalCache.investmentQuotes.filter { !identities.contains($0.key) },
                      "Nasdaq replay changed an unrelated public cache")

            stage = "transport failure retains the last valid price and provider date"
            await transport.fail()
            let failed = await executor.refreshPublic(configuration: configuration, manual: true, scopes: .nasdaq)
            try check(failed == .completed(.retryPending), "Generic transport failure did not retain its retry state")
            let failureCounts = await transport.counts
            try check(transportCounts(failureCounts, live: 15, replay: 15, failed: 15),
                      "Failure control escaped the selected Nasdaq requests")
            let retained = try sqlite.backgroundPublicCacheRepo.snapshot(now: Date())
            try check(retained == validCache, "Provider failure erased or changed a successful cached observation")
            let failedProgress = try BackgroundPublicProgressStore(database: sqlite.database).load()
            try check(identities.allSatisfy { failedProgress[$0]?.succeeded == false && failedProgress[$0]?.failure != nil && failedProgress[$0]?.retryAt != nil },
                      "Failed prices lack explicit failure and retry state")
            try check(failedProgress.filter { !identities.contains($0.key) } == originalProgress.filter { !identities.contains($0.key) },
                      "Nasdaq refresh changed unrelated progress")
            let failures = Dictionary(uniqueKeysWithValues: identities.map { ($0, InvestmentPriceError.unavailable) })
            session.installShared(retained.investmentQuotes, failures: failures, busy: false)
            try verifyValues(session.valuations, rows: rows, oracles: oracles)
            try check(Set(session.failures.keys) == identities, "Foreground lost the explicit failure state")
            try verifyConsumers(provider, workspaceID: workspaceID, rows: rows, oracles: oracles, cache: retained, failures: identities)
            try check(try provider.investmentRepo.snapshot(workspaceID: workspaceID) == snapshot &&
                      digest(sqlite.database, tables: preservedTables) == graph && otherJobs(sqlite) == unrelatedJobs,
                      "Price refresh changed authentic positions, provenance, owner records or another job")

            stage = "normal database reopen and canonical readback"
            try sqlite.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: databaseURL.path, migrations: allMigrations, access: .existing)
            defer { reopened.database.close() }
            try BackupCompatibility.verifyDatabase(reopened.database)
            let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened)
            try check(try reopenedProvider.investmentRepo.snapshot(workspaceID: workspaceID) == snapshot &&
                      reopened.backgroundPublicCacheRepo.snapshot(now: Date()) == retained &&
                      BackgroundPublicProgressStore(database: reopened.database).load() == failedProgress &&
                      digest(reopened.database, tables: preservedTables) == graph && otherJobs(reopened) == unrelatedJobs,
                      "Normal reopen changed preserved records, provider dates, cache or failure state")
            try verifyConsumers(reopenedProvider, workspaceID: workspaceID, rows: rows, oracles: oracles, cache: retained, failures: identities)
            try check(try BackupFiles.verifyPackage(source) == manifest &&
                      BackupFiles.hash(source.appendingPathComponent("manifest.json")).sha256 == manifestSHA,
                      "Qualification changed its sealed source backup")
            print("IBKR Nasdaq qualification passed: 15 authentic holdings; 15 genuine responses; 15 exact replays; 15 retained failures; canonical reopen preserved")
        } catch let failure as Failure { throw failure }
        catch { throw Failure.assertion("Qualification could not complete stage: " + stage) }
    }

    private func qualifiedRows(_ snapshot: InvestmentSnapshot) throws -> [Row] {
        let containers = snapshot.containers.filter { $0.ibkrSource != nil }
        try check(containers.count == 1, "Selected backup lacks one current authentic Flex account")
        guard let container = containers.first, let source = container.ibkrSource else { throw Failure.assertion("Flex source missing") }
        try check(source.sourceFingerprintAlgorithm == IBKRFlexAccountSnapshot.fingerprintAlgorithm && source.sourceSHA256.count == 64 &&
                  source.sourceByteCount > 0 && source.accountID == container.identity && source.positions.count == 15,
                  "Current Flex source provenance or selected coverage is incomplete")
        let holdings = snapshot.holdings.filter { $0.containerID == container.id }
        try check(holdings.count == 15, "Current Flex holding count is incomplete")
        let rows = try holdings.map { holding -> Row in
            guard holding.ibkrObservationID == source.observationID,
                  let position = source.positions.first(where: { $0.instrumentIdentity == holding.instrumentIdentity }) else {
                throw Failure.assertion("Holding is not bound to the current Flex observation")
            }
            let definitions = InvestmentPriceRegistry.definitions.filter {
                $0.mapping.provider == "nasdaq" && $0.sourceIdentity == position.instrumentIdentity && $0.isin == position.isin &&
                $0.mapping.code == position.symbol && $0.mapping.listing == position.listing && $0.mapping.currency == position.currency
            }
            try check(definitions.count == 1 && position.currency == "USD", "Current Flex identity does not independently bind one confirmed Nasdaq listing")
            let definition = definitions[0], attributes = position.sourceAttributes
            try check(holding.priceMapping == definition.mapping && holding.parserProfile == "ibkr.flex.open-positions" &&
                      attributes["conid"] == position.conid && attributes["isin"] == position.isin && attributes["symbol"] == position.symbol &&
                      attributes["listingExchange"] == position.listing && attributes["currency"] == position.currency &&
                      attributes["accountId"] == source.accountID && attributes["reportDate"] == source.reportDateText,
                      "Stored mapping or current raw source identity disagrees with the exact source binding")
            guard let unitsText = attributes["position"], let costText = attributes["costBasisMoney"] else { throw Failure.assertion("Authentic units or cost absent") }
            let units = try decimal(unitsText), cost = try decimal(costText)
            try check(holding.units.sourceText == unitsText && holding.units.value == units && holding.totalCost?.sourceText == costText &&
                      holding.totalCost?.value == cost && holding.costCurrency == "USD" && units > 0 && cost >= 0,
                      "Source units or supported cost changed precision or meaning")
            return Row(holding: holding, position: position, definition: definition, units: units, cost: cost)
        }
        try check(Set(rows.map { $0.definition.mapping.identity }).count == 15, "Selected source mappings are not unique")
        return rows
    }

    private func fetch(_ definitions: [InvestmentPriceDefinition], client: InvestmentPriceClient) async throws -> [String: InvestmentQuote] {
        let results = await withTaskGroup(of: [String: Result<InvestmentQuote, InvestmentPriceError>].self,
            returning: [String: Result<InvestmentQuote, InvestmentPriceError>].self) { group in
            var iterator = definitions.makeIterator(), combined: [String: Result<InvestmentQuote, InvestmentPriceError>] = [:]
            for _ in 0..<min(4, definitions.count) { if let definition = iterator.next() { group.addTask { await client.fetch([definition]) } } }
            for await result in group {
                combined.merge(result) { _, new in new }
                if let definition = iterator.next() { group.addTask { await client.fetch([definition]) } }
            }
            return combined
        }
        try check(results.count == 15, "Genuine Nasdaq result coverage is incomplete")
        var quotes: [String: InvestmentQuote] = [:]
        for (identity, result) in results {
            guard case .success(let quote) = result else { throw Failure.assertion("A live Nasdaq price could not be qualified") }
            quotes[identity] = quote
        }
        return quotes
    }

    /// Independent Foundation JSON field reader and Gregorian component parser;
    /// no production JSON, date, valuation or arithmetic helper supplies expected values.
    private func independentOracle(_ record: IBKRNasdaqQualificationTransport.Record, row: Row) throws -> Oracle {
        guard record.response.statusCode == 200,
              let object = try JSONSerialization.jsonObject(with: record.data) as? [String: Any],
              let data = object["data"] as? [String: Any],
              let primary = data["primaryData"] as? [String: Any],
              let price = primary["lastSalePrice"] as? String, price.hasPrefix("$"),
              let timestamp = primary["lastTradeTimestamp"] as? String else { throw Failure.assertion("Raw Nasdaq fields unavailable") }
        try check(data["symbol"] as? String == row.position.symbol && (data["assetClass"] as? String)?.lowercased() == "etf" &&
                  data["exchange"] as? String == (row.position.listing == "ARCA" ? "PSE" : "NASDAQ-GM") &&
                  (data["currency"] == nil || data["currency"] as? String == "USD"), "Raw Nasdaq listing or identity disagrees with current Flex")
        let pattern = #"^([A-Za-z]{3}) ([0-9]{1,2}), ([0-9]{4})(?:,? ([0-9]{1,2}):([0-9]{2})(?::([0-9]{2}))? ([AP]M) ET)?$"#
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: timestamp, range: NSRange(timestamp.startIndex..., in: timestamp)) else {
            throw Failure.assertion("Raw provider timestamp has no independently qualified meaning")
        }
        func field(_ index: Int) -> String? { Range(match.range(at: index), in: timestamp).map { String(timestamp[$0]) } }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard let month = months.firstIndex(of: field(1) ?? "").map({ $0 + 1 }),
              let day = field(2).flatMap(Int.init), let year = field(3).flatMap(Int.init),
              let zone = TimeZone(identifier: "America/New_York") else { throw Failure.assertion("Raw provider calendar date is invalid") }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        var components = DateComponents(year: year, month: month, day: day, hour: 0, minute: 0, second: 0)
        let timed = field(4) != nil
        if timed {
            guard let hour = field(4).flatMap(Int.init), (1...12).contains(hour),
                  let minute = field(5).flatMap(Int.init), (0...59).contains(minute),
                  let second = Int(field(6) ?? "0"), (0...59).contains(second), let meridiem = field(7) else {
                throw Failure.assertion("Raw provider clock time is invalid")
            }
            components.hour = hour % 12 + (meridiem == "PM" ? 12 : 0); components.minute = minute; components.second = second
        }
        guard let date = calendar.date(from: components) else { throw Failure.assertion("Raw provider date cannot be represented") }
        let actual = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        try check(actual.year == components.year && actual.month == components.month && actual.day == components.day &&
                  actual.hour == components.hour && actual.minute == components.minute && actual.second == components.second,
                  "Raw provider date silently normalized")
        let token = String(price.dropFirst()), amount = try decimal(token)
        try check(amount > 0, "Raw provider price is not positive")
        return Oracle(price: amount, priceText: token, day: String(format: "%04d-%02d-%02d", year, month, day),
                      timestamp: timestamp, instant: timed ? date : nil, url: record.url)
    }

    private func verifyQuote(_ quote: InvestmentQuote?, row: Row, oracle: Oracle) throws {
        guard let quote else { throw Failure.assertion("Qualified Nasdaq quote missing") }
        try check(quote.mapping == row.definition.mapping && quote.price.value == oracle.price && quote.price.sourceText == oracle.priceText &&
                  quote.valuationDay == oracle.day && quote.valuationText == oracle.timestamp && quote.valuationInstant == oracle.instant &&
                  quote.dateBasis == (oracle.instant == nil ? .providerCalendarDate : .providerInstant) &&
                  quote.calendarTimeZone == "America/New_York" && quote.sourceURL == oracle.url,
                  "Production quote changed the independent Nasdaq identity, amount or provider date")
    }
    private func verifyUnpriced(_ values: [String: InvestmentValuation], rows: [Row]) throws {
        for row in rows {
            guard let value = values[row.holding.id] else { throw Failure.assertion("Unpriced holding disappeared") }
            try check(value.quote == nil && value.currentValue == nil && value.gain == nil && value.supportedCost == row.cost,
                      "Missing public cache incorrectly used a Flex mark, statement value or P/L as current market value")
        }
    }
    private func verifyValues(_ values: [String: InvestmentValuation], rows: [Row], oracles: [String: Oracle]) throws {
        for row in rows {
            guard let value = values[row.holding.id], let oracle = oracles[row.holding.id] else { throw Failure.assertion("Priced holding disappeared") }
            try verifyQuote(value.quote, row: row, oracle: oracle)
            let expected = try product(row.units, oracle.price), gain = try difference(expected, row.cost)
            try check(value.currentValue == expected && value.supportedCost == row.cost && value.costBasis == .reportedTotal && value.gain == gain,
                      "Valuation is not exact source units times Nasdaq price with source-supported cost")
        }
    }

    /// Canonical Net Worth and the actual Mac-authored Companion read projection
    /// consume the same snapshot and cache; no cloud publication or packet file.
    private func verifyConsumers(_ provider: DatabaseProvider, workspaceID: String, rows: [Row], oracles: [String: Oracle],
                                 cache: BackgroundPublicCacheSnapshot, failures: Set<String>) throws {
        let capture = try CompanionMacCapture.take(provider: provider, workspaceID: workspaceID, selectedGmailAccount: nil, now: Date())
        let valuations = InvestmentPriceSession.makeValuations(snapshot: capture.runtime.investments, quotes: cache.investmentQuotes)
        try verifyValues(valuations, rows: rows, oracles: oracles)
        let packet = try capture.projection(generation: 1, currencies: [.usd],
            readBasis: .init(alDarLegs: cache.alDarLegs, investmentQuotes: cache.investmentQuotes, rateFailures: [], priceFailures: failures))
        for row in rows {
            guard let holding = packet.investments.holdings.first(where: { $0.id == row.holding.id }),
                  let oracle = oracles[row.holding.id] else { throw Failure.assertion("Shared read projection omitted a selected holding") }
            let value = try product(row.units, oracle.price)
            try check(try decimal(holding.unitsExact) == row.units && holding.currency == "USD" &&
                      holding.details.first(where: { $0.id == "provider" })?.value == "Nasdaq" &&
                      holding.details.first(where: { $0.id == "priceDate" })?.value == oracle.day,
                      "Shared read projection changed source units or provider/date provenance")
            for (key, expected) in [("value", value), ("cost", row.cost), ("gain", try difference(value, row.cost)), ("price", oracle.price)] {
                guard let amount = holding.metrics.first(where: { $0.id == key })?.exact else { throw Failure.assertion("Shared exact value is absent") }
                try check(try decimal(amount.numerator) == expected && amount.denominator == "1" && amount.currency == "USD",
                          "Shared read projection changed an exact market value or source cost")
            }
            guard let contribution = packet.dashboard.members.flatMap(\.metrics).first(where: { $0.id == "holding:" + row.holding.id })?.exact else {
                throw Failure.assertion("Canonical Net Worth omitted the selected holding component")
            }
            try check(try decimal(contribution.numerator) == value && contribution.denominator == "1" && contribution.currency == "USD",
                      "Canonical Net Worth used a different current value")
        }
    }

    private func decimal(_ text: String) throws -> Decimal {
        let token = text.replacingOccurrences(of: ",", with: "")
        guard token.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else {
            throw Failure.assertion("Independent decimal input is invalid")
        }
        return value
    }
    private func product(_ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
        var left = lhs, right = rhs, result = Decimal()
        try check(NSDecimalMultiply(&result, &left, &right, .plain) == .noError, "Independent multiplication lost precision")
        return result
    }
    private func difference(_ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
        var left = lhs, right = rhs, result = Decimal()
        try check(NSDecimalSubtract(&result, &left, &right, .plain) == .noError, "Independent subtraction lost precision")
        return result
    }
    private func transportCounts(_ counts: IBKRNasdaqQualificationTransport.Counts, live: Int, replay: Int, failed: Int) -> Bool {
        counts.live == live && counts.replay == replay && counts.failed == failed && counts.maximumConcurrent <= 4
    }
    private func otherJobs(_ sqlite: SQLiteRepositoryProvider) throws -> [BackgroundJobRecord?] {
        try [BackgroundJobKind.gmailCollection, .zurichISP, .ibkrFlex].map { try sqlite.backgroundJobRepo.jobRecord($0) }
    }
    private func check(_ condition: @autoclosure () throws -> Bool, _ reason: String) throws {
        guard try condition() else { throw Failure.assertion(reason) }
    }
    private func quoted(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    private func inventory(_ db: SQLiteDatabase) throws -> [Table] {
        let names = try db.query(sql: "SELECT name FROM sqlite_master WHERE type='table';") { $0.string(at: 0) ?? "" }.sorted()
        return try names.map { name in
            let columns = try db.query(sql: "PRAGMA table_info(" + quoted(name) + ");") { $0.string(at: 1) ?? "" }
            try check(!name.isEmpty && !columns.isEmpty, "Preservation inventory is incomplete")
            return Table(name: name, columns: columns)
        }
    }
    /// Full typed old-column values enter RAM hashes only; SQLite never orders
    /// financial values and cannot create a sort spill containing private rows.
    private func digest(_ db: SQLiteDatabase, tables: [Table], excludingMigrationSequence: Bool = false) throws -> SHA256.Digest {
        let available = Dictionary(uniqueKeysWithValues: try inventory(db).map { ($0.name, Set($0.columns)) })
        try check(available["transactions"] != nil && available["document_fingerprints"] != nil && available["investment_holdings"] != nil,
                  "Preserved financial and provenance graph is incomplete")
        var hash = SHA256()
        func frame(_ data: Data, into target: inout SHA256) {
            var count = UInt64(data.count).bigEndian
            withUnsafeBytes(of: &count) { target.update(data: Data($0)) }; target.update(data: data)
        }
        for table in tables {
            try check(available[table.name]?.isSuperset(of: table.columns) == true, "A preserved table or column was removed")
            frame(try JSONEncoder().encode([table.name] + table.columns), into: &hash)
            let expressions = table.columns.flatMap { column -> [String] in
                let value = quoted(column)
                return ["typeof(" + value + ")", "CAST(CASE WHEN typeof(" + value + ")='real' THEN printf('%!.26g'," + value + ") ELSE " + value + " END AS BLOB)"]
            }.joined(separator: ",")
            let condition = excludingMigrationSequence && table.name == "sqlite_sequence" ? " WHERE name IS NOT 'schema_migrations'" : ""
            let rows = try db.query(sql: "SELECT " + expressions + " FROM " + quoted(table.name) + condition + ";") { row in
                var rowHash = SHA256()
                for index in table.columns.indices {
                    frame(Data((row.string(at: Int32(index * 2)) ?? "missing").utf8), into: &rowHash)
                    frame(row.data(at: Int32(index * 2 + 1)) ?? Data(), into: &rowHash)
                }
                return rowHash.finalize().map { String(format: "%02x", $0) }.joined()
            }.sorted()
            for row in rows { frame(Data(row.utf8), into: &hash) }
        }
        return hash.finalize()
    }
}

/// Replays the original Data AND HTTP response object; never reencodes JSON or
/// invents a response envelope. The failure control changes transport mechanics.
private actor IBKRNasdaqQualificationTransport {
    struct Record: Sendable { let url: String; let data: Data; let response: HTTPURLResponse }
    struct Counts: Sendable { let live: Int; let replay: Int; let failed: Int; let maximumConcurrent: Int }
    private enum Mode { case live, replay, fail }
    private let allowedSymbols: Set<String>
    private let native = InvestmentPriceClient().transport
    private var mode: Mode = .live
    private(set) var records: [String: Record] = [:]
    private var liveCount = 0, replayCount = 0, failureCount = 0, concurrent = 0, maximum = 0
    var counts: Counts { .init(live: liveCount, replay: replayCount, failed: failureCount, maximumConcurrent: maximum) }
    init(allowedSymbols: Set<String>) { self.allowedSymbols = allowedSymbols }
    func replay() { mode = .replay }
    func fail() { mode = .fail }
    func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url, url.scheme == "https", url.host == "api.nasdaq.com",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.query == "assetclass=etf", request.httpMethod == "GET" else { throw URLError(.unsupportedURL) }
        let parts = url.path.split(separator: "/")
        guard parts.count == 4, parts[0] == "api", parts[1] == "quote", parts[3] == "info",
              allowedSymbols.contains(String(parts[2])) else { throw URLError(.unsupportedURL) }
        let symbol = String(parts[2])
        switch mode {
        case .fail: failureCount += 1; throw URLError(.cannotConnectToHost)
        case .replay:
            guard let record = records[symbol], record.url == url.absoluteString else { throw URLError(.resourceUnavailable) }
            replayCount += 1; return (record.data, record.response)
        case .live:
            guard records[symbol] == nil else { throw URLError(.badServerResponse) }
            liveCount += 1; concurrent += 1; maximum = max(maximum, concurrent)
            defer { concurrent -= 1 }
            let (data, response) = try await native(request)
            records[symbol] = .init(url: url.absoluteString, data: data, response: response)
            return (data, response)
        }
    }
}
