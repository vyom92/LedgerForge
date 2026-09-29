import AppKit
import Foundation
import OSLog

/// No current-ledger lookup, migration, OAuth browser or financial Gmail import
/// exists in this executable. Only explicit existing-ledger enrollment opens it.
@main
struct LedgerForgeBackgroundWorker {
    static func main() {
        Task { @MainActor in await BackgroundWorkerRuntime.start() }
        dispatchMain()
    }
}

@MainActor
private final class BackgroundWorkerRuntime {
    private let enrollment: BackgroundEnrollment
    private let store: BackgroundEnrollmentStore
    private let provider: SQLiteRepositoryProvider
    private let executor: BackgroundUpdateExecutor
    private let configuration: BackgroundScheduleConfiguration
    private var controlListener: NSXPCListener?
    private var controlDelegate: BackgroundWorkerControlListener?
    private var publicControlActive = false
    private var publicControlFailed = false
    private var publicControlHasObservedRequest = false
    private var publicRequests = BackgroundPublicControlQueue()
    private static let log = Logger(subsystem: "com.vyom.LedgerForge.BackgroundWorker", category: "lifecycle")

    private init(enrollment: BackgroundEnrollment, store: BackgroundEnrollmentStore,
                 provider: SQLiteRepositoryProvider, configuration: BackgroundScheduleConfiguration) {
        self.enrollment = enrollment; self.store = store; self.provider = provider; self.configuration = configuration
        executor = BackgroundUpdateExecutor(provider: provider, activation: enrollment.activation, workspaceID: enrollment.workspaceID,
            enrollment: enrollment, enrollmentStore: store, origin: .helper)
    }

    static func start() async {
        do {
            let store = BackgroundEnrollmentStore()
            guard var enrollment = try store.load(), enrollment.enabled else { lf_background_cancel(); return }
            let provider = try SQLiteRepositoryProvider.openEnrolledExisting(path: enrollment.databasePath, expected: enrollment.activation)
            guard try provider.workspaceRepo.workspace(id: enrollment.workspaceID) != nil else { throw LedgerAccessError.unavailable }
            let configuration = try provider.backgroundScheduleRepo.configuration()
            guard configuration.enabled else { lf_background_cancel(); return }
            if let requested = enrollment.authorizationRequestedAt {
                enrollment = try store.consumeAuthorization(enrollment)
                // This permission belongs to a fresh explicit action while the
                // LedgerForge window is foreground. A deferred scheduled launch
                // consumes but never displays an old authorization request.
                if (0...30).contains(Date().timeIntervalSince(requested)),
                   NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.vyom.LedgerForge" {
                    await authorizeExistingConnections(configuration)
                } else { log.notice("Foreground authorization request expired; no prompt was allowed.") }
            }
            let runtime = BackgroundWorkerRuntime(enrollment: enrollment, store: store, provider: provider, configuration: configuration)
            let wake = BackgroundWakePlanStore(enrollmentStore: store)
            let existing = try wake.load(for: enrollment)
            let target: Date?
            if let existing { target = existing.target }
            else { target = try await runtime.executor.nextAutomaticTarget(configuration: configuration) }
            let start: LFBackgroundStart = { token, target in
                Task { @MainActor in await runtime.run(token: token, target: Date(timeIntervalSince1970: target)) }
            }
            if let target {
                try wake.save(target: target, enrollment: enrollment)
                lf_background_begin(target.timeIntervalSince1970, existing == nil, start)
            } else {
                // All scheduled scopes may be off while an explicit manual
                // public request remains valid. Wait only through the same
                // bounded idle exit used after CHECK_IN; this is not a daemon.
                // The copied callback also owns runtime/listener lifetime and
                // is available when a manual failure arms the first wake.
                lf_background_wait_for_control(start)
            }
            runtime.activateControlListener()
        } catch {
            log.error("Worker refused unavailable or stale enrollment; no fallback ledger was opened.")
            lf_background_cancel()
        }
    }

    private func run(token: UInt64, target: Date) async {
        do {
            try store.withValid(enrollment) {}
            await executor.runAutomatic(configuration: configuration, scheduledTarget: target)
            let next = try await executor.nextAutomaticTarget(configuration: configuration)
            if let next { try BackgroundWakePlanStore(enrollmentStore: store).save(target: next, enrollment: enrollment) }
            lf_background_finish(token, next != nil, next?.timeIntervalSince1970 ?? 0)
        } catch {
            Self.log.error("Worker publication or rearm authority was refused.")
            lf_background_finish(token, false, 0)
        }
    }

    private func activateControlListener() {
        let delegate = BackgroundWorkerControlListener(handler: { [weak self] revision, scopes, manual, reply in
            Task { @MainActor [weak self] in
                reply(self?.acceptPublicControl(revision: revision, scopes: scopes, manual: manual).rawValue
                    ?? BackgroundWorkerControlStatus.unavailable.rawValue)
            }
        }, reschedule: { [weak self] revision, reply in
            Task { @MainActor [weak self] in reply(self?.acceptReschedule(revision: revision).rawValue ?? BackgroundWorkerControlStatus.unavailable.rawValue) }
        }, status: { [weak self] revision, reply in
            Task { @MainActor [weak self] in
                guard let self, revision == self.enrollment.revision.uuidString else {
                    reply(BackgroundWorkerControlStatus.refused.rawValue); return
                }
                reply(BackgroundPublicCompletion.status(hasObservedRequest: self.publicControlHasObservedRequest,
                    active: self.publicControlActive, failed: self.publicControlFailed).rawValue)
            }
        })
        let listener = NSXPCListener(machServiceName: BackgroundWorkerControl.machService)
        listener.setConnectionCodeSigningRequirement(BackgroundWorkerControl.appRequirement)
        listener.delegate = delegate
        listener.activate()
        controlDelegate = delegate
        controlListener = listener
    }

    /// Ack only accepts work ownership; the result remains durable cache and
    /// progress state. A disconnected client never cancels this task.
    private func acceptPublicControl(revision: String, scopes: BackgroundPublicControlScopes,
                                     manual: Bool) -> BackgroundWorkerControlStatus {
        guard revision == enrollment.revision.uuidString, scopes.isValid else { return .refused }
        let status = publicRequests.enqueue(scopes: scopes, manual: manual)
        publicControlHasObservedRequest = true
        guard !publicControlActive, let request = publicRequests.next() else { return status }
        publicControlActive = true
        publicControlFailed = false
        lf_background_control_begin()
        startPublicControl(request)
        return status
    }

    private func acceptReschedule(revision: String) -> BackgroundWorkerControlStatus {
        guard revision == enrollment.revision.uuidString else { return .refused }
        guard !publicControlActive else { return .alreadyRunning }
        publicControlActive = true
        lf_background_control_begin()
        Task { @MainActor [weak self] in await self?.finishPublicControl(.notDue) }
        return .accepted
    }

    private func startPublicControl(_ request: BackgroundPublicControlQueue.Request) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            var scoped = configuration
            scoped.alDarCurrencyRatesEnabled = !request.scopes.intersection(.rates).isEmpty
            scoped.investmentPublicPricesEnabled = !request.scopes.intersection(.prices).isEmpty
            scoped.gmailCollectionEnabled = false
            scoped.zurichISPHoldingsEnabled = false
            let outcome = await executor.refreshPublic(configuration: scoped, manual: request.manual, scopes: request.scopes)
            await finishPublicControl(outcome)
        }
    }

    private func finishPublicControl(_ outcome: BackgroundUpdateExecutor.Outcome) async {
        if outcome == .alreadyRunning || outcome == .authorityRefused { publicControlFailed = true }
        if let pending = publicRequests.next() {
            startPublicControl(pending)
            return
        }
        do {
            try store.withValid(enrollment) {}
            let next = try await executor.nextAutomaticTarget(configuration: configuration)
            // Computing the target yields. A new scope accepted meanwhile
            // still belongs to this drain and keeps the process alive.
            if let pending = publicRequests.next() {
                startPublicControl(pending)
                return
            }
            if let next { try BackgroundWakePlanStore(enrollmentStore: store).save(target: next, enrollment: enrollment) }
            // A simultaneously running scheduled activity merges this
            // successor in the C bridge before it completes.
            lf_background_control_finish(next != nil, next?.timeIntervalSince1970 ?? 0)
            if case .authorityRefused = outcome { Self.log.notice("Public control authority was refused.") }
        } catch {
            publicControlFailed = true
            lf_background_control_finish(false, 0)
            Self.log.error("Public control could not rearm its durable target.")
        }
        publicControlActive = false
        publicRequests = BackgroundPublicControlQueue()
    }

    @concurrent private static func authorizeExistingConnections(_ configuration: BackgroundScheduleConfiguration) async {
        // Permission checks use the original Keychain records. No exported,
        // duplicate or widened-ACL credential is created by this action.
        if configuration.gmailCollectionEnabled {
            do {
                let store = GmailKeychainGrantStore(interaction: .foreground)
                let grant = try store.load()
                try store.updateExisting(grant)
            } catch { await log.notice("Gmail helper authorization was not completed.") }
        }
        if configuration.zurichISPHoldingsEnabled {
            do { _ = try ZurichISPCredentialStore(interaction: .foreground).load() }
            catch { await log.notice("ISP helper authorization was not completed.") }
        }
    }
}

/// The listener checks the caller requirement before this delegate receives a
/// connection. Its exported object has only primitive control fields.
nonisolated private final class BackgroundWorkerControlListener: NSObject, NSXPCListenerDelegate {
    typealias Handler = (String, BackgroundPublicControlScopes, Bool, @escaping (Int) -> Void) -> Void
    private let handler: Handler
    typealias Reschedule = (String, @escaping (Int) -> Void) -> Void
    private let reschedule: Reschedule
    private let status: Reschedule

    init(handler: @escaping Handler, reschedule: @escaping Reschedule, status: @escaping Reschedule) {
        self.handler = handler; self.reschedule = reschedule; self.status = status
    }

    nonisolated func listener(_ listener: NSXPCListener,
                              shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = BackgroundWorkerControlInterface.make()
        newConnection.exportedObject = BackgroundWorkerControlExported(handler: handler, reschedule: reschedule, status: status)
        newConnection.activate()
        return true
    }
}

nonisolated private final class BackgroundWorkerControlExported: NSObject, BackgroundWorkerControlProtocol {
    private let handler: BackgroundWorkerControlListener.Handler
    private let reschedule: BackgroundWorkerControlListener.Reschedule
    private let status: BackgroundWorkerControlListener.Reschedule
    init(handler: @escaping BackgroundWorkerControlListener.Handler,
         reschedule: @escaping BackgroundWorkerControlListener.Reschedule,
         status: @escaping BackgroundWorkerControlListener.Reschedule) {
        self.handler = handler; self.reschedule = reschedule; self.status = status
    }

    nonisolated func requestReschedule(enrollmentRevision: String, reply: @escaping (Int) -> Void) { reschedule(enrollmentRevision, reply) }

    nonisolated func publicRequestStatus(enrollmentRevision: String, reply: @escaping (Int) -> Void) { status(enrollmentRevision, reply) }

    nonisolated func requestPublic(enrollmentRevision: String, alDarRates: Bool,
                                   investmentPrices: Bool, manual: Bool,
                                   reply: @escaping (Int) -> Void) {
        handler(enrollmentRevision, .init(rates: alDarRates, prices: investmentPrices), manual, reply)
    }

    nonisolated func requestPublicSources(enrollmentRevision: String, sources: Int,
                                          manual: Bool, reply: @escaping (Int) -> Void) {
        handler(enrollmentRevision, .init(rawValue: sources), manual, reply)
    }
}
