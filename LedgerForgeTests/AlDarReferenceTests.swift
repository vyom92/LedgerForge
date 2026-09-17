import Foundation
import XCTest
@testable import LedgerForge

/// Ordinary user-entered planning numbers and source-independent transport
/// mechanics only. No statement, imported row or captured balance is created.
@MainActor
final class AlDarReferenceTests: XCTestCase {
    private func money(_ value: String, _ currency: String = "QAR") throws -> Money {
        try Money(canonicalDecimal: value, currency: currency)
    }
    private func quote(_ amount: Money, raw: String = "3.0000") throws -> AlDarReferenceQuote {
        try AlDarReferenceQuote(submittedQAR: amount, returnedINR: AlDarReturnedINRDecimal(rawToken: raw), fetchedAtISO: "2026-09-15T08:00:00Z")
    }
    private func editor(month: String = "2026-09", runtime: DatabaseProvider? = nil, store: FundingPlanStore? = nil) throws -> (SalaryWorkspaceViewModel, DatabaseProvider, FundingPlanStore) {
        let memory = InMemoryRepositoryProvider()
        let active = runtime ?? DatabaseProvider(workspaceRepo: memory.workspaceRepo, transactionRepo: memory.transactionRepo,
            accountRepo: memory.accountRepo, importSessionRepo: memory.importSessionRepo, fundingPlanRepo: memory.fundingPlanRepo)
        let plans = store ?? FundingPlanStore()
        if store == nil { plans.installWithoutObservation([], generation: active.generationToken) }
        let vm = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(canonical: month), provider: { active },
            accountStore: AccountStore(), salaryStore: SalaryStore(), fundingPlanStore: plans, locale: Locale(identifier: "en_US_POSIX"),
            refresh: { current in
                _ = try RepositoryStoreHydrator(accountRepo: current.accountRepo, importSessionRepo: current.importSessionRepo,
                    transactionRepo: current.transactionRepo, fundingPlanRepo: current.fundingPlanRepo,
                    accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(),
                    cardStore: CardStore(), salaryStore: SalaryStore(), fundingPlanStore: plans,
                    importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
                    providerGeneration: current.generationToken, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            })
        vm.plannerOpened()
        return (vm, active, plans)
    }
    private func seed(_ vm: SalaryWorkspaceViewModel, shortfall: String = "1.00") throws -> String {
        vm.addCommitment(region: "india")
        let id = try XCTUnwrap(vm.plan.indiaCommitments.first?.id)
        vm.updateCommitment(region: "india", id: id, label: "My planning input", amountText: shortfall, included: true, fundingAccountID: nil)
        return id
    }
    private func publish(_ vm: SalaryWorkspaceViewModel, raw: String = "3.0000") throws {
        vm.receiveSharedReference(try AlDarUnitReference(currency: .inr, rawToken: raw, fetchedAtISO: "2026-09-15T08:00:00Z"))
    }
    func testRawTokenIsExactAndNarrow() throws {
        XCTAssertEqual(try AlDarReturnedINRDecimal.parseResponse(Data(" \n1.006000\r\t".utf8)).rawToken, "1.006000")
        for invalid in ["0", "0.000", "-1", "+1", "01", "1.", ".1", "1e2", "NaN", "Infinity", "\"1.0\"", "null", "<html>", "1 2", "1\u{00a0}", String(repeating: "1", count: 33), "0." + String(repeating: "0", count: 28) + "1"] {
            XCTAssertThrowsError(try AlDarReturnedINRDecimal.parseResponse(Data(invalid.utf8)))
        }
        XCTAssertNoThrow(try AlDarReturnedINRDecimal(rawToken: String(repeating: "9", count: 32)))
        XCTAssertNoThrow(try AlDarReturnedINRDecimal(rawToken: "0." + String(repeating: "0", count: 27) + "1"))
        XCTAssertThrowsError(try AlDarReturnedINRDecimal.parseResponse(Data(repeating: 32, count: 129)))
    }
    func testUnitRateDisplayUsesTwoDecimalsWithoutChangingExactRatio() throws {
        for (raw, displayed) in [
            ("26.25419600", "26.25"), ("26", "26.00"), ("26.2", "26.20"),
            ("26.255", "26.26"), ("26.999999", "27.00"), ("0.004", "0.00")
        ] {
            let reference = try quote(money("1.00"), raw: raw)
            let before = reference
            XCTAssertEqual(reference.displayRate, displayed)
            XCTAssertEqual(reference, before)
            XCTAssertEqual(reference.returnedINR.rawToken, raw)
        }

        let reference = try quote(money("1.00"), raw: "26.25419600")
        let shortfall = try money("2625.00", "INR")
        let exactPrincipal = try reference.principal(for: shortfall)
        XCTAssertEqual(reference.displayRate, "26.25")
        XCTAssertEqual(try reference.principal(for: shortfall), exactPrincipal)
        XCTAssertEqual(exactPrincipal, try money("99.99"))
        // Feeding the displayed rate back into calculation would change Money.
        let roundedReference = try quote(money("1.00"), raw: reference.displayRate)
        XCTAssertEqual(try roundedReference.principal(for: shortfall), try money("100.00"))
        XCTAssertNotEqual(try roundedReference.principal(for: shortfall), exactPrincipal)
    }
    func testExactRatioCeilingAndOverflow() throws {
        XCTAssertEqual(try quote(money("1.00")).principal(for: money("1.00", "INR")), try money("0.34"))
        XCTAssertEqual(try quote(money("1.00"), raw: "1.0000").principal(for: money("1.00", "INR")), try money("1.00"))
        XCTAssertEqual(try quote(money("1.00"), raw: "1.006000").principal(for: money("1.01", "INR")), try money("1.01"))
        let maximumQAR = try Money.fromMinorUnits(Int64.max, currency: "QAR")
        let maximumINR = try Money.fromMinorUnits(Int64.max, currency: "INR")
        XCTAssertThrowsError(try quote(maximumQAR, raw: "0.0000000000000000000000000001").principal(for: maximumINR))
        XCTAssertThrowsError(try quote(maximumQAR, raw: "1").principal(for: maximumINR))
        XCTAssertThrowsError(try quote(money("0.00")))
        XCTAssertThrowsError(try quote(money("1.00")).principal(for: money("-1.00", "INR")))
    }

    func testSharedReferenceUpdatesDraftAutomaticallyAndSaveRemainsSeparate() throws {
        let (vm, active, _) = try editor(); _ = try seed(vm)
        try publish(vm)
        XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("0.34"))
        XCTAssertNotNil(vm.plan.effectiveAlDarReference)
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
        vm.save(); XCTAssertEqual(vm.saveState, .saved)
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").first?.effectiveReference?.rawINR, "3.0000")
    }

    func testShortfallChangesReuseTheSameExactUnitReference() throws {
        let (vm, _, _) = try editor(); let id = try seed(vm); try publish(vm)
        let evidence = vm.plan.effectiveAlDarReference
        vm.editCommitment(region: "india", id: id, field: "amount", text: "2.00")
        XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("0.67"))
        XCTAssertEqual(vm.plan.effectiveAlDarReference, evidence)
        _ = vm.updateMoney(.fixed, text: "100")
        XCTAssertEqual(vm.plan.effectiveAlDarReference, evidence)
    }

    func testManualEditRemovesExternalEvenWhenInvalid() throws {
        let (vm, active, _) = try editor(); _ = try seed(vm); try publish(vm)
        vm.setFX(rateText: "2.", dateText: "2026-09-15")
        XCTAssertNil(vm.plan.effectiveAlDarReference); XCTAssertNil(vm.plan.planningFX)
        XCTAssertEqual(vm.plan.referenceMode, .manual); XCTAssertFalse(vm.hasValidCalculation)
        vm.save(); XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
        try publish(vm, raw: "4.00")
        XCTAssertEqual(vm.rawText["fx.rate"], "2."); XCTAssertNil(vm.plan.effectiveAlDarReference)
    }

    func testManualOverrideReopensSameMonthAndDoesNotSeedNextMonth() throws {
        let (vm, active, store) = try editor(); _ = try seed(vm)
        vm.setFX(rateText: "22.750123", dateText: "2026-09-15"); vm.save()
        XCTAssertEqual(vm.saveState, .saved)
        let same = try editor(runtime: active, store: store).0
        XCTAssertEqual(same.plan.referenceMode, .manual)
        XCTAssertEqual(same.plan.planningFX?.inrPerQAR, Decimal(string: "22.750123"))
        let next = try editor(month: "2026-10", runtime: active, store: store).0
        XCTAssertEqual(next.plan.referenceMode, .alDar)
        XCTAssertNil(next.plan.planningFX); XCTAssertNil(next.plan.effectiveAlDarReference)
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").count, 1)
    }

    func testDashboardFundingReadsOnlyCanonicalCurrentMonthPlan() throws {
        let (vm, active, store) = try editor(); _ = try seed(vm); try publish(vm)
        XCTAssertNil(store.plan(for: vm.month))
        vm.save(); let saved = try XCTUnwrap(store.plan(for: vm.month))
        let before = FundingPlanCalculator.calculate(saved)
        try publish(vm, raw: "6.00")
        XCTAssertEqual(FundingPlanCalculator.calculate(try XCTUnwrap(store.plan(for: vm.month))), before)
        XCTAssertNotEqual(vm.calculation.requiredQARPrincipal, before.requiredQARPrincipal)
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").first?.effectiveReference?.rawINR, "3.0000")
    }

    func testRolloverDoesNotInheritAppliedExternalEvidence() throws {
        let (vm, active, store) = try editor(); _ = try seed(vm); try publish(vm); vm.save()
        let next = try editor(month: "2026-10", runtime: active, store: store).0
        XCTAssertEqual(next.plan.referenceMode, .alDar); XCTAssertNil(next.plan.effectiveAlDarReference)
        try publish(next, raw: "4.00")
        XCTAssertEqual(next.calculation.requiredQARPrincipal, try money("0.25"))
        XCTAssertEqual(store.plans.count, 1)
    }

    func testReferenceWithoutShortfallUpdatesDraftWithoutFinancialWrite() throws {
        let (vm, active, _) = try editor(); try publish(vm)
        XCTAssertEqual(vm.plan.effectiveAlDarReference?.submittedQAR, try money("1.00"))
        XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("0.00"))
        XCTAssertEqual(vm.calculation.estimatedINR, try money("0.00", "INR"))
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
    }

    func testSharedUpdateCannotReplaceInvalidVisibleInput() throws {
        let (vm, active, _) = try editor(); _ = try seed(vm)
        _ = vm.updateMoney(.fixed, text: "100."); let before = vm.plan
        try publish(vm)
        XCTAssertEqual(vm.plan, before); XCTAssertEqual(vm.rawText["fixed"], "100.")
        XCTAssertFalse(vm.canSave)
        _ = vm.updateMoney(.fixed, text: "100")
        XCTAssertNotNil(vm.plan.effectiveAlDarReference)
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
    }

    func testUSDLegCannotBecomePlannerINREvidence() throws {
        let leg = try AlDarUnitReference(currency: .usd, rawToken: "0.273972602739726027397260274", fetchedAtISO: "2026-09-15T08:00:00Z")
        XCTAssertThrowsError(try leg.planningQuote())
        let (vm, _, _) = try editor(); _ = try seed(vm); vm.receiveSharedReference(leg)
        XCTAssertNil(vm.plan.effectiveAlDarReference); XCTAssertNil(vm.calculation.requiredQARPrincipal)
    }

    func testManualOverrideSurvivesSharedRefreshUntilUseAlDar() throws {
        let (vm, _, _) = try editor(); _ = try seed(vm)
        vm.setFX(rateText: "2", dateText: "2026-09-15"); let before = vm.plan
        try publish(vm, raw: "4")
        XCTAssertEqual(vm.plan, before); XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("0.50"))
        vm.useSharedAlDar()
        XCTAssertNil(vm.plan.planningFX); XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("0.25"))
    }

    func testLateSharedReplyDoesNotRewriteInactiveOrManualMonth() throws {
        let (vm, _, _) = try editor(); _ = try seed(vm); try publish(vm)
        let september = vm.plan
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        vm.setFX(rateText: "2", dateText: "2026-09-15"); let october = vm.plan
        try publish(vm, raw: "4")
        XCTAssertEqual(vm.plan, october)
        vm.switchMonth(to: september.month)
        XCTAssertEqual(vm.plan.indiaCommitments, september.indiaCommitments)
        XCTAssertEqual(vm.plan.effectiveAlDarReference?.returnedINR.rawToken, "4")
    }

    func testMissingSharedReferenceLeavesSavedPlanUntouched() throws {
        let (vm, active, _) = try editor(); _ = try seed(vm); try publish(vm); vm.save()
        let saved = try active.fundingPlanRepo.plans(workspaceId: "default-workspace")
        vm.receiveSharedReference(nil)
        XCTAssertNil(vm.calculation.requiredQARPrincipal)
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace"), saved)
    }

    func testUnopenedPlannerHydrationDoesNotCreateAnInvisibleReferenceDraft() throws {
        let (vm, active, savedStore) = try editor(); _ = try seed(vm); try publish(vm); vm.save()
        let store = FundingPlanStore(); store.installWithoutObservation([], generation: active.generationToken)
        let unopened = SalaryWorkspaceViewModel(month: vm.month, provider: { active }, accountStore: AccountStore(),
            salaryStore: SalaryStore(), fundingPlanStore: store, refresh: { _ in })
        store.installWithoutObservation(savedStore.plans, generation: active.generationToken); store.notifyInstalledValue()
        XCTAssertEqual(unopened.plan.effectiveAlDarReference, vm.plan.effectiveAlDarReference)
        XCTAssertFalse(unopened.hasUnsavedDrafts)
    }

    func testLateUnitReplyCannotCrossGeneration() throws {
        let (vm, _, store) = try editor(); _ = try seed(vm); let before = vm.plan
        store.installWithoutObservation([], generation: ProviderGenerationToken()); store.notifyInstalledValue()
        try publish(vm)
        XCTAssertEqual(vm.plan, before); XCTAssertFalse(vm.canSave)
    }

    func testAllMonthDraftsParticipateInUnsavedWorkGuard() throws {
        let (vm, _, _) = try editor(); _ = vm.updateMoney(.fixed, text: "100.")
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        XCTAssertTrue(vm.hasUnsavedDrafts)
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-09"))
        XCTAssertEqual(vm.rawText["fixed"], "100."); XCTAssertFalse(vm.canSave)
    }

    func testCurrentProductBackupAndVerificationRetainEffectiveEvidence() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s95-reference-backup-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let current = folder.appendingPathComponent("planner.sqlite")
        let sqlite = try SQLiteRepositoryProvider(path: current.path, migrations: allMigrations)
        defer { sqlite.database.close() }
        let runtime = DatabaseProvider.verifiedSQLite(sqlite)
        let (vm, _, _) = try editor(runtime: runtime); _ = try seed(vm); try publish(vm); vm.save()
        XCTAssertEqual(vm.saveState, .saved)
        let expected = try sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace")
        let originalProvider = DatabaseProvider.shared; DatabaseProvider.shared = runtime
        defer { DatabaseProvider.shared = originalProvider }
        let coordinator = BackupRestoreCoordinator(testingAt: current); coordinator.installTestProvider(sqlite)
        let destination = folder.appendingPathComponent("backups"); try BackupFiles.createDirectory(destination)
        await coordinator.createBackup(to: destination)
        let package = try XCTUnwrap(coordinator.lastBackupURL)
        XCTAssertEqual(try BackupFiles.verifyPackage(package).schemaVersion, 22)
        let backup = try SQLiteRepositoryProvider(path: package.appendingPathComponent("ledger.sqlite").path, migrations: allMigrations, access: .readOnlySnapshot)
        XCTAssertEqual(try backup.fundingPlanRepo.plans(workspaceId: "default-workspace"), expected)
        try backup.database.closeChecked()
        await coordinator.verifyRestore(from: package)
        XCTAssertEqual(coordinator.candidateManifest?.schemaVersion, 22)
        await coordinator.discardCandidate()
        XCTAssertEqual(try sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace"), expected)
    }

    func testSQLiteEvidenceRoundTripExclusivityAndLegacyBinding() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s95-planner-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("planner.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        defer { sqlite.database.close() }
        let runtime = DatabaseProvider.verifiedSQLite(sqlite)
        let (vm, _, _) = try editor(runtime: runtime); _ = try seed(vm); try publish(vm); vm.save()
        let external = try XCTUnwrap(sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace").first)
        XCTAssertThrowsError(try sqlite.database.executePrepared(sql: "UPDATE funding_plans SET fx_inr_per_qar_decimal='1', fx_observation_date='2026-09-15', fx_provenance='user_entered' WHERE id=?;", params: [external.id]))
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        XCTAssertEqual(try reopened.fundingPlanRepo.plans(workspaceId: "default-workspace"), [external])
        var legacy = external
        legacy.calculationVersion = "legacy"; legacy.keepInCBQMinor = nil; legacy.keepInCBQDecimal = nil
        legacy.referenceMode = nil; legacy.effectiveReference = nil
        legacy.alDarReference = try FundingPlanAlDarReferenceDTO(planID: legacy.id, evidence: AlDarReferenceEvidence(quote: quote(money("1.00")), boundShortfallINR: money("1.00", "INR")))
        _ = try reopened.fundingPlanRepo.savePlan(legacy)
        XCTAssertThrowsError(try reopened.database.executePrepared(sql: "UPDATE funding_plans SET fx_inr_per_qar_decimal='1', fx_observation_date='2026-09-15', fx_provenance='user_entered' WHERE id=?;", params: [legacy.id]))
        try reopened.database.executePrepared(sql: "UPDATE funding_plan_commitments SET amount_minor=200, amount_decimal='2.00' WHERE funding_plan_id=? AND region='india';", params: [legacy.id])
        XCTAssertThrowsError(try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(reopened), participatesInLifecycleGate: false).stageHydration())
    }
}
