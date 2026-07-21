import Foundation

/// Process-local protection for the narrow window where a financial commit is
/// durable but canonical runtime stores have not yet been refreshed.
final class ConfirmedImportReconciliationGate {
    private let lock = NSLock()
    private var blocked = false

    var isBlocked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return blocked
    }

    func requireReconciliation() {
        lock.lock()
        blocked = true
        lock.unlock()
    }

    func clearAfterCanonicalHydration() {
        lock.lock()
        blocked = false
        lock.unlock()
    }
}
