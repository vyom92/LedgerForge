import Foundation
import Testing
@testable import LedgerForge

/// User-authored planning input only. No statement, source fact, or captured balance is manufactured.
@MainActor
struct PlannerEditorTests {
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test func liveAmountWordsUseExactIndianGroupingAndHideUnfinishedInput() {
        let examples = ["7000": "Seven thousand", "250072": "Two lakh fifty thousand seventy-two",
                        "12000000": "One crore twenty lakh", "0": "Zero",
                        "-1250": "Minus one thousand two hundred fifty", "7.05": "Seven point zero five"]
        for (input, expected) in examples {
            #expect(PlannerInputCodec.amountInWords(input, currency: "INR", locale: locale) == expected)
        }
        for invalid in ["", "-", "7.", "7.001", "1e3"] {
            #expect(PlannerInputCodec.amountInWords(invalid, currency: "QAR", locale: locale) == nil)
        }
        #expect(PlannerInputCodec.amountInWords("90071992547409.91", currency: "INR", locale: locale)?.hasSuffix("point nine one") == true)
        #expect(PlannerInputCodec.amountInWords("90071992547409.92", currency: "INR", locale: locale)?.hasSuffix("point nine two") == true)
        #expect(PlannerInputCodec.amountInWords("7,05", currency: "INR", locale: Locale(identifier: "de_DE")) == "Seven point zero five")
    }

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

    @Test func untouchedZeroDefaultsAreBlankAndExplicitZeroRemainsVisible() throws {
        let setup = try editor()
        for field in [SalaryWorkspaceViewModel.MoneyField.fixed, .variable, .deductions, .investment] {
            #expect(setup.vm.amountInputText(field.rawValue) == "")
            #expect(setup.vm.moneyText(field) == "0")
        }
        #expect(setup.vm.amountInputText("fee") == "")
        #expect(!setup.vm.isDirty)
        #expect(setup.vm.updateMoney(.fixed, text: "0"))
        #expect(setup.vm.amountInputText("fixed") == "0")
        #expect(!setup.vm.isDirty)
        #expect(setup.vm.updateMoney(.fee, text: "0"))
        #expect(setup.vm.amountInputText("fee") == "0")
        setup.vm.save()
        #expect(setup.vm.saveState == .saved)
        for field in SalaryWorkspaceViewModel.MoneyField.allCases {
            #expect(setup.vm.amountInputText(field.rawValue) == "0")
        }
    }

    @Test func newCommitmentZerosStayBlankUntilAmountEditingAndSaveExactly() throws {
        let setup = try editor()
        for region in ["qatar", "india"] {
            setup.vm.addCommitment(region: region)
            let row = try #require((region == "qatar" ? setup.vm.plan.qatarCommitments : setup.vm.plan.indiaCommitments).first)
            let key = "amount.\(row.id)"
            #expect(setup.vm.amountInputText(key) == "")
            #expect(setup.vm.rawText[key] == "0")
            setup.vm.editCommitment(region: region, id: row.id, field: "label", text: "My commitment")
            setup.vm.editCommitment(region: region, id: row.id, field: "included", text: "false")
            #expect(setup.vm.amountInputText(key) == "")
            setup.vm.editCommitment(region: region, id: row.id, field: "amount", text: "0")
            #expect(setup.vm.amountInputText(key) == "0")
        }
        setup.vm.save()
        #expect(setup.vm.saveState == .saved)
        let saved = try #require(setup.spy.plans(workspaceId: "default-workspace").first)
        #expect(saved.commitments.count == 2)
        #expect(saved.commitments.allSatisfy { $0.amountDecimal == "0.00" })
        let row = try #require(setup.vm.plan.qatarCommitments.first)
        setup.vm.editCommitment(region: "qatar", id: row.id, field: "amount", text: "")
        #expect(setup.vm.amountInputText("amount.\(row.id)") == "")
        #expect(setup.vm.fieldErrors["amount.\(row.id)"] != nil)
        setup.vm.save()
        #expect(setup.spy.saves == 1)
    }

    @Test func rolledZerosAndEnteredBalanceZerosRemainVisible() throws {
        let setup = try editor()
        setup.vm.save()
        let next = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(canonical: "2026-10"),
            provider: { setup.holder.active }, accountStore: AccountStore(), salaryStore: SalaryStore(),
            fundingPlanStore: setup.store, locale: locale, refresh: { _ in })
        next.rolloverFromPreviousPlan()
        for field in [SalaryWorkspaceViewModel.MoneyField.fixed, .variable, .deductions, .investment] {
            #expect(next.amountInputText(field.rawValue) == "0")
        }
        // An ordinary manually entered balance is separate from an untouched default.
        let account = Account(repositoryAccountId: "manual-bank", institution: "My bank", name: "My balance", type: .bank, currencyCode: "QAR")
        next.setManualBalance(account, text: "0")
        #expect(next.amountInputText("balance.manual-bank") == "0")
    }

    @Test func manualFXCalendarSelectionPreservesTheChosenDayAndSaveBoundary() throws {
        #expect(SalaryWorkspaceViewModel.monthTitle(try SelectedStatementMonth(canonical: "2026-08")) == "Aug 2026")
        for zone in ["Asia/Qatar", "America/Los_Angeles", "Pacific/Kiritimati"] {
            let timeZone = try #require(TimeZone(identifier: zone))
            let setup = try editor()
            setup.vm.setFX(rateText: "25", dateText: "2026-08-31")
            let before = setup.vm.plan
            let selection = setup.vm.manualFXPickerDate(timeZone: timeZone)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let parts = calendar.dateComponents([.year, .month, .day], from: selection)
            #expect(parts.year == 2026 && parts.month == 8 && parts.day == 31)
            #expect(setup.vm.plan == before)
            #expect(setup.spy.saves == 0)
            let chosen = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 12)))
            setup.vm.setManualFXObservationDate(chosen, timeZone: timeZone)
            #expect(setup.vm.rawText["fx.date"] == "2026-09-01")
            #expect(setup.vm.plan.planningFX?.inrPerQAR == 25)
            #expect(setup.spy.saves == 0)
            setup.vm.save()
            #expect(setup.vm.saveState == .saved)
            #expect(setup.vm.plan.planningFX?.observationDate.canonical == "2026-09-01")
        }
    }

    @Test func budgetCapacityRetainsDeficitsAndLegacyInvestmentInterpretationStaysDistinct() throws {
        for deductions in ["0", "10", "20"] {
            let setup = try editor()
            _ = setup.vm.updateMoney(.fixed, text: "10")
            setup.vm.addDeduction()
            let row = try #require(setup.vm.plan.deductions.first)
            setup.vm.editDeduction(id: row.id, label: "My deduction", amount: deductions)
            #expect(!setup.vm.updateMoney(.investment, text: "5"))
            let expectedBefore = Decimal(10) - (try #require(Decimal(string: deductions)))
            #expect(setup.vm.calculation.signedPotentialCapacity?.amount == expectedBefore)
            #expect(setup.vm.calculation.transferablePrincipal?.amount == max(0, expectedBefore))
            #expect(setup.vm.calculation.finalQARBuffer?.amount == expectedBefore)
            #expect(setup.vm.calculation.availableForInvestment == nil)
            var legacy = setup.vm.plan
            legacy.calculationVersion = .legacy
            legacy.expectedDeductions = try Money(amount: Decimal(string: deductions)!, currency: "QAR")
            legacy.plannedInvestment = try Money(amount: 5, currency: "QAR")
            let historical = FundingPlanCalculator.calculate(legacy)
            #expect(historical.qarBeforeInvestment?.amount == expectedBefore)
            #expect(historical.availableForInvestment?.amount == max(0, expectedBefore))
            #expect(historical.finalQARBuffer?.amount == expectedBefore - 5)
        }
        let incomplete = try editor()
        incomplete.vm.addCommitment(region: "india")
        let row = try #require(incomplete.vm.plan.indiaCommitments.first)
        incomplete.vm.editCommitment(region: "india", id: row.id, field: "amount", text: "1")
        #expect(incomplete.vm.calculation.availableForInvestment == nil)
        #expect(incomplete.vm.calculation.finalQARBuffer == nil)
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
