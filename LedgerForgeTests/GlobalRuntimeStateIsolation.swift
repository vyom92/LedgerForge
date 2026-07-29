import Testing
@testable import LedgerForge

/// Cross-suite isolation for tests that mutate LedgerForge's process-wide runtime state.
///
/// Swift Testing's `.serialized` trait is suite-local. This trait instead uses one
/// target-wide async gate, and its scope remains held while an async test suspends.
struct GlobalRuntimeStateIsolationTrait: TestTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @concurrent @Sendable () async throws -> Void
    ) async throws {
        await GlobalRuntimeStateGate.shared.acquire()
        await MainActor.run {
            GlobalRuntimeStateCleanup.reset()
        }
        do {
            try await function()
        } catch {
            await MainActor.run {
                GlobalRuntimeStateCleanup.reset()
            }
            await GlobalRuntimeStateGate.shared.release()
            throw error
        }
        await MainActor.run {
            GlobalRuntimeStateCleanup.reset()
        }
        await GlobalRuntimeStateGate.shared.release()
    }
}

extension Trait where Self == GlobalRuntimeStateIsolationTrait {
    static var globalRuntimeStateIsolation: Self {
        GlobalRuntimeStateIsolationTrait()
    }
}

private actor GlobalRuntimeStateGate {
    static let shared = GlobalRuntimeStateGate()

    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

@MainActor
private enum GlobalRuntimeStateCleanup {
    static func reset() {
#if DEBUG
        DevelopmentDatabaseLifecycleCoordinator.shared.closeOwnedProvider()
        DevelopmentProfileAcknowledgementGate.shared.resetForTesting()
#endif
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)
        AccountStore.shared.replaceAccounts([])
        TransactionStore.shared.replaceTransactions([])
        DocumentStore.shared.clear()
        ImportSessionStore.shared.replaceImportSessions([])
        ImportAttemptStore.shared.replaceAttempts([])
        CategoryStore.shared.replaceSnapshot(.empty)
        CategoryReconciliationGate.shared.resetForTesting()
        DeveloperConsole.shared._resetForTests()
        DevelopmentDatabaseActivityGate.shared.resetForTesting()
    }
}
