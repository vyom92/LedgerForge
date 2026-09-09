import Combine
import CryptoKit
import Foundation

/// Facts embedded in the product by Xcode, never obtained from the live checkout.
struct BuildIdentity: Codable, Equatable {
    let revision: String
    let worktree: String
    let builtAt: String
    let configuration: String

    static let unavailable = BuildIdentity(revision: "unavailable", worktree: "unknown", builtAt: "not captured", configuration: "unknown")
    static func read(bundle: Bundle = .main) -> BuildIdentity {
        guard let url = bundle.url(forResource: "LedgerForgeBuildIdentity", withExtension: "json"),
              let data = try? Data(contentsOf: url), data.count < 2048,
              let value = try? JSONDecoder().decode(Self.self, from: data),
              value.revision.range(of: "^[a-f0-9]{40}$", options: .regularExpression) != nil,
              ["clean", "dirty"].contains(value.worktree),
              ["Debug", "Release"].contains(value.configuration),
              ISO8601DateFormatter().date(from: value.builtAt) != nil else { return .unavailable }
        return value
    }
    var label: String { "\(revision) (\(worktree), \(configuration), \(builtAt))" }
}

enum DiagnosticPrivacy {
    static let maximumMessageLength = 480
    static let maximumValueLength = 240
    static let maximumFields = 24
    static let allowedKeys: Set<String> = [
        "code", "operation", "stage", "root_reference", "related_root_reference", "effect", "retry_eligible", "next_action",
        "reason", "family", "outcome", "result", "migration_version", "expected_name", "observed_name", "observed_name_sha256",
        "expected_checksum", "observed_checksum", "requested_target", "requested_profile", "remembered_profile", "active_profile",
        "build_identity", "provider_kind", "error_type", "cause", "sqlite_primary", "sqlite_extended",
        "sqlite_operation", "hydration_domain", "hydration_stage", "accountCount", "transactionCount", "count", "profile", "sourceVersion",
        "schemaVersion", "transactions", "candidates", "eligibleAccounts", "rows", "columns", "headerRow", "firstTransactionRow", "passed", "selection", "scheme", "identifier", "phase", "duration_ms", "acceptedCount", "rejectedCount", "attemptCount"
    ]

    /// Reject suspicious free text rather than attempting to reconstruct secrets after redaction.
    static func text(_ value: String, limit: Int = maximumMessageLength) -> String {
        guard value.utf8.count <= limit * 4,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || CharacterSet(charactersIn: "\u{2028}\u{2029}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}").contains($0) }) else {
            return "Details withheld (unsafe text)"
        }
        let lower = value.lowercased()
        let prohibited = ["/users/", "/private/", "/tmp/", "/var/", "file://", "https://", "http://", "bearer ", "password=", "password:", "token=", "token:", "secret=", ".pdf", ".xlsx", ".csv", "select ", "insert into", "update schema", "delete from"]
        guard !prohibited.contains(where: lower.contains),
              value.range(of: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}|[0-9]{10,}", options: [.regularExpression, .caseInsensitive]) == nil else {
            return "Details withheld (private text)"
        }
        return String(value.prefix(limit))
    }

    private static let closedValues: [String: Set<String>] = [
        "scheme": ["Recognized", "Unknown"],
        "selection": ["Recognized", "Unavailable"],
        "operation": ["startup", "startup hydration", "canonical reload", "plan save", "developer forced refresh"],
        "stage": ["provider initialization", "provider availability", "snapshot validation", "repository transaction", "post-commit canonical reload", "migration verification", "provider activation", "Preparation"],
        "effect": ["durable outcome not established", "canonical data not loaded", "runtime stores not replaced", "plan committed; runtime data not current", "committed and canonical data current"],
        "next_action": ["Open Diagnostics to review the failed operation before retrying.", "Restarting does not repair migration history. Keep the database for an explicit recovery decision.", "Use a build that supports this database version. Restarting this older build cannot make it compatible.", "Reload the current database before making another change.", "Reload canonical data. Retained values are not current until reload succeeds.", "Wait for the active database operation to finish, then retry only the failed operation.", "Quit and reopen the app to establish canonical data before deciding whether to save again."],
        "error_type": ["unknown", "MigrationIntegrityError", "SQLiteRepositoryProviderError", "RepositoryError", "RepositoryStoreHydrationError", "SQLiteExecutionError"],
        "cause": ["MigrationIntegrityError", "SQLiteExecutionError"],
        "requested_target": ["Test session", "Debug memory session", "Isolated development database", "Current Database", "Personal database"],
        "provider_kind": ["verified SQLite"], "active_profile": ["not established"],
        "sqlite_operation": ["open", "transaction", "statement", "query", "migration", "backup", "checkpoint", "close"],
        "hydration_domain": ["provider", "categories", "cards", "salary", "funding_plan", "transactions"],
        "hydration_stage": ["provider availability", "snapshot validation"]
    ]

    static func metadata(_ values: [String: String]?) -> [String: String]? {
        guard let values else { return nil }
        var result: [String: String] = [:]
        for key in values.keys.filter({ allowedKeys.contains($0) }).sorted().prefix(maximumFields) {
            guard let value = values[key], !value.isEmpty else { continue }
            if let allowed = closedValues[key] {
                result[key] = allowed.contains(value) ? value : "not captured"
            } else if key == "expected_name" || key == "observed_name" {
                result[key] = allMigrations.contains(where: { $0.name == value }) || ["unrecognized name", "unrecognized name (fingerprint provided)"].contains(value) ? value : "not captured"
            } else if key == "code" {
                result[key] = value.range(of: "^[a-z][a-z0-9_]*(?:[.][a-z0-9_]+)+\\z", options: .regularExpression) != nil && value.count <= 80 ? value : "not captured"
            } else if key == "root_reference" || key == "related_root_reference" {
                result[key] = UUID(uuidString: value)?.uuidString.lowercased() ?? "not captured"
            } else if key.lowercased().hasSuffix("count") || ["migration_version", "sourceVersion", "schemaVersion", "duration_ms", "sqlite_primary", "sqlite_extended", "transactions", "candidates", "eligibleAccounts", "rows", "columns", "headerRow", "firstTransactionRow"].contains(key) {
                result[key] = value.range(of: "^[0-9]{1,9}$", options: .regularExpression) != nil ? value : "not captured"
            } else if ["retry_eligible", "passed"].contains(key) {
                result[key] = ["true", "false"].contains(value) ? value : "not captured"
            } else if key == "identifier" {
                result[key] = "[redacted]"
            } else if key.contains("checksum") || key.hasSuffix("sha256") {
                result[key] = value.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil ? value : "not captured"
            } else if key == "build_identity" {
                // Generated/validated product identity contains long hexadecimal values.
                result[key] = value.range(of: "^[a-zA-Z0-9 (),:TZ+.\\-]{1,180}$", options: .regularExpression) != nil ? value : "not captured"
            } else {
                result[key] = text(value, limit: maximumValueLength)
            }
        }
        return result.isEmpty ? nil : result
    }
}

enum RuntimeDiagnostic {
    static func logicalTarget(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
#if DEBUG
        if environment["LEDGERFORGE_TEST_HOST"] == "1" { return "Test session" }
        if environment["LEDGERFORGE_RUN_HOST"] == "1" { return "Debug memory session" }
        if environment["LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE"] != nil { return "Isolated development database" }
        return "Current Database"
#else
        return "Personal database"
#endif
    }

    static func failure(_ error: Error, operation: String, stage: String, effect: String = "durable outcome not established", relatedRoot: PersistenceFailureContext? = nil) -> PersistenceFailureContext {
        let reference = UUID().uuidString.lowercased()
        var code = "operation.unknown"
        var summary = "The operation could not be completed"
        var action = "Open Diagnostics to review the failed operation before retrying."
        var details: [String: String] = ["operation": operation, "stage": stage, "effect": effect,
            "root_reference": reference, "retry_eligible": "false", "error_type": "unknown",
            "requested_target": logicalTarget(), "build_identity": BuildIdentity.read().label]
        if let relatedRoot { details["related_root_reference"] = relatedRoot.reference }
        var integrity = error as? MigrationIntegrityError
        if case SQLiteRepositoryProviderError.migrationIntegrityFailed(let cause) = error {
            integrity = cause
            details["cause"] = "MigrationIntegrityError"
            details["error_type"] = "SQLiteRepositoryProviderError"
        }
        if let integrity {
            details["stage"] = "migration verification"
            details["active_profile"] = "not established"
            action = "Restarting does not repair migration history. Keep the database for an explicit recovery decision."
            if details["error_type"] == "unknown" { details["error_type"] = "MigrationIntegrityError" }
            func version(_ value: Int?) { if let value { details["migration_version"] = String(value) } }
            switch integrity {
            case .emptyRegisteredChain: code = "migration.registered_empty"; summary = "This build has no registered migrations"
            case .duplicateRegisteredVersion(let v): code = "migration.registered_duplicate"; summary = "This build registers a migration version twice"; version(v)
            case .registeredOrderInvalid: code = "migration.registered_order"; summary = "This build has an unordered migration chain"
            case .missingRegisteredVersion(let v): code = "migration.registered_missing"; summary = "This build is missing a migration version"; version(v)
            case .duplicatePersistedVersion(let v): code = "migration.persisted_duplicate"; summary = "Database history contains a duplicate migration version"; version(v)
            case .missingPersistedVersion(let v): code = "migration.persisted_missing"; summary = "Database history is missing a migration version"; version(v)
            case .persistedRecordIncomplete(let v): code = "migration.persisted_incomplete"; summary = "Database history contains an incomplete migration record"; version(v)
            case .persistedNameMismatch(let v, let expected, let observed):
                code = "migration.persisted_name_mismatch"; summary = "Stored migration name differs from this build"; version(v)
                details["expected_name"] = allMigrations.contains(where: { $0.name == expected }) ? expected : "unrecognized name"
                details["observed_name"] = allMigrations.contains(where: { $0.name == observed }) ? observed : "unrecognized name (fingerprint provided)"
                if !observed.isEmpty { details["observed_name_sha256"] = SHA256.hash(data: Data(observed.utf8)).map { String(format: "%02x", $0) }.joined() }
            case .persistedChecksumMismatch(let v, let expected, let observed):
                code = "migration.persisted_checksum_mismatch"; summary = "Stored migration checksum differs from this build"; version(v)
                details["expected_checksum"] = expected; details["observed_checksum"] = observed
            case .unsupportedFutureVersion(let v):
                code = "migration.unsupported_future_version"; summary = "This database requires a newer build"; version(v)
                action = "Use a build that supports this database version. Restarting this older build cannot make it compatible."
            }
        } else {
            switch error {
            case SQLiteRepositoryProviderError.databaseOpenFailed:
                code = "persistence.open_failed"; summary = "The database could not be opened"; details["error_type"] = "SQLiteRepositoryProviderError"
            case SQLiteRepositoryProviderError.databaseInitializationFailed:
                code = "persistence.initialization_failed"; summary = "Database initialization did not complete"; details["error_type"] = "SQLiteRepositoryProviderError"
            case SQLiteRepositoryProviderError.migrationFailed:
                code = "migration.execution_failed"; summary = "A database migration could not complete"; details["error_type"] = "SQLiteRepositoryProviderError"
            case RepositoryError.relationshipViolation:
                code = "repository.relationship_invalid"; summary = "The plan or record references an invalid relationship"; details["error_type"] = "RepositoryError"
            case RepositoryError.persistenceUnavailable, RepositoryError.providerNotConfigured:
                code = "repository.provider_unavailable"; summary = "The operation is blocked by unavailable persistence"; details["error_type"] = "RepositoryError"
            case RepositoryError.staleProviderGeneration:
                code = "provider.generation_changed"; summary = "The active database changed"; action = "Reload the current database before making another change."; details["error_type"] = "RepositoryError"
            case is RepositoryStoreHydrationError:
                code = "hydration.validation_failed"; summary = "Canonical data could not be loaded"; details["error_type"] = "RepositoryStoreHydrationError"
                action = "Reload canonical data. Retained values are not current until reload succeeds."
            case SQLiteDatabaseError.execution(let cause):
                code = "sqlite.\(cause.operation.rawValue)_failed"; summary = "A database operation failed"; details["error_type"] = "SQLiteExecutionError"
                details["sqlite_primary"] = String(cause.primaryCode); details["sqlite_extended"] = String(cause.extendedCode)
                details["sqlite_operation"] = cause.operation.rawValue
                details["retry_eligible"] = cause.isRetryableContention ? "true" : "false"
                if cause.isRetryableContention { action = "Wait for the active database operation to finish, then retry only the failed operation." }
            default: break
            }
        }
        var sqliteCause: SQLiteExecutionError?
        switch error {
        case SQLiteRepositoryProviderError.databaseOpenFailed(let cause), SQLiteRepositoryProviderError.databaseInitializationFailed(let cause), SQLiteRepositoryProviderError.migrationFailed(let cause): sqliteCause = cause
        default: break
        }
        if let cause = sqliteCause {
            details["sqlite_primary"] = String(cause.primaryCode); details["sqlite_extended"] = String(cause.extendedCode)
            details["sqlite_operation"] = cause.operation.rawValue
            details["retry_eligible"] = cause.isRetryableContention ? "true" : "false"
            details["cause"] = "SQLiteExecutionError"
        }
        if let hydration = error as? RepositoryStoreHydrationError {
            let domain: String
            switch hydration {
            case .persistenceUnavailable: domain = "provider"
            case .invalidCategoryState: domain = "categories"
            case .invalidCardState: domain = "cards"
            case .invalidSalaryState: domain = "salary"
            case .invalidFundingPlanState: domain = "funding_plan"
            default: domain = "transactions"
            }
            code = "hydration." + domain + "_invalid"
            details["hydration_domain"] = domain; details["hydration_stage"] = "snapshot validation"
            if hydration == .persistenceUnavailable {
                code = "hydration.provider_unavailable"
                details["stage"] = "provider availability"; details["hydration_stage"] = "provider availability"
                action = relatedRoot?.nextAction ?? "Open Diagnostics to review the failed operation before retrying."
                summary = relatedRoot == nil ? "Canonical data is blocked by unavailable persistence" : "Hydration is blocked by the persistence failure referenced in Details"
            }
        }
        if operation == "plan save", effect == "durable outcome not established" { action = "Quit and reopen the app to establish canonical data before deciding whether to save again."; details["retry_eligible"] = "false" }
        details["code"] = code; details["next_action"] = action
        return PersistenceFailureContext(reference: reference, code: code, summary: summary, nextAction: action, metadata: DiagnosticPrivacy.metadata(details) ?? [:])
    }

    static func record(_ failure: PersistenceFailureContext, category: DeveloperLogCategory) {
        DeveloperConsole.shared.error(category, failure.summary, metadata: failure.metadata)
    }
}

enum ApplicationDataState: Equatable {
    case loading, empty, current, unavailable, retainedNonCurrent
    var permitsMutation: Bool { self == .empty || self == .current }
}

/// Presentation authority follows complete canonical publication; it never loads repositories.
@MainActor
final class ApplicationAvailability: ObservableObject {
    static let shared = ApplicationAvailability()
    @Published private(set) var state: ApplicationDataState = .loading
    @Published private(set) var failure: PersistenceFailureContext?
    private(set) var generation: ProviderGenerationToken?

    func begin() { state = .loading; failure = nil; generation = nil }
    func didHydrate(_ result: RepositoryStoreHydrationResult, generation: ProviderGenerationToken) {
        self.generation = generation
        failure = nil
        state = result.accountCount == 0 && result.transactionCount == 0 && result.salaryStatementCount == 0 && result.fundingPlanCount == 0 && result.importSessionCount == 0 ? .empty : .current
    }
    func didFail(_ failure: PersistenceFailureContext, generation: ProviderGenerationToken?) {
        let retained = self.generation != nil && self.generation == generation
        self.failure = failure
        state = retained ? .retainedNonCurrent : .unavailable
    }
    var permitsMutation: Bool { state.permitsMutation && DatabaseProvider.shared.persistenceState.isUsable && generation == DatabaseProvider.shared.generationToken }
}
