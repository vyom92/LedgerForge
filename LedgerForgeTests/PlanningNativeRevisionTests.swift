import Foundation
import XCTest
@testable import LedgerForge

@MainActor
final class PlanningNativeRevisionTests: XCTestCase {
    private func editor(month: String = "2026-10", provider: DatabaseProvider,
                        plans: FundingPlanStore) throws -> SalaryWorkspaceViewModel {
        SalaryWorkspaceViewModel(month: try SelectedStatementMonth(canonical: month),
            provider: { provider }, accountStore: AccountStore(), salaryStore: SalaryStore(),
            fundingPlanStore: plans, locale: Locale(identifier: "en_US_POSIX"),
            refresh: { current in
                _ = try RepositoryStoreHydrator(accountRepo: current.accountRepo,
                    importSessionRepo: current.importSessionRepo, transactionRepo: current.transactionRepo,
                    fundingPlanRepo: current.fundingPlanRepo, accountStore: AccountStore(),
                    transactionStore: TransactionStore(), categoryStore: CategoryStore(),
                    cardStore: CardStore(), salaryStore: SalaryStore(), fundingPlanStore: plans,
                    importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
                    providerGeneration: current.generationToken,
                    participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            })
    }

    func testNativeCanonicalABARejectsOriginalEditorRevision() throws {
        let provider = DatabaseProvider(inMemory: true)
        let plans = FundingPlanStore()
        plans.installWithoutObservation([], generation: provider.generationToken)
        let vm = try editor(provider: provider, plans: plans)
        _ = vm.updateMoney(.fixed, text: "100")
        vm.save()
        XCTAssertEqual(vm.saveState, .saved)

        let original = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: "default-workspace", month: "2026-10").monthRevision
        var changed = vm.plan
        changed.expectedFixedEarnings = try Money(canonicalDecimal: "200.00", currency: "QAR")
        let middle = try provider.fundingPlanRepo.savePlan(changed.persistenceDTO(),
            expected: original, origin: .manual)
        let restored = try provider.fundingPlanRepo.savePlan(vm.plan.persistenceDTO(),
            expected: middle, origin: .manual)
        XCTAssertGreaterThan(restored.counter, original.counter)
        XCTAssertThrowsError(try provider.fundingPlanRepo.savePlan(changed.persistenceDTO(),
            expected: original, origin: .manual))
        XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: "default-workspace", month: "2026-10").monthRevision, restored)
    }

    func testPreDebounceAndCachedIncompleteEntriesBlockOnlyTheirTargetMonth() throws {
        let provider = DatabaseProvider(inMemory: true)
        let plans = FundingPlanStore()
        plans.installWithoutObservation([], generation: provider.generationToken)
        let vm = try editor(provider: provider, plans: plans)
        vm.plannerOpened()
        _ = vm.updateMoney(.fixed, text: "100.")
        let october = try SelectedStatementMonth(canonical: "2026-10")
        let november = try SelectedStatementMonth(canonical: "2026-11")
        XCTAssertNotNil(SalaryWorkspaceViewModel.planningWriteConflict(
            workspaceID: "default-workspace", month: october, provider: provider))
        XCTAssertNil(SalaryWorkspaceViewModel.planningWriteConflict(
            workspaceID: "default-workspace", month: november, provider: provider))
        var entered = false
        XCTAssertThrowsError(try SalaryWorkspaceViewModel.withPlanningWriteReservation(
            workspaceID: "default-workspace", month: october, provider: provider) { entered = true })
        XCTAssertFalse(entered)

        vm.switchMonth(to: november)
        XCTAssertEqual(vm.month, november)
        XCTAssertNotNil(SalaryWorkspaceViewModel.planningWriteConflict(
            workspaceID: "default-workspace", month: october, provider: provider))
        XCTAssertNil(SalaryWorkspaceViewModel.planningWriteConflict(
            workspaceID: "default-workspace", month: november, provider: provider))
    }

    func testDelayedNativeSaveCannotOverwriteLaterRepositoryPublication() throws {
        let provider = DatabaseProvider(inMemory: true)
        let plans = FundingPlanStore()
        plans.installWithoutObservation([], generation: provider.generationToken)
        let first = try editor(provider: provider, plans: plans)
        _ = first.updateMoney(.fixed, text: "100")
        first.save()
        XCTAssertEqual(first.saveState, .saved)
        let stale = try editor(provider: provider, plans: plans)

        let baseline = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: "default-workspace", month: "2026-10").monthRevision
        var external = first.plan
        external.expectedFixedEarnings = try Money(canonicalDecimal: "200.00", currency: "QAR")
        _ = try provider.fundingPlanRepo.savePlan(external.persistenceDTO(),
            expected: baseline, origin: .chatgpt)
        _ = stale.updateMoney(.fixed, text: "300")
        stale.save()
        XCTAssertEqual(stale.saveState, .failed)
        XCTAssertEqual(try provider.fundingPlanRepo.plans(workspaceId: "default-workspace").first?.expectedFixedDecimal,
                       "200.00")
    }

    func testNativeSaveAdvancesItsOwnRetainedRawBaselineBeforeHydration() throws {
        let provider = DatabaseProvider(inMemory: true)
        let plans = FundingPlanStore()
        plans.installWithoutObservation([], generation: provider.generationToken)
        let vm = try editor(provider: provider, plans: plans)
        vm.plannerOpened()
        _ = vm.updateMoney(.fixed, text: "100.")
        vm.flushPendingEntries()
        let retained = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: "default-workspace", month: "2026-10").monthRevision
        XCTAssertGreaterThan(retained.counter, 0)

        _ = vm.updateMoney(.fixed, text: "100")
        vm.save()
        XCTAssertEqual(vm.saveState, .saved)
        XCTAssertGreaterThan(try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: "default-workspace", month: "2026-10").monthRevision.counter, retained.counter)
    }
}
