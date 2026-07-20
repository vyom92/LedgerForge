import Foundation

enum MigrationPreflightError: Error, Equatable, LocalizedError {
    case failed(issueCode: String)
    var errorDescription: String? { "Migration compatibility preflight failed." }
}

private func ownershipAudit(_ issueCode: String, _ sql: String) -> MigrationPreflightCheck {
    MigrationPreflightCheck(issueCode: issueCode) { database in
        try database.queryInt(sql) == 0
    }
}

let migrationV5 = Migration(
    version: 5,
    name: "identifier_ownership_and_observations",
    sql: """
CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_id_workspace ON accounts(id, workspace_id);
ALTER TABLE account_identifiers RENAME TO account_identifiers_v4;
CREATE TABLE account_identifiers (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  workspace_id TEXT NOT NULL,
  scheme TEXT NOT NULL,
  identifier TEXT NOT NULL,
  provenance TEXT,
  created_at DATETIME NOT NULL,
  UNIQUE(workspace_id, scheme, identifier),
  UNIQUE(account_id, scheme, identifier),
  FOREIGN KEY(account_id, workspace_id) REFERENCES accounts(id, workspace_id) ON DELETE CASCADE
);
INSERT INTO account_identifiers (id, account_id, workspace_id, scheme, identifier, provenance, created_at)
SELECT ai.id, ai.account_id, a.workspace_id, ai.scheme, ai.identifier, ai.provenance, ai.created_at
FROM account_identifiers_v4 ai JOIN accounts a ON a.id = ai.account_id;
DROP TABLE account_identifiers_v4;
CREATE INDEX idx_account_identifiers_scheme ON account_identifiers(workspace_id, scheme, identifier);
CREATE TABLE account_identifier_observations (
  id TEXT PRIMARY KEY,
  ownership_id TEXT NOT NULL,
  import_session_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  parser_provenance_code TEXT NOT NULL,
  association_authority_code TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  UNIQUE(ownership_id, import_session_id, document_id),
  FOREIGN KEY(ownership_id) REFERENCES account_identifiers(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT
);
CREATE INDEX idx_identifier_observations_session ON account_identifier_observations(import_session_id, document_id);
""",
    preflightChecks: [
        ownershipAudit("identifier-missing-account", "SELECT COUNT(*) FROM account_identifiers ai LEFT JOIN accounts a ON a.id = ai.account_id WHERE a.id IS NULL;"),
        ownershipAudit("account-missing-workspace", "SELECT COUNT(*) FROM accounts a LEFT JOIN workspaces w ON w.id = a.workspace_id WHERE w.id IS NULL;"),
        ownershipAudit("duplicate-ownership", "SELECT COUNT(*) FROM (SELECT a.workspace_id, ai.scheme, ai.identifier FROM account_identifiers ai JOIN accounts a ON a.id = ai.account_id GROUP BY a.workspace_id, ai.scheme, ai.identifier HAVING COUNT(*) > 1);"),
        ownershipAudit("empty-identifier-fields", "SELECT COUNT(*) FROM account_identifiers WHERE TRIM(account_id) = '' OR TRIM(scheme) = '' OR TRIM(identifier) = '';"),
        ownershipAudit("empty-account-workspace", "SELECT COUNT(*) FROM accounts WHERE TRIM(workspace_id) = '';"),
    ]
)

func validateIdentifierOwnershipV5Schema(_ database: SQLiteDatabase) throws {
    let columns = try database.query(sql: "PRAGMA table_info(account_identifiers);") { $0.string(at: 1) ?? "" }
    guard Set(["id", "account_id", "workspace_id", "scheme", "identifier", "provenance", "created_at"]).isSubset(of: Set(columns)) else {
        throw MigrationPreflightError.failed(issueCode: "v5-schema-columns")
    }
    let observationColumns = try database.query(sql: "PRAGMA table_info(account_identifier_observations);") { $0.string(at: 1) ?? "" }
    guard Set(["ownership_id", "import_session_id", "document_id", "parser_provenance_code", "association_authority_code", "created_at"]).isSubset(of: Set(observationColumns)) else {
        throw MigrationPreflightError.failed(issueCode: "v5-observation-schema")
    }
    let foreignKeys = try database.query(sql: "PRAGMA foreign_key_list(account_identifiers);") { $0.string(at: 3) ?? "" }
    guard foreignKeys.contains("account_id"), foreignKeys.contains("workspace_id") else {
        throw MigrationPreflightError.failed(issueCode: "v5-ownership-foreign-key")
    }
}
