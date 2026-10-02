import Combine
import Foundation
import Testing
@testable import LedgerForge

@Suite("DashboardViewModel", .serialized)
@MainActor
struct DashboardViewModelTests {

    @Test(.globalRuntimeStateIsolation)
    func currentDatabaseProjectionMatchesIndependentOracleAndDoesNotMutateReadOnlyFiles() throws {
        let context = try dashboardCurrentDatabaseContext()
        let before = try databaseFiles(context)
        let availability = ApplicationAvailability()
        availability.didHydrate(context.snapshot.hydrationResult, generation: context.provider.generationToken)

        let viewModel = DashboardViewModel(
            accountStore: context.accountStore,
            transactionStore: context.transactionStore,
            cardStore: context.cardStore,
            fundingPlanStore: context.fundingPlanStore,
            availability: availability,
            workspaceID: context.workspaceID,
            now: Date.init
        )
        viewModel.refreshPresentation()

        let expectedPositions = dashboardPositionOracle(context: context)
        assertPositions(viewModel.positions, equalTo: expectedPositions)
        check(
            viewModel.positionState == DashboardContentState.resolve(
                availability: availability.state,
                isEmpty: expectedPositions.isEmpty
            ),
            "Dashboard position state follows canonical availability"
        )
        assertCanonicalBalancesMatchSelectedEvidence(context: context)

        check(viewModel.accounts.count == context.snapshot.accounts.count, "Dashboard account mirror is observation-only")
        #expect(viewModel.storedTransactionCount == context.snapshot.transactions.count)

        check(
            Set(viewModel.positions.map(\.currency)).count == viewModel.positions.count,
            "Dashboard currency groups are unique"
        )
        check(
            try databaseFiles(context) == before,
            "Dashboard observation leaves read-only database and WAL bytes unchanged"
        )

        if context.snapshot.cardSnapshot.statements.isEmpty {
            notObserved("card-position-shape")
        }
        if Set(context.snapshot.accounts.filter { $0.type == .bank || $0.type == .creditCard }.map(\.nativeCurrency)).count < 2 {
            notObserved("mixed-native-currency-shape")
        }
        if context.snapshot.fundingPlans.isEmpty {
            notObserved("saved-funding-plan-shape")
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func historyOnlyAccountScopePreservesCanonicalHistoryAndSavedPlanning() throws {
        let source = try dashboardCurrentDatabaseContext()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-dashboard-history-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("qualification.sqlite").path
        try source.provider.database.createBackup(at: path)
        let sqlite = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing, migrateExisting: true)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let accounts = AccountStore(), transactions = TransactionStore(), cards = CardStore()
        let categories = CategoryStore(), funding = FundingPlanStore(), salary = SalaryStore()
        let intelligence = FinancialIntelligenceStore()
        let hydrator = RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo, investmentRepo: provider.investmentRepo,
            intelligenceRepo: provider.intelligenceRepo,
            accountStore: accounts, transactionStore: transactions, categoryStore: categories, cardStore: cards,
            salaryStore: salary, fundingPlanStore: funding, investmentStore: InvestmentStore(), intelligenceStore: intelligence,
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(), workspaceId: source.workspaceID,
            persistenceState: .verifiedSQLite, providerGeneration: provider.generationToken, participatesInLifecycleGate: false)
        let before = try hydrator.stageHydration()
        hydrator.publish(before)
        let accountID = try #require(before.accounts.first { account in
            account.type == .creditCard && !account.isHistoryOnly && before.transactions.contains {
                $0.repositoryAccountId == account.repositoryAccountId
            }
        }?.repositoryAccountId)
        let durableRows = try provider.transactionRepo.trustedTransactions(workspaceId: source.workspaceID)
        let durableCards = try provider.cardRepo.snapshot(workspaceId: source.workspaceID)
        let metadata = AccountMetadataCoordinator(provider: { provider }, developerConsole: nil,
            forcedHydration: { _, _ in try hydrator.hydrateIfNeeded(forceRefresh: true) },
            acknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
        #expect(try metadata.markAccountHistoryOnly(accountId: accountID, workspaceId: source.workspaceID))
        let availability = ApplicationAvailability()
        availability.didHydrate(before.hydrationResult, generation: provider.generationToken)
        let model = DashboardViewModel(accountStore: accounts, transactionStore: transactions, cardStore: cards,
            fundingPlanStore: funding, availability: availability, workspaceID: source.workspaceID)
        model.refreshPresentation()
        #expect(model.positions.flatMap(\.cards).allSatisfy { $0.id != accountID })
        check(transactions.transactions.map(\.repositoryTransactionId) == before.transactions.map(\.repositoryTransactionId), "Canonical transaction inventory survives history-only metadata")
        check(try provider.transactionRepo.trustedTransactions(workspaceId: source.workspaceID) == durableRows, "Durable transactions are unchanged")
        check(try provider.cardRepo.snapshot(workspaceId: source.workspaceID) == durableCards, "Durable card evidence is unchanged")
        #expect(accounts.accounts.first { $0.repositoryAccountId == accountID }?.isHistoryOnly == true)
        let hidden = try hydrator.stageHydration()
        let expectedHistoryIDs = Set(durableRows.filter { $0.accountId == accountID }.map(\.id))
        #expect(!expectedHistoryIDs.isEmpty)
        func visibleIDs(_ filter: TransactionPresentationFilterSpec) -> Set<String> {
            Set(TransactionPresentationEngine.evaluate(transactions: hidden.transactions, accounts: hidden.accounts,
                categories: hidden.categorySnapshot.categories, assignments: hidden.categorySnapshot.assignments,
                filter: filter, sort: .init(), availability: .available).rows.compactMap { $0.transaction.repositoryTransactionId })
        }
        check(visibleIDs(.empty).isDisjoint(with: expectedHistoryIDs), "Default transactions exclude historical account rows")
        var explicitHistory = TransactionPresentationFilterSpec.empty
        explicitHistory.accountIDs = [accountID]
        check(visibleIDs(explicitHistory) == expectedHistoryIDs, "Explicit history selection restores exact transaction membership")
        #expect(try metadata.markAccountCurrent(accountId: accountID, workspaceId: source.workspaceID))
        model.refreshPresentation()
        #expect(model.positions.flatMap(\.cards).contains { $0.id == accountID })
        #expect(accounts.accounts.first { $0.repositoryAccountId == accountID }?.isHistoryOnly == false)
        check(try provider.transactionRepo.trustedTransactions(workspaceId: source.workspaceID) == durableRows, "Returning to current preserves durable transactions")
        check(try provider.cardRepo.snapshot(workspaceId: source.workspaceID) == durableCards, "Returning to current preserves card evidence")

        // Continue with an actual saved plan and its nonzero bank balance. All
        // financial inputs come from the approved normal database backup.
        func required<T>(_ value: T?, _ label: String) throws -> T {
            let present = value != nil
            try #require(present, "\(label)")
            return value!
        }
        let bankBefore = try hydrator.stageHydration()
        let month = try SelectedStatementMonth(canonical: "2026-09")
        let savedPlan = try required(bankBefore.fundingPlans.first { $0.month == month }, "Authentic saved September plan is present")
        let planningMetadata = try required(bankBefore.intelligence, "Authentic planning metadata is present")
        let manualExclusions = planningMetadata.preferences?.excludedPlanningAccountIDs ?? []
        let includedBalance = try required(savedPlan.balances.first { balance in
            balance.included && balance.nativeCurrency.code == "QAR" && balance.money.map { $0.amount != 0 } == true &&
            !manualExclusions.contains(balance.accountID) && bankBefore.accounts.contains {
                $0.repositoryAccountId == balance.accountID && $0.type == .bank && !$0.isHistoryOnly && $0.currentBalanceAsOfISO != nil
            }
        }, "Saved plan includes a nonzero genuine current bank balance")
        let bankID = includedBalance.accountID
        let includedMoney = try required(includedBalance.money, "Saved balance has exact Money")
        let savedClock = try required(ISO8601DateFormatter().date(from: savedPlan.updatedAtISO), "Saved plan has a valid update timestamp")
        let plansBefore = try provider.fundingPlanRepo.plans(workspaceId: source.workspaceID)
        let accountsBefore = try provider.accountRepo.accounts(workspaceId: source.workspaceID)
        let financialDigest = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["accounts"])
        let bankTransactionIDs = Set(durableRows.filter { $0.accountId == bankID }.map(\.id))
        #expect(!bankTransactionIDs.isEmpty)

        func worksheet() -> SalaryWorkspaceViewModel {
            SalaryWorkspaceViewModel(month: savedPlan.month, workspaceID: source.workspaceID, provider: { provider },
                accountStore: accounts, transactionStore: transactions, salaryStore: salary, fundingPlanStore: funding,
                intelligenceStore: intelligence, locale: Locale(identifier: "en_US_POSIX"), now: { savedClock },
                refresh: { _ in _ = try hydrator.hydrateIfNeeded(forceRefresh: true) })
        }
        func projected(_ snapshot: RepositoryRuntimeSnapshot, selecting historyIDs: Set<String> = []) throws -> PlanningProjection {
            let metadata = try required(snapshot.intelligence, "Planning metadata survives scope changes")
            let anchors: [PlanningAccountAnchor] = snapshot.accounts.compactMap { account in
                guard [.bank, .creditCard].contains(account.type), let id = account.repositoryAccountId else { return nil }
                let date = account.currentBalanceAsOfISO.flatMap { try? StatementDate(canonical: String($0.prefix(10))) }
                return .init(id: id, title: account.preferredDisplayName, currency: account.currencyCode,
                    domain: account.type == .bank ? "bank" : "credit_card", amount: date == nil ? nil : account.currentBalance,
                    date: date, historyOnly: account.isHistoryOnly)
            }
            let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources,
                cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot, salaryRuleIDs: metadata.preferences?.salaryRuleIDs ?? [])
            return try PlanningIntelligence.project(plan: savedPlan, anchors: anchors, rows: rows, metadata: metadata,
                sources: snapshot.financialSources, cards: snapshot.cardSnapshot, today: savedPlan.recurringStart,
                selectedHistoryAccountIDs: historyIDs)
        }
        func unchangedFinancialState() throws {
            check(try provider.transactionRepo.trustedTransactions(workspaceId: source.workspaceID) == durableRows, "Scope preserves every durable transaction")
            check(try provider.cardRepo.snapshot(workspaceId: source.workspaceID) == durableCards, "Scope preserves every card source fact")
            check(try provider.fundingPlanRepo.plans(workspaceId: source.workspaceID) == plansBefore, "Scope never rewrites saved plans")
            check(try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["accounts"]) == financialDigest, "Only account metadata changes")
        }

        let baselineWorksheet = worksheet()
        check(baselineWorksheet.plan == savedPlan, "Retained worksheet agrees with the saved authentic plan")
        #expect(baselineWorksheet.fieldErrors.isEmpty)
        let baselineCalculation = baselineWorksheet.calculation
        let baselineQAR = try required(baselineCalculation.selectedQARLiquidity, "Saved worksheet has complete QAR liquidity")
        let baselineProjection = try projected(bankBefore)
        let baselineRunway = try required(baselineProjection.runways.first { $0.id == bankID }, "Current bank has a source-backed runway")
        check(baselineRunway.anchor.date != nil && baselineRunway.anchor.amount != nil, "Authentic runway has dated balance evidence")
        let baselineActualIDs = Set(baselineProjection.actualTransactionIDs.values.flatMap { $0 })
        if baselineActualIDs.isDisjoint(with: bankTransactionIDs) {
            notObserved("saved-plan-selected-bank-spending-shape")
        }
        try unchangedFinancialState()

        #expect(try metadata.markAccountHistoryOnly(accountId: bankID, workspaceId: source.workspaceID))
        let bankHidden = try hydrator.stageHydration()
        let historyIDs = Set(try provider.accountRepo.accounts(workspaceId: source.workspaceID).filter { $0.closedAtISO != nil }.map(\.id))
        let expectedDefaultIDs = Set(durableRows.filter { $0.accountId.map { !historyIDs.contains($0) } ?? true }.map(\.id))
        func bankVisibleIDs(_ selected: Set<String>) -> Set<String> {
            var filter = TransactionPresentationFilterSpec.empty
            filter.accountIDs = selected
            return Set(TransactionPresentationEngine.evaluate(transactions: bankHidden.transactions, accounts: bankHidden.accounts,
                categories: bankHidden.categorySnapshot.categories, assignments: bankHidden.categorySnapshot.assignments,
                filter: filter, sort: .init(), availability: .available).rows.compactMap { $0.transaction.repositoryTransactionId })
        }
        check(bankVisibleIDs([]) == expectedDefaultIDs, "Default scope matches independent durable closed-at membership")
        check(bankVisibleIDs([bankID]) == bankTransactionIDs, "Explicit selection restores all historical bank rows")
        check(Set(bankHidden.transactions.compactMap(\.repositoryTransactionId)) == Set(durableRows.map(\.id)), "Hydration keeps the complete financial inventory")
        let hiddenProjection = try projected(bankHidden)
        check(!hiddenProjection.runways.contains { $0.id == bankID }, "Default projection hides the historical bank runway")
        check(Set(hiddenProjection.actualTransactionIDs.values.flatMap { $0 }).isDisjoint(with: bankTransactionIDs), "Default planning excludes historical bank activity")
        let scopedWorksheet = worksheet()
        let expectedCurrentQAR = try baselineQAR - includedMoney
        check(scopedWorksheet.calculation.selectedQARLiquidity == expectedCurrentQAR, "Default worksheet removes exactly the saved included Money")
        check(scopedWorksheet.plan == savedPlan, "Default scope retains the complete saved plan")
        check(!scopedWorksheet.eligibleAccounts.contains { $0.repositoryAccountId == bankID }, "Default worksheet hides the historical account row")
        try unchangedFinancialState()

        scopedWorksheet.setHistoryAccountSelected(bankID, selected: true)
        check(scopedWorksheet.calculation == baselineCalculation, "Explicit history restores the complete worksheet result")
        let explicitProjection = try projected(bankHidden, selecting: [bankID])
        let restored = try required(explicitProjection.runways.first { $0.id == bankID }, "Explicit history restores the runway")
        check(restored.anchor.amount == baselineRunway.anchor.amount && restored.anchor.date == baselineRunway.anchor.date, "Restored runway retains the exact source anchor")
        check(restored.points.map(\.id) == baselineRunway.points.map(\.id) && restored.points.map(\.date) == baselineRunway.points.map(\.date), "Restored points retain identity, dates and order")
        check(restored.points.map(\.balance) == baselineRunway.points.map(\.balance), "Restored points retain exact balances")
        check(restored.points.map(\.isForecast) == baselineRunway.points.map(\.isForecast) && restored.points.map(\.transactionIDs) == baselineRunway.points.map(\.transactionIDs), "Restored points retain forecast meaning and provenance")
        check(restored.events.map(\.id) == baselineRunway.events.map(\.id) && restored.events.map(\.date) == baselineRunway.events.map(\.date), "Restored events retain identity, dates and order")
        check(restored.events.map(\.change) == baselineRunway.events.map(\.change), "Restored events retain exact cash effects")
        check(restored.events.map(\.kind) == baselineRunway.events.map(\.kind) && restored.events.map(\.transactionIDs) == baselineRunway.events.map(\.transactionIDs), "Restored events retain meaning and provenance")
        check(restored.reserveFloor == baselineRunway.reserveFloor && restored.limitations == baselineRunway.limitations, "Restored runway retains reserves and limitations")
        check(explicitProjection.actualSpending == baselineProjection.actualSpending && explicitProjection.actualTransactionIDs == baselineProjection.actualTransactionIDs, "Explicit history restores exact planning activity and membership")
        check(explicitProjection.plannedCommitments == baselineProjection.plannedCommitments, "Explicit history restores planned totals")
        scopedWorksheet.selectCurrentAccountScope()
        check(scopedWorksheet.calculation.selectedQARLiquidity == expectedCurrentQAR, "Returning to current restores default worksheet scope")
        try unchangedFinancialState()
        #expect(try metadata.markAccountCurrent(accountId: bankID, workspaceId: source.workspaceID))
        check(try provider.accountRepo.accounts(workspaceId: source.workspaceID) == accountsBefore, "Metadata roundtrip restores every account exactly")
        try unchangedFinancialState()

        // A subsequent, intentional editor phase checks invalid historical raw
        // input without constructing financial fixtures or replacement Money.
        #expect(try metadata.markAccountHistoryOnly(accountId: bankID, workspaceId: source.workspaceID))
        let editor = worksheet()
        if let quote = savedPlan.effectiveAlDarReference {
            check(quote.submittedQAR.amount == 1, "Saved reference is a unit quote")
            let reference = try AlDarUnitReference(currency: .inr, rawToken: quote.returnedINR.rawToken, fetchedAtISO: quote.fetchedAtISO)
            check(try reference.planningQuote() == quote, "Editor reuses the exact saved quote")
            editor.receiveSharedReference(reference)
        }
        editor.plannerOpened()
        editor.flushPendingEntries()
        let editBaseline = editor.plan
        let plansAtEditStart = try provider.fundingPlanRepo.plans(workspaceId: source.workspaceID)
        let planTables = Set(try sqlite.database.query(sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND (name LIKE 'funding_plan%' OR name = 'monthly_plan_scratchpads');") { $0.string(at: 0)! })
        let editExcludedTables = planTables.union(["accounts"])
        let sourceDigest = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: editExcludedTables)
        let historyBank = try required(accounts.accounts.first { $0.repositoryAccountId == bankID }, "Historical bank remains available")
        editor.setHistoryAccountSelected(bankID, selected: true)
        let balanceKey = "balance.\(bankID)"
        editor.setManualBalance(historyBank, text: "-")
        let retainedError = try required(editor.fieldErrors[balanceKey], "Invalid UI input retains its error")
        #expect(!editor.canSave)
        editor.flushPendingEntries()
        check(try provider.fundingPlanRepo.plans(workspaceId: source.workspaceID) == plansAtEditStart, "Invalid text cannot change canonical financial inputs")
        editor.selectCurrentAccountScope()
        #expect(editor.hasValidCalculation && editor.canSave)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        check(editor.rawText[balanceKey] == "-" && editor.fieldErrors[balanceKey] == retainedError, "Scope and metadata refresh preserve hidden invalid input")

        let currentHistoryIDs = Set(try provider.accountRepo.accounts(workspaceId: source.workspaceID).filter { $0.closedAtISO != nil }.map(\.id))
        let bills = editor.plan.qatarCommitments.map { ("qatar", $0) } + editor.plan.indiaCommitments.map { ("india", $0) }
        let selectedBill = try required(bills.first { _, bill in
            (bill.fundingAccountID.map { !currentHistoryIDs.contains($0) } ?? true) &&
            (editor.plan.assistance?.billFundingAccounts?[bill.id].map { !currentHistoryIDs.contains($0) } ?? true)
        }, "Saved plan contains a current commitment")
        let (region, bill) = selectedBill
        let remark = bill.remark == "History scope check" ? "History scope check completed" : "History scope check"
        var expectedEdit = editBaseline
        if region == "qatar" {
            let index = try required(expectedEdit.qatarCommitments.firstIndex { $0.id == bill.id }, "Existing Qatar commitment is retained")
            expectedEdit.qatarCommitments[index].remark = remark
        } else {
            let index = try required(expectedEdit.indiaCommitments.firstIndex { $0.id == bill.id }, "Existing India commitment is retained")
            expectedEdit.indiaCommitments[index].remark = remark
        }
        expectedEdit.updatedAtISO = ISO8601DateFormatter().string(from: savedClock)
        editor.setCommitmentDetails(region: region, id: bill.id, remark: remark)
        editor.flushPendingEntries()
        #expect(editor.saveState == .saved)
        let plansAfterEdit = try provider.fundingPlanRepo.plans(workspaceId: source.workspaceID)
        let savedAfterEdit = try required(plansAfterEdit.first { $0.id == editBaseline.id }, "Edited plan remains durable")
        check(savedAfterEdit == (try expectedEdit.persistenceDTO()), "Current publication changes only the intended remark and timestamp")
        check(plansAfterEdit.filter { $0.id != savedPlan.id } == plansAtEditStart.filter { $0.id != savedPlan.id }, "Current edit leaves all other months unchanged")
        let scratchDTO = try required(try provider.fundingPlanRepo.scratchpads(workspaceId: source.workspaceID).first { $0.month == month.canonical }, "Invalid history input is retained durably")
        let scratch = try MonthlyPlanScratchpad.decode(scratchDTO)
        check(scratch.rawText[balanceKey] == "-" && scratch.fieldErrors[balanceKey] == retainedError, "Current publication retains hidden raw input and validation")
        check(scratch.canonical == expectedEdit, "Retained draft references the newly saved canonical plan")
        editor.setHistoryAccountSelected(bankID, selected: true)
        check(editor.rawText[balanceKey] == "-" && editor.fieldErrors[balanceKey] == retainedError, "Explicit reselection restores the invalid input")
        #expect(!editor.hasValidCalculation && !editor.canSave)
        check(try NetWorthTestSupport.financialDigest(sqlite.database, excluding: editExcludedTables) == sourceDigest, "Current remark edit and retained draft leave all source facts unchanged")
        sqlite.database.close()
        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing, migrateExisting: false)
        defer { reopened.database.close() }
        check(try reopened.fundingPlanRepo.plans(workspaceId: source.workspaceID) == plansAfterEdit, "Reopening preserves exact saved plans")
        check(try reopened.transactionRepo.trustedTransactions(workspaceId: source.workspaceID) == durableRows, "Reopening preserves complete financial history")
    }

    @Test(.globalRuntimeStateIsolation)
    func retainedPlanPresentationWithholdsIncompleteEntriesAndRespectsPlanningExclusions() throws {
        let source = try dashboardCurrentDatabaseContext()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-dashboard-retained-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("qualification.sqlite").path
        try source.provider.database.createBackup(at: path)
        let sqlite = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing, migrateExisting: true)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let accounts = AccountStore(), transactions = TransactionStore(), cards = CardStore()
        let funding = FundingPlanStore(), salary = SalaryStore(), intelligence = FinancialIntelligenceStore()
        let hydrator = RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo, investmentRepo: provider.investmentRepo,
            intelligenceRepo: provider.intelligenceRepo, accountStore: accounts, transactionStore: transactions,
            categoryStore: CategoryStore(), cardStore: cards, salaryStore: salary, fundingPlanStore: funding,
            investmentStore: InvestmentStore(), intelligenceStore: intelligence,
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(), workspaceId: source.workspaceID,
            persistenceState: .verifiedSQLite, providerGeneration: provider.generationToken, participatesInLifecycleGate: false)
        let initial = try hydrator.stageHydration()
        hydrator.publish(initial)
        func required<T>(_ value: T?, _ message: String) throws -> T {
            let present = value != nil
            try #require(present, "\(message)")
            return value!
        }
        let month = try SelectedStatementMonth(canonical: "2026-09")
        let savedPlan = try required(initial.fundingPlans.first { $0.month == month }, "The genuine saved September plan is available")
        let oldPreferences = try required(initial.intelligence?.preferences, "The genuine planning preferences are available")
        let account = try required(initial.accounts.first { account in
            guard let id = account.repositoryAccountId else { return false }
            return account.type == .bank && !account.isHistoryOnly && !(oldPreferences.excludedPlanningAccountIDs ?? []).contains(id) &&
                savedPlan.balances.contains { $0.accountID == id && $0.included && $0.money != nil }
        }, "The saved plan includes a genuine current bank balance")
        let accountID = try required(account.repositoryAccountId, "The selected account has durable identity")
        let clock = try required(ISO8601DateFormatter().date(from: savedPlan.updatedAtISO), "The saved plan has a valid timestamp")
        let plansBefore = try provider.fundingPlanRepo.plans(workspaceId: source.workspaceID)
        let sourceDigest = try NetWorthTestSupport.financialDigest(sqlite.database,
            excluding: ["monthly_plan_scratchpads", "intelligence_preferences"])
        let availability = ApplicationAvailability()
        availability.didHydrate(initial.hydrationResult, generation: provider.generationToken)
        var editor: SalaryWorkspaceViewModel? = SalaryWorkspaceViewModel(month: month, workspaceID: source.workspaceID,
            provider: { provider }, accountStore: accounts, transactionStore: transactions, salaryStore: salary,
            fundingPlanStore: funding, intelligenceStore: intelligence, locale: Locale(identifier: "en_US_POSIX"),
            now: { clock }, refresh: { _ in _ = try hydrator.hydrateIfNeeded(forceRefresh: true) })
        if let quote = savedPlan.effectiveAlDarReference {
            check(quote.submittedQAR.amount == 1, "The genuine saved reference is a unit quote")
            editor!.receiveSharedReference(try AlDarUnitReference(currency: .inr,
                rawToken: quote.returnedINR.rawToken, fetchedAtISO: quote.fetchedAtISO))
        }
        editor!.plannerOpened()
        editor!.flushPendingEntries()
        check(editor!.plan == savedPlan, "Opening the genuine plan does not change its financial inputs")
        let dashboard = DashboardViewModel(accountStore: accounts, transactionStore: transactions, cardStore: cards,
            fundingPlanStore: funding, intelligenceStore: intelligence, availability: availability,
            workspaceID: source.workspaceID, fundingMonth: month, fundingWorkspace: editor, now: { clock })
        editor!.setManualBalance(account, text: "-")
        #expect(editor!.retentionPending)
        dashboard.refreshPresentation()
        check(dashboard.fundingState == .unavailable && dashboard.fundingCalculation == nil,
            "Pending retention withholds Dashboard amounts")
        editor!.flushPendingEntries()
        #expect(!editor!.retentionPending)
        dashboard.refreshPresentation()
        check(dashboard.fundingState == .unavailable && dashboard.fundingCalculation == nil,
            "Retained incomplete entries withhold Dashboard amounts")
        let balanceKey = "balance.\(accountID)"
        let error = try required(editor!.fieldErrors[balanceKey], "Invalid editor text has an explicit retained error")
        if case .retained(let scratch) = editor!.retainedPlanPresentation(for: month, workspaceID: source.workspaceID,
            generation: provider.generationToken, canonical: savedPlan) {
            check(scratch.rawText[balanceKey] == "-" && scratch.fieldErrors[balanceKey] == error,
                "The bridge returns the successfully retained raw entry and error")
        } else { Issue.record("Matching ownership must expose the retained scratchpad") }
        let otherMonth = try SelectedStatementMonth(canonical: "2026-10")
        check(editor!.retainedPlanPresentation(for: otherMonth, workspaceID: source.workspaceID,
            generation: provider.generationToken, canonical: savedPlan) == nil,
            "Another month cannot use this editor's retained entries")
        check(editor!.retainedPlanPresentation(for: month, workspaceID: "another-workspace",
            generation: provider.generationToken, canonical: savedPlan) == nil,
            "Another workspace cannot use this editor's retained entries")
        if case .unavailable = editor!.retainedPlanPresentation(for: month, workspaceID: source.workspaceID,
            generation: ProviderGenerationToken(), canonical: savedPlan) {} else {
            Issue.record("A different provider generation must withhold retained amounts")
        }
        if case .unavailable = editor!.retainedPlanPresentation(for: month, workspaceID: source.workspaceID,
            generation: provider.generationToken, canonical: nil) {} else {
            Issue.record("A different canonical base must withhold retained amounts")
        }
        // Release the editor before the preference publication: its existing
        // preference subscriber would otherwise clear the live field error.
        editor = nil
        var excludedPreferences = oldPreferences
        excludedPreferences.excludedPlanningAccountIDs = (oldPreferences.excludedPlanningAccountIDs ?? []).union([accountID])
        try provider.intelligenceRepo.applyPlanning(.preferences(excludedPreferences, replacing: oldPreferences))
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let coldDashboard = DashboardViewModel(accountStore: accounts, transactionStore: transactions, cardStore: cards,
            fundingPlanStore: funding, intelligenceStore: intelligence, availability: availability,
            workspaceID: source.workspaceID, fundingMonth: month, now: { clock })
        coldDashboard.refreshPresentation()
        check(coldDashboard.fundingState == .populated && coldDashboard.fundingCalculation != nil,
            "An excluded account's incomplete entry does not withhold Dashboard amounts")
        let retained = try required(funding.scratchpads.first { $0.plan.month == month }, "Hydration retains the actual scratchpad")
        check(retained.rawText[balanceKey] == "-" && retained.fieldErrors[balanceKey] == error,
            "Excluding an account masks its balance error without erasing retained input")
        check(retained.canonical == savedPlan && retained.plan.effectiveAlDarReference == savedPlan.effectiveAlDarReference,
            "The cold Dashboard uses the retained canonical base and plan-local FX")
        try provider.intelligenceRepo.applyPlanning(.preferences(oldPreferences, replacing: excludedPreferences))
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        coldDashboard.refreshPresentation()
        check(coldDashboard.fundingState == .unavailable && coldDashboard.fundingCalculation == nil,
            "Reincluding the account restores withholding for its incomplete entry")
        check(try provider.fundingPlanRepo.plans(workspaceId: source.workspaceID) == plansBefore,
            "Invalid raw input and planning scope leave canonical plans unchanged")
        check(try NetWorthTestSupport.financialDigest(sqlite.database,
            excluding: ["monthly_plan_scratchpads", "intelligence_preferences"]) == sourceDigest,
            "The retained-entry check leaves all imported financial and source facts unchanged")
    }

    @Test(.globalRuntimeStateIsolation)
    func currentMonthSalaryFundingMapsSavedPlanExactlyOrReportsNotObserved() throws {
        let context = try dashboardCurrentDatabaseContext()
        let availability = ApplicationAvailability()
        availability.didHydrate(context.snapshot.hydrationResult, generation: context.provider.generationToken)
        let now = Date()
        let viewModel = DashboardViewModel(
            accountStore: context.accountStore,
            transactionStore: context.transactionStore,
            cardStore: context.cardStore,
            fundingPlanStore: context.fundingPlanStore,
            availability: availability,
            workspaceID: context.workspaceID,
            now: { now }
        )

        guard let month = DashboardViewModel.currentMonth(at: now),
              let plan = context.snapshot.fundingPlans.first(where: {
                  $0.workspaceID == context.workspaceID && $0.month == month
              }) else {
            check(viewModel.fundingCalculation == nil, "No current-month plan produces no dashboard calculation")
            notObserved("current-month-saved-plan")
            return
        }

        // Derive the expected scope from durable account metadata, independently
        // of the presentation scope helper. The saved plan stays untouched.
        let historyIDs = Set(try context.provider.accountRepo.accounts(workspaceId: context.workspaceID)
            .filter { $0.closedAtISO != nil }.map(\.id))
        let excluded = historyIDs.union(context.snapshot.intelligence?.preferences?.excludedPlanningAccountIDs ?? [])
        var currentPlan = plan
        currentPlan.balances.removeAll { excluded.contains($0.accountID) }
        currentPlan.qatarCommitments.removeAll { $0.fundingAccountID.map(historyIDs.contains) == true || plan.assistance?.billFundingAccounts?[$0.id].map(historyIDs.contains) == true }
        currentPlan.indiaCommitments.removeAll { $0.fundingAccountID.map(historyIDs.contains) == true || plan.assistance?.billFundingAccounts?[$0.id].map(historyIDs.contains) == true }
        if currentPlan.assistance?.payslipFunding.map({ historyIDs.contains($0.accountID) }) == true {
            currentPlan.assistance?.payslipFunding = nil
        }
        let expected = FundingPlanCalculator.calculate(currentPlan,
            salaryReceipt: PayslipReceiptState.resolve(plan: currentPlan, transactions: context.snapshot.transactions, excludedAccounts: excluded))
        guard let actual = viewModel.fundingCalculation else {
            check(false, "Saved current-month plan produces a dashboard calculation")
            return
        }
        for metric in DashboardFundingMetric.allCases {
            let expectedMoney: Money?
            switch metric {
            case .expected: expectedMoney = expected.expectedNet
            case .indiaShortfall: expectedMoney = expected.indiaFundingShortfall
            case .principal: expectedMoney = expected.requiredQARPrincipal
            case .investment: expectedMoney = expected.finalQARBuffer
            }
            check(
                sameMoney(metric.money(in: actual), expectedMoney),
                "Dashboard funding metric maps the accepted saved-plan result"
            )
        }
        check(actual.incompleteReasons == expected.incompleteReasons, "Dashboard funding completeness matches the saved-plan result")
        let expectedState: DashboardContentState = expected.incompleteReasons.contains(.invalidCurrency) ? .unavailable : .populated
        check(viewModel.fundingState == expectedState, "Dashboard funding state preserves complete or missing-input semantics")
        if expected.incompleteReasons.isEmpty {
            notObserved("saved-funding-plan-missing-input-shape")
        }
    }

    @Test
    func fundingMetricLabelsCurrenciesAndNilInputRemainExplicit() {
        for metric in DashboardFundingMetric.allCases {
            let expectedCurrency = metric == .indiaShortfall ? "INR" : "QAR"
            check(metric.currencyCode == expectedCurrency, "Funding metric exposes its accepted native currency")
            check(metric.money(in: nil) == nil, "Funding metric does not fabricate a value without a calculation")
        }
    }

    @Test
    func availabilityAndHydrationStatesCoverLoadingEmptyCurrentUnavailableAndRetained() {
        check(DashboardContentState.resolve(availability: .loading, isEmpty: true) == .loading, "Loading availability remains loading")
        check(DashboardContentState.resolve(availability: .empty, isEmpty: true) == .empty, "Empty availability remains empty")
        check(DashboardContentState.resolve(availability: .empty, isEmpty: false) == .populated, "Nonempty empty-generation data is populated")
        check(DashboardContentState.resolve(availability: .current, isEmpty: true) == .empty, "Current empty data is empty")
        check(DashboardContentState.resolve(availability: .current, isEmpty: false) == .populated, "Current data is populated")
        check(DashboardContentState.resolve(availability: .unavailable, isEmpty: false) == .unavailable, "Unavailable data is unavailable")
        check(DashboardContentState.resolve(availability: .retainedNonCurrent, isEmpty: false) == .unavailable, "Retained noncurrent data is unavailable")

        let availability = ApplicationAvailability()
        let viewModel = DashboardViewModel(
            accountStore: AccountStore(),
            transactionStore: TransactionStore(),
            cardStore: CardStore(),
            fundingPlanStore: FundingPlanStore(),
            availability: availability,
            now: { Date(timeIntervalSince1970: 0) }
        )
        viewModel.markHydrationStarted()
        check(viewModel.presentationState == .loading("Loading persisted dashboard..."), "Hydration start is loading")
        check(viewModel.positionState == .loading, "Hydration start resets positions to loading")
        check(viewModel.fundingState == .loading, "Hydration start resets funding to loading")

        viewModel.markHydrationCompleted(.init(didHydrate: true, accountCount: 1, transactionCount: 2))
        check(viewModel.presentationState == .loaded("Loaded 1 account(s), 2 transaction(s)"), "Hydration completion reports loaded")
        viewModel.markHydrationFailed(DashboardTestError.fixed)
        check(viewModel.presentationState == .failed("Dashboard load failed"), "Hydration failure reports unavailable")
        check(viewModel.positionState == .unavailable, "Hydration failure clears position state")
        check(viewModel.fundingState == .unavailable, "Hydration failure clears funding state")
        check(viewModel.positions.isEmpty && viewModel.fundingCalculation == nil, "Hydration failure clears projected values")

        availability.didHydrate(.init(didHydrate: true, accountCount: 0, transactionCount: 0), generation: ProviderGenerationToken())
        viewModel.refreshPresentation()
        check(viewModel.fundingState == .unavailable, "A stale funding generation is unavailable rather than an absent saved plan")
    }

    @Test
    func asOfLabelUsesOnlyOptionalStatementDateAndRoutesKeepApprovedDestinations() throws {
        let date = try StatementDate(year: 2026, month: 9, day: 11)
        let today = try StatementDate(year: 2026, month: 9, day: 21)
        check(DashboardAccountPosition.asOfLabel(for: date, today: today) == "10 days ago", "Age counts calendar days from the source balance date")
        check(DashboardAccountPosition.asOfLabel(for: today, today: today) == "Today", "Same-day balance")
        check(DashboardAccountPosition.asOfLabel(for: try StatementDate(canonical: "2026-09-20"), today: today) == "1 day ago", "Singular age")
        check(DashboardAccountPosition.asOfLabel(for: today, today: date) == "In 10 days", "Future date is not presented as fresh current data")
        check(DashboardAccountPosition.asOfLabel(for: nil) == "Date unavailable", "Missing as-of date remains unavailable")

        check(DashboardRoute.allCases.count == 3, "Dashboard exposes exactly three approved routes")
        check(DashboardRoute.transactions.destination == .transactions, "Transactions route selects Transactions")
        check(DashboardRoute.imports.destination == .imports, "Import route selects Import")
        check(DashboardRoute.salary.destination == .salary, "Salary route selects Salary")
        check(AppShellSection.ordinaryNavigation.first == .dashboard, "Dashboard remains the default ordinary navigation destination")
    }

    @Test
    func attentionOmitsNonReviewRoutesAndPassesExplicitReviewRoutes() {
        let omitted: [ConfirmedImportRecoveryRoute?] = [
            nil,
            ConfirmedImportRecoveryRoute.none,
            .unavailable,
            .prepareAgain(.persistenceUnavailable),
            .retryCanonicalReconciliation,
            .retryCanonicalReconciliationThenPrepareAgain
        ]
        for route in omitted {
            check(DashboardAttentionProjection.presentation(for: route) == nil, "Non-review import routes are omitted from Dashboard attention")
        }

        let reviewReasons: [ConfirmedImportRecoveryReason] = [
            .validationFailed,
            .exactStatementDuplicate,
            .transactionEventBlock,
            .accountChoiceRequired,
            .accountChoiceStale,
            .identityAmbiguous,
            .identityConflict,
            .identifierOwnershipConflict,
            .repositoryIntegrityConflict
        ]
        for reason in reviewReasons {
            let route: ConfirmedImportRecoveryRoute = .reviewRequired(reason)
            let projected = DashboardAttentionProjection.presentation(for: route)
            let accepted = ConfirmedImportRecoveryPresentationMapper.presentation(for: route)
            check(projected == accepted && projected != nil, "Explicit review-required route passes through unchanged")
            if let projected {
                check(projected.primaryAction == nil, "Review-required attention exposes no mutation action")
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func importActivityUsesHydratedLatestDurableAttemptOrNonfinancialIdleFallback() throws {
        let context = try dashboardCurrentDatabaseContext()
        let latest = ImportActivityPresentation.latestDurableAttempt(from: context.snapshot.importAttempts)
        let expectedLatest = latestImportAttemptOracle(context.snapshot.importAttempts)
        check(latest?.id == expectedLatest?.id, "Import Activity latest durable attempt selection is stable")

        let presentation = ImportActivityPresentation(importState: .idle, latestDurableAttempt: latest)
        if latest == nil {
            check(presentation.title == "No recent import", "Idle Import Activity reports no durable attempt")
            check(presentation.subtitle == "No durable import activity", "Idle Import Activity reports unavailable history")
            check(presentation.status == "Idle", "Idle Import Activity remains idle")
            check(presentation.iconName == "tray", "Idle Import Activity uses the tray icon")
            notObserved("durable-import-attempt")
        } else {
            check(presentation.title == "Last import attempt", "Idle Import Activity uses the latest durable attempt")
            check(!presentation.status.isEmpty && !presentation.subtitle.isEmpty, "Durable Import Activity has bounded presentation fields")
        }
    }

    @Test
    func shellSizingAndRailThresholdRemainDestinationSpecific() {
        check(AppShellSizing.minimumSize(for: .dashboard) == CGSize(width: 640, height: 608), "Dashboard minimum size remains accepted")
        check(AppShellSizing.minimumSize(for: .transactions) == CGSize(width: 1024, height: 736), "Transactions minimum size remains accepted")
        check(AppShellSizing.minimumSize(for: .settings) == CGSize(width: 760, height: 608), "Settings minimum size remains accepted")
        check(AppShellSizing.minimumSize(for: .accounts) == CGSize(width: 1180, height: 760), "Other screen minimum size remains accepted")
        check(AppShellSizing.dashboardUsesRail(at: 999), "Dashboard uses rail below the width threshold")
        check(!AppShellSizing.dashboardUsesRail(at: 1000), "Dashboard uses expanded navigation at the width threshold")
    }

    @Test(.globalRuntimeStateIsolation)
    func backgroundCalendarDayNotificationRefreshesThroughMainActorAfterInitialEmissionsDrain() async throws {
        let boundaries = try dashboardDayChangeBoundaries()
        guard let beforeMonth = DashboardViewModel.currentMonth(at: boundaries.before),
              let afterMonth = DashboardViewModel.currentMonth(at: boundaries.after) else {
            throw DashboardDayChangeTestError.invalidBoundary
        }
        let probe = DashboardDayChangeProbe(currentDate: boundaries.before)
        let availability = ApplicationAvailability()
        let viewModel = DashboardViewModel(
            accountStore: AccountStore(),
            transactionStore: TransactionStore(),
            cardStore: CardStore(),
            fundingPlanStore: FundingPlanStore(),
            availability: availability,
            workspaceID: "day-change-regression",
            now: { probe.now() }
        )
        let observation = viewModel.$storedTransactionCount.dropFirst().sink { _ in probe.didRefresh() }
        defer { withExtendedLifetime((viewModel, observation)) {} }

        await drainDashboardMainQueue()
        check(probe.refreshCount == 0, "Initial current-value emissions reuse the initial snapshot refresh")
        check(viewModel.fundingMonthTitle == SalaryWorkspaceViewModel.monthTitle(beforeMonth), "The initial funding month follows the selected month")
        probe.advance(to: boundaries.after)

        let postFinished = DispatchGroup()
        postFinished.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            dispatchPrecondition(condition: .notOnQueue(.main))
            NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
            postFinished.leave()
        }

        try await pumpDashboardMainRunLoopUntil(.backgroundNotificationTimeout) {
            postFinished.wait(timeout: .now()) == .success && probe.refreshCount > 0
        }
        check(probe.refreshCount == 1, "The background calendar notification publishes one refresh on MainActor")
        check(viewModel.fundingMonthTitle == SalaryWorkspaceViewModel.monthTitle(beforeMonth), "Calendar rollover preserves the selected funding month")
        viewModel.selectFundingMonth(afterMonth)
        check(viewModel.fundingMonthTitle == SalaryWorkspaceViewModel.monthTitle(afterMonth), "An explicit month selection updates the funding month")
    }

    @Test(.globalRuntimeStateIsolation)
    func coherentStoreNotificationsCoalesceAndAvailabilityWithdrawalIsImmediate() async throws {
        let context = try dashboardCurrentDatabaseContext()
        let availability = ApplicationAvailability()
        availability.didHydrate(context.snapshot.hydrationResult, generation: context.provider.generationToken)
        let probe = DashboardDayChangeProbe(currentDate: Date())
        let model = DashboardViewModel(
            accountStore: context.accountStore, transactionStore: context.transactionStore,
            cardStore: context.cardStore,
            fundingPlanStore: context.fundingPlanStore, availability: availability,
            workspaceID: context.workspaceID, now: { probe.now() }
        )
        let observation = model.$storedTransactionCount.dropFirst().sink { _ in probe.didRefresh() }
        defer { withExtendedLifetime((model, observation)) {} }
        await drainDashboardMainQueue()
        check(probe.refreshCount == 0, "The initial coherent projection has no redundant refresh")
        context.accountStore.notifyAccountsOfInstalledValue()
        context.transactionStore.notifyTransactionsOfInstalledValues()
        context.categoryStore.notifySnapshotOfInstalledValue()
        try await pumpDashboardMainRunLoopUntil(.initialEmissionsDrainedTimeout) { probe.refreshCount == 1 }
        check(probe.refreshCount == 1, "One refresh for the coherently installed store notifications")
        context.accountStore.notifyAccountsOfInstalledValue()
        availability.begin()
        check(model.positionState == .loading, "Loading invalidates synchronously")
        check(model.positions.isEmpty, "Old positions are withdrawn immediately")
        check(model.fundingCalculation == nil, "Old aggregates are withdrawn immediately")
        await drainDashboardMainQueue()
        check(probe.refreshCount == 1, "Withdrawal cancels the previously queued refresh")
    }
}

private enum DashboardTestError: Error {
    case fixed
    case databaseReadFailed
}

private enum DashboardDayChangeTestError: Error {
    case invalidBoundary
    case initialEmissionsDrainedTimeout
    case backgroundNotificationTimeout
}

@MainActor
private final class DashboardDayChangeProbe {
    private(set) var currentDate: Date
    private(set) var refreshCount = 0

    init(currentDate: Date) {
        self.currentDate = currentDate
    }

    func now() -> Date {
        MainActor.assertIsolated()
        return currentDate
    }

    func didRefresh() {
        MainActor.assertIsolated()
        refreshCount += 1
    }

    func advance(to date: Date) {
        currentDate = date
    }
}

@MainActor
private func drainDashboardMainQueue() async {
    await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
    }
}

@MainActor
private func dashboardDayChangeBoundaries() throws -> (before: Date, after: Date) {
    let calendar = Calendar(identifier: .gregorian)
    guard let before = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12)),
          let after = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12)),
          DashboardViewModel.currentMonth(at: before) != DashboardViewModel.currentMonth(at: after) else {
        throw DashboardDayChangeTestError.invalidBoundary
    }
    return (before, after)
}

@MainActor
private func pumpDashboardMainRunLoopUntil(
    _ timeout: DashboardDayChangeTestError,
    condition: () -> Bool
) async throws {
    let deadline = Date(timeIntervalSinceNow: 2)
    while !condition() {
        guard Date() < deadline else { throw timeout }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private struct DashboardReadOnlyContext {
    let provider: SQLiteRepositoryProvider
    let databaseURL: URL
    let workspaceID: String
    let snapshot: RepositoryRuntimeSnapshot
    let bankSections: [BankStatementSectionPlanDTO]
    let zeroControls: [StatementZeroActivityControlDTO]
    let accountStore: AccountStore
    let transactionStore: TransactionStore
    let cardStore: CardStore
    let categoryStore: CategoryStore
    let salaryStore: SalaryStore
    let fundingPlanStore: FundingPlanStore
    let importSessionStore: ImportSessionStore
}

@MainActor
private enum AcceptedDashboardSnapshot {
    static var cached: DashboardReadOnlyContext?
}

@MainActor
private func dashboardCurrentDatabaseContext() throws -> DashboardReadOnlyContext {
    if let cached = AcceptedDashboardSnapshot.cached { return cached }

    let databaseURL = try AuthenticSourceTestSupport.presentationDatabaseURL()
    let provider = try AuthenticSourceTestSupport.readOnlyRegisteredProvider(at: databaseURL)
    try provider.database.execute(sql: "PRAGMA query_only = ON;")
    // The owner may import in the separate app process during this read-only
    // check. All hydration queries must observe one committed SQLite snapshot.
    try provider.database.execute(sql: "BEGIN DEFERRED TRANSACTION;")
    defer { try? provider.database.execute(sql: "ROLLBACK;") }
    let workspaces = try provider.database.query(sql: "SELECT id FROM workspaces ORDER BY id", params: []) {
        $0.string(at: 0)
    }.compactMap { $0 }
    guard workspaces.count == 1, let workspaceID = workspaces.first else {
        throw RepositoryError.persistenceUnavailable
    }

    let accountStore = AccountStore()
    let transactionStore = TransactionStore()
    let cardStore = CardStore()
    let categoryStore = CategoryStore()
    let salaryStore = SalaryStore()
    let fundingPlanStore = FundingPlanStore()
    let importSessionStore = ImportSessionStore()
    let hydrator = RepositoryStoreHydrator(
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        categoryRepo: provider.categoryRepo,
        cardRepo: provider.cardRepo,
        salaryRepo: provider.salaryRepo,
        fundingPlanRepo: provider.fundingPlanRepo,
        accountStore: accountStore,
        transactionStore: transactionStore,
        categoryStore: categoryStore,
        cardStore: cardStore,
        salaryStore: salaryStore,
        fundingPlanStore: fundingPlanStore,
        importSessionStore: importSessionStore,
        importAttemptStore: ImportAttemptStore(),
        workspaceId: workspaceID,
        persistenceState: .verifiedSQLite,
        providerGeneration: provider.generationToken,
        participatesInLifecycleGate: false
    )
    let snapshot = try hydrator.stageHydration()
    hydrator.publish(snapshot)
    let context = DashboardReadOnlyContext(
        provider: provider,
        databaseURL: databaseURL,
        workspaceID: workspaceID,
        snapshot: snapshot,
        bankSections: try provider.importSessionRepo.bankSectionSnapshot(workspaceId: workspaceID).sections,
        zeroControls: try provider.importSessionRepo.statementZeroActivityControls(workspaceId: workspaceID),
        accountStore: accountStore,
        transactionStore: transactionStore,
        cardStore: cardStore,
        categoryStore: categoryStore,
        salaryStore: salaryStore,
        fundingPlanStore: fundingPlanStore,
        importSessionStore: importSessionStore
    )
    AcceptedDashboardSnapshot.cached = context
    return context
}

private struct DatabaseFiles: Equatable {
    let database: Data?
    let wal: Data?
}

@MainActor
private func databaseFiles(_ context: DashboardReadOnlyContext) throws -> DatabaseFiles {
    guard let database = try? Data(contentsOf: context.databaseURL) else {
        throw DashboardTestError.databaseReadFailed
    }
    let walURL = URL(fileURLWithPath: context.databaseURL.path + "-wal")
    let wal: Data?
    if FileManager.default.fileExists(atPath: walURL.path) {
        guard let value = try? Data(contentsOf: walURL) else {
            throw DashboardTestError.databaseReadFailed
        }
        wal = value
    } else {
        wal = nil
    }
    return DatabaseFiles(database: database, wal: wal)
}

private struct OraclePosition {
    let id: String
    let displayName: String
    let institution: String
    let amount: Money?
    let asOf: StatementDate?
    let sourceContext: String?
    let sourcePeriodEnd: StatementDate?
}

private struct OracleCurrencyPosition {
    let currency: CurrencyCode
    let banks: [OraclePosition]
    let cards: [OraclePosition]
    let bankTotal: Money?
    let cardTotal: Money?
}

@MainActor
private func oracleDisplayName(_ account: Account, context: DashboardReadOnlyContext) -> String {
    if let nickname = account.nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nickname }
    let identifierOnly = !account.name.isEmpty && account.name.allSatisfy { "0123456789Xx* -".contains($0) }
    guard identifierOnly else { return account.name }
    let labels = context.bankSections.filter { $0.accountId == account.repositoryAccountId }.map(\.productLabel)
    let roles = Set(labels.flatMap { label in
        ["NRE", "NRO"].filter { label.uppercased().range(of: "\\b" + $0 + "\\b", options: .regularExpression) != nil }
    })
    if account.type == .bank, ["Axis Bank", "HDFC Bank"].contains(account.institution),
       roles.count == 1, let role = roles.first {
        return String(account.institution.split(separator: " ")[0]) + " " + role
    }
    return account.institution + " account"
}

@MainActor
private func dashboardPositionOracle(context: DashboardReadOnlyContext) -> [OracleCurrencyPosition] {
    let snapshot = context.snapshot
    let eligible = snapshot.accounts
        .filter { ($0.type == .bank || $0.type == .creditCard) && !$0.isHistoryOnly }
        .sorted(by: oracleAccountPrecedes)
    let banks = eligible.compactMap { account -> (CurrencyCode, OraclePosition)? in
        guard account.type == .bank else { return nil }
        let selected = oracleBankBalance(for: account, context: context)
        let amount = selected?.money.currency == account.nativeCurrency ? selected?.money : nil
        return (
            account.nativeCurrency,
            OraclePosition(
                id: oraclePositionID(account),
                displayName: oracleDisplayName(account, context: context),
                institution: account.institution,
                amount: amount,
                asOf: amount == nil ? nil : selected?.date,
                sourceContext: nil,
                sourcePeriodEnd: nil
            )
        )
    }
    let cards = eligible.compactMap { account -> (CurrencyCode, OraclePosition)? in
        guard account.type == .creditCard else { return nil }
        let selected = oracleCardStatement(for: account, snapshot: snapshot.cardSnapshot)
        let amount: Money?
        if let selected,
           let newBalance = selected.newBalance,
           selected.currency == account.nativeCurrency,
           newBalance.currency == account.nativeCurrency {
            amount = newBalance
        } else {
            amount = nil
        }
        return (
            account.nativeCurrency,
            OraclePosition(
                id: oraclePositionID(account),
                displayName: oracleDisplayName(account, context: context),
                institution: account.institution,
                amount: amount,
                asOf: amount == nil ? nil : selected?.statementDate,
                sourceContext: amount == nil || selected?.statementDate != nil
                    ? nil
                    : oracleCardSourceContext(selected),
                sourcePeriodEnd: amount == nil ? nil : selected?.period?.end
            )
        )
    }

    let currencies = Set(banks.map(\.0)).union(cards.map(\.0)).sorted { $0.code < $1.code }
    return currencies.map { currency in
        let bankPositions = banks.filter { $0.0 == currency }.map(\.1)
        let cardPositions = cards.filter { $0.0 == currency }.map(\.1)
        return OracleCurrencyPosition(
            currency: currency,
            banks: bankPositions,
            cards: cardPositions,
            bankTotal: oracleAggregate(bankPositions, currency: currency),
            cardTotal: oracleAggregate(cardPositions, currency: currency)
        )
    }
}

@MainActor
private func oraclePositionID(_ account: Account) -> String {
    account.repositoryAccountId ?? account.id.uuidString
}

@MainActor
private func oracleAccountPrecedes(_ lhs: Account, _ rhs: Account) -> Bool {
    let left = (lhs.institution, lhs.nickname ?? lhs.name, oraclePositionID(lhs))
    let right = (rhs.institution, rhs.nickname ?? rhs.name, oraclePositionID(rhs))
    if left.0 != right.0 { return left.0 < right.0 }
    if left.1 != right.1 { return left.1 < right.1 }
    return left.2 < right.2
}

@MainActor
private func oracleAggregate(_ positions: [OraclePosition], currency: CurrencyCode) -> Money? {
    guard !positions.isEmpty, positions.allSatisfy({ $0.amount?.currency == currency }) else { return nil }
    return try? Money.aggregate(positions.compactMap(\.amount))
}

/// Independently include source-owned zero-activity closings, which can be
/// later than the last transaction. Read persisted evidence, not the hydrated
/// account's selected date or the production balance selector.
@MainActor
private func oracleBankBalance(for account: Account, context: DashboardReadOnlyContext) -> (money: Money, date: StatementDate)? {
    let transaction = oracleTransactionBalance(for: account, transactions: context.snapshot.transactions)
    let controls = context.zeroControls.filter { $0.accountId == account.repositoryAccountId }
    var observations: [(Money, StatementDate)] = []
    for control in controls where control.authorityRole == "authoritative" {
        if let decimal = control.closingBalanceDecimal,
           let day = control.statementDateISO ?? control.statementEndDateISO,
           let money = try? Money(canonicalDecimal: decimal, currency: control.nativeCurrency),
           let date = try? StatementDate(canonical: day) { observations.append((money, date)) }
    }
    for section in context.bankSections where section.accountId == account.repositoryAccountId && section.rows.isEmpty {
        guard !controls.contains(where: { $0.documentId == section.documentId && $0.authorityRole == "supporting" }) else { continue }
        let evidence = section.sourceEvidence
        if let decimal = evidence.closingBalanceDecimal,
           let day = evidence.statementBoundaryDateISO ?? evidence.statementEndDateISO,
           let money = try? Money(canonicalDecimal: decimal, currency: section.nativeCurrency),
           let date = try? StatementDate(canonical: day) { observations.append((money, date)) }
    }
    guard let newest = observations.map({ $0.1 }).max() else { return transaction }
    if let transaction, transaction.date > newest { return transaction }
    let latest = observations.filter { $0.1 == newest }
    guard let money = latest.first?.0, money.currency == account.nativeCurrency,
          latest.allSatisfy({ $0.0 == money }) else { return nil }
    if context.snapshot.transactions.contains(where: { $0.repositoryAccountId == account.repositoryAccountId && $0.runningBalanceMoney != nil && $0.statementDate == newest }),
       transaction?.money != money { return nil }
    return (money, newest)
}

@MainActor
private func oracleTransactionBalance(
    for account: Account,
    transactions: [Transaction]
) -> (money: Money, date: StatementDate)? {
    guard let accountID = account.repositoryAccountId else { return nil }
    let dated = transactions.compactMap { transaction -> (transaction: Transaction, money: Money, date: StatementDate)? in
        guard transaction.repositoryAccountId == accountID,
              let date = transaction.statementDate,
              let money = transaction.runningBalanceMoney else { return nil }
        return (transaction, money, date)
    }
    guard let latestDate = dated.map(\.date).max() else { return nil }
    let candidates = dated.filter { $0.date == latestDate }
    let selected: (transaction: Transaction, money: Money, date: StatementDate)?
    if let documentID = candidates.first?.transaction.documentScopedSourceOrder?.documentID,
       candidates.allSatisfy({ $0.transaction.documentScopedSourceOrder?.documentID == documentID }) {
        selected = candidates.max {
            ($0.transaction.documentScopedSourceOrder?.ordinal ?? 0)
                < ($1.transaction.documentScopedSourceOrder?.ordinal ?? 0)
        }
    } else {
        selected = candidates.count == 1 ? candidates.first : nil
    }
    guard let selected, selected.money.currency == account.nativeCurrency else { return nil }
    return (selected.money, selected.date)
}

@MainActor
private func oracleCardStatement(for account: Account, snapshot: CardStoreSnapshot) -> CardStatement? {
    guard let accountID = account.repositoryAccountId else { return nil }
    let statements = snapshot.statements.filter { $0.liabilityAccountID == accountID }
    if statements.allSatisfy({ !$0.parserProfileID.hasPrefix("axis.credit-card.") }) {
        return statements.max { lhs, rhs in
            let leftDate = lhs.statementDate?.canonical ?? ""
            let rightDate = rhs.statementDate?.canonical ?? ""
            if leftDate != rightDate { return leftDate < rightDate }
            let leftEnd = lhs.period?.end.canonical ?? ""
            let rightEnd = rhs.period?.end.canonical ?? ""
            if leftEnd != rightEnd { return leftEnd < rightEnd }
            return lhs.id < rhs.id
        }
    }

    func cycleMonth(_ statement: CardStatement) -> String? {
        if let month = statement.selectedStatementMonth { return month.canonical }
        if let date = statement.statementDate { return String(format: "%04d-%02d", date.year, date.month) }
        if let end = statement.period?.end { return String(format: "%04d-%02d", end.year, end.month) }
        return nil
    }

    let keyed = statements.compactMap { statement in cycleMonth(statement).map { ($0, statement) } }
    guard let latestMonth = keyed.map(\.0).max() else { return nil }
    let cycle = keyed.filter { $0.0 == latestMonth }.map(\.1)
    if let exactDate = cycle.compactMap(\.statementDate).max() {
        let exact = cycle.filter { $0.statementDate == exactDate }
        let groupIDs = Set(exact.compactMap(\.semanticGroupID))
        return exact.count == 1 || (groupIDs.count == 1 && exact.allSatisfy { $0.semanticGroupID != nil })
            ? exact.first
            : nil
    }
    let groupIDs = Set(cycle.compactMap(\.semanticGroupID))
    return cycle.count == 1 || (groupIDs.count == 1 && cycle.allSatisfy { $0.semanticGroupID != nil })
        ? cycle.first
        : nil
}

@MainActor
private func oracleCardSourceContext(_ statement: CardStatement?) -> String? {
    guard let statement else { return nil }
    if let period = statement.period {
        return "Statement period \(period.start.presentation)–\(period.end.presentation)"
    }
    if let month = statement.selectedStatementMonth {
        return "Statement month \(month.canonical)"
    }
    return nil
}

@MainActor
private func assertPositions(_ actual: [DashboardCurrencyPosition], equalTo expected: [OracleCurrencyPosition]) {
    check(actual.count == expected.count, "Dashboard currency-group count matches independent oracle")
    for (actualGroup, expectedGroup) in zip(actual, expected) {
        check(actualGroup.currency == expectedGroup.currency, "Dashboard currency group preserves native currency")
        assertAccountPositions(actualGroup.banks, equalTo: expectedGroup.banks)
        assertAccountPositions(actualGroup.cards, equalTo: expectedGroup.cards)
        check(sameMoney(actualGroup.bankTotal, expectedGroup.bankTotal), "Dashboard bank total sums only known same-currency members")
        check(sameMoney(actualGroup.cardTotal, expectedGroup.cardTotal), "Dashboard card total sums only known same-currency members")
    }
}

@MainActor
private func assertAccountPositions(_ actual: [DashboardAccountPosition], equalTo expected: [OraclePosition]) {
    check(actual.count == expected.count, "Dashboard account membership matches independent domain oracle")
    for (actualPosition, expectedPosition) in zip(actual, expected) {
        check(actualPosition.id == expectedPosition.id, "Dashboard account identity is durable")
        let displayName = expectedPosition.displayName.replacingOccurrences(of: "Commercial Bank of Qatar", with: "CBQ", options: .caseInsensitive)
        let institution = expectedPosition.institution.replacingOccurrences(of: "Commercial Bank of Qatar", with: "CBQ", options: .caseInsensitive)
        check(actualPosition.displayName == displayName, "Dashboard account name follows the approved CBQ abbreviation")
        check(actualPosition.institution == institution, "Dashboard institution follows the approved CBQ abbreviation")
        check(sameMoney(actualPosition.amount, expectedPosition.amount), "Dashboard account amount matches selected source money")
        check(actualPosition.asOf == expectedPosition.asOf, "Dashboard account as-of date is source-backed")
        check(actualPosition.sourceContext == expectedPosition.sourceContext, "Dashboard account source context remains optional")
        check(actualPosition.sourcePeriodEnd == expectedPosition.sourcePeriodEnd,
              "Printed period end remains separate from the optional balance date")
    }
}

@MainActor
private func assertCanonicalBalancesMatchSelectedEvidence(context: DashboardReadOnlyContext) {
    let snapshot = context.snapshot
    for account in snapshot.accounts where account.type == .bank {
        guard let selected = oracleBankBalance(for: account, context: context) else { continue }
        check(sameMoney(account.currentBalanceMoney, selected.money), "Hydrated bank balance matches selected running balance")
        check(account.currentBalanceAsOfISO == selected.date.canonical, "Hydrated bank balance date matches independently selected source date")
    }
    for account in snapshot.accounts where account.type == .creditCard {
        guard let selected = oracleCardStatement(for: account, snapshot: snapshot.cardSnapshot),
              let newBalance = selected.newBalance else { continue }
        guard let negated = try? Money(amount: -newBalance.amount, currency: newBalance.currency) else {
            check(false, "Hydrated card balance can be compared with selected statement balance")
            continue
        }
        check(sameMoney(account.currentBalanceMoney, negated), "Hydrated card balance is the negation of selected statement balance")
    }
}

@MainActor
private func latestImportAttemptOracle(_ attempts: [RepositoryImportAttempt]) -> RepositoryImportAttempt? {
    attempts.max { lhs, rhs in
        switch (importAttemptDate(lhs.createdAtISO), importAttemptDate(rhs.createdAtISO)) {
        case let (left?, right?) where left != right:
            return left < right
        case (.some, nil):
            return false
        case (nil, .some):
            return true
        default:
            return lhs.id < rhs.id
        }
    }
}

@MainActor
private func importAttemptDate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
}

@MainActor
private func sameMoney(_ lhs: Money?, _ rhs: Money?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): return true
    case let (left?, right?): return left.currency == right.currency && left.amount == right.amount
    default: return false
    }
}

@MainActor
private func check(_ condition: Bool, _ label: String) {
    #expect(condition, "\(label)")
}

@MainActor
private func notObserved(_ caseName: String) {
    print("NOT_OBSERVED \(caseName)")
}
