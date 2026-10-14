import CryptoKit
import Darwin
import Foundation
import Combine
import XCTest
@testable import LedgerForge

/// Opt-in, populated-native-backup qualification. Owner decisions enter through
/// a FIFO and stay in memory until ordinary repository APIs persist metadata.
/// No statement, source-derived fixture, financial attachment, or log is made.
@MainActor
final class CategorySpendingAuthenticQualificationTests: XCTestCase {
    private enum Failure: Error { case assertion(String) }

    private struct SourceFact: Decodable {
        let id: String, workspaceID: String
        let accountID: String?, importSessionID: String?, documentID: String?, originalRowID: String?
        let postedDate: String, financialDateRole: String, statementTimezoneEvidence: String
        let valueDate: String?, description: String?, payee: String?, reference: String?
        let currency: String, amountMinor: Int64, amountDecimal: String, direction: String
        let runningBalanceMinor: Int64?

        @MainActor func agrees(with fact: TransactionDTO) -> Bool {
            id == fact.id && workspaceID == fact.workspaceId && accountID == fact.accountId &&
            importSessionID == fact.importSessionId && documentID == fact.documentId && originalRowID == fact.originalRowId &&
            postedDate == fact.postedDateISO && financialDateRole == fact.financialDateRole &&
            statementTimezoneEvidence == fact.statementTimezoneEvidence && valueDate == fact.valueDateISO &&
            description == fact.description && payee == fact.payee && reference == fact.reference &&
            currency == fact.nativeCurrency && amountMinor == fact.amountMinor && amountDecimal == fact.amountDecimal &&
            direction == fact.direction && runningBalanceMinor == fact.runningBalanceMinor && fact.isTrusted
        }
    }
    private struct CategorySeed: Decodable { let id: String, name: String }
    private struct FiniteChoice: Decodable { let transactionID: String, categoryID: String }
    private struct Allocation: Decodable {
        let creditID: String
        let minor: Int64, creditMinor: Int64
        let purchaseDate: String?, creditDate: String?
    }
    private struct Refund: Decodable {
        let purchaseID: String, currency: String
        let purchaseMinor: Int64
        let requiresFeeRecognition: Bool
        let allocations: [Allocation]
    }
    private struct CashAdvanceCase: Decodable {
        let transactionID: String
        let expectedCashAdvanceFee: Bool
        let expectedTreatment: String
        let expectedSpendingMinor: Int64
    }
    private struct SourceOccurrence: Decodable {
        let sourceSHA256: String, normalizedDigest: String, canonicalID: String
        let sourceBytesIsDuplicateAuthority: Bool
        let sourceOrdinal: Int
        let matchedRuleIDs: [String], expenseRuleIDs: [String]
        var key: String { sourceSHA256 + "|" + normalizedDigest + "|" + String(sourceOrdinal) }
    }
    private struct FutureOriginalRow: Decodable {
        let sourceOrdinal: Int
        let frozenCanonicalID: String, normalizedDigest: String
        let date: String, narration: String, reference: String?, direction: String, currency: String
        let signedMinor: Int64, signedDecimal: String, balanceMinor: Int64
        let matchedRuleIDs: [String], expenseRuleIDs: [String]
        var key: String { String(sourceOrdinal) }
    }
    private struct FutureOriginal: Decodable {
        let sourceSHA256: String, currency: String, coverage: String, directionConvention: String
        let rawTextSHA256: String, frozenDocumentID: String
        let sourceBytesIsDuplicateAuthority: Bool, rawTextIsDuplicateAuthority: Bool
        let consecutiveBalanceChecks: Int
        let rows: [FutureOriginalRow]
    }
    private struct FutureOutcome: Equatable {
        let categoryID: String?, categoryKind: String?, spendingKind: String?, workOutcome: String
        let categoryRules: Set<String>, spendingRules: Set<String>
    }
    private struct Payload: Decodable {
        let formatVersion: Int
        let workspaceID: String, sourceBackupSHA256: String, sourceBackupID: String, reviewedAtISO: String
        let sourceFacts: [SourceFact]
        let baselineRules: [CategoryRule], baselineRawMatches: [String: [String]], baselineCategoryByID: [String: String]
        let categories: [CategorySeed], rules: [CategoryRule], expectedRawMatches: [String: [String]]
        let initialRules: [CategoryRule], initialRawMatches: [String: [String]], initialCategoryByID: [String: String]
        let initialAutomaticBankExpenseIDs: [String]
        let expectedCategoryByID: [String: String], expectedAutomaticBankExpenseIDs: [String]
        let salaryRuleID: String, expectedSalaryIDs: [String], excludedClosedSalaryIDs: [String]
        let finiteChoices: [FiniteChoice], refunds: [Refund], cashAdvanceCases: [CashAdvanceCase]
        let futureSourceOccurrences: [SourceOccurrence]
        let futureOriginal: FutureOriginal
        let portableConfigurationIncluded: Bool
    }

    @MainActor
    private final class Ledger {
        let directory: URL, path: URL, workspaceID: String
        var sqlite: SQLiteRepositoryProvider
        var provider: DatabaseProvider
        init(directory: URL, workspaceID: String) throws {
            self.directory = directory; self.workspaceID = workspaceID
            path = directory.appendingPathComponent("current.sqlite")
            let opened = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing)
            sqlite = opened; provider = .verifiedSQLite(opened)
        }
        func reopen() throws {
            provider.invalidateGeneration(); try sqlite.database.checkpointAndClose()
            sqlite = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing)
            provider = .verifiedSQLite(sqlite)
        }
        func close() { provider.invalidateGeneration(); sqlite.database.close() }
    }
    private struct Runtime {
        let snapshot: RepositoryRuntimeSnapshot
        let metadata: FinancialIntelligenceSnapshot
        let automation: CategoryAutomationSnapshot
        let rows: [SpendingSourceRow]
        let resolved: [SpendingReviewRow]
        let accounts: Set<String>
    }

    func testOwnerApprovedCategorySpendingAndRefundsOnSelectedAuthenticBackup() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let sourcePath = environment["LEDGERFORGE_CATEGORY_AUTHENTIC_BACKUP"], !sourcePath.isEmpty,
              let outputPath = environment["LEDGERFORGE_CATEGORY_QUALIFICATION_ROOT"], !outputPath.isEmpty,
              let pipePath = environment["LEDGERFORGE_CATEGORY_OWNER_DATA"], !pipePath.isEmpty else {
            throw XCTSkip("AUTHENTIC_BACKUP_QUALIFICATION_ROOT_AND_OWNER_FIFO_REQUIRED")
        }
        var stage = "owner payload"
        do {
            let payload = try readPayload(from: pipePath)
            try check(payload.formatVersion == 1 && !payload.sourceFacts.isEmpty, "Private owner payload is incomplete")
            let source = URL(fileURLWithPath: sourcePath).standardizedFileURL.resolvingSymlinksInPath()
            let root = URL(fileURLWithPath: outputPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
            try check(root.path != source.path && !root.path.hasPrefix(source.path + "/"), "Qualification destination overlaps its original backup")
            try BackupFiles.rejectGitDestination(root)
            stage = "isolated output directory"
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            stage = "authentic backup binding"
            let manifest = try BackupFiles.verifyPackage(source)
            let manifestDigest = try BackupFiles.hash(source.appendingPathComponent("manifest.json")).sha256
            try check(manifest.database.sha256 == payload.sourceBackupSHA256 && manifest.backupID.uuidString == payload.sourceBackupID,
                      "Selected backup does not match the independently recovered approval cohort")
            stage = "sealed source table and column inventory"
            let originalGraph = try sealedSourceGraph(source)
            let directory = root.appendingPathComponent("category-spending-qualification-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            _ = try BackupCompatibility.prepareCandidate(package: source, manifest: manifest,
                destination: directory.appendingPathComponent("current.sqlite"))
            let ledger = try Ledger(directory: directory, workspaceID: payload.workspaceID)
            defer { ledger.close() }
            stage = "populated authentic upgrade preservation"
            try check(try tableContentDigest(ledger.sqlite.database, tables: originalGraph.tables, excludeMigrationSequence: true) == originalGraph.digest,
                      "Schema upgrade changed preexisting source, financial, planning, holding or owner metadata content")
            stage = "immutable source graph binding"
            let sourceDigest = try immutableGraphDigest(ledger.sqlite.database)
            let facts = try ledger.provider.transactionRepo.trustedTransactions(workspaceId: payload.workspaceID)
            try verifySourceFacts(facts, payload)
            let existingInterpretations = try intelligence(ledger).movements
            stage = "actual Swift historical merchant matcher"
            try verifyMatcher(rules: payload.baselineRules, inputs: facts.map(CategoryRuleInput.init),
                              rawMatches: payload.baselineRawMatches, assigned: payload.baselineCategoryByID)
            stage = "source-qualified fee positives and negatives"
            try verifyCashAdvanceCases(runtime(ledger), payload)
            stage = "final portable Swift matcher"
            try verifyMatcher(rules: payload.rules, inputs: facts.map(CategoryRuleInput.init),
                              rawMatches: payload.expectedRawMatches, assigned: payload.expectedCategoryByID)
            stage = "ordinary category creation and rule save"
            try installConfiguration(ledger, payload, initial: true)
            let beforeApply = try automation(ledger)
            let beforeAssignments = try assignments(ledger)
            let preview = try evaluate(ledger, facts: facts)
            try check(try automation(ledger) == beforeApply && assignments(ledger) == beforeAssignments,
                      "Preview mutated category or spending metadata")
            try verifyPreview(preview, payload, initial: true)
            stage = "explicit historical preview apply"
            _ = try ledger.provider.categoryRepo.applyCategoryEvaluation(preview, workspaceId: payload.workspaceID, historical: true)
            try verifyAppliedConfiguration(ledger, payload, initial: true)
            stage = "versioned portable-rule refinement"
            try refinePortableConfiguration(ledger, payload)
            let finalPreview = try evaluate(ledger, facts: facts)
            try verifyPreview(finalPreview, payload)
            _ = try ledger.provider.categoryRepo.applyCategoryEvaluation(finalPreview, workspaceId: payload.workspaceID, historical: true)
            try verifyAppliedConfiguration(ledger, payload)
            stage = "finite approved historical choices"
            try installFiniteChoices(ledger, payload)
            stage = "approved fee spending metadata"
            try recognizeRefundPurchases(ledger, payload)
            let beforeRefunds = try projections(runtime(ledger))
            stage = "same identity expense to allocated refund edits"
            try installRefunds(ledger, payload)
            stage = "native exact refund projection and source dates"
            try verifyRefunds(runtime(ledger), payload, beforeRefunds: beforeRefunds)
            stage = "actual monthly native-currency money-flow graphs"
            let flowView = try runtime(ledger)
            let calendar = Calendar.current
            let currentMonth = try SelectedStatementMonth(year: calendar.component(.year, from: Date()),
                month: calendar.component(.month, from: Date()))
            let flowCoverage = try MoneyFlowAuthenticAssertions.check(rows: flowView.rows, metadata: flowView.metadata,
                sources: flowView.snapshot.financialSources, currentMonth: currentMonth) { month, currency in
                try projection(flowView, currency: currency, start: StatementDate(year: month.year, month: month.month, day: 1),
                    end: FinancialCalendar.lastDay(month))
            }
            // Shape names describe exercised contracts; no financial data is logged.
            record("MONEY_FLOW_OBSERVED_SHAPES=" + flowCoverage.map(\.rawValue).sorted().joined(separator: ","))
            record("MONEY_FLOW_UNOBSERVED_SHAPES=" + Set(MoneyFlowAuthenticAssertions.Shape.allCases).subtracting(flowCoverage).map(\.rawValue).sorted().joined(separator: ","))
            stage = "saved Monthly Plan consumer of approved spending and refunds"
            let planningCoverage = try PlanningConsumerAuthenticAssertions.check(
                snapshot: flowView.snapshot, rows: flowView.rows, metadata: flowView.metadata,
                spendingIntents: flowView.automation.spendingIntents,
                approvedAutomaticBankExpenseIDs: Set(payload.expectedAutomaticBankExpenseIDs),
                approvedRefunds: payload.refunds.map { refund in
                    .init(purchaseID: refund.purchaseID, currency: refund.currency,
                          purchaseMinor: refund.purchaseMinor,
                          allocations: refund.allocations.map {
                              .init(creditID: $0.creditID, minor: $0.minor,
                                    purchaseDate: $0.purchaseDate, creditDate: $0.creditDate)
                          })
                },
                approvedSalaryIDs: Set(payload.expectedSalaryIDs),
                independentlyExcludedLoanIDs: Set(payload.cashAdvanceCases.filter { $0.expectedTreatment == "outsideScope" }.map(\.transactionID)),
                sourcePostedDates: Dictionary(uniqueKeysWithValues: payload.sourceFacts.map { ($0.id, $0.postedDate) }),
                today: FinancialCalendar.statement(Date())!)
            record("MONTHLY_PLAN_OBSERVED_SHAPES=" + planningCoverage.map(\.rawValue).sorted().joined(separator: ","))
            record("MONTHLY_PLAN_UNOBSERVED_SHAPES=" + Set(PlanningConsumerAuthenticAssertions.Shape.allCases)
                .subtracting(planningCoverage).map(\.rawValue).sorted().joined(separator: ","))
            stage = "preserved prior owner interpretations"
            let afterInterpretations = try intelligence(ledger).movements
            let refundPurchases = Set(payload.refunds.map(\.purchaseID))
            for old in existingInterpretations where Set(old.transactionIDs).isDisjoint(with: refundPurchases) {
                try check(afterInterpretations.contains(old), "Configuration changed an unrelated existing owner interpretation")
            }
            let configuredAutomation = try automation(ledger)
            let configuredIntelligence = try intelligence(ledger)
            let configuredAssignments = try assignments(ledger)
            stage = "idempotent rule persistence"
            try installConfiguration(ledger, payload)
            try check(try automation(ledger) == configuredAutomation && intelligence(ledger) == configuredIntelligence,
                      "Re-saving the exact installed configuration changed historical metadata")
            stage = "source graph preservation"
            try check(try immutableGraphDigest(ledger.sqlite.database) == sourceDigest, "Owner metadata altered immutable financial or source records")
            stage = "reopen exact metadata"
            try ledger.reopen()
            try check(try automation(ledger) == configuredAutomation && intelligence(ledger) == configuredIntelligence &&
                      assignments(ledger) == configuredAssignments, "Reopen did not recover the exact configured metadata")
            try verifySourceFacts(try ledger.provider.transactionRepo.trustedTransactions(workspaceId: payload.workspaceID), payload)
            try verifyRefunds(runtime(ledger), payload, beforeRefunds: beforeRefunds)
            stage = "configured native backup and restore"
            let configuredBackup = try makeNativeBackup(ledger)
            let configuredManifest = try BackupFiles.verifyPackage(configuredBackup)
            let challengeDirectory = directory.appendingPathComponent("challenge-restore", isDirectory: true)
            try FileManager.default.createDirectory(at: challengeDirectory, withIntermediateDirectories: false)
            _ = try BackupCompatibility.prepareCandidate(package: configuredBackup, manifest: configuredManifest,
                destination: challengeDirectory.appendingPathComponent("current.sqlite"))
            let challenge = try Ledger(directory: challengeDirectory, workspaceID: payload.workspaceID)
            defer { challenge.close() }
            try check(try automation(challenge) == configuredAutomation && intelligence(challenge) == configuredIntelligence &&
                      assignments(challenge) == configuredAssignments, "Native backup restore changed configured metadata")
            try check(try immutableGraphDigest(challenge.sqlite.database) == sourceDigest, "Native restore changed preserved source records")
            stage = "manual choices suppression conflicts and stale apply"
            try await challengeAsyncCategoryOverride(challenge, payload)
            stage = "async historical apply and unchanged receipt updates"
            try await challengeAsyncCategoryApply(challenge, payload)
            try challengeCategoryControls(challenge, payload)
            stage = "authenticated preview reuse and durable proposal validation"
            try challengePreviewWitnessValidation(challenge, payload)
            try challengeProtectedInterpretation(challenge, payload)
            stage = "refund stale edits occupied legs and category attribution"
            try challengeRefundControls(challenge, payload)
            try challengeRefundSourceRejections(challenge, payload)
            try check(try immutableGraphDigest(challenge.sqlite.database) == sourceDigest, "Metadata challenge altered financial or source facts")
            stage = "ordinary authentic future import and provider parity"
            try await qualifyFutureImports(root: directory, payload: payload)
            stage = "selected original native backup preservation"
            try check(try BackupFiles.verifyPackage(source) == manifest &&
                      BackupFiles.hash(source.appendingPathComponent("manifest.json")).sha256 == manifestDigest,
                      "Qualification changed its selected original native backup")
            // Paths contain only test-owned artifact identifiers, never source row identities.
            record("AUTHENTIC_CATEGORY_QUALIFICATION_PASSED")
            record("QUALIFIED_DATABASE_PATH=" + ledger.path.path)
            record("QUALIFIED_NATIVE_BACKUP_PATH=" + configuredBackup.path)
        } catch let skipped as XCTSkip { throw skipped }
        catch let failure as Failure {
            if case .assertion(let reason) = failure { XCTFail(reason) }
        } catch let failure as PlanningConsumerAuthenticAssertions.Failure {
            if case .assertion(let reason) = failure { XCTFail(reason) }
        } catch let failure as MoneyFlowAuthenticAssertions.Failure {
            if case .assertion(let reason) = failure { XCTFail(reason) }
        } catch {
            // Repository errors may include source text: never print their value.
            let failure = error as NSError
            XCTFail("Authentic category qualification failed at \(stage); type=\(type(of: error)); domain=\(failure.domain); code=\(failure.code)")
        }
    }

    /// Native result activities retain only technical coverage names and owned
    /// database/backup paths; source facts and private configuration stay in RAM.
    private func record(_ technicalEvidence: String) {
        print(technicalEvidence)
        XCTContext.runActivity(named: technicalEvidence) { _ in }
    }

    private func readPayload(from path: String) throws -> Payload {
        var info = stat()
        try check(lstat(path, &info) == 0 && (info.st_mode & S_IFMT) == S_IFIFO, "Owner configuration must arrive through the task FIFO")
        let descriptor = open(path, O_RDONLY | O_NOFOLLOW)
        try check(descriptor >= 0, "Owner FIFO could not be opened")
        defer { close(descriptor) }
        try check(fstat(descriptor, &info) == 0 && (info.st_mode & S_IFMT) == S_IFIFO, "Owner transport handle is not a FIFO")
        var result = Data(), buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
            if count == 0 { break }
            try check(count > 0 && result.count + count <= 64 * 1024 * 1024, "Owner FIFO failed or exceeded its memory bound")
            result.append(contentsOf: buffer.prefix(count))
        }
        return try JSONDecoder().decode(Payload.self, from: result)
    }

    private func verifySourceFacts(_ facts: [TransactionDTO], _ payload: Payload) throws {
        let actual = Dictionary(uniqueKeysWithValues: facts.map { ($0.id, $0) })
        try check(actual.count == payload.sourceFacts.count, "Frozen canonical cohort membership changed")
        for expected in payload.sourceFacts {
            guard let fact = actual[expected.id] else { throw Failure.assertion("An approved source-bound canonical record is missing") }
            try check(expected.agrees(with: fact), "Canonical source identity, native Money, date or narration differs from the approval freeze")
            let money = try Money(canonicalDecimal: fact.amountDecimal, currency: fact.nativeCurrency)
            try check(try money.minorUnits() == fact.amountMinor, "Canonical native Money representations disagree")
        }
    }

    private func verifyMatcher(rules: [CategoryRule], inputs: [CategoryRuleInput], rawMatches: [String: [String]], assigned: [String: String]) throws {
        try check(Set(rules.map(\.id)).count == rules.count && Set(rawMatches.keys) == Set(rules.map(\.id)),
                  "Independent rule membership oracle is incomplete")
        for rule in rules {
            try rule.validate()
            let actual = Set(inputs.filter(rule.matches).map(\.transactionID))
            try check(actual == Set(rawMatches[rule.id] ?? []), "Actual Swift rule membership differs from the recovered independent oracle")
        }
        let evaluation = CategoryEvaluation.evaluate(inputs: inputs, snapshot: .init(rules: rules), assignments: [:],
            activeCategoryIDs: Set(rules.map(\.categoryID)))
        let actual = Dictionary(uniqueKeysWithValues: evaluation.decisions.compactMap { value in
            value.categoryID.map { (value.transactionID, $0) }
        })
        try check(actual == assigned && !evaluation.decisions.contains { $0.outcome == .conflict },
                  "Actual Swift complete-cohort category decisions differ from the independent oracle")
    }

    private func installConfiguration(_ ledger: Ledger, _ payload: Payload, initial: Bool = false) throws {
        let repository = ledger.provider.categoryRepo
        let storedCategories = Dictionary(uniqueKeysWithValues: try repository.categories(workspaceId: payload.workspaceID).map { ($0.id, $0) })
        for seed in payload.categories {
            let name = try CategoryName.validated(seed.name)
            if let existing = storedCategories[seed.id] {
                try check(existing.name == name.display && existing.normalizedName == name.normalized && !existing.isArchived,
                          "An existing owner category conflicts with the exact approved configuration")
            } else {
                _ = try repository.createCategory(.init(id: seed.id, workspaceId: payload.workspaceID,
                    name: name.display, normalizedName: name.normalized, createdAtISO: payload.reviewedAtISO))
            }
        }
        let storedRules = Dictionary(uniqueKeysWithValues: try automation(ledger).rules.map { ($0.id, $0) })
        for rule in initial ? payload.initialRules : payload.rules {
            if let existing = storedRules[rule.id] { try check(existing == rule, "An installed rule differs from the reviewed version") }
            else { try repository.saveRule(rule, previousVersion: nil) }
        }
        let previous = try intelligence(ledger).preferences
        var next = previous ?? IntelligencePreferences(workspaceID: payload.workspaceID)
        next.salaryRuleIDs.insert(payload.salaryRuleID)
        if next != previous { try ledger.provider.intelligenceRepo.applyPlanning(.preferences(next, replacing: previous)) }
    }

    private func refinePortableConfiguration(_ ledger: Ledger, _ payload: Payload) throws {
        let repository = ledger.provider.categoryRepo
        let before = try automation(ledger), beforeAssignments = try assignments(ledger)
        let existing = Dictionary(uniqueKeysWithValues: before.rules.map { ($0.id, $0) })
        let finalIDs = Set(payload.rules.map(\.id))
        for rule in payload.rules {
            guard let old = existing[rule.id] else { throw Failure.assertion("Portable refinement lost its exact prior approved rule") }
            if old != rule {
                try check(rule.version == old.version + 1, "Portable refinement omitted its explicit version transition")
                try repository.saveRule(rule, previousVersion: old.version)
            }
        }
        for old in before.rules where !finalIDs.contains(old.id) {
            try check(payload.initialRules.contains(old), "Portable refinement tried to retire an unrelated saved rule")
            try repository.deleteRule(id: old.id, workspaceId: ledger.workspaceID, version: old.version)
        }
        let after = try automation(ledger)
        try check(after.rules == payload.rules.sorted { $0.id < $1.id }, "Saved portable configuration differs from the reviewed rule versions")
        try check(after.intents == before.intents && after.spendingIntents == before.spendingIntents && after.work == before.work &&
                  assignments(ledger) == beforeAssignments, "Editing future portable rules rewrote historical metadata before explicit preview apply")
    }

    private func verifyPreview(_ evaluation: CategoryEvaluation, _ payload: Payload, initial: Bool = false) throws {
        let categories = Dictionary(uniqueKeysWithValues: evaluation.decisions.compactMap { value in
            value.categoryID.map { (value.transactionID, $0) }
        })
        let automatic = Set(evaluation.decisions.filter { $0.spending?.proposed?.kind == .automaticExpense }.map(\.transactionID))
        try check(categories == (initial ? payload.initialCategoryByID : payload.expectedCategoryByID), "Native historical preview differs from approved category membership")
        try check(automatic == Set(initial ? payload.initialAutomaticBankExpenseIDs : payload.expectedAutomaticBankExpenseIDs),
                  "Native preview bank-spending actions differ from source-qualified approval")
    }

    private func verifyAppliedConfiguration(_ ledger: Ledger, _ payload: Payload, initial: Bool = false) throws {
        let expectedAssignments = initial ? payload.initialCategoryByID : payload.expectedCategoryByID
        let expectedSpending = initial ? payload.initialAutomaticBankExpenseIDs : payload.expectedAutomaticBankExpenseIDs
        try check(try assignments(ledger) == expectedAssignments, "Category apply did not preserve exact approved membership")
        let state = try automation(ledger)
        try check(Set(state.spendingIntents.filter { $0.value.kind == .automaticExpense }.keys) == Set(expectedSpending),
                  "Category apply did not persist exact bank-spending membership")
        let view = try runtime(ledger)
        try check(Set(view.rows.filter(\.isRegularSalary).map(\.id)) == Set(payload.expectedSalaryIDs),
                  "Selected salary rule did not preserve its narrow approved account scope")
        try check(Set(view.rows.filter(\.isRegularSalary).map(\.id)).isDisjoint(with: payload.excludedClosedSalaryIDs),
                  "Closed-account salary history entered the selected current salary rule")
        let byID = Dictionary(uniqueKeysWithValues: view.resolved.map { ($0.id, $0) })
        for id in expectedSpending {
            try check(byID[id]?.treatment == .expense, "Approved automatic bank expense was absent from spending")
        }
    }

    private func installFiniteChoices(_ ledger: Ledger, _ payload: Payload) throws {
        for choice in payload.finiteChoices {
            _ = try ledger.provider.categoryRepo.setCategory(categoryId: choice.categoryID, transactionId: choice.transactionID, workspaceId: payload.workspaceID)
            try recognizeExpense(ledger, transactionID: choice.transactionID, reviewedAt: payload.reviewedAtISO)
        }
    }
    private func recognizeExpense(_ ledger: Ledger, transactionID: String, reviewedAt: String) throws {
        let existing = try intelligence(ledger).confirmedByTransaction[transactionID]
        if let existing {
            try check(existing.kind == .expense && existing.transactionIDs == [transactionID], "Approved spending overlaps an existing reviewed interpretation")
            return
        }
        let event = MovementEvent(id: MovementSuggestion.identity(.expense, ids: [transactionID]), workspaceID: ledger.workspaceID,
            kind: .expense, decision: .confirmed, transactionIDs: [transactionID],
            explanation: "Owner-approved finite historical spending.", reviewedAtISO: reviewedAt)
        try ledger.provider.intelligenceRepo.saveMovement(event, replacing: nil)
    }
    private func recognizeRefundPurchases(_ ledger: Ledger, _ payload: Payload) throws {
        for refund in payload.refunds where refund.requiresFeeRecognition {
            try recognizeExpense(ledger, transactionID: refund.purchaseID, reviewedAt: payload.reviewedAtISO)
        }
    }
    private func installRefunds(_ ledger: Ledger, _ payload: Payload) throws {
        for refund in payload.refunds {
            let metadata = try intelligence(ledger)
            let previous = metadata.confirmedByTransaction[refund.purchaseID]
            if let previous { try check(previous.kind == .expense || previous.kind == .refund, "Refund purchase overlaps a protected interpretation") }
            let ids = [refund.purchaseID] + refund.allocations.map(\.creditID)
            let allocations = try refund.allocations.map { value in
                MovementRefundAllocation(purchaseTransactionID: refund.purchaseID, creditTransactionID: value.creditID,
                    amount: try Money.fromMinorUnits(value.minor, currency: refund.currency))
            }
            let event = MovementEvent(id: previous?.id ?? MovementSuggestion.identity(.refund, ids: ids), workspaceID: payload.workspaceID,
                kind: .refund, decision: .confirmed, transactionIDs: ids.sorted(), explanation: "Owner-approved exact original-purchase refund allocation.",
                reviewedAtISO: payload.reviewedAtISO, refundAllocations: allocations)
            if previous != event { try ledger.provider.intelligenceRepo.saveMovement(event, replacing: previous) }
            if let previous, previous.kind == .expense {
                try expectMovementFailure(.staleReview) { try ledger.provider.intelligenceRepo.saveMovement(event, replacing: previous) }
                try check(try intelligence(ledger).movements.first { $0.id == event.id } == event,
                          "Stale expense-to-refund retry changed the accepted replacement")
            }
        }
    }

    private func verifyCashAdvanceCases(_ view: Runtime, _ payload: Payload) throws {
        let source = Dictionary(uniqueKeysWithValues: view.rows.map { ($0.id, $0) })
        let reviewed = Dictionary(uniqueKeysWithValues: view.resolved.map { ($0.id, $0) })
        try check(!payload.cashAdvanceCases.isEmpty && payload.cashAdvanceCases.contains { $0.expectedCashAdvanceFee } &&
                  payload.cashAdvanceCases.contains { !$0.expectedCashAdvanceFee }, "Authentic fee qualification requires observed positives and negatives")
        for value in payload.cashAdvanceCases {
            guard let row = source[value.transactionID], let result = reviewed[value.transactionID] else {
                throw Failure.assertion("Authentic cash-advance control disappeared from canonical hydration")
            }
            try check(row.isCashAdvanceFee == value.expectedCashAdvanceFee, "Source-qualified fee recognition differs from the authentic independent case oracle")
            try check(treatmentCode(result.treatment) == value.expectedTreatment, "Cash-advance principal, settlement, EMI or fee treatment changed incorrectly")
            let money = try Money(amount: result.spending, currency: row.currency)
            try check(try money.minorUnits() == value.expectedSpendingMinor, "Source-qualified fee spending differs from exact native expected Money")
        }
    }

    private func verifyRefunds(_ view: Runtime, _ payload: Payload, beforeRefunds: [String: SpendingProjection]) throws {
        let byID = Dictionary(uniqueKeysWithValues: view.resolved.map { ($0.id, $0) })
        let reports = try projections(view)
        var totals: [String: Int64] = [:]
        for refund in payload.refunds {
            guard let purchase = byID[refund.purchaseID], let amounts = purchase.amounts else { throw Failure.assertion("Refund purchase has no resolved spending amounts") }
            let allocationMinor = refund.allocations.reduce(Int64(0)) { $0 + $1.minor }
            totals[refund.currency, default: 0] += allocationMinor
            try check(purchase.treatment == .expense && amounts.gross.currency.code == refund.currency,
                      "Refund allocation changed purchase treatment or native currency")
            try check(try amounts.gross.minorUnits() == refund.purchaseMinor && amounts.allocatedRefund.minorUnits() == allocationMinor &&
                      amounts.net.minorUnits() == refund.purchaseMinor - allocationMinor, "Original purchase gross, allocated refund and net are not exact")
            try check(Set(purchase.refundDetails.map(\.creditTransactionID)) == Set(refund.allocations.map(\.creditID)),
                      "Purchase drill-down lost a supporting refund credit")
            for allocation in refund.allocations {
                guard let credit = byID[allocation.creditID], let detail = purchase.refundDetails.first(where: { $0.creditTransactionID == allocation.creditID }) else {
                    throw Failure.assertion("Refund credit or exact allocation detail is missing")
                }
                try check(credit.spending == 0 && credit.income == 0 && credit.treatment == .refund,
                          "A refund credit independently changed receipt-month spending or income")
                try check(try detail.allocated.minorUnits() == allocation.minor && detail.creditAmount.minorUnits() == allocation.creditMinor &&
                          detail.residual.minorUnits() == allocation.creditMinor - allocation.minor,
                          "Refund detail lost its allocation bound or native residual")
                try check(detail.purchaseDate?.canonical == allocation.purchaseDate && detail.creditDate?.canonical == allocation.creditDate &&
                          purchase.source.date?.canonical == allocation.purchaseDate && credit.source.date?.canonical == allocation.creditDate,
                          "Refund attribution moved or replaced a source transaction date")
                try check(reports[refund.currency]?.categories.allSatisfy { !$0.transactionIDs.contains(allocation.creditID) } == true,
                          "Refund credit created an independent category spending contribution")
            }
            if let date = purchase.source.date {
                let month = try SelectedStatementMonth(canonical: String(date.canonical.prefix(7)))
                let first = try StatementDate(year: month.year, month: month.month, day: 1)
                guard let last = FinancialCalendar.lastDay(month) else { throw Failure.assertion("Authentic purchase month cannot be resolved") }
                let report = try projection(view, currency: refund.currency, start: first, end: last)
                guard let selected = report.rows.first(where: { $0.id == refund.purchaseID }) else { throw Failure.assertion("Original purchase disappeared from its actual source month") }
                try check(selected.amounts == amounts && report.supportingTransactionIDs.isSuperset(of: refund.allocations.map(\.creditID)),
                          "Original-month report lost the exact refund or its out-of-period support")
            }
        }
        for (currency, minor) in totals {
            guard let before = beforeRefunds[currency], let after = reports[currency] else { throw Failure.assertion("Native-currency refund report is missing") }
            let allocated = try Money.fromMinorUnits(minor, currency: currency)
            try check(after.amounts.gross == before.amounts.gross && after.amounts.net == (try before.amounts.net - allocated) &&
                      after.amounts.allocatedRefund == (try before.amounts.allocatedRefund + allocated),
                      "Whole-history native spending did not deduct approved refunds exactly once")
        }
    }


    /// The ordinary async owner action is exercised against the entire selected
    /// authentic graph. Only deliberate category choices and reversible workspace
    /// metadata are edited; failure messages contain no source values or IDs.
    private func challengeAsyncCategoryOverride(_ ledger: Ledger, _ payload: Payload) async throws {
        let provider = ledger.provider, workspace = ledger.workspaceID
        let initial = try automation(ledger), assigned = try assignments(ledger)
        guard let transactionID = payload.expectedAutomaticBankExpenseIDs.first(where: { initial.intents[$0]?.kind == .automatic }),
              let alternate = payload.categories.first(where: { $0.id != assigned[transactionID] }),
              let originalWorkspace = try provider.workspaceRepo.workspace(id: workspace) else {
            throw Failure.assertion("Authentic async category override control is unavailable")
        }
        let sourceBefore = try immutableGraphDigest(ledger.sqlite.database)
        let store = CategoryStore(), gate = CategoryReconciliationGate()
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, categoryStore: store,
            workspaceId: workspace, categoryReconciliationGate: gate, participatesInLifecycleGate: false)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        guard let initialWitness = store.sourceWitness, !initialWitness.isCompact else {
            throw Failure.assertion("Canonical hydration did not retain its exact pending source cut")
        }
        let intelligenceRevision = FinancialIntelligenceStore.shared.revision
        let intelligenceBefore = FinancialIntelligenceStore.shared.snapshot
        var fullRefreshes = 0, allowFullRetry = false, categoryNotifications = 0, financialNotifications = 0
        let categorySubscription = store.$snapshot.dropFirst().sink { _ in categoryNotifications += 1 }
        let financialSubscription = TransactionStore.shared.$transactions.dropFirst().sink { _ in financialNotifications += 1 }
        defer { categorySubscription.cancel(); financialSubscription.cancel() }
        let coordinator = CategoryManagementCoordinator(provider: { provider }, workspaceID: workspace, categoryStore: store,
            reconciliationGate: gate, forcedHydration: { provider, categoryStore, workspaceID in
                fullRefreshes += 1
                guard allowFullRetry else { throw Failure.assertion("Unrequested full category refresh") }
                return try RepositoryStoreHydrator(databaseProvider: provider, categoryStore: categoryStore,
                    workspaceId: workspaceID, categoryReconciliationGate: gate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            })
        let firstRevision = store.revision
        let changed = try await coordinator.setCategory(categoryID: alternate.id, transactionID: transactionID)
        try check(changed && fullRefreshes == 0 && store.revision != firstRevision &&
                  store.sourceWitness == initialWitness && store.sourceWitness?.isCompact == true,
                  "Current override did not use and compact its canonical source witness")
        let ordinary = try runtime(ledger).snapshot.categorySnapshot
        try check(store.snapshot == ordinary && store.snapshot.automation?.spendingIntents == initial.spendingIntents &&
                  store.snapshot.automation?.pendingIDs == ordinary.automation?.pendingIDs,
                  "Async category publication differs from the complete ordinary category oracle")
        try check(store.snapshot.automation?.intents[transactionID]?.kind == .manual &&
                  store.snapshot.assignments[transactionID] == alternate.id && categoryNotifications == 1 && financialNotifications == 0 &&
                  FinancialIntelligenceStore.shared.revision == intelligenceRevision && FinancialIntelligenceStore.shared.snapshot == intelligenceBefore,
                  "Category override changed independent financial runtime or missed its coherent publication")
        let unchangedRevision = store.revision, unchangedCounter = try ledger.sqlite.database.totalChangeCounter()
        let unchanged = try await coordinator.setCategory(categoryID: alternate.id, transactionID: transactionID)
        let repeatedCounter = try ledger.sqlite.database.totalChangeCounter()
        try check(!unchanged && store.revision == unchangedRevision && categoryNotifications == 1 &&
                  repeatedCounter == unchangedCounter,
                  "A repeated manual choice wrote or published again")
        let cleared = try await coordinator.setCategory(categoryID: nil, transactionID: transactionID)
        try check(cleared && fullRefreshes == 0 && store.snapshot.assignments[transactionID] == nil &&
                  store.snapshot.automation?.intents[transactionID]?.kind == .deliberatelyCleared &&
                  store.snapshot.automation?.spendingIntents == initial.spendingIntents && financialNotifications == 0,
                  "Async deliberate clear erased independent spending history or used full hydration")

        let previous = store.snapshot, previousRevision = store.revision, previousWitness = store.sourceWitness
        let notificationsBeforeFailure = categoryNotifications
        var workspaceChanged = false
        defer { if workspaceChanged { _ = try? provider.workspaceRepo.upsertWorkspace(originalWorkspace) } }
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: originalWorkspace.id,
            name: originalWorkspace.name + " (qualification)", createdAtISO: originalWorkspace.createdAtISO,
            updatedAtISO: originalWorkspace.updatedAtISO))
        workspaceChanged = true
        do {
            _ = try await coordinator.setCategory(categoryID: alternate.id, transactionID: transactionID)
            throw Failure.assertion("Changed retained source basis did not reject partial publication")
        } catch CategoryManagementCoordinatorError.savedButRefreshFailed { }
        let durable = try automation(ledger), savedCounter = try ledger.sqlite.database.totalChangeCounter()
        try check(durable.intents[transactionID]?.kind == .manual && durable.intents[transactionID]?.categoryID == alternate.id &&
                  store.snapshot == previous && store.revision == previousRevision && store.sourceWitness == previousWitness &&
                  categoryNotifications == notificationsBeforeFailure && gate.isBlocked(for: provider.generationToken) && fullRefreshes == 0,
                  "Saved source-mismatch failure altered runtime or failed to retain the one durable category write")
        try check(try coordinator.retryCanonicalHydration() == .failed && automation(ledger) == durable &&
                  ledger.sqlite.database.totalChangeCounter() == savedCounter,
                  "Failed full retry rewrote a saved category mutation")
        _ = try provider.workspaceRepo.upsertWorkspace(originalWorkspace); workspaceChanged = false
        let retryCounter = try ledger.sqlite.database.totalChangeCounter()
        allowFullRetry = true
        try check(try coordinator.retryCanonicalHydration() == .succeeded && !gate.isBlocked(for: provider.generationToken) &&
                  automation(ledger) == durable && ledger.sqlite.database.totalChangeCounter() == retryCounter,
                  "Full retry repeated the category write or failed to reconcile its saved result")
        let sourceAfter = try immutableGraphDigest(ledger.sqlite.database)
        try check(store.snapshot.automation == durable && store.snapshot.assignments[transactionID] == alternate.id &&
                  store.sourceWitness != previousWitness && store.sourceWitness?.isCompact == false &&
                  sourceAfter == sourceBefore,
                  "Full retry failed to replace its complete canonical cut or changed retained source records")
    }

    /// The configured authentic ledger supplies every selected input. The
    /// formerly blocking changed-Apply path includes an explanation-only receipt
    /// update even when the historical preview labels its financial effects unchanged.
    private func challengeAsyncCategoryApply(_ ledger: Ledger, _ payload: Payload) async throws {
        let provider = ledger.provider, repo = provider.categoryRepo, workspace = ledger.workspaceID
        let initial = try automation(ledger), originalAssignments = try assignments(ledger)
        let refundIDs = Set(payload.refunds.flatMap { [$0.purchaseID] + $0.allocations.map(\.creditID) })
        guard let id = payload.expectedAutomaticBankExpenseIDs.first(where: { !refundIDs.contains($0) }),
              initial.spendingIntents[id]?.kind == .automaticExpense,
              initial.spendingContexts[id]?.sourceEligible == true, initial.spendingContexts[id]?.protectsInterpretation == false,
              let originalSpending = initial.spendingIntents[id],
              let alternate = payload.categories.first(where: { $0.id != originalAssignments[id] }) else {
            throw Failure.assertion("Authentic async Apply control is unavailable")
        }
        let sourceBefore = try immutableGraphDigest(ledger.sqlite.database)
        let store = CategoryStore(), gate = CategoryReconciliationGate()
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, categoryStore: store,
            workspaceId: workspace, categoryReconciliationGate: gate, participatesInLifecycleGate: false)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        var fullRefreshes = 0, allowFullRetry = false
        let coordinator = CategoryManagementCoordinator(provider: { provider }, workspaceID: workspace, categoryStore: store,
            reconciliationGate: gate, forcedHydration: { provider, categoryStore, workspaceID in
                fullRefreshes += 1
                guard allowFullRetry else { throw Failure.assertion("Unrequested full Apply refresh") }
                return try RepositoryStoreHydrator(databaseProvider: provider, categoryStore: categoryStore,
                    workspaceId: workspaceID, categoryReconciliationGate: gate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            })
        _ = try await coordinator.setCategory(categoryID: nil, transactionID: id)
        let beforeReceipt = try automation(ledger), beforeAssignments = try assignments(ledger)
        let receiptEvaluation = try evaluate(ledger, ids: [id])
        guard let decision = receiptEvaluation.decisions.first, let previousWork = beforeReceipt.work[id] else {
            throw Failure.assertion("Authentic Apply receipt control has no reviewed work")
        }
        let preview = CategoryHistoricalPreview(evaluation: receiptEvaluation, assignments: beforeAssignments,
            intents: beforeReceipt.intents, spendingIntents: beforeReceipt.spendingIntents, spendingContexts: beforeReceipt.spendingContexts)
        let explanation = [decision.explanation, decision.spending?.explanation].compactMap { $0 }.joined(separator: " ")
        try check(decision.outcome == .protected && preview.isUnchanged(decision) &&
                  (previousWork.outcome != decision.outcome || previousWork.explanation != explanation),
                  "The unchanged preview does not exercise a real receipt update")
        let beforeRevision = store.revision, beforeWitness = store.sourceWitness
        let intelligenceRevision = FinancialIntelligenceStore.shared.revision
        let intelligenceBefore = FinancialIntelligenceStore.shared.snapshot
        let changed = try await coordinator.applyEvaluation(receiptEvaluation, historical: true, expectedGeneration: provider.generationToken)
        let afterReceipt = try automation(ledger)
        let canonicalReceiptSnapshot = try runtime(ledger).snapshot.categorySnapshot
        try check(changed && fullRefreshes == 0 && store.revision != beforeRevision && store.sourceWitness == beforeWitness &&
                  store.sourceWitness?.isCompact == true && store.snapshot == canonicalReceiptSnapshot,
                  "Changed Apply did not publish complete fresh metadata through its existing source witness")
        try check(try assignments(ledger) == beforeAssignments && afterReceipt.intents == beforeReceipt.intents &&
                  afterReceipt.spendingIntents == beforeReceipt.spendingIntents && afterReceipt.work[id]?.outcome == decision.outcome &&
                  afterReceipt.work[id]?.explanation == explanation && afterReceipt.work[id]?.origin == previousWork.origin &&
                  afterReceipt.work.filter { $0.key != id } == beforeReceipt.work.filter { $0.key != id },
                  "Receipt-only Apply changed an independent assignment, intent or work item")
        try check(FinancialIntelligenceStore.shared.revision == intelligenceRevision &&
                  FinancialIntelligenceStore.shared.snapshot == intelligenceBefore,
                  "Receipt-only Apply republished financial runtime")
        let noOpCounter = try ledger.sqlite.database.totalChangeCounter(), noOpRevision = store.revision
        let repeated = try await coordinator.applyEvaluation(receiptEvaluation, historical: true, expectedGeneration: provider.generationToken)
        let automaticRetry = try await coordinator.applyEvaluation(receiptEvaluation, historical: false, expectedGeneration: provider.generationToken)
        try check(try !repeated && !automaticRetry && fullRefreshes == 0 && store.revision == noOpRevision &&
                  ledger.sqlite.database.totalChangeCounter() == noOpCounter && automation(ledger) == afterReceipt,
                  "A completed Apply receipt was written or published again")

        // Existing owner metadata operations make the authentic expense action
        // available again; no financial row, source or rule is replaced.
        _ = try repo.setSpendingSuppressed(true, transactionID: id, workspaceId: workspace, expected: originalSpending)
        let suppressed = try automation(ledger).spendingIntents[id]
        _ = try repo.setSpendingSuppressed(false, transactionID: id, workspaceId: workspace, expected: suppressed)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let spendingEvaluation = try evaluate(ledger, ids: [id])
        try check(spendingEvaluation.decisions.first?.spending?.changesIntent == true &&
                  spendingEvaluation.decisions.first?.spending?.proposed == originalSpending,
                  "Authentic Apply does not contain its independent reviewed spending update")
        let spendingRevision = store.revision, spendingIntelligenceRevision = FinancialIntelligenceStore.shared.revision
        let spendingChanged = try await coordinator.applyEvaluation(spendingEvaluation, historical: true, expectedGeneration: provider.generationToken)
        let canonicalSpendingSnapshot = try runtime(ledger).snapshot.categorySnapshot
        try check(spendingChanged && fullRefreshes == 0 && store.revision != spendingRevision &&
                  store.snapshot.automation?.intents[id]?.kind == .deliberatelyCleared && store.snapshot.assignments[id] == nil &&
                  store.snapshot.automation?.spendingIntents[id] == originalSpending &&
                  store.snapshot == canonicalSpendingSnapshot &&
                  FinancialIntelligenceStore.shared.revision == spendingIntelligenceRevision,
                  "Async Apply lost independent spending intent, manual clear or coherent category publication")
        try check(try resolved(ledger, id: id).treatment == .expense,
                  "The refreshed authentic spending action did not reach resolved spending")

        // Keep the historical/custom fallback's committed-failure recovery
        // explicit. This clears only the runtime optimization witness; the real
        // canonical snapshot and durable authentic source remain intact.
        _ = try repo.setCategory(categoryId: alternate.id, transactionId: id, workspaceId: workspace)
        _ = try repo.setCategory(categoryId: nil, transactionId: id, workspaceId: workspace)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        store.replaceSnapshot(store.snapshot)
        let previous = store.snapshot, previousRevision = store.revision
        let fallbackEvaluation = try evaluate(ledger, ids: [id])
        do {
            _ = try await coordinator.applyEvaluation(fallbackEvaluation, historical: true, expectedGeneration: provider.generationToken)
            throw Failure.assertion("Committed Apply did not expose its failed canonical refresh")
        } catch CategoryManagementCoordinatorError.savedButRefreshFailed { }
        let saved = try automation(ledger), savedCounter = try ledger.sqlite.database.totalChangeCounter()
        try check(store.snapshot == previous && store.revision == previousRevision && store.sourceWitness == nil &&
                  gate.isBlocked(for: provider.generationToken) && fullRefreshes == 1 && saved.work[id] != previous.automation?.work[id],
                  "Saved Apply failure republished runtime or lost its committed receipt")
        try check(try coordinator.retryCanonicalHydration() == .failed && automation(ledger) == saved &&
                  ledger.sqlite.database.totalChangeCounter() == savedCounter,
                  "Failed Apply recovery repeated a metadata write")
        allowFullRetry = true
        try check(try coordinator.retryCanonicalHydration() == .succeeded && !gate.isBlocked(for: provider.generationToken) &&
                  store.snapshot.automation == saved && automation(ledger) == saved && ledger.sqlite.database.totalChangeCounter() == savedCounter,
                  "Canonical Apply retry did not reconcile exactly the saved metadata")
        try check(try immutableGraphDigest(ledger.sqlite.database) == sourceBefore,
                  "Async Apply controls changed retained source or financial records")
        record("CATEGORY_ASYNC_APPLY_CONTROLS=receipt_only_change,complete_publication,true_noop,pending_skip,spending_independence,manual_clear,legacy_saved_failure,full_retry_without_rewrite")
    }

    private func challengeCategoryControls(_ ledger: Ledger, _ payload: Payload) throws {
        let refundIDs = Set(payload.refunds.flatMap { [$0.purchaseID] + $0.allocations.map(\.creditID) })
        let candidates = payload.expectedAutomaticBankExpenseIDs.filter { !refundIDs.contains($0) }
        guard candidates.count >= 2, let first = candidates.first, let second = candidates.dropFirst().first else {
            throw Failure.assertion("Authentic bank-spending controls do not have independent observed members")
        }
        let repo = ledger.provider.categoryRepo, workspace = payload.workspaceID
        let originalIntent = try automation(ledger).spendingIntents[first]
        _ = try repo.setCategory(categoryId: nil, transactionId: first, workspaceId: workspace)
        try check(try automation(ledger).intents[first]?.kind == .deliberatelyCleared && automation(ledger).spendingIntents[first] == originalIntent,
                  "Manual category clear erased independent historical spending intent")
        try check(try resolved(ledger, id: first).treatment == .expense, "Manual category clear erased approved spending")
        _ = try repo.applyCategoryEvaluation(evaluate(ledger, ids: [first]), workspaceId: workspace, historical: true)
        try check(try assignments(ledger)[first] == nil && resolved(ledger, id: first).treatment == .expense,
                  "Rule retry overrode deliberate category clear or lost spending")
        _ = try repo.setSpendingSuppressed(true, transactionID: first, workspaceId: workspace, expected: originalIntent)
        let suppressed = try automation(ledger).spendingIntents[first]
        _ = try repo.applyCategoryEvaluation(evaluate(ledger, ids: [first]), workspaceId: workspace, historical: true)
        try check(try automation(ledger).spendingIntents[first] == suppressed && resolved(ledger, id: first).treatment == .unresolved,
                  "Automatic rule retry overrode explicit spending suppression")
        _ = try repo.setSpendingSuppressed(false, transactionID: first, workspaceId: workspace, expected: suppressed)
        _ = try repo.applyCategoryEvaluation(evaluate(ledger, ids: [first]), workspaceId: workspace, historical: true)
        try check(try resolved(ledger, id: first).treatment == .expense, "Explicit suppression reset could not reapply reviewed spending")
        let input = try selectedFact(ledger, id: first)
        let matchingRules = try automation(ledger).rules.filter { $0.bankExpenseAction == .expense && $0.matches(CategoryRuleInput(transaction: input)) }
        try check(!matchingRules.isEmpty, "Authentic spending rule challenge has no actual match")
        for var rule in matchingRules { let old = rule.version; rule.version += 1; rule.isEnabled = false; try repo.saveRule(rule, previousVersion: old) }
        try check(try resolved(ledger, id: first).treatment == .expense, "Disabling future rules rewrote historical spending before explicit apply")
        let removal = try evaluate(ledger, ids: [first])
        try check(removal.decisions.first?.spending?.removesIntent == true, "History preview omitted removal of automatic spending")
        _ = try repo.applyCategoryEvaluation(removal, workspaceId: workspace, historical: true)
        try check(try resolved(ledger, id: first).treatment == .unresolved, "Explicit history apply did not remove obsolete automatic spending")
        for var rule in matchingRules { rule.version += 2; rule.isEnabled = true; try repo.saveRule(rule, previousVersion: rule.version - 1) }
        _ = try repo.applyCategoryEvaluation(evaluate(ledger, ids: [first]), workspaceId: workspace, historical: true)

        let actual = try selectedFact(ledger, id: second)
        guard let oldCategory = try assignments(ledger)[second], let alternate = payload.categories.first(where: { $0.id != oldCategory }),
              let narration = actual.description, !narration.isEmpty else { throw Failure.assertion("Authentic category-conflict control is unavailable") }
        let conflict = CategoryRule(id: "qualification-conflict-" + UUID().uuidString, workspaceID: workspace,
            name: "Qualification of explicit metadata conflict", version: 1, isEnabled: true, categoryID: alternate.id,
            accountID: actual.accountId, currency: actual.nativeCurrency, direction: actual.direction,
            predicates: [.init(field: .narration, match: .exact, text: narration)])
        try repo.saveRule(conflict, previousVersion: nil)
        let preview = try evaluate(ledger, ids: [second])
        try check(preview.decisions.first?.outcome == .conflict && preview.decisions.first?.spending?.proposed?.kind == .automaticExpense,
                  "Category conflict incorrectly suppressed independent spending intent")
        let expected = try automation(ledger).spendingIntents[second]
        _ = try repo.setSpendingSuppressed(true, transactionID: second, workspaceId: workspace, expected: expected)
        let beforeStale = try automation(ledger), beforeAssignments = try assignments(ledger)
        try expectCategoryStale { _ = try repo.applyCategoryEvaluation(preview, workspaceId: workspace, historical: true) }
        try check(try automation(ledger) == beforeStale && assignments(ledger) == beforeAssignments,
                  "Stale financial preview left accepted metadata residue")
        _ = try repo.setSpendingSuppressed(false, transactionID: second, workspaceId: workspace, expected: beforeStale.spendingIntents[second])
        _ = try repo.applyCategoryEvaluation(evaluate(ledger, ids: [second]), workspaceId: workspace, historical: true)
        try check(try assignments(ledger)[second] == nil && automation(ledger).work[second]?.outcome == .conflict &&
                  resolved(ledger, id: second).treatment == .expense, "Conflict handling invented a category or lost source-qualified spending")
        _ = try repo.setCategory(categoryId: alternate.id, transactionId: second, workspaceId: workspace)
        _ = try repo.applyCategoryEvaluation(evaluate(ledger, ids: [second]), workspaceId: workspace, historical: true)
        try check(try assignments(ledger)[second] == alternate.id && automation(ledger).intents[second]?.kind == .manual,
                  "Automatic history retry overrode an explicit manual category choice")
    }


    /// Genuine stored transactions exercise both evaluator-minted reuse and the
    /// ordinary unbound fallback. Only controlled owner metadata is changed,
    /// inside the restored challenge ledger; all source records remain intact.
    private func challengePreviewWitnessValidation(_ ledger: Ledger, _ payload: Payload) throws {
        let repo = ledger.provider.categoryRepo, workspace = ledger.workspaceID
        let refundIDs = Set(payload.refunds.flatMap { [$0.purchaseID] + $0.allocations.map(\.creditID) })
        let initial = try automation(ledger)
        let eligible = Set(payload.expectedAutomaticBankExpenseIDs.filter {
            !refundIDs.contains($0) && initial.intents[$0]?.kind == .automatic &&
            initial.spendingIntents[$0]?.kind == .automaticExpense &&
            initial.spendingContexts[$0]?.sourceEligible == true &&
            initial.spendingContexts[$0]?.protectsInterpretation == false
        })
        let selections = try evaluate(ledger, ids: eligible).decisions.filter {
            $0.outcome == .assigned && $0.categoryID != nil && $0.spending?.proposed?.kind == .automaticExpense
        }.map(\.transactionID).sorted()
        guard selections.count >= 3 else { throw Failure.assertion("Authentic preview controls lack independent approved bank members") }
        let first = selections[0], manualID = selections[1], contextID = selections[2]
        let genuine = try selectedFact(ledger, id: first)
        let input = CategoryRuleInput(transaction: genuine)
        func resetSpendingForExplicitApply() throws {
            let expected = try automation(ledger).spendingIntents[first]
            _ = try repo.setSpendingSuppressed(true, transactionID: first, workspaceId: workspace, expected: expected)
            let suppressed = try automation(ledger).spendingIntents[first]
            _ = try repo.setSpendingSuppressed(false, transactionID: first, workspaceId: workspace, expected: suppressed)
            try check(try automation(ledger).spendingIntents[first] == nil,
                      "Ordinary owner reset did not make the genuine expense action available for explicit Apply")
        }
        func plain(_ value: CategoryEvaluation, decisions: [CategoryEvaluation.Decision]? = nil) -> CategoryEvaluation {
            CategoryEvaluation(rules: value.rules, activeCategoryIDs: value.activeCategoryIDs, decisions: decisions ?? value.decisions)
        }
        func durableChangeCount() throws -> Int64 {
            try ledger.sqlite.database.query(sql: "SELECT total_changes();") { $0.int64(at: 0) ?? 0 }.first ?? 0
        }
        func rejectWithoutResidue(_ value: CategoryEvaluation) throws {
            let before = try automation(ledger), beforeAssignments = try assignments(ledger), beforeMeanings = try intelligence(ledger)
            try expectCategoryStale { _ = try repo.applyCategoryEvaluation(value, workspaceId: workspace, historical: true) }
            try check(try automation(ledger) == before && assignments(ledger) == beforeAssignments && intelligence(ledger) == beforeMeanings,
                      "Rejected preview proposal left durable category, spending, work or interpretation residue")
        }

        try resetSpendingForExplicitApply()
        let bound = try evaluate(ledger, ids: [first])
        let boundState = try automation(ledger), boundAssignments = try assignments(ledger)
        let lookup = try bound.validatedDecisionLookup(rules: boundState.rules, activeCategoryIDs: bound.activeCategoryIDs)
        try check(lookup(input, boundState, boundAssignments[first]) == bound.decisions.first,
                  "Evaluator-minted preview did not bind to its exact genuine current transaction and owner metadata")
        let unbound = plain(bound)
        let unboundLookup = try unbound.validatedDecisionLookup(rules: boundState.rules, activeCategoryIDs: bound.activeCategoryIDs)
        try check(unbound == bound && unboundLookup(input, boundState, boundAssignments[first]) == nil,
                  "Public decision values acquired reusable evaluator authority through the ordinary initializer")
        _ = try repo.applyCategoryEvaluation(bound, workspaceId: workspace, historical: true)
        let afterBound = try automation(ledger), assignmentsAfterBound = try assignments(ledger)
        try check(afterBound.spendingIntents[first]?.kind == .automaticExpense &&
                  assignmentsAfterBound[first] == bound.decisions.first?.categoryID,
                  "Bound Apply did not persist the genuine reviewed category and spending action")
        let writesBeforeBoundRepeat = try durableChangeCount()
        try check(try repo.applyCategoryEvaluation(evaluate(ledger, ids: [first]), workspaceId: workspace, historical: true) == 0,
                  "Fresh repeated bound Apply reported a metadata change")
        try check(try automation(ledger) == afterBound && assignments(ledger) == assignmentsAfterBound,
                  "Fresh repeated bound Apply changed already accepted metadata")
        try check(try durableChangeCount() == writesBeforeBoundRepeat, "Fresh repeated bound Apply issued redundant durable writes")

        try resetSpendingForExplicitApply()
        let fallback = plain(try evaluate(ledger, ids: [first]))
        _ = try repo.applyCategoryEvaluation(fallback, workspaceId: workspace, historical: true)
        try check(try automation(ledger) == afterBound && assignments(ledger) == assignmentsAfterBound,
                  "Unbound durable revalidation differs from evaluator-bound Apply over the same genuine approval")
        let writesBeforeUnboundRepeat = try durableChangeCount()
        try check(try repo.applyCategoryEvaluation(plain(try evaluate(ledger, ids: [first])), workspaceId: workspace, historical: true) == 0,
                  "Fresh repeated unbound Apply reported a metadata change")
        try check(try automation(ledger) == afterBound && assignments(ledger) == assignmentsAfterBound,
                  "Fresh repeated unbound Apply changed already accepted metadata")
        try check(try durableChangeCount() == writesBeforeUnboundRepeat, "Fresh repeated unbound Apply issued redundant durable writes")

        let honest = try evaluate(ledger, ids: [first])
        guard let decision = honest.decisions.first,
              let alternate = payload.categories.first(where: { $0.id != decision.categoryID }) else {
            throw Failure.assertion("Authentic category proposal has no distinct active owner category")
        }
        let forgedCategory = CategoryEvaluation.Decision(transactionID: first, categoryID: alternate.id,
            outcome: .assigned, matches: decision.matches, explanation: decision.explanation, spending: decision.spending)
        try rejectWithoutResidue(plain(honest, decisions: [forgedCategory]))

        // The independent exclusion set contains both card and bank sources.
        // Bank-only context validation must use its genuine bank-debit member;
        // select by canonical source fields, never by production eligibility.
        let bankAccountIDs = Set(try ledger.provider.accountRepo.accounts(workspaceId: workspace)
            .filter { $0.accountType == "bank" }.map(\.id))
        let frozenFacts = Dictionary(uniqueKeysWithValues: payload.sourceFacts.map { ($0.id, $0) })
        guard let loanID = payload.cashAdvanceCases.first(where: { candidate in
            guard candidate.expectedTreatment == "outsideScope", let fact = frozenFacts[candidate.transactionID],
                  let accountID = fact.accountID else { return false }
            return bankAccountIDs.contains(accountID) && fact.direction == "debit" && fact.amountMinor < 0
        })?.transactionID, let genuineExpense = try automation(ledger).spendingIntents[first] else {
            throw Failure.assertion("Independent real bank-loan control or approved expense evidence is unavailable")
        }
        let currentLoanFact = try selectedFact(ledger, id: loanID)
        try check(frozenFacts[loanID]?.agrees(with: currentLoanFact) == true,
                  "Selected bank-loan control differs from its independently frozen canonical source fact")
        let loanReview = try evaluate(ledger, ids: [loanID])
        guard let loanDecision = loanReview.decisions.first, let originalSpending = loanDecision.spending,
              originalSpending.context?.sourceEligible == false,
              originalSpending.expected?.kind != .automaticExpense,
              originalSpending.proposed?.kind != .automaticExpense else {
            throw Failure.assertion("Independent authentic bank loan acquired automatic spending eligibility or intent")
        }
        try check(try resolved(ledger, id: loanID).treatment == .outsideScope,
                  "Genuine bank-loan treatment differs from its independent outside-scope oracle")
        let forgedSpending = CategoryEvaluation.SpendingDecision(expected: originalSpending.expected,
            proposed: genuineExpense, context: originalSpending.context, explanation: originalSpending.explanation)
        let forgedLoan = CategoryEvaluation.Decision(transactionID: loanID, categoryID: loanDecision.categoryID,
            outcome: loanDecision.outcome, matches: loanDecision.matches, explanation: loanDecision.explanation, spending: forgedSpending)
        try rejectWithoutResidue(plain(loanReview, decisions: [forgedLoan]))

        let duplicateState = try automation(ledger), duplicateAssignments = try assignments(ledger)
        let repeatedInput = CategoryEvaluation.evaluate(inputs: [input, input], snapshot: duplicateState,
            assignments: duplicateAssignments, activeCategoryIDs: honest.activeCategoryIDs)
        try rejectWithoutResidue(repeatedInput)
        try rejectWithoutResidue(plain(honest, decisions: [decision, decision]))

        // Reusing a genuine preview cannot overrule a newer deliberate category
        // choice. Existing stale-spending tests retain their rollback coverage.
        let beforeManual = try evaluate(ledger, ids: [manualID])
        let spendingBeforeManual = try automation(ledger).spendingIntents
        _ = try repo.setCategory(categoryId: nil, transactionId: manualID, workspaceId: workspace)
        _ = try repo.applyCategoryEvaluation(beforeManual, workspaceId: workspace, historical: true)
        try check(try assignments(ledger)[manualID] == nil && automation(ledger).intents[manualID]?.kind == .deliberatelyCleared &&
                  automation(ledger).spendingIntents == spendingBeforeManual,
                  "Cached preview overrode a newer deliberate category clear or altered independent spending")
        _ = try repo.setCategory(categoryId: alternate.id, transactionId: manualID, workspaceId: workspace)
        _ = try repo.applyCategoryEvaluation(beforeManual, workspaceId: workspace, historical: true)
        try check(try assignments(ledger)[manualID] == alternate.id && automation(ledger).intents[manualID]?.kind == .manual &&
                  automation(ledger).spendingIntents == spendingBeforeManual,
                  "Cached preview overrode a newer manual category or altered independent spending")

        // A same-purpose owner confirmation changes the protected context even
        // though no transaction fact, amount, category or spending intent moves.
        let beforeContext = try evaluate(ledger, ids: [contextID])
        let confirmation = MovementEvent(id: "qualification-preview-context-" + UUID().uuidString,
            workspaceID: workspace, kind: .expense, decision: .confirmed, transactionIDs: [contextID],
            explanation: "Qualification of a newer owner confirmation over an already approved genuine expense.",
            reviewedAtISO: payload.reviewedAtISO)
        try ledger.provider.intelligenceRepo.saveMovement(confirmation, replacing: nil)
        try rejectWithoutResidue(beforeContext)
        let protectedReview = try evaluate(ledger, ids: [contextID])
        var revisedConfirmation = confirmation
        revisedConfirmation.explanation = "Qualification of a revised owner note without changing the genuine expense meaning."
        try ledger.provider.intelligenceRepo.saveMovement(revisedConfirmation, replacing: confirmation)
        try rejectWithoutResidue(protectedReview)
        try check(try intelligence(ledger).confirmedByTransaction[contextID] == revisedConfirmation &&
                  resolved(ledger, id: contextID).treatment == .expense,
                  "Rejected stale preview damaged the newer confirmed expense interpretation")
        record("CATEGORY_PREVIEW_VALIDATION_CONTROLS=bound_reuse,unbound_parity,idempotence,altered_category,source_ineligible_action,duplicate_ids,stale_manual,stale_context")
    }

    private func challengeRefundControls(_ ledger: Ledger, _ payload: Payload) throws {
        guard let chosen = payload.refunds.first(where: { $0.requiresFeeRecognition }),
              let event = try intelligence(ledger).confirmedByTransaction[chosen.purchaseID] else {
            throw Failure.assertion("Authentic same-identity fee-refund control is unavailable")
        }
        let repo = ledger.provider.intelligenceRepo
        var duplicate = event; duplicate.id = "qualification-occupied-" + UUID().uuidString
        try expectMovementFailure(.occupiedLeg) { try repo.saveMovement(duplicate, replacing: nil) }
        try check(try intelligence(ledger).confirmedByTransaction[chosen.purchaseID] == event, "Occupied refund retry replaced approved ownership")
        var legacy = event; legacy.refundAllocations = nil
        try repo.saveMovement(legacy, replacing: event)
        let legacyView = try runtime(ledger)
        guard let purchase = legacyView.resolved.first(where: { $0.id == chosen.purchaseID }) else { throw Failure.assertion("Legacy refund purchase disappeared") }
        try check(try purchase.amounts?.gross.minorUnits() == chosen.purchaseMinor && purchase.amounts?.net.minorUnits() == chosen.purchaseMinor,
                  "Legacy refund metadata inferred an unreviewed allocation")
        for allocation in chosen.allocations {
            let credit = legacyView.resolved.first { $0.id == allocation.creditID }
            try check(credit?.refundNeedsReview == true && credit?.spending == 0 && credit?.income == 0,
                      "Legacy refund credit silently became income or receipt-month negative spending")
        }
        try expectMovementFailure(.staleReview) { try repo.saveMovement(event, replacing: event) }
        try repo.saveMovement(event, replacing: legacy)
        guard let oldCategory = try assignments(ledger)[chosen.purchaseID],
              let alternate = payload.categories.first(where: { $0.id != oldCategory }) else {
            // An approved fee can genuinely be uncategorized. Select another
            // actual allocated purchase for category attribution below.
            try challengeRefundCategory(ledger, payload)
            return
        }
        try verifyCategoryReattribution(ledger, refund: chosen, oldCategory: oldCategory, newCategory: alternate.id)
    }
    private func challengeProtectedInterpretation(_ ledger: Ledger, _ payload: Payload) throws {
        let view = try runtime(ledger)
        guard let source = view.rows.first(where: { row in
            row.isBankOut && view.automation.spendingContexts[row.id]?.sourceEligible == true &&
            view.metadata.confirmedByTransaction[row.id].map { $0.kind == .ownTransfer || $0.kind == .cardPayment } == true &&
            !row.transaction.description.isEmpty
        }), let original = view.metadata.confirmedByTransaction[source.id],
            let category = payload.categories.first else {
            throw Failure.assertion("Authentic protected bank interpretation is unavailable for precedence qualification")
        }
        let fact = try selectedFact(ledger, id: source.id)
        let before = try resolved(ledger, id: source.id)
        let rule = CategoryRule(id: "qualification-protected-" + UUID().uuidString, workspaceID: ledger.workspaceID,
            name: "Qualification of reviewed financial interpretation precedence", version: 1, isEnabled: true,
            categoryID: category.id, accountID: fact.accountId, currency: fact.nativeCurrency, direction: fact.direction,
            predicates: [.init(field: .narration, match: .exact, text: fact.description ?? "")], bankExpenseAction: .expense)
        try ledger.provider.categoryRepo.saveRule(rule, previousVersion: nil)
        let preview = try evaluate(ledger, ids: [source.id])
        try check(preview.decisions.first?.spending?.proposed == view.automation.spendingIntents[source.id],
                  "An expense rule overrode a reviewed bank interpretation")
        _ = try ledger.provider.categoryRepo.applyCategoryEvaluation(preview, workspaceId: ledger.workspaceID, historical: true)
        try check(try intelligence(ledger).confirmedByTransaction[source.id] == original &&
                  resolved(ledger, id: source.id).treatment == before.treatment && resolved(ledger, id: source.id).spending == before.spending,
                  "Category Apply rewrote existing financial interpretation or its spending treatment")
    }
    private func challengeRefundCategory(_ ledger: Ledger, _ payload: Payload) throws {
        let assigned = try assignments(ledger)
        guard let chosen = payload.refunds.first(where: { assigned[$0.purchaseID] != nil }), let old = assigned[chosen.purchaseID],
              let alternate = payload.categories.first(where: { $0.id != old }) else {
            throw Failure.assertion("Authentic categorized refund purchase is unavailable for reattribution")
        }
        try verifyCategoryReattribution(ledger, refund: chosen, oldCategory: old, newCategory: alternate.id)
    }
    private func verifyCategoryReattribution(_ ledger: Ledger, refund: Refund, oldCategory: String, newCategory: String) throws {
        let before = try projection(runtime(ledger), currency: refund.currency)
        let allocation = try Money.fromMinorUnits(refund.allocations.reduce(0) { $0 + $1.minor }, currency: refund.currency)
        let zero = try SpendingAmounts.zero(currency: refund.currency)
        let beforeOld = before.categories.first { $0.id == oldCategory }?.amounts ?? zero
        let beforeNew = before.categories.first { $0.id == newCategory }?.amounts ?? zero
        _ = try ledger.provider.categoryRepo.setCategory(categoryId: newCategory, transactionId: refund.purchaseID, workspaceId: ledger.workspaceID)
        let after = try projection(runtime(ledger), currency: refund.currency)
        let afterOld = after.categories.first { $0.id == oldCategory }?.amounts ?? zero
        let afterNew = after.categories.first { $0.id == newCategory }?.amounts ?? zero
        try check(after.amounts == before.amounts && afterOld.allocatedRefund == (try beforeOld.allocatedRefund - allocation) &&
                  afterNew.allocatedRefund == (try beforeNew.allocatedRefund + allocation),
                  "Manual purchase category edit detached its refund attribution or changed total spending")
        try check(after.categories.first { $0.id == newCategory }?.supportingTransactionIDs.isSuperset(of: refund.allocations.map(\.creditID)) == true,
                  "Refund supporting credits did not follow their original purchase category")
    }

    private func challengeRefundSourceRejections(_ ledger: Ledger, _ payload: Payload) throws {
        let view = try runtime(ledger)
        let available = view.rows.filter { view.metadata.confirmedByTransaction[$0.id] == nil }
        let credits = available.filter { ($0.isCardDecrease || $0.isBankIn) && !$0.isLoanOrEMI && $0.date != nil && $0.amount > 0 }
        var observed: Set<String> = []
        func reject(_ purchase: SpendingSourceRow, _ credit: SpendingSourceRow, amount: Decimal? = nil, control: String) throws {
            let before = try intelligence(ledger)
            // The proposal uses the unchanged full magnitude of a real observed
            // source leg. Only owner interpretation metadata is challenged.
            let allocation = MovementRefundAllocation(purchaseTransactionID: purchase.id, creditTransactionID: credit.id,
                amount: try Money(amount: amount ?? credit.amount, currency: credit.currency))
            let event = MovementEvent(id: "qualification-source-rejection-" + UUID().uuidString,
                workspaceID: ledger.workspaceID, kind: .refund, decision: .confirmed,
                transactionIDs: [purchase.id, credit.id], explanation: "Qualification of a rejected source-ineligible refund interpretation.",
                reviewedAtISO: payload.reviewedAtISO, refundAllocations: [allocation])
            try expectMovementFailure(.invalidLegs) { try ledger.provider.intelligenceRepo.saveMovement(event, replacing: nil) }
            try check(try intelligence(ledger) == before, "Rejected source-ineligible refund left durable interpretation residue")
            observed.insert(control)
        }
        for purchase in available where purchase.isLoanOrEMI && (purchase.isCardIncrease || purchase.isBankOut) && purchase.date != nil {
            if let credit = credits.first(where: { $0.accountID == purchase.accountID && $0.currency == purchase.currency &&
                $0.amount <= purchase.amount && $0.date! >= purchase.date! }) {
                try reject(purchase, credit, control: "sourceLoanOrEMI")
                break
            }
        }
        for purchase in available where !purchase.isLoanOrEMI && (purchase.isCardIncrease || purchase.isBankOut) && purchase.date != nil {
            if let credit = credits.first(where: { $0.accountID == purchase.accountID && $0.currency == purchase.currency &&
                $0.amount <= purchase.amount && $0.date! < purchase.date! }) {
                try reject(purchase, credit, control: "creditBeforePurchase")
                break
            }
        }
        let eligiblePurchases = available.filter {
            !$0.isLoanOrEMI && ($0.isCardIncrease || $0.isBankOut) && $0.date != nil && $0.amount > 0
        }
        for purchase in eligiblePurchases {
            if let credit = credits.first(where: { $0.accountID == purchase.accountID && $0.currency == purchase.currency &&
                $0.date! >= purchase.date! && $0.amount > purchase.amount }) {
                // Full real credit passes its own cap and exceeds purchase cost.
                try reject(purchase, credit, control: "purchaseTotalCap")
                break
            }
        }
        for purchase in eligiblePurchases {
            if let credit = credits.first(where: { $0.accountID == purchase.accountID && $0.currency == purchase.currency &&
                $0.date! >= purchase.date! && $0.amount < purchase.amount }) {
                // Full real purchase passes its own cap and exceeds the credit.
                try reject(purchase, credit, amount: purchase.amount, control: "creditTotalCap")
                break
            }
        }
        let required: Set<String> = ["sourceLoanOrEMI", "creditBeforePurchase", "purchaseTotalCap", "creditTotalCap"]
        record("REFUND_OBSERVED_NEGATIVE_CONTROLS=" + observed.sorted().joined(separator: ","))
        record("REFUND_UNOBSERVED_NEGATIVE_CONTROLS=" + required.subtracting(observed).sorted().joined(separator: ","))
    }

    private func qualifyFutureImports(root: URL, payload: Payload) async throws {
        let path = root.appendingPathComponent("future-import.sqlite")
        let sqlite = try SQLiteRepositoryProvider(path: path.path)
        defer { sqlite.database.close() }
        let sqlProvider = DatabaseProvider.verifiedSQLite(sqlite)
        defer { sqlProvider.invalidateGeneration() }
        let memoryProvider = DatabaseProvider(inMemory: true)
        defer { memoryProvider.invalidateGeneration() }
        let sql = try await qualifyFutureImport(provider: sqlProvider, database: sqlite.database, payload: payload)
        let memory = try await qualifyFutureImport(provider: memoryProvider, database: nil, payload: payload)
        try check(sql == memory, "SQLite and InMemory disagree on source-bound future category or spending outcomes")
    }

    /// Every financial record comes from the existing unchanged authentic-source
    /// helper, ordinary ImportEngine preparation and the production import mapper.
    /// No transaction/domain DTO is authored or copied into either provider.
    private func qualifyFutureImport(provider: DatabaseProvider, database: SQLiteDatabase?, payload: Payload) async throws -> [String: FutureOutcome] {
        let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
        let workspace = plan.workspace.id
        try check(workspace == payload.workspaceID, "Authentic future import selected a different approved workspace")
        let beforeFacts = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        try check(beforeFacts.isEmpty, "Future qualification must own an empty isolated provider")
        guard case .committed(let receipt) = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
            throw Failure.assertion("Unchanged authentic source did not commit through the ordinary provider")
        }
        let facts = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        let exactNewIDs = Set(facts.map(\.id)).subtracting(beforeFacts.map(\.id))
        try check(!exactNewIDs.isEmpty && facts.allSatisfy { $0.importSessionId == receipt.importSessionId && $0.documentId == receipt.documentId },
                  "New-import ownership is not bound to the exact committed canonical cohort")
        let independent = payload.futureOriginal
        let sourceFingerprints = plan.historyTemplate.fingerprints.filter {
            $0.algorithm == DocumentFingerprintDTO.sourceBytesSHA256Algorithm
        }
        let rawTextFingerprints = plan.historyTemplate.fingerprints.filter {
            $0.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm
        }
        try check(sourceFingerprints.count == 1 && sourceFingerprints.first?.fingerprint == independent.sourceSHA256 &&
                  sourceFingerprints.first?.isDuplicateAuthority == independent.sourceBytesIsDuplicateAuthority &&
                  rawTextFingerprints.count == 1 && rawTextFingerprints.first?.fingerprint == independent.rawTextSHA256 &&
                  rawTextFingerprints.first?.isDuplicateAuthority == independent.rawTextIsDuplicateAuthority &&
                  !independent.sourceBytesIsDuplicateAuthority && independent.rawTextIsDuplicateAuthority,
                  "Existing authentic CSV source identity or raw-text duplicate-authority role changed")
        let frozenByID = Dictionary(uniqueKeysWithValues: payload.sourceFacts.map { ($0.id, $0) })
        try check(Set(independent.rows.map(\.frozenCanonicalID)).count == independent.rows.count &&
                  independent.rows.allSatisfy { frozenByID[$0.frozenCanonicalID]?.documentID == independent.frozenDocumentID } &&
                  independent.consecutiveBalanceChecks == independent.rows.count - 1 &&
                  independent.rows.count == facts.count,
                  "Existing authentic original does not bind to its complete frozen canonical cohort and independent source table")
        let oracle = Dictionary(uniqueKeysWithValues: independent.rows.map { ($0.sourceOrdinal, $0) })
        var bound: [String: FutureOriginalRow] = [:]
        for fact in facts {
            var candidates: [Int: FutureOriginalRow] = [:]
            for raw in fact.rawRows {
                guard let ordinal = raw.sourceOrdinal, raw.parserProfileId == "axis.bank-account.csv",
                      raw.normalizedRecordDigest?.isEmpty == false else { continue }
                if let candidate = oracle[ordinal], raw.normalizedRecordDigest == candidate.normalizedDigest {
                    candidates[ordinal] = candidate
                }
            }
            try check(candidates.count == 1, "New canonical occurrence did not bind uniquely to the exact original and independent row oracle")
            guard let occurrence = candidates.values.first else {
                throw Failure.assertion("Source-bound future occurrence has no independent original table row")
            }
            let expectedMoney = try Money(canonicalDecimal: occurrence.signedDecimal, currency: occurrence.currency)
            let actualMoney = try Money(canonicalDecimal: fact.amountDecimal, currency: fact.nativeCurrency)
            try check(fact.nativeCurrency == occurrence.currency && fact.direction == occurrence.direction && fact.amountMinor == occurrence.signedMinor &&
                      actualMoney == expectedMoney && String(fact.postedDateISO.prefix(10)) == occurrence.date &&
                      fact.financialDateRole == "transaction_date" && fact.valueDateISO == nil &&
                      fact.description == occurrence.narration && fact.reference == occurrence.reference && fact.runningBalanceMinor == occurrence.balanceMinor,
                      "Future preparation differs from its exact independent authentic original table row")
            bound[fact.id] = occurrence
        }
        try check(Set(bound.values.map(\.key)).count == facts.count, "Distinct authentic occurrences collapsed in the future-import oracle")
        let categoryRepo = provider.categoryRepo
        func snapshot() throws -> CategoryAutomationSnapshot {
            guard let value = try categoryRepo.automationSnapshot(workspaceId: workspace) else { throw Failure.assertion("Future metadata snapshot is unavailable") }
            return value
        }
        func assigned() throws -> [String: String] {
            Dictionary(uniqueKeysWithValues: try categoryRepo.assignments(workspaceId: workspace).map { ($0.transactionId, $0.categoryId) })
        }
        let pending = try snapshot()
        try check(pending.pendingIDs == exactNewIDs && pending.work.values.allSatisfy { $0.origin == .newImport && $0.importSessionID == receipt.importSessionId },
                  "Ordinary import did not create work for exactly its newly committed canonical IDs")
        let immutableBefore = try database.map(immutableGraphDigest)
        let savedDocument = try provider.importSessionRepo.importedDocument(id: receipt.documentId)
        let savedSession = try provider.importSessionRepo.importSession(id: receipt.importSessionId)
        let savedProjections = try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspace)
        let savedBankSections = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: workspace)
        for category in payload.categories {
            let name = try CategoryName.validated(category.name)
            _ = try categoryRepo.createCategory(.init(id: category.id, workspaceId: workspace, name: name.display,
                normalizedName: name.normalized, createdAtISO: payload.reviewedAtISO))
        }
        // Narrow rules refer to adopted account identities and are not rebound
        // to a newly created account merely because its source is familiar.
        let initialRules = payload.initialRules.filter { $0.accountID == nil }
        let finalRules = payload.rules.filter { $0.accountID == nil }
        let finalByID = Dictionary(uniqueKeysWithValues: finalRules.map { ($0.id, $0) })
        for rule in initialRules { try categoryRepo.saveRule(rule, previousVersion: nil) }
        for old in initialRules {
            if let final = finalByID[old.id] {
                if old != final { try categoryRepo.saveRule(final, previousVersion: old.version) }
            } else { try categoryRepo.deleteRule(id: old.id, workspaceId: workspace, version: old.version) }
        }
        let active = Set(payload.categories.map(\.id))
        let factsByID = Dictionary(uniqueKeysWithValues: facts.map { ($0.id, $0) })
        func evaluation(_ ids: [String]) throws -> CategoryEvaluation {
            try check(Set(ids).isSubset(of: exactNewIDs), "Future evaluation included an unowned canonical record")
            return CategoryEvaluation.evaluate(inputs: ids.compactMap { factsByID[$0] }.map(CategoryRuleInput.init),
                snapshot: try snapshot(), assignments: try assigned(), activeCategoryIDs: active)
        }
        let orderedIDs = facts.map(\.id).sorted { bound[$0]!.key < bound[$1]!.key }
        let fullPreview = try evaluation(orderedIDs)
        for decision in fullPreview.decisions {
            guard let expected = bound[decision.transactionID] else { throw Failure.assertion("Future preview has an unbound occurrence") }
            let actualMatches = Set(finalRules.filter { $0.matches(CategoryRuleInput(transaction: factsByID[decision.transactionID]!)) }.map(\.id))
            try check(actualMatches == Set(expected.matchedRuleIDs), "Future native rule matches differ from the frozen original-source oracle")
            try check(Set(decision.spending?.proposed?.matches.map(\.ruleID) ?? []) == Set(expected.expenseRuleIDs),
                      "Future bank-spending action differs from its exact source-qualified approval")
        }
        let eligible = orderedIDs.filter { !(bound[$0]?.expenseRuleIDs.isEmpty ?? true) }
        guard eligible.count >= 2 else { throw Failure.assertion("Selected authentic new source does not exercise two approved bank expense actions") }
        let first = eligible[0], second = eligible[1]
        let reviewedPair = try evaluation([first, second])
        _ = try categoryRepo.setSpendingSuppressed(true, transactionID: second, workspaceId: workspace, expected: nil)
        let beforeStale = try snapshot(), beforeStaleAssignments = try assigned()
        try expectCategoryStale { _ = try categoryRepo.applyCategoryEvaluation(reviewedPair, workspaceId: workspace, historical: false) }
        try check(try snapshot() == beforeStale && assigned() == beforeStaleAssignments && snapshot().pendingIDs == exactNewIDs,
                  "Failed new-import metadata apply left partial assignments, spending intent or completed receipts")
        _ = try categoryRepo.setCategory(categoryId: nil, transactionId: first, workspaceId: workspace)
        try check(try snapshot().pendingIDs.contains(first), "Manual category clear prematurely completed the independent expense receipt")
        let retry = try evaluation(orderedIDs)
        try check(try categoryRepo.applyCategoryEvaluation(retry, workspaceId: workspace, historical: false) == exactNewIDs.count,
                  "Fresh metadata retry did not finish exactly the pending new-import cohort")
        let completed = try snapshot()
        try check(completed.pendingIDs.isEmpty && completed.intents[first]?.kind == .deliberatelyCleared &&
                  completed.spendingIntents[first]?.kind == .automaticExpense && completed.spendingIntents[second]?.kind == .deliberatelySuppressed,
                  "Future retry lost manual category precedence or independent spending suppression")
        try check(try categoryRepo.applyCategoryEvaluation(retry, workspaceId: workspace, historical: false) == 0 && snapshot() == completed,
                  "Completed future metadata work replayed after an identical retry")
        let futureView = try runtime(provider: provider, workspaceID: workspace)
        let resolved = Dictionary(uniqueKeysWithValues: futureView.resolved.map { ($0.id, $0) })
        for id in eligible {
            try check(resolved[id]?.treatment == (id == second ? .unresolved : .expense),
                      "Future canonical hydration disagrees with saved bank-spending or suppression intent")
        }
        try challengeAuthenticExclusion(categoryRepo: categoryRepo, rules: finalRules, facts: facts, workspaceID: workspace)
        try await challengeSavedRefresh(provider: provider, workspaceID: workspace, transactionID: first,
                                  categoryID: payload.categories[0].id)
        try check(try provider.transactionRepo.trustedTransactions(workspaceId: workspace) == facts &&
                  provider.importSessionRepo.importedDocument(id: receipt.documentId) == savedDocument &&
                  provider.importSessionRepo.importSession(id: receipt.importSessionId) == savedSession &&
                  provider.importSessionRepo.statementFinancialProjections(workspaceId: workspace) == savedProjections &&
                  provider.importSessionRepo.bankSectionSnapshot(workspaceId: workspace) == savedBankSections,
                  "Metadata failure or retry reimported or modified authentic financial/source records")
        try check(provider.confirmedImportRepo.commitConfirmedImport(plan) == .exactDuplicate,
                  "Exact unchanged authentic import replay was not recognized as a duplicate")
        try check(try provider.transactionRepo.trustedTransactions(workspaceId: workspace) == facts,
                  "Exact source replay duplicated or replaced canonical records")
        if let database, let immutableBefore {
            try check(try immutableGraphDigest(database) == immutableBefore, "Future metadata retry changed the durable financial/source graph")
        }
        let finished = try snapshot(), assignments = try assigned()
        var outcomes: [String: FutureOutcome] = [:]
        for id in orderedIDs {
            guard let occurrence = bound[id], let work = finished.work[id] else { throw Failure.assertion("Completed future receipt disappeared") }
            outcomes[occurrence.key] = FutureOutcome(categoryID: assignments[id], categoryKind: finished.intents[id]?.kind.rawValue,
                spendingKind: finished.spendingIntents[id]?.kind.rawValue, workOutcome: work.outcome.rawValue,
                categoryRules: Set(finished.intents[id]?.matches.map(\.ruleID) ?? []),
                spendingRules: Set(finished.spendingIntents[id]?.matches.map(\.ruleID) ?? []))
        }
        return outcomes
    }

    private func challengeAuthenticExclusion(categoryRepo: CategoryRepository, rules: [CategoryRule], facts: [TransactionDTO], workspaceID: String) throws {
        for original in rules where original.bankExpenseAction == .expense {
            let matches = facts.filter { original.matches(CategoryRuleInput(transaction: $0)) }
            for excluded in matches {
                guard let narration = excluded.description, !narration.isEmpty,
                      let retained = matches.first(where: { value in
                          (value.description ?? "").range(of: narration, options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) == nil
                      }) else { continue }
                var rule = original
                rule.id = "qualification-exclusion-" + UUID().uuidString; rule.version = 1
                rule.name = "Qualification of an exact observed narration exclusion"
                rule.predicates.append(.init(field: .narration, match: .doesNotContain, text: narration))
                try categoryRepo.saveRule(rule, previousVersion: nil)
                guard let saved = try categoryRepo.automationSnapshot(workspaceId: workspaceID)?.rules.first(where: { $0.id == rule.id }) else {
                    throw Failure.assertion("Native narration-exclusion rule did not persist")
                }
                try check(!saved.matches(CategoryRuleInput(transaction: excluded)) && saved.matches(CategoryRuleInput(transaction: retained)),
                          "Persisted narration exclusion did not distinguish two observed genuine source occurrences")
                try categoryRepo.deleteRule(id: rule.id, workspaceId: workspaceID, version: rule.version)
                return
            }
        }
        throw Failure.assertion("Selected authentic source lacks distinct observed members for an exclusion control")
    }

    private func challengeSavedRefresh(provider: DatabaseProvider, workspaceID: String, transactionID: String, categoryID: String) async throws {
        let store = CategoryStore(), gate = CategoryReconciliationGate()
        _ = try RepositoryStoreHydrator(databaseProvider: provider, categoryStore: store, workspaceId: workspaceID,
            categoryReconciliationGate: gate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
        let previous = store.snapshot
        // This legacy/custom-runtime control intentionally has no shortcut witness.
        store.replaceSnapshot(previous)
        var failHydration = true
        let coordinator = CategoryManagementCoordinator(provider: { provider }, workspaceID: workspaceID, categoryStore: store,
            reconciliationGate: gate, forcedHydration: { provider, categoryStore, workspaceID in
                if failHydration { throw Failure.assertion("Qualification requested canonical refresh failure") }
                return try RepositoryStoreHydrator(databaseProvider: provider, categoryStore: categoryStore,
                    workspaceId: workspaceID, categoryReconciliationGate: gate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            })
        do {
            _ = try await coordinator.setCategory(categoryID: categoryID, transactionID: transactionID)
            throw Failure.assertion("Requested post-save hydration failure did not occur")
        } catch CategoryManagementCoordinatorError.savedButRefreshFailed { }
        let durable = try provider.categoryRepo.automationSnapshot(workspaceId: workspaceID)
        try check(durable?.intents[transactionID]?.kind == .manual && durable?.intents[transactionID]?.categoryID == categoryID &&
                  store.snapshot == previous && gate.isBlocked(for: provider.generationToken),
                  "Saved metadata and failed canonical refresh were not distinguished")
        failHydration = false
        try check(try coordinator.retryCanonicalHydration() == .succeeded && !gate.isBlocked(for: provider.generationToken),
                  "Canonical hydration retry did not recover the already saved metadata")
        try check(try provider.categoryRepo.automationSnapshot(workspaceId: workspaceID) == durable && store.snapshot.assignments[transactionID] == categoryID,
                  "Refresh retry replayed metadata or failed to publish canonical owner state")
    }

    private func runtime(_ ledger: Ledger) throws -> Runtime {
        try runtime(provider: ledger.provider, workspaceID: ledger.workspaceID)
    }
    private func runtime(provider: DatabaseProvider, workspaceID: String) throws -> Runtime {
        let snapshot = try RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspaceID,
            categoryReconciliationGate: nil, participatesInLifecycleGate: false).stageHydration()
        guard let metadata = snapshot.intelligence, let automation = snapshot.categorySnapshot.automation else {
            throw Failure.assertion("Canonical hydration did not stage required owner metadata")
        }
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources,
            cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot, salaryRuleIDs: metadata.preferences?.salaryRuleIDs ?? [])
        return Runtime(snapshot: snapshot, metadata: metadata, automation: automation, rows: rows,
            resolved: try SpendingIntelligence.resolvedRows(rows: rows, metadata: metadata, spendingIntents: automation.spendingIntents),
            accounts: Set(snapshot.financialSources.accounts.map(\.id)))
    }
    private func resolved(_ ledger: Ledger, id: String) throws -> SpendingReviewRow {
        guard let result = try runtime(ledger).resolved.first(where: { $0.id == id }) else { throw Failure.assertion("Authentic control disappeared from resolved spending") }
        return result
    }
    private func projections(_ view: Runtime) throws -> [String: SpendingProjection] {
        var result: [String: SpendingProjection] = [:]
        for currency in Set(view.rows.map(\.currency)) { result[currency] = try projection(view, currency: currency) }
        return result
    }
    private func projection(_ view: Runtime, currency: String, start: StatementDate? = nil, end: StatementDate? = nil) throws -> SpendingProjection {
        try SpendingIntelligence.project(rows: view.rows, metadata: view.metadata, sources: view.snapshot.financialSources,
            currency: currency, accountIDs: view.accounts, start: start, end: end, allSuggestions: [], spendingIntents: view.automation.spendingIntents)
    }
    private func selectedFact(_ ledger: Ledger, id: String) throws -> TransactionDTO {
        guard let result = try ledger.provider.transactionRepo.trustedTransactions(workspaceId: ledger.workspaceID).first(where: { $0.id == id }) else {
            throw Failure.assertion("Authentic selected control has no canonical transaction")
        }
        return result
    }
    private func evaluate(_ ledger: Ledger, ids: Set<String>? = nil, facts supplied: [TransactionDTO]? = nil) throws -> CategoryEvaluation {
        let facts = try supplied ?? ledger.provider.transactionRepo.trustedTransactions(workspaceId: ledger.workspaceID)
        return CategoryEvaluation.evaluate(inputs: facts.filter { ids == nil || ids!.contains($0.id) }.map(CategoryRuleInput.init),
            snapshot: try automation(ledger), assignments: try assignments(ledger),
            activeCategoryIDs: Set(try ledger.provider.categoryRepo.categories(workspaceId: ledger.workspaceID).filter { !$0.isArchived }.map(\.id)))
    }
    private func automation(_ ledger: Ledger) throws -> CategoryAutomationSnapshot {
        guard let value = try ledger.provider.categoryRepo.automationSnapshot(workspaceId: ledger.workspaceID) else { throw Failure.assertion("Category automation repository is unavailable") }
        return value
    }
    private func intelligence(_ ledger: Ledger) throws -> FinancialIntelligenceSnapshot {
        guard let value = try ledger.provider.intelligenceRepo.snapshot(workspaceID: ledger.workspaceID) else { throw Failure.assertion("Financial interpretation repository is unavailable") }
        return value
    }
    private func assignments(_ ledger: Ledger) throws -> [String: String] {
        Dictionary(uniqueKeysWithValues: try ledger.provider.categoryRepo.assignments(workspaceId: ledger.workspaceID).map { ($0.transactionId, $0.categoryId) })
    }
    private func treatmentCode(_ treatment: SpendingTreatment) -> String {
        switch treatment {
        case .income: "income"
        case .expense: "expense"
        case .refund: "refund"
        case .ownTransfer: "ownTransfer"
        case .cardPayment: "cardPayment"
        case .reversal: "reversal"
        case .outsideScope: "outsideScope"
        case .unresolved: "unresolved"
        }
    }
    private func expectCategoryStale(_ body: () throws -> Void) throws {
        do { try body(); throw Failure.assertion("Stale category preview was accepted") }
        catch let error as CategoryAutomationError { try check(error == .stalePreview, "Category challenge failed for an unexpected domain reason") }
    }
    private func expectMovementFailure(_ expected: FinancialIntelligenceError, _ body: () throws -> Void) throws {
        do { try body(); throw Failure.assertion("Invalid or stale movement edit was accepted") }
        catch let error as FinancialIntelligenceError { try check(error == expected, "Movement challenge failed for an unexpected domain reason") }
    }
    private func check(_ condition: @autoclosure () throws -> Bool, _ reason: String) throws {
        guard try condition() else { throw Failure.assertion(reason) }
    }

    private struct TableColumns {
        let name: String
        let columns: [String]
    }
    private struct GraphSeal {
        let tables: [TableColumns]
        let digest: SHA256.Digest
    }
    private func quotedSQLIdentifier(_ name: String) -> String {
        "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    private func tableInventory(_ database: SQLiteDatabase) throws -> [TableColumns] {
        let names = try database.query(sql: "SELECT name FROM sqlite_master WHERE type='table';") { $0.string(at: 0) ?? "" }.sorted()
        return try names.map { name in
            let columns = try database.query(sql: "PRAGMA table_info(" + quotedSQLIdentifier(name) + ");") { $0.string(at: 1) ?? "" }
            try check(!name.isEmpty && !columns.isEmpty, "Preserved source table or column inventory is incomplete")
            return TableColumns(name: name, columns: columns)
        }
    }
    private func sealedSourceGraph(_ package: URL) throws -> GraphSeal {
        let database = SQLiteDatabase(path: package.appendingPathComponent("ledger.sqlite").path)
        try database.open(access: .readOnlySnapshot)
        defer { database.close() }
        let tables = try tableInventory(database).filter { $0.name != "schema_migrations" }
        try check(tables.contains { $0.name == "transactions" } && tables.contains { $0.name == "document_fingerprints" },
                  "Original backup lacks its financial and provenance graph")
        return GraphSeal(tables: tables, digest: try tableContentDigest(database, tables: tables, excludeMigrationSequence: true))
    }

    /// Hash every selected old column with its SQLite type and full byte value.
    /// Only fixed-size row digests are sorted, in Swift RAM. SQLite performs no
    /// value ordering that could spill private rows or original BLOBs to disk.
    private func tableContentDigest(_ database: SQLiteDatabase, tables: [TableColumns], excludeMigrationSequence: Bool = false) throws -> SHA256.Digest {
        let available = Dictionary(uniqueKeysWithValues: try tableInventory(database).map { ($0.name, Set($0.columns)) })
        var digest = SHA256()
        func frame(_ value: Data, into hash: inout SHA256) {
            var size = UInt64(value.count).bigEndian
            withUnsafeBytes(of: &size) { hash.update(data: Data($0)) }
            hash.update(data: value)
        }
        for table in tables {
            try check(available[table.name]?.isSuperset(of: table.columns) == true, "Schema upgrade removed an original table or column")
            frame(try JSONEncoder().encode([table.name] + table.columns), into: &digest)
            let expressions = table.columns.flatMap { column -> [String] in
                let value = quotedSQLIdentifier(column)
                // The alternate real representation distinguishes SQLite doubles;
                // casting all other values to BLOB preserves embedded text NULs.
                return ["typeof(" + value + ")", "CAST(CASE WHEN typeof(" + value + ")='real' THEN printf('%!.26g'," + value + ") ELSE " + value + " END AS BLOB)"]
            }.joined(separator: ",")
            // AUTOINCREMENT's own migration-history counter is part of that
            // registered history. Every unrelated sequence row stays protected.
            let condition = excludeMigrationSequence && table.name == "sqlite_sequence" ? " WHERE name IS NOT 'schema_migrations'" : ""
            let rows = try database.query(sql: "SELECT " + expressions + " FROM " + quotedSQLIdentifier(table.name) + condition + ";") { row in
                var rowDigest = SHA256()
                for index in table.columns.indices {
                    frame(Data((row.string(at: Int32(index * 2)) ?? "missing").utf8), into: &rowDigest)
                    frame(row.data(at: Int32(index * 2 + 1)) ?? Data(), into: &rowDigest)
                }
                return rowDigest.finalize().map { String(format: "%02x", $0) }.joined()
            }.sorted()
            for row in rows { frame(Data(row.utf8), into: &digest) }
        }
        return digest.finalize()
    }

    /// All financial, source, provenance, exclusion, planning and intake tables
    /// remain protected while ordinary approved interpretation metadata changes.
    private func immutableGraphDigest(_ database: SQLiteDatabase) throws -> SHA256.Digest {
        let mutable: Set<String> = ["categories", "category_rules", "transaction_category_assignments", "transaction_category_intent",
            "category_import_work", "transaction_spending_intent", "movement_events", "movement_legs", "intelligence_preferences"]
        let tables = try tableInventory(database).filter { !mutable.contains($0.name) }
        let names = Set(tables.map(\.name))
        try check(names.contains("transactions") && names.contains("net_worth_exclusions") && names.contains("document_fingerprints"),
                  "Preserved financial and provenance graph is incomplete")
        return try tableContentDigest(database, tables: tables)
    }
    private func makeNativeBackup(_ ledger: Ledger) throws -> URL {
        let package = ledger.directory.appendingPathComponent("qualified.ledgerforgebackup", isDirectory: true)
        try BackupFiles.createDirectory(package)
        let payload = package.appendingPathComponent("ledger.sqlite")
        try ledger.sqlite.database.withExclusiveAccess {
            try BackupCompatibility.checkContents(ledger.sqlite.database)
            try ledger.sqlite.database.createBackup(at: payload.path)
        }
        let digest = try BackupFiles.hash(payload)
        let manifest = BackupManifest(formatVersion: 1, backupID: UUID(), createdAt: ISO8601DateFormatter().string(from: Date()),
            application: .init(identifier: nil, version: nil, build: nil),
            database: .init(file: "ledger.sqlite", byteSize: digest.size, sha256: digest.sha256),
            schemaVersion: BackupCompatibility.supportedSchemaVersion, migrations: BackupCompatibility.migrationIdentities,
            contents: BackupManifest.contentDescription, exclusions: BackupManifest.excluded)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(manifest).write(to: package.appendingPathComponent("manifest.json"), options: .withoutOverwriting)
        try BackupFiles.flushPackage(package)
        return package
    }
}

/// Invoke only with the authentic qualification ledger's full hydrated rows and
/// ordinary SpendingIntelligence projection closure. This checks presentation
/// contracts over real records; it does not replace the independent source and
/// refund oracles in the enclosing qualification campaign. No financial value,
/// statement row, source date, or owner interpretation is authored here.
@MainActor
enum MoneyFlowAuthenticAssertions {
    enum Failure: Error { case assertion(String) }

    enum Shape: String, CaseIterable {
        case currentMonth, emptyMonth, noMatchingCurrency, mismatchedMonthRejected
        case multipleNativeCurrencies, confirmedPair, pairInsideOneMonth
        case counterpartOutsideMonth, reviewedCurrencyConversion
        case refundSupportingCredit, refundCreditOutsidePurchaseMonth
        case multipleRefundCredits, zeroNetPurchaseRetained, residualCredit
        case undatedRecord, historyOnlyAccount, unresolvedRecord, unknownDirection
        case unequalRecordedAccountSides, outsideSpendingScopeRecorded
    }

    private struct Scope: Hashable {
        let month: SelectedStatementMonth
        let currency: String
    }

    /// The caller retains the result in RAM and reports absent shapes as not
    /// observed. Neither absent source cases nor an unexecuted check pass by
    /// virtue of this helper existing.
    static func check(
        rows: [SpendingSourceRow], metadata: FinancialIntelligenceSnapshot,
        sources: FinancialSourceContext, currentMonth: SelectedStatementMonth,
        projection: (SelectedStatementMonth, String) throws -> SpendingProjection
    ) throws -> Set<Shape> {
        try require(!rows.isEmpty, "A populated authentic ledger is required")
        try require(Set(rows.map(\.id)).count == rows.count, "Authentic occurrence identities must be unique")
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        let currencies = Set(rows.map(\.currency)).sorted()
        var scopes: Set<Scope> = []
        for row in rows {
            guard let date = row.date else { continue }
            scopes.insert(.init(month: try SelectedStatementMonth(year: date.year, month: date.month), currency: row.currency))
        }
        let latest = max(scopes.map(\.month).max() ?? currentMonth, currentMonth)
        let emptyMonth = try SelectedStatementMonth(year: latest.month == 12 ? latest.year + 1 : latest.year,
                                                   month: latest.month == 12 ? 1 : latest.month + 1)
        for currency in currencies {
            scopes.insert(.init(month: currentMonth, currency: currency))
            scopes.insert(.init(month: emptyMonth, currency: currency))
        }
        // Selecting an unused catalog currency is a filter-boundary check, not
        // an invented source transaction or a claim of source-scale coverage.
        let usedCurrencies = Set(sources.accounts.map(\.currency)).union(currencies)
        let absentCurrency = CurrencyCatalog.shared.definitions.first { !usedCurrencies.contains($0.code.code) }?.code.code
        if let absentCurrency { scopes.insert(.init(month: currentMonth, currency: absentCurrency)) }

        var observed: Set<Shape> = []
        if currencies.count > 1 { observed.insert(.multipleNativeCurrencies) }
        var nonemptyProjection: (Scope, SpendingProjection)?
        for scope in scopes.sorted(by: { ($0.month, $0.currency) < ($1.month, $1.currency) }) {
            let spending = try projection(scope.month, scope.currency)
            let flow = try MoneyFlow.project(rows: rows, metadata: metadata, sources: sources,
                                             month: scope.month, currency: scope.currency, spending: spending)
            try check(flow, rows: rows, byID: byID, metadata: metadata, spending: spending, observed: &observed)
            if scope.month == currentMonth { observed.insert(.currentMonth) }
            if scope.month == emptyMonth || scope.currency == absentCurrency {
                try require(flow.periodTransactionIDs.isEmpty && flow.actual.nodes.isEmpty && flow.actual.links.isEmpty &&
                            flow.adjusted.nodes.isEmpty && flow.adjusted.links.isEmpty,
                            "An empty filter must not borrow out-of-period records or fabricate graph endpoints")
                let zero = try Money(amount: 0, currency: scope.currency)
                try require(flow.adjustedAmounts.gross == zero && flow.adjustedAmounts.allocatedRefund == zero &&
                            flow.adjustedAmounts.net == zero, "An empty filter must retain exact native zero totals")
                observed.insert(scope.month == emptyMonth ? .emptyMonth : .noMatchingCurrency)
            }
            if nonemptyProjection == nil && !spending.rows.isEmpty { nonemptyProjection = (scope, spending) }
        }
        guard let selected = nonemptyProjection else { throw Failure.assertion("No dated authentic scope was exercised") }
        var rejected = false
        do {
            _ = try MoneyFlow.project(rows: rows, metadata: metadata, sources: sources,
                                      month: emptyMonth, currency: selected.0.currency, spending: selected.1)
        } catch MoneyFlowError.inconsistentSnapshot { rejected = true }
        try require(rejected, "A projection from another month must fail closed")
        observed.insert(.mismatchedMonthRejected)
        return observed
    }

    private static func check(
        _ flow: MoneyFlowProjection, rows: [SpendingSourceRow], byID: [String: SpendingSourceRow],
        metadata: FinancialIntelligenceSnapshot, spending: SpendingProjection, observed: inout Set<Shape>
    ) throws {
        let native = flow.currency
        let selected = rows.filter { row in
            row.currency == native && row.date?.year == flow.month.year && row.date?.month == flow.month.month
        }
        let periodIDs = Set(selected.map(\.id))
        let undated = Set(rows.filter { $0.currency == native && $0.date == nil }.map(\.id))
        let review = Dictionary(uniqueKeysWithValues: spending.rows.map { ($0.id, $0) })
        let excluded = Set(spending.rows.filter { $0.treatment == .outsideScope }.map(\.id))
        let unknown = Set(selected.filter { row in
            let outgoing = row.isBankOut || row.isCardIncrease
            let incoming = row.isBankIn || row.isCardDecrease
            return outgoing == incoming || !["bank", "credit_card"].contains(row.domain)
        }.map(\.id))
        let expectedActual = periodIDs.subtracting(unknown)
        let expectedExpenses = Set(spending.rows.filter { $0.treatment == .expense }.map(\.id))
        try require(flow.periodTransactionIDs == periodIDs && flow.undatedTransactionIDs == undated,
                    "Period membership must follow each immutable source date and native currency")
        try require(flow.excludedTransactionIDs == excluded && flow.unknownDirectionIDs == unknown,
                    "Excluded or undirected records must remain explicitly accounted for")
        try require(flow.actual.transactionIDs == expectedActual && flow.adjusted.transactionIDs == expectedExpenses,
                    "Actual movement and adjusted purchase membership must remain separate")
        try require(flow.adjusted.transactionIDs.isDisjoint(with: excluded),
                    "Source exclusions must continue to take precedence in adjusted spending")
        for id in excluded.subtracting(unknown) {
            let links = flow.actual.links.filter { $0.transactionIDs.contains(id) }
            try require(links.count == 1 && [.outsideSpendingScope, .transfer, .cardPayment].contains(links[0].role),
                        "A source movement outside spending scope must remain actual and visibly non-consumption")
            observed.insert(.outsideSpendingScopeRecorded)
        }
        try require(flow.adjustedAmounts.gross == spending.amounts.gross &&
                    flow.adjustedAmounts.allocatedRefund == spending.amounts.allocatedRefund &&
                    flow.adjustedAmounts.net == spending.amounts.net,
                    "Money flow must agree exactly with the shared spending oracle")
        try require(Set(flow.records.keys) == Set(byID.keys), "Supporting history must remain available in RAM")
        for (id, record) in flow.records {
            guard let original = byID[id] else { throw Failure.assertion("Unknown supporting record") }
            try require(record.money == original.transaction.money && record.date == original.date &&
                        record.accountID == original.accountID && record.dateRole == original.dateRole,
                        "Drill-down must preserve original money, account and date meaning")
        }
        if !undated.isEmpty { observed.insert(.undatedRecord) }
        if !unknown.isEmpty { observed.insert(.unknownDirection) }
        if !flow.unresolvedTransactionIDs.isEmpty { observed.insert(.unresolvedRecord) }
        if flow.coverage.contains(where: \.isHistoryOnly) { observed.insert(.historyOnlyAccount) }

        let pairs = metadata.movements.filter { event in
            event.decision == .confirmed && [.ownTransfer, .cardPayment].contains(event.kind) &&
                !periodIDs.isDisjoint(with: event.transactionIDs)
        }
        for event in pairs {
            let contributors = Set(event.transactionIDs).intersection(periodIDs)
            let support = Set(event.transactionIDs).subtracting(contributors)
            let links = flow.actual.links.filter { !$0.transactionIDs.isDisjoint(with: contributors) }
            try require(links.count == 1, "Each confirmed movement must contribute one principal link")
            guard let link = links.first else { throw Failure.assertion("Confirmed movement link is missing") }
            try require(contributors.isSubset(of: link.transactionIDs) && support.isSubset(of: link.supportingIDs),
                        "A confirmed counterpart outside the filter must remain supporting evidence")
            try require(flow.adjusted.transactionIDs.isDisjoint(with: event.transactionIDs),
                        "A confirmed movement must not become terminal adjusted spending")
            observed.insert(.confirmedPair)
            if contributors.count == 2 { observed.insert(.pairInsideOneMonth) }
            if support.contains(where: { id in
                guard let date = byID[id]?.date else { return true }
                return date.year != flow.month.year || date.month != flow.month.month
            }) { observed.insert(.counterpartOutsideMonth) }
        }

        for bridge in flow.conversionBridges {
            guard let event = pairs.first(where: { $0.id == bridge.id }),
                  let sent = byID[bridge.sent.id], let received = byID[bridge.received.id] else {
                throw Failure.assertion("A conversion bridge requires its reviewed authentic pair")
            }
            try require(sent.currency != received.currency && bridge.sent.money == sent.transaction.money &&
                        bridge.received.money == received.transaction.money && bridge.sent.date == sent.date &&
                        bridge.received.date == received.date &&
                        bridge.allTransactionIDs == Set(event.transactionIDs),
                        "Currency conversion context must retain both actual native amounts and dates")
            try require(bridge.transactionIDs == Set(event.transactionIDs).intersection(periodIDs) &&
                        bridge.supportingIDs == Set(event.transactionIDs).subtracting(periodIDs),
                        "Conversion context must not combine native currencies into a common principal")
            observed.insert(.reviewedCurrencyConversion)
        }
        let expectedConversions = Set(pairs.filter { event in
            Set(event.transactionIDs.compactMap { byID[$0]?.currency }).count > 1
        }.map(\.id))
        try require(Set(flow.conversionBridges.map(\.id)) == expectedConversions,
                    "Every reviewed cross-currency pair must retain a visible bridge")

        try checkGraph(flow.actual, isActual: true, flow: flow, byID: byID, review: review,
                       pairs: pairs, observed: &observed)
        try checkGraph(flow.adjusted, isActual: false, flow: flow, byID: byID, review: review,
                       pairs: pairs, observed: &observed)
        // This independent account-side oracle uses all directed authentic
        // monthly source occurrences, including those outside spending scope.
        // Repeated diagram endpoints still belong to the same real account.
        let actualRows = selected.filter { expectedActual.contains($0.id) }
        let expectedAccountIDs = Set(actualRows.map(\.accountID))
        let accountNodes = flow.actual.nodes.filter(\.isAccount)
        try require(accountNodes.allSatisfy { $0.accountID != nil } &&
                    Set(accountNodes.compactMap(\.accountID)) == expectedAccountIDs,
                    "Actual account nodes must retain the full authentic monthly account set")
        let zero = try Money(amount: 0, currency: native)
        for accountID in expectedAccountIDs {
            let original = actualRows.filter { $0.accountID == accountID }
            let expectedIncoming = try original.filter { $0.isBankIn || $0.isCardDecrease }
                .reduce(zero) { try $0 + magnitude($1) }
            let expectedOutgoing = try original.filter { $0.isBankOut || $0.isCardIncrease }
                .reduce(zero) { try $0 + magnitude($1) }
            let visual = accountNodes.filter { $0.accountID == accountID }
            let actualIncoming = try visual.reduce(zero) { try $0 + $1.incoming }
            let actualOutgoing = try visual.reduce(zero) { try $0 + $1.outgoing }
            try require(actualIncoming == expectedIncoming && actualOutgoing == expectedOutgoing,
                        "Actual account sides must equal all genuine source movements without spending exclusions")
        }
        for value in spending.rows where value.treatment == .expense {
            let credits = Set(value.refundDetails.map(\.creditTransactionID))
            guard !credits.isEmpty else { continue }
            let links = flow.adjusted.links.filter { $0.transactionIDs.contains(value.id) }
            try require(links.count == 1 && credits.isSubset(of: links[0].supportingIDs),
                        "A refunded purchase must retain every credit as supporting evidence")
            observed.insert(.refundSupportingCredit)
            if credits.count > 1 { observed.insert(.multipleRefundCredits) }
            if value.amounts?.net.amount == 0 { observed.insert(.zeroNetPurchaseRetained) }
            if value.refundDetails.contains(where: { detail in
                guard let date = detail.creditDate else { return false }
                return date.year != flow.month.year || date.month != flow.month.month
            }) { observed.insert(.refundCreditOutsidePurchaseMonth) }
        }
        for value in spending.rows where value.treatment == .refund {
            try require(!flow.adjusted.transactionIDs.contains(value.id),
                        "An actual refund credit must not cause a second receipt-month spending deduction")
            if (value.refundResidual?.amount ?? 0) > 0 { observed.insert(.residualCredit) }
        }
    }

    private static func checkGraph(
        _ graph: MoneyFlowGraph, isActual: Bool, flow: MoneyFlowProjection,
        byID: [String: SpendingSourceRow], review: [String: SpendingReviewRow],
        pairs: [MovementEvent], observed: inout Set<Shape>
    ) throws {
        let zero = try Money(amount: 0, currency: flow.currency)
        let nodes = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        var used: Set<String> = []
        for link in graph.links {
            try require(!link.transactionIDs.isEmpty && used.isDisjoint(with: link.transactionIDs),
                        "Every graph must count each actual occurrence once")
            used.formUnion(link.transactionIDs)
            try require(link.amount.currency.code == flow.currency && link.amount.amount >= 0 &&
                        link.transactionIDs.isSubset(of: flow.periodTransactionIDs) &&
                        link.supportingIDs.isDisjoint(with: link.transactionIDs) &&
                        link.supportingIDs.isSubset(of: Set(byID.keys)),
                        "A link must retain exact native values and separate contributors from support")
            guard let source = nodes[link.sourceID], let target = nodes[link.targetID] else {
                throw Failure.assertion("A link endpoint is missing")
            }
            try require(source.stage < target.stage, "Every ribbon must have a readable forward endpoint")
            var expected = zero
            if isActual && [.transfer, .cardPayment].contains(link.role) {
                let contributing = pairs.filter { !link.transactionIDs.isDisjoint(with: $0.transactionIDs) }
                try require(!contributing.isEmpty && Set(contributing.flatMap(\.transactionIDs))
                    .intersection(flow.periodTransactionIDs) == link.transactionIDs,
                    "A transfer ribbon may contain only confirmed movement contributors")
                for event in contributing {
                    let legs = event.transactionIDs.compactMap { byID[$0] }
                    guard let selected = legs.first(where: { $0.isBankOut && link.transactionIDs.contains($0.id) }) ??
                            legs.first(where: { link.transactionIDs.contains($0.id) }) else {
                        throw Failure.assertion("A movement has no selected native leg")
                    }
                    expected = try expected + magnitude(selected)
                }
            } else if isActual {
                for id in link.transactionIDs {
                    guard let row = byID[id] else { throw Failure.assertion("A source occurrence is missing") }
                    expected = try expected + magnitude(row)
                }
            } else {
                var gross = zero, refund = zero
                for id in link.transactionIDs {
                    guard let value = review[id], value.treatment == .expense, let amounts = value.amounts else {
                        throw Failure.assertion("Adjusted spending requires a recognised original purchase")
                    }
                    gross = try gross + magnitude(value.source)
                    refund = try refund + amounts.allocatedRefund
                }
                expected = try gross - refund
                guard let amounts = link.amounts else { throw Failure.assertion("Adjusted amount detail is missing") }
                try require(amounts.gross == gross && amounts.allocatedRefund == refund && amounts.net == expected,
                            "Adjusted links must preserve exact gross, allocated refund and net amounts")
            }
            try require(link.amount == expected, "A ribbon amount must equal its original contributors exactly")
            guard let detail = try graph.detail(for: .link(link.id)) else { throw Failure.assertion("Link detail is missing") }
            try require(detail.amount == link.amount && detail.transactionIDs == link.transactionIDs &&
                        detail.supportingIDs == link.supportingIDs &&
                        detail.allTransactionIDs == link.transactionIDs.union(link.supportingIDs),
                        "Link activation must expose every contributor and supporting record")
        }
        try require(used == graph.transactionIDs, "Graph occurrence membership must equal its links")
        for node in graph.nodes {
            let incoming = graph.links.filter { $0.targetID == node.id }
            let outgoing = graph.links.filter { $0.sourceID == node.id }
            let incomingAmount = try incoming.reduce(zero) { try $0 + $1.amount }
            let outgoingAmount = try outgoing.reduce(zero) { try $0 + $1.amount }
            let contributors = Set((incoming + outgoing).flatMap(\.transactionIDs))
            let support = Set((incoming + outgoing).flatMap(\.supportingIDs)).subtracting(contributors)
            try require(node.incoming == incomingAmount && node.outgoing == outgoingAmount &&
                        node.transactionIDs == contributors && node.supportingIDs == support,
                        "Node totals must preserve recorded incoming and outgoing sides without balancing them")
            guard let detail = try graph.detail(for: .node(node.id)) else { throw Failure.assertion("Node detail is missing") }
            try require(detail.incoming == incomingAmount && detail.outgoing == outgoingAmount &&
                        detail.allTransactionIDs == contributors.union(support),
                        "Node activation must expose exact amounts and complete record drill-down")
            if isActual && node.isAccount && node.incoming != node.outgoing { observed.insert(.unequalRecordedAccountSides) }
        }
        let missing = UUID().uuidString
        if try graph.detail(for: .node(missing)) != nil || graph.detail(for: .link(missing)) != nil {
            throw Failure.assertion("A stale selection must not resolve to an unrelated record")
        }
    }

    private static func magnitude(_ row: SpendingSourceRow) throws -> Money {
        try Money(amount: abs(row.transaction.money.amount), currency: row.transaction.money.currency)
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure.assertion(message) }
    }
}
