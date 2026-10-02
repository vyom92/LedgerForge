import Foundation
import LocalAuthentication
import Security

nonisolated enum LedgerCredentialIdentity {
    static let statementPasswords = "com.ledgerforge.statement-password"
}

/// Security's legacy Keychain interaction flag is process-global. Every
/// Keychain operation in this process passes through this synchronous
/// coordinator, so foreground work cannot re-enable UI while scheduled work
/// has interaction disabled. The scope deliberately cannot await.
nonisolated protocol LegacyKeychainInteractionControlling: Sendable {
    func userInteractionAllowed() -> (status: OSStatus, allowed: Bool)
    func setUserInteractionAllowed(_ allowed: Bool) -> OSStatus
}

nonisolated struct SystemLegacyKeychainInteractionController: LegacyKeychainInteractionControlling {
    // Existing file-based Keychain items still need the process-wide no-UI
    // guard; a per-query LAContext does not replace that legacy guard. Keep these
    // legacy calls inside deprecated witnesses, reached only through the
    // coordinator's protocol, without suppressing other compiler warnings or
    // changing credential identities/backends.
    @available(macOS, deprecated: 10.10, message: "Legacy Keychain compatibility; use CredentialInteractionPolicy.perform(_:).")
    func userInteractionAllowed() -> (status: OSStatus, allowed: Bool) {
        var allowed = DarwinBoolean(false)
        return (SecKeychainGetUserInteractionAllowed(&allowed), allowed.boolValue)
    }

    @available(macOS, deprecated: 10.10, message: "Legacy Keychain compatibility; use CredentialInteractionPolicy.perform(_:).")
    func setUserInteractionAllowed(_ allowed: Bool) -> OSStatus {
        SecKeychainSetUserInteractionAllowed(allowed)
    }
}

nonisolated enum CredentialInteractionPolicyError: Error, Equatable {
    case legacyInteractionStateUnavailable(OSStatus)
    case legacyInteractionSuppressionFailed(OSStatus)
    case legacyInteractionRestoreFailed(OSStatus)
}

nonisolated final class CredentialInteractionCoordinator: @unchecked Sendable {
    static let shared = CredentialInteractionCoordinator(controller: SystemLegacyKeychainInteractionController())

    private let lock = NSLock()
    private let controller: any LegacyKeychainInteractionControlling

    init(controller: any LegacyKeychainInteractionControlling) {
        self.controller = controller
    }

    /// Executes one synchronous Security operation. Forbidden work restores the
    /// previous process-global UI state even if its Security call fails. A
    /// failed restore is surfaced rather than silently affecting later work.
    func perform<T>(policy: CredentialInteractionPolicy, _ operation: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }

        guard policy == .forbidden else {
            return try operation()
        }

        let previous = controller.userInteractionAllowed()
        guard previous.status == errSecSuccess else {
            throw CredentialInteractionPolicyError.legacyInteractionStateUnavailable(previous.status)
        }
        let suppression = controller.setUserInteractionAllowed(false)
        guard suppression == errSecSuccess else {
            throw CredentialInteractionPolicyError.legacyInteractionSuppressionFailed(suppression)
        }

        let result: Result<T, Error>
        do {
            result = .success(try operation())
        } catch {
            result = .failure(error)
        }

        let restoration = controller.setUserInteractionAllowed(previous.allowed)
        guard restoration == errSecSuccess else {
            throw CredentialInteractionPolicyError.legacyInteractionRestoreFailed(restoration)
        }
        return try result.get()
    }
}

/// Only an explicit foreground action may ask macOS for credential access.
/// The same policy applies to refresh-token updates as to reads.
nonisolated enum CredentialInteractionPolicy: Sendable {
    case foreground, forbidden

    /// This holds the shared process-wide coordinator only for a synchronous
    /// Security call. Do not run asynchronous work from this closure.
    func perform<T>(_ operation: () throws -> T) throws -> T {
        try CredentialInteractionCoordinator.shared.perform(policy: self, operation)
    }

    func applying(to query: [CFString: Any]) -> [CFString: Any] {
        var result = query
        if self == .forbidden {
            let context = LAContext()
            context.interactionNotAllowed = true
            result[kSecUseAuthenticationContext] = context
        }
        return result
    }

    func applying(to query: [String: Any]) -> [String: Any] {
        var result = query
        if self == .forbidden {
            let context = LAContext()
            context.interactionNotAllowed = true
            result[kSecUseAuthenticationContext as String] = context
        }
        return result
    }
}
