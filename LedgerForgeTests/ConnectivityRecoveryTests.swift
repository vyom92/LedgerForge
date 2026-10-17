import Foundation
import XCTest
@testable import LedgerForge

/// Isolated operational records and deterministic transport failures. No live
/// connection, Keychain read, source statement or adopted ledger is involved.
@MainActor
final class ConnectivityRecoveryTests: XCTestCase {
    private actor RateTransport {
        var steps: [URLError.Code?]
        var calls = 0
        var currencies: [AlDarCurrency] = []
        init(_ steps: [URLError.Code?]) { self.steps = steps }
        func fetch(_ currency: AlDarCurrency) throws -> AlDarUnitReference {
            calls += 1
            currencies.append(currency)
            if !steps.isEmpty, let error = steps.removeFirst() { throw URLError(error) }
            return try .init(currency: currency, rawToken: currency == .inr ? "25.50" : "0.27",
                             fetchedAtISO: ISO8601DateFormatter().string(from: Date()))
        }
    }
    private actor ISPTransport {
        var calls = 0
        func fetch(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
            calls += 1
            if calls <= 2 { throw URLError(calls == 1 ? .notConnectedToInternet : .networkConnectionLost) }
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!)
        }
    }
    private func location() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-connectivity-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("isolated.sqlite")
    }
    private func configuration(rates: Bool = true, isp: Bool = false) -> BackgroundScheduleConfiguration {
        .init(enabled: true, alDarCurrencyRatesEnabled: rates, investmentPublicPricesEnabled: false,
              gmailCollectionEnabled: false, zurichISPHoldingsEnabled: isp)
    }
    private func executor(_ provider: SQLiteRepositoryProvider, transport: RateTransport) throws -> BackgroundUpdateExecutor {
        .init(provider: provider, activation: try provider.database.validatedActivationStamp(), workspaceID: "default-workspace",
              fetchRate: { try await transport.fetch($0) })
    }

    private func seedPriceHoldings(_ definitions: [InvestmentPriceDefinition], in provider: SQLiteRepositoryProvider) throws {
        // Small isolated DTOs exercise the real executor/repository boundary;
        // the invented financial values and fingerprint are not source evidence.
        let day = "20260101", account = "U1", generated = "20260102;000000"
        let positions = try definitions.enumerated().map { offset, definition in
            let mapping = definition.mapping, isin = try XCTUnwrap(definition.isin)
            let attributes = ["accountId": account, "reportDate": day, "levelOfDetail": "SUMMARY",
                "assetCategory": "STK", "subCategory": "ETF", "side": "Long", "securityIDType": "ISIN",
                "securityID": isin, "isin": isin, "conid": String(definition.sourceIdentity.dropFirst("ibkr-conid:".count)),
                "symbol": mapping.code, "listingExchange": try XCTUnwrap(mapping.listing), "description": "Isolated " + mapping.code,
                "currency": "USD", "multiplier": "1", "position": "1", "costBasisPrice": "100", "costBasisMoney": "100",
                "markPrice": "100", "positionValue": "100", "fifoPnlUnrealized": "0"]
            return try IBKRFlexPosition.parse(attributes, ordinal: offset + 1, expectedAccountID: account, reportDateText: day)
        }
        let digest = String(repeating: "a", count: 64)
        let source = IBKRFlexAccountSnapshot(observationID: "ibkr-flex-" + digest, accountID: account, queryID: "1",
            referenceCode: "1", reportDate: "2026-01-01", reportDateText: day, generatedAtSourceText: generated,
            fetchedAt: Date().addingTimeInterval(-60), sourceFingerprintAlgorithm: IBKRFlexAccountSnapshot.fingerprintAlgorithm,
            sourceSHA256: digest, sourceByteCount: 1, queryAttributes: ["type": "AF", "queryName": "Isolated"],
            statementAttributes: ["accountId": account, "period": "LastBusinessDay", "fromDate": day,
                                  "toDate": day, "whenGenerated": generated], positions: positions)
        XCTAssertEqual(provider.investmentRepo.saveIBKRFlexHoldings(.init(providerGeneration: provider.generationToken,
            workspace: .init(id: "default-workspace", name: "Isolated", createdAtISO: "2026-01-01T00:00:00Z"),
            baseline: .empty, source: source)), .saved)
    }

    func testPriceReasonsKeepMixedOutcomesNewerQuotesAndClearOnlyOnANewCheck() async throws {
        let cases: [(String, InvestmentPriceError?)] = [
            ("older", .olderResponse), ("equal", nil), ("newer", nil), ("offline", .networkInterrupted),
            ("http401", .unavailable), ("http503", .unavailable), ("malformed", .invalidResponse),
            ("identity", .wrongIdentity), ("currency", .wrongCurrency), ("missing", .invalidResponse)]
        let definitions = Array(InvestmentPriceRegistry.definitions.filter { $0.mapping.provider == "nasdaq" }.prefix(cases.count))
        XCTAssertEqual(definitions.count, cases.count)
        let url = try location(), provider = try SQLiteRepositoryProvider(path: url.path)
        try seedPriceHoldings(definitions, in: provider)
        let holdings = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        let config = BackgroundScheduleConfiguration(enabled: true, alDarCurrencyRatesEnabled: false,
            investmentPublicPricesEnabled: true, gmailCollectionEnabled: false, zurichISPHoldingsEnabled: false)
        try provider.backgroundScheduleRepo.saveConfiguration(config)
        let fetched = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-05T20:00:00Z"))
        var originals: [String: InvestmentQuote] = [:]
        var responses: [String: (Data, Int)] = [:]
        var goodResponses: [String: Data] = [:]
        var offline: Set<String> = []
        for (definition, test) in zip(definitions, cases) {
            let mapping = definition.mapping, kind = test.0
            originals[mapping.identity] = .init(mapping: mapping, price: try InvestmentDecimal("100"),
                valuationDay: "2026-01-03", valuationText: "Jan 3, 2026", valuationInstant: nil,
                dateBasis: .providerCalendarDate, calendarTimeZone: "America/New_York",
                fetchedAt: fetched.addingTimeInterval(-86_400), sourceURL: "https://api.nasdaq.com", qualification: "Isolated test")
            func body(_ kind: String) throws -> Data {
                let primary: [String: String] = kind == "missing" ? [:] : [
                    "lastSalePrice": kind == "malformed" ? "invalid" : "$110",
                    "lastTradeTimestamp": kind == "older" ? "Jan 2, 2026" : kind == "equal" ? "Jan 3, 2026" : "Jan 4, 2026"]
                return try JSONSerialization.data(withJSONObject: ["data": [
                    "symbol": kind == "identity" ? "WRONG" : mapping.code,
                    "assetClass": "ETF", "currency": kind == "currency" ? "INR" : "USD",
                    "exchange": mapping.listing == "ARCA" ? "PSE" : "NASDAQ-GM", "primaryData": primary]])
            }
            responses[mapping.code] = (try body(kind), kind == "http401" ? 401 : kind == "http503" ? 503 : 200)
            goodResponses[mapping.code] = try body("newer")
            if kind == "offline" { offline.insert(mapping.code) }
        }
        try provider.backgroundPublicCacheRepo.mergeSeed(alDarLegs: [:], investmentQuotes: originals, now: Date())
        let replies = responses, interruptions = offline
        let client = InvestmentPriceClient(now: { fetched }, transport: { request in
            let code = request.url!.pathComponents.dropLast().last!
            if interruptions.contains(code) { throw URLError(.notConnectedToInternet) }
            let reply = replies[code]!
            return (reply.0, HTTPURLResponse(url: request.url!, statusCode: reply.1, httpVersion: nil, headerFields: nil)!)
        })
        let worker = BackgroundUpdateExecutor(provider: provider, activation: try provider.database.validatedActivationStamp(),
            workspaceID: "default-workspace", prices: client)
        let result = await worker.refreshPublic(configuration: config, manual: true, scopes: .nasdaq)
        XCTAssertEqual(result, .completed(.retryPending))
        let progress = try BackgroundPublicProgressStore(database: provider.database).load()
        let quotes = try provider.backgroundPublicCacheRepo.snapshot(now: Date()).investmentQuotes
        for (definition, test) in zip(definitions, cases) {
            let key = definition.mapping.identity, state = try XCTUnwrap(progress[key])
            XCTAssertEqual(state.priceError, test.1, test.0)
            if test.1 != nil { XCTAssertEqual(quotes[key], originals[key], test.0) }
            else { XCTAssertEqual(quotes[key]?.price.sourceText, "110"); XCTAssertTrue(state.succeeded) }
            XCTAssertEqual(state.waitingForConnectivity, test.0 == "offline")
            XCTAssertEqual(state.attempts, test.0 == "offline" ? 0 : 1)
            XCTAssertEqual(state.retryAt != nil, test.1 != nil && test.0 != "offline")
        }
        XCTAssertEqual(try provider.investmentRepo.snapshot(workspaceID: "default-workspace"), holdings)
        try provider.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: url.path)
        defer { reopened.database.close() }
        XCTAssertEqual(try BackgroundPublicProgressStore(database: reopened.database).load(), progress)
        XCTAssertEqual(try reopened.backgroundPublicCacheRepo.snapshot(now: Date()).investmentQuotes, quotes)

        let good = goodResponses
        func nextWorker(at instant: Date) throws -> BackgroundUpdateExecutor {
            .init(provider: reopened, activation: try reopened.database.validatedActivationStamp(), workspaceID: "default-workspace",
                prices: .init(now: { instant }, transport: { request in
                    let code = request.url!.pathComponents.dropLast().last!
                    return (good[code]!, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                }))
        }
        // A valid response with a future fetch instant is rejected by the
        // executor's admission guard, never mislabeled as an older quote.
        let futureWorker = try nextWorker(at: Date().addingTimeInterval(3_600))
        _ = await futureWorker.refreshPublic(configuration: config, manual: true, scopes: .nasdaq)
        XCTAssertTrue(try BackgroundPublicProgressStore(database: reopened.database).load().values.allSatisfy { $0.priceError == .invalidResponse })
        XCTAssertEqual(try reopened.backgroundPublicCacheRepo.snapshot(now: Date()).investmentQuotes, quotes)
        let successfulWorker = try nextWorker(at: fetched.addingTimeInterval(86_400))
        let success = await successfulWorker.refreshPublic(configuration: config, manual: true, scopes: .nasdaq)
        XCTAssertEqual(success, .completed(.installedCache))
        XCTAssertTrue(try BackgroundPublicProgressStore(database: reopened.database).load().values.allSatisfy {
            $0.succeeded && $0.priceFailure == nil && $0.priceError == nil && $0.failure == nil && $0.retryAt == nil
        })
        XCTAssertEqual(try reopened.investmentRepo.snapshot(workspaceID: "default-workspace"), holdings)
        XCTAssertEqual(try reopened.backgroundScheduleRepo.configuration(), config)
    }

    func testInterruptedPublicWorkWaitsAcrossReopenAndRecoversWithoutSpendingProviderAttempts() async throws {
        let url = try location(), provider = try SQLiteRepositoryProvider(path: url.path)
        let config = configuration(), transport = RateTransport([.notConnectedToInternet, .networkConnectionLost, nil])
        try provider.backgroundScheduleRepo.saveConfiguration(config)
        let firstExecutor = try executor(provider, transport: transport)
        let initial = await firstExecutor.refreshPublic(configuration: config, manual: true, scopes: .inr)
        XCTAssertEqual(initial, .completed(.retryPending))
        let first = try XCTUnwrap(BackgroundPublicProgressStore(database: provider.database).load()["aldar:INR"])
        XCTAssertEqual(first.attempts, 0); XCTAssertEqual(first.waitingForConnectivity, true)
        XCTAssertNotNil(first.checkedAt); XCTAssertNotNil(first.failure); XCTAssertNil(first.retryAt)
        XCTAssertTrue(try provider.backgroundPublicCacheRepo.snapshot(now: Date()).alDarLegs.isEmpty)
        try provider.database.checkpointAndClose()

        let reopened = try SQLiteRepositoryProvider(path: url.path)
        defer { reopened.database.close() }
        let resumed = try executor(reopened, transport: transport)
        XCTAssertEqual(try BackgroundPublicProgressStore(database: reopened.database).load()["aldar:INR"], first)
        let ordinary = await resumed.refreshPublic(configuration: config, manual: false, scopes: .inr)
        let retry = try await resumed.nextPublicRetry()
        XCTAssertEqual(ordinary, .notDue); XCTAssertNil(retry)
        let one = await transport.calls; XCTAssertEqual(one, 1)

        for expectedCall in 2...3 {
            let release = await resumed.releaseInterruptedPublic(configuration: config)
            XCTAssertEqual(release, .released(.inr))
            let released = try XCTUnwrap(BackgroundPublicProgressStore(database: reopened.database).load()["aldar:INR"])
            XCTAssertNotNil(released.failure); XCTAssertNotNil(released.checkedAt)
            let result = await resumed.refreshPublic(configuration: config, manual: false, scopes: .inr)
            XCTAssertEqual(result, .completed(expectedCall == 2 ? .retryPending : .installedCache))
            let again = await resumed.refreshPublic(configuration: config, manual: false, scopes: .inr)
            XCTAssertEqual(again, .notDue)
            let count = await transport.calls; XCTAssertEqual(count, expectedCall)
        }
        let done = try XCTUnwrap(BackgroundPublicProgressStore(database: reopened.database).load()["aldar:INR"])
        XCTAssertTrue(done.succeeded); XCTAssertEqual(done.attempts, 1); XCTAssertNil(done.failure)
        XCTAssertEqual(done.waitingForConnectivity, false)
        let duplicateEvent = await resumed.releaseInterruptedPublic(configuration: config)
        XCTAssertEqual(duplicateEvent, .nothingEligible)
        XCTAssertEqual(try reopened.backgroundPublicCacheRepo.snapshot(now: Date()).alDarLegs[.inr]?.returned.rawToken, "25.50")
        XCTAssertEqual(try reopened.backgroundScheduleRepo.configuration(), config)
    }

    func testSecondAttemptInterruptionKeepsOrdinaryErrorBudgetAndFinalFailureTerminal() async throws {
        let provider = try SQLiteRepositoryProvider(path: location().path)
        defer { provider.database.close() }
        let config = configuration(), now = Date()
        let store = BackgroundPublicProgressStore(database: provider.database)
        try store.save(.init(identity: "aldar:INR", slot: BackgroundSchedule.publicSlot(at: now),
                             attempts: 1, retryAt: now.addingTimeInterval(-1), failure: "Rate unavailable"))
        let transport = RateTransport([.networkConnectionLost, .badServerResponse])
        let worker = try executor(provider, transport: transport)
        let interrupted = await worker.refreshPublic(configuration: config, manual: false, scopes: .inr)
        XCTAssertEqual(interrupted, .completed(.retryPending))
        XCTAssertEqual(try store.load()["aldar:INR"]?.attempts, 1)
        let release = await worker.releaseInterruptedPublic(configuration: config)
        XCTAssertEqual(release, .released(.inr))
        let failed = await worker.refreshPublic(configuration: config, manual: false, scopes: .inr)
        XCTAssertEqual(failed, .completed(.failedFinal))
        let final = try XCTUnwrap(store.load()["aldar:INR"])
        XCTAssertEqual(final.attempts, 2); XCTAssertEqual(final.waitingForConnectivity, false); XCTAssertNil(final.retryAt)
        let noRelease = await worker.releaseInterruptedPublic(configuration: config)
        let noRetry = await worker.refreshPublic(configuration: config, manual: false, scopes: .inr)
        XCTAssertEqual(noRelease, .nothingEligible); XCTAssertEqual(noRetry, .notDue)
        let count = await transport.calls; XCTAssertEqual(count, 2)

        var ordinary = BackgroundPublicLegProgress(identity: "aldar:USD", slot: now, attempts: 1)
        ordinary.recordFailure("Rate unavailable", interrupted: false, at: now)
        XCTAssertEqual(ordinary.retryAt, now.addingTimeInterval(60)); XCTAssertEqual(ordinary.attempts, 1)
    }

    func testWaitingEligibilityRespectsDisabledScopesLeasesLegacyRecordsAndSlotRollover() async throws {
        let provider = try SQLiteRepositoryProvider(path: location().path)
        defer { provider.database.close() }
        let transport = RateTransport([nil, nil]), worker = try executor(provider, transport: transport)
        let now = Date(), slot = BackgroundSchedule.publicSlot(at: now), store = BackgroundPublicProgressStore(database: provider.database)
        let old = Data(#"{"identity":"aldar:USD","slot":100,"attempts":2,"succeeded":false,"failure":"Rate unavailable"}"#.utf8)
        let legacy = try JSONDecoder().decode(BackgroundPublicLegProgress.self, from: old)
        XCTAssertNil(legacy.waitingForConnectivity)
        try store.save(legacy)
        var manual = BackgroundPublicLegProgress(identity: "aldar:INR", slot: slot.addingTimeInterval(-86400),
            failure: "Rate unavailable", manuallyRequested: true, checkedAt: now, waitingForConnectivity: true)
        try store.save(manual)
        let disabled = configuration(rates: false)
        let noTimer = try await worker.nextAutomaticTarget(configuration: disabled, now: now)
        XCTAssertNil(noTimer)
        var lease = try XCTUnwrap(BackgroundJobLease.acquire(path: provider.databasePath, kind: .publicReferences)) as BackgroundJobLease?
        let busy = await worker.releaseInterruptedPublic(configuration: disabled)
        XCTAssertEqual(busy, .busy); XCTAssertEqual(try store.load()[manual.identity], manual)
        withExtendedLifetime(lease) {}; lease = nil
        let released = await worker.releaseInterruptedPublic(configuration: disabled)
        XCTAssertEqual(released, .released(.inr))
        let finished = await worker.refreshPublic(configuration: disabled, manual: false)
        XCTAssertEqual(finished, .completed(.installedCache))
        XCTAssertEqual(try store.load()[legacy.identity], legacy)
        let disabledNext = try await worker.nextAutomaticTarget(configuration: disabled, now: Date())
        XCTAssertNil(disabledNext)

        // The same manual-origin interruption in an enabled source covers the
        // current slot once, whether it resumes at the clock or a network event.
        manual.manuallyRequested = true
        try store.save(manual)
        var sibling = legacy; sibling.succeeded = true
        sibling = .init(identity: legacy.identity, slot: slot, attempts: 1, succeeded: true)
        try store.save(sibling)
        let releaseInNewSlot = await worker.releaseInterruptedPublic(configuration: configuration())
        XCTAssertEqual(releaseInNewSlot, .released(.inr))
        let covered = await worker.refreshPublic(configuration: configuration(), manual: false, scopes: .inr)
        XCTAssertEqual(covered, .completed(.installedCache))
        XCTAssertEqual(try store.load()[manual.identity]?.slot, slot)
        let next = try await worker.nextAutomaticTarget(configuration: configuration(), now: Date())
        XCTAssertEqual(next, BackgroundSchedule.nextOccurrence(of: configuration().publicReferencesRule, after: Date()))
        let count = await transport.calls; XCTAssertEqual(count, 2)
    }

    func testClientsPreserveOnlyTheTwoConnectivityErrors() async throws {
        let definition = try XCTUnwrap(InvestmentPriceRegistry.definitions.first { $0.mapping.provider == "nasdaq" })
        let credentials = ZurichISPCredentials(username: "isolated", password: "test-only", memorablePIN: "1234")
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut, .badServerResponse, .cancelled] {
            let isInterruption = code == .notConnectedToInternet || code == .networkConnectionLost
            let prices = InvestmentPriceClient(transport: { _ in throw URLError(code) })
            let result = await prices.fetch([definition])
            guard case .failure(let error) = result[definition.mapping.identity] else { return XCTFail("Expected a failed transport") }
            XCTAssertEqual(error, isInterruption ? .networkInterrupted : .unavailable)
            let isp = ZurichISPClient(transport: { _, _ in throw URLError(code) })
            do { _ = try await isp.fetch(credentials: credentials, expectedPolicyIDs: [], status: { _ in }); XCTFail("Expected failure") }
            catch { XCTAssertEqual(error as? ZurichISPClientError, isInterruption ? .networkInterrupted : .network) }
        }
        for failure in [ZurichISPClientError.rejectedSignIn, .sessionExpired, .malformedSource, .timedOut, .partialResponse] {
            let isp = ZurichISPClient(transport: { _, _ in throw failure })
            do { _ = try await isp.fetch(credentials: credentials, expectedPolicyIDs: [], status: { _ in }); XCTFail("Expected failure") }
            catch { XCTAssertEqual(error as? ZurichISPClientError, failure) }
        }
    }

    func testISPInterruptedReceiptNeedsAnEventAndOneEventCannotConsumeItsOwnNewFailure() async throws {
        let provider = try SQLiteRepositoryProvider(path: location().path)
        defer { provider.database.close() }
        let transport = ISPTransport(), config = configuration(rates: false, isp: true)
        let worker = BackgroundUpdateExecutor(provider: provider, activation: try provider.database.validatedActivationStamp(),
            workspaceID: "default-workspace", ispClient: .init(transport: { request, _ in try await transport.fetch(request) }),
            ispCredentials: { .init(username: "isolated", password: "test-only", memorablePIN: "1234") })
        let initial = await worker.refreshISP(configuration: config, manual: true)
        XCTAssertEqual(initial, .completed(.retryPending))
        let claimA = try XCTUnwrap(provider.backgroundJobRepo.jobRecord(.zurichISP))
        let ordinary = await worker.refreshISP(configuration: config, manual: false)
        XCTAssertEqual(ordinary, .notDue)
        let busy = await worker.runAutomaticNonPublic(configuration: config, recoverInterruptedISP: true)
        XCTAssertFalse(busy)
        let claimB = try XCTUnwrap(provider.backgroundJobRepo.jobRecord(.zurichISP))
        XCTAssertNotEqual(claimA.claimID, claimB.claimID); XCTAssertEqual(claimB.outcome, .retryPending)
        let staleGrant = await worker.refreshISP(configuration: config, manual: false, recovering: claimA.claimID)
        XCTAssertEqual(staleGrant, .notDue)
        let two = await transport.calls; XCTAssertEqual(two, 2)
        _ = await worker.runAutomaticNonPublic(configuration: config, recoverInterruptedISP: true)
        XCTAssertEqual(try provider.backgroundJobRepo.jobRecord(.zurichISP)?.outcome, .failedFinal)
        _ = await worker.runAutomaticNonPublic(configuration: config, recoverInterruptedISP: true)
        let three = await transport.calls; XCTAssertEqual(three, 3, "HTTP failure is terminal, not another interruption")
        XCTAssertEqual(try provider.investmentRepo.snapshot(workspaceID: "default-workspace"), .empty)
    }

    func testRecoveryEventsCoalesceAndSurviveActiveWorkWithoutBusyLoops() {
        var recovery = BackgroundConnectivityRecovery()
        recovery.networkAvailableEvent(); recovery.networkAvailableEvent()
        let offline = recovery.begin(networkAvailable: false)
        XCTAssertNil(offline.publicEvent); XCTAssertNil(offline.ispEvent); XCTAssertTrue(recovery.hasPending)
        let first = recovery.begin(networkAvailable: true)
        XCTAssertNotNil(first.publicEvent); XCTAssertFalse(recovery.hasPending)
        XCTAssertFalse(recovery.finish(first, publicBusy: true, ispBusy: false), "A lease is not a new event")
        XCTAssertTrue(recovery.hasPending)
        recovery.observedCompletion()
        let second = recovery.begin(networkAvailable: true)
        XCTAssertEqual(second.publicEvent, first.publicEvent); XCTAssertNil(second.ispEvent)
        recovery.networkAvailableEvent() // Arrives while an operation is active.
        XCTAssertTrue(recovery.finish(second, publicBusy: false, ispBusy: false))
        let third = recovery.begin(networkAvailable: true)
        XCTAssertNotEqual(third.publicEvent, second.publicEvent)
        recovery.observedCompletion() // Completion raced the busy result.
        XCTAssertTrue(recovery.finish(third, publicBusy: true, ispBusy: true))
        let last = recovery.begin(networkAvailable: true)
        XCTAssertFalse(recovery.finish(last, publicBusy: false, ispBusy: false))
        XCTAssertFalse(recovery.hasPending, "A second transport interruption must wait for a fresh event")
        recovery.networkAvailableEvent()
        let busyPublic = recovery.begin(networkAvailable: true)
        recovery.observedCompletion(.zurichISP)
        XCTAssertFalse(recovery.finish(busyPublic, publicBusy: true, ispBusy: false), "An idle ISP release cannot spin a busy public lane")
        XCTAssertTrue(recovery.hasPending(.publicReferences)); XCTAssertFalse(recovery.hasPending(.zurichISP))
        let retryPublic = recovery.begin(networkAvailable: true)
        recovery.observedCompletion(.publicReferences)
        XCTAssertTrue(recovery.finish(retryPublic, publicBusy: true, ispBusy: false))
    }

    func testSalaryRecoveryRequiresTheExactInterruptedAttemptAndNoLaterSuccess() {
        let attempted = Date(timeIntervalSince1970: 1_800_000_000.25), now = attempted.addingTimeInterval(30)
        let formatter = ISO8601DateFormatter()
        var salary = SalaryAssistance(transactionID: "isolated-salary", workspaceID: "isolated", financialDate: "2026-01-01",
            targetMonth: "2026-01", ispLastAttemptAt: formatter.string(from: attempted))
        var receipt = BackgroundJobRecord(kind: .zurichISP, claimID: UUID(), activationEpoch: UUID(), origin: .helper,
            claimedAt: attempted, completedAt: attempted.addingTimeInterval(1), outcome: .retryPending)
        func admitted(_ latest: Date? = nil) -> Bool {
            BackgroundUpdateExecutor.canRecoverSalary(salary, receipt: receipt, now: now, latestFetch: latest)
        }
        XCTAssertTrue(admitted()); XCTAssertFalse(admitted(attempted.addingTimeInterval(2)))
        for state in [SalaryAssistance.ISPState.verified, .dismissed] { salary.ispState = state; XCTAssertFalse(admitted()) }
        salary.ispState = .indeterminate; XCTAssertTrue(admitted())
        salary.ispLastAttemptAt = formatter.string(from: attempted.addingTimeInterval(-1)); XCTAssertFalse(admitted())
        salary.ispLastAttemptAt = formatter.string(from: attempted)
        receipt.outcome = .failedFinal; XCTAssertFalse(admitted())
    }

    func testMixedBatchRecoversOnlyInterruptedCurrencyAndPreservesSuccessfulSibling() async throws {
        let provider = try SQLiteRepositoryProvider(path: location().path)
        defer { provider.database.close() }
        let transport = RateTransport([nil, .notConnectedToInternet, nil])
        let worker = try executor(provider, transport: transport), config = configuration()
        let first = await worker.refreshPublic(configuration: config, manual: true, scopes: .rates)
        XCTAssertEqual(first, .completed(.retryPending))
        let requests = await transport.currencies
        let success = try XCTUnwrap(requests.first), interrupted = try XCTUnwrap(requests.last)
        XCTAssertNotEqual(success, interrupted)
        let before = try BackgroundPublicProgressStore(database: provider.database).load()["aldar:" + success.rawValue]
        let cache = try provider.backgroundPublicCacheRepo.snapshot(now: Date()).alDarLegs[success]
        let release = await worker.releaseInterruptedPublic(configuration: config)
        XCTAssertEqual(release, .released(.currency(interrupted)))
        let recovered = await worker.refreshPublic(configuration: config, manual: false, scopes: .rates)
        XCTAssertEqual(recovered, .completed(.installedCache))
        let actual = await transport.currencies
        XCTAssertEqual(actual, [success, interrupted, interrupted])
        XCTAssertEqual(try BackgroundPublicProgressStore(database: provider.database).load()["aldar:" + success.rawValue], before)
        XCTAssertEqual(try provider.backgroundPublicCacheRepo.snapshot(now: Date()).alDarLegs[success], cache)

        // A disabled sibling with no history must not be admitted by recovery.
        let other = try SQLiteRepositoryProvider(path: location().path)
        defer { other.database.close() }
        let one = RateTransport([.networkConnectionLost, nil]), narrow = try executor(other, transport: one)
        _ = await narrow.refreshPublic(configuration: config, manual: true, scopes: .inr)
        _ = await narrow.releaseInterruptedPublic(configuration: configuration(rates: false))
        _ = await narrow.refreshPublic(configuration: configuration(rates: false), manual: false)
        let exact = await one.currencies
        XCTAssertEqual(exact, [.inr, .inr])
        XCTAssertNil(try BackgroundPublicProgressStore(database: other.database).load()["aldar:USD"])
    }

    func testSalaryAdmissionRechecksCurrentOwnerChoiceWithoutCreatingAClaim() async throws {
        let provider = try SQLiteRepositoryProvider(path: location().path)
        defer { provider.database.close() }
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: "default-workspace", name: "Isolated", createdAtISO: "2026-01-01T00:00:00Z"))
        let enabled = IntelligencePreferences(workspaceID: "default-workspace", salaryISPEnabled: true)
        try provider.intelligenceRepo.applyPlanning(.preferences(enabled, replacing: nil))
        let captured = try provider.intelligenceRepo.snapshot(workspaceID: "default-workspace")
        XCTAssertEqual(captured?.preferences?.salaryISPEnabled, true)
        var disabled = enabled; disabled.salaryISPEnabled = false
        try provider.intelligenceRepo.applyPlanning(.preferences(disabled, replacing: enabled))
        let worker = try executor(provider, transport: RateTransport([]))
        let result = try await worker.admitISP(salaryCheck: true, now: Date(), baseline: .empty, recovery: nil)
        guard case .notDue = result else { return XCTFail("Stale preflight must not authorize salary-only admission") }
        XCTAssertNil(try provider.backgroundJobRepo.jobRecord(.zurichISP))
        XCTAssertEqual(try provider.intelligenceRepo.snapshot(workspaceID: "default-workspace")?.preferences, disabled)
        let manual = try await worker.admitISP(salaryCheck: false, now: Date(), baseline: .empty, recovery: nil)
        guard case .claimed = manual else { return XCTFail("Disabling salary assistance cannot disable explicit or monthly work") }
    }

    func testSameAuthorityFallbackPreservesActivePassButChangedOwnerConfigurationCancelsIt() async throws {
        let url = try location(), provider = try SQLiteRepositoryProvider(path: url.path)
        defer { provider.database.close() }
        var config = configuration(); config.ibkrFlexHoldingsEnabled = true
        try provider.backgroundScheduleRepo.saveConfiguration(config)
        let enrollment = BackgroundEnrollmentStore(url: url.deletingLastPathComponent().appendingPathComponent("enrollment.json"))
        let enrolled = BackgroundEnrollment(revision: UUID(), databasePath: url.path, workspaceID: "default-workspace",
            activation: try provider.database.validatedActivationStamp(), enabled: true)
        try enrollment.save(enrolled)
        let gate = DatabaseActivityGate.shared, unavailable = gate.isUnavailable
        guard gate.beginExclusive(allowUnavailable: true) else { return XCTFail("Requires isolated activity interval") }
        let original = DatabaseProvider.shared
        defer {
            DatabaseProvider.shared = original
            if unavailable { gate.enterUnavailable() } else { gate.finishExclusive(providerChanged: false) }
        }
        DatabaseProvider.shared = .verifiedSQLite(provider)
        let session = BackgroundUpdatesSession(networkEnabled: false, enrollmentStore: enrollment, serviceStatus: { .enabled })
        defer { session.cancelAutomaticPassForTesting() }
        session.reload()
        let managed = try XCTUnwrap(session.executorForTesting)
        let pass = Task<Void, Never> { do { try await Task.sleep(for: .seconds(60)) } catch {} }
        session.holdAutomaticPassForTesting(pass, configuration: config)
        session.helperBecameUnavailable(after: session.helperRecoveryGeneration)
        session.reload()
        XCTAssertTrue(session.executorForTesting === managed)
        XCTAssertFalse(pass.isCancelled, "Same-authority fallback must not discard a captured ISP opportunity")
        session.cancelAutomaticPassForTesting(); await pass.value
        session.reload()
        let fallback = try XCTUnwrap(session.executorForTesting)
        XCTAssertFalse(fallback === managed)

        // This is the real inactive-settings save path: no new enrollment is
        // created, and it must retire a pass that captured the previous choice.
        let later = Task<Void, Never> { do { try await Task.sleep(for: .seconds(60)) } catch {} }
        session.holdAutomaticPassForTesting(later, configuration: config)
        session.saveIBKRSchedule(enabled: false, rule: config.ibkrFlexRule, replacing: config)
        XCTAssertTrue(later.isCancelled)
        await later.value
        XCTAssertFalse(session.executorForTesting === fallback)
        XCTAssertEqual(try enrollment.load(), enrolled)
        XCTAssertFalse(try provider.backgroundScheduleRepo.configuration().ibkrFlexHoldingsEnabled)
    }

    func testNoOpLeaseHolderSignalsAfterReleaseSoPendingRecoveryCanResume() async throws {
        let provider = try SQLiteRepositoryProvider(path: location().path)
        defer { provider.database.close() }
        let path = provider.databasePath
        let released = expectation(description: "No-op released its lease")
        released.assertForOverFulfill = false
        let observer = DistributedNotificationCenter.default().addObserver(forName: BackgroundUpdateExecutor.didReleaseNotification,
            object: BackgroundJobKind.publicReferences.rawValue, queue: .main) { _ in
                do {
                    let lease = try BackgroundJobLease.acquire(path: path, kind: .publicReferences)
                    XCTAssertNotNil(lease)
                    withExtendedLifetime(lease) {}
                    released.fulfill()
                } catch { XCTFail("Could not check released lease") }
            }
        defer { DistributedNotificationCenter.default().removeObserver(observer) }
        let worker = try executor(provider, transport: RateTransport([]))
        let result = await worker.refreshPublic(configuration: configuration(rates: false), manual: false)
        XCTAssertEqual(result, .notDue)
        let completion = await XCTWaiter.fulfillment(of: [released], timeout: 2)
        XCTAssertEqual(completion, .completed)
        XCTAssertNil(try provider.backgroundJobRepo.jobRecord(.publicReferences))
    }
}
