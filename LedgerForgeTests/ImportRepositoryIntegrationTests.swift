// LedgerForgeTests/ImportRepositoryIntegrationTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ImportRepositoryIntegrationTests {

    @Test func validImportPersistsValidatedRepositoryRecords() async throws {
        try runForEachProvider { provider in
            let fixture = makeValidFixture()
            let coordinator = DefaultImportPersistenceCoordinator(
                workspaceRepo: provider.workspaceRepo,
                accountRepo: provider.accountRepo,
                importSessionRepo: provider.importSessionRepo,
                transactionRepo: provider.transactionRepo,
                mapper: ImportPersistenceMapper(
                    workspaceId: "workspace-import-integration",
                    workspaceName: "Import Integration Workspace"
                )
            )

            let result = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                fingerprint: fixture.fingerprint,
                accountChoice: .createNewAccount
            )

            #expect(result.persisted)
            #expect(result.workspaceId == "workspace-import-integration")
            #expect(result.importSessionId == fixture.importSession.id.uuidString)
            #expect(result.transactionCount == fixture.financialDocument.transactions.count)

            let storedWorkspace = try provider.workspaceRepo.workspace(id: "workspace-import-integration")
            let workspace = try #require(storedWorkspace)
            #expect(workspace.name == "Import Integration Workspace")

            let accountId = try #require(result.accountId)
            let storedAccount = try provider.accountRepo.account(id: accountId)
            let account = try #require(storedAccount)
            #expect(account.workspaceId == "workspace-import-integration")
            #expect(account.institutionId == "Axis Bank")
            #expect(account.accountType == "bank")
            #expect(account.nativeCurrency == "INR")

            let storedImportSession = try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString)
            let importSession = try #require(storedImportSession)
            #expect(importSession.workspaceId == "workspace-import-integration")
            #expect(importSession.userVisibleName == fixture.importSession.fileName)
            #expect(importSession.validationStatus == "passed")
            #expect(importSession.completedAtISO != nil)
            #expect(importSession.parserVersion == fixture.importSession.parserName)

            let transactions = try provider.transactionRepo.transactions(
                workspaceId: "workspace-import-integration",
                importSessionId: fixture.importSession.id.uuidString
            )
            #expect(transactions.count == 2)
            #expect(transactions.allSatisfy { $0.isTrusted })
            #expect(transactions.allSatisfy { $0.trustedAtISO != nil })
            #expect(transactions.allSatisfy { $0.workspaceId == "workspace-import-integration" })
            #expect(transactions.allSatisfy { $0.accountId == result.accountId })
            #expect(transactions.allSatisfy { $0.importSessionId == fixture.importSession.id.uuidString })
            #expect(transactions.allSatisfy { $0.documentId != nil })

            let orderedTransactions = transactions.sorted {
                if $0.postedDateISO == $1.postedDateISO {
                    return $0.id < $1.id
                }
                return $0.postedDateISO < $1.postedDateISO
            }

            #expect(orderedTransactions.map(\.amountMinor) == [10_000, -5_000])
            #expect(orderedTransactions.map(\.amountDecimal) == ["100", "-50"])
            #expect(orderedTransactions.map(\.direction) == ["credit", "debit"])
            #expect(orderedTransactions.map(\.runningBalanceMinor) == [110_000, 105_000])
        }
    }

    @Test func firstVerifiedImportCreatesOpaqueAccountAndSeedsIdentifier() async throws {
        try runForEachProvider { provider in
            let identifier = try makeVerifiedAccountIdentifier("001234567890123")
            let fixture = makeValidFixture(
                fileName: "axis-first-verified-import.csv",
                financialIdentifiers: [identifier]
            )
            let coordinator = makePersistenceCoordinator(provider: provider)

            let result = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                fingerprint: fixture.fingerprint,
                accountChoice: .createNewAccount
            )

            let accountId = try #require(result.accountId)
            let storedAccountValue = try provider.accountRepo.account(id: accountId)
            let storedAccount = try #require(storedAccountValue)
            let storedIdentifiers = try provider.accountRepo.identifiers(
                accountId: accountId,
                workspaceId: "workspace-import-integration"
            )
            let transactions = try provider.transactionRepo.transactions(
                workspaceId: "workspace-import-integration",
                importSessionId: fixture.importSession.id.uuidString
            )
            let storedImportSessionValue = try provider.importSessionRepo.importSession(
                id: fixture.importSession.id.uuidString
            )
            let storedImportSession = try #require(storedImportSessionValue)

            #expect(result.persisted)
            #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").count == 1)
            #expect(accountId == "account-\(fixture.importSession.id.uuidString.lowercased())")
            #expect(!accountId.localizedCaseInsensitiveContains(fixture.importSession.fileName))
            #expect(!accountId.localizedCaseInsensitiveContains("Axis Bank"))
            #expect(!accountId.localizedCaseInsensitiveContains(storedAccount.name))
            #expect(storedIdentifiers.count == 1)
            #expect(storedIdentifiers.first?.scheme == identifier.kind.rawValue)
            #expect(storedIdentifiers.first?.identifier == identifier.normalizedValue)
            #expect(storedIdentifiers.first?.strength == identifier.strength.rawValue)
            #expect(storedIdentifiers.first?.verificationState == identifier.verificationState.rawValue)
            #expect(storedIdentifiers.first?.provenance == identifier.provenance.rawValue)
            #expect(transactions.allSatisfy { $0.accountId == accountId })
            #expect(storedImportSession.workspaceId == "workspace-import-integration")
        }
    }

    @Test func failedValidationDoesNotPersistTrustedTransactionsOrTrustedImport() async throws {
        try runForEachProvider { provider in
            let fixture = makeFailedValidationFixture()
            let observedAccountRepo = ObservingAccountRepository(base: provider.accountRepo)
            let coordinator = DefaultImportPersistenceCoordinator(
                workspaceRepo: provider.workspaceRepo,
                accountRepo: observedAccountRepo,
                importSessionRepo: provider.importSessionRepo,
                transactionRepo: provider.transactionRepo,
                mapper: ImportPersistenceMapper(
                    workspaceId: "workspace-failed-import",
                    workspaceName: "Failed Import Workspace"
                )
            )

            let result = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                fingerprint: fixture.fingerprint
            )

            #expect(!result.persisted)
            #expect(result.workspaceId == nil)
            #expect(result.importSessionId == nil)
            #expect(result.transactionCount == 0)
            #expect(observedAccountRepo.accountIdsCallCount == 0)
            #expect(observedAccountRepo.upsertCallCount == 0)
            #expect(observedAccountRepo.attachCallCount == 0)
            #expect(try provider.workspaceRepo.workspace(id: "workspace-failed-import") == nil)
            #expect(try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString) == nil)
            #expect(try provider.transactionRepo.transactions(workspaceId: "workspace-failed-import", importSessionId: fixture.importSession.id.uuidString).isEmpty)
            #expect(try provider.importSessionRepo.priorImportedStatement(
                algorithm: fixture.fingerprint.algorithm,
                fingerprint: fixture.fingerprint.digest
            ) == nil)
        }
    }

    @Test func missingIdentifiersCreateUnseededOpaqueAccountWithoutMetadataIdentity() async throws {
        try runForEachProvider { provider in
            let fixture = makeValidFixture(fileName: "axis-missing-identifier.csv")
            let result = try makePersistenceCoordinator(provider: provider).persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                fingerprint: fixture.fingerprint
            )

            let accountId = try #require(result.accountId)
            #expect(result.persisted)
            #expect(accountId == "account-\(fixture.importSession.id.uuidString.lowercased())")
            #expect(!accountId.localizedCaseInsensitiveContains("axis"))
            #expect(!accountId.localizedCaseInsensitiveContains("missing"))
            #expect(try provider.accountRepo.identifiers(
                accountId: accountId,
                workspaceId: "workspace-import-integration"
            ).isEmpty)
        }
    }

    @Test func weakAndUnverifiedIdentifiersNeitherResolveNorAttach() async throws {
        try runForEachProvider { provider in
            let weak = try FinancialIdentifier(
                kind: .accountSuffix,
                rawValue: "0123",
                verificationState: .verified,
                provenance: .parserDerivedText
            )
            let unverifiedStrong = try FinancialIdentifier(
                kind: .institutionAccountId,
                rawValue: "001234567890123",
                verificationState: .unverified,
                provenance: .institutionStructuredField
            )
            let fixture = makeValidFixture(
                financialIdentifiers: [weak, unverifiedStrong]
            )

            let result = try makePersistenceCoordinator(provider: provider).persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                fingerprint: fixture.fingerprint
            )

            let accountId = try #require(result.accountId)
            #expect(result.persisted)
            #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").count == 1)
            #expect(try provider.accountRepo.identifiers(
                accountId: accountId,
                workspaceId: "workspace-import-integration"
            ).isEmpty)
        }
    }

    @Test func explicitExistingAccountChoiceAttachesIdentifierWithoutReplacingAccount() async throws {
        let provider = makeInMemoryProvider()
        let workspace = WorkspaceDTO(
            id: "workspace-import-integration",
            name: "Existing Workspace",
            createdAtISO: "2026-07-13T00:00:00Z"
        )
        let existingAccount = AccountDTO(
            id: "account-unseeded",
            workspaceId: workspace.id,
            name: "Verification Account",
            institutionId: "Independent Credit Union",
            accountType: "cash",
            nativeCurrency: "INR",
            description: "Unseeded account with unrelated presentation metadata",
            createdAtISO: "2026-07-13T00:00:00Z"
        )
        _ = try provider.workspaceRepo.upsertWorkspace(workspace)
        _ = try provider.accountRepo.upsertAccount(existingAccount)
        let identifier = try makeVerifiedAccountIdentifier("001234567890123")
        let fixture = makeValidFixture(financialIdentifiers: [identifier])
        let coordinator = makePersistenceCoordinator(provider: provider)

        let review = try coordinator.reviewValidatedImport(
            financialDocument: fixture.financialDocument,
            validation: fixture.validation
        )
        #expect(review.isAvailable)
        #expect(review.eligibleAccountIds == [existingAccount.id])

        let result = try coordinator.persistValidatedImport(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation,
            fingerprint: fixture.fingerprint,
            accountChoice: .useExistingAccount(accountId: existingAccount.id)
        )

        #expect(result.persisted)
        #expect(result.accountId == existingAccount.id)
        #expect(try provider.accountRepo.account(id: existingAccount.id) == existingAccount)
        #expect(try provider.accountRepo.identifiers(
            accountId: existingAccount.id,
            workspaceId: workspace.id
        ).count == 1)
        #expect(try provider.transactionRepo.transactions(
            workspaceId: workspace.id,
            importSessionId: fixture.importSession.id.uuidString
        ).allSatisfy { $0.accountId == existingAccount.id })
    }

    @Test func qualifyingNoMatchRejectsMissingChoiceBeforeEveryWrite() async throws {
        let provider = makeInMemoryProvider()
        let workspace = WorkspaceDTO(
            id: "workspace-import-integration",
            name: "Choice Workspace",
            createdAtISO: "2026-07-13T00:00:00Z"
        )
        _ = try provider.workspaceRepo.upsertWorkspace(workspace)
        let fixture = makeValidFixture(financialIdentifiers: [try makeVerifiedAccountIdentifier("001234567890123")])

        #expect(throws: ImportPersistenceCoordinationError.explicitChoiceRequired) {
            try makePersistenceCoordinator(provider: provider).persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                fingerprint: fixture.fingerprint,
                accountChoice: nil
            )
        }
        #expect(try provider.accountRepo.accounts(workspaceId: workspace.id).isEmpty)
        #expect(try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString) == nil)
    }

    @Test func mapperRejectsUnsupportedCurrencyBeforePersistence() async throws {
        let fixture = makeValidFixture(currency: "JPY")
        let mapper = ImportPersistenceMapper(
            workspaceId: "workspace-unsupported-currency",
            workspaceName: "Unsupported Currency Workspace"
        )

        do {
            _ = try mapper.payload(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                accountId: "account-unsupported-currency",
                fingerprint: fixture.fingerprint
            )
            Issue.record("Expected unsupported currency mapping to fail before persistence.")
        } catch let error as ImportPersistenceError {
            #expect(error == .unsupportedCurrency("JPY"))
        }
    }

    @Test func appPersistenceBootstrapConfiguresDurableSQLiteProvider() async throws {
        let folder = try temporaryFolder(named: "LedgerForgePersistenceBootstrapTests")
        defer {
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            try? FileManager.default.removeItem(at: folder)
        }

        let dbPath = folder.appendingPathComponent("bootstrap.sqlite").path
        #expect(LedgerForgeApp.configurePersistence(path: dbPath))

        let workspace = WorkspaceDTO(
            id: "workspace-bootstrap",
            name: "Bootstrap Workspace",
            createdAtISO: "2026-07-10T00:00:00Z"
        )
        #expect(try DatabaseProvider.shared.workspaceRepo.upsertWorkspace(workspace) == workspace.id)

        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        #expect(LedgerForgeApp.configurePersistence(path: dbPath))

        let restoredWorkspace = try DatabaseProvider.shared.workspaceRepo.workspace(id: workspace.id)
        #expect(restoredWorkspace == workspace)
    }

    @Test func persistedImportHydratesRuntimeStoresAfterSQLiteProviderRecreation() async throws {
        let folder = try temporaryFolder(named: "LedgerForgePersistenceRelaunchRegressionTests")
        defer {
            resetRuntimeStoresForImportIntegration()
            try? FileManager.default.removeItem(at: folder)
        }

        let dbPath = folder.appendingPathComponent("relaunch.sqlite").path
        let fixture = makeValidFixture()
        let initialProvider = try SQLiteRepositoryProvider(path: dbPath)
        let coordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: initialProvider.workspaceRepo,
            accountRepo: initialProvider.accountRepo,
            importSessionRepo: initialProvider.importSessionRepo,
            transactionRepo: initialProvider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            )
        )

        let persistence = try coordinator.persistValidatedImport(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation,
            fingerprint: fixture.fingerprint
        )
        #expect(persistence.persisted)

        resetRuntimeStoresForImportIntegration()
        let relaunchedProvider = try SQLiteRepositoryProvider(path: dbPath)
        let hydrator = RepositoryStoreHydrator(
            accountRepo: relaunchedProvider.accountRepo,
            importSessionRepo: relaunchedProvider.importSessionRepo,
            transactionRepo: relaunchedProvider.transactionRepo,
            workspaceId: "workspace-import-integration"
        )

        let hydration = try hydrator.hydrateIfNeeded()

        #expect(hydration.didHydrate)
        #expect(hydration.accountCount == 1)
        #expect(hydration.transactionCount == 2)
        #expect(AccountStore.shared.accounts.first?.name == "Axis Bank INR")
        #expect(AccountStore.shared.accounts.first?.institution == "Axis Bank")
        #expect(TransactionStore.shared.transactions.count == 2)
        #expect(TransactionStore.shared.transactions.allSatisfy { !$0.account.contains(".csv") })
        #expect(TransactionStore.shared.transactions.allSatisfy { $0.sourceBank == "Axis Bank" })
    }

    @Test func mapperUsesSuppliedAccountIdForAccountAndEveryTransaction() async throws {
        let fixture = makeValidFixture()
        let renamedFixture = makeValidFixture(fileName: "renamed-axis-export.csv")
        let mapper = ImportPersistenceMapper(
            workspaceId: "workspace-import-integration",
            workspaceName: "Import Integration Workspace"
        )
        let selectedAccountId = "account-selected-opaque-id"

        let payload = try mapper.payload(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation,
            accountId: selectedAccountId,
            fingerprint: fixture.fingerprint
        )
        let renamedPayload = try mapper.payload(
            financialDocument: renamedFixture.financialDocument,
            importSession: renamedFixture.importSession,
            validation: renamedFixture.validation,
            accountId: selectedAccountId,
            fingerprint: renamedFixture.fingerprint
        )

        #expect(payload.account.name == "Axis Bank INR")
        #expect(payload.account.institutionId == "Axis Bank")
        #expect(!payload.account.name.localizedCaseInsensitiveContains(".csv"))
        #expect(payload.account.id == selectedAccountId)
        #expect(payload.transactions.allSatisfy { $0.accountId == selectedAccountId })
        #expect(renamedPayload.account.id == selectedAccountId)
        #expect(renamedPayload.transactions.allSatisfy { $0.accountId == selectedAccountId })
    }

    @Test func laterVerifiedImportWithDifferentFilenameReusesExistingAccountUnchanged() async throws {
        try runForEachProvider { provider in
            let identifier = try makeVerifiedAccountIdentifier("001234567890123")
            let firstFixture = makeValidFixture(
                importSessionId: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                fileName: "axis-original.csv",
                financialIdentifiers: [identifier]
            )
            let secondFixture = makeValidFixture(
                importSessionId: UUID(uuidString: "66666666-7777-8888-9999-000000000000")!,
                fileName: "renamed-axis-statement.csv",
                financialIdentifiers: [identifier]
            )
            let firstCoordinator = makePersistenceCoordinator(provider: provider)
            let secondCoordinator = makePersistenceCoordinator(
                provider: provider,
                workspaceName: "Replacement Workspace Name Must Not Persist"
            )

            let firstResult = try firstCoordinator.persistValidatedImport(
                financialDocument: firstFixture.financialDocument,
                importSession: firstFixture.importSession,
                validation: firstFixture.validation,
                fingerprint: firstFixture.fingerprint,
                accountChoice: .createNewAccount
            )
            let originalAccountId = try #require(firstResult.accountId)
            let originalAccountValue = try provider.accountRepo.account(id: originalAccountId)
            let originalAccount = try #require(originalAccountValue)
            let originalWorkspaceValue = try provider.workspaceRepo.workspace(
                id: "workspace-import-integration"
            )
            let originalWorkspace = try #require(originalWorkspaceValue)
            let secondResult = try secondCoordinator.persistValidatedImport(
                financialDocument: secondFixture.financialDocument,
                importSession: secondFixture.importSession,
                validation: secondFixture.validation,
                fingerprint: secondFixture.fingerprint
            )

            #expect(firstResult.accountId == secondResult.accountId)
            #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").count == 1)
            #expect(try provider.accountRepo.account(id: originalAccountId) == originalAccount)
            #expect(try provider.workspaceRepo.workspace(id: "workspace-import-integration") == originalWorkspace)
            #expect(try provider.accountRepo.identifiers(
                accountId: originalAccountId,
                workspaceId: "workspace-import-integration"
            ).count == 1)
            let secondTransactions = try provider.transactionRepo.transactions(
                workspaceId: "workspace-import-integration",
                importSessionId: secondFixture.importSession.id.uuidString
            )
            #expect(secondTransactions.allSatisfy { $0.accountId == originalAccountId })
        }
    }

    @Test func ambiguousIdentityThrowsBeforeEveryRepositoryWrite() async throws {
        let provider = makeInMemoryProvider()
        let accountRepo = ObservingAccountRepository(
            base: provider.accountRepo,
            forcedCandidates: ["account-a", "account-b"]
        )
        let identifier = try makeVerifiedAccountIdentifier("001234567890123")
        let fixture = makeValidFixture(financialIdentifiers: [identifier])
        let coordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            )
        )

        do {
            _ = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                fingerprint: fixture.fingerprint
            )
            Issue.record("Expected ambiguous identity to reject persistence.")
        } catch let error as ImportPersistenceCoordinationError {
            #expect(error == .ambiguousIdentity)
            #expect(error.localizedDescription == "Financial identity is ambiguous; import was not persisted.")
        }

        #expect(accountRepo.accountIdsCallCount == 1)
        #expect(accountRepo.upsertCallCount == 0)
        #expect(accountRepo.attachCallCount == 0)
        #expect(try provider.workspaceRepo.workspace(id: "workspace-import-integration") == nil)
        #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").isEmpty)
        #expect(try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString) == nil)
        #expect(try provider.transactionRepo.transactions(
            workspaceId: "workspace-import-integration",
            importSessionId: fixture.importSession.id.uuidString
        ).isEmpty)
    }

    @Test func conflictingIdentityPreservesEveryExistingRelationshipAndWritesNothing() async throws {
        try runForEachProvider { provider in
            let firstIdentifier = try makeVerifiedAccountIdentifier("001234567890123")
            let secondIdentifier = try makeVerifiedAccountIdentifier("009876543210987")
            let workspace = WorkspaceDTO(
                id: "workspace-import-integration",
                name: "Existing Workspace",
                createdAtISO: "2026-07-10T00:00:00Z"
            )
            let firstAccount = makeAccountDTO(id: "account-existing-a")
            let secondAccount = makeAccountDTO(id: "account-existing-b")
            _ = try provider.workspaceRepo.upsertWorkspace(workspace)
            _ = try provider.accountRepo.upsertAccount(firstAccount)
            _ = try provider.accountRepo.upsertAccount(secondAccount)
            _ = try provider.accountRepo.attachIdentifier(
                firstIdentifier.repositoryDTO(
                    accountId: firstAccount.id,
                    workspaceId: workspace.id,
                    createdAtISO: firstAccount.createdAtISO,
                    id: "identifier-existing-a"
                )
            )
            _ = try provider.accountRepo.attachIdentifier(
                secondIdentifier.repositoryDTO(
                    accountId: secondAccount.id,
                    workspaceId: workspace.id,
                    createdAtISO: secondAccount.createdAtISO,
                    id: "identifier-existing-b"
                )
            )
            let originalAccounts = try provider.accountRepo.accounts(workspaceId: workspace.id)
            let originalFirstIdentifiers = try provider.accountRepo.identifiers(
                accountId: firstAccount.id,
                workspaceId: workspace.id
            )
            let originalSecondIdentifiers = try provider.accountRepo.identifiers(
                accountId: secondAccount.id,
                workspaceId: workspace.id
            )
            let fixture = makeValidFixture(
                financialIdentifiers: [firstIdentifier, secondIdentifier]
            )

            do {
                _ = try makePersistenceCoordinator(provider: provider).persistValidatedImport(
                    financialDocument: fixture.financialDocument,
                    importSession: fixture.importSession,
                    validation: fixture.validation,
                    fingerprint: fixture.fingerprint
                )
                Issue.record("Expected conflicting identity to reject persistence.")
            } catch let error as ImportPersistenceCoordinationError {
                #expect(error == .conflictingIdentity)
                #expect(error.localizedDescription == "Financial identity conflicts across accounts; import was not persisted.")
            }

            #expect(try provider.workspaceRepo.workspace(id: workspace.id) == workspace)
            #expect(try provider.accountRepo.accounts(workspaceId: workspace.id) == originalAccounts)
            #expect(try provider.accountRepo.identifiers(
                accountId: firstAccount.id,
                workspaceId: workspace.id
            ) == originalFirstIdentifiers)
            #expect(try provider.accountRepo.identifiers(
                accountId: secondAccount.id,
                workspaceId: workspace.id
            ) == originalSecondIdentifiers)
            #expect(try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString) == nil)
            #expect(try provider.transactionRepo.transactions(
                workspaceId: workspace.id,
                importSessionId: fixture.importSession.id.uuidString
            ).isEmpty)
        }
    }

    @Test func identityFailureDiagnosticsDoNotExposeIdentifierOrSourceFragmentText() async throws {
        let developerConsole = DeveloperConsole()
        let provider = makeInMemoryProvider()
        let accountRepo = ObservingAccountRepository(
            base: provider.accountRepo,
            forcedCandidates: ["account-a", "account-b"]
        )
        let rawIdentifier = "001234567890123"
        let sourceFragment = "Statement Account Number : \(rawIdentifier)"
        let fixture = makeValidFixture(
            financialIdentifiers: [try makeVerifiedAccountIdentifier(rawIdentifier)]
        )
        let coordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            ),
            developerConsole: developerConsole
        )

        do {
            _ = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                fingerprint: fixture.fingerprint
            )
        } catch {
            #expect(error.localizedDescription == "Financial identity is ambiguous; import was not persisted.")
        }

        let diagnosticText = developerConsole.entries.map { entry in
            [
                entry.message,
                DeveloperConsole.metadataText(for: entry) ?? ""
            ].joined(separator: " ")
        }.joined(separator: "\n")
        #expect(!diagnosticText.contains(rawIdentifier))
        #expect(!diagnosticText.contains(sourceFragment))
        #expect(diagnosticText.contains("Ambiguous"))
    }

    @Test func exactAxisReimportIsBlockedDurablyWithBoundedProvenance() async throws {
        let folder = try temporaryFolder(named: "LedgerForgeExactReimportTests")
        defer { try? FileManager.default.removeItem(at: folder) }
        let databaseURL = folder.appendingPathComponent("exact-reimport.sqlite")
        let originalURL = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let renamedURL = folder.appendingPathComponent("renamed-axis-statement.csv")
        let changedURL = folder.appendingPathComponent("changed-axis-statement.csv")
        let exactText = try String(contentsOf: originalURL, encoding: .utf8)
        try exactText.write(to: renamedURL, atomically: true, encoding: .utf8)
        try (exactText + "\n").write(to: changedURL, atomically: true, encoding: .utf8)

        let firstProvider = try SQLiteRepositoryProvider(path: databaseURL.path)
        let firstCoordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: firstProvider.workspaceRepo,
            accountRepo: firstProvider.accountRepo,
            importSessionRepo: firstProvider.importSessionRepo,
            transactionRepo: firstProvider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            )
        )
        let firstEngine = ImportEngine(importPersistenceCoordinator: firstCoordinator)
        let firstPrepared = try await firstEngine.prepareImport(from: originalURL)
        #expect(firstPrepared.transactionCount == 81)
        let first = await firstEngine.commitPreparedImport(firstPrepared, accountChoice: .createNewAccount)
        #expect(first.persisted)
        #expect(first.transactionCount == 81)
        #expect(first.requiresHydration)
        let firstAccountId = try #require(first.accountId)
        let firstSessionId = try #require(first.importSessionId)
        let firstAccount = try #require(try firstProvider.accountRepo.account(id: firstAccountId))
        let firstIdentifiers = try firstProvider.accountRepo.identifiers(
            accountId: firstAccountId,
            workspaceId: "workspace-import-integration"
        )
        let countsBeforeDuplicate = try sqliteImportHistoryCounts(firstProvider)

        let sameNamePrepared = try await firstEngine.prepareImport(from: originalURL)
        let sameNameDuplicate = await firstEngine.commitPreparedImport(sameNamePrepared)
        #expect(!sameNameDuplicate.persisted)
        #expect(sameNameDuplicate.previousImport?.importSessionId == firstSessionId)
        #expect(try sqliteImportHistoryCounts(firstProvider) == countsBeforeDuplicate)

        let relaunchedProvider = try SQLiteRepositoryProvider(path: databaseURL.path)
        let relaunchedCoordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: relaunchedProvider.workspaceRepo,
            accountRepo: relaunchedProvider.accountRepo,
            importSessionRepo: relaunchedProvider.importSessionRepo,
            transactionRepo: relaunchedProvider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            )
        )
        let relaunchedEngine = ImportEngine(importPersistenceCoordinator: relaunchedCoordinator)
        let duplicatePrepared = try await relaunchedEngine.prepareImport(from: renamedURL)
        #expect(duplicatePrepared.fingerprint == firstPrepared.fingerprint)
        #expect(duplicatePrepared.advisoryPreviousImport?.importSessionId == firstSessionId)
        #expect(duplicatePrepared.advisoryPreviousImport?.transactionCount == 81)
        #expect(duplicatePrepared.advisoryPreviousImport?.accountId == firstAccountId)
        #expect(duplicatePrepared.advisoryPreviousImport?.accountDisplayName == firstAccount.name)
        #expect(duplicatePrepared.advisoryPreviousImport?.completedAtISO != nil)

        let duplicate = await relaunchedEngine.commitPreparedImport(duplicatePrepared)
        #expect(!duplicate.persisted)
        #expect(duplicate.errorMessage == nil)
        #expect(duplicate.previousImport?.importSessionId == firstSessionId)
        #expect(duplicate.previousImport?.transactionCount == 81)
        #expect(duplicate.previousImport?.accountDisplayName == firstAccount.name)
        #expect(!duplicate.requiresHydration)
        #expect(try sqliteImportHistoryCounts(relaunchedProvider) == countsBeforeDuplicate)
        #expect(try relaunchedProvider.accountRepo.account(id: firstAccountId) == firstAccount)
        #expect(try relaunchedProvider.accountRepo.identifiers(
            accountId: firstAccountId,
            workspaceId: "workspace-import-integration"
        ) == firstIdentifiers)

        let changedPrepared = try await relaunchedEngine.prepareImport(from: changedURL)
        #expect(changedPrepared.fingerprint != firstPrepared.fingerprint)
        #expect(changedPrepared.advisoryPreviousImport == nil)
        let changed = await relaunchedEngine.commitPreparedImport(changedPrepared)
        #expect(changed.persisted)
        #expect(changed.transactionCount == 81)
        #expect(changed.requiresHydration)
    }

    @Test func legacyUnfingerprintedHistoryIsNotBackfilledAndRegistersProspectively() async throws {
        try runForEachProvider { provider in
            let workspace = WorkspaceDTO(
                id: "workspace-import-integration",
                name: "Legacy Workspace",
                createdAtISO: "2026-07-01T00:00:00Z"
            )
            let legacyAccount = makeAccountDTO(id: "account-legacy")
            let legacySession = ImportSessionDTO(
                id: "session-legacy",
                workspaceId: workspace.id,
                userVisibleName: "legacy.csv",
                startedAtISO: "2026-07-01T00:01:00Z",
                validationStatus: "pending"
            )
            _ = try provider.workspaceRepo.upsertWorkspace(workspace)
            _ = try provider.accountRepo.upsertAccount(legacyAccount)
            _ = try provider.importSessionRepo.createImportSession(legacySession)
            try provider.importSessionRepo.updateImportSession(
                legacySession.id,
                updates: PartialImportSessionUpdate(
                    validationStatus: "passed",
                    completedAtISO: "2026-07-01T00:02:00Z"
                )
            )
            let prospectiveFingerprint = ExactStatementFingerprint(text: "legacy exact statement text")
            #expect(try provider.importSessionRepo.priorImportedStatement(
                algorithm: prospectiveFingerprint.algorithm,
                fingerprint: prospectiveFingerprint.digest
            ) == nil)

            let firstFixture = makeValidFixture(
                importSessionId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                fileName: "legacy-first-post-sprint39.csv",
                fingerprintText: "legacy exact statement text"
            )
            let first = try makePersistenceCoordinator(provider: provider).persistValidatedImport(
                financialDocument: firstFixture.financialDocument,
                importSession: firstFixture.importSession,
                validation: firstFixture.validation,
                fingerprint: firstFixture.fingerprint
            )
            #expect(first.persisted)

            let nextFixture = makeValidFixture(
                importSessionId: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                fileName: "legacy-next-exact.csv",
                fingerprintText: "legacy exact statement text"
            )
            let next = try makePersistenceCoordinator(provider: provider).persistValidatedImport(
                financialDocument: nextFixture.financialDocument,
                importSession: nextFixture.importSession,
                validation: nextFixture.validation,
                fingerprint: nextFixture.fingerprint
            )
            #expect(!next.persisted)
            #expect(next.previousImport?.importSessionId == firstFixture.importSession.id.uuidString)
            #expect(try provider.importSessionRepo.importSession(id: legacySession.id)?.validationStatus == "passed")
            #expect(try provider.importSessionRepo.importSession(id: nextFixture.importSession.id.uuidString) == nil)
        }
    }

    @Test func preparationWithoutConfirmationLeavesNoDurableFingerprint() async throws {
        let folder = try temporaryFolder(named: "LedgerForgeCancelledPreparationTests")
        defer { try? FileManager.default.removeItem(at: folder) }
        let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("cancelled.sqlite").path)
        let coordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo
        )
        let engine = ImportEngine(importPersistenceCoordinator: coordinator)

        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )

        #expect(prepared.validation.passed)
        #expect(try provider.importSessionRepo.priorImportedStatement(
            algorithm: prepared.fingerprint.algorithm,
            fingerprint: prepared.fingerprint.digest
        ) == nil)
        #expect(try sqliteImportHistoryCounts(provider) == SQLiteImportHistoryCounts(
            documents: 0,
            fingerprints: 0,
            sessions: 0,
            transactions: 0
        ))
    }

    @Test func missingPriorAccountPresentationStillBlocksExactReimport() async throws {
        let folder = try temporaryFolder(named: "LedgerForgeMissingPriorAccountTests")
        defer { try? FileManager.default.removeItem(at: folder) }
        let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("missing-account.sqlite").path)
        let coordinator = makeSQLitePersistenceCoordinator(provider: provider)
        let firstFixture = makeValidFixture(
            importSessionId: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            fingerprintText: "missing account provenance exact text"
        )
        let first = try coordinator.persistValidatedImport(
            financialDocument: firstFixture.financialDocument,
            importSession: firstFixture.importSession,
            validation: firstFixture.validation,
            fingerprint: firstFixture.fingerprint
        )
        let firstAccountId = try #require(first.accountId)
        try provider.database.executePrepared(
            sql: "UPDATE transactions SET account_id = NULL WHERE import_session_id = ?;",
            params: [firstFixture.importSession.id.uuidString]
        )
        try provider.database.executePrepared(sql: "DELETE FROM accounts WHERE id = ?;", params: [firstAccountId])
        let countsBeforeDuplicate = try sqliteImportHistoryCounts(provider)

        let secondFixture = makeValidFixture(
            importSessionId: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            fileName: "renamed-missing-account.csv",
            fingerprintText: "missing account provenance exact text"
        )
        let duplicate = try coordinator.persistValidatedImport(
            financialDocument: secondFixture.financialDocument,
            importSession: secondFixture.importSession,
            validation: secondFixture.validation,
            fingerprint: secondFixture.fingerprint
        )

        #expect(!duplicate.persisted)
        #expect(duplicate.previousImport != nil)
        #expect(duplicate.previousImport?.accountId == nil)
        #expect(duplicate.previousImport?.accountDisplayName == nil)
        #expect(try sqliteImportHistoryCounts(provider) == countsBeforeDuplicate)
    }

    @Test func duplicateDiagnosticsExcludeRawContentAndFullFingerprint() async throws {
        let developerConsole = DeveloperConsole()
        let provider = makeInMemoryProvider()
        let coordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            ),
            developerConsole: developerConsole
        )
        let rawContent = "private statement exact content 90210"
        let firstFixture = makeValidFixture(
            importSessionId: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            fingerprintText: rawContent
        )
        _ = try coordinator.persistValidatedImport(
            financialDocument: firstFixture.financialDocument,
            importSession: firstFixture.importSession,
            validation: firstFixture.validation,
            fingerprint: firstFixture.fingerprint
        )
        let secondFixture = makeValidFixture(
            importSessionId: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            fileName: "renamed-private.csv",
            fingerprintText: rawContent
        )
        _ = try coordinator.persistValidatedImport(
            financialDocument: secondFixture.financialDocument,
            importSession: secondFixture.importSession,
            validation: secondFixture.validation,
            fingerprint: secondFixture.fingerprint
        )
        let diagnostics = developerConsole.entries.map { entry in
            entry.message + " " + (DeveloperConsole.metadataText(for: entry) ?? "")
        }.joined(separator: "\n")

        #expect(diagnostics.contains(ExactStatementFingerprint.algorithm))
        #expect(diagnostics.contains("Previously imported"))
        #expect(!diagnostics.contains(rawContent))
        #expect(!diagnostics.contains(firstFixture.fingerprint.digest))
    }

}

private struct SQLiteImportHistoryCounts: Equatable {
    let documents: Int
    let fingerprints: Int
    let sessions: Int
    let transactions: Int
}

private func sqliteImportHistoryCounts(_ provider: SQLiteRepositoryProvider) throws -> SQLiteImportHistoryCounts {
    SQLiteImportHistoryCounts(
        documents: try provider.database.queryInt("SELECT COUNT(*) FROM documents;"),
        fingerprints: try provider.database.queryInt("SELECT COUNT(*) FROM document_fingerprints;"),
        sessions: try provider.database.queryInt("SELECT COUNT(*) FROM import_sessions;"),
        transactions: try provider.database.queryInt("SELECT COUNT(*) FROM transactions;")
    )
}

private func makeSQLitePersistenceCoordinator(
    provider: SQLiteRepositoryProvider
) -> DefaultImportPersistenceCoordinator {
    DefaultImportPersistenceCoordinator(
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        mapper: ImportPersistenceMapper(
            workspaceId: "workspace-import-integration",
            workspaceName: "Import Integration Workspace"
        )
    )
}

private struct ImportRepositoryHandles {
    let workspaceRepo: WorkspaceRepository
    let accountRepo: AccountRepository
    let importSessionRepo: ImportSessionRepository
    let transactionRepo: TransactionRepository
}

private struct ImportRepositoryFixture {
    let financialDocument: FinancialDocument
    let importSession: ImportSession
    let validation: ImportValidationResult
    let fingerprint: ExactStatementFingerprint
}

private final class ObservingAccountRepository: AccountRepository {
    private let base: AccountRepository
    private let forcedCandidates: [String]?

    private(set) var accountIdsCallCount = 0
    private(set) var upsertCallCount = 0
    private(set) var attachCallCount = 0

    init(base: AccountRepository, forcedCandidates: [String]? = nil) {
        self.base = base
        self.forcedCandidates = forcedCandidates
    }

    func upsertAccount(_ account: AccountDTO) throws -> String {
        upsertCallCount += 1
        return try base.upsertAccount(account)
    }

    func updateAccountDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
        try base.updateAccountDisplayName(
            accountId: accountId,
            workspaceId: workspaceId,
            displayName: displayName
        )
    }

    func account(id: String) throws -> AccountDTO? {
        try base.account(id: id)
    }

    func accounts(workspaceId: String) throws -> [AccountDTO] {
        try base.accounts(workspaceId: workspaceId)
    }

    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String {
        attachCallCount += 1
        return try base.attachIdentifier(identifier)
    }

    func identifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO] {
        try base.identifiers(accountId: accountId, workspaceId: workspaceId)
    }

    func accountIds(workspaceId: String, scheme: String, identifier: String) throws -> [String] {
        accountIdsCallCount += 1
        if let forcedCandidates {
            return forcedCandidates
        }
        return try base.accountIds(
            workspaceId: workspaceId,
            scheme: scheme,
            identifier: identifier
        )
    }
}

private func runForEachProvider(_ body: (ImportRepositoryHandles) throws -> Void) throws {
    try body(makeInMemoryProvider())
    try withTemporarySQLiteProvider(body)
}

private func makeInMemoryProvider() -> ImportRepositoryHandles {
    let provider = InMemoryRepositoryProvider()
    return ImportRepositoryHandles(
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo
    )
}

private func makePersistenceCoordinator(
    provider: ImportRepositoryHandles,
    workspaceName: String = "Import Integration Workspace"
) -> DefaultImportPersistenceCoordinator {
    DefaultImportPersistenceCoordinator(
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        mapper: ImportPersistenceMapper(
            workspaceId: "workspace-import-integration",
            workspaceName: workspaceName
        )
    )
}

private func withTemporarySQLiteProvider<T>(_ body: (ImportRepositoryHandles) throws -> T) throws -> T {
    let folder = try temporaryFolder(named: "LedgerForgeImportRepositoryIntegrationTests")
    defer {
        try? FileManager.default.removeItem(at: folder)
    }

    let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("integration.sqlite").path)
    let handles = ImportRepositoryHandles(
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo
    )
    return try body(handles)
}

private func temporaryFolder(named name: String) throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

private func resetRuntimeStoresForImportIntegration() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
}

private func makeValidFixture(
    currency: String = "INR",
    importSessionId: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
    fileName: String = "repository-integration.csv",
    financialIdentifiers: [FinancialIdentifier] = [],
    fingerprintText: String? = nil
) -> ImportRepositoryFixture {
    let transactions = [
        makeTransaction(
            date: Date(timeIntervalSince1970: 1_804_896_000),
            description: "Opening credit",
            debit: nil,
            credit: 100,
            amount: 100,
            balance: 1_100,
            currency: currency
        ),
        makeTransaction(
            date: Date(timeIntervalSince1970: 1_804_982_400),
            description: "Card payment",
            debit: 50,
            credit: nil,
            amount: -50,
            balance: 1_050,
            currency: currency
        )
    ]
    let financialDocument = makeFinancialDocument(
        transactions: transactions,
        fileName: fileName,
        financialIdentifiers: financialIdentifiers
    )
    let validation = ImportValidator.validate(financialDocument: financialDocument)
    let importSession = makeImportSession(
        id: importSessionId,
        fileName: fileName,
        transactionCount: transactions.count,
        validation: validation
    )

    return ImportRepositoryFixture(
        financialDocument: financialDocument,
        importSession: importSession,
        validation: validation,
        fingerprint: ExactStatementFingerprint(text: fingerprintText ?? "fixture:\(fileName):\(currency)")
    )
}

private func makeFailedValidationFixture() -> ImportRepositoryFixture {
    let financialDocument = makeFinancialDocument(transactions: [])
    let validation = ImportValidator.validate(financialDocument: financialDocument)
    let importSession = makeImportSession(transactionCount: 0, validation: validation)

    return ImportRepositoryFixture(
        financialDocument: financialDocument,
        importSession: importSession,
        validation: validation,
        fingerprint: ExactStatementFingerprint(text: "failed-validation-fixture")
    )
}

private func makeFinancialDocument(
    transactions: [Transaction],
    fileName: String = "repository-integration.csv",
    financialIdentifiers: [FinancialIdentifier] = []
) -> FinancialDocument {
    FinancialDocument(
        sourceDocument: Document(
            filename: fileName,
            url: URL(fileURLWithPath: "/tmp/\(fileName)"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 1_804_896_000)
        ),
        metadata: DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: .csv,
            confidence: 1.0
        ),
        parserName: "Axis Bank Account",
        transactions: transactions,
        financialIdentifiers: financialIdentifiers,
        selectionReasons: ["Repository integration test parser selection."],
        createdAt: Date(timeIntervalSince1970: 1_804_896_000)
    )
}

private func makeImportSession(
    id: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
    fileName: String = "repository-integration.csv",
    transactionCount: Int,
    validation: ImportValidationResult
) -> ImportSession {
    ImportSession(
        id: id,
        importedAt: Date(timeIntervalSince1970: 1_804_896_000),
        fileName: fileName,
        institution: .axis,
        documentType: .bankAccount,
        parserName: "Axis Bank Account",
        transactionCount: transactionCount,
        validation: validation
    )
}

private func makeTransaction(
    date: Date,
    description: String,
    debit: Decimal?,
    credit: Decimal?,
    amount: Decimal,
    balance: Decimal?,
    currency: String
) -> Transaction {
    Transaction(
        date: date,
        description: description,
        debit: debit,
        credit: credit,
        amount: amount,
        balance: balance,
        currency: currency,
        account: "Axis NRE",
        sourceBank: "Axis Bank",
        sourceFile: "repository-integration.csv"
    )
}

private func makeVerifiedAccountIdentifier(_ rawValue: String) throws -> FinancialIdentifier {
    try FinancialIdentifier(
        kind: .institutionAccountId,
        rawValue: rawValue,
        verificationState: .verified,
        provenance: .institutionStructuredField
    )
}

private func makeAccountDTO(id: String) -> AccountDTO {
    AccountDTO(
        id: id,
        workspaceId: "workspace-import-integration",
        name: "Existing \(id)",
        institutionId: "Axis Bank",
        accountType: "bank",
        nativeCurrency: "INR",
        description: "Existing account",
        createdAtISO: "2026-07-10T00:00:00Z"
    )
}
