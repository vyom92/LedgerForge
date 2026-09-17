import CryptoKit
import Darwin
import Foundation
import Testing
@testable import LedgerForge

/// Explicit qualification transport for unchanged, nominated email originals.
/// A task-owned FIFO carries the original bytes and one-use unlock value in RAM.
/// No attachment, decrypted statement or financial oracle is a disk fixture.
@Suite(.serialized)
@MainActor
struct InvestmentRAMOriginalTests {
    nonisolated struct Original: Decodable, Sendable {
        let fileName: String
        let sha256: String
        let byteCount: Int
        let bytes: Data
        let password: String?
        let family: String
        let expected: [ExpectedHolding]
        let approvedFolioAliases: [[String]]?
    }

    /// Independent source interpretation arrives through the same RAM transport,
    /// before production output is read. These are comparison fields, not a
    /// FinancialDocument/DTO used as input to any import or repository.
    nonisolated struct ExpectedHolding: Decodable, Sendable {
        let container: String
        let institution: String?
        let instrument: String
        let units: String
        let currency: String
        let averageCost: String?
        let totalCost: String?
        let holdingsDate: String
        let valuationDate: String?
    }

    private enum QualificationError: Error { case invalidTransport, invalidOriginal }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEDGERFORGE_INVESTMENT_RAM_PIPE"] != nil))
    func nominatedOriginalsPrepareCommitAndReopen() async throws {
        var transport = stat()
        guard let path = ProcessInfo.processInfo.environment["LEDGERFORGE_INVESTMENT_RAM_PIPE"],
              lstat(path, &transport) == 0, transport.st_mode & S_IFMT == S_IFIFO,
              transport.st_uid == getuid() else {
            throw QualificationError.invalidTransport
        }
        let pipe = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? pipe.close() }
        let payload = try pipe.readToEnd() ?? Data()
        guard !payload.isEmpty, payload.count <= 64 * 1_024 * 1_024 else { throw QualificationError.invalidTransport }
        let originals = try JSONDecoder().decode([Original].self, from: payload)
        guard !originals.isEmpty, Set(originals.map(\.sha256)).count == originals.count else {
            throw QualificationError.invalidOriginal
        }
        for (index, original) in originals.enumerated() {
            guard original.bytes.count == original.byteCount,
                  SHA256.hash(data: original.bytes).map({ String(format: "%02x", $0) }).joined() == original.sha256,
                  ["pdf", "csv"].contains(URL(fileURLWithPath: original.fileName).pathExtension.lowercased()),
                  original.fileName == URL(fileURLWithPath: original.fileName).lastPathComponent else {
                throw QualificationError.invalidOriginal
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-investment-ram-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: folder) }
            let databaseURL = folder.appendingPathComponent("holdings.sqlite")
            let sqlite = try SQLiteRepositoryProvider(path: databaseURL.path)
            defer { sqlite.database.close() }
            for provider in [DatabaseProvider(inMemory: true), DatabaseProvider.verifiedSQLite(sqlite)] {
                let store = InvestmentStore()
                let engine = makeEngine(provider, original: original, store: store)
                do {
                    let url = URL(string: "gmail-original://\(original.sha256)/")!.appendingPathComponent(original.fileName)
                    let cancelled = try await engine.prepareImport(from: url)
                    engine.cancelPreparedImport(cancelled)
                    let empty = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == .empty
                    #expect(empty)
                    let prepared = try await engine.prepareImport(from: url)
                    guard prepared.validation.passed, !prepared.investmentConfirmationBlocked,
                          let expected = prepared.investmentReview?.snapshot else {
                        Issue.record("RAM original held at inventory index \(index).");
                        engine.cancelPreparedImport(prepared); continue
                    }
                    let result = await engine.commitPreparedImport(prepared)
                    let committed = result.succeeded
                    let exact = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
                    let hydrated = store.snapshot == expected
                    let currentOnly = expected.holdings.allSatisfy { $0.units.value > 0 }
                    #expect(committed && exact && hydrated && currentOnly)
                    let sourceAgrees = agreesWithOriginal(store.snapshot, expected: original.expected)
                    #expect(sourceAgrees, "Independent original comparison failed at inventory index \(index).")
                    let replay = try await engine.prepareImport(from: url)
                    let replayResult = await engine.commitPreparedImport(replay)
                    let unchanged = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
                    #expect(replayResult.previousImport != nil && unchanged)
                } catch {
                    let reason = (error as? InvestmentError).map { String(describing: $0) } ?? "reader-or-persistence"
                    Issue.record("RAM original failed at inventory index \(index): \(reason).")
                }
            }
            let before = try sqlite.investmentRepo.snapshot(workspaceID: "default-workspace")
            try sqlite.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: databaseURL.path)
            let exact = try reopened.investmentRepo.snapshot(workspaceID: "default-workspace") == before
            #expect(exact)
            let originalAgreesAfterReopen = try agreesWithOriginal(
                reopened.investmentRepo.snapshot(workspaceID: "default-workspace"), expected: original.expected)
            #expect(originalAgreesAfterReopen, "Independent original reopen comparison failed at inventory index \(index).")
            try BackupCompatibility.verifyDatabase(reopened.database)
            reopened.database.close()
        }
        try await confirmFolioAliasesAndSameDateSourceChoices(originals)
    }

    private func confirmFolioAliasesAndSameDateSourceChoices(_ originals: [Original]) async throws {
        let latest = originals.filter { ["cas_detailed", "cas_summary"].contains($0.family) }
        guard !latest.isEmpty else { return }
        guard latest.count == 2 else { throw QualificationError.invalidOriginal }
        let earlier = originals.filter { $0.family == "local-IndianMutualFunds" }
            .sorted { $0.expected[0].holdingsDate < $1.expected[0].holdingsDate }
        func folio(_ text: String) -> String { text.filter { !$0.isWhitespace } }
        for ordered in [latest, Array(latest.reversed())] {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-folio-ram-\(UUID())")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: folder) }
            let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("holdings.sqlite").path)
            defer { sqlite.database.close() }
            for provider in [DatabaseProvider(inMemory: true), DatabaseProvider.verifiedSQLite(sqlite)] {
                let store = InvestmentStore()
                for (index, original) in (earlier + ordered).enumerated() {
                    let engine = makeEngine(provider, original: original, store: store)
                    let url = URL(string: "original://\(original.sha256)/")!.appendingPathComponent(original.fileName)
                    var prepared = try await engine.prepareImport(from: url)
                    guard let plan = prepared.investmentPlan else { throw QualificationError.invalidOriginal }
                    var choices = plan.choices
                    for scope in plan.evidence.scopes {
                        let approved = (original.approvedFolioAliases ?? []).filter { $0.map(folio).contains(folio(scope.identity)) }
                        guard approved.count <= 1 else { throw QualificationError.invalidOriginal }
                        if let pair = approved.first {
                            let aliases = Set(pair.map(folio))
                            let targets = plan.baseline.containers.filter {
                                $0.identityKind == "folio" && !Set($0.aliases.map(folio)).isDisjoint(with: aliases)
                            }
                            guard targets.count <= 1 else { throw QualificationError.invalidOriginal }
                            if let target = targets.first { choices.containerTargets[scope.key] = target.id }
                        }
                    }
                    prepared.updateInvestmentChoices(choices)
                    guard let mapped = prepared.investmentReview, mapped.mappingQuestions.isEmpty else {
                        Issue.record("Confirmed folio choices did not resolve the authentic sequence at index \(index).")
                        engine.cancelPreparedImport(prepared); continue
                    }
                    if index == earlier.count + 1 { #expect(!mapped.sameDateConflictScopes.isEmpty) }
                    // Both genuine same-date representations must offer the same
                    // explicit choice; this branch exercises choosing the incoming one.
                    choices.replaceSameDateScopes = mapped.sameDateConflictScopes
                    prepared.updateInvestmentChoices(choices)
                    let result = await engine.commitPreparedImport(prepared)
                    let exact = agreesWithOriginal(store.snapshot, expected: original.expected)
                    let currentContainers = store.snapshot.containers.count == Set(original.expected.map { folio($0.container) }).count
                    #expect(result.succeeded && exact && currentContainers,
                        "Authentic folio sequence failed at index \(index).")
                    let replay = try await engine.prepareImport(from: url)
                    let replayNeedsNoMapping = replay.investmentReview?.mappingQuestions.isEmpty != false
                    let repeated = await engine.commitPreparedImport(replay)
                    #expect(repeated.previousImport != nil && replayNeedsNoMapping)
                }
                let snapshot = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
                for pair in latest.flatMap({ $0.approvedFolioAliases ?? [] }) {
                    let aliases = Set(pair.map(folio))
                    let matching = snapshot.containers.filter { !Set($0.aliases.map(folio)).isDisjoint(with: aliases) }
                    let preserved = matching.count == 1 && aliases.isSubset(of: Set(matching[0].aliases.map(folio)))
                    #expect(preserved)
                }
            }
        }
    }

    private func agreesWithOriginal(_ snapshot: InvestmentSnapshot, expected: [ExpectedHolding]) -> Bool {
        func folio(_ value: String) -> String { value.filter { !$0.isWhitespace } }
        func sameNumber(_ actual: InvestmentDecimal?, _ source: String?) -> Bool {
            switch (actual, source) {
            case (nil, nil): true
            case let (actual?, source?): actual.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                == source.trimmingCharacters(in: .whitespacesAndNewlines)
            default: false
            }
        }
        guard snapshot.holdings.count == expected.count else { return false }
        var matched = Set<String>()
        for source in expected {
            let candidates = snapshot.holdings.filter { holding in
                guard let container = snapshot.containers.first(where: { $0.id == holding.containerID }),
                      container.aliases.contains(where: { folio($0) == folio(source.container) }) else { return false }
                if let institution = source.institution,
                   container.institution.caseInsensitiveCompare(institution) != .orderedSame { return false }
                return holding.instrumentIdentity == "isin:" + source.instrument
                    || holding.sourceAliases.contains("isin:" + source.instrument)
                    || holding.instrumentIdentity == "cbq-fund-name:" + source.instrument
                    || holding.instrumentIdentity == "zurich-fund-name:" + source.instrument
            }
            guard candidates.count == 1, let holding = candidates.first, matched.insert(holding.id).inserted,
                  sameNumber(holding.units, source.units), sameNumber(holding.averageCost, source.averageCost),
                  sameNumber(holding.totalCost, source.totalCost), holding.currency == source.currency,
                  holding.holdingsDate == source.holdingsDate, holding.valuationDate == source.valuationDate,
                  holding.costCurrency == ((source.averageCost != nil || source.totalCost != nil) ? source.currency : nil),
                  !holding.displayName.contains("PAN:"), holding.priceMapping == nil else { return false }
        }
        return true
    }

    private func makeEngine(_ provider: DatabaseProvider, original: Original, store: InvestmentStore) -> ImportEngine {
        let passwords = DefaultPasswordProvider(
            credentialStore: InMemoryStatementPasswordCredentialStore(), supportedInstitutionCodes: [],
            challenge: { _ in original.password })
        let hydrator = RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo, investmentRepo: provider.investmentRepo,
            accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(),
            cardStore: CardStore(), salaryStore: SalaryStore(), fundingPlanStore: FundingPlanStore(), investmentStore: store,
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
            persistenceState: provider.persistenceState, providerGeneration: provider.generationToken, participatesInLifecycleGate: false)
        return ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
            sourceSnapshotAcquirer: { _ in SourceContentSnapshot(bytes: original.bytes) },
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
    }
}
