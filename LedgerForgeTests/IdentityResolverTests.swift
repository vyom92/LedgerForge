// LedgerForgeTests/IdentityResolverTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct IdentityResolverTests {

    @Test func deterministicDecisionSortsStrongVerifiedIdentifiersBySchemeAndValue() throws {
        let zed = try financialIdentifier(kind: .institutionAccountId, value: "ZED-001")
        let alpha = try financialIdentifier(kind: .institutionAccountId, value: "ALPHA-001")
        let iban = try financialIdentifier(kind: .iban, value: "QA12LEDGERFORGE1234567890")
        let weak = try financialIdentifier(kind: .displayName, value: "Ignored")

        #expect(FinancialIdentityResolver.strongVerifiedIdentifiers(from: [zed, weak, alpha, iban]).map(\.normalizedValue) == ["QA12LEDGERFORGE1234567890", "ALPHA-001", "ZED-001"])
    }

    @Test func verifiedStrongIdentifierResolvesSingleAccount() async throws {
        let provider = InMemoryRepositoryProvider()
        let fixture = try seedResolverWorkspace(provider)
        let identifier = try financialIdentifier(kind: .iban, value: "qa12 ledger forge 1234567890")

        try attach(identifier, accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId, provider: provider)

        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: nil)
        #expect(try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [identifier]) == .resolved(accountId: fixture.primaryAccountId))
    }

    @Test func verifiedIdentifierResolvesSameAccountAfterDisplayNameChange() async throws {
        let provider = InMemoryRepositoryProvider()
        let fixture = try seedResolverWorkspace(provider)
        let identifier = try financialIdentifier(kind: .iban, value: "qa12 ledger forge 1234567890")
        try attach(identifier, accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId, provider: provider)

        #expect(try provider.accountRepo.updateAccountDisplayName(
            accountId: fixture.primaryAccountId,
            workspaceId: fixture.workspaceId,
            displayName: "Renamed Account"
        ))

        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: nil)
        #expect(try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [identifier]) == .resolved(accountId: fixture.primaryAccountId))
    }

    @Test func weakIdentifiersOnlyReturnNoMatch() async throws {
        let provider = InMemoryRepositoryProvider()
        let fixture = try seedResolverWorkspace(provider)
        let weak = try financialIdentifier(kind: .cardLastFour, value: "7890")

        try attach(weak, accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId, provider: provider)

        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: nil)
        #expect(try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [weak]) == .noMatch)
    }

    @Test func noIdentifiersReturnNoMatch() async throws {
        let provider = InMemoryRepositoryProvider()
        let fixture = try seedResolverWorkspace(provider)
        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: nil)

        #expect(try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: []) == .noMatch)
    }

    @Test func verifiedStrongMatchPlusVerifiedNoMatchStillResolves() async throws {
        let provider = InMemoryRepositoryProvider()
        let fixture = try seedResolverWorkspace(provider)
        let matching = try financialIdentifier(kind: .institutionAccountId, value: "AXIS-ACCOUNT-001")
        let nonMatching = try financialIdentifier(kind: .brokerAccountId, value: "BROKER-MISSING-002")

        try attach(matching, accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId, provider: provider)

        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: nil)
        #expect(try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [nonMatching, matching]) == .resolved(accountId: fixture.primaryAccountId))
    }

    @Test func convergingStrongIdentifiersResolveSameAccountRegardlessOfInputOrdering() async throws {
        let provider = InMemoryRepositoryProvider()
        let fixture = try seedResolverWorkspace(provider)
        let iban = try financialIdentifier(kind: .iban, value: "QA12LEDGERFORGE1234567890")
        let institutionId = try financialIdentifier(kind: .institutionAccountId, value: "AXIS-ACCOUNT-001")
        let weak = try financialIdentifier(kind: .displayName, value: "Primary Account")

        try attach(iban, accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId, provider: provider)
        try attach(institutionId, accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId, provider: provider)
        try attach(weak, accountId: fixture.secondaryAccountId, workspaceId: fixture.workspaceId, provider: provider)

        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: nil)
        let first = try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [weak, institutionId, iban])
        let second = try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [iban, weak, institutionId])

        #expect(first == .resolved(accountId: fixture.primaryAccountId))
        #expect(second == first)
    }

    @Test func conflictingStrongIdentifiersReturnConflict() async throws {
        let provider = InMemoryRepositoryProvider()
        let fixture = try seedResolverWorkspace(provider)
        let iban = try financialIdentifier(kind: .iban, value: "QA12LEDGERFORGE1234567890")
        let institutionId = try financialIdentifier(kind: .institutionAccountId, value: "AXIS-ACCOUNT-001")

        try attach(iban, accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId, provider: provider)
        try attach(institutionId, accountId: fixture.secondaryAccountId, workspaceId: fixture.workspaceId, provider: provider)

        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: nil)
        #expect(try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [institutionId, iban]) == .conflict(candidates: [fixture.primaryAccountId, fixture.secondaryAccountId]))
    }

    @Test func duplicateRepositoryCandidatesReturnAmbiguous() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForgeResolverAmbiguityTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("resolver.sqlite").path)
        let fixture = try seedResolverWorkspace(provider)
        let identifier = try financialIdentifier(kind: .iban, value: "QA12LEDGERFORGE1234567890")
        let dto = identifier.repositoryDTO(
            accountId: fixture.primaryAccountId,
            workspaceId: fixture.workspaceId,
            createdAtISO: resolverTimestamp,
            id: "resolver-identifier-original"
        )

        #expect(try provider.accountRepo.attachIdentifier(dto) == dto.id)
        try provider.database.executePrepared(
            sql: "INSERT INTO account_identifiers (id, account_id, scheme, identifier, provenance, created_at) VALUES (?,?,?,?,?,?);",
            params: [
                "resolver-identifier-duplicate",
                fixture.primaryAccountId,
                dto.scheme,
                dto.identifier,
                "{\"provenance\":\"administrative\",\"strength\":\"strong\",\"verificationState\":\"verified\"}",
                resolverTimestamp
            ]
        )

        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: nil)
        #expect(try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [identifier]) == .ambiguous(candidates: [fixture.primaryAccountId, fixture.primaryAccountId]))
    }

    @Test func unverifiedStrongIdentifierReturnsNoMatch() async throws {
        let provider = InMemoryRepositoryProvider()
        let fixture = try seedResolverWorkspace(provider)
        let identifier = try FinancialIdentifier(
            kind: .iban,
            rawValue: "QA12LEDGERFORGE1234567890",
            verificationState: .unverified,
            provenance: .parserDerivedText
        )

        try attach(identifier, accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId, provider: provider)

        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: nil)
        #expect(try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [identifier]) == .noMatch)
    }

    @Test func normalizationRejectsInvalidAndEmptyValues() async throws {
        #expect(throws: FinancialIdentifierNormalizationError.self) {
            try financialIdentifier(kind: .iban, value: "   ")
        }
        #expect(throws: FinancialIdentifierNormalizationError.self) {
            try financialIdentifier(kind: .cardLastFour, value: "78901")
        }
        #expect(try financialIdentifier(kind: .iban, value: "qa12 ledger-forge 1234").normalizedValue == "QA12LEDGERFORGE1234")
        #expect(try financialIdentifier(kind: .displayName, value: "  Primary   Account  ").normalizedValue == "primary account")
    }

    @Test func resolverDiagnosticsDoNotLogSensitiveIdentifierValues() async throws {
        let console = DeveloperConsole()
        let provider = InMemoryRepositoryProvider()
        let fixture = try seedResolverWorkspace(provider)
        let identifier = try financialIdentifier(kind: .iban, value: "QA12LEDGERFORGE1234567890")

        try attach(identifier, accountId: fixture.primaryAccountId, workspaceId: fixture.workspaceId, provider: provider)

        let resolver = FinancialIdentityResolver(accountRepository: provider.accountRepo, developerConsole: console)
        #expect(try resolver.resolve(workspaceId: fixture.workspaceId, identifiers: [identifier]) == .resolved(accountId: fixture.primaryAccountId))
        #expect(!DeveloperConsole.logText(from: console.entries).contains(identifier.normalizedValue))
    }
}

private struct ResolverFixture {
    let workspaceId: String
    let primaryAccountId: String
    let secondaryAccountId: String
}

private let resolverTimestamp = "2026-07-12T12:00:00Z"

private func seedResolverWorkspace(_ provider: InMemoryRepositoryProvider) throws -> ResolverFixture {
    try seedResolverWorkspace(
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo
    )
}

private func seedResolverWorkspace(_ provider: SQLiteRepositoryProvider) throws -> ResolverFixture {
    try seedResolverWorkspace(
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo
    )
}

private func seedResolverWorkspace(workspaceRepo: WorkspaceRepository, accountRepo: AccountRepository) throws -> ResolverFixture {
    let workspace = WorkspaceDTO(id: "workspace-resolver", name: "Resolver Workspace", createdAtISO: resolverTimestamp)
    let primary = resolverAccount(id: "account-primary", workspaceId: workspace.id, name: "Primary")
    let secondary = resolverAccount(id: "account-secondary", workspaceId: workspace.id, name: "Secondary")

    #expect(try workspaceRepo.upsertWorkspace(workspace) == workspace.id)
    #expect(try accountRepo.upsertAccount(primary) == primary.id)
    #expect(try accountRepo.upsertAccount(secondary) == secondary.id)

    return ResolverFixture(workspaceId: workspace.id, primaryAccountId: primary.id, secondaryAccountId: secondary.id)
}

private func attach(_ identifier: FinancialIdentifier,
                    accountId: String,
                    workspaceId: String,
                    provider: InMemoryRepositoryProvider) throws {
    let dto = identifier.repositoryDTO(
        accountId: accountId,
        workspaceId: workspaceId,
        createdAtISO: resolverTimestamp,
        id: "identifier-\(accountId)-\(identifier.kind.rawValue)"
    )
    _ = try provider.accountRepo.attachIdentifier(dto)
}

private func financialIdentifier(kind: FinancialIdentifierKind, value: String) throws -> FinancialIdentifier {
    try FinancialIdentifier(
        kind: kind,
        rawValue: value,
        verificationState: .verified,
        provenance: .administrative
    )
}

private func resolverAccount(id: String, workspaceId: String, name: String) -> AccountDTO {
    AccountDTO(
        id: id,
        workspaceId: workspaceId,
        name: name,
        institutionId: nil,
        accountType: "bank",
        nativeCurrency: "QAR",
        description: nil,
        createdAtISO: resolverTimestamp
    )
}
