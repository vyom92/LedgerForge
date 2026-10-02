import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct PlanningIntelligenceTests {

    @Test func retainedRecurringIdentitySurvivesDueDayChangesWithinAndAcrossSalaryWindows() throws {
        let month = try SelectedStatementMonth(canonical: "2026-10")
        let retained = try StatementDate(canonical: "2026-10-20")
        let movedWithinWindow = try StatementDate(canonical: "2026-10-22")
        let movedAcrossWindow = try StatementDate(canonical: "2026-10-27")
        let identities: Set<String> = ["commitment:" + retained.canonical]
        for generated in [movedWithinWindow, movedAcrossWindow] {
            #expect(PlanningIntelligence.occurrenceDates(definitionID: "commitment", month: month,
                generatedDate: generated, retaining: identities) == [retained])
        }
        let nextMonth = try SelectedStatementMonth(canonical: "2026-11")
        let nextDate = try StatementDate(canonical: "2026-11-27")
        #expect(PlanningIntelligence.occurrenceDates(definitionID: "commitment", month: nextMonth,
            generatedDate: nextDate, retaining: identities) == [nextDate])
    }

    @Test func retainedRecurringIdentityKeepsShortMonthDateAndAllExistingOwnership() throws {
        let month = try SelectedStatementMonth(canonical: "2027-02")
        let savedDate = try StatementDate(canonical: "2027-02-28")
        let revisedDate = try StatementDate(canonical: "2027-02-20")
        let ids: Set<String> = ["commitment:" + savedDate.canonical, "other:" + revisedDate.canonical, "invalid"]
        #expect(PlanningIntelligence.occurrenceDates(definitionID: "commitment", month: month,
            generatedDate: revisedDate, retaining: ids) == [savedDate])
        #expect(PlanningIntelligence.occurrenceDates(definitionID: "unowned", month: month,
            generatedDate: revisedDate, retaining: ids) == [revisedDate])
        let anotherSavedDate = try StatementDate(canonical: "2027-02-21")
        #expect(PlanningIntelligence.occurrenceDates(definitionID: "commitment", month: month,
            generatedDate: revisedDate, retaining: ids.union(["commitment:" + anotherSavedDate.canonical])) == [anotherSavedDate, savedDate])
    }

    @Test func recurringExclusionPrecedenceKeepsOtherMonthsAndHonorsExplicitReadd() throws {
        let september = try SelectedStatementMonth(canonical: "2026-09")
        let october = try SelectedStatementMonth(canonical: "2026-10")
        let november = try SelectedStatementMonth(canonical: "2026-11")
        let original: Set<String> = ["commitment:2026-10-20"]
        let resolved = PlanningIntelligence.resolvedOccurrenceIDs(currentMonth: october, currentIDs: [],
            savedByMonth: [september: original, october: ["stale-current"], november: ["stale-draft"]],
            draftByMonth: [november: []])
        #expect(resolved == original)
        #expect(PlanningIntelligence.resolvedOccurrenceIDs(currentMonth: september, currentIDs: [],
            savedByMonth: [september: original], draftByMonth: [:]).isEmpty)
    }

    @Test func retainedRecurringOwnershipIncludesIncompleteOtherMonthDrafts() throws {
        let september = try SelectedStatementMonth(canonical: "2026-09")
        let october = try SelectedStatementMonth(canonical: "2026-10")
        let original = try StatementDate(canonical: "2026-10-20")
        let moved = try StatementDate(canonical: "2026-10-27")
        let id = "commitment:" + original.canonical
        let retained = PlanningIntelligence.resolvedOccurrenceIDs(currentMonth: october, currentIDs: [],
            savedByMonth: [october: ["stale-current"]], draftByMonth: [september: [id]])
        #expect(retained == [id])
        #expect(PlanningIntelligence.occurrenceDates(definitionID: "commitment", month: october,
            generatedDate: moved, retaining: retained) == [original])
        #expect(PlanningIntelligence.resolvedOccurrenceIDs(currentMonth: september, currentIDs: [],
            savedByMonth: [september: [id]], draftByMonth: [september: [id]]).isEmpty)
    }

    @Test func recurringRemovalKeepsReviewIdentityWhileExcludingMonthlyCashAndAutomaticInclusion() throws {
        let october = try SelectedStatementMonth(canonical: "2026-10")
        let original = try StatementDate(canonical: "2026-10-20")
        let moved = try StatementDate(canonical: "2026-10-27")
        let id = "commitment:" + original.canonical, excluded: Set<String> = [id]
        for generated in [original, moved] {
            let review = PlanningIntelligence.occurrenceSelections(definitionID: "commitment", month: october,
                generatedDate: generated, retaining: [], excluding: excluded)
            #expect(review == [.init(id: id, date: original, isExcludedFromPlan: true)])
        }
        let reapplied = PlanningIntelligence.occurrenceSelections(definitionID: "commitment", month: october,
            generatedDate: moved, retaining: [id], excluding: [])
        #expect(reapplied == [.init(id: id, date: original, isExcludedFromPlan: false)])
        let november = try SelectedStatementMonth(canonical: "2026-11")
        let next = try StatementDate(canonical: "2026-11-27")
        #expect(PlanningIntelligence.occurrenceSelections(definitionID: "commitment", month: november,
            generatedDate: next, retaining: [], excluding: excluded) == [.init(id: "commitment:" + next.canonical, date: next, isExcludedFromPlan: false)])
    }
    private struct OwnerCategoryNomination: Decodable {
        let categoryID: String, categoryName: String
        let rule: CategoryRule
        let expectedTransactionIDs: [String]
    }
    private let stamp = "2026-09-21T00:00:00Z"

    @Test(.globalRuntimeStateIsolation)
    func importedPayslipProposalPreservesDraftsAndSavesItsSourceLinkExactlyOnce() async throws {
        let root = try folder(), target = root.appendingPathComponent("qualification.sqlite")
        let sourceURL = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_S99_REVIEW_LEDGER"]))
        let source = try AuthenticSourceTestSupport.readOnlyRegisteredProvider(at: sourceURL)
        try source.database.createBackup(at: target.path); source.database.close()
        let sqlite = try SQLiteRepositoryProvider(path: target.path)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false)
        let snapshot = try hydrator.stageHydration()
        let statement = try #require(snapshot.salaryStatements.filter { $0.evidence.kind == .regularSalary }.max { $0.evidence.financialPeriod < $1.evidence.financialPeriod })
        let month = statement.evidence.financialPeriod
        let salaryCredit = try #require(snapshot.transactions.filter {
            $0.currency == "QAR" && $0.creditMoney != nil && $0.description.uppercased().hasPrefix("SALARY TRANSFER") && $0.description.uppercased().contains("QATAR AIRWAYS")
        }.max { ($0.statementDate?.canonical ?? "") < ($1.statementDate?.canonical ?? "") })
        let accountID = try #require(salaryCredit.repositoryAccountId)
        let beforeFacts = try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace)
        let oldPreferences = snapshot.intelligence?.preferences
        var preferences = oldPreferences ?? .init(workspaceID: workspace)
        preferences.salaryAssistanceEnabled = true; preferences.excludedPlanningAccountIDs = []
        try sqlite.intelligenceRepo.applyPlanning(.preferences(preferences, replacing: oldPreferences))
        hydrator.publish(try hydrator.stageHydration())
        let today = try StatementDate(year: month.year, month: month.month, day: 28)
        let model = SalaryWorkspaceViewModel(month: month, workspaceID: workspace, provider: { provider },
            now: { FinancialCalendar.instant(today)! }, refresh: { _ in hydrator.publish(try hydrator.stageHydration()) })
        let initial = model.plan
        #expect(model.payslipProposals.map(\.id) == [statement.id])
        #expect(model.plan == initial, "Discovery must not edit the existing plan")
        #expect(model.updateMoney(.fixed, text: "17"))
        let next = model.nextPlanningMonth
        model.switchMonth(to: next); #expect(model.updateMoney(.variable, text: "23"))
        model.switchMonth(to: month)
        #expect(model.moneyText(.fixed) == "17")
        model.captureAccountBalance(try #require(snapshot.accounts.first { $0.repositoryAccountId == accountID }))
        #expect(model.applyPayslip(statement, accountID: accountID))
        #expect(model.plan.expectedFixedEarnings.amount == 0 && model.plan.expectedVariableEarnings.amount == 0 && model.plan.deductions.isEmpty)
        #expect(model.plan.qatarCommitments == initial.qatarCommitments && model.plan.indiaCommitments == initial.indiaCommitments)
        #expect(model.payslipReceiptState == .pending)
        #expect(model.calculation.expectedNet == statement.evidence.printedNet)
        #expect(model.payslipProposals.isEmpty)
        #expect(!model.applyPayslip(statement, accountID: accountID), "Applying the same source twice is a no-op")
        model.switchMonth(to: next); #expect(model.moneyText(.variable) == "23")
        model.switchMonth(to: month)
        model.save()
        #expect(model.saveState == .saved)
        let saved = try #require(sqlite.fundingPlanRepo.plans(workspaceId: workspace).first { $0.planMonthISO == month.canonical })
        #expect(saved.assistance?.payslipFunding?.statementID == statement.id)
        #expect(saved.assistance?.payslipFunding?.fingerprintDigest == statement.fingerprintDigest)
        #expect(try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace) == beforeFacts)
        var invalid = saved
        invalid.assistance?.payslipFunding?.fingerprintDigest = String(repeating: "0", count: 64)
        #expect(throws: FinancialIntelligenceError.invalidRecord) { try sqlite.fundingPlanRepo.savePlan(invalid) }
        #expect(try sqlite.fundingPlanRepo.plans(workspaceId: workspace).first { $0.planMonthISO == month.canonical } == saved)
        let balance = try #require(saved.balances.first { $0.accountId == accountID && $0.included })
        let balanceAmount = try PlanningAmount(Money(canonicalDecimal: #require(balance.amountDecimal), currency: #require(balance.amountCurrency)))
        let balanceDate = try #require(balance.financialBalanceDateISO)
        let exactAcknowledgement = PayslipBalanceAcknowledgement(balanceID: balance.id, amount: balanceAmount, financialDate: balanceDate)
        let metadata = try #require(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace))
        var acknowledged = saved
        acknowledged.assistance?.payslipFunding?.balanceAcknowledgement = exactAcknowledgement
        #expect(throws: FinancialIntelligenceError.invalidRecord) {
            try PlanningMetadataValidation.validatePlanLinks(acknowledged, snapshot: metadata)
        }
        var premature = model.plan
        premature.assistance?.payslipFunding?.balanceAcknowledgement = exactAcknowledgement
        #expect(PayslipReceiptState.resolve(plan: premature, transactions: []) == .needsReview,
            "An exact balance acknowledgment still cannot precede the expected payday")
        // Change only the editable expected payday; the genuine captured bank
        // balance and its source date remain intact.
        let capturedDay = try StatementDate(canonical: balanceDate)
        #expect(capturedDay.year == month.year && capturedDay.month == month.month)
        acknowledged.assistance?.salaryCycle = SalaryFundingCycle.expected(month: month, day: capturedDay.day)
        try PlanningMetadataValidation.validatePlanLinks(acknowledged, snapshot: metadata)
        premature.assistance?.salaryCycle = acknowledged.assistance?.salaryCycle
        #expect(PayslipReceiptState.resolve(plan: premature, transactions: []) == .acknowledgedBalance)
        var missingCycle = acknowledged
        missingCycle.assistance?.salaryCycle = nil
        #expect(throws: FinancialIntelligenceError.invalidRecord) {
            try PlanningMetadataValidation.validatePlanLinks(missingCycle, snapshot: metadata)
        }
        for acknowledgement in [
            PayslipBalanceAcknowledgement(balanceID: UUID().uuidString, amount: balanceAmount, financialDate: balanceDate),
            PayslipBalanceAcknowledgement(balanceID: balance.id, amount: try PlanningAmount(statement.evidence.printedNet), financialDate: balanceDate),
            PayslipBalanceAcknowledgement(balanceID: balance.id, amount: balanceAmount, financialDate: today.canonical)
        ] {
            var corrupt = saved
            corrupt.assistance?.payslipFunding?.balanceAcknowledgement = acknowledgement
            #expect(throws: FinancialIntelligenceError.invalidRecord) { try sqlite.fundingPlanRepo.savePlan(corrupt) }
            #expect(try sqlite.fundingPlanRepo.plans(workspaceId: workspace).first { $0.planMonthISO == month.canonical } == saved)
        }
        // The scratchpad preserves an incomplete owner entry through the same
        // populated backup, without changing the last valid plan or source facts.
        #expect(!model.updateMoney(.fee, text: "25."))
        model.flushPendingEntries()
        let retainedScratchpads = try sqlite.fundingPlanRepo.scratchpads(workspaceId: workspace)
        let retainedMonthly = try #require(retainedScratchpads.first { $0.month == month.canonical })
        #expect(try MonthlyPlanScratchpad.decode(retainedMonthly).rawText["fee"] == "25.")
        DatabaseProvider.shared = provider
        let backup = BackupRestoreCoordinator(testingAt: target); backup.installTestProvider(sqlite)
        let destination = root.appendingPathComponent("backups"); try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        await backup.createBackup(to: destination)
        let package = try #require(backup.lastBackupURL), manifest = try BackupFiles.verifyPackage(package)
        let restoredURL = root.appendingPathComponent("restored.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: restoredURL)
        let restored = try SQLiteRepositoryProvider(path: restoredURL.path)
        defer { restored.database.close() }
        #expect(try restored.fundingPlanRepo.plans(workspaceId: workspace).first { $0.planMonthISO == month.canonical } == saved)
        #expect(try restored.transactionRepo.trustedTransactions(workspaceId: workspace) == beforeFacts)
        #expect(try restored.fundingPlanRepo.scratchpads(workspaceId: workspace) == retainedScratchpads)
        hydrator.publish(try hydrator.stageHydration())
        let refreshed = SalaryWorkspaceViewModel(month: month, workspaceID: workspace, provider: { provider }, now: { FinancialCalendar.instant(today)! })
        #expect(refreshed.payslipProposals.isEmpty)
        #expect(refreshed.calculation.expectedNet == statement.evidence.printedNet)
        #expect(refreshed.moneyText(.fee) == "25.")

        // Exercise receipt precedence with an actual earlier payslip and its
        // genuine bank credit. Only the owner's planning acknowledgment changes.
        let creditDate = try #require(salaryCredit.statementDate)
        let receivedMonth = try SelectedStatementMonth(canonical: String(creditDate.canonical.prefix(7)))
        let receivedSlip = try #require(snapshot.salaryStatements.first {
            $0.evidence.kind == .regularSalary && $0.evidence.financialPeriod == receivedMonth && $0.evidence.printedNet == salaryCredit.money
        })
        var received = SalaryWorkspaceViewModel(month: receivedMonth, workspaceID: workspace, provider: { provider }).plan
        received.balances = model.plan.balances.filter { $0.accountID == accountID }
        received.assistance = .init(workspaceID: workspace, month: receivedMonth.canonical, salaryCycle: SalaryFundingCycle.expected(month: receivedMonth))
        received.assistance?.payslipFunding = .init(statementID: receivedSlip.id, fingerprintAlgorithm: receivedSlip.fingerprintAlgorithm,
            fingerprintDigest: receivedSlip.fingerprintDigest, accountID: accountID, net: try PlanningAmount(receivedSlip.evidence.printedNet))
        let beforeCredit = try #require(FinancialCalendar.addDays(-1, to: creditDate))
        received.balances[0].financialBalanceDate = beforeCredit
        received.assistance?.payslipFunding?.balanceAcknowledgement = .init(balanceID: received.balances[0].id,
            amount: balanceAmount, financialDate: beforeCredit.canonical)
        #expect(PayslipReceiptState.resolve(plan: received, transactions: []) == .acknowledgedBalance)
        #expect(PayslipReceiptState.resolve(plan: received, transactions: snapshot.transactions) ==
            .bankCredit(id: salaryCredit.repositoryTransactionId!, date: creditDate, includedInBalance: false))
        received.balances[0].financialBalanceDate = try StatementDate(canonical: balanceDate)
        #expect(PayslipReceiptState.resolve(plan: received, transactions: snapshot.transactions) ==
            .bankCredit(id: salaryCredit.repositoryTransactionId!, date: creditDate, includedInBalance: true))
    }

    @Test func salaryFundingDatesSeparateIssuedBillsFromUpcomingPayments() throws {
        let month = try SelectedStatementMonth(canonical: "2026-09")
        let cycle = try #require(SalaryFundingCycle.expected(month: month))
        try cycle.validated(month: month.canonical)
        #expect(cycle.previousPayday == "2026-08-25")
        #expect(cycle.payday == "2026-09-25")
        #expect(cycle.nextPayday == "2026-10-25")
        for (date, included) in [("2026-08-25", false), ("2026-08-26", true), ("2026-09-25", true), ("2026-09-26", false)] {
            #expect(cycle.includesBill(issuedOn: try StatementDate(canonical: date)) == included)
        }
        for (date, included) in [("2026-09-24", false), ("2026-09-25", true), ("2026-10-01", true), ("2026-10-20", true), ("2026-10-24", true), ("2026-10-25", false)] {
            #expect(cycle.includesRecurring(dueOn: try StatementDate(canonical: date)) == included)
        }
        let leap = try #require(SalaryFundingCycle.expected(month: try SelectedStatementMonth(canonical: "2028-02"), day: 31))
        #expect(leap.previousPayday == "2028-01-31" && leap.payday == "2028-02-29" && leap.nextPayday == "2028-03-31")
        let shorter = try #require(SalaryFundingCycle.expected(month: try SelectedStatementMonth(canonical: "2027-02"), day: 31))
        #expect(shorter.payday == "2027-02-28")
        #expect(SalaryFundingCycle.expected(month: month, day: 0) == nil)
        var invalid = cycle; invalid.nextPayday = "2026-09-25"
        #expect(throws: FinancialIntelligenceError.invalidRecord) { try invalid.validated(month: month.canonical) }
        let legacy = PlanAssistance(workspaceID: "date-mechanics", month: month.canonical)
        let roundTrip = try JSONDecoder().decode(PlanAssistance.self, from: JSONEncoder().encode(legacy))
        #expect(roundTrip.salaryCycle == nil)
        #expect(roundTrip.includesRecurring(try StatementDate(canonical: "2026-09-01")))
        #expect(!roundTrip.includesRecurring(try StatementDate(canonical: "2026-10-01")))
        // Owner-edited preceding paydays cannot silently leave a gap or an
        // overlap in an already-created following bill window.
        for day in [24, 26] {
            let revised = try #require(SalaryFundingCycle.expected(month: month, day: day))
            let previousPlan = PlanAssistance(workspaceID: "date-mechanics", month: month.canonical, salaryCycle: revised)
            let metadata = FinancialIntelligenceSnapshot(workspaceID: "date-mechanics", plans: [previousPlan])
            var following = try #require(SalaryFundingCycle.expected(month: SelectedStatementMonth(canonical: "2026-10")))
            #expect(following.needsPreviousBoundaryReview(in: metadata))
            following.previousPayday = try #require(following.previousSavedPayday(in: metadata))
            try following.validated(month: "2026-10")
            #expect(!following.needsPreviousBoundaryReview(in: metadata))
            #expect(!following.includesBill(issuedOn: revised.recurringStart))
            #expect(following.includesBill(issuedOn: try #require(FinancialCalendar.addDays(1, to: revised.recurringStart))))
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func genuineUndatedCardStatementsRemainVisibleForSalaryFundingReview() throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let metadata = try #require(snapshot.intelligence)
        let undated = snapshot.cardSnapshot.statements.filter { $0.statementDate == nil && ($0.newBalance?.amount ?? 0) > 0 }
        #expect(!undated.isEmpty, "The authentic Axis corpus exercises unknown bill generation dates")
        let accountAnchors = anchors(snapshot)
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot)
        var selected = try draft(workspace: workspace, month: SelectedStatementMonth(canonical: "2026-09"))
        selected.assistance = .init(workspaceID: workspace, month: selected.month.canonical, salaryCycle: SalaryFundingCycle.expected(month: selected.month))
        let before = try NetWorthTestSupport.financialDigest(sqlite.database)
        let projection = try PlanningIntelligence.project(plan: selected, anchors: accountAnchors, rows: rows, metadata: metadata,
            sources: snapshot.financialSources, cards: snapshot.cardSnapshot, today: StatementDate(canonical: "2026-09-22"))
        for account in accountAnchors where undated.contains(where: { $0.liabilityAccountID == account.id }) && !account.historyOnly {
            #expect(projection.cardNeeds.contains { $0.hasPrefix(account.title + ":") && $0.contains("no bill generation date") })
        }
        // Hiding the genuine card accounts from planning must not erase their
        // unresolved payment needs or make bank cash appear investable.
        var removedCards = metadata
        var preferences = metadata.preferences ?? .init(workspaceID: workspace)
        preferences.excludedPlanningAccountIDs = Set(accountAnchors.filter { $0.domain == "credit_card" }.map(\.id))
        removedCards.preferences = preferences
        let hiddenProjection = try PlanningIntelligence.project(plan: selected, anchors: accountAnchors, rows: rows, metadata: removedCards,
            sources: snapshot.financialSources, cards: snapshot.cardSnapshot, today: StatementDate(canonical: "2026-09-22"))
        #expect(hiddenProjection.cardNeeds == projection.cardNeeds)
        for bank in accountAnchors where bank.domain == "bank" {
            #expect(hiddenProjection.investmentCapacity(accountID: bank.id, assistance: selected.assistance).0 == nil)
        }
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database) == before)
    }

    @Test(.globalRuntimeStateIsolation)
    func planningAccountAvailabilityPersistsWithoutChangingImportedAccountsOrSavedPlans() async throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false)
        let initial = try hydrator.stageHydration()
        let bank = try #require(initial.accounts.first { $0.type == .bank && $0.currencyCode == "QAR" && $0.currentBalanceAsOfISO != nil })
        let id = try #require(bank.repositoryAccountId)
        let old = try #require(initial.intelligence)
        let digest = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["intelligence_preferences"])
        var preferences = old.preferences ?? .init(workspaceID: workspace)
        preferences.excludedPlanningAccountIDs = [id]
        try sqlite.intelligenceRepo.applyPlanning(.preferences(preferences, replacing: old.preferences))
        let hidden = try hydrator.stageHydration()
        hydrator.publish(hidden)
        let model = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(canonical: "2026-09"), workspaceID: workspace, provider: { provider })
        #expect(!model.eligibleAccounts.contains { $0.repositoryAccountId == id })
        #expect(model.availablePlanningAccounts.contains { $0.repositoryAccountId == id })
        #expect(hidden.accounts.map(\.repositoryAccountId) == initial.accounts.map(\.repositoryAccountId))
        #expect(hidden.accounts.map(\.currentBalanceMoney) == initial.accounts.map(\.currentBalanceMoney))
        #expect(hidden.transactions.map(\.id) == initial.transactions.map(\.id))
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["intelligence_preferences"]) == digest)
        var selected = try draft(workspace: workspace, month: try SelectedStatementMonth(canonical: "2026-09"))
        selected.balances = [.init(id: "planning-selection", accountID: id, nativeCurrency: bank.nativeCurrency, included: true, money: bank.currentBalanceMoney, provenance: .manual)]
        #expect(FundingPlanCalculator.calculate(selected).selectedQARLiquidity == bank.currentBalanceMoney)
        #expect(FundingPlanCalculator.calculate(selected, excludingAccounts: [id]).selectedQARLiquidity?.amount == 0)
        #expect(selected.balances.count == 1, "Removing from planning retains the saved selection for Add back")
        DatabaseProvider.shared = provider
        let backup = BackupRestoreCoordinator(testingAt: root.appendingPathComponent("qualification.sqlite")); backup.installTestProvider(sqlite)
        let destination = root.appendingPathComponent("backups"); try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        await backup.createBackup(to: destination)
        let package = try #require(backup.lastBackupURL), manifest = try BackupFiles.verifyPackage(package)
        let restoredURL = root.appendingPathComponent("restored.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: restoredURL)
        let restored = try SQLiteRepositoryProvider(path: restoredURL.path)
        defer { restored.database.close() }
        #expect(try restored.intelligenceRepo.snapshot(workspaceID: workspace)?.preferences == preferences)
        #expect(try NetWorthTestSupport.financialDigest(restored.database, excluding: ["intelligence_preferences"]) == digest)
        // Making this provider current for Backup may seed its public FX/price
        // caches from the app's existing cache. Freeze that separate binding
        // outcome before proving the Add back mutation changes only preferences.
        let afterBackup = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["intelligence_preferences"])
        var included = preferences; included.excludedPlanningAccountIDs = []
        try sqlite.intelligenceRepo.applyPlanning(.preferences(included, replacing: preferences))
        hydrator.publish(try hydrator.stageHydration())
        #expect(model.eligibleAccounts.contains { $0.repositoryAccountId == id })
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["intelligence_preferences"]) == afterBackup)
    }
    @Test(.globalRuntimeStateIsolation)
    func populatedV28BackupPreservesPlansWithoutInventingBalanceDates() throws {
        let source = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_S99_V28_BACKUP"]))
        let manifest = try BackupFiles.verifyPackage(source)
        #expect(manifest.schemaVersion == 28)
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let oldURL = root.appendingPathComponent("prior.sqlite")
        try FileManager.default.copyItem(at: source.appendingPathComponent("ledger.sqlite"), to: oldURL)
        let old = try SQLiteRepositoryProvider(path: oldURL.path, migrations: Array(allMigrations.prefix(28)), access: .existing)
        defer { old.database.close() }
        let workspace = try #require(old.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let plans = try old.fundingPlanRepo.plans(workspaceId: workspace)
        #expect(!plans.isEmpty)
        #expect(plans.flatMap(\.balances).contains { $0.amountDecimal != nil })
        #expect(plans.flatMap(\.balances).allSatisfy { $0.financialBalanceDateISO == nil })
        let before = try #require(try old.intelligenceRepo.snapshot(workspaceID: workspace))
        var changed = before.preferences ?? .init(workspaceID: workspace)
        changed.salaryAssistanceEnabled.toggle()
        // A V28 metadata edit also validates existing plans; it cannot read the
        // V29 date column before the normal forward migration has happened.
        try old.intelligenceRepo.applyPlanning(.preferences(changed, replacing: before.preferences))
        #expect(try old.intelligenceRepo.snapshot(workspaceID: workspace)?.preferences == changed)
        let upgradedURL = root.appendingPathComponent("upgraded.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: source, manifest: manifest, destination: upgradedURL)
        let upgraded = try SQLiteRepositoryProvider(path: upgradedURL.path, migrations: allMigrations, access: .existing)
        #expect(try upgraded.fundingPlanRepo.plans(workspaceId: workspace) == plans)
        #expect(try upgraded.intelligenceRepo.snapshot(workspaceID: workspace) == before)
        let provider = DatabaseProvider.verifiedSQLite(upgraded)
        DatabaseProvider.shared = provider
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false)
        let snapshot = try hydrator.stageHydration()
        hydrator.publish(snapshot)
        let monthly = try #require(snapshot.fundingPlans.first)
        let model = SalaryWorkspaceViewModel(month: monthly.month, workspaceID: workspace, provider: { provider })
        model.plannerOpened()
        let reservedAccountIDs = Set(before.reserves.filter { $0.kind == .accountCash }.compactMap(\.accountID))
        let bankCandidates = snapshot.accounts.filter { account in
            guard account.type == .bank, account.currencyCode == "INR",
                  let accountID = account.repositoryAccountId else { return false }
            return account.currentBalanceMoney.amount > Decimal.zero && reservedAccountIDs.contains(accountID)
        }
        let bank = try #require(bankCandidates.first)
        model.setAccountIncluded(bank, included: true)
        model.captureAccountBalance(bank)
        let selected = model.plan.balances.filter { $0.included && $0.nativeCurrency.code == "INR" }.compactMap(\.money)
        #expect(!selected.isEmpty)
        #expect(model.calculation.selectedINRLiquidity == (try Money.aggregate(selected)),
                "Saved reserve targets must not reduce the Monthly plan's selected bank balances")
        model.flushPendingEntries()
        let retainedPlans = try upgraded.fundingPlanRepo.plans(workspaceId: workspace)
        let retainedMonthly = try #require(retainedPlans.first { $0.planMonthISO == monthly.month.canonical })
        #expect(try retainedMonthly.balances.first { $0.accountId == bank.repositoryAccountId }?.amountDecimal == bank.currentBalanceMoney.canonicalDecimalString())
        try upgraded.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: upgradedURL.path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        #expect(try reopened.fundingPlanRepo.plans(workspaceId: workspace) == retainedPlans)
        #expect(try BackupFiles.verifyPackage(source) == manifest)
    }

    @Test func existingPreferencesDecodeWithoutInventingPatternDecisions() throws {
        let old = Data(#"{"workspaceID":"owner-preferences","salaryRuleIDs":[],"salaryAssistanceEnabled":true,"salaryISPEnabled":false,"salaryISPMinuteUTC":0}"#.utf8)
        let decoded = try JSONDecoder().decode(IntelligencePreferences.self, from: old)
        #expect(decoded.recurringCandidateDecisions == nil)
        #expect(decoded.excludedPlanningAccountIDs == nil)
        let left = PlanningIntelligence.recurringCandidateKey(accountID: "a|b", currency: "INR", amount: 1, narration: "c")
        let right = PlanningIntelligence.recurringCandidateKey(accountID: "a", currency: "INR", amount: 1, narration: "b|c")
        #expect(left != right)
    }

    @Test(.globalRuntimeStateIsolation)
    func genuineRepeatedPatternDecisionsPersistAndConfirmationIsAtomic() async throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let editedMetadata: Set<String> = ["intelligence_preferences", "recurring_definitions"]
        let before = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: editedMetadata)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot)
        let original = try #require(snapshot.intelligence)
        let candidate = try #require(try PlanningIntelligence.recurringCandidates(rows: rows, metadata: original).first)
        let old = original.preferences
        var dismissed = old ?? .init(workspaceID: workspace)
        dismissed.recurringCandidateDecisions = [candidate.id: .dismissed]
        try sqlite.intelligenceRepo.applyPlanning(.preferences(dismissed, replacing: old))
        let saved = try #require(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace))
        #expect(try PlanningIntelligence.recurringCandidates(rows: rows, metadata: saved).first { $0.id == candidate.id }?.decision == .dismissed)
        var reconsidered = dismissed; reconsidered.recurringCandidateDecisions = [:]
        try sqlite.intelligenceRepo.applyPlanning(.preferences(reconsidered, replacing: dismissed))
        let definition = RecurringDefinition(id: UUID().uuidString, workspaceID: workspace, accountID: candidate.accountID,
            title: "Reviewed genuine repeated payment", revisions: [.init(effectiveFrom: "2026-09-21", dueDay: candidate.dates.last!.day,
                amount: try PlanningAmount(Money(amount: candidate.amount, currency: candidate.currency)))], predicates: [.init(field: .narration, match: .exact, text: candidate.narration)])
        #expect(throws: FinancialIntelligenceError.staleReview) {
            try sqlite.intelligenceRepo.applyPlanning(.confirmRecurringCandidate(definition, key: candidate.id, replacingPreferences: dismissed))
        }
        #expect(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace)?.recurring == original.recurring)
        try sqlite.intelligenceRepo.applyPlanning(.confirmRecurringCandidate(definition, key: candidate.id, replacingPreferences: reconsidered))
        let confirmed = try #require(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace))
        #expect(confirmed.preferences?.recurringCandidateDecisions?[candidate.id] == .confirmed(definitionID: definition.id))
        #expect(confirmed.recurring.first { $0.id == definition.id } == definition)
        #expect(confirmed.recurring.filter { $0.id != definition.id } == original.recurring)
        #expect(confirmed.occurrences == original.occurrences, "Confirming a template does not claim any historical payment")
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database, excluding: editedMetadata) == before)
        DatabaseProvider.shared = provider
        let backup = BackupRestoreCoordinator(testingAt: root.appendingPathComponent("qualification.sqlite")); backup.installTestProvider(sqlite)
        let destination = root.appendingPathComponent("backups"); try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        await backup.createBackup(to: destination)
        let package = try #require(backup.lastBackupURL), manifest = try BackupFiles.verifyPackage(package)
        let restored = root.appendingPathComponent("restored.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: restored)
        let reopened = try SQLiteRepositoryProvider(path: restored.path)
        defer { reopened.database.close() }
        #expect(try reopened.intelligenceRepo.snapshot(workspaceID: workspace) == confirmed)
        #expect(try NetWorthTestSupport.financialDigest(reopened.database, excluding: editedMetadata) == before)
    }
    private func folder() throws -> URL {
        let value = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s99-planning-\(UUID())")
        try FileManager.default.createDirectory(at: value, withIntermediateDirectories: false)
        return value
    }
    private func copy(_ folder: URL) throws -> SQLiteRepositoryProvider {
        let path = try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_S99_V26_BACKUP"])
        let package = URL(fileURLWithPath: path), manifest = try BackupFiles.verifyPackage(package)
        let target = folder.appendingPathComponent("qualification.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: target)
        return try SQLiteRepositoryProvider(path: target.path)
    }
    private func plan(workspace: String, month: String, commitments: [FundingPlanCommitmentDTO] = []) -> FundingPlanDTO {
        // Explicit owner-planning values; no financial input is fabricated.
        .init(id: "plan:" + month, workspaceId: workspace, planMonthISO: month, rolloverSourcePlanId: nil,
            expectedFixedMinor: 0, expectedFixedDecimal: "0.00", expectedFixedProvenance: "manual",
            expectedVariableMinor: 0, expectedVariableDecimal: "0.00", expectedVariableProvenance: "manual",
            expectedDeductionsMinor: 0, expectedDeductionsDecimal: "0.00", expectedDeductionsProvenance: "manual",
            configuredFeeMinor: 0, configuredFeeDecimal: "0.00", configuredFeeProvenance: "manual",
            fxINRPerQARDecimal: nil, fxObservationDateISO: nil, plannedInvestmentMinor: 0, plannedInvestmentDecimal: "0.00",
            plannedInvestmentProvenance: "manual", updatedAtISO: stamp, balances: [], commitments: commitments)
    }
    private func draft(workspace: String, month: SelectedStatementMonth) throws -> FundingPlan {
        let zero = try Money(amount: 0, currency: "QAR")
        return .init(id: "owner-draft", workspaceID: workspace, month: month, expectedFixedEarnings: zero, expectedFixedProvenance: .manual,
            expectedVariableEarnings: zero, expectedVariableProvenance: .manual, expectedDeductions: zero, expectedDeductionsProvenance: .manual,
            balances: [], qatarCommitments: [], indiaCommitments: [], configuredTransferFee: zero, configuredTransferFeeProvenance: .manual,
            planningFX: nil, plannedInvestment: zero, plannedInvestmentProvenance: .manual, updatedAtISO: stamp)
    }
    private func anchors(_ snapshot: RepositoryRuntimeSnapshot) -> [PlanningAccountAnchor] {
        snapshot.accounts.compactMap { account in
            guard let id = account.repositoryAccountId else { return nil }
            return .init(id: id, title: account.preferredDisplayName, currency: account.currencyCode, domain: account.type == .bank ? "bank" : "credit_card",
                amount: account.currentBalanceAsOfISO == nil ? nil : account.currentBalance, date: account.currentBalanceAsOfISO.flatMap { try? StatementDate(canonical: String($0.prefix(10))) }, historyOnly: account.isHistoryOnly)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func cancelledPlanRefreshRestartsWithoutLosingCompletedNavigationCache() async throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        DatabaseProvider.shared = provider
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false)
        hydrator.publish(try hydrator.stageHydration())
        let plan = try draft(workspace: workspace, month: .init(year: 2026, month: 9))
        let model = PlanningAnalysisModel()
        defer { model.cancel() }
        model.refresh(plan: plan, scenario: .init())
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while model.isWorking && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.projection != nil)
        #expect(!model.isWorking)
        let beforeNavigation = try #require(model.projection)
        let worksheetBefore = FundingPlanCalculator.calculate(plan)
        model.cancel()
        model.refresh(plan: plan, scenario: .init())
        #expect(!model.isWorking, "A completed unchanged plan returns from the navigation cache")
        let afterNavigation = try #require(model.projection)
        #expect(FundingPlanCalculator.calculate(plan) == worksheetBefore)
        #expect(afterNavigation.start == beforeNavigation.start && afterNavigation.end == beforeNavigation.end)
        #expect(afterNavigation.actualSpending == beforeNavigation.actualSpending)
        #expect(afterNavigation.actualTransactionIDs == beforeNavigation.actualTransactionIDs)
        #expect(afterNavigation.plannedCommitments == beforeNavigation.plannedCommitments)
        #expect(afterNavigation.runways.map(\.id) == beforeNavigation.runways.map(\.id))
        for (before, after) in zip(beforeNavigation.runways, afterNavigation.runways) {
            #expect(after.anchor.amount == before.anchor.amount && after.anchor.date == before.anchor.date)
            #expect(after.points.map(\.balance) == before.points.map(\.balance))
            #expect(after.points.map(\.date) == before.points.map(\.date))
            #expect(after.points.map(\.transactionIDs) == before.points.map(\.transactionIDs))
            #expect(after.events.map(\.change) == before.events.map(\.change))
            #expect(after.reserveFloor == before.reserveFloor)
            #expect(afterNavigation.investmentCapacity(accountID: after.id, assistance: plan.assistance).0 == beforeNavigation.investmentCapacity(accountID: before.id, assistance: plan.assistance).0)
            #expect(afterNavigation.investmentCapacity(accountID: after.id, assistance: plan.assistance).1 == beforeNavigation.investmentCapacity(accountID: before.id, assistance: plan.assistance).1)
        }
        var changed = PlanningScenario(); changed.extraCost = 1
        model.refresh(plan: plan, scenario: changed)
        #expect(model.isWorking)
        model.cancel()
        model.refresh(plan: plan, scenario: changed)
        #expect(model.isWorking, "An interrupted new scenario cannot reuse the older completed projection")
    }

    @Test(.globalRuntimeStateIsolation)
    func cancelledHistoryAnalysisStopsWithoutPublishingPartialResults() async throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let metadata = try #require(snapshot.intelligence)
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot)
        let today = try StatementDate(canonical: "2026-09-21")
        let plan = try draft(workspace: workspace, month: .init(year: 2026, month: 9))
        let accountAnchors = anchors(snapshot)
        let transactions = snapshot.transactions, sources = snapshot.financialSources, cards = snapshot.cardSnapshot, categories = snapshot.categorySnapshot
        let checks = await Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            var cancelled = 0
            do { _ = try SpendingIntelligence.rows(transactions: transactions, sources: sources, cards: cards, categories: categories) }
            catch is CancellationError { cancelled += 1 } catch { }
            do { _ = try SpendingIntelligence.suggestions(rows: rows, metadata: metadata, sources: sources) }
            catch is CancellationError { cancelled += 1 } catch { }
            do { _ = try SpendingIntelligence.project(rows: rows, metadata: metadata, sources: sources, currency: "INR", accountIDs: [], start: nil, end: nil) }
            catch is CancellationError { cancelled += 1 } catch { }
            do { _ = try PlanningIntelligence.project(plan: plan, anchors: accountAnchors, rows: rows, metadata: metadata, sources: sources, cards: cards, today: today) }
            catch is CancellationError { cancelled += 1 } catch { }
            return cancelled
        }.value
        #expect(checks == 4)
    }

    @Test(.globalRuntimeStateIsolation)
    func populatedLedgerBatchReadRetainsEveryOrderedSourceLink() throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let before = try NetWorthTestSupport.financialDigest(sqlite.database)
        let start = ContinuousClock.now
        let trusted = try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace)
        print("Populated trusted transaction read: \(trusted.count) rows in \(start.duration(to: .now))")
        let all = try sqlite.transactionRepo.transactions(workspaceId: workspace, importSessionId: nil)
        #expect(!trusted.isEmpty)
        #expect(all.filter(\.isTrusted) == trusted)
        // Retain the prior per-parent source query as an independent read oracle.
        // These are genuine stored records, never manufactured statement DTOs.
        var sourceLinks = 0
        for transaction in trusted {
            let expected = try sqlite.database.query(sql: """
                SELECT r.id,r.normalized_row_id,r.contribution_type,n.row_index,n.record_digest,
                       n.normalized_document_id,d.profile_id,d.profile_version
                FROM transaction_raw_rows r JOIN normalized_rows n ON n.id=r.normalized_row_id
                JOIN normalized_documents d ON d.id=n.normalized_document_id
                WHERE r.transaction_id=? ORDER BY n.row_index,r.id;
                """, params: [transaction.id]) { row in (0..<8).map { row.string(at: $0) } }
            let actual: [[String?]] = transaction.rawRows.map {
                [$0.id, $0.normalizedRowId, $0.contributionType, $0.sourceOrdinal.map(String.init),
                 $0.normalizedRecordDigest, $0.normalizedDocumentId, $0.parserProfileId, $0.parserProfileVersion]
            }
            #expect(actual == expected)
            sourceLinks += expected.count
        }
        #expect(sourceLinks == (try sqlite.database.queryInt("SELECT COUNT(*) FROM transaction_raw_rows r JOIN transactions t ON t.id=r.transaction_id WHERE t.is_trusted=1;")))
        for session in Set(trusted.compactMap(\.importSessionId)).sorted() {
            #expect(try sqlite.transactionRepo.transactions(workspaceId: workspace, importSessionId: session) == all.filter { $0.importSessionId == session })
        }
        #expect(try sqlite.transactionRepo.trustedTransactions(workspaceId: "absent-workspace").isEmpty)
        #expect(try sqlite.transactionRepo.transactions(workspaceId: workspace, importSessionId: "absent-session").isEmpty)
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database) == before)
    }

    @Test(.globalRuntimeStateIsolation)
    func genuinePaymentAfterPrefillReducesForecastAndMonthOverrideSurvivesTemplateChange() throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot)
        let nominations = try JSONDecoder().decode([OwnerCategoryNomination].self,
            from: AuthenticSourceTestSupport.ramNomination("LEDGERFORGE_S99_CATEGORY_OWNER_DATA"))
        let nominatedIDs = Set(try #require(nominations.first { $0.categoryName == "India rent" }).expectedTransactionIDs)
        let payment = try #require(rows.first { nominatedIDs.contains($0.id) && $0.isBankOut && $0.currency == "INR" })
        let day = try #require(payment.date), month = try SelectedStatementMonth(year: day.year, month: day.month)
        let definition = RecurringDefinition(id: "owner-rent", workspaceID: workspace, accountID: payment.accountID, title: "Owner planning test",
            revisions: [.init(effectiveFrom: day.canonical, dueDay: day.day, amount: .init(currency: "INR", decimal: "99999.00"))], predicates: [])
        var metadata = try #require(snapshot.intelligence); metadata.recurring = [definition]
        var draft = try draft(workspace: workspace, month: month)
        let amount = try Money(amount: payment.amount + 100, currency: "INR")
        draft.indiaCommitments = [.init(id: "rent-row", label: "This month override", money: amount, included: true, fundingAccountID: payment.accountID, provenance: .manual, recurs: false, dueDate: day)]
        let occurrenceID = definition.id + ":" + day.canonical
        draft.assistance = .init(workspaceID: workspace, month: month.canonical, appliedRecurringIDs: [occurrenceID: "rent-row"], appliedRecurringPaid: [occurrenceID: .init(currency: "INR", decimal: "0.00")])
        func project() throws -> RecurringPaymentProjection {
            let value = try PlanningIntelligence.project(plan: draft, anchors: anchors(snapshot), rows: rows, metadata: metadata, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, today: day)
            return try #require(value.recurring.first { $0.id == occurrenceID })
        }
        #expect(try project().remaining == amount.amount)
        metadata.occurrences = [.init(id: occurrenceID, workspaceID: workspace, definitionID: definition.id, dueDate: day.canonical, transactionIDs: [payment.id])]
        #expect(try project().paid == payment.amount)
        #expect(try project().remaining == 100)
        metadata.recurring[0].revisions[0].amount = .init(currency: "INR", decimal: "12345.00")
        #expect(try project().expected == amount.amount)
        draft.indiaCommitments[0].money = try Money(amount: 100, currency: "INR")
        draft.assistance?.appliedRecurringPaid?[occurrenceID] = try PlanningAmount(Money(amount: payment.amount, currency: "INR"))
        #expect(try project().remaining == 100)
        draft.indiaCommitments[0].included = false
        #expect(try project().remaining == 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func genuineDatedAnchorsKeepOneFeeReserveFloorAndExactTransferCashEffects() throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let accountAnchors = anchors(snapshot), bank = try #require(accountAnchors.first { $0.domain == "bank" && $0.currency == "QAR" && $0.amount != nil })
        let destination = try #require(snapshot.financialSources.accounts.first { $0.routeType == "NRE" && $0.currency == "INR" })
        let anchorDate = try #require(bank.date)
        let today = try #require(FinancialCalendar.addDays(1, to: anchorDate))
        let month = try SelectedStatementMonth(year: today.year, month: today.month)
        var draft = try draft(workspace: workspace, month: month)
        draft.referenceMode = .manual; draft.planningFX = try .init(inrPerQAR: Decimal(string: "26.2")!, observationDate: today)
        draft.configuredTransferFee = try Money(amount: 15, currency: "QAR"); draft.keepInCBQ = try Money(amount: 70000, currency: "QAR")
        let received = try Money(amount: 10000, currency: "INR")
        let principal = try #require(PlanningIntelligence.transferPrincipal(received: received, fromCurrency: "QAR", plan: draft))
        // Independent integer ceiling: 1,000,000 INR paise / 26.2, rounded upward to QAR paise.
        #expect(try principal.minorUnits() == 38168)
        draft.assistance = .init(workspaceID: workspace, month: month.canonical, transfers: [.init(id: "owner-transfer", fromAccountID: bank.id, toAccountID: destination.id,
            sent: try PlanningAmount(principal), received: try PlanningAmount(received), date: today.canonical, conversionBasis: "Owner-selected planning rate")], reserveAllocationReviewed: true)
        var metadata = try #require(snapshot.intelligence)
        metadata.preferences = .init(workspaceID: workspace, retentionAccountID: bank.id)
        metadata.reserves = [.init(id: "owner-reserve", workspaceID: workspace, accountID: bank.id, title: "CBQ reserve", kind: .accountCash, target: .init(currency: "QAR", decimal: "74000.00"))]
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot)
        let value = try PlanningIntelligence.project(plan: draft, anchors: accountAnchors, rows: rows, metadata: metadata, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, today: today)
        let runway = try #require(value.runways.first { $0.id == bank.id })
        #expect(runway.reserveFloor == 74000)
        #expect(runway.points.allSatisfy { $0.date >= value.start })
        #expect(runway.points.first?.date == value.start)
        #expect(runway.points.first?.balance == bank.amount)
        #expect(runway.firstShortfall.map { $0.date >= value.start } ?? true)
        #expect(runway.lowestBalance == runway.points.map(\.balance).min())
        #expect(runway.events.filter { $0.id.hasPrefix("transfer-fee:") }.count == 1)
        #expect(runway.events.filter { $0.kind == .actual }.allSatisfy { $0.date > bank.date! })
        let expectedActual = rows.filter { $0.accountID == bank.id && $0.transaction.statementDate.map { $0 > bank.date! && $0 <= value.end } == true }.reduce(Decimal.zero) { $0 + $1.transaction.money.amount }
        #expect(runway.endingBalance == bank.amount! + expectedActual - principal.amount - 15)
        #expect(value.reserves.first?.fundedAfterBills == max(0, bank.amount! - principal.amount - 15))
        #expect(!value.cardNeeds.isEmpty)
        #expect(value.investmentCapacity(accountID: bank.id, assistance: draft.assistance).0 == nil)
    }

    @Test(.globalRuntimeStateIsolation)
    func oneCardStatementCannotCreateTwoRemainingCashNeeds() throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let statement = try #require(snapshot.cardSnapshot.statements.first { $0.newBalance?.currency.code == "QAR" && ($0.newBalance?.amount ?? 0) > 0 })
        let bank = try #require(snapshot.accounts.first { $0.type == .bank && $0.nativeCurrency.code == "QAR" }?.repositoryAccountId)
        let originalFacts = try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace)
        var selected = plan(workspace: workspace, month: "2026-10")
        let remaining = PlanDatedAdjustment(id: "owner-remaining-card-bill", accountID: bank, kind: .irregularCost,
            title: "Owner-reviewed remaining card cash need", amount: .init(currency: "QAR", decimal: "1.00"), date: "2026-10-01",
            cardAccountID: statement.liabilityAccountID, cardStatementID: statement.id)
        selected.assistance = .init(workspaceID: workspace, month: "2026-10", datedAdjustments: [remaining])
        _ = try sqlite.fundingPlanRepo.savePlan(selected)
        var repeated = remaining; repeated.id = "second-copy-of-same-bill"
        var duplicate = selected; duplicate.assistance?.datedAdjustments.append(repeated)
        #expect(throws: FinancialIntelligenceError.invalidRecord) { try sqlite.fundingPlanRepo.savePlan(duplicate) }
        #expect(try sqlite.fundingPlanRepo.plans(workspaceId: workspace) == [selected])
        #expect(try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace) == originalFacts)
    }

    @Test(.globalRuntimeStateIsolation)
    func salaryClockUsesActualCreditAndCoalescesLateDailyChecks() throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let facts = try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace)
        let salary = try #require(facts.first { $0.direction == "credit" && $0.description?.localizedCaseInsensitiveContains("SALARY TRANSFER") == true && $0.description?.localizedCaseInsensitiveContains("QATAR AIRWAYS") == true })
        let date = try StatementDate(canonical: String(salary.postedDateISO.prefix(10)))
        var record = SalaryAssistance(transactionID: salary.id, workspaceID: workspace, financialDate: date.canonical, targetMonth: String(format: "%04d-%02d", date.month == 12 ? date.year + 1 : date.year, date.month == 12 ? 1 : date.month + 1))
        let credit = try #require(SalaryISPVerification.creditDay(record)), threshold = try #require(SalaryISPVerification.threshold(record))
        #expect(threshold.timeIntervalSince(credit) == 10 * 86400)
        let late = credit.addingTimeInterval(15 * 86400 + 3600)
        var preferences = IntelligencePreferences(workspaceID: workspace, salaryISPEnabled: true)
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: late, latestFetch: nil) == late)
        record.ispLastAttemptAt = ISO8601DateFormatter().string(from: late)
        let next = try #require(SalaryISPVerification.nextCheck(record, preferences: preferences, now: late, latestFetch: nil))
        #expect(next == credit.addingTimeInterval(16 * 86400))
        // A suitable manual receipt needs only metadata review, then no second fetch that day.
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: late, latestFetch: late) == late)
        record.ispLastFetchAt = ISO8601DateFormatter().string(from: late)
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: late, latestFetch: late) == next)
        // Runtime fetch dates carry fractions; durable check receipts use whole
        // ISO seconds. The same observation must not become a new daily read.
        let fractionalFetch = late.addingTimeInterval(0.75)
        let justAfterFetch = late.addingTimeInterval(0.9)
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: justAfterFetch, latestFetch: fractionalFetch) == next)
        let newerFetch = late.addingTimeInterval(1.25)
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: newerFetch, latestFetch: newerFetch) == newerFetch)
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: next, latestFetch: fractionalFetch) == next)
        // A manual/monthly fetch before a later daily slot still covers that UTC day.
        preferences.salaryISPMinuteUTC = 18 * 60
        let noon = credit.addingTimeInterval(15 * 86400 + 12 * 3600)
        let evening = credit.addingTimeInterval(15 * 86400 + 19 * 3600)
        record.ispLastAttemptAt = nil
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: evening, latestFetch: noon) == evening)
        record.ispLastFetchAt = ISO8601DateFormatter().string(from: noon)
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: evening, latestFetch: noon)
            == credit.addingTimeInterval(16 * 86400 + 18 * 3600))
        // Day ten changes the notice, not the continuing daily-check eligibility.
        preferences.salaryISPMinuteUTC = 0; record.ispLastFetchAt = nil
        for boundary in [threshold.addingTimeInterval(-1), threshold, threshold.addingTimeInterval(1)] {
            for state in [SalaryAssistance.ISPState.unverified, .indeterminate] {
                record.ispState = state
                #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: boundary, latestFetch: nil) == boundary)
            }
        }
        preferences.salaryISPEnabled = false
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: late, latestFetch: nil) == nil)
        preferences.salaryISPEnabled = true; record.ispState = .dismissed
        #expect(SalaryISPVerification.nextCheck(record, preferences: preferences, now: late, latestFetch: nil) == nil)
    }
    @Test(.globalRuntimeStateIsolation)
    func planningMetadataUsesGenuineAccountsAndMatchesProvidersWithoutChangingFacts() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let sqlite = try SQLiteRepositoryProvider(path: root.appendingPathComponent("parity.sqlite").path)
        defer { sqlite.database.close() }
        var results: [FinancialIntelligenceSnapshot] = []
        for provider in [DatabaseProvider.verifiedSQLite(sqlite), DatabaseProvider(inMemory: true)] {
            let imported = try await confirmedImportPlan(generationToken: provider.generationToken)
            guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(imported) else { Issue.record("Authentic import failed"); return }
            let facts = try provider.transactionRepo.trustedTransactions(workspaceId: imported.workspace.id)
            let account = try #require(try provider.accountRepo.accounts(workspaceId: imported.workspace.id).first { $0.accountType == "bank" })
            let definition = RecurringDefinition(id: "owner-monthly", workspaceID: imported.workspace.id, accountID: account.id, title: "Owner planning commitment",
                revisions: [.init(effectiveFrom: "2026-09-21", dueDay: 20, amount: .init(currency: account.nativeCurrency, decimal: "1.00"))], endsOn: "2026-11-30", predicates: [])
            try provider.intelligenceRepo.applyPlanning(.recurring(definition, replacing: nil))
            let occurrence = RecurringOccurrence(id: definition.id + ":2026-10-20", workspaceID: imported.workspace.id, definitionID: definition.id, dueDate: "2026-10-20", amountOverride: .init(currency: account.nativeCurrency, decimal: "2.00"), isWaived: true)
            try provider.intelligenceRepo.applyPlanning(.occurrence(occurrence, replacing: nil))
            var ended = definition; ended.endsOn = "2026-10-19"
            #expect(throws: FinancialIntelligenceError.invalidRecord) { try provider.intelligenceRepo.applyPlanning(.recurring(ended, replacing: definition)) }
            var badRevision = definition; badRevision.revisions.append(.init(effectiveFrom: "2026-12-01", dueDay: 20, amount: definition.revisions[0].amount))
            #expect(throws: FinancialIntelligenceError.invalidRecord) { try provider.intelligenceRepo.applyPlanning(.recurring(badRevision, replacing: definition)) }
            #expect(throws: FinancialIntelligenceError.staleReview) { try provider.intelligenceRepo.applyPlanning(.recurring(definition, replacing: nil)) }
            #expect(PlanningIntelligence.dueDate(definition: definition, month: try SelectedStatementMonth(canonical: "2026-09")) == nil)
            #expect(PlanningIntelligence.dueDate(definition: definition, month: try SelectedStatementMonth(canonical: "2026-10"))?.0.canonical == "2026-10-20")
            var preferences = IntelligencePreferences(workspaceID: imported.workspace.id)
            preferences.excludedPlanningAccountIDs = [account.id]
            try provider.intelligenceRepo.applyPlanning(.preferences(preferences, replacing: nil))
            let month = try SelectedStatementMonth(canonical: "2026-09")
            var selected = plan(workspace: imported.workspace.id, month: month.canonical)
            selected.assistance = .init(workspaceID: imported.workspace.id, month: month.canonical, salaryCycle: SalaryFundingCycle.expected(month: month, day: 26))
            _ = try provider.fundingPlanRepo.savePlan(selected)
            #expect(try provider.fundingPlanRepo.plans(workspaceId: imported.workspace.id) == [selected])
            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: imported.workspace.id) == facts)
            var state = try #require(try provider.intelligenceRepo.snapshot(workspaceID: imported.workspace.id))
            // Runtime-generated canonical account IDs differ across independent imports.
            state.recurring[0].accountID = "verified-account"
            state.preferences?.excludedPlanningAccountIDs = ["verified-account"]
            results.append(state)
        }
        #expect(results[0] == results[1])
    }

    @Test(.globalRuntimeStateIsolation)
    func automaticRecurringInclusionPreservesOverridesSuppressionAndNextMonthInventory() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("recurring.sqlite")
        let sqlite = try SQLiteRepositoryProvider(path: path.path)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let imported = try await confirmedImportPlan(generationToken: provider.generationToken)
        guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(imported) else {
            Issue.record("Authentic import failed"); return
        }
        let workspace = imported.workspace.id
        let facts = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        let account = try #require(try provider.accountRepo.accounts(workspaceId: workspace).first { $0.accountType == "bank" })
        #expect(account.nativeCurrency == "INR")
        let definition = RecurringDefinition(id: "owner-recurring-s100", workspaceID: workspace, accountID: account.id,
            title: "Owner monthly estimate", revisions: [.init(effectiveFrom: "2026-09-01", dueDay: 1,
            amount: .init(currency: "INR", decimal: "1.00"))], endsOn: nil, predicates: [])
        try provider.intelligenceRepo.applyPlanning(.recurring(definition, replacing: nil))
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false)
        hydrator.publish(try hydrator.stageHydration())
        let month = try SelectedStatementMonth(canonical: "2026-09")
        let instant = try #require(FinancialCalendar.instant(StatementDate(canonical: "2026-09-29")))
        func open(_ current: DatabaseProvider = provider) -> SalaryWorkspaceViewModel {
            let vm = SalaryWorkspaceViewModel(month: month, workspaceID: workspace, provider: { current },
                now: { instant }, refresh: { active in
                    let read = RepositoryStoreHydrator(databaseProvider: active, workspaceId: workspace, participatesInLifecycleGate: false)
                    read.publish(try read.stageHydration())
                })
            vm.plannerOpened(); return vm
        }
        let model = open()
        for _ in 0..<200 where model.plan.indiaCommitments.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        let row = try #require(model.plan.indiaCommitments.first)
        #expect(model.plan.indiaCommitments.count == 1)
        #expect(row.dueDate?.canonical == "2026-10-01")
        #expect(row.fundingAccountID == account.id)
        model.editCommitment(region: "india", id: row.id, field: "amount", text: "2.5")
        model.editCommitment(region: "india", id: row.id, field: "label", text: "This month only")
        model.editCommitment(region: "india", id: row.id, field: "included", text: "false")
        model.editCommitment(region: "india", id: row.id, field: "account", text: "")
        #expect(model.plan.indiaCommitments.first?.fundingAccountID == account.id)
        model.setBillDate(region: "india", id: row.id, date: nil)
        #expect(model.plan.indiaCommitments.first?.dueDate == row.dueDate)
        model.setCommitmentDetails(region: "india", id: row.id, recurs: true)
        model.flushPendingEntries()
        hydrator.publish(try hydrator.stageHydration())
        let reopened = open()
        for _ in 0..<30 { await Task.yield() }
        #expect(reopened.plan.indiaCommitments.map(\.id) == [row.id])
        #expect(reopened.plan.indiaCommitments.first?.label == "This month only")
        #expect(reopened.plan.indiaCommitments.first?.included == false)
        #expect(reopened.rawText["amount.\(row.id)"] == "2.5")
        reopened.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        for _ in 0..<200 where reopened.plan.indiaCommitments.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(reopened.plan.indiaCommitments.count == 1)
        #expect(reopened.plan.indiaCommitments.first?.dueDate?.canonical == "2026-11-01")
        #expect(reopened.plan.indiaCommitments.first?.money.amount == 1)
        reopened.switchMonth(to: month)
        reopened.removeCommitment(region: "india", id: row.id)
        reopened.flushPendingEntries()
        hydrator.publish(try hydrator.stageHydration())
        let afterRemoval = open()
        for _ in 0..<30 { await Task.yield() }
        #expect(afterRemoval.plan.indiaCommitments.isEmpty)
        let retained = try #require(provider.fundingPlanRepo.scratchpads(workspaceId: workspace).first { $0.month == month.canonical })
        #expect(try MonthlyPlanScratchpad.decode(retained).excludedRecurringOccurrenceIDs.count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspace) == facts)
    }

    @Test(.globalRuntimeStateIsolation)
    func planningReviewCannotAcknowledgeANewerHydratedState() throws {
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        DatabaseProvider.shared = provider
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let store = FinancialIntelligenceStore.shared
        let previous = store.snapshot?.preferences, revision = store.revision
        var reviewed = previous ?? .init(workspaceID: workspace)
        reviewed.lastReviewedChangeKey = "reviewed-state"
        let coordinator = FinancialIntelligenceCoordinator(provider: { provider })
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        #expect(store.revision != revision)
        #expect(throws: FinancialIntelligenceError.staleReview) {
            try coordinator.acknowledgePlanningReview(reviewed, replacing: previous, generation: provider.generationToken, revision: revision)
        }
        #expect(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace)?.preferences == previous)
        try coordinator.acknowledgePlanningReview(reviewed, replacing: previous, generation: provider.generationToken, revision: store.revision)
        #expect(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace)?.preferences?.lastReviewedChangeKey == "reviewed-state")
    }

    @Test(.globalRuntimeStateIsolation)
    func genuineSalaryProposalIsConsumedOnlyWithAtomicPlanSaveAndRecovers() async throws {
        let nominated = try JSONDecoder().decode([OwnerCategoryNomination].self, from: AuthenticSourceTestSupport.ramNomination("LEDGERFORGE_S99_CATEGORY_OWNER_DATA"))
        let ids = Set(try #require(nominated.first).expectedTransactionIDs)
        let root = try folder(), sqlite = try copy(root)
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: root) }
        let workspace = try #require(try sqlite.database.query(sql: "SELECT id FROM workspaces ORDER BY id;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let facts = try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace)
        let salarySeed = try #require(nominated.first)
        let categoryName = try CategoryName.validated(salarySeed.categoryName)
        _ = try sqlite.categoryRepo.createCategory(.init(id: salarySeed.categoryID, workspaceId: workspace,
            name: categoryName.display, normalizedName: categoryName.normalized, createdAtISO: stamp))
        try sqlite.categoryRepo.saveRule(salarySeed.rule, previousVersion: nil)
        let hydration = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let rows = try SpendingIntelligence.rows(transactions: hydration.transactions, sources: hydration.financialSources,
            cards: hydration.cardSnapshot, categories: hydration.categorySnapshot, salaryRuleIDs: [salarySeed.rule.id])
        var setup = IntelligencePreferences(workspaceID: workspace)
        #expect(SpendingIntelligence.salarySetupIssue(preferences: setup, categories: hydration.categorySnapshot, sources: hydration.financialSources)?.hasPrefix("Setup incomplete:") == true)
        setup.salaryRuleIDs = [salarySeed.rule.id]
        #expect(SpendingIntelligence.salarySetupIssue(preferences: setup, categories: hydration.categorySnapshot, sources: hydration.financialSources) == nil)
        var changedCategories = hydration.categorySnapshot
        let disabledRules: [CategoryRule] = changedCategories.automation?.rules.map { rule in var value = rule; value.isEnabled = false; return value } ?? []
        changedCategories.automation?.rules = disabledRules
        #expect(SpendingIntelligence.salarySetupIssue(preferences: setup, categories: changedCategories, sources: hydration.financialSources) != nil)
        setup.salaryAssistanceEnabled = false
        #expect(SpendingIntelligence.salarySetupIssue(preferences: setup, categories: changedCategories, sources: hydration.financialSources) == nil)
        let proposals = SalaryAssistanceSession.proposals(rows: rows, metadata: try #require(hydration.intelligence),
            today: try StatementDate(canonical: "2026-09-21"), includeHistorical: true)
        #expect(Set(proposals.map(\.id)) == ids)
        let suggestions = try SpendingIntelligence.suggestions(rows: rows, metadata: try #require(hydration.intelligence), sources: hydration.financialSources)
        #expect(!suggestions.isEmpty)
        #expect(suggestions.filter { $0.kind == .ownTransfer }.allSatisfy { Set($0.transactionIDs).isDisjoint(with: ids) })
        let factsByID = Dictionary(uniqueKeysWithValues: facts.map { ($0.id, $0) })
        for proposal in proposals {
            let posted = try StatementDate(canonical: String(try #require(factsByID[proposal.id]).postedDateISO.prefix(10)))
            #expect(proposal.financialDate == posted.canonical)
            #expect(proposal.targetMonth == String(posted.canonical.prefix(7)))
            #expect(proposal.planningBasis == .creditMonth)
        }
        print("Authentic salary date coverage: \(proposals.count) credits; \(rows.filter { ids.contains($0.id) && $0.date != $0.transaction.statementDate }.count) with unequal source and bank-credit dates")
        let salary = try #require(facts.filter { ids.contains($0.id) && $0.direction == "credit" }.max { $0.postedDateISO < $1.postedDateISO })
        let date = try StatementDate(canonical: String(salary.postedDateISO.prefix(10)))
        let month = try SelectedStatementMonth(year: date.year, month: date.month)
        let proposal = SalaryAssistance(transactionID: salary.id, workspaceID: workspace, financialDate: date.canonical, targetMonth: month.canonical, planningBasis: .creditMonth)
        try sqlite.intelligenceRepo.applyPlanning(.salary(proposal, replacing: nil))
        var selected = plan(workspace: workspace, month: month.canonical)
        var cycle = try #require(SalaryFundingCycle.expected(month: month)); cycle.payday = date.canonical; cycle.receivedSalaryID = salary.id
        selected.assistance = .init(workspaceID: workspace, month: month.canonical, appliedSalaryIDs: [salary.id], salaryCycle: cycle)
        try sqlite.database.execute(sql: "CREATE TRIGGER s99_plan_failure BEFORE INSERT ON plan_assistance BEGIN SELECT RAISE(ABORT,'qualification failure'); END;")
        #expect(throws: (any Error).self) { try sqlite.fundingPlanRepo.savePlan(selected) }
        #expect(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace)?.salaries == [proposal])
        #expect(try sqlite.fundingPlanRepo.plans(workspaceId: workspace).isEmpty)
        try sqlite.database.execute(sql: "DROP TRIGGER s99_plan_failure;")
        _ = try sqlite.fundingPlanRepo.savePlan(selected)
        #expect(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace)?.salaries.first?.draftState == .consumed)
        let consumed = try #require(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace)?.salaries.first)
        #expect(throws: FinancialIntelligenceError.invalidRecord) { try sqlite.intelligenceRepo.applyPlanning(.salary(proposal, replacing: consumed)) }
        var corrupt = selected; corrupt.assistance?.appliedRecurringIDs = ["unowned:2026-09-20": "not-a-bill"]
        #expect(throws: FinancialIntelligenceError.invalidRecord) { try sqlite.fundingPlanRepo.savePlan(corrupt) }
        #expect(try sqlite.fundingPlanRepo.plans(workspaceId: workspace) == [selected])
        let encoded = try SQLiteFinancialIntelligenceRepository.encode(try #require(selected.assistance))
        let badEncoded = try SQLiteFinancialIntelligenceRepository.encode(try #require(corrupt.assistance))
        try sqlite.database.executePrepared(sql: "UPDATE plan_assistance SET assistance_json=? WHERE workspace_id=? AND plan_month=?;", params: [badEncoded,workspace,month.canonical])
        #expect(throws: FinancialIntelligenceError.invalidRecord) { try sqlite.intelligenceRepo.snapshot(workspaceID: workspace) }
        try sqlite.database.executePrepared(sql: "UPDATE plan_assistance SET assistance_json=? WHERE workspace_id=? AND plan_month=?;", params: [encoded,workspace,month.canonical])
        #expect(try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace) == facts)
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        DatabaseProvider.shared = provider
        let backup = BackupRestoreCoordinator(testingAt: root.appendingPathComponent("qualification.sqlite")); backup.installTestProvider(sqlite)
        let destination = root.appendingPathComponent("backups"); try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        await backup.createBackup(to: destination)
        let package = try #require(backup.lastBackupURL), manifest = try BackupFiles.verifyPackage(package)
        let restore = root.appendingPathComponent("restored.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: restore)
        let reopened = try SQLiteRepositoryProvider(path: restore.path)
        defer { reopened.database.close() }
        #expect(try reopened.intelligenceRepo.snapshot(workspaceID: workspace) == sqlite.intelligenceRepo.snapshot(workspaceID: workspace))
        #expect(try reopened.fundingPlanRepo.plans(workspaceId: workspace) == [selected])
        #expect(try reopened.transactionRepo.trustedTransactions(workspaceId: workspace) == facts)
    }
}
