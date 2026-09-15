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
    private func editor(month: String = "2026-09", runtime: DatabaseProvider? = nil, store: FundingPlanStore? = nil,
                        fetch: @escaping @Sendable (Money) async throws -> AlDarReferenceQuote = {
        try AlDarReferenceQuote(submittedQAR: $0, returnedINR: AlDarReturnedINRDecimal(rawToken: "3.0000"), fetchedAtISO: "2026-09-15T08:00:00Z")
    }) throws -> (SalaryWorkspaceViewModel, DatabaseProvider, FundingPlanStore) {
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
            }, fetchAlDar: fetch)
        return (vm, active, plans)
    }
    private func seed(_ vm: SalaryWorkspaceViewModel, shortfall: String = "1.00") throws -> String {
        vm.addCommitment(region: "india")
        let id = try XCTUnwrap(vm.plan.indiaCommitments.first?.id)
        vm.updateCommitment(region: "india", id: id, label: "My planning input", amountText: shortfall, included: true, fundingAccountID: nil)
        vm.setFX(rateText: "1", dateText: "2026-09-15")
        return id
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
    func testRefreshThenApplyThenSaveAreSeparate() async throws {
        let (vm, active, store) = try editor()
        _ = try seed(vm)
        let before = vm.plan, calculation = vm.calculation
        await vm.refreshAlDarReference()
        XCTAssertEqual(vm.plan, before)
        XCTAssertEqual(vm.calculation, calculation)
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
        XCTAssertTrue(vm.canUseAlDarReference)
        vm.useAlDarReference()
        XCTAssertNil(vm.plan.planningFX)
        XCTAssertEqual(vm.rawText["fx.rate"], "")
        XCTAssertEqual(vm.plan.alDarReference?.quote.submittedQAR, try money("1.00"))
        XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("0.34"))
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
        vm.save()
        XCTAssertEqual(vm.saveState, .saved)
        XCTAssertEqual(store.plans.first, vm.plan)
        XCTAssertEqual(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").first?.alDarReference?.returnedINRRawDecimal, "3.0000")
    }
    func testBindingInvalidationAndUnrelatedEdits() async throws {
        let (vm, _, _) = try editor()
        let id = try seed(vm)
        await vm.refreshAlDarReference(); vm.useAlDarReference()
        let reference = vm.plan.alDarReference
        _ = vm.updateMoney(.fee, text: "2.5"); _ = vm.updateMoney(.investment, text: "3")
        vm.addCommitment(region: "qatar")
        XCTAssertEqual(vm.plan.alDarReference, reference)
        vm.updateCommitment(region: "india", id: id, label: "My changed input", amountText: "2", included: true, fundingAccountID: nil)
        XCTAssertNil(vm.plan.alDarReference)
        XCTAssertEqual(vm.previousAlDarContext, reference)
        XCTAssertNil(vm.calculation.requiredQARPrincipal)
        XCTAssertTrue(vm.canRefreshAlDar)
        vm.setFX(rateText: "1", dateText: "2026-09-15")
        XCTAssertTrue(vm.canRefreshAlDar)
        vm.updateCommitment(region: "india", id: id, label: "No transfer", amountText: "0", included: true, fundingAccountID: nil)
        XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("0.00"))
        XCTAssertEqual(vm.calculation.effectiveTransferFee, try money("0.00"))
    }
    func testManualEditRemovesExternalEvenWhenInvalid() async throws {
        let (vm, _, _) = try editor()
        _ = try seed(vm)
        await vm.refreshAlDarReference(); vm.useAlDarReference()
        vm.setFX(rateText: "2junk", dateText: "2026-09-15")
        XCTAssertNil(vm.plan.alDarReference)
        XCTAssertNil(vm.plan.planningFX)
        XCTAssertFalse(vm.canSave)
        vm.setFX(rateText: "2", dateText: "2026-09-15")
        XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("0.50"))
        vm.save()
        XCTAssertEqual(vm.saveState, .saved)
        XCTAssertNil(vm.plan.alDarReference)
    }
    func testPopulatedManualFXRollsOverExactlyUnderV18() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s94-manual-rollover-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("planner.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        defer { sqlite.database.close() }
        let (prior, active, store) = try editor(runtime: .verifiedSQLite(sqlite))
        _ = try seed(prior)
        prior.setFX(rateText: "22.750100", dateText: "2026-09-09")
        _ = prior.updateMoney(.fee, text: "7.35")
        prior.save()
        XCTAssertEqual(prior.saveState, .saved)
        let savedPrior = try XCTUnwrap(store.plans.first)
        let expectedFX = try FundingPlanFX(inrPerQAR: XCTUnwrap(Decimal(string: "22.750100")),
                                          observationDate: StatementDate(year: 2026, month: 9, day: 9))
        XCTAssertEqual(savedPrior.planningFX, expectedFX)
        XCTAssertNil(savedPrior.alDarReference)

        let (next, _, _) = try editor(month: "2026-10", runtime: active, store: store)
        next.rolloverFromPreviousPlan()
        XCTAssertEqual(next.plan.planningFX, expectedFX)
        XCTAssertEqual(next.plan.rolloverSourcePlanID, savedPrior.id)
        XCTAssertEqual(next.plan.configuredTransferFee, savedPrior.configuredTransferFee)
        XCTAssertNil(next.plan.alDarReference)
        XCTAssertNil(next.pendingAlDarReference)
        next.save()
        XCTAssertEqual(next.saveState, .saved)
        let reloaded = try XCTUnwrap(store.plan(for: next.plan.month, workspaceID: "default-workspace"))
        XCTAssertEqual(reloaded.planningFX, expectedFX)
        XCTAssertNil(reloaded.alDarReference)
        XCTAssertEqual(store.plan(for: prior.plan.month, workspaceID: "default-workspace"), savedPrior)
        let savedDTOs = try sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace")
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        XCTAssertEqual(try reopened.fundingPlanRepo.plans(workspaceId: "default-workspace"), savedDTOs)
    }

    func testDashboardFundingReadsOnlyCanonicalCurrentMonthPlan() async throws {
        let (vm, active, store) = try editor()
        let availability = ApplicationAvailability()
        availability.didHydrate(.init(didHydrate: true, accountCount: 0, transactionCount: 0), generation: active.generationToken)
        let dashboard = DashboardViewModel(accountStore: AccountStore(), transactionStore: TransactionStore(),
            cardStore: CardStore(), categoryStore: CategoryStore(), fundingPlanStore: store, availability: availability,
            now: { ISO8601DateFormatter().date(from: "2026-09-15T12:00:00Z")! })
        XCTAssertEqual(dashboard.fundingMonthTitle, "Sep 2026")
        XCTAssertNil(dashboard.fundingCalculation)
        _ = try seed(vm)
        dashboard.refreshPresentation()
        XCTAssertNil(dashboard.fundingCalculation)
        vm.save(); dashboard.refreshPresentation()
        XCTAssertEqual(dashboard.fundingCalculation, vm.calculation)
        let savedManual = dashboard.fundingCalculation
        await vm.refreshAlDarReference(); dashboard.refreshPresentation()
        XCTAssertEqual(dashboard.fundingCalculation, savedManual)
        vm.useAlDarReference(); dashboard.refreshPresentation()
        XCTAssertEqual(dashboard.fundingCalculation, savedManual)
        vm.save(); dashboard.refreshPresentation()
        XCTAssertEqual(dashboard.fundingCalculation, vm.calculation)
        XCTAssertEqual(dashboard.fundingCalculation?.requiredQARPrincipal, try money("0.34"))
        let nextMonth = DashboardViewModel(accountStore: AccountStore(), transactionStore: TransactionStore(),
            cardStore: CardStore(), categoryStore: CategoryStore(), fundingPlanStore: store, availability: availability,
            now: { ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z")! })
        XCTAssertEqual(nextMonth.fundingMonthTitle, "Oct 2026")
        XCTAssertNil(nextMonth.fundingCalculation)
        availability.didHydrate(.init(didHydrate: true, accountCount: 0, transactionCount: 0), generation: ProviderGenerationToken())
        dashboard.refreshPresentation()
        XCTAssertEqual(dashboard.fundingState, .unavailable)
        XCTAssertNil(dashboard.fundingCalculation)
    }

    func testRolloverDoesNotApplyExternalAndRefreshUsesUnitAmount() async throws {
        let (prior, active, store) = try editor()
        _ = try seed(prior)
        await prior.refreshAlDarReference(); prior.useAlDarReference(); prior.save()
        let (next, _, _) = try editor(month: "2026-10", runtime: active, store: store)
        next.rolloverFromPreviousPlan()
        XCTAssertNil(next.plan.alDarReference)
        XCTAssertNil(next.plan.planningFX)
        XCTAssertNil(next.calculation.requiredQARPrincipal)
        XCTAssertTrue(next.canRefreshAlDar)
        XCTAssertNil(next.pendingAlDarReference)
        await next.refreshAlDarReference()
        XCTAssertNil(next.plan.alDarReference)
        XCTAssertEqual(next.pendingAlDarReference?.submittedQAR, try money("1.00"))
    }
    func testUnitLookupWithoutShortfallOrManualRateLeavesPlanUnchanged() async throws {
        let (vm, active, _) = try editor()
        let before = vm.plan, calculation = vm.calculation, rawText = vm.rawText
        XCTAssertNil(vm.plan.planningFX)
        XCTAssertTrue(vm.canRefreshAlDar)
        await vm.refreshAlDarReference()
        XCTAssertEqual(vm.pendingAlDarReference?.submittedQAR, try money("1.00"))
        XCTAssertEqual(vm.pendingAlDarReference?.returnedINR.rawToken, "3.0000")
        XCTAssertEqual(vm.plan, before)
        XCTAssertEqual(vm.calculation, calculation)
        XCTAssertEqual(vm.rawText, rawText)
        XCTAssertFalse(vm.isDirty)
        XCTAssertFalse(vm.canUseAlDarReference)
        vm.useAlDarReference()
        XCTAssertEqual(vm.plan, before)
        XCTAssertNotNil(vm.pendingAlDarReference)
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
    }
    func testUnitLookupWithMissingBalanceAndInvalidFieldsLeavesDraftUnchanged() async throws {
        let (vm, active, _) = try editor()
        // Ordinary account metadata and an unfilled manual balance, not source evidence.
        let account = Account(repositoryAccountId: "manual-bank", institution: "My bank", name: "My balance", type: .bank, currencyCode: "INR")
        vm.setAccountIncluded(account, included: true)
        vm.setFX(rateText: "unfinished", dateText: "")
        XCTAssertNil(vm.calculation.indiaFundingShortfall)
        XCTAssertFalse(vm.fieldErrors.isEmpty)
        let before = vm.plan, rawText = vm.rawText, errors = vm.fieldErrors
        XCTAssertTrue(vm.canRefreshAlDar)
        await vm.refreshAlDarReference()
        XCTAssertEqual(vm.pendingAlDarReference?.submittedQAR, try money("1.00"))
        XCTAssertFalse(vm.canUseAlDarReference)
        XCTAssertEqual(vm.plan, before)
        XCTAssertEqual(vm.rawText, rawText)
        XCTAssertEqual(vm.fieldErrors, errors)
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
    }
    func testUnitLookupRejectsAResponseForAnotherAmount() async throws {
        let (vm, active, _) = try editor(fetch: { _ in
            try AlDarReferenceQuote(submittedQAR: Money(canonicalDecimal: "2.00", currency: "QAR"),
                returnedINR: AlDarReturnedINRDecimal(rawToken: "3.0000"), fetchedAtISO: "2026-09-15T08:00:00Z")
        })
        let before = vm.plan, calculation = vm.calculation, rawText = vm.rawText
        await vm.refreshAlDarReference()
        XCTAssertNil(vm.pendingAlDarReference)
        XCTAssertEqual(vm.plan, before)
        XCTAssertEqual(vm.calculation, calculation)
        XCTAssertEqual(vm.rawText, rawText)
        XCTAssertFalse(vm.isRefreshingAlDar)
        XCTAssertTrue(vm.alDarMessage?.contains("unusable reference") == true)
        XCTAssertTrue(try active.fundingPlanRepo.plans(workspaceId: "default-workspace").isEmpty)
    }
    func testUnitLookupIgnoresManualRateAndBindsOnlyWhenApplied() async throws {
        let (vm, _, store) = try editor()
        _ = try seed(vm, shortfall: "900.00")
        vm.setFX(rateText: "25", dateText: "2026-09-15")
        XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("36.00"))
        let before = vm.plan
        await vm.refreshAlDarReference()
        XCTAssertEqual(vm.pendingAlDarReference?.submittedQAR, try money("1.00"))
        XCTAssertEqual(vm.plan, before)
        vm.useAlDarReference()
        XCTAssertEqual(vm.plan.alDarReference?.boundShortfallINR, try money("900.00", "INR"))
        XCTAssertEqual(vm.calculation.requiredQARPrincipal, try money("300.00"))
        XCTAssertNil(vm.plan.planningFX)
        vm.save()
        XCTAssertEqual(vm.saveState, .saved)
        XCTAssertEqual(store.plans.first?.alDarReference, vm.plan.alDarReference)
        XCTAssertEqual(store.plans.first?.alDarReference?.quote.submittedQAR, try money("1.00"))
    }
    func testLateUnitReplyRemainsUnboundUntilExplicitUseOfCurrentShortfall() async throws {
        let delayed = DeferredAlDarResponse()
        let (vm, _, _) = try editor(fetch: { try await delayed.fetch($0) })
        let task = Task { await vm.refreshAlDarReference() }
        while !(await delayed.isWaiting) { await Task.yield() }
        vm.addCommitment(region: "india")
        let id = try XCTUnwrap(vm.plan.indiaCommitments.first?.id)
        vm.editCommitment(region: "india", id: id, field: "amount", text: "2")
        let before = vm.plan
        try await delayed.complete(); await task.value
        XCTAssertEqual(vm.plan, before)
        XCTAssertEqual(vm.pendingAlDarReference?.submittedQAR, try money("1.00"))
        XCTAssertNil(vm.plan.alDarReference)
        vm.editCommitment(region: "india", id: id, field: "amount", text: "3")
        XCTAssertNotNil(vm.pendingAlDarReference)
        vm.useAlDarReference()
        XCTAssertEqual(vm.plan.alDarReference?.boundShortfallINR, try money("3.00", "INR"))
        XCTAssertNil(vm.pendingAlDarReference)
    }
    func testFetchFailureDoesNotChangePlan() async throws {
        let (vm, _, _) = try editor(fetch: { _ in throw AlDarReferenceError.unavailable })
        _ = try seed(vm)
        let before = vm.plan, result = vm.calculation
        await vm.refreshAlDarReference()
        XCTAssertEqual(vm.plan, before); XCTAssertEqual(vm.calculation, result)
        XCTAssertNil(vm.pendingAlDarReference); XCTAssertFalse(vm.isRefreshingAlDar)
    }
    func testLateUnitReplyCannotCrossGeneration() async throws {
        let delayed = DeferredAlDarResponse()
        let (vm, _, store) = try editor(fetch: { try await delayed.fetch($0) })
        let task = Task { await vm.refreshAlDarReference() }
        while !(await delayed.isWaiting) { await Task.yield() }
        store.installWithoutObservation([], generation: ProviderGenerationToken()); store.notifyInstalledValue()
        try await delayed.complete(); await task.value
        XCTAssertNil(vm.pendingAlDarReference)
        XCTAssertNil(vm.plan.alDarReference)
    }
    func testRepeatedRefreshKeepsOneCancellableRequestOwner() async throws {
        let delayed = DeferredAlDarResponse()
        let (vm, _, _) = try editor(fetch: { try await delayed.fetch($0) })
        vm.startAlDarRefresh(); vm.startAlDarRefresh()
        while !(await delayed.isWaiting) { await Task.yield() }
        vm.cancelAlDarRefresh()
        try await delayed.complete()
        while !(await delayed.finished) { await Task.yield() }
        let count = await delayed.requests, cancelled = await delayed.observedCancellation
        XCTAssertEqual(count, 1); XCTAssertTrue(cancelled)
        XCTAssertNil(vm.pendingAlDarReference); XCTAssertFalse(vm.isRefreshingAlDar)
    }

    func testV18ProductBackupAndVerificationRetainAppliedEvidence() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s94-reference-backup-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let current = folder.appendingPathComponent("planner.sqlite")
        let sqlite = try SQLiteRepositoryProvider(path: current.path, migrations: allMigrations)
        defer { sqlite.database.close() }
        let runtime = DatabaseProvider.verifiedSQLite(sqlite)
        let (vm, _, _) = try editor(runtime: runtime)
        _ = try seed(vm)
        await vm.refreshAlDarReference(); vm.useAlDarReference(); vm.save()
        XCTAssertEqual(vm.saveState, .saved)
        let expected = try sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace")
        let originalProvider = DatabaseProvider.shared
        DatabaseProvider.shared = runtime
        defer { DatabaseProvider.shared = originalProvider }
        let coordinator = BackupRestoreCoordinator(testingAt: current)
        coordinator.installTestProvider(sqlite)
        let destination = folder.appendingPathComponent("backups")
        try BackupFiles.createDirectory(destination)
        await coordinator.createBackup(to: destination)
        let package = try XCTUnwrap(coordinator.lastBackupURL)
        XCTAssertEqual(try BackupFiles.verifyPackage(package).schemaVersion, 18)
        let backup = try SQLiteRepositoryProvider(path: package.appendingPathComponent("ledger.sqlite").path,
                                                  migrations: allMigrations, access: .readOnlySnapshot)
        XCTAssertEqual(try backup.fundingPlanRepo.plans(workspaceId: "default-workspace"), expected)
        try backup.database.closeChecked()
        await coordinator.verifyRestore(from: package)
        XCTAssertEqual(coordinator.candidateManifest?.schemaVersion, 18)
        await coordinator.discardCandidate()
        XCTAssertEqual(try sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace"), expected)
    }

    func testSQLiteEvidenceRoundTripAndExclusivity() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s94-planner-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("planner.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        defer { sqlite.database.close() }
        let runtime = DatabaseProvider.verifiedSQLite(sqlite)
        let (vm, _, _) = try editor(runtime: runtime)
        _ = try seed(vm)
        vm.save(); XCTAssertEqual(vm.saveState, .saved)
        var manual = try XCTUnwrap(sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace").first)
        await vm.refreshAlDarReference(); vm.useAlDarReference(); vm.save()
        let external = try XCTUnwrap(sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace").first)
        manual.alDarReference = external.alDarReference
        XCTAssertThrowsError(try sqlite.fundingPlanRepo.savePlan(manual))
        XCTAssertEqual(try sqlite.fundingPlanRepo.plans(workspaceId: "default-workspace"), [external])
        XCTAssertThrowsError(try sqlite.database.executePrepared(sql: "UPDATE funding_plans SET fx_inr_per_qar_decimal='1', fx_observation_date='2026-09-15', fx_provenance='user_entered' WHERE id=?;", params: [external.id]))
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        XCTAssertEqual(try reopened.fundingPlanRepo.plans(workspaceId: "default-workspace"), [external])
        manual.alDarReference = nil
        _ = try reopened.fundingPlanRepo.savePlan(manual)
        XCTAssertNil(try reopened.fundingPlanRepo.plans(workspaceId: "default-workspace").first?.alDarReference)
        _ = try reopened.fundingPlanRepo.savePlan(external)
        try reopened.database.executePrepared(sql: "UPDATE funding_plan_commitments SET amount_minor=200, amount_decimal='2.00' WHERE funding_plan_id=? AND region='india';", params: [external.id])
        let hydration = RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(reopened), participatesInLifecycleGate: false)
        XCTAssertThrowsError(try hydration.stageHydration())
    }
}

private actor DeferredAlDarResponse {
    private var continuation: CheckedContinuation<AlDarReferenceQuote, any Error>?
    private var amount: Money?
    private(set) var requests = 0
    private(set) var observedCancellation = false
    private(set) var finished = false
    var isWaiting: Bool { continuation != nil }
    func fetch(_ amount: Money) async throws -> AlDarReferenceQuote {
        self.amount = amount
        requests += 1
        let value = try await withCheckedThrowingContinuation { continuation = $0 }
        observedCancellation = Task.isCancelled; finished = true
        return value
    }
    func complete() throws {
        let quote = try AlDarReferenceQuote(submittedQAR: amount!, returnedINR: AlDarReturnedINRDecimal(rawToken: "3.0000"), fetchedAtISO: "2026-09-15T08:00:00Z")
        continuation?.resume(returning: quote); continuation = nil
    }
}
