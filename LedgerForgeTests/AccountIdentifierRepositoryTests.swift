// LedgerForgeTests/AccountIdentifierRepositoryTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AccountIdentifierRepositoryTests {

    @Test func attachingIdentifierIsIdempotentForSameAccount() async throws {
        try runIdentifierScenarioForEachProvider { provider in
            let fixture = try seedIdentifierWorkspace(provider)
            let identifier = accountIdentifier(
                id: "identifier-primary",
                accountId: fixture.primaryAccountId,
                workspaceId: fixture.workspaceId,
                kind: .iban,
                value: "QA12LEDGERFORGE1234567890"
            )
            let duplicate = accountIdentifier(
                id: "identifier-duplicate",
                accountId: fixture.primaryAccountId,
                workspaceId: fixture.workspaceId,
                kind: .iban,
                value: "QA12LEDGERFORGE1234567890"
            )

            #expect(try provider.accountRepo.attachIdentifier(identifier) == identifier.id)
            #expect(try provider.accountRepo.attachIdentifier(duplicate) == identifier.id)
            #expect(try provider.accountRepo.identifiers(accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId) == [identifier])
            #expect(try provider.accountRepo.accountIds(workspaceId: fixture.workspaceId, scheme: identifier.scheme, identifier: identifier.identifier) == [fixture.primaryAccountId])
        }
    }

    @Test func conflictingIdentifierOwnershipIsRejectedWithoutMutatingState() async throws {
        try runIdentifierScenarioForEachProvider { provider in
            let fixture = try seedIdentifierWorkspace(provider)
            let original = accountIdentifier(
                id: "identifier-original",
                accountId: fixture.primaryAccountId,
                workspaceId: fixture.workspaceId,
                kind: .institutionAccountId,
                value: "AXIS-ACCOUNT-001"
            )
            let conflict = accountIdentifier(
                id: "identifier-conflict",
                accountId: fixture.secondaryAccountId,
                workspaceId: fixture.workspaceId,
                kind: .institutionAccountId,
                value: "AXIS-ACCOUNT-001"
            )

            #expect(try provider.accountRepo.attachIdentifier(original) == original.id)

            do {
                _ = try provider.accountRepo.attachIdentifier(conflict)
                Issue.record("Expected conflicting account identifier assignment to fail.")
            } catch RepositoryError.conflictingAccountIdentifier(let workspaceId, let scheme, let identifier, let existingAccountId, let attemptedAccountId) {
                #expect(workspaceId == fixture.workspaceId)
                #expect(scheme == original.scheme)
                #expect(identifier == original.identifier)
                #expect(existingAccountId == fixture.primaryAccountId)
                #expect(attemptedAccountId == fixture.secondaryAccountId)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }

            #expect(try provider.accountRepo.identifiers(accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId) == [original])
            #expect(try provider.accountRepo.identifiers(accountId: fixture.secondaryAccountId, workspaceId: fixture.workspaceId).isEmpty)
        }
    }

    @Test func identifierLookupIsWorkspaceScoped() async throws {
        try runIdentifierScenarioForEachProvider { provider in
            let fixture = try seedIdentifierWorkspace(provider)
            let otherWorkspace = WorkspaceDTO(id: "workspace-other", name: "Other", createdAtISO: timestamp)
            let otherAccount = account(id: "account-other", workspaceId: otherWorkspace.id, name: "Other Account")
            let primaryIdentifier = accountIdentifier(
                id: "identifier-primary",
                accountId: fixture.primaryAccountId,
                workspaceId: fixture.workspaceId,
                kind: .brokerAccountId,
                value: "BROKER-12345"
            )
            let otherIdentifier = accountIdentifier(
                id: "identifier-other",
                accountId: otherAccount.id,
                workspaceId: otherWorkspace.id,
                kind: .brokerAccountId,
                value: "BROKER-12345"
            )

            #expect(try provider.workspaceRepo.upsertWorkspace(otherWorkspace) == otherWorkspace.id)
            #expect(try provider.accountRepo.upsertAccount(otherAccount) == otherAccount.id)
            #expect(try provider.accountRepo.attachIdentifier(primaryIdentifier) == primaryIdentifier.id)
            #expect(try provider.accountRepo.attachIdentifier(otherIdentifier) == otherIdentifier.id)

            #expect(try provider.accountRepo.accountIds(workspaceId: fixture.workspaceId, scheme: primaryIdentifier.scheme, identifier: primaryIdentifier.identifier) == [fixture.primaryAccountId])
            #expect(try provider.accountRepo.accountIds(workspaceId: otherWorkspace.id, scheme: otherIdentifier.scheme, identifier: otherIdentifier.identifier) == [otherAccount.id])
        }
    }

    @Test func listingIdentifiersIsDeterministicallyOrdered() async throws {
        try runIdentifierScenarioForEachProvider { provider in
            let fixture = try seedIdentifierWorkspace(provider)
            let suffix = accountIdentifier(
                id: "identifier-b",
                accountId: fixture.primaryAccountId,
                workspaceId: fixture.workspaceId,
                kind: .accountSuffix,
                value: "7890"
            )
            let iban = accountIdentifier(
                id: "identifier-a",
                accountId: fixture.primaryAccountId,
                workspaceId: fixture.workspaceId,
                kind: .iban,
                value: "QA12LEDGERFORGE1234567890"
            )

            #expect(try provider.accountRepo.attachIdentifier(suffix) == suffix.id)
            #expect(try provider.accountRepo.attachIdentifier(iban) == iban.id)

            #expect(try provider.accountRepo.identifiers(accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId) == [suffix, iban])
        }
    }

    @Test func sqliteDuplicateStoredMappingsAreReturnedAsAmbiguousCandidates() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForgeIdentifierDuplicateTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let sqliteProvider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("identifiers.sqlite").path)
        let provider = IdentifierRepositoryHandles(
            workspaceRepo: sqliteProvider.workspaceRepo,
            accountRepo: sqliteProvider.accountRepo
        )
        let fixture = try seedIdentifierWorkspace(provider)
        let identifier = accountIdentifier(
            id: "identifier-duplicate-source",
            accountId: fixture.primaryAccountId,
            workspaceId: fixture.workspaceId,
            kind: .iban,
            value: "QA12LEDGERFORGE1234567890"
        )

        #expect(try provider.accountRepo.attachIdentifier(identifier) == identifier.id)
        try sqliteProvider.database.executePrepared(
            sql: "INSERT INTO account_identifiers (id, account_id, scheme, identifier, provenance, created_at) VALUES (?,?,?,?,?,?);",
            params: [
                "identifier-duplicate-row",
                fixture.primaryAccountId,
                identifier.scheme,
                identifier.identifier,
                "{\"provenance\":\"administrative\",\"strength\":\"strong\",\"verificationState\":\"verified\"}",
                timestamp
            ]
        )

        #expect(try provider.accountRepo.accountIds(workspaceId: fixture.workspaceId, scheme: identifier.scheme, identifier: identifier.identifier) == [fixture.primaryAccountId, fixture.primaryAccountId])
    }
}

private struct IdentifierRepositoryHandles {
    let workspaceRepo: WorkspaceRepository
    let accountRepo: AccountRepository
}

private struct IdentifierRepositoryFixture {
    let workspaceId: String
    let primaryAccountId: String
    let secondaryAccountId: String
}

private let timestamp = "2026-07-12T12:00:00Z"

private func runIdentifierScenarioForEachProvider(_ body: (IdentifierRepositoryHandles) throws -> Void) throws {
    try body(makeIdentifierInMemoryProvider())
    try withTemporaryIdentifierSQLiteProvider(body)
}

private func makeIdentifierInMemoryProvider() -> IdentifierRepositoryHandles {
    let provider = InMemoryRepositoryProvider()
    return IdentifierRepositoryHandles(workspaceRepo: provider.workspaceRepo, accountRepo: provider.accountRepo)
}

private func withTemporaryIdentifierSQLiteProvider<T>(_ body: (IdentifierRepositoryHandles) throws -> T) throws -> T {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForgeIdentifierRepositoryTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }

    let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("identifiers.sqlite").path)
    return try body(IdentifierRepositoryHandles(workspaceRepo: provider.workspaceRepo, accountRepo: provider.accountRepo))
}

private func seedIdentifierWorkspace(_ provider: IdentifierRepositoryHandles) throws -> IdentifierRepositoryFixture {
    let workspace = WorkspaceDTO(id: "workspace-identifiers", name: "Identifier Workspace", createdAtISO: timestamp)
    let primary = account(id: "account-primary", workspaceId: workspace.id, name: "Primary Account")
    let secondary = account(id: "account-secondary", workspaceId: workspace.id, name: "Secondary Account")

    #expect(try provider.workspaceRepo.upsertWorkspace(workspace) == workspace.id)
    #expect(try provider.accountRepo.upsertAccount(primary) == primary.id)
    #expect(try provider.accountRepo.upsertAccount(secondary) == secondary.id)

    return IdentifierRepositoryFixture(
        workspaceId: workspace.id,
        primaryAccountId: primary.id,
        secondaryAccountId: secondary.id
    )
}

private func account(id: String, workspaceId: String, name: String) -> AccountDTO {
    AccountDTO(
        id: id,
        workspaceId: workspaceId,
        name: name,
        institutionId: nil,
        accountType: "bank",
        nativeCurrency: "QAR",
        description: nil,
        createdAtISO: timestamp
    )
}

private func accountIdentifier(id: String,
                               accountId: String,
                               workspaceId: String,
                               kind: FinancialIdentifierKind,
                               value: String) -> AccountIdentifierDTO {
    AccountIdentifierDTO(
        id: id,
        accountId: accountId,
        workspaceId: workspaceId,
        scheme: kind.rawValue,
        identifier: value,
        strength: kind.strength.rawValue,
        verificationState: FinancialIdentifierVerificationState.verified.rawValue,
        provenance: FinancialIdentifierProvenance.administrative.rawValue,
        createdAtISO: timestamp
    )
}
