import Foundation
import Testing
@testable import LedgerForge

/// User-authored planning input only. No statement, source fact, or captured balance is manufactured.
@MainActor
struct PlannerEditorTests {
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test func financialMCPQualifiesCurrentInputResultsWhileNativeTotalsCanBeHeld() throws {
        let setup = try editor(), vm = setup.vm
        #expect(vm.updateMoney(.fixed, text: "5000.55"))
        vm.flushPendingEntries()
        let saves = setup.spy.saves, retentions = setup.spy.scratchpadSaves
        #expect(vm.updateMoney(.fixed, text: "5000.75"))
        let valid = try FinancialMCPPresentation.editor(vm)
        let calculation = try #require(valid["calculation"] as? [String: Any])
        let values = try #require(calculation["values"] as? [[String: Any]])
        #expect(values.first { $0["label"] as? String == "Expected net pay" }?["amount"] as? String == "5000.75")
        #expect(valid["has_valid_calculation"] as? Bool == true)
        let basis = try #require(valid["calculation_basis"] as? String)
        #expect(basis.contains("Current validated editor inputs"))
        #expect(basis.contains("not that held display snapshot"))
        #expect((valid["status_basis"] as? String)?.contains("Editor retention and validation") == true)

        #expect(!vm.updateMoney(.fixed, text: "5000."))
        let incomplete = try FinancialMCPPresentation.editor(vm)
        #expect(incomplete["has_valid_calculation"] as? Bool == false)
        #expect((incomplete["raw_input"] as? [String: String])?["fixed"] == "5000.")
        #expect((incomplete["calculation"] as? [String: Any])?["state"] as? String == "unavailable")
        #expect((incomplete["inr_buffer_estimate"] as? [String: Any])?["amount"] is NSNull)
        #expect(incomplete["calculation_basis"] as? String == basis)
        #expect(setup.spy.saves == saves && setup.spy.scratchpadSaves == retentions,
                "Reading the editor does not save its valid or incomplete input.")
    }

    @Test func clearedAmountsRemainEditableAndBecomeZeroOnlyWhenFocusEnds() throws {
        let setup = try editor(), vm = setup.vm
        let month = vm.month
        #expect(vm.updateMoney(.fee, text: "25.50"))
        vm.flushPendingEntries()
        let saved = setup.spy.saves
        #expect(!vm.updateMoney(.fee, text: ""))
        vm.flushPendingEntries()
        #expect(vm.moneyText(.fee).isEmpty)
        #expect(vm.canEdit && setup.spy.saves == saved)
        vm.finishEditingAmount("fee", in: month)
        #expect(vm.moneyText(.fee) == "0")
        #expect(setup.spy.saves == saved, "Focus completion uses the existing save lifecycle.")
        vm.flushPendingEntries()
        #expect(vm.saveState == .saved && vm.plan.configuredTransferFee.amount == 0)

        #expect(!vm.updateMoney(.fee, text: "12."))
        vm.finishEditingAmount("fee", in: month)
        vm.flushPendingEntries()
        #expect(vm.moneyText(.fee) == "12.", "Focus changes must not coerce a partial decimal.")
        #expect(vm.canEdit)
        #expect(vm.updateMoney(.fee, text: "12.75"))
        vm.flushPendingEntries()
        #expect(try vm.plan.configuredTransferFee.canonicalDecimalString() == "12.75")
        #expect(vm.saveState == .saved)
    }

    @Test func focusCompletionCoversBillAndDeductionAmountsWithoutChangingRatesOrOtherMonths() throws {
        let setup = try editor(), vm = setup.vm
        let september = vm.month
        vm.addDeduction()
        let deduction = try #require(vm.plan.deductions.first)
        vm.editDeduction(id: deduction.id, label: "Owner planning entry", amount: "")
        vm.finishEditingAmount("deduction.amount.\(deduction.id)", in: september)
        #expect(vm.rawText["deduction.amount.\(deduction.id)"] == "0")
        vm.addCommitment(region: "india")
        let bill = try #require(vm.plan.indiaCommitments.first)
        vm.editCommitment(region: "india", id: bill.id, field: "label", text: "Owner planning bill")
        vm.editCommitment(region: "india", id: bill.id, field: "amount", text: "")
        vm.finishEditingAmount("amount.\(bill.id)", in: september)
        #expect(vm.rawText["amount.\(bill.id)"] == "0")
        #expect(vm.plan.indiaCommitments.first?.money.currency.code == "INR")
        vm.setFX(rateText: "", dateText: "")
        vm.finishEditingAmount("fx.rate", in: september)
        #expect(vm.rawText["fx.rate"] == "")
        #expect(!vm.updateMoney(.fee, text: ""))
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        #expect(!vm.updateMoney(.fee, text: ""))
        vm.finishEditingAmount("fee", in: september)
        #expect(vm.moneyText(.fee).isEmpty, "A delayed old-month focus callback cannot edit the newly selected plan.")
        vm.switchMonth(to: september)
        #expect(vm.moneyText(.fee).isEmpty, "Month browsing preserves an unfinished retained draft.")
    }

    @Test func monthShortcutsCrossYearBoundariesAndRespectRetainedDraftFailures() throws {
        let setup = try editor(), vm = setup.vm
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-12"))
        #expect(vm.planningMonth(offsetBy: 1)?.canonical == "2027-01")
        #expect(vm.planningMonth(offsetBy: 2)?.canonical == "2027-02")
        #expect(!vm.updateMoney(.fee, text: "15."))
        setup.spy.rejectRetention = true
        vm.switchMonth(to: try #require(vm.planningMonth(offsetBy: 1)))
        #expect(vm.month.canonical == "2026-12" && vm.moneyText(.fee) == "15.")
        setup.spy.rejectRetention = false
        vm.switchMonth(to: try #require(vm.planningMonth(offsetBy: 2)))
        #expect(vm.month.canonical == "2027-02")
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-12"))
        #expect(vm.moneyText(.fee) == "15.")
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2099-12"))
        #expect(vm.planningMonth(offsetBy: 1)?.canonical == "2100-01")
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "9999-12"))
        #expect(vm.planningMonth(offsetBy: 1) == nil)
        #expect(vm.plan.recurringEnd.canonical == "9999-12-31")
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "1900-01"))
        #expect(vm.planningMonth(offsetBy: -1) == nil)
        #expect(vm.plan.recurringStart.canonical == "1900-01-01")
    }

    @Test func monthNavigationDoesNotCreatePlansOrModifySavedEntries() async throws {
        let setup = try editor(), vm = setup.vm
        let originalMonth = vm.month
        #expect(vm.updateMoney(.fee, text: "25.50"))
        vm.flushPendingEntries()
        let saved = vm.plan, raw = vm.rawText
        let saves = setup.spy.saves, retentions = setup.spy.scratchpadSaves
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        for _ in 0..<5 { vm.switchMonth(to: try #require(vm.planningMonth(offsetBy: 1))) }
        #expect(vm.month.canonical == "2027-03")
        vm.switchMonth(to: try #require(vm.planningMonth(offsetBy: -1)))
        #expect(vm.month.canonical == "2027-02")
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2027-12"))
        for section in ["Plan insights", "Salary History", "This Month"] {
            vm.destinationSection = section
            vm.plannerOpened()
            #expect(vm.month.canonical == "2027-12")
        }
        vm.switchMonth(to: vm.currentPlanningMonth)
        #expect(vm.month == vm.currentPlanningMonth)
        vm.switchMonth(to: originalMonth)
        vm.flushPendingEntries()
        try await Task.sleep(for: .milliseconds(900))
        #expect(vm.plan == saved && vm.rawText == raw)
        #expect(setup.spy.saves == saves && setup.spy.scratchpadSaves == retentions,
                "Browsing has no canonical or scratchpad writes; actual pending edits use the existing retention path.")
    }

    @Test(arguments: [false, true], [false, true])
    func restoredDraftBrowsingPreservesSavedAndRetainedState(hasCanonical: Bool, incomplete: Bool) async throws {
        let setup = try editor()
        var canonical = setup.vm.plan
        canonical.expectedFixedEarnings = try Money(canonicalDecimal: "4000.00", currency: "QAR")
        var draft = canonical
        draft.expectedFixedEarnings = try Money(canonicalDecimal: "5000.50", currency: "QAR")
        var raw = setup.vm.rawText
        raw["fixed"] = incomplete ? "5000." : "5000.50"
        let retained = MonthlyPlanScratchpad(plan: draft, canonical: hasCanonical ? canonical : nil,
            rawText: raw, fieldErrors: incomplete ? ["fixed": "Complete the amount"] : [:],
            untouchedZeroFields: [], unavailableBalanceAccountIDs: [], preReductionBasis: [:],
            excludedRecurringOccurrenceIDs: [])
        if hasCanonical { _ = try setup.spy.base.savePlan(canonical.persistenceDTO()) }
        let retainedBaseline = try setup.spy.base.planningWriteSnapshot(
            workspaceID: draft.workspaceID, month: draft.month.canonical).monthRevision
        _ = try setup.spy.base.saveScratchpad(retained.dto(), expected: retainedBaseline)
        setup.store.installWithoutObservation(hasCanonical ? [canonical] : [],
            generation: setup.holder.active.generationToken, scratchpads: [retained])
        let savedBefore = try setup.spy.plans(workspaceId: draft.workspaceID)
        let retainedBefore = try setup.spy.scratchpads(workspaceId: draft.workspaceID)

        func reopen() -> SalaryWorkspaceViewModel {
            SalaryWorkspaceViewModel(month: draft.month, provider: { setup.holder.active },
                accountStore: AccountStore(), salaryStore: SalaryStore(), fundingPlanStore: setup.store,
                locale: locale, refresh: { active in
                    let hydrator = RepositoryStoreHydrator(accountRepo: active.accountRepo,
                        importSessionRepo: active.importSessionRepo, transactionRepo: active.transactionRepo,
                        fundingPlanRepo: active.fundingPlanRepo, accountStore: AccountStore(),
                        transactionStore: TransactionStore(), categoryStore: CategoryStore(), cardStore: CardStore(),
                        salaryStore: SalaryStore(), fundingPlanStore: setup.store, importSessionStore: ImportSessionStore(),
                        importAttemptStore: ImportAttemptStore(), providerGeneration: active.generationToken,
                        participatesInLifecycleGate: false)
                    _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
                })
        }

        var vm = reopen()
        for _ in 0..<2 {
            vm.plannerOpened()
            vm.receiveSharedReference(try AlDarUnitReference(currency: .inr, rawToken: "3", fetchedAtISO: "2026-09-16T08:00:00Z"))
            for _ in 0..<2 {
                for section in ["Plan insights", "Salary History", "This Month"] {
                    vm.destinationSection = section
                    vm.plannerOpened()
                    vm.flushPendingEntries()
                }
                vm.switchMonth(to: try SelectedStatementMonth(canonical: "2027-03"))
                vm.switchMonth(to: draft.month)
                setup.store.notifyInstalledValue()
            }
            try await Task.sleep(for: .milliseconds(900))
            #expect(SalaryWorkspaceViewModel.prepareForCompanionReceive(provider: setup.holder.active),
                "An observed public quote does not turn fully retained entries into an unsaved companion conflict.")
            try #require(setup.spy.saves == 0 && setup.spy.scratchpadSaves == 0,
                "Restoration, navigation, unchanged hydration and live FX are not fresh edits.")
            #expect(try setup.spy.plans(workspaceId: draft.workspaceID) == savedBefore)
            #expect(try setup.spy.scratchpads(workspaceId: draft.workspaceID) == retainedBefore)
            #expect(vm.plan.id == draft.id && vm.plan.expectedFixedEarnings == draft.expectedFixedEarnings)
            #expect(vm.rawText == raw && vm.fieldErrors == retained.fieldErrors)
            #expect(vm.isDirty, "The retained draft still differs from canonical authority for conflict/recovery purposes.")
            vm = reopen()
        }

        #expect(vm.updateMoney(.fixed, text: "6000.75"))
        for _ in 0..<150 where setup.spy.saves == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(setup.spy.saves == 1 && vm.saveState == .saved)
        let savedAfter = try #require(setup.spy.plans(workspaceId: draft.workspaceID).first)
        #expect(savedAfter.id == draft.id && savedAfter.expectedFixedDecimal == "6000.75")
        let retainedAfter = try MonthlyPlanScratchpad.decode(#require(setup.spy.scratchpads(workspaceId: draft.workspaceID).first))
        #expect(retainedAfter.canonical == vm.plan && retainedAfter.rawText["fixed"] == "6000.75")
    }

    @Test func startupRestoresLastSavedMonthWithoutRememberingMonthBrowsing() throws {
        let suite = "LedgerForge-last-saved-month-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("2026-09", forKey: "LedgerForge.planning.selectedMonth.v1.default-workspace")
        let setup = try editor(selectionDefaults: defaults)
        let october = try SelectedStatementMonth(canonical: "2026-10")
        let november = try SelectedStatementMonth(canonical: "2026-11")
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z"))
        func reopen(workspaceID: String = "default-workspace") -> SalaryWorkspaceViewModel {
            SalaryWorkspaceViewModel(workspaceID: workspaceID, provider: { setup.holder.active },
                accountStore: AccountStore(), salaryStore: SalaryStore(), fundingPlanStore: setup.store,
                selectionDefaults: defaults, locale: locale, now: { instant }, refresh: { _ in })
        }
        #expect(reopen().month == october, "A legacy viewed-month preference is not save history.")
        #expect(setup.vm.updateMoney(.fee, text: "25"))
        setup.vm.flushPendingEntries()
        #expect(setup.vm.saveState == .saved)
        #expect(reopen().month.canonical == "2026-09")
        #expect(reopen(workspaceID: "separate-workspace").month == october)

        setup.vm.switchMonth(to: october)
        setup.vm.flushPendingEntries() // Browsing alone is not an owner edit or a save.
        #expect(reopen().month.canonical == "2026-09")
        #expect(setup.vm.updateMoney(.fee, text: "26"))
        setup.vm.flushPendingEntries()
        #expect(setup.vm.saveState == .saved)
        #expect(reopen().month == october)
        setup.vm.switchMonth(to: november)
        setup.vm.flushPendingEntries()
        #expect(reopen().month == october)
    }

    @Test func invalidRetainedDraftAndFailedSaveDoNotReplaceLastSavedMonth() throws {
        let suite = "LedgerForge-failed-save-month-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "LedgerForge.planning.lastSavedMonth.v1.default-workspace"
        let setup = try editor(selectionDefaults: defaults)
        #expect(setup.vm.updateMoney(.fee, text: "25"))
        setup.vm.flushPendingEntries()
        #expect(defaults.string(forKey: key) == "2026-09")
        setup.vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        #expect(!setup.vm.updateMoney(.fee, text: "26."))
        setup.vm.flushPendingEntries()
        #expect(!setup.vm.retentionPending)
        #expect(defaults.string(forKey: key) == "2026-09")
        // Remembering a pending user edit belongs to its month, not the next viewed month.
        setup.vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-11"))
        setup.vm.flushPendingEntries()
        #expect(defaults.string(forKey: key) == "2026-09")
        setup.vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        #expect(setup.vm.moneyText(.fee) == "26.")
        #expect(setup.vm.updateMoney(.fee, text: "26"))
        setup.spy.reject = true
        setup.vm.flushPendingEntries()
        #expect(setup.vm.saveState == .failed)
        #expect(defaults.string(forKey: key) == "2026-09")
    }

    @Test func committedSaveRemembersMonthEvenWhenCanonicalReloadNeedsRecovery() throws {
        let suite = "LedgerForge-committed-month-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let setup = try editor(failRefresh: true, selectionDefaults: defaults)
        #expect(setup.vm.updateMoney(.fee, text: "25"))
        setup.vm.flushPendingEntries()
        #expect(setup.vm.saveState == .committedNeedsRefresh)
        #expect(try setup.spy.plans(workspaceId: "default-workspace").count == 1)
        #expect(defaults.string(forKey: "LedgerForge.planning.lastSavedMonth.v1.default-workspace") == "2026-09")
    }

    @Test func retainedInputSpellingRemembersItsMonthOnlyAfterSuccessfulRetention() throws {
        let suite = "LedgerForge-retained-input-month-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "LedgerForge.planning.lastSavedMonth.v1.default-workspace"
        let setup = try editor(selectionDefaults: defaults)
        #expect(setup.vm.updateMoney(.fee, text: "25"))
        setup.vm.flushPendingEntries()
        setup.vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        #expect(setup.vm.updateMoney(.fee, text: "26"))
        setup.vm.flushPendingEntries()
        setup.vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-09"))
        let saves = setup.spy.saves
        #expect(setup.vm.updateMoney(.fee, text: "25.00"))
        setup.spy.rejectRetention = true
        setup.vm.flushPendingEntries()
        #expect(defaults.string(forKey: key) == "2026-10")
        setup.spy.rejectRetention = false
        setup.vm.flushPendingEntries()
        #expect(setup.vm.saveState == .saved)
        #expect(setup.spy.saves == saves, "Only the retained spelling changed, not the canonical amount.")
        #expect(defaults.string(forKey: key) == "2026-09")
    }

    @Test func dashboardNumberAndWordsUseTheSameCurrencySpecificRounding() throws {
        // Source-independent formatting mechanics; these are not statement facts.
        for code in ["INR", "QAR", "USD"] {
            let money = try Money(canonicalDecimal: "12345678.50", currency: code)
            #expect(MoneyFormatting.number(money, locale: locale) == (code == "INR" ? "1,23,45,679" : "12,345,679"))
            #expect(MoneyFormatting.amountInWords(money) == (code == "INR"
                ? "One crore twenty-three lakh forty-five thousand six hundred seventy-nine"
                : "Twelve million three hundred forty-five thousand six hundred seventy-nine"))
            #expect(try money.canonicalDecimalString() == "12345678.50")
            let small = try Money(canonicalDecimal: "-0.49", currency: code)
            #expect(MoneyFormatting.number(small, locale: locale) == "0")
            #expect(MoneyFormatting.amountInWords(small) == "Zero")
        }
        #expect(PlannerInputCodec.amountInWords("1234567.05", currency: "QAR", locale: locale)
            == "One million two hundred thirty-four thousand five hundred sixty-seven point zero five")
    }

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

    @Test func automaticPublicationRetainsExactInputAndReloadsExactlyOnce() throws {
        let setup = try editor()
        #expect(setup.vm.updateMoney(.fixed, text: "5000.55"))
        setup.vm.addCommitment(region: "india")
        let row = try #require(setup.vm.plan.indiaCommitments.first)
        setup.vm.updateCommitment(region: "india", id: row.id, label: "Manual plan", amountText: "5000.5", included: true, fundingAccountID: nil)
        setup.vm.setFX(rateText: "22.7501", dateText: "2026-09-09")
        setup.vm.flushPendingEntries()
        #expect(setup.spy.saves == 1)
        #expect(setup.vm.saveState == .saved)
        let persisted = try #require(setup.spy.plans(workspaceId: "default-workspace").first)
        #expect(persisted.expectedFixedDecimal == "5000.55")
        #expect(persisted.commitments.first?.amountDecimal == "5000.50")
        #expect(setup.vm.rawText["amount.\(row.id)"] == "5000.5")
        #expect(persisted.fxINRPerQARDecimal == "22.7501")
        #expect(setup.vm.plan == setup.store.plans.first)
    }

    @Test func screenNavigationRetainsPartialInputWithoutPublishingInvalidMoney() throws {
        let setup = try editor()
        #expect(setup.vm.updateMoney(.fixed, text: "5000.55"))
        setup.vm.flushPendingEntries()
        let saved = try setup.spy.plans(workspaceId: "default-workspace")
        let month = setup.vm.month
        #expect(!setup.vm.updateMoney(.fixed, text: "5000."))
        setup.vm.flushPendingEntries()
        #expect(!setup.vm.hasUnsavedDrafts)
        let plan = setup.vm.plan, rawText = setup.vm.rawText, errors = setup.vm.fieldErrors

        for section in ["Plan insights", "Salary History", "This Month"] {
            setup.vm.destinationSection = section
            #expect(setup.vm.month == month)
            #expect(setup.vm.plan == plan)
            #expect(setup.vm.rawText == rawText)
            #expect(setup.vm.fieldErrors == errors)
            #expect(setup.vm.isDirty)
            #expect(!setup.vm.canSave)
            #expect(setup.spy.saves == 1)
            #expect(try setup.spy.plans(workspaceId: "default-workspace") == saved)
        }
        #expect(setup.vm.updateMoney(.fixed, text: "5000.75"))
        #expect(setup.spy.saves == 1)
        setup.vm.flushPendingEntries()
        #expect(setup.spy.saves == 2)
        #expect(setup.vm.saveState == .saved)
        #expect(try setup.spy.plans(workspaceId: "default-workspace").first?.expectedFixedDecimal == "5000.75")
    }

    @Test func debouncePublishesValidInputButRetainsIncompleteTextWithoutAnEditHistory() async throws {
        let setup = try editor()
        #expect(setup.vm.updateMoney(.fixed, text: "5000.5"))
        for _ in 0..<150 where setup.spy.saves == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(setup.spy.saves == 1)
        #expect(setup.vm.moneyText(.fixed) == "5000.5")
        #expect(!setup.vm.updateMoney(.fixed, text: "5000."))
        setup.vm.flushPendingEntries()
        #expect(setup.spy.saves == 1)
        #expect(!setup.vm.hasUnsavedDrafts)
        let retained = try #require(setup.spy.scratchpads(workspaceId: "default-workspace").first)
        let state = try MonthlyPlanScratchpad.decode(retained)
        #expect(state.rawText["fixed"] == "5000.")
        #expect(state.fieldErrors["fixed"] != nil)
        #expect(try setup.spy.scratchpads(workspaceId: "default-workspace").count == 1)
        #expect(try setup.spy.plans(workspaceId: "default-workspace").first?.expectedFixedDecimal == "5000.50")
    }

    @Test func failedRawRetentionKeepsTheAppOpenUntilTheEntriesAreRetained() throws {
        let setup = try editor()
        setup.spy.rejectRetention = true
        #expect(!setup.vm.updateMoney(.fixed, text: "25."))
        #expect(!SalaryWorkspaceViewModel.retainOpenWorkspacesBeforeTermination())
        #expect(setup.vm.hasUnsavedDrafts)
        #expect(setup.vm.saveState == .retentionFailed)
        #expect(setup.vm.moneyText(.fixed) == "25.")
        #expect(setup.spy.saves == 0)
        setup.spy.rejectRetention = false
        setup.vm.flushPendingEntries()
        #expect(!setup.vm.hasUnsavedDrafts)
        let retained = try #require(setup.spy.scratchpads(workspaceId: "default-workspace").first)
        #expect(try MonthlyPlanScratchpad.decode(retained).rawText["fixed"] == "25.")
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

    @Test func unchangedCanonicalPublicationPreservesEveryMonthDraftAndInvalidRawText() throws {
        let setup = try editor()
        let september = setup.vm.month
        let october = try SelectedStatementMonth(canonical: "2026-10")
        _ = setup.vm.updateMoney(.fixed, text: "5000.")
        setup.vm.switchMonth(to: october)
        setup.vm.setFX(rateText: "22.75junk", dateText: "2026-10-")
        let octoberText = setup.vm.rawText, octoberErrors = setup.vm.fieldErrors
        // Helper holdings hydration also publishes the unchanged planning store.
        setup.store.installWithoutObservation(setup.store.plans, generation: setup.store.generation)
        setup.store.notifyInstalledValue()
        #expect(setup.vm.rawText == octoberText)
        #expect(setup.vm.fieldErrors == octoberErrors)
        #expect(setup.vm.isDirty)
        #expect(setup.vm.saveState == .ready)
        setup.vm.switchMonth(to: september)
        #expect(setup.vm.moneyText(.fixed) == "5000.")
        #expect(setup.vm.isDirty)
        #expect(setup.vm.saveState == .ready)
        setup.vm.switchMonth(to: october)
        #expect(setup.vm.rawText == octoberText)
        #expect(setup.vm.fieldErrors == octoberErrors)
        #expect(setup.spy.saves == 0)
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
        setup.vm.flushPendingEntries()
        #expect(!setup.vm.hasUnsavedDrafts)
        let retained = try #require(setup.spy.scratchpads(workspaceId: "default-workspace").first)
        #expect(try MonthlyPlanScratchpad.decode(retained).untouchedZeroFields.contains("fixed") == false)
        #expect(try MonthlyPlanScratchpad.decode(retained).untouchedZeroFields.contains("fee") == false)
        for field in SalaryWorkspaceViewModel.MoneyField.allCases {
            #expect(setup.vm.amountInputText(field.rawValue) == ([.fixed, .fee].contains(field) ? "0" : ""))
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

    @Test func manualFXCalendarSelectionPreservesTheChosenDayThroughAutomaticPublication() throws {
        #expect(SalaryWorkspaceViewModel.monthTitle(try SelectedStatementMonth(canonical: "2026-08")) == "Aug 26")
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
            setup.vm.flushPendingEntries()
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

    @Test func negativeConfiguredFeeIsRetainedWithoutCanonicalPublication() throws {
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
            setup.vm.flushPendingEntries()
            #expect(setup.spy.saves == 0)
            #expect(!setup.vm.hasUnsavedDrafts)
            #expect(setup.vm.moneyText(.fee) == "-25")
            for fee in ["0", "25.5"] {
                #expect(setup.vm.updateMoney(.fee, text: fee))
                #expect(setup.vm.fieldErrors.isEmpty)
                setup.vm.flushPendingEntries()
                #expect(!setup.vm.hasUnsavedDrafts)
                let retained = try #require(setup.spy.scratchpads(workspaceId: "default-workspace").first)
                #expect(try MonthlyPlanScratchpad.decode(retained).rawText["fee"] == fee)
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
            let zeroRevision = try pair.0.planningWriteSnapshot(
                workspaceID: "default-workspace", month: zero.planMonthISO).monthRevision
            #expect(throws: RepositoryError.self) {
                _ = try pair.0.savePlan(negative, expected: zeroRevision, origin: .manual)
            }
            #expect(try pair.0.plans(workspaceId: "default-workspace") == [zero])
            _ = try pair.0.savePlan(positive, expected: zeroRevision, origin: .manual)
            let positiveRevision = try pair.0.planningWriteSnapshot(
                workspaceID: "default-workspace", month: positive.planMonthISO).monthRevision
            #expect(throws: RepositoryError.self) {
                _ = try pair.0.savePlan(negative, expected: positiveRevision, origin: .manual)
            }
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

    private func editor(failRefresh: Bool = false, selectionDefaults: UserDefaults? = nil) throws -> (vm: SalaryWorkspaceViewModel, spy: PlanWriteSpy, store: FundingPlanStore, holder: PlannerProviderHolder) {
        let memory = InMemoryRepositoryProvider()
        _ = try memory.workspaceRepo.upsertWorkspace(WorkspaceDTO(id: "default-workspace", name: "Planner input", createdAtISO: "2026-09-09T00:00:00Z"))
        let spy = PlanWriteSpy(memory.fundingPlanRepo)
        let provider = DatabaseProvider(workspaceRepo: memory.workspaceRepo, transactionRepo: memory.transactionRepo, accountRepo: memory.accountRepo, importSessionRepo: memory.importSessionRepo, fundingPlanRepo: spy)
        let holder = PlannerProviderHolder(provider)
        let store = FundingPlanStore()
        store.installWithoutObservation([], generation: provider.generationToken)
        let vm = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(canonical: "2026-09"), provider: { holder.active }, accountStore: AccountStore(), salaryStore: SalaryStore(), fundingPlanStore: store, selectionDefaults: selectionDefaults, locale: locale, refresh: { active in
            if failRefresh { throw RepositoryStoreHydrationError.invalidFundingPlanState("injected nonfinancial failure") }
            let hydrator = RepositoryStoreHydrator(accountRepo: active.accountRepo, importSessionRepo: active.importSessionRepo, transactionRepo: active.transactionRepo, fundingPlanRepo: active.fundingPlanRepo, accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(), cardStore: CardStore(), salaryStore: SalaryStore(), fundingPlanStore: store, importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(), providerGeneration: active.generationToken, participatesInLifecycleGate: false)
            _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        })
        return (vm, spy, store, holder)
    }
}

private final class PlanWriteSpy: FundingPlanRepository {
    var saves = 0
    var scratchpadSaves = 0
    var reject = false
    var rejectRetention = false
    let base: FundingPlanRepository
    init(_ base: FundingPlanRepository) { self.base = base }
    func plans(workspaceId: String) throws -> [FundingPlanDTO] { try base.plans(workspaceId: workspaceId) }
    func planningMonthRevisions(workspaceID: String) throws -> [PlanningMonthRevision] {
        try base.planningMonthRevisions(workspaceID: workspaceID)
    }
    func planningWriteSnapshot(workspaceID: String, month: String) throws -> PlanningWriteSnapshot {
        try base.planningWriteSnapshot(workspaceID: workspaceID, month: month)
    }
    func savePlan(_ plan: FundingPlanDTO) throws -> FundingPlanDTO { saves += 1; if reject { throw RepositoryError.relationshipViolation("injected failure") }; return try base.savePlan(plan) }
    func savePlan(_ plan: FundingPlanDTO, expected: PlanningMonthRevision,
                  origin: PlanningSaveOrigin) throws -> PlanningMonthRevision {
        saves += 1
        if reject { throw RepositoryError.relationshipViolation("injected failure") }
        return try base.savePlan(plan, expected: expected, origin: origin)
    }
    func scratchpads(workspaceId: String) throws -> [MonthlyPlanScratchpadDTO] { try base.scratchpads(workspaceId: workspaceId) }
    func saveScratchpad(_ value: MonthlyPlanScratchpadDTO) throws {
        scratchpadSaves += 1
        if rejectRetention { throw RepositoryError.persistenceUnavailable }
        try base.saveScratchpad(value)
    }
    func saveScratchpad(_ value: MonthlyPlanScratchpadDTO,
                        expected: PlanningMonthRevision) throws -> PlanningMonthRevision {
        scratchpadSaves += 1
        if rejectRetention { throw RepositoryError.persistenceUnavailable }
        return try base.saveScratchpad(value, expected: expected)
    }
    func removeScratchpad(workspaceId: String, month: String) throws { try base.removeScratchpad(workspaceId: workspaceId, month: month) }
    func removeScratchpad(workspaceId: String, month: String,
                          expected: PlanningMonthRevision) throws -> PlanningMonthRevision {
        try base.removeScratchpad(workspaceId: workspaceId, month: month, expected: expected)
    }
    func savePlan(_ plan: FundingPlanDTO, retaining scratchpad: MonthlyPlanScratchpadDTO) throws -> FundingPlanDTO {
        saves += 1
        if reject { throw RepositoryError.relationshipViolation("injected failure") }
        return try base.savePlan(plan, retaining: scratchpad)
    }
    func savePlan(_ plan: FundingPlanDTO, retaining scratchpad: MonthlyPlanScratchpadDTO,
                  expected: PlanningMonthRevision, origin: PlanningSaveOrigin) throws -> PlanningMonthRevision {
        saves += 1
        if reject { throw RepositoryError.relationshipViolation("injected failure") }
        return try base.savePlan(plan, retaining: scratchpad, expected: expected, origin: origin)
    }
}

@MainActor
private final class PlannerProviderHolder {
    var active: DatabaseProvider
    init(_ active: DatabaseProvider) { self.active = active }
}
