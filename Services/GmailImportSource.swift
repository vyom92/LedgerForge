import Foundation
import Security

/// Resolves an inbox locator into the existing immutable snapshot boundary.
/// It never prepares financial data, creates a temporary statement file, or
/// bypasses the ordinary engine's confirmation/provider/hydration checks.
@MainActor
enum GmailImportSource {
    nonisolated static let scheme = "ledgerforge-email"

    static func resolve(_ url: URL, repository: any GmailInboxRepository = DatabaseProvider.shared.gmailInboxRepo) throws -> (source: GmailInboxSource, repository: any GmailInboxRepository) {
        guard url.scheme == scheme, url.host == "inbox",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let account = components.queryItems?.first(where: { $0.name == "account" })?.value,
              url.pathComponents.count == 3 else { throw GmailIntakeError.invalidLocator }
        let id = url.pathComponents[1]
        guard let source = try repository.load(account: account).sources[id], source.importURL == url else {
            throw GmailIntakeError.invalidLocator
        }
        return (source, repository)
    }

    static func acquireSnapshot(from url: URL, repository: any GmailInboxRepository = DatabaseProvider.shared.gmailInboxRepo) throws -> SourceContentSnapshot {
        let (source, repository) = try resolve(url, repository: repository)
        guard source.acquisition == .available, let sha = source.sha256 else { throw GmailIntakeError.unavailable }
        let bytes = try repository.original(sha256: sha, byteCount: source.expectedByteCount)
        return SourceContentSnapshot(bytes: bytes)
    }

    static func additionalCASCredential(_ request: ImportRequest) async throws -> [StatementPasswordStoredCredential] {
        guard request.fileURL.scheme == scheme else { return [] }
        let (source, _) = try resolve(request.fileURL)
        guard source.family == .consolidatedFunds else { return [] }
        return try await GmailCASCredential.read()
    }
}

nonisolated enum GmailCASCredential {
    // Explicit owner choice: reuse this one existing entry in place. These
    // nomination hints permit a bounded unlock attempt, never financial identity.
    static let service = "com.ledgerforge.BackgroundProbe.Development"
    static let account = "kfintech-cas.statement-password"

    @concurrent static func read() async throws -> [StatementPasswordStoredCredential] {
        let interaction = CredentialInteractionPolicy.foreground
        let query = interaction.applying(to: [kSecClass: kSecClassGenericPassword,
            kSecAttrService: service, kSecAttrAccount: account, kSecAttrSynchronizable: false,
            kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne])
        var value: CFTypeRef?
        let status = try interaction.perform { SecItemCopyMatching(query as CFDictionary, &value) }
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = value as? Data, data.count <= 8_192,
              let password = String(data: data, encoding: .utf8), !password.isEmpty else {
            throw StatementPasswordCredentialStoreError.keychainFailure(status)
        }
        return [.init(value: password, origin: .compatibility(scope: account))]
    }
}
