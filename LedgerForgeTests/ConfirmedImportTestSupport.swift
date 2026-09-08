// Shared authentic-source plan support for confirmed-import contract tests.

import Foundation
@testable import LedgerForge

/// Produces a repository plan exclusively from an unchanged registered
/// authentic source through ordinary preparation and the production mapper.
/// This helper does not author or mutate source bytes, financial facts,
/// identifiers, transactions, provenance, or statement controls.
@MainActor
func confirmedImportPlan(
    generationToken: ProviderGenerationToken,
    alternatePeriod: Bool = false,
    accountChoice: ConfirmedImportAccountChoiceDTO = .createProposedAccount,
    selectedAccountID: String? = nil
) async throws -> ConfirmedImportPlanDTO {
    let preparationProvider = DatabaseProvider(inMemory: true)
    let engine = ImportEngine(
        importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: preparationProvider),
        persistenceStateProvider: { preparationProvider.persistenceState },
        providerGenerationProvider: { generationToken }
    )
    let prepared = try await engine.prepareImport(
        from: AuthenticSourceTestSupport.axisBankCSV(alternatePeriod: alternatePeriod)
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
