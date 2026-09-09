import Foundation
import Testing
@testable import LedgerForge

/// User-authored planning input only. No statement, source fact, or captured balance is manufactured.
@MainActor
struct PlannerEditorTests {
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test func exactEditingSpellingsAndLocales() throws {
        for currency in ["QAR", "INR"] {
            for (input, expected) in [("5000", "5000.00"), ("5000.5", "5000.50"), ("5000.55", "5000.55"), ("-5.5", "-5.50")] {
                #expect(try PlannerInputCodec.money(input, currency: currency, locale: locale).canonicalDecimalString() == expected)
            }
        }
        #expect(try PlannerInputCodec.money("5000,5", currency: "INR", locale: Locale(identifier: "de_DE")).canonicalDecimalString() == "5000.50")
        for invalid in ["", "-", "5.", "5,000", "5,000.50", "5.555", "1e3", "5junk", " 5", "5\n", "99999999999999999999999999"] {
            #expect(throws: Error.self) { try PlannerInputCodec.money(invalid, currency: "QAR", locale: locale) }
        }
        for invalid in ["0", "-1", "22junk", "2e2", "22.4.1", "99999999999999999999999999999999999"] {
            #expect(throws: Error.self) { try PlannerInputCodec.rate(invalid, locale: locale) }
        }
    }

    @Test func invalidVisibleMoneyAndFXCannotPersistOldValues() throws {
        let setup = try editor()
        #expect(setup.vm.updateMoney(.fixed, text: "5000.5"))
        #expect(!setup.vm.updateMoney(.fixed, text: "5000.555"))
        setup.vm.save()
        #expect(setup.spy.saves == 0)
        #expect(setup.vm.moneyText(.fixed) == "5000.555")
        #expect(setup.vm.updateMoney(.fixed, text: "5000.55"))
        setup.vm.setFX(rateText: "22.75", dateText: "2026-09-09")
        setup.vm.setFX(rateText: "22.75junk", dateText: "2026-09-09")
        setup.vm.save()
        #expect(setup.spy.saves == 0)
        #expect(setup.vm.rawText["fx.rate"] == "22.75junk")
    }

    @Test func focusedEquivalentDraftSavesAllRowsAndReloadsExactlyOnce() throws {
        let setup = try editor()
        #expect(setup.vm.updateMoney(.fixed, text: "5000.55"))
        setup.vm.addCommitment(region: "india")
        let row = try #require(setup.vm.plan.indiaCommitments.first)
        setup.vm.updateCommitment(region: "india", id: row.id, label: "Manual plan", amountText: "5000.5", included: true, fundingAccountID: nil)
        setup.vm.setFX(rateText: "22.7501", dateText: "2026-09-09")
        setup.vm.save()
        #expect(setup.spy.saves == 1)
        #expect(setup.vm.saveState == .saved)
        let persisted = try #require(setup.spy.plans(workspaceId: "default-workspace").first)
        #expect(persisted.expectedFixedDecimal == "5000.55")
        #expect(persisted.commitments.first?.amountDecimal == "5000.50")
        #expect(persisted.fxINRPerQARDecimal == "22.7501")
        #expect(setup.vm.plan == setup.store.plans.first)
    }

    @Test func commitThenRefreshFailureNeverReplaysWrite() throws {
        let setup = try editor(failRefresh: true)
        _ = setup.vm.updateMoney(.fixed, text: "5000")
        setup.vm.save()
        #expect(setup.spy.saves == 1)
        #expect(setup.vm.saveState == .committedNeedsRefresh)
        setup.vm.save()
        setup.vm.retryCanonicalRefresh()
        setup.vm.retryCanonicalRefresh()
        #expect(setup.spy.saves == 1)
        #expect(setup.vm.saveState == .committedNeedsRefresh)
        #expect(try setup.spy.plans(workspaceId: "default-workspace").first?.expectedFixedDecimal == "5000.00")
    }

    @Test func dirtyDraftSurvivesCanonicalConflict() throws {
        let setup = try editor()
        var published = setup.vm.plan
        published.expectedFixedEarnings = try Money(canonicalDecimal: "4.00", currency: "QAR")
        _ = setup.vm.updateMoney(.fixed, text: "5000.")
        setup.store.installWithoutObservation([published], generation: setup.store.generation); setup.store.notifyInstalledValue()
        #expect(setup.vm.moneyText(.fixed) == "5000.")
        #expect(setup.vm.saveState == .canonicalChanged)
        setup.vm.save()
        #expect(setup.spy.saves == 0)
        setup.vm.discardAndReload()
        #expect(try setup.vm.plan.expectedFixedEarnings.canonicalDecimalString() == "0.00")
        #expect(!setup.vm.isDirty)
    }

    @Test func includedMissingBalanceAndAbsentFXRemainIncomplete() throws {
        let setup = try editor()
        setup.vm.addCommitment(region: "india")
        let row = try #require(setup.vm.plan.indiaCommitments.first)
        setup.vm.updateCommitment(region: "india", id: row.id, label: "Manual plan", amountText: "5000", included: true, fundingAccountID: nil)
        #expect(setup.vm.calculation.requiredQARPrincipal == nil)
        #expect(setup.vm.calculation.incompleteReasons.contains(.missingPlanningFX))
        #expect(setup.vm.canSave)
    }

    @Test func wrongGenerationCannotBeAdoptedAtInitializationOrDiscard() throws {
        let setup = try editor()
        _ = setup.vm.updateMoney(.fixed, text: "5000.5")
        let older = setup.vm.plan
        setup.store.installWithoutObservation([older], generation: ProviderGenerationToken())
        let fresh = SalaryWorkspaceViewModel(month: older.month, provider: { setup.holder.active }, accountStore: AccountStore(), salaryStore: SalaryStore(), fundingPlanStore: setup.store, locale: locale, refresh: { _ in })
        #expect(fresh.saveState == .providerChanged)
        #expect(fresh.plan.id != older.id)
        #expect(!fresh.canSave)
        fresh.discardAndReload()
        #expect(fresh.saveState == .providerChanged)
        #expect(fresh.plan.id != older.id)
        fresh.save()
        #expect(setup.spy.saves == 0)
    }

    @Test func delayedWrongGenerationPublicationBlocksPristineEditor() throws {
        let setup = try editor()
        let id = setup.vm.plan.id
        setup.store.installWithoutObservation([], generation: ProviderGenerationToken())
        setup.store.notifyInstalledValue()
        #expect(setup.vm.saveState == .providerChanged)
        #expect(setup.vm.plan.id == id)
        #expect(!setup.vm.canSave)
    }

    @Test func providerSwitchAfterCommitReportsPriorWriteWithoutReplay() throws {
        let setup = try editor(failRefresh: true)
        _ = setup.vm.updateMoney(.fixed, text: "5000")
        setup.vm.save()
        setup.holder.active = .intentionalNonDurable(.testMemory)
        setup.vm.retryCanonicalRefresh()
        #expect(setup.vm.saveState == .committedToPreviousProvider)
        setup.vm.save()
        #expect(setup.spy.saves == 1)
    }

    @Test func compactTextUndoAndFieldSpecificRowsStayCoherent() throws {
        let setup = try editor()
        #expect(setup.vm.moneyText(.fixed) == "0")
        #expect(!setup.vm.isDirty)
        _ = setup.vm.updateMoney(.fixed, text: "5000")
        _ = setup.vm.updateMoney(.fixed, text: "0")
        #expect(!setup.vm.isDirty)
        setup.vm.addCommitment(region: "qatar")
        let row = try #require(setup.vm.plan.qatarCommitments.first)
        setup.vm.editCommitment(region: "qatar", id: row.id, field: "included", text: "false")
        setup.vm.editCommitment(region: "qatar", id: row.id, field: "amount", text: "5000.5")
        setup.vm.editCommitment(region: "qatar", id: row.id, field: "label", text: String(repeating: "a", count: 240))
        #expect(setup.vm.plan.qatarCommitments.first?.included == false)
        #expect(try setup.vm.plan.qatarCommitments.first?.money.canonicalDecimalString() == "5000.50")
        #expect(setup.vm.fieldErrors.isEmpty)
        setup.vm.editCommitment(region: "qatar", id: row.id, field: "label", text: String(repeating: "a", count: 241))
        #expect(!setup.vm.canSave)
        #expect(throws: Error.self) { try PlannerInputCodec.money("5000.5", currency: "QAR", locale: Locale(identifier: "de_DE")) }
    }

    @Test func unknownWriteFailureRetainsDraftAndBlocksBlindRetry() throws {
        let setup = try editor()
        setup.spy.reject = true
        _ = setup.vm.updateMoney(.fixed, text: "5000.55")
        setup.vm.save()
        #expect(setup.vm.saveState == .failed)
        #expect(!setup.vm.canSave)
        #expect(setup.vm.moneyText(.fixed) == "5000.55")
        setup.vm.save()
        #expect(setup.spy.saves == 1)
        #expect(try setup.spy.plans(workspaceId: "default-workspace").isEmpty)
    }

    @Test func firstPlanCreatesWorkspaceAtomicallyWithProviderParityAndReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-first-plan-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("planner.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path)
        let memory = InMemoryRepositoryProvider()
        let input = try editor()
        _ = input.vm.updateMoney(.fixed, text: "5000.55")
        input.vm.save()
        let candidate = try #require(input.spy.plans(workspaceId: "default-workspace").first)
        // A valid DTO with an invalid relationship fails after SQLite's proposed
        // workspace insert. Rollback must leave both tables empty.
        let invalid = FundingPlanDTO(
            id: candidate.id,
            workspaceId: candidate.workspaceId,
            planMonthISO: candidate.planMonthISO,
            rolloverSourcePlanId: "absent-source",
            expectedFixedMinor: candidate.expectedFixedMinor,
            expectedFixedDecimal: candidate.expectedFixedDecimal,
            expectedFixedProvenance: candidate.expectedFixedProvenance,
            expectedVariableMinor: candidate.expectedVariableMinor,
            expectedVariableDecimal: candidate.expectedVariableDecimal,
            expectedVariableProvenance: candidate.expectedVariableProvenance,
            expectedDeductionsMinor: candidate.expectedDeductionsMinor,
            expectedDeductionsDecimal: candidate.expectedDeductionsDecimal,
            expectedDeductionsProvenance: candidate.expectedDeductionsProvenance,
            configuredFeeMinor: candidate.configuredFeeMinor,
            configuredFeeDecimal: candidate.configuredFeeDecimal,
            configuredFeeProvenance: candidate.configuredFeeProvenance,
            fxINRPerQARDecimal: candidate.fxINRPerQARDecimal,
            fxObservationDateISO: candidate.fxObservationDateISO,
            plannedInvestmentMinor: candidate.plannedInvestmentMinor,
            plannedInvestmentDecimal: candidate.plannedInvestmentDecimal,
            plannedInvestmentProvenance: candidate.plannedInvestmentProvenance,
            updatedAtISO: candidate.updatedAtISO,
            balances: candidate.balances,
            commitments: candidate.commitments
        )
        for pair in [(sqlite.fundingPlanRepo, sqlite.workspaceRepo), (memory.fundingPlanRepo, memory.workspaceRepo)] {
            #expect(try pair.1.workspace(id: "default-workspace") == nil)
            #expect(throws: Error.self) { try pair.0.savePlan(invalid) }
            #expect(try pair.1.workspace(id: "default-workspace") == nil)
            #expect(try pair.0.plans(workspaceId: "default-workspace").isEmpty)
            #expect(try pair.0.savePlan(candidate) == candidate)
            #expect(try pair.1.workspace(id: "default-workspace") != nil)
        }
        #expect(try sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace") == memory.fundingPlanRepo.plans(workspaceId: "default-workspace"))
        sqlite.database.close()
        let reopened = try SQLiteRepositoryProvider(path: path)
        defer { reopened.database.close() }
        #expect(try reopened.fundingPlanRepo.plans(workspaceId: "default-workspace") == [candidate])
    }

    @Test func negativeConfiguredFeeRejectsFocusedSaveWithAndWithoutTransfer() throws {
        for needsTransfer in [false, true] {
            let setup = try editor()
            if needsTransfer {
                setup.vm.addCommitment(region: "india")
                let row = try #require(setup.vm.plan.indiaCommitments.first)
                setup.vm.updateCommitment(region: "india", id: row.id, label: "Manual requirement", amountText: "100", included: true, fundingAccountID: nil)
                setup.vm.setFX(rateText: "2", dateText: "2026-09-09")
            }
            #expect(!setup.vm.updateMoney(.fee, text: "-25"))
            #expect(setup.vm.moneyText(.fee) == "-25")
            #expect(setup.vm.fieldErrors["fee"] == "Transfer fee must be zero or greater")
            #expect(!setup.vm.canSave)
            setup.vm.save() // The shared Save/Command-S action with the field still focused.
            #expect(setup.spy.saves == 0)
            #expect(setup.vm.moneyText(.fee) == "-25")
            for fee in ["0", "25.5"] {
                #expect(setup.vm.updateMoney(.fee, text: fee))
                #expect(setup.vm.fieldErrors.isEmpty)
                setup.vm.save()
                #expect(setup.vm.saveState == .saved)
                #expect(setup.vm.plan.configuredTransferFee.amount == Decimal(string: fee))
                if !needsTransfer { #expect(setup.vm.calculation.effectiveTransferFee?.amount == 0) }
            }
            if needsTransfer { #expect(setup.vm.calculation.finalQARBuffer?.amount == -75.5) }
        }
    }

    @Test(arguments: [false, true])
    func negativeFeeDirectWritesLeaveNoResidueAndValidFeesReopen(_ needsTransfer: Bool) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-fee-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("manual-planner.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path)
        defer { sqlite.database.close() }
        let memory = InMemoryRepositoryProvider()
        let input = try editor()
        if needsTransfer {
            input.vm.addCommitment(region: "india")
            let row = try #require(input.vm.plan.indiaCommitments.first)
            input.vm.updateCommitment(region: "india", id: row.id, label: "Manual requirement", amountText: "100", included: true, fundingAccountID: nil)
            input.vm.setFX(rateText: "2", dateText: "2026-09-09")
        }
        input.vm.save()
        let candidate = try #require(input.spy.plans(workspaceId: "default-workspace").first)
        let negative = replacingFee(candidate, minor: -2500, decimal: "-25.00")
        let zero = replacingFee(candidate, minor: 0, decimal: "0.00")
        let positive = replacingFee(candidate, minor: 2550, decimal: "25.50")
        for pair in [(sqlite.fundingPlanRepo, sqlite.workspaceRepo), (memory.fundingPlanRepo, memory.workspaceRepo)] {
            #expect(throws: RepositoryError.self) { try pair.0.savePlan(negative) }
            #expect(try pair.1.workspace(id: "default-workspace") == nil)
            #expect(try pair.0.plans(workspaceId: "default-workspace").isEmpty)
            #expect(try pair.0.savePlan(zero) == zero)
            #expect(throws: RepositoryError.self) { try pair.0.savePlan(negative) }
            #expect(try pair.0.plans(workspaceId: "default-workspace") == [zero])
            #expect(try pair.0.savePlan(positive) == positive)
            #expect(throws: RepositoryError.self) { try pair.0.savePlan(negative) }
            #expect(try pair.0.plans(workspaceId: "default-workspace") == [positive])
        }
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path)
        defer { reopened.database.close() }
        #expect(try reopened.fundingPlanRepo.plans(workspaceId: "default-workspace") == [positive])
        let negativeBalance = FundingPlanBalanceDTO(id: "manual", planId: candidate.id, sourceOrdinal: 1, accountId: "manual-selection", nativeCurrency: "QAR", included: true, amountCurrency: "QAR", amountMinor: -1000, amountDecimal: "-10.00", provenanceCode: "manual", carriedSourcePlanId: nil, capturedAtISO: nil)
        try SalaryPersistenceDTOValidator.validate(plan: replacingFee(candidate, minor: 0, decimal: "0.00", balances: [negativeBalance]))
        var manual = input.vm.plan
        manual.indiaCommitments = []
        manual.configuredTransferFee = try Money(canonicalDecimal: "0.00", currency: "QAR")
        manual.balances = [FundingPlanBalance(id: "manual", accountID: "manual-selection", nativeCurrency: try CurrencyCode("QAR"), included: true, money: try Money(canonicalDecimal: "-10.00", currency: "QAR"), provenance: .manual)]
        #expect(FundingPlanCalculator.calculate(manual).selectedQARLiquidity?.amount == -10)
        #expect(FundingPlanCalculator.calculate(manual).finalQARBuffer?.amount == -10)
    }

    private func replacingFee(_ candidate: FundingPlanDTO, minor: Int64, decimal: String, balances: [FundingPlanBalanceDTO]? = nil) -> FundingPlanDTO {
        return FundingPlanDTO(
            id: candidate.id,
            workspaceId: candidate.workspaceId,
            planMonthISO: candidate.planMonthISO,
            rolloverSourcePlanId: candidate.rolloverSourcePlanId,
            expectedFixedMinor: candidate.expectedFixedMinor,
            expectedFixedDecimal: candidate.expectedFixedDecimal,
            expectedFixedProvenance: candidate.expectedFixedProvenance,
            expectedVariableMinor: candidate.expectedVariableMinor,
            expectedVariableDecimal: candidate.expectedVariableDecimal,
            expectedVariableProvenance: candidate.expectedVariableProvenance,
            expectedDeductionsMinor: candidate.expectedDeductionsMinor,
            expectedDeductionsDecimal: candidate.expectedDeductionsDecimal,
            expectedDeductionsProvenance: candidate.expectedDeductionsProvenance,
            configuredFeeMinor: minor,
            configuredFeeDecimal: decimal,
            configuredFeeProvenance: candidate.configuredFeeProvenance,
            fxINRPerQARDecimal: candidate.fxINRPerQARDecimal,
            fxObservationDateISO: candidate.fxObservationDateISO,
            plannedInvestmentMinor: candidate.plannedInvestmentMinor,
            plannedInvestmentDecimal: candidate.plannedInvestmentDecimal,
            plannedInvestmentProvenance: candidate.plannedInvestmentProvenance,
            updatedAtISO: candidate.updatedAtISO,
            balances: balances ?? candidate.balances,
            commitments: candidate.commitments
        )
    }

    private func editor(failRefresh: Bool = false) throws -> (vm: SalaryWorkspaceViewModel, spy: PlanWriteSpy, store: FundingPlanStore, holder: PlannerProviderHolder) {
        let memory = InMemoryRepositoryProvider()
        _ = try memory.workspaceRepo.upsertWorkspace(WorkspaceDTO(id: "default-workspace", name: "Planner input", createdAtISO: "2026-09-09T00:00:00Z"))
        let spy = PlanWriteSpy(memory.fundingPlanRepo)
        let provider = DatabaseProvider(workspaceRepo: memory.workspaceRepo, transactionRepo: memory.transactionRepo, accountRepo: memory.accountRepo, importSessionRepo: memory.importSessionRepo, fundingPlanRepo: spy)
        let holder = PlannerProviderHolder(provider)
        let store = FundingPlanStore()
        store.installWithoutObservation([], generation: provider.generationToken)
        let vm = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(canonical: "2026-09"), provider: { holder.active }, accountStore: AccountStore(), salaryStore: SalaryStore(), fundingPlanStore: store, locale: locale, refresh: { active in
            if failRefresh { throw RepositoryStoreHydrationError.invalidFundingPlanState("injected nonfinancial failure") }
            let hydrator = RepositoryStoreHydrator(accountRepo: active.accountRepo, importSessionRepo: active.importSessionRepo, transactionRepo: active.transactionRepo, fundingPlanRepo: active.fundingPlanRepo, accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(), cardStore: CardStore(), salaryStore: SalaryStore(), fundingPlanStore: store, importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(), providerGeneration: active.generationToken, participatesInLifecycleGate: false)
            _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        })
        return (vm, spy, store, holder)
    }
}

private final class PlanWriteSpy: FundingPlanRepository {
    var saves = 0
    var reject = false
    let base: FundingPlanRepository
    init(_ base: FundingPlanRepository) { self.base = base }
    func plans(workspaceId: String) throws -> [FundingPlanDTO] { try base.plans(workspaceId: workspaceId) }
    func savePlan(_ plan: FundingPlanDTO) throws -> FundingPlanDTO { saves += 1; if reject { throw RepositoryError.relationshipViolation("injected failure") }; return try base.savePlan(plan) }
}

@MainActor
private final class PlannerProviderHolder {
    var active: DatabaseProvider
    init(_ active: DatabaseProvider) { self.active = active }
}
