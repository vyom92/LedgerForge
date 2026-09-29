import Foundation

/// The sole foreground-to-agent control surface. Its wire format contains
/// enrollment identity, selected public legs and a manual/due intent only;
/// cache values, filesystem paths, credentials and provider payloads never
/// cross this boundary.
nonisolated enum BackgroundWorkerControl {
    static let machService = "com.vyom.LedgerForge.BackgroundWorker.control"
    static let helperRequirement = "anchor apple generic and certificate leaf[subject.OU] = \"T45VZQAFDY\" and identifier \"com.vyom.LedgerForge.BackgroundWorker\""
    static let appRequirement = "anchor apple generic and certificate leaf[subject.OU] = \"T45VZQAFDY\" and identifier \"com.vyom.LedgerForge\""
}

/// Integers deliberately keep the control reply nonfinancial and trivially
/// NSSecureCoding-compatible. `accepted` means the helper took ownership of
/// the request; it does not claim a provider result.
@objc enum BackgroundWorkerControlStatus: Int, Sendable {
    case accepted = 0
    case alreadyRunning = 1
    case refused = 2
    case unavailable = 3
    /// Delivery could have occurred before the reply connection ended. The
    /// foreground deliberately does not submit a local duplicate in this case.
    case indeterminate = 4
    case completed = 5
    case failed = 6
}

@objc protocol BackgroundWorkerControlProtocol {
    func requestReschedule(enrollmentRevision: String, reply: @escaping (Int) -> Void)
    func requestPublic(enrollmentRevision: String,
                       alDarRates: Bool,
                       investmentPrices: Bool,
                       manual: Bool,
                       reply: @escaping (Int) -> Void)
    func requestPublicSources(enrollmentRevision: String, sources: Int,
                              manual: Bool, reply: @escaping (Int) -> Void)
    func publicRequestStatus(enrollmentRevision: String, reply: @escaping (Int) -> Void)
}

nonisolated enum BackgroundWorkerControlInterface {
    nonisolated static func make() -> NSXPCInterface {
        NSXPCInterface(with: BackgroundWorkerControlProtocol.self)
    }
}

nonisolated struct BackgroundPublicControlScopes: OptionSet, Sendable {
    let rawValue: Int
    static let inr = Self(rawValue: 1 << 0)
    static let usd = Self(rawValue: 1 << 1)
    static let amfi = Self(rawValue: 1 << 2)
    static let nasdaq = Self(rawValue: 1 << 3)
    static let fe = Self(rawValue: 1 << 4)
    static let fidelity = Self(rawValue: 1 << 5)
    static let blackrock = Self(rawValue: 1 << 6)
    static let franklin = Self(rawValue: 1 << 7)
    static let rates: Self = [.inr, .usd]
    static let prices: Self = [.amfi, .nasdaq, .fe, .fidelity, .blackrock, .franklin]
    static let all: Self = [.rates, .prices]
    init(rawValue: Int) { self.rawValue = rawValue }
    init(rates: Bool, prices: Bool) {
        rawValue = (rates ? Self.rates.rawValue : 0) | (prices ? Self.prices.rawValue : 0)
    }
    var isValid: Bool { !isEmpty && subtracting(.all).isEmpty }
    static func currency(_ currency: AlDarCurrency) -> Self { currency == .inr ? .inr : .usd }
    static func provider(_ provider: String) -> Self {
        switch provider {
        case "amfi": .amfi
        case "nasdaq": .nasdaq
        case "fe": .fe
        case "fidelity": .fidelity
        case "blackrock": .blackrock
        case "franklin": .franklin
        default: []
        }
    }
    func includes(provider: String) -> Bool {
        let source = Self.provider(provider)
        return !source.isEmpty && contains(source)
    }
}

/// Coalesce one drain of public work. A repeated scope joins its accepted
/// work; a newly requested scope is queued once. Manual intent upgrades only
/// that scope while it is still pending.
nonisolated struct BackgroundPublicControlQueue {
    struct Request: Equatable, Sendable {
        let scopes: BackgroundPublicControlScopes
        let manual: Bool
    }
    private var accepted: BackgroundPublicControlScopes = []
    private var pending: BackgroundPublicControlScopes = []
    private var manualPending: BackgroundPublicControlScopes = []

    mutating func enqueue(scopes: BackgroundPublicControlScopes, manual: Bool) -> BackgroundWorkerControlStatus {
        guard scopes.isValid else { return .refused }
        let added = scopes.subtracting(accepted)
        let upgraded = manual ? pending.intersection(scopes).subtracting(manualPending) : []
        guard !added.isEmpty || !upgraded.isEmpty else { return .alreadyRunning }
        accepted.formUnion(added); pending.formUnion(added)
        if manual { manualPending.formUnion(pending.intersection(scopes)) }
        return .accepted
    }

    mutating func next() -> Request? {
        guard !pending.isEmpty else { return nil }
        let manual = !manualPending.isEmpty
        let scopes = manual ? manualPending : pending
        pending.subtract(scopes); manualPending.subtract(scopes)
        return Request(scopes: scopes, manual: manual)
    }
}

/// Acceptance keeps the selected buttons busy. Only the helper's drain status
/// ends that state; loss of contact is uncertainty, never a success or retry.
@MainActor
enum BackgroundPublicCompletion {
    static func status(hasObservedRequest: Bool, active: Bool, failed: Bool) -> BackgroundWorkerControlStatus {
        guard hasObservedRequest else { return .indeterminate }
        return active ? .alreadyRunning : failed ? .failed : .completed
    }

    static func wait(after acknowledgement: BackgroundWorkerControlStatus,
                     polls: Int = 300,
                     status: () async -> BackgroundWorkerControlStatus,
                     sleep: () async throws -> Void = { try await Task.sleep(for: .seconds(1)) }) async -> BackgroundWorkerControlStatus {
        guard acknowledgement == .accepted || acknowledgement == .alreadyRunning else { return acknowledgement }
        for _ in 0..<polls {
            guard !Task.isCancelled else { return .indeterminate }
            let value = await status()
            guard value == .alreadyRunning else { return value }
            do { try await sleep() } catch { return .indeterminate }
        }
        return .indeterminate
    }
}

/// A reply, transport failure and deadline may race. Resolve once, cancel the
/// deadline and release the completion independently of the XPC connection.
@MainActor
final class BackgroundControlAcknowledgement {
    private var completion: (@MainActor (BackgroundWorkerControlStatus) -> Void)?
    private var deadline: Task<Void, Never>?

    init(timeout: Duration = .seconds(5), completion: @escaping @MainActor (BackgroundWorkerControlStatus) -> Void) {
        self.completion = completion
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            self?.finish(.indeterminate)
        }
    }

    func finish(_ status: BackgroundWorkerControlStatus) {
        guard let completion else { return }
        self.completion = nil; deadline?.cancel(); deadline = nil
        completion(status)
    }
}

/// NSXPC invokes its handlers on its own queue, not on the foreground actor.
/// This value contains only a Sendable delivery closure. It is the explicit
/// nonisolated entry boundary for every Cocoa callback and always hops back to
/// the acknowledgement's MainActor before mutating connection state.
nonisolated struct BackgroundControlTransportCallbacks: Sendable {
    private let deliver: @Sendable (BackgroundWorkerControlStatus) -> Void

    @MainActor
    init(acknowledgement: BackgroundControlAcknowledgement) {
        deliver = { @Sendable status in
            Task { @MainActor in acknowledgement.finish(status) }
        }
    }

    nonisolated func invalidationHandler() -> @Sendable () -> Void {
        let deliver = deliver
        return { @Sendable in deliver(.indeterminate) }
    }

    nonisolated func errorHandler() -> @Sendable (any Error) -> Void {
        let deliver = deliver
        return { @Sendable _ in deliver(.indeterminate) }
    }

    nonisolated func replyHandler() -> @Sendable (Int) -> Void {
        let deliver = deliver
        return { @Sendable raw in
            deliver(BackgroundWorkerControlStatus(rawValue: raw) ?? .unavailable)
        }
    }
}

/// A short-lived client request. Callers must treat an invalidated connection
/// as an unknown delivery and refresh durable state later; retrying here could
/// duplicate a request whose helper acknowledgement was lost.
@MainActor
final class BackgroundWorkerControlClient {
    typealias Completion = @MainActor (BackgroundWorkerControlStatus) -> Void

    private var connections: [NSXPCConnection] = []

    /// Re-evaluate the existing wake plan after ledger-owned salary settings
    /// change. This neither enables a service nor requests a network refresh.
    func requestReschedule(enrollmentRevision: UUID, completion: @escaping Completion) {
        send({ $0.requestReschedule(enrollmentRevision: enrollmentRevision.uuidString, reply: $1) }, completion: completion)
    }

    func requestPublic(enrollmentRevision: UUID, scopes: BackgroundPublicControlScopes, manual: Bool,
                       completion: @escaping Completion) {
        guard scopes.isValid else {
            completion(.refused)
            return
        }
        send({ $0.requestPublicSources(enrollmentRevision: enrollmentRevision.uuidString,
                                       sources: scopes.rawValue, manual: manual, reply: $1) }, completion: completion)
    }

    func publicRequestStatus(enrollmentRevision: UUID, completion: @escaping Completion) {
        send({ $0.publicRequestStatus(enrollmentRevision: enrollmentRevision.uuidString, reply: $1) }, completion: completion)
    }

    private func send(_ operation: (BackgroundWorkerControlProtocol, @escaping @Sendable (Int) -> Void) -> Void,
                      completion: @escaping Completion) {
        let connection = NSXPCConnection(machServiceName: BackgroundWorkerControl.machService, options: [])
        connection.remoteObjectInterface = BackgroundWorkerControlInterface.make()
        connection.setCodeSigningRequirement(BackgroundWorkerControl.helperRequirement)
        connections.append(connection)
        let acknowledgement = BackgroundControlAcknowledgement { [weak self, weak connection] status in
            if let connection, let index = self?.connections.firstIndex(where: { $0 === connection }) {
                self?.connections.remove(at: index)
            }
            connection?.invalidate()
            completion(status)
        }
        let callbacks = BackgroundControlTransportCallbacks(acknowledgement: acknowledgement)
        connection.invalidationHandler = callbacks.invalidationHandler()
        connection.interruptionHandler = callbacks.invalidationHandler()
        connection.activate()
        let proxy = connection.remoteObjectProxyWithErrorHandler(callbacks.errorHandler()) as? BackgroundWorkerControlProtocol
        guard let proxy else {
            acknowledgement.finish(.unavailable)
            return
        }
        operation(proxy, callbacks.replyHandler())
    }
}
