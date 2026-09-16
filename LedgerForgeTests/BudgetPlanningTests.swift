import Foundation
import XCTest
@testable import LedgerForge

/// Ordinary manual planning estimates and source-independent arithmetic.
/// No statement, payslip, transaction, or captured bank evidence is fabricated.
@MainActor
final class BudgetPlanningTests: XCTestCase {
    private func money(_ value: String, _ currency: String = "QAR") throws -> Money {
        try Money(amount: XCTUnwrap(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))), currency: currency)
    }
    private func editor(month: String = "2026-09", active: DatabaseProvider? = nil, store: FundingPlanStore? = nil, opened: Bool = true) throws -> (SalaryWorkspaceViewModel, DatabaseProvider, FundingPlanStore) {
        let memory = InMemoryRepositoryProvider()
        let provider = active ?? DatabaseProvider(workspaceRepo: memory.workspaceRepo, transactionRepo: memory.transactionRepo,
            accountRepo: memory.accountRepo, importSessionRepo: memory.importSessionRepo, fundingPlanRepo: memory.fundingPlanRepo)
        let plans = store ?? FundingPlanStore()
        if store == nil { plans.installWithoutObservation([], generation: provider.generationToken) }
        let vm = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(canonical: month), provider: { provider },
            accountStore: AccountStore(), salaryStore: SalaryStore(), fundingPlanStore: plans, locale: Locale(identifier: "en_US_POSIX"),
            refresh: { current in
                _ = try RepositoryStoreHydrator(accountRepo: current.accountRepo, importSessionRepo: current.importSessionRepo,
                    transactionRepo: current.transactionRepo, fundingPlanRepo: current.fundingPlanRepo,
                    accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(),
                    cardStore: CardStore(), salaryStore: SalaryStore(), fundingPlanStore: plans,
                    importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
                    providerGeneration: current.generationToken, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            })
        if opened { vm.plannerOpened() }
        return (vm, provider, plans)
    }
    private func bill(_ vm: SalaryWorkspaceViewModel, region: String, amount: String, name: String = "My bill") throws -> String {
        vm.addCommitment(region: region)
        let id = try XCTUnwrap((region == "qatar" ? vm.plan.qatarCommitments : vm.plan.indiaCommitments).last?.id)
        vm.updateCommitment(region: region, id: id, label: name, amountText: amount, included: true, fundingAccountID: nil)
        return id
    }
    private func inputPlan() throws -> FundingPlan {
        let (vm, _, _) = try editor()
        _ = vm.updateMoney(.fixed, text: "1000"); _ = vm.updateMoney(.variable, text: "200")
        _ = vm.updateMoney(.reserve, text: "100"); _ = vm.updateMoney(.fee, text: "10")
        vm.addDeduction(); let id = try XCTUnwrap(vm.plan.deductions.first?.id)
        vm.editDeduction(id: id, label: "My deduction", amount: "50")
        _ = try bill(vm, region: "qatar", amount: "300")
        _ = try bill(vm, region: "india", amount: "600")
        vm.setFX(rateText: "3", dateText: "2026-09-15")
        var plan = vm.plan
        plan.balances = [.init(id: "manual-balance", accountID: "my-selected-bank", nativeCurrency: try CurrencyCode("QAR"), included: true, money: try money("100"), provenance: .manual)]
        return plan
    }

    func testWorksheetNormalCaseReserveAndFeeCountOnce() throws {
        let c = FundingPlanCalculator.calculate(try inputPlan())
        XCTAssertEqual(c.totalDeductions, try money("50")); XCTAssertEqual(c.expectedNet, try money("1150"))
        XCTAssertEqual(c.positionBeforeTransfer, try money("850"))
        XCTAssertEqual(c.signedPotentialCapacity, try money("840")); XCTAssertEqual(c.transferablePrincipal, try money("840"))
        XCTAssertEqual(c.estimatedINR, try money("2520", "INR"))
        XCTAssertEqual(c.indiaCommitments, try money("600", "INR")); XCTAssertEqual(c.requiredQARPrincipal, try money("200"))
        XCTAssertEqual(c.finalQARBuffer, try money("640")); XCTAssertEqual(c.effectiveTransferFee, try money("10"))
    }

    func testZeroTransferOptionalINRFundsAndDeficitRemainIndependent() throws {
        var plan = try inputPlan()
        plan.balances.append(.init(id: "manual-inr", accountID: "my-selected-inr-bank", nativeCurrency: try CurrencyCode("INR"), included: false, money: try money("600", "INR"), provenance: .manual))
        XCTAssertEqual(FundingPlanCalculator.calculate(plan).indiaFundingShortfall, try money("600", "INR"))
        plan.balances[1].included = true
        var c = FundingPlanCalculator.calculate(plan)
        XCTAssertEqual(c.indiaCommitments, try money("600", "INR")); XCTAssertEqual(c.indiaFundingShortfall, try money("0", "INR"))
        XCTAssertEqual(c.requiredQARPrincipal, try money("0")); XCTAssertEqual(c.effectiveTransferFee, try money("0"))
        XCTAssertEqual(c.finalQARBuffer, try money("850")); XCTAssertEqual(c.transferablePrincipal, try money("840"))
        plan.balances[1].included = false; plan.expectedFixedEarnings = try money("0")
        c = FundingPlanCalculator.calculate(plan)
        XCTAssertEqual(c.positionBeforeTransfer, try money("-150")); XCTAssertEqual(c.signedPotentialCapacity, try money("-160"))
        XCTAssertEqual(c.transferablePrincipal, try money("0")); XCTAssertEqual(c.requiredQARPrincipal, try money("200"))
        XCTAssertEqual(c.finalQARBuffer, try money("-360"))
    }

    func testMissingRatePreservesQatarAndZeroRequirementDoesNotNeedFX() throws {
        var plan = try inputPlan(); plan.planningFX = nil; plan.referenceMode = .alDar
        var c = FundingPlanCalculator.calculate(plan)
        XCTAssertEqual(c.transferablePrincipal, try money("840")); XCTAssertNil(c.requiredQARPrincipal); XCTAssertNil(c.finalQARBuffer)
        plan.indiaCommitments = []
        c = FundingPlanCalculator.calculate(plan)
        XCTAssertEqual(c.requiredQARPrincipal, try money("0")); XCTAssertEqual(c.finalQARBuffer, try money("850"))
        XCTAssertFalse(c.incompleteReasons.contains(.missingPlanningFX))
        plan.balances[0].money = nil
        c = FundingPlanCalculator.calculate(plan)
        XCTAssertNil(c.selectedQARLiquidity); XCTAssertNil(c.transferablePrincipal)
        XCTAssertTrue(c.incompleteReasons.contains(.includedQARBalanceMissing))
    }

    func testDeductionsAreNonnegativeAndTicketReductionChangesSubtotal() throws {
        let (vm, active, _) = try editor(); _ = vm.updateMoney(.fixed, text: "100")
        vm.addDeduction(); let id = try XCTUnwrap(vm.plan.deductions.first?.id)
        vm.editDeduction(id: id, label: "My ticket", amount: "30")
        XCTAssertEqual(vm.calculation.expectedNet, try money("70"))
        vm.editDeduction(id: id, amount: "10")
        XCTAssertEqual(vm.calculation.expectedNet, try money("90"))
        vm.editDeduction(id: id, amount: "-10"); vm.save()
        XCTAssertEqual(vm.rawText["deduction.amount.\(id)"], "-10"); XCTAssertFalse(vm.canSave)
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
        vm.editDeduction(id: id, amount: "0"); vm.save()
        XCTAssertEqual(vm.saveState, .saved); XCTAssertEqual(vm.calculation.totalDeductions, try money("0"))
    }

    func testOrdinaryEditsCarryOneOffsOmitAndTemporaryPaidAmountRetainsBasis() throws {
        let (vm, active, store) = try editor()
        let ordinary = try bill(vm, region: "qatar", amount: "100", name: "My recurring bill")
        vm.editCommitment(region: "qatar", id: ordinary, field: "amount", text: "120")
        vm.setCommitmentDetails(region: "qatar", id: ordinary, temporary: true)
        vm.editCommitment(region: "qatar", id: ordinary, field: "amount", text: "0")
        let once = try bill(vm, region: "india", amount: "10", name: "My one-off bill")
        vm.setCommitmentDetails(region: "india", id: once, recurs: false)
        vm.addDeduction(); let regular = try XCTUnwrap(vm.plan.deductions.last?.id)
        vm.editDeduction(id: regular, label: "My recurring deduction", amount: "5")
        vm.addDeduction(); let oneDeduction = try XCTUnwrap(vm.plan.deductions.last?.id)
        vm.editDeduction(id: oneDeduction, label: "My ticket", amount: "2", recurs: false)
        vm.save(); XCTAssertEqual(vm.saveState, .saved)
        let previous = try active.fundingPlanRepo.plans(workspaceId: "default-workspace")
        let next = try editor(month: "2026-10", active: active, store: store).0
        XCTAssertEqual(next.plan.qatarCommitments.first?.money, try money("120"))
        XCTAssertNil(next.plan.qatarCommitments.first?.temporaryCarryBasis)
        XCTAssertNotEqual(next.plan.qatarCommitments.first?.id, ordinary)
        XCTAssertEqual(next.plan.qatarCommitments.first?.carriedSourceRowID, ordinary)
        XCTAssertTrue(next.plan.indiaCommitments.isEmpty)
        XCTAssertEqual(next.plan.deductions.count, 1); XCTAssertEqual(next.plan.deductions.first?.money, try money("5"))
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace"), previous)
        next.save(); XCTAssertEqual(next.saveState, .saved)
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").first, previous.first)
    }

    func testOpeningDashboardDoesNotCreateAnInvisibleSeededDraft() throws {
        let (first, active, store) = try editor()
        _ = first.updateMoney(.fixed, text: "100"); first.save()
        let next = try editor(month: "2026-10", active: active, store: store, opened: false).0
        XCTAssertFalse(next.hasUnsavedDrafts)
        XCTAssertNil(next.plan.rolloverSourcePlanID)
        next.plannerOpened()
        XCTAssertTrue(next.hasUnsavedDrafts)
        XCTAssertEqual(next.plan.expectedFixedEarnings, try money("100"))
    }

    func testLegacyScalarDeductionRemainsVisibleWhenSeedingTheWorksheet() throws {
        var prior = try inputPlan()
        prior.calculationVersion = .legacy
        prior.expectedDeductions = try money("50"); prior.deductions = []
        let (_, active, store) = try editor()
        store.installWithoutObservation([prior], generation: active.generationToken)
        let next = try editor(month: "2026-10", active: active, store: store).0
        XCTAssertEqual(next.plan.deductions.first?.label, "Prior deduction total · unitemized")
        XCTAssertEqual(next.plan.deductions.first?.money, try money("50"))
        XCTAssertEqual(next.calculation.expectedNet, try money("1150"))
        XCTAssertFalse(next.plan.deductions.first?.recurs ?? true)
    }

    func testTemporaryBillReductionCanBeChosenAfterEditingAndSwitchingMonths() throws {
        let (vm, active, store) = try editor()
        let id = try bill(vm, region: "qatar", amount: "120")
        vm.save()
        vm.editCommitment(region: "qatar", id: id, field: "amount", text: "0")
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-09"))
        vm.setCommitmentDetails(region: "qatar", id: id, temporary: true)
        XCTAssertEqual(vm.plan.qatarCommitments.first?.temporaryCarryBasis, try money("120"))
        vm.save(); XCTAssertEqual(vm.saveState, .saved)
        let reopenedNext = try editor(month: "2026-10", active: active, store: store).0
        XCTAssertEqual(reopenedNext.plan.qatarCommitments.first?.money, try money("120"))
    }

    func testRemovingTemporaryExceptionRestoresBasisAndInvalidSaveCannotReuseOldAmount() throws {
        let (vm, active, _) = try editor()
        let id = try bill(vm, region: "qatar", amount: "120")
        vm.setCommitmentDetails(region: "qatar", id: id, temporary: true)
        vm.editCommitment(region: "qatar", id: id, field: "amount", text: "0")
        vm.setCommitmentDetails(region: "qatar", id: id, temporary: false)
        XCTAssertEqual(vm.plan.qatarCommitments.first?.money, try money("120"))
        XCTAssertEqual(vm.rawText["amount.\(id)"], "120")
        vm.save(); let saved = try active.fundingPlanRepo.plans(workspaceId: "default-workspace")
        vm.editCommitment(region: "qatar", id: id, field: "amount", text: "-1"); vm.save()
        XCTAssertEqual(vm.rawText["amount.\(id)"], "-1"); XCTAssertFalse(vm.canSave)
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace"), saved)
    }

    func testExistingTargetPlanIsNotOverwrittenAndIncompleteDraftSurvivesSwitching() throws {
        let (vm, active, store) = try editor(); _ = vm.updateMoney(.fixed, text: "100"); vm.save()
        let next = try editor(month: "2026-10", active: active, store: store).0
        _ = next.updateMoney(.fixed, text: "200"); next.save()
        _ = vm.updateMoney(.fixed, text: "300.")
        vm.switchMonth(to: next.month)
        XCTAssertEqual(vm.plan.expectedFixedEarnings, try money("200"))
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-09"))
        XCTAssertEqual(vm.rawText["fixed"], "300."); XCTAssertFalse(vm.canSave)
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").count, 2)
    }

    func testAnyFutureMonthCanBeChosenWithoutLosingOtherDrafts() throws {
        let (vm, active, _) = try editor()
        _ = vm.updateMoney(.fixed, text: "100.")
        let future = try SelectedStatementMonth(canonical: "2031-04")
        vm.switchMonth(to: future); XCTAssertEqual(vm.month, future); XCTAssertTrue(vm.canEdit)
        _ = vm.updateMoney(.fixed, text: "250")
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-09"))
        XCTAssertEqual(vm.rawText["fixed"], "100.")
        vm.switchMonth(to: future); XCTAssertEqual(vm.plan.expectedFixedEarnings, try money("250"))
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-08"))
        XCTAssertEqual(vm.month, future)
        let last = try SelectedStatementMonth(canonical: "2099-12")
        vm.switchMonth(to: last); XCTAssertEqual(vm.month, last); XCTAssertTrue(vm.canEdit)
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2100-01"))
        XCTAssertEqual(vm.month, last)
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
    }

    func testSwitchingWithSharedFXSeedsSavedRowsBeforeMakingTheNewDraftDirty() throws {
        let (vm, active, _) = try editor()
        _ = vm.updateMoney(.fixed, text: "700")
        _ = try bill(vm, region: "india", amount: "120")
        vm.setFX(rateText: "4", dateText: "2026-09-15")
        vm.save(); XCTAssertEqual(vm.saveState, .saved)
        vm.receiveSharedReference(try AlDarUnitReference(currency: .inr, rawToken: "3", fetchedAtISO: "2026-09-16T08:00:00Z"))
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        XCTAssertEqual(vm.plan.expectedFixedEarnings, try money("700"))
        XCTAssertEqual(vm.plan.indiaCommitments.first?.money, try money("120", "INR"))
        XCTAssertEqual(vm.plan.referenceMode, .alDar)
        XCTAssertEqual(vm.plan.effectiveAlDarReference?.returnedINR.rawToken, "3")
        XCTAssertNil(vm.errorMessage); XCTAssertTrue(vm.isDirty)
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").count, 1)
        _ = vm.updateMoney(.variable, text: "5.")
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-09"))
        XCTAssertEqual(vm.plan.referenceMode, .manual)
        XCTAssertEqual(vm.plan.planningFX?.inrPerQAR, 4)
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        XCTAssertEqual(vm.rawText["variable"], "5.")
        XCTAssertFalse(vm.canSave)
    }

    func testFinalINREstimateRoundingAndNoHiddenInvestmentSubtraction() throws {
        XCTAssertEqual(try AlDarReturnedINRDecimal(rawToken: "1.005").receiveEstimate(forQAR: money("1")), try money("1.01", "INR"))
        XCTAssertEqual(try AlDarReturnedINRDecimal(rawToken: "1.0049").receiveEstimate(forQAR: money("1")), try money("1.00", "INR"))
        var plan = try inputPlan(); let before = FundingPlanCalculator.calculate(plan)
        plan.plannedInvestment = try money("999")
        XCTAssertEqual(FundingPlanCalculator.calculate(plan).finalQARBuffer, before.finalQARBuffer)
        XCTAssertNil(FundingPlanCalculator.calculate(plan).availableForInvestment)
    }

    func testBillDateCarriesSameDayAndShorterMonthsUseTheirLastDay() throws {
        for (sourceMonth, nextMonth, day, expected) in [("2026-09", "2026-10", 30, "2026-10-30"), ("2027-01", "2027-02", 31, "2027-02-28")] {
            let (vm, active, store) = try editor(month: sourceMonth)
            let id = try bill(vm, region: "qatar", amount: "120")
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Qatar")!
            let date = try XCTUnwrap(calendar.date(from: DateComponents(year: vm.month.year, month: vm.month.month, day: day, hour: 12)))
            vm.setBillDate(region: "qatar", id: id, date: date, timeZone: calendar.timeZone)
            vm.save(); XCTAssertEqual(vm.saveState, .saved)
            XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").first?.commitments.first?.dueDateISO, String(format: "%@-%02d", sourceMonth, day))
            let next = try editor(month: nextMonth, active: active, store: store).0
            XCTAssertEqual(next.plan.qatarCommitments.first?.dueDate(in: next.month)?.canonical, expected)
        }
    }

    func testOctoberFirstCanBeSelectedInSeptemberAndRecursWithoutInventingPayment() throws {
        let (vm, active, store) = try editor()
        let id = try bill(vm, region: "india", amount: "120")
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Qatar")!
        let chosen = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12)))
        vm.setBillDate(region: "india", id: id, date: chosen, timeZone: calendar.timeZone)
        XCTAssertEqual(vm.plan.indiaCommitments.first?.dueDate(in: vm.month)?.canonical, "2026-10-01")
        XCTAssertTrue(vm.plan.indiaCommitments.first?.included == true)
        XCTAssertEqual(vm.calculation.indiaCommitments, try money("120", "INR"))
        vm.save(); XCTAssertEqual(vm.saveState, .saved)
        let october = try editor(month: "2026-10", active: active, store: store).0
        XCTAssertEqual(october.plan.indiaCommitments.first?.dueDate(in: october.month)?.canonical, "2026-10-01")
        october.save()
        let november = try editor(month: "2026-11", active: active, store: store).0
        XCTAssertEqual(november.plan.indiaCommitments.first?.dueDate(in: november.month)?.canonical, "2026-11-01")
        var lastDay = try XCTUnwrap(november.plan.indiaCommitments.first)
        lastDay.dueDate = try StatementDate(canonical: "2026-01-31")
        XCTAssertEqual(lastDay.dueDate(in: try SelectedStatementMonth(canonical: "2026-02"))?.canonical, "2026-02-28")
        XCTAssertEqual(lastDay.dueDate(in: try SelectedStatementMonth(canonical: "2028-02"))?.canonical, "2028-02-29")
        XCTAssertEqual(lastDay.dueDate(in: try SelectedStatementMonth(canonical: "2026-04"))?.canonical, "2026-04-30")
        XCTAssertEqual(lastDay.dueDate(in: try SelectedStatementMonth(canonical: "2026-03"))?.canonical, "2026-03-31")
    }

    func testBackgroundCalendarChangeUpdatesMonthChoicesWithoutReplacingDraft() async throws {
        let memory = InMemoryRepositoryProvider()
        let active = DatabaseProvider(workspaceRepo: memory.workspaceRepo, transactionRepo: memory.transactionRepo,
            accountRepo: memory.accountRepo, importSessionRepo: memory.importSessionRepo, fundingPlanRepo: memory.fundingPlanRepo)
        let store = FundingPlanStore(); store.installWithoutObservation([], generation: active.generationToken)
        var instant = ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z")!
        let vm = SalaryWorkspaceViewModel(provider: { active }, accountStore: AccountStore(), salaryStore: SalaryStore(),
            fundingPlanStore: store, locale: Locale(identifier: "en_US_POSIX"), now: { instant }, refresh: { _ in })
        vm.plannerOpened(); _ = vm.updateMoney(.fixed, text: "100.")
        let draft = vm.plan
        instant = ISO8601DateFormatter().date(from: "2026-10-20T12:00:00Z")!
        await Task.detached { NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil) }.value
        for _ in 0..<100 where vm.currentPlanningMonth.canonical != "2026-10" { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(vm.currentPlanningMonth.canonical, "2026-10")
        XCTAssertEqual(vm.nextPlanningMonth.canonical, "2026-11")
        XCTAssertEqual(vm.plan, draft); XCTAssertEqual(vm.month.canonical, "2026-09")
        XCTAssertEqual(vm.rawText["fixed"], "100."); XCTAssertTrue(vm.hasUnsavedDrafts)
    }

    func testPlannerSaveReopenParityAndLegacyVersionRemainDistinct() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s95-plan-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("plan.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path)
        let (vm, _, _) = try editor(active: .verifiedSQLite(sqlite))
        _ = vm.updateMoney(.fixed, text: "100"); _ = vm.updateMoney(.reserve, text: "20")
        let billID = try bill(vm, region: "india", amount: "30")
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Qatar")!
        vm.setBillDate(region: "india", id: billID, date: calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12)), timeZone: calendar.timeZone)
        vm.addDeduction(); let id = try XCTUnwrap(vm.plan.deductions.first?.id)
        vm.editDeduction(id: id, label: "My deduction", amount: "5"); vm.save()
        XCTAssertEqual(vm.saveState, .saved)
        let saved = try XCTUnwrap(sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace").first)
        let memory = InMemoryRepositoryProvider(); _ = try memory.fundingPlanRepo.savePlan(saved)
        XCTAssertEqual(try memory.fundingPlanRepo.plans(workspaceId: "default-workspace"), [saved])
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing); defer { reopened.database.close() }
        XCTAssertEqual(try reopened.fundingPlanRepo.plans(workspaceId: "default-workspace"), [saved])
        XCTAssertEqual(saved.calculationVersion, "budgetV1"); XCTAssertEqual(saved.keepInCBQDecimal, "20.00")
        XCTAssertEqual(saved.deductions.first?.amountDecimal, "5.00")
        XCTAssertEqual(saved.commitments.first?.dueDateISO, "2026-09-20")
    }
}
