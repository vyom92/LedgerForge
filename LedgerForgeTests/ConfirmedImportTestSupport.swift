// Shared plan support for confirmed-import mechanics and explicit source integration.

import Foundation
@testable import LedgerForge

/// Uses a small deterministic source through the real preparation and mapper.
/// The separate authentic entry point is reserved for source-oracle integration.
@MainActor
func confirmedImportPlan(
    generationToken: ProviderGenerationToken,
    alternatePeriod: Bool = false,
    accountChoice: ConfirmedImportAccountChoiceDTO = .createProposedAccount,
    selectedAccountID: String? = nil
) async throws -> ConfirmedImportPlanDTO {
    try await mappedImportPlan(
        source: MechanicsTestSupport.axisBankCSV(alternatePeriod: alternatePeriod),
        generationToken: generationToken, accountChoice: accountChoice, selectedAccountID: selectedAccountID
    )
}

@MainActor
func authenticConfirmedImportPlan(generationToken: ProviderGenerationToken) async throws -> ConfirmedImportPlanDTO {
    try await mappedImportPlan(source: AuthenticSourceTestSupport.axisBankCSV(),
        generationToken: generationToken, accountChoice: .createProposedAccount, selectedAccountID: nil)
}

@MainActor
private func mappedImportPlan(
    source: URL, generationToken: ProviderGenerationToken,
    accountChoice: ConfirmedImportAccountChoiceDTO, selectedAccountID: String?
) async throws -> ConfirmedImportPlanDTO {
    let preparationProvider = DatabaseProvider(inMemory: true)
    let engine = ImportEngine(
        importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: preparationProvider),
        persistenceStateProvider: { preparationProvider.persistenceState },
        providerGenerationProvider: { generationToken }
    )
    let prepared = try await engine.prepareImport(
        from: source
    )
    defer { engine.cancelPreparedImport(prepared) }
    let accountID = selectedAccountID
        ?? "account-\(prepared.importSession.id.uuidString.lowercased())"
    return try ImportPersistenceMapper().confirmedImportPlan(
        financialDocument: prepared.financialDocument,
        importSession: prepared.importSession,
        validation: prepared.validation,
        fingerprintSet: prepared.fingerprintSet,
        providerGeneration: generationToken,
        advisoryIdentity: .noMatch,
        accountChoice: accountChoice,
        selectedAccountId: accountID
    )
}
