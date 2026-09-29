import Foundation
import LocalAuthentication
import Security
import XCTest
@testable import LedgerForge

/// Empty schema, operational clocks and claims only. These tests create no
/// statements, financial DTO graphs, prices, rates, holdings or Gmail originals.
@MainActor
final class BackgroundPersistenceTests: XCTestCase {
    private func location() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-background-mechanics-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("mechanics.sqlite")
    }

    func testControlRequestsCoalesceRepeatedAndAdditionalScopes() throws {
        var queue = BackgroundPublicControlQueue()
        XCTAssertEqual(queue.enqueue(scopes: .rates, manual: true), .accepted)
        XCTAssertEqual(queue.next(), .init(scopes: .rates, manual: true))
        XCTAssertEqual(queue.enqueue(scopes: [.rates, .prices], manual: true), .accepted)
        XCTAssertEqual(queue.enqueue(scopes: .rates, manual: true), .alreadyRunning)
        XCTAssertEqual(queue.next(), .init(scopes: .prices, manual: true))
        XCTAssertNil(queue.next())

        queue = BackgroundPublicControlQueue()
        _ = queue.enqueue(scopes: [.rates, .prices], manual: false)
        _ = queue.enqueue(scopes: .prices, manual: true)
        XCTAssertEqual(queue.next(), .init(scopes: .prices, manual: true))
        XCTAssertEqual(queue.next(), .init(scopes: .rates, manual: false))
        XCTAssertNil(queue.next())
    }

    func testIndividualPublicSourcesStayNarrowAndRefreshAllAddsOnlyRemainingWork() {
        var queue = BackgroundPublicControlQueue()
        XCTAssertEqual(queue.enqueue(scopes: .inr, manual: true), .accepted)
        XCTAssertEqual(queue.next(), .init(scopes: .inr, manual: true))
        XCTAssertEqual(queue.enqueue(scopes: .amfi, manual: true), .accepted)
        XCTAssertEqual(queue.enqueue(scopes: .inr, manual: true), .alreadyRunning)
        XCTAssertEqual(queue.next(), .init(scopes: .amfi, manual: true))
        XCTAssertEqual(queue.enqueue(scopes: .all, manual: true), .accepted)
        XCTAssertEqual(queue.next(), .init(scopes: .all.subtracting([.inr, .amfi]), manual: true))
        XCTAssertNil(queue.next())
        XCTAssertEqual(queue.enqueue(scopes: .all, manual: true), .alreadyRunning)

        queue = BackgroundPublicControlQueue()
        XCTAssertEqual(queue.enqueue(scopes: .all, manual: false), .accepted)
        XCTAssertEqual(queue.enqueue(scopes: .fe, manual: true), .accepted)
        XCTAssertEqual(queue.next(), .init(scopes: .fe, manual: true))
        XCTAssertEqual(queue.next(), .init(scopes: .all.subtracting(.fe), manual: false))
        XCTAssertNil(queue.next())
    }

    func testPublicSourceSelectionRoundTripsAndRejectsUnknownRequests() {
        for currency in AlDarCurrency.allCases {
            let scopes = BackgroundPublicControlScopes.currency(currency)
            XCTAssertEqual(AlDarCurrency.allCases.filter { scopes.contains(.currency($0)) }, [currency])
            XCTAssertTrue(InvestmentPriceRegistry.providerOrder.allSatisfy { !scopes.includes(provider: $0) })
        }
        for provider in InvestmentPriceRegistry.providerOrder {
            let scopes = BackgroundPublicControlScopes.provider(provider)
            let wireValue = BackgroundPublicControlScopes(rawValue: scopes.rawValue)
            XCTAssertTrue(wireValue.isValid)
            XCTAssertTrue(wireValue.intersection(.rates).isEmpty)
            XCTAssertEqual(InvestmentPriceRegistry.providerOrder.filter { wireValue.includes(provider: $0) }, [provider])
        }
        XCTAssertFalse(BackgroundPublicControlScopes.all.includes(provider: "unknown"))
        var queue = BackgroundPublicControlQueue()
        XCTAssertEqual(queue.enqueue(scopes: [], manual: true), .refused)
        XCTAssertEqual(queue.enqueue(scopes: .init(rawValue: 1 << 12), manual: true), .refused)
        XCTAssertEqual(queue.enqueue(scopes: .init(rawValue: -1), manual: true), .refused)
        XCTAssertNil(queue.next())
    }

    func testManualPublicScopeWaitsForActiveLeaseWithoutLosingRequest() async throws {
        let url = try location(), provider = try SQLiteRepositoryProvider(path: url.path)
        defer { provider.database.close() }
        let activation = try XCTUnwrap(provider.database.currentActivationStamp)
        let executor = BackgroundUpdateExecutor(provider: provider, activation: activation, workspaceID: "mechanics")
        var lease = try XCTUnwrap(BackgroundJobLease.acquire(path: url.path, kind: .publicReferences)) as BackgroundJobLease?
        var completed = false
        var configuration = BackgroundScheduleConfiguration()
        configuration.alDarCurrencyRatesEnabled = false
        configuration.investmentPublicPricesEnabled = true
        let request = Task {
            let outcome = await executor.refreshPublic(configuration: configuration, manual: true, scopes: .fe)
            completed = true
            return outcome
        }
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertFalse(completed)
        XCTAssertNotNil(lease)
        lease = nil
        // This mechanics ledger has no holdings; reaching notDue proves the
        // request survived contention and evaluated its own scope, with no fetch.
        let outcome = await request.value
        XCTAssertEqual(outcome, .notDue)
        XCTAssertTrue(completed)
        XCTAssertTrue(try BackgroundPublicProgressStore(database: provider.database).load().isEmpty)
    }

    func testHelperAcceptanceRemainsPendingUntilCompletionAndLossIsNotSuccess() async {
        let running = BackgroundPublicCompletion.status(hasObservedRequest: true, active: true, failed: false)
        XCTAssertEqual(running, .alreadyRunning)
        // The accepting runtime disappears; a new runtime has no evidence of
        // that drain. Its ordinary idle state must not imply completion.
        let restarted = BackgroundPublicCompletion.status(hasObservedRequest: false, active: false, failed: false)
        XCTAssertEqual(restarted, .indeterminate)
        XCTAssertEqual(BackgroundPublicCompletion.status(hasObservedRequest: true, active: false, failed: false), .completed)
        XCTAssertEqual(BackgroundPublicCompletion.status(hasObservedRequest: true, active: false, failed: true), .failed)
        var statuses: [BackgroundWorkerControlStatus] = [.alreadyRunning, .alreadyRunning, .completed]
        var sleeps = 0
        let result = await BackgroundPublicCompletion.wait(after: .accepted, polls: 3,
            status: { statuses.removeFirst() }, sleep: { sleeps += 1 })
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(sleeps, 2)
        XCTAssertTrue(statuses.isEmpty)
        let lost = await BackgroundPublicCompletion.wait(after: .accepted,
            status: { .indeterminate }, sleep: { XCTFail("Lost contact must not resubmit or poll forever") })
        XCTAssertEqual(lost, .indeterminate)
        let timeout = await BackgroundPublicCompletion.wait(after: .accepted, polls: 2,
            status: { .alreadyRunning }, sleep: {})
        XCTAssertEqual(timeout, .indeterminate)
    }

    func testControlDeadlineAndLateRepliesCompleteOnlyOnce() async throws {
        var outcomes: [BackgroundWorkerControlStatus] = []
        let lostReply = BackgroundControlAcknowledgement(timeout: .milliseconds(10)) { outcomes.append($0) }
        try await Task.sleep(for: .milliseconds(40))
        lostReply.finish(.accepted)
        lostReply.finish(.unavailable)
        XCTAssertEqual(outcomes, [.indeterminate])

        let accepted = BackgroundControlAcknowledgement(timeout: .milliseconds(10)) { outcomes.append($0) }
        accepted.finish(.accepted)
        try await Task.sleep(for: .milliseconds(40))
        accepted.finish(.indeterminate)
        XCTAssertEqual(outcomes, [.indeterminate, .accepted])
    }

    func testXPCStyleTransportCallbacksFromNonMainQueueReachAcknowledgement() async {
        let expected: [BackgroundWorkerControlStatus] = [.indeterminate, .indeterminate, .accepted, .unavailable]
        for (entry, status) in expected.enumerated() {
            let completed = expectation(description: "Transport callback \(entry) completed")
            completed.assertForOverFulfill = true
            var outcomes: [BackgroundWorkerControlStatus] = []
            let acknowledgement = BackgroundControlAcknowledgement(timeout: .seconds(5)) {
                outcomes.append($0)
                completed.fulfill()
            }
            let callbacks = BackgroundControlTransportCallbacks(acknowledgement: acknowledgement)
            let invalidated = callbacks.invalidationHandler()
            let failed = callbacks.errorHandler()
            let replied = callbacks.replyHandler()

            DispatchQueue.global(qos: .userInitiated).async {
                XCTAssertFalse(Thread.isMainThread)
                switch entry {
                case 0: failed(TestXPCTransportError.failed)
                case 1: invalidated()
                case 2: replied(BackgroundWorkerControlStatus.accepted.rawValue)
                default: replied(Int.max)
                }
            }
            let result = await XCTWaiter.fulfillment(of: [completed], timeout: 1)
            XCTAssertEqual(result, .completed)
            XCTAssertEqual(outcomes, [status])
        }
    }

    func testManualDisabledScopeRetrySurvivesReopenAndDoesNotEnableFutureSlots() async throws {
        let url = try location(), provider = try SQLiteRepositoryProvider(path: url.path)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-19T11:59:40Z"))
        let retry = now.addingTimeInterval(60)
        var configuration = BackgroundScheduleConfiguration()
        configuration.enabled = true
        configuration.alDarCurrencyRatesEnabled = false; configuration.investmentPublicPricesEnabled = false
        configuration.gmailCollectionEnabled = false; configuration.zurichISPHoldingsEnabled = false
        try provider.backgroundScheduleRepo.saveConfiguration(configuration)
        var progress = BackgroundPublicLegProgress(identity: "aldar:INR", slot: BackgroundSchedule.publicSlot(at: now),
            attempts: 1, retryAt: retry, manuallyRequested: true)
        try BackgroundPublicProgressStore(database: provider.database).save(progress)
        try provider.database.checkpointAndClose()

        let reopened = try SQLiteRepositoryProvider(path: url.path)
        defer { reopened.database.close() }
        let stamp = try XCTUnwrap(reopened.database.currentActivationStamp)
        let executor = BackgroundUpdateExecutor(provider: reopened, activation: stamp, workspaceID: "mechanics")
        XCTAssertEqual(try reopened.backgroundScheduleRepo.configuration(), configuration)
        let before = try await executor.nextAutomaticTarget(configuration: configuration, now: now)
        let afterSlotChanged = try await executor.nextAutomaticTarget(configuration: configuration, now: retry)
        XCTAssertEqual(before, retry)
        XCTAssertEqual(afterSlotChanged, retry)

        progress.attempts = 2; progress.retryAt = nil
        try BackgroundPublicProgressStore(database: reopened.database).save(progress)
        let finalFailure = try await executor.nextAutomaticTarget(configuration: configuration, now: retry)
        XCTAssertNil(finalFailure)
        progress.attempts = 1; progress.succeeded = true
        try BackgroundPublicProgressStore(database: reopened.database).save(progress)
        let successful = try await executor.nextAutomaticTarget(configuration: configuration, now: retry)
        XCTAssertNil(successful)
        XCTAssertEqual(try reopened.backgroundPublicCacheRepo.snapshot(now: now), .empty)
    }

    func testLongGapPublicAndISPUseOneCurrentCatchUpThenTheirNextConfiguredTarget() async throws {
        let url = try location(), provider = try SQLiteRepositoryProvider(path: url.path)
        defer { provider.database.close() }
        let stamp = try XCTUnwrap(provider.database.currentActivationStamp)
        let old = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-20T00:00:00Z"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-03-20T12:00:00Z"))
        let executor = BackgroundUpdateExecutor(provider: provider, activation: stamp, workspaceID: "mechanics")

        var publicConfiguration = BackgroundScheduleConfiguration(enabled: true,
            alDarCurrencyRatesEnabled: true, investmentPublicPricesEnabled: false,
            gmailCollectionEnabled: false, zurichISPHoldingsEnabled: false,
            publicReferencesRule: .selectedWeekdays(weekdays: BackgroundScheduleConfiguration.allWeekdays, timesUTC: [0]),
            gmailRule: .selectedWeekdays(weekdays: BackgroundScheduleConfiguration.allWeekdays, timesUTC: [0]),
            zurichISPRule: .monthly(daysUTC: [1], timesUTC: [0]))
        try provider.backgroundScheduleRepo.saveConfiguration(publicConfiguration)
        for currency in AlDarCurrency.allCases {
            try BackgroundPublicProgressStore(database: provider.database).save(.init(identity: "aldar:" + currency.rawValue,
                slot: old, attempts: 1, succeeded: true))
        }
        let publicCatchUp = try await executor.nextAutomaticTarget(configuration: publicConfiguration, now: now)
        XCTAssertEqual(publicCatchUp, now)
        let publicCurrent = try XCTUnwrap(BackgroundSchedule.latestOccurrence(of: publicConfiguration.publicReferencesRule, at: now))
        for currency in AlDarCurrency.allCases {
            try BackgroundPublicProgressStore(database: provider.database).save(.init(identity: "aldar:" + currency.rawValue,
                slot: publicCurrent, attempts: 1, succeeded: true))
        }
        let publicSuccessor = try await executor.nextAutomaticTarget(configuration: publicConfiguration, now: now)
        let expectedPublicSuccessor = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-03-21T00:00:00Z"))
        XCTAssertEqual(publicSuccessor, expectedPublicSuccessor)

        publicConfiguration.alDarCurrencyRatesEnabled = false
        publicConfiguration.zurichISPHoldingsEnabled = true
        try provider.backgroundScheduleRepo.saveConfiguration(publicConfiguration)
        let oldISP = try XCTUnwrap(provider.backgroundJobRepo.claim(.zurichISP, activation: stamp, origin: .helper, now: old))
        try provider.backgroundJobRepo.finish(oldISP, outcome: .committedCurrentHoldings, now: old)
        let ispCatchUp = try await executor.nextAutomaticTarget(configuration: publicConfiguration, now: now)
        XCTAssertEqual(ispCatchUp, now)
        let currentISP = try XCTUnwrap(provider.backgroundJobRepo.claim(.zurichISP, activation: stamp, origin: .foreground, now: now))
        try provider.backgroundJobRepo.finish(currentISP, outcome: .committedCurrentHoldings, now: now)
        let ispSuccessor = try await executor.nextAutomaticTarget(configuration: publicConfiguration, now: now)
        let expectedISPSuccessor = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-04-01T00:00:00Z"))
        XCTAssertEqual(ispSuccessor, expectedISPSuccessor)
    }

    func testConfigurationReopenAndRestoreReconciliation() throws {
        let url = try location(), provider = try SQLiteRepositoryProvider(path: url.path)
        let stamp = try XCTUnwrap(provider.database.currentActivationStamp)
        var configuration = BackgroundScheduleConfiguration()
        configuration.gmailRule = .selectedWeekdays(weekdays: [2, 4, 6], timesUTC: [7 * 60 + 15])
        configuration.zurichISPRule = .monthly(daysUTC: [1, 15], timesUTC: [18 * 60])
        try provider.backgroundScheduleRepo.saveConfiguration(configuration)
        let claim = try XCTUnwrap(provider.backgroundJobRepo.claim(.gmailCollection, activation: stamp, origin: .helper, now: Date()))
        try provider.backgroundJobRepo.finish(claim, outcome: .refusedNoCoverage, now: Date())
        try BackgroundPublicProgressStore(database: provider.database).save(.init(identity: "mechanical-leg", slot: Date(), attempts: 1, retryAt: Date().addingTimeInterval(60)))
        try SQLiteBackgroundJobRepository.reconcileRestore(database: provider.database)
        XCTAssertNil(try provider.backgroundJobRepo.jobRecord(.gmailCollection))
        XCTAssertTrue(try BackgroundPublicProgressStore(database: provider.database).load().isEmpty)
        XCTAssertEqual(try provider.backgroundScheduleRepo.configuration(), configuration)
        try provider.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: url.path)
        defer { reopened.database.close() }
        XCTAssertEqual(try reopened.backgroundScheduleRepo.configuration(), configuration)
        XCTAssertEqual(try reopened.backgroundPublicCacheRepo.snapshot(now: Date()), .empty)
    }

    func testAbandonedClaimCanBeReplacedButLateCompletionIsRefused() throws {
        let url = try location(), provider = try SQLiteRepositoryProvider(path: url.path)
        defer { provider.database.close() }
        let stamp = try XCTUnwrap(provider.database.currentActivationStamp)
        var lease = try BackgroundJobLease.acquire(path: url.path, kind: .publicReferences)
        XCTAssertNotNil(lease)
        let first = try XCTUnwrap(provider.backgroundJobRepo.claim(.publicReferences, activation: stamp, origin: .helper, now: Date()))
        XCTAssertNil(try BackgroundJobLease.acquire(path: url.path, kind: .publicReferences))
        lease = nil
        let successorLease = try XCTUnwrap(BackgroundJobLease.acquire(path: url.path, kind: .publicReferences))
        defer { withExtendedLifetime(successorLease) {} }
        let second = try XCTUnwrap(provider.backgroundJobRepo.claim(.publicReferences, activation: stamp, origin: .foreground, now: Date()))
        XCTAssertNotEqual(first.claimID, second.claimID)
        XCTAssertThrowsError(try provider.backgroundJobRepo.finish(first, outcome: .failedFinal, now: Date()))
        try provider.backgroundJobRepo.finish(second, outcome: .failedFinal, now: Date())
        XCTAssertEqual(try provider.backgroundJobRepo.jobRecord(.publicReferences)?.origin, .foreground)
        XCTAssertEqual(try provider.backgroundJobRepo.jobRecord(.publicReferences)?.outcome, .failedFinal)
    }

    func testReceiptIsRolledBackWithItsOwningTransaction() throws {
        let provider = try SQLiteRepositoryProvider(path: location().path)
        defer { provider.database.close() }
        let stamp = try XCTUnwrap(provider.database.currentActivationStamp)
        let claim = try XCTUnwrap(provider.backgroundJobRepo.claim(.zurichISP, activation: stamp, origin: .helper, now: Date()))
        try provider.database.withExclusiveAccess {
            try provider.database.execute(sql: "BEGIN IMMEDIATE;")
            try SQLiteBackgroundJobRepository.finishWithinTransaction(database: provider.database, record: claim, outcome: .failedFinal, now: Date())
            try provider.database.execute(sql: "ROLLBACK;")
        }
        XCTAssertNil(try provider.backgroundJobRepo.jobRecord(.zurichISP)?.completedAt)
    }

    func testEnrollmentRevocationAndOneTimeAuthorizationConsumption() throws {
        let url = try location(), provider = try SQLiteRepositoryProvider(path: url.path)
        defer { provider.database.close() }
        let stamp = try XCTUnwrap(provider.database.currentActivationStamp)
        let store = BackgroundEnrollmentStore(url: url.deletingLastPathComponent().appendingPathComponent("enrollment.json"))
        let enrolled = BackgroundEnrollment(revision: UUID(), databasePath: url.path, workspaceID: "mechanical-workspace",
            activation: stamp, enabled: true, authorizationRequestedAt: Date())
        try store.save(enrolled)
        let consumed = try store.consumeAuthorization(enrolled)
        XCTAssertNil(consumed.authorizationRequestedAt)
        XCTAssertThrowsError(try store.withValid(enrolled) {})
        try store.withValid(consumed) {}
        let disabled = BackgroundEnrollment(revision: UUID(), databasePath: url.path, workspaceID: "mechanical-workspace", activation: stamp, enabled: false)
        try store.save(disabled)
        XCTAssertThrowsError(try store.withValid(consumed) {})
        XCTAssertThrowsError(try store.withValid(disabled) {})
    }

    func testScheduledKeychainQueriesProhibitInteractionWithoutReadingCredentials() throws {
        let query = CredentialInteractionPolicy.forbidden.applying(to: [kSecClass: kSecClassGenericPassword])
        let context = try XCTUnwrap(query[kSecUseAuthenticationContext] as? LAContext)
        XCTAssertTrue(context.interactionNotAllowed)
        XCTAssertNil(CredentialInteractionPolicy.foreground.applying(to: [:])[kSecUseAuthenticationContext])
    }

    func testForegroundMigrationPreservesOnlyExactExistingEnrollment() throws {
        for enabled in [true, false] {
            let url = try location()
            let old = try SQLiteRepositoryProvider(path: url.path, migrations: Array(allMigrations.prefix(25)))
            let previous = try old.database.validatedActivationStamp()
            var configuration = BackgroundScheduleConfiguration()
            configuration.enabled = enabled
            try old.backgroundScheduleRepo.saveConfiguration(configuration)
            let store = BackgroundEnrollmentStore(url: url.deletingLastPathComponent().appendingPathComponent("enrollment.json"))
            let original = BackgroundEnrollment(revision: UUID(), databasePath: url.path, workspaceID: "mechanical-workspace",
                activation: previous, enabled: enabled, authorizationRequestedAt: Date())
            try store.save(original)
            try old.database.checkpointAndClose()

            let current = try SQLiteRepositoryProvider(path: url.path, migrations: allMigrations, access: .existing, migrateExisting: true)
            defer { current.database.close() }
            let updated = try current.database.validatedActivationStamp()
            XCTAssertNotEqual(previous, updated)
            XCTAssertEqual(updated.schemaVersion, allMigrations.count)
            try store.reconcileMigration(path: url.path, from: previous, to: updated)
            let enrolled = try XCTUnwrap(store.load())
            XCTAssertEqual(enrolled.activation, updated)
            XCTAssertEqual(enrolled.enabled, enabled)
            XCTAssertEqual(enrolled.authorizationRequestedAt, original.authorizationRequestedAt)
            XCTAssertEqual(enrolled.workspaceID, original.workspaceID)
            XCTAssertNotEqual(enrolled.revision, original.revision)
            XCTAssertEqual(try current.backgroundScheduleRepo.configuration(), configuration)
            XCTAssertThrowsError(try store.withValid(original) {})
            if enabled { try store.withValid(enrolled) {} }
            else { XCTAssertThrowsError(try store.withValid(enrolled) {}) }
            try store.reconcileMigration(path: url.path, from: previous, to: updated)
            XCTAssertEqual(try store.load(), enrolled)

            let unrelated = BackgroundEnrollment(revision: UUID(), databasePath: url.path + ".other",
                workspaceID: original.workspaceID, activation: previous, enabled: enabled)
            try store.save(unrelated)
            try store.reconcileMigration(path: url.path, from: previous, to: updated)
            XCTAssertEqual(try store.load(), unrelated)
            let stale = LedgerActivationStamp(epoch: UUID(), device: previous.device, inode: previous.inode,
                schemaVersion: previous.schemaVersion, compatibilityVersion: previous.compatibilityVersion, transitioning: false)
            let staleEnrollment = BackgroundEnrollment(revision: UUID(), databasePath: url.path,
                workspaceID: original.workspaceID, activation: stale, enabled: enabled)
            try store.save(staleEnrollment)
            try store.reconcileMigration(path: url.path, from: previous, to: updated)
            XCTAssertEqual(try store.load(), staleEnrollment)
            try store.save(original)
            let replaced = LedgerActivationStamp(epoch: updated.epoch, device: updated.device, inode: updated.inode + 1,
                schemaVersion: updated.schemaVersion, compatibilityVersion: updated.compatibilityVersion, transitioning: false)
            try store.reconcileMigration(path: url.path, from: previous, to: replaced)
            XCTAssertEqual(try store.load(), original)
        }
    }

    func testForbiddenCredentialOperationsSuppressAndRestoreLegacyInteractionForReadAndUpdate() throws {
        let controller = TestLegacyKeychainInteractionController(allowed: true)
        let coordinator = CredentialInteractionCoordinator(controller: controller)

        XCTAssertEqual(try coordinator.perform(policy: .forbidden) {
            XCTAssertFalse(controller.snapshot().allowed)
            return "read"
        }, "read")
        XCTAssertEqual(try coordinator.perform(policy: .forbidden) {
            XCTAssertFalse(controller.snapshot().allowed)
            return "update"
        }, "update")

        XCTAssertEqual(controller.snapshot().setHistory, [false, true, false, true])
        XCTAssertTrue(controller.snapshot().allowed)
    }

    func testForbiddenCredentialOperationRestoresLegacyStateAfterOperationError() {
        let controller = TestLegacyKeychainInteractionController(allowed: true)
        let coordinator = CredentialInteractionCoordinator(controller: controller)
        XCTAssertThrowsError(try coordinator.perform(policy: .forbidden) { () -> Void in
            throw TestCredentialInteractionError.operationFailed
        })
        XCTAssertEqual(controller.snapshot().setHistory, [false, true])
        XCTAssertTrue(controller.snapshot().allowed)
    }

    func testForbiddenCredentialOperationReportsLegacyStateFailuresAndRestorationFailure() {
        let unavailable = TestLegacyKeychainInteractionController(allowed: true, getStatus: errSecAuthFailed)
        let unavailableCoordinator = CredentialInteractionCoordinator(controller: unavailable)
        XCTAssertThrowsError(try unavailableCoordinator.perform(policy: .forbidden) { () -> Void in }) { error in
            XCTAssertEqual(error as? CredentialInteractionPolicyError, .legacyInteractionStateUnavailable(errSecAuthFailed))
        }

        let restoreFailure = TestLegacyKeychainInteractionController(allowed: true, setStatuses: [errSecSuccess, errSecAuthFailed])
        let restoreCoordinator = CredentialInteractionCoordinator(controller: restoreFailure)
        XCTAssertThrowsError(try restoreCoordinator.perform(policy: .forbidden) { () -> Void in }) { error in
            XCTAssertEqual(error as? CredentialInteractionPolicyError, .legacyInteractionRestoreFailed(errSecAuthFailed))
        }
        XCTAssertEqual(restoreFailure.snapshot().setHistory, [false, true])
    }

    func testForbiddenCredentialOperationDoesNotEnterWhenLegacySuppressionFails() {
        let controller = TestLegacyKeychainInteractionController(allowed: true, setStatuses: [errSecAuthFailed])
        let coordinator = CredentialInteractionCoordinator(controller: controller)
        var entered = false
        XCTAssertThrowsError(try coordinator.perform(policy: .forbidden) {
            entered = true
        }) { error in
            XCTAssertEqual(error as? CredentialInteractionPolicyError, .legacyInteractionSuppressionFailed(errSecAuthFailed))
        }
        XCTAssertFalse(entered)
        XCTAssertEqual(controller.snapshot().setHistory, [false])
        XCTAssertTrue(controller.snapshot().allowed)
    }

    func testForbiddenCredentialOperationPreservesPreviouslyDisabledLegacyState() throws {
        let controller = TestLegacyKeychainInteractionController(allowed: false)
        let coordinator = CredentialInteractionCoordinator(controller: controller)
        try coordinator.perform(policy: .forbidden) {
            XCTAssertFalse(controller.snapshot().allowed)
        }
        XCTAssertEqual(controller.snapshot().setHistory, [false, false])
        XCTAssertFalse(controller.snapshot().allowed)
    }

    func testForegroundCredentialOperationWaitsForForbiddenLegacyScope() throws {
        let controller = TestLegacyKeychainInteractionController(allowed: true)
        let coordinator = CredentialInteractionCoordinator(controller: controller)
        let forbiddenEntered = DispatchSemaphore(value: 0)
        let releaseForbidden = DispatchSemaphore(value: 0)
        let forbiddenFinished = DispatchSemaphore(value: 0)
        let foregroundAttempted = DispatchSemaphore(value: 0)
        let foregroundEntered = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            defer { forbiddenFinished.signal() }
            try? coordinator.perform(policy: .forbidden) {
                forbiddenEntered.signal()
                _ = releaseForbidden.wait(timeout: .now() + 2)
            }
        }
        XCTAssertEqual(forbiddenEntered.wait(timeout: .now() + 1), .success)

        DispatchQueue.global().async {
            foregroundAttempted.signal()
            try? coordinator.perform(policy: .foreground) {
                XCTAssertTrue(controller.snapshot().allowed)
                foregroundEntered.signal()
            }
        }
        XCTAssertEqual(foregroundAttempted.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(foregroundEntered.wait(timeout: .now() + 0.05), .timedOut)
        releaseForbidden.signal()
        XCTAssertEqual(forbiddenFinished.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(foregroundEntered.wait(timeout: .now() + 1), .success)
    }

    func testSystemLegacyInteractionControllerSuppressesAndRestoresWithoutCredentialAccess() throws {
        var before = DarwinBoolean(false)
        XCTAssertEqual(SecKeychainGetUserInteractionAllowed(&before), errSecSuccess)
        let expected = before.boolValue

        try CredentialInteractionCoordinator.shared.perform(policy: .forbidden) {
            var inside = DarwinBoolean(false)
            XCTAssertEqual(SecKeychainGetUserInteractionAllowed(&inside), errSecSuccess)
            XCTAssertFalse(inside.boolValue)
        }

        var after = DarwinBoolean(false)
        XCTAssertEqual(SecKeychainGetUserInteractionAllowed(&after), errSecSuccess)
        XCTAssertEqual(after.boolValue, expected)
    }

    func testIndependentProcessOwnsLeaseUntilProcessExit() throws {
        let url = try location()
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = try XCTUnwrap(Bundle(for: Self.self).resourceURL?.appendingPathComponent("LedgerForgeSubprocessProbe"))
        process.arguments = [url.path, "background-lease", "mechanics", "lease"]
        process.standardInput = input; process.standardOutput = output
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeout)
        defer { timeout.cancel(); if process.isRunning { process.terminate(); process.waitUntilExit() } }
        var line = Data()
        while let byte = try output.fileHandleForReading.read(upToCount: 1), !byte.isEmpty, byte != Data([10]) { line.append(byte) }
        XCTAssertEqual(String(decoding: line, as: UTF8.self), "READY")
        XCTAssertNil(try BackgroundJobLease.acquire(path: url.path, kind: .publicReferences))
        try input.fileHandleForWriting.write(contentsOf: Data("GO\n".utf8))
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let response = try XCTUnwrap(JSONSerialization.jsonObject(with: output.fileHandleForReading.readDataToEndOfFile()) as? [String: Any])
        XCTAssertEqual(response["result"] as? String, "exited-with-lease")
        let lease = try XCTUnwrap(BackgroundJobLease.acquire(path: url.path, kind: .publicReferences))
        withExtendedLifetime(lease) {}
    }

    func testResetReconcilesClaimsAndEnrollmentOnSuccessAndBothFailureSides() throws {
        let failures: [DevelopmentDatabaseLifecycleFailurePoint?] = [nil, .backupCreation, .recreation]
        for failure in failures {
            let root = try location().deletingLastPathComponent()
            let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
            try FileManager.default.createDirectory(at: identity.canonicalDevelopmentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let store = BackgroundEnrollmentStore(url: root.appendingPathComponent("enrollment.json"))
            let saved = DatabaseProvider.shared
            defer { DatabaseProvider.shared = saved }
            let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: DevelopmentDatabaseActivityGate(),
                injectedFailures: [], backgroundEnrollmentStore: store)
            _ = try coordinator.installInitialProvider(SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path))
            defer { coordinator.closeOwnedProvider() }
            guard case .activated = coordinator.activate(.persistentDebug) else { return XCTFail("Mechanical profile activation failed") }
            let prior = try XCTUnwrap(DatabaseProvider.shared.sqliteProvider)
            let stamp = try prior.database.validatedActivationStamp()
            let enrollment = BackgroundEnrollment(revision: UUID(), databasePath: prior.databasePath, workspaceID: "mechanical-workspace", activation: stamp, enabled: true)
            try store.save(enrollment)
            var configuration = BackgroundScheduleConfiguration()
            configuration.gmailRule = .selectedWeekdays(weekdays: [3], timesUTC: [123])
            try prior.backgroundScheduleRepo.saveConfiguration(configuration)
            let claim = try XCTUnwrap(prior.backgroundJobRepo.claim(.gmailCollection, activation: stamp, origin: .helper, now: Date()))
            try BackgroundPublicProgressStore(database: prior.database).save(.init(identity: "mechanical-leg", slot: Date(), attempts: 1, retryAt: Date().addingTimeInterval(60)))
            if let failure { coordinator.injectedFailures = [failure] }
            let result = coordinator.resetActiveProfile()
            if failure == nil {
                guard case .activated = result else { return XCTFail("Mechanical reset failed") }
            } else { XCTAssertEqual(result, .candidateCreationFailed) }
            let current = try XCTUnwrap(DatabaseProvider.shared.sqliteProvider)
            let after = try current.database.validatedActivationStamp()
            XCTAssertNotEqual(after.epoch, stamp.epoch)
            XCTAssertEqual(try store.load()?.activation, after)
            XCTAssertNotEqual(try store.load()?.revision, enrollment.revision)
            XCTAssertNil(try current.backgroundJobRepo.jobRecord(.gmailCollection))
            XCTAssertTrue(try BackgroundPublicProgressStore(database: current.database).load().isEmpty)
            XCTAssertThrowsError(try current.backgroundJobRepo.finish(claim, outcome: .failedFinal, now: Date()))
            XCTAssertEqual(try current.backgroundScheduleRepo.configuration(), failure == nil ? .init() : configuration)
        }
    }

    func testEmptyGmailCoverageRefusesBeforeCredentialsAndDoesNotAdvanceNativeCoverage() async throws {
        let provider = try SQLiteRepositoryProvider(path: location().path)
        defer { provider.database.close() }
        let stamp = try XCTUnwrap(provider.database.currentActivationStamp)
        let executor = BackgroundUpdateExecutor(provider: provider, activation: stamp, workspaceID: "mechanical-workspace")
        let outcome = await executor.collectGmail(configuration: .init(), manual: false)
        XCTAssertEqual(outcome, .completed(.refusedNoCoverage))
        XCTAssertTrue(try provider.gmailInboxRepo.storedAccounts().isEmpty)
        XCTAssertEqual(try provider.backgroundJobRepo.jobRecord(.gmailCollection)?.outcome, .refusedNoCoverage)
        let repeatOutcome = await executor.collectGmail(configuration: .init(), manual: false)
        XCTAssertEqual(repeatOutcome, .notDue)
    }
}

private enum TestCredentialInteractionError: Error {
    case operationFailed
}

private enum TestXPCTransportError: Error {
    case failed
}

private final class TestLegacyKeychainInteractionController: LegacyKeychainInteractionControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var allowed: Bool
    private let getStatus: OSStatus
    private var setStatuses: [OSStatus]
    private var setHistory = [Bool]()

    init(allowed: Bool, getStatus: OSStatus = errSecSuccess, setStatuses: [OSStatus] = []) {
        self.allowed = allowed
        self.getStatus = getStatus
        self.setStatuses = setStatuses
    }

    func userInteractionAllowed() -> (status: OSStatus, allowed: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (getStatus, allowed)
    }

    func setUserInteractionAllowed(_ allowed: Bool) -> OSStatus {
        lock.lock()
        defer { lock.unlock() }
        setHistory.append(allowed)
        let status = setStatuses.isEmpty ? errSecSuccess : setStatuses.removeFirst()
        if status == errSecSuccess { self.allowed = allowed }
        return status
    }

    func snapshot() -> (allowed: Bool, setHistory: [Bool]) {
        lock.lock()
        defer { lock.unlock() }
        return (allowed, setHistory)
    }
}
