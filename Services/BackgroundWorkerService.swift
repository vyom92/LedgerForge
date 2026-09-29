import Foundation
import ServiceManagement

/// The foreground-only lifecycle surface. It never registers on construction
/// or when configuration changes; Settings must invoke an explicit operation.
@MainActor
final class BackgroundWorkerService {
    static let plistName = "com.vyom.LedgerForge.BackgroundWorker.plist"

    enum Status: Equatable {
        case notRegistered
        case enabled
        case requiresApproval
        case unavailable
    }

    private let service = SMAppService.agent(plistName: BackgroundWorkerService.plistName)

    func status() -> Status {
        switch service.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    /// Explicit user action only. The scheduled helper itself always uses
    /// prompt-free credential policies; this method contains no authorization.
    func registerFromForegroundAction() throws { try service.register() }

    func unregisterFromForegroundAction() async throws { try await service.unregister() }

    /// Schedule or bundled-binary changes use the ServiceManagement completion
    /// boundary: registration happens only after the old agent is no longer
    /// running. Call this solely from an explicit foreground Settings action.
    func refreshFromForegroundScheduleAction() async throws {
        if service.status == .enabled || service.status == .requiresApproval { try await service.unregister() }
        try service.register()
    }
}
