import CryptoKit
import Foundation
import XCTest
@testable import LedgerForge

private func stageCPost(_ body: Data, to url: URL, token: String) async throws -> (status: Int, body: Data) {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    let (reply, response) = try await URLSession.shared.data(for: request)
    guard let status = (response as? HTTPURLResponse)?.statusCode else { throw URLError(.badServerResponse) }
    return (status, reply)
}

/// Opt-in end-to-end HTTP qualification. The selected native backup is verified
/// and copied; every mutation below is confined to a temporary candidate.
@MainActor
final class FinancialMCPPlanningRuntimeTests: XCTestCase {
    private let month = "2026-10"
    private let timestamp = "2026-10-21T04:00:00Z"

    func testAuthenticBackupIsolatedHTTPPlanningWriteAndRetry() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let selected = environment["LEDGERFORGE_STAGE_C_BACKUP"]
            ?? environment["LEDGERFORGE_COMPANION_AUTHENTIC_BACKUP"], !selected.isEmpty else {
            throw XCTSkip("STAGE_C_NATIVE_BACKUP_NOT_SELECTED")
        }
        let source = URL(fileURLWithPath: selected).standardizedFileURL.resolvingSymlinksInPath()
        let sourceManifest = try BackupFiles.verifyPackage(source)
        let originalPayloadHash = try BackupFiles.hash(source.appendingPathComponent("ledger.sqlite")).sha256
        let originalManifestHash = try BackupFiles.hash(source.appendingPathComponent("manifest.json")).sha256
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-StageC-HTTP-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let candidate = folder.appendingPathComponent("isolated.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: source, manifest: sourceManifest, destination: candidate)

        var sqlite = try SQLiteRepositoryProvider(path: candidate.path, migrations: allMigrations, access: .existing)
        var provider = DatabaseProvider.verifiedSQLite(sqlite)
        defer { provider.invalidateGeneration(); sqlite.database.close() }
        let workspace = "stage-c-http-" + UUID().uuidString.lowercased()
        let planID = workspace + "-plan"
        try seedMechanicalPlan(provider: provider, workspace: workspace, planID: planID)
        var store = FundingPlanStore()
        try hydrate(provider: provider, store: store, workspace: workspace)
        let baseline = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
        let revision = try XCTUnwrap(baseline.writeRevision)
        let evidenceBefore = try nonPlanningTableDigests(sqlite.database)
        var service = makeService(provider: provider, store: store, workspace: workspace)

        let token = "stage-c-ephemeral-" + UUID().uuidString
        var writeAllowed = false
        let listener = try FinancialMCPLocalHTTP()
        defer { listener.stop() }
        listener.handler = { request in
            guard request.path == "/mcp" else { return (404, Data()) }
            guard request.headers["authorization"] == "Bearer " + token,
                  request.headers["origin"] == nil else { return (401, Data()) }
            guard request.method == "POST" else { return (405, Data()) }
            return FinancialMCPProtocol.handle(request.body,
                allowed: [FinancialMCPProtocol.Tool.planningContext.rawValue],
                writeAllowed: writeAllowed,
                write: { service.apply($0) },
                read: { _, _ in [:] })
        }
        let ready = expectation(description: "isolated Financial MCP listener ready")
        var port: UInt16 = 0
        listener.onReady = { actual in port = actual; ready.fulfill() }
        listener.start()
        await fulfillment(of: [ready], timeout: 5)
        XCTAssertNotEqual(port, 0)
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/mcp"))
        let requestID = UUID().uuidString.lowercased()
        let body = FinancialMCPProtocol.encode([
            "jsonrpc": "2.0", "id": "stage-c-qualification", "method": "tools/call",
            "params": [
                "name": FinancialMCPProtocol.planningWriteToolName,
                "arguments": [
                    "request_id": requestID, "workspace_id": workspace, "month": month,
                    "plan_id": planID, "expected_write_revision": revision,
                    "changes": [["type": "monthly_amount", "field": "expected_variable",
                                 "amount": ["currency": "QAR", "decimal": "1.00"]]]
                ]
            ]
        ] as [String: Any])

        let badAuth = try await stageCPost(body, to: url, token: "wrong-ephemeral-token")
        XCTAssertEqual(badAuth.status, 401)
        XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision,
                       baseline.monthRevision)
        let denied = try await stageCPost(body, to: url, token: token)
        XCTAssertEqual(denied.status, 200)
        XCTAssertEqual(try structured(denied.body)["error"] as? String, "planning_write_not_authorized")
        XCTAssertNil(try provider.fundingPlanRepo.planningRequestReceipt(requestID: requestID))
        XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision,
                       baseline.monthRevision)

        // The caller deliberately drops the first successful HTTP body. Reopen
        // the isolated provider and repeat the identical request to recover its
        // durable technical receipt, as after a lost response.
        writeAllowed = true
        _ = try await stageCPost(body, to: url, token: token)
        let committed = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
        XCTAssertEqual(committed.monthRevision.counter, baseline.monthRevision.counter + 1)
        XCTAssertEqual(committed.monthRevision.latestOrigin, .chatgpt)
        XCTAssertNotNil(try provider.fundingPlanRepo.planningRequestReceipt(requestID: requestID))

        provider.invalidateGeneration()
        try sqlite.database.checkpointAndClose()
        sqlite = try SQLiteRepositoryProvider(path: candidate.path, migrations: allMigrations, access: .existing)
        provider = .verifiedSQLite(sqlite)
        store = FundingPlanStore()
        try hydrate(provider: provider, store: store, workspace: workspace)
        service = makeService(provider: provider, store: store, workspace: workspace)
        let replay = try await stageCPost(body, to: url, token: token)
        XCTAssertEqual(replay.status, 200)
        let replayValue = try structured(replay.body)
        XCTAssertEqual(replayValue["outcome"] as? String, "applied", String(describing: replayValue))
        XCTAssertEqual(replayValue["replayed"] as? Bool, true)
        XCTAssertEqual((replayValue["canonical_readback"] as? [String: Any])?["state"] as? String, "verified")
        XCTAssertEqual(replayValue["committed_month_revision"] as? String, String(committed.monthRevision.counter))
        let afterReplay = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
        XCTAssertEqual(afterReplay.monthRevision.workspaceID, committed.monthRevision.workspaceID)
        XCTAssertEqual(afterReplay.monthRevision.month, committed.monthRevision.month)
        XCTAssertEqual(afterReplay.monthRevision.counter, committed.monthRevision.counter)
        XCTAssertEqual(afterReplay.monthRevision.latestOrigin, committed.monthRevision.latestOrigin)
        XCTAssertNotEqual(afterReplay.monthRevision.providerID, committed.monthRevision.providerID)
        XCTAssertNotEqual(afterReplay.writeRevision, committed.writeRevision)
        XCTAssertEqual(try afterReplay.plan?.allocationCalculationInput().expectedVariableEarnings,
                       try Money(canonicalDecimal: "1.00", currency: "QAR"))

        let concurrentID = UUID().uuidString.lowercased()
        let concurrentArguments: [String: Any] = [
            "request_id": concurrentID, "workspace_id": workspace, "month": month,
            "plan_id": planID, "expected_write_revision": try XCTUnwrap(afterReplay.writeRevision),
            "changes": [["type": "monthly_amount", "field": "expected_variable",
                         "amount": ["currency": "QAR", "decimal": "2.00"]]]
        ]
        let expectedDigest = try PlanningChangeRequest.decode(
            FinancialMCPProtocol.encode(concurrentArguments)).digestSHA256()
        let concurrentBody = FinancialMCPProtocol.encode([
            "jsonrpc": "2.0", "id": "stage-c-concurrent", "method": "tools/call",
            "params": ["name": FinancialMCPProtocol.planningWriteToolName,
                       "arguments": concurrentArguments]
        ] as [String: Any])
        async let first = stageCPost(concurrentBody, to: url, token: token)
        async let second = stageCPost(concurrentBody, to: url, token: token)
        let (firstReply, secondReply) = try await (first, second)
        XCTAssertEqual(firstReply.status, 200)
        XCTAssertEqual(secondReply.status, 200)
        let values = try [structured(firstReply.body), structured(secondReply.body)]
        XCTAssertTrue(values.allSatisfy { $0["outcome"] as? String == "applied" && $0["committed"] as? Bool == true })
        XCTAssertEqual(values.filter { $0["replayed"] as? Bool == false }.count, 1)
        XCTAssertEqual(values.filter { $0["replayed"] as? Bool == true }.count, 1)
        XCTAssertTrue(values.allSatisfy {
            ($0["canonical_readback"] as? [String: Any])?["state"] as? String == "verified"
        })
        let afterConcurrent = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
        XCTAssertEqual(afterConcurrent.monthRevision.counter, afterReplay.monthRevision.counter + 1)
        XCTAssertEqual(try afterConcurrent.plan?.allocationCalculationInput().expectedVariableEarnings,
                       try Money(canonicalDecimal: "2.00", currency: "QAR"))
        let concurrentReceipt = try XCTUnwrap(provider.fundingPlanRepo.planningRequestReceipt(requestID: concurrentID))
        XCTAssertEqual(concurrentReceipt.requestID, concurrentID)
        XCTAssertEqual(concurrentReceipt.requestDigest, expectedDigest)
        XCTAssertEqual(concurrentReceipt.workspaceID, workspace)
        XCTAssertEqual(concurrentReceipt.month, month)
        XCTAssertEqual(concurrentReceipt.planID, planID)
        XCTAssertEqual(concurrentReceipt.committedRevision, afterConcurrent.monthRevision.counter)
        XCTAssertEqual(concurrentReceipt.outcome.rawValue, "saved")
        XCTAssertNotNil(FinancialMCPProtocol.object(Data(concurrentReceipt.resultJSON.utf8)))
        XCTAssertTrue(values.allSatisfy {
            $0["committed_month_revision"] as? String == String(concurrentReceipt.committedRevision)
        })
        XCTAssertEqual(try nonPlanningTableDigests(sqlite.database), evidenceBefore)
        try BackupCompatibility.verifyDatabase(sqlite.database)
        XCTAssertEqual(try BackupFiles.verifyPackage(source), sourceManifest)
        XCTAssertEqual(try BackupFiles.hash(source.appendingPathComponent("ledger.sqlite")).sha256, originalPayloadHash)
        XCTAssertEqual(try BackupFiles.hash(source.appendingPathComponent("manifest.json")).sha256, originalManifestHash)
    }

    private func seedMechanicalPlan(provider: DatabaseProvider, workspace: String, planID: String) throws {
        let zero = try Money(canonicalDecimal: "0.00", currency: "QAR")
        let thousand = try Money(canonicalDecimal: "1000.00", currency: "QAR")
        let hundred = try Money(canonicalDecimal: "100.00", currency: "QAR")
        let accountID = workspace + "-bank"
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Isolated Stage C qualification", createdAtISO: timestamp))
        _ = try provider.accountRepo.upsertAccount(.init(id: accountID, workspaceId: workspace,
            name: "Test bank", institutionId: nil, accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: timestamp))
        let plan = try FundingPlan(id: planID, workspaceID: workspace,
            month: SelectedStatementMonth(canonical: month),
            expectedFixedEarnings: thousand, expectedFixedProvenance: .manual,
            expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
            expectedDeductions: zero, expectedDeductionsProvenance: .manual,
            balances: [.init(id: workspace + "-balance", accountID: accountID,
                nativeCurrency: CurrencyCode("QAR"), included: true, money: hundred, provenance: .manual)],
            qatarCommitments: [.init(id: workspace + "-bill", label: "Test bill", money: hundred,
                included: true, fundingAccountID: accountID, provenance: .manual)],
            indiaCommitments: [], configuredTransferFee: zero, configuredTransferFeeProvenance: .manual,
            planningFX: FundingPlanFX(inrPerQAR: 3, observationDate: StatementDate(canonical: "2026-10-18")),
            plannedInvestment: zero, plannedInvestmentProvenance: .manual, updatedAtISO: timestamp,
            calculationVersion: .budgetV1, keepInCBQ: zero, referenceMode: .manual,
            assistance: .init(workspaceID: workspace, month: month))
        _ = try provider.fundingPlanRepo.savePlan(plan.persistenceDTO())
    }

    private func hydrate(provider: DatabaseProvider, store: FundingPlanStore, workspace: String) throws {
        let plans = try provider.fundingPlanRepo.plans(workspaceId: workspace).map { try $0.allocationCalculationInput() }
        let raw = try provider.fundingPlanRepo.scratchpads(workspaceId: workspace).map(MonthlyPlanScratchpad.decode)
        let revision = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision
        store.installWithoutObservation(plans, generation: provider.generationToken,
            scratchpads: raw, monthRevisions: [revision])
        store.notifyInstalledValue()
    }

    private func makeService(provider: DatabaseProvider, store: FundingPlanStore,
                             workspace: String) -> FinancialMCPPlanningWriteService {
        FinancialMCPPlanningWriteService(provider: { provider }, store: store,
            hydrate: { active in try self.hydrate(provider: active, store: store, workspace: workspace) })
    }

    private func structured(_ body: Data) throws -> [String: Any] {
        let rpc = try XCTUnwrap(FinancialMCPProtocol.object(body))
        let result = try XCTUnwrap(rpc["result"] as? [String: Any])
        return try XCTUnwrap(result["structuredContent"] as? [String: Any])
    }

    private func nonPlanningTableDigests(_ db: SQLiteDatabase) throws -> [String: String] {
        let excluded: Set<String> = [
            "funding_plans", "funding_plan_balances", "funding_plan_commitments",
            "funding_plan_deduction_components", "funding_plan_al_dar_references",
            "funding_plan_effective_al_dar_references", "plan_assistance",
            "monthly_plan_scratchpads", "planning_write_state", "planning_request_receipts"
        ]
        let tables = try db.query(sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;") {
            $0.string(at: 0) ?? ""
        }.filter { !excluded.contains($0) }
        var result: [String: String] = [:]
        for table in tables {
            let quoted = "\"" + table.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let columns = try db.query(sql: "PRAGMA table_info(\(quoted));") { $0.string(at: 1) ?? "" }.count
            var hasher = SHA256()
            _ = try db.query(sql: "SELECT * FROM \(quoted) ORDER BY rowid;") { row in
                for index in 0..<columns {
                    let position = Int32(index)
                    let marker: UInt8
                    let value: Data
                    if let blob = row.data(at: position) { marker = 2; value = blob }
                    else if let text = row.string(at: position) { marker = 1; value = Data(text.utf8) }
                    else { marker = 0; value = Data() }
                    hasher.update(data: Data([marker]))
                    hasher.update(data: Data("\(value.count):".utf8))
                    hasher.update(data: value)
                }
                return true
            }
            result[table] = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }
        return result
    }
}
