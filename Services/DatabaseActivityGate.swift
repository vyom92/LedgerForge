import Foundation
import Combine

enum DatabaseActivity: String, Equatable {
    case importPreparation
    case preparedAwaitingConfirmation
    case confirmedPersistence
    case hydration
    case repositoryWrite
    case developerReload
    case backup
}

enum DatabaseActivityError: Error, LocalizedError {
    case lifecycleOperationInProgress
    case lifecycleUnavailable

    var errorDescription: String? {
        "Database activity is unavailable while the database is being replaced."
    }
}

@MainActor
final class DatabaseActivityLease {
    private weak var gate: DatabaseActivityGate?
    fileprivate let id: UUID
    fileprivate(set) var activity: DatabaseActivity
    private(set) var generation: Int
    private var isFinished = false

    fileprivate init(gate: DatabaseActivityGate, activity: DatabaseActivity, generation: Int) {
        self.gate = gate
        self.id = UUID()
        self.activity = activity
        self.generation = generation
    }

    func transition(to activity: DatabaseActivity) async {
        guard !isFinished else { return }
        self.activity = activity
        gate?.update(self)
        await gate?.observeTransitionForTesting(activity)
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        gate?.finish(self)
    }
}

#if DEBUG
struct DevelopmentDatabasePreparedImportDrainPermit {
    fileprivate init() {}
}

enum DevelopmentDatabaseProfileSwitchBarrierResult: Equatable {
    case acquired(DevelopmentPreparedImportInvalidationResult)
    case activityBlocked
    case lifecycleUnavailable
}

#endif

@MainActor
final class DatabaseActivityGate {
    static let shared = DatabaseActivityGate()
    /// Pending app-owned work resumes after recovery/profile transitions release their gate.
    let didBecomeAvailable = PassthroughSubject<Void, Never>()

    private var leases: [UUID: DatabaseActivity] = [:]
    private(set) var generation = 1
    private(set) var hasExclusiveOperation = false
    private(set) var isProfileSwitchPending = false
    private(set) var isUnavailable = false
#if DEBUG
    private var transitionObserverForTesting: (@MainActor (DatabaseActivity) async -> Void)?

#endif

    private struct DraftOwner {
        weak var owner: AnyObject?
        let hasDraft: @MainActor () -> Bool
    }
    private var draftOwners: [ObjectIdentifier: DraftOwner] = [:]
    func registerDraftOwner(_ owner: AnyObject, hasDraft: @escaping @MainActor () -> Bool) {
        draftOwners[ObjectIdentifier(owner)] = DraftOwner(owner: owner, hasDraft: hasDraft)
    }
    var hasUnresolvedDrafts: Bool {
        draftOwners = draftOwners.filter { $0.value.owner != nil }
        return draftOwners.values.contains { $0.hasDraft() }
    }

    var hasActiveOperations: Bool { !leases.isEmpty }

    func begin(_ activity: DatabaseActivity) throws -> DatabaseActivityLease {
        guard !isUnavailable else { throw DatabaseActivityError.lifecycleUnavailable }
        guard !hasExclusiveOperation, !isProfileSwitchPending else {
            throw DatabaseActivityError.lifecycleOperationInProgress
        }
        let lease = DatabaseActivityLease(gate: self, activity: activity, generation: generation)
        leases[lease.id] = activity
        return lease
    }

    func beginExclusive(allowUnavailable: Bool = false) -> Bool {
        guard (!isUnavailable || allowUnavailable), !hasUnresolvedDrafts, !hasExclusiveOperation, !isProfileSwitchPending, leases.isEmpty else { return false }
        hasExclusiveOperation = true
        return true
    }

#if DEBUG
    /// Creates one synchronous barrier: new work is blocked before prepared
    /// previews are drained, and exclusive ownership is granted only after all
    /// corresponding leases have been released.
    func beginProfileSwitch(
        drainPreparedImports: (DevelopmentDatabasePreparedImportDrainPermit) -> DevelopmentPreparedImportInvalidationResult
    ) -> DevelopmentDatabaseProfileSwitchBarrierResult {
        guard !isUnavailable else { return .lifecycleUnavailable }
        guard !hasExclusiveOperation, !isProfileSwitchPending else { return .activityBlocked }

        isProfileSwitchPending = true
        let hasNonDrainableActivity = leases.values.contains { $0 != .preparedAwaitingConfirmation }
        guard !hasNonDrainableActivity else {
            isProfileSwitchPending = false
            return .activityBlocked
        }

        let invalidation = drainPreparedImports(DevelopmentDatabasePreparedImportDrainPermit())
        guard leases.isEmpty else {
            isProfileSwitchPending = false
            return .activityBlocked
        }

        hasExclusiveOperation = true
        return .acquired(invalidation)
    }

#endif

    func finishExclusive(providerChanged: Bool) {
        isUnavailable = false
        if providerChanged { generation += 1 }
        hasExclusiveOperation = false
        isProfileSwitchPending = false
        didBecomeAvailable.send()
    }

    func enterUnavailable() {
        isUnavailable = true
        hasExclusiveOperation = false
        isProfileSwitchPending = false
    }

    fileprivate func update(_ lease: DatabaseActivityLease) {
        guard leases[lease.id] != nil else { return }
        leases[lease.id] = lease.activity
    }

    fileprivate func observeTransitionForTesting(_ activity: DatabaseActivity) async {
#if DEBUG
        await transitionObserverForTesting?(activity)
#endif
    }

#if DEBUG
    func setTransitionObserverForTesting(
        _ observer: (@MainActor (DatabaseActivity) async -> Void)?
    ) {
        transitionObserverForTesting = observer
    }

#endif

    fileprivate func finish(_ lease: DatabaseActivityLease) {
        leases.removeValue(forKey: lease.id)
    }

#if DEBUG
    func resetForTesting() {
        leases.removeAll()
        hasExclusiveOperation = false
        isProfileSwitchPending = false
        isUnavailable = false
        generation = 1
        transitionObserverForTesting = nil
    }
#endif
}

#if DEBUG
// Existing DEBUG callers/tests retain their names; production uses the shared gate.
typealias DevelopmentDatabaseActivity = DatabaseActivity
typealias DevelopmentDatabaseActivityError = DatabaseActivityError
typealias DevelopmentDatabaseActivityLease = DatabaseActivityLease
typealias DevelopmentDatabaseActivityGate = DatabaseActivityGate
#endif
