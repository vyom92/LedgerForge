// LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift

import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct ConfirmationGatedImportWorkflowTests {

    @Test(.globalRuntimeStateIsolation)
    func capturedPlanningBalancesRefreshFromLaterOriginalWithoutSavingOrOverwritingManualInput() async throws {
        let root = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_PRIVATE_ORIGINALS_DIRECTORY"]))
        let password = try await HDFCBankAccountAuthenticAcceptanceTests()
            .sourceOraclePassword(ProcessInfo.processInfo.environment)
        for inMemory in [true, false] {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-captured-plan-\(UUID())")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let sqlite = inMemory ? nil : try SQLiteRepositoryProvider(path: folder.appendingPathComponent("planning.sqlite").path)
            defer { sqlite?.database.close() }
            let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
            var active = provider
            let workspace = "captured-plan"
            let accounts = AccountStore(), transactions = TransactionStore()
            let salaries = SalaryStore(), plans = FundingPlanStore()
            let hydrator = RepositoryStoreHydrator(
                accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
                transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo,
                salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo,
                accountStore: accounts, transactionStore: transactions, categoryStore: CategoryStore(),
                salaryStore: salaries, fundingPlanStore: plans,
                importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
                workspaceId: workspace, persistenceState: provider.persistenceState,
                providerGeneration: provider.generationToken, categoryReconciliationGate: nil, participatesInLifecycleGate: false
            )
            let engine = ImportEngine(
                importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(),
                    passwordProvider: DefaultPasswordProvider(
                        credentialStore: InMemoryStatementPasswordCredentialStore(passwords: [Institution.hdfc.statementPasswordCredentialScope: password]),
                        supportedInstitutionCodes: [Institution.hdfc.statementPasswordCredentialScope], challenge: { _ in nil })),
                importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider,
                    mapper: ImportPersistenceMapper(workspaceId: workspace, workspaceName: "Captured planning balance")),
                persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
                forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {}
            )
            let first = try await engine.prepareImport(from: root.appendingPathComponent("HDFC/HDFC NRE FY 25-26.pdf"))
            let firstResult = await engine.commitPreparedImport(first, accountChoice: .createNewAccount(displayName: "HDFC NRE"))
            #expect(firstResult.persisted)
            let account = try #require(accounts.accounts.first)
            let initialMoney = account.currentBalanceMoney
            let model = SalaryWorkspaceViewModel(
                workspaceID: workspace, provider: { active }, accountStore: accounts, transactionStore: transactions,
                salaryStore: salaries, fundingPlanStore: plans, locale: Locale(identifier: "en_US_POSIX"),
                refresh: { _ in _ = try hydrator.hydrateIfNeeded(forceRefresh: true) }
            )
            model.refreshCapturedAccountBalances()
            let firstBalance = try #require(model.plan.balances.first)
            let initialCaptureMatches = firstBalance.money == initialMoney && !firstBalance.included
            #expect(initialCaptureMatches)
            if case .capturedAccountBalance = firstBalance.provenance {} else { Issue.record("Expected genuine captured provenance") }
            model.setAccountIncluded(account, included: true)
            model.save()
            #expect(model.saveState == .saved)
            let saved = try provider.fundingPlanRepo.plans(workspaceId: workspace)
            let savedDraft = model.plan
            model.refreshCapturedAccountBalances()
            let unchangedOpen = model.plan == savedDraft && !model.isDirty
            #expect(unchangedOpen)

            let later = try await engine.prepareImport(from: root.appendingPathComponent("HDFC/HDFC NRE FY 26-27.pdf"))
            let laterResult = await engine.commitPreparedImport(later)
            #expect(laterResult.persisted)
            let latest = try #require(accounts.accounts.first)
            let authenticBalanceChanged = latest.currentBalanceMoney != initialMoney
            #expect(authenticBalanceChanged)
            model.refreshCapturedAccountBalances()
            let refreshed = try #require(model.plan.balances.first)
            let refreshMatchesCurrent = refreshed.money == latest.currentBalanceMoney && refreshed.included && model.isDirty
            #expect(refreshMatchesCurrent)
            let savedPlanUnchanged = try provider.fundingPlanRepo.plans(workspaceId: workspace) == saved
            #expect(savedPlanUnchanged)

            model.setManualBalance(latest, text: "-")
            model.refreshCapturedAccountBalances()
            let inputKey = "balance.\(try #require(latest.repositoryAccountId))"
            let incompleteEditPreserved = model.rawText[inputKey] == "-" && model.fieldErrors[inputKey] != nil
            #expect(incompleteEditPreserved)
            model.setManualBalance(latest, text: "0") // Ordinary owner-editable planning input, not a source fact.
            model.refreshCapturedAccountBalances()
            let manual = try #require(model.plan.balances.first)
            let manualPreserved = manual.provenance == .manual && manual.money?.amount == .zero && manual.included
            #expect(manualPreserved)

            let other = try await engine.prepareImport(from: root.appendingPathComponent("HDFC/HDFC NRO FY 25-26.pdf"))
            let otherResult = await engine.commitPreparedImport(other, accountChoice: .createNewAccount(displayName: "HDFC NRO"))
            #expect(otherResult.persisted)
            model.refreshCapturedAccountBalances()
            let otherID = try #require(otherResult.accountId)
            let otherAccount = try #require(accounts.accounts.first { $0.repositoryAccountId == otherID })
            let otherBalance = try #require(model.plan.balances.first { $0.accountID == otherID })
            let newAccountPopulated = model.plan.balances.count == 2 && otherBalance.money == otherAccount.currentBalanceMoney && !otherBalance.included
            #expect(newAccountPopulated)
            let draft = model.plan
            active = .unavailable(reason: .notInitialized)
            model.refreshCapturedAccountBalances()
            let withdrawalPreservedDraft = model.plan == draft && model.saveState == .providerChanged
            #expect(withdrawalPreservedDraft)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticBankChoiceRejectsDifferentIdentifiersTypesAndCurrenciesAcrossProviders() async throws {
        let root = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_PRIVATE_ORIGINALS_DIRECTORY"]))
        var passwords: [String: String] = [:]
        for institution in [Institution.hdfc, .amex, .cbq] {
            let scope = institution.statementPasswordCredentialScope
            let password: String = try #require(try await KeychainStatementPasswordCredentialStore().password(institutionCode: scope))
            passwords[scope] = password
        }
        for inMemory in [true, false] {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-account-compatibility-\(UUID())")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let sqlite = inMemory ? nil : try SQLiteRepositoryProvider(path: folder.appendingPathComponent("confirmation.sqlite").path)
            defer { sqlite?.database.close() }
            let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
            let workspace = "account-compatibility"
            let hydrator = RepositoryStoreHydrator(
                accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
                transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
                accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(), cardStore: CardStore(),
                importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
                workspaceId: workspace, categoryReconciliationGate: nil, participatesInLifecycleGate: false
            )
            let persistence = DefaultImportPersistenceCoordinator(databaseProvider: provider,
                mapper: ImportPersistenceMapper(workspaceId: workspace, workspaceName: "Account compatibility"))
            let engine = ImportEngine(
                importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(),
                    passwordProvider: DefaultPasswordProvider(credentialStore: InMemoryStatementPasswordCredentialStore(passwords: passwords),
                        supportedInstitutionCodes: passwords.keys.sorted(), challenge: { _ in nil })),
                importPersistenceCoordinator: persistence,
                persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
                forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {}
            )
            var accountIDs: [String] = []
            for relative in ["HDFC/HDFC NRE FY 25-26.pdf", "AmericanExpress/amex 24 apr 2025.pdf", "CBQ/BankAccounts/Jan 2025.pdf"] {
                let source = try await engine.prepareImport(from: root.appendingPathComponent(relative))
                defer { engine.cancelPreparedImport(source) }
                let choice: ImportAccountChoice = source.detectedDocumentType == .creditCard
                    ? .createNewCardLiabilityAccountAndInstrument(displayName: "Reviewed card")
                    : .createNewAccount(displayName: "Reviewed bank")
                let result = await engine.commitPreparedImport(source, accountChoice: choice)
                #expect(result.persisted)
                accountIDs.append(try #require(result.accountId))
            }
            let accountsBefore = try provider.accountRepo.accounts(workspaceId: workspace)
            let rowsBefore = try provider.transactionRepo.trustedTransactions(workspaceId: workspace).count
            let nroURL = root.appendingPathComponent("HDFC/HDFC NRO FY 25-26.pdf")
            for incompatibleID in accountIDs {
                let source = try await engine.prepareImport(from: nroURL)
                defer { engine.cancelPreparedImport(source) }
                let review = try engine.reviewPreparedImport(source)
                #expect(review == .choiceRequired(eligibleAccountIds: []))
                let result = await engine.commitPreparedImport(source, accountChoice: .useExistingAccount(accountId: incompatibleID))
                #expect(!result.persisted)
                let unchanged = try provider.accountRepo.accounts(workspaceId: workspace) == accountsBefore
                #expect(unchanged)
                #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspace).count == rowsBefore)
                #expect(try provider.importSessionRepo.importSession(id: source.importSession.id.uuidString) == nil)
            }
            let source = try await engine.prepareImport(from: nroURL)
            defer { engine.cancelPreparedImport(source) }
            let result = await engine.commitPreparedImport(source, accountChoice: .createNewAccount(displayName: "HDFC NRO review"))
            #expect(result.persisted && result.accountId != accountIDs.first)
            #expect(try provider.accountRepo.accounts(workspaceId: workspace).count == accountsBefore.count + 1)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func prepareImportParsesAndValidatesWithoutPersistenceOrRuntimeStoreMutation() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let persistence = CountingPersistenceCoordinator()
        let engine = availableImportEngine(persistence)
        let url = try AuthenticSourceTestSupport.axisBankCSV()

        let preparedImport = try await engine.prepareImport(from: url)

        #expect(preparedImport.fileName == url.lastPathComponent)
        #expect(preparedImport.detectedInstitution == .axis)
        #expect(preparedImport.detectedDocumentType == .bankAccount)
        #expect(preparedImport.validation.passed)
        #expect(preparedImport.transactionCount == preparedImport.financialDocument.transactions.count)
        #expect(preparedImport.detectedCurrency == "INR")
        #expect(persistence.persistCallCount == 0)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
    }

    @Test(.globalRuntimeStateIsolation)
    func confirmationCommitsUsingPreparedFinancialDocumentWithoutRuntimeMutation() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let persistence = CountingPersistenceCoordinator()
        let engine = availableImportEngine(persistence)
        let preparedImport = try await engine.prepareImport(from: AuthenticSourceTestSupport.axisBankCSV())

        let result = await engine.commitPreparedImport(preparedImport)

        #expect(result.validationPassed)
        #expect(result.persisted)
        #expect(persistence.persistCallCount == 1)
        #expect(persistence.capturedFinancialDocument?.id == preparedImport.financialDocument.id)
        #expect(persistence.capturedImportSession?.id == preparedImport.importSession.id)
        #expect(persistence.capturedValidation?.passed == preparedImport.validation.passed)
        #expect(persistence.capturedFingerprint?.algorithm == ExactStatementFingerprint.algorithm)
        #expect(persistence.capturedFingerprint?.digest == preparedImport.fingerprint.digest)
        #expect(persistence.fingerprintedPersistCallCount == 1)
        #expect(persistence.legacyPersistCallCount == 0)
        #expect(TransactionStore.shared.transactions.isEmpty)
        #expect(AccountStore.shared.accounts.isEmpty)
    }

    @Test(.globalRuntimeStateIsolation)
    func duplicateConfirmationIsRejectedWithoutSecondPersistence() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let persistence = CountingPersistenceCoordinator()
        let engine = availableImportEngine(persistence)
        let preparedImport = try await engine.prepareImport(from: AuthenticSourceTestSupport.axisBankCSV())

        let firstResult = await engine.commitPreparedImport(preparedImport)
        let secondResult = await engine.commitPreparedImport(preparedImport)

        #expect(firstResult.persisted)
        #expect(secondResult.validationPassed)
        #expect(!secondResult.persisted)
        #expect(secondResult.errorMessage == "Prepared import has already been committed.")
        #expect(persistence.persistCallCount == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func persistenceFailureLeavesEveryRuntimeFinancialStoreUnchanged() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let existingEngine = availableImportEngine(CountingPersistenceCoordinator())
        let existingPrepared = try await existingEngine.prepareImport(from: AuthenticSourceTestSupport.axisBankCSV(alternatePeriod: true))
        defer { existingEngine.cancelPreparedImport(existingPrepared) }
        TransactionStore.shared.replaceTransactions(existingPrepared.financialDocument.transactions)
        DocumentStore.shared.update(with: existingPrepared.rawContents)
        await Task.yield()

        let originalDocumentRows = DocumentStore.shared.rows
        let originalTransactionIds = TransactionStore.shared.transactions.map(\.id)
        let originalAccountIds = AccountStore.shared.accounts.map(\.id)
        let persistence = CountingPersistenceCoordinator()
        persistence.errorToThrow = ConfirmationPersistenceError.writeFailed
        let engine = availableImportEngine(persistence)

        let result = await engine.commitPreparedImport(try await engine.prepareImport(from: AuthenticSourceTestSupport.axisBankCSV()))

        #expect(result.validationPassed)
        #expect(!result.persisted)
        #expect(result.errorMessage == "The confirmed import could not be completed.")
        #expect(persistence.persistCallCount == 1)
        #expect(DocumentStore.shared.rows == originalDocumentRows)
        #expect(TransactionStore.shared.transactions.map(\.id) == originalTransactionIds)
        #expect(AccountStore.shared.accounts.map(\.id) == originalAccountIds)
    }

    @Test(.globalRuntimeStateIsolation)
    func skippedPersistenceLeavesRuntimeStoresEmptyAndReportsFailure() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let persistence = CountingPersistenceCoordinator()
        persistence.resultOverride = .skipped
        let engine = availableImportEngine(persistence)

        let result = await engine.commitPreparedImport(try await engine.prepareImport(from: AuthenticSourceTestSupport.axisBankCSV()))

        #expect(result.validationPassed)
        #expect(!result.persisted)
        #expect(result.errorMessage == "Import persistence was skipped.")
        #expect(DocumentStore.shared.rows.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
        #expect(AccountStore.shared.accounts.isEmpty)
    }

    @Test(.globalRuntimeStateIsolation)
    func ambiguousAndConflictingIdentityFailuresLeaveRuntimeStoresUnchanged() async throws {
        let errors: [ImportPersistenceCoordinationError] = [
            .ambiguousIdentity,
            .conflictingIdentity
        ]

        for error in errors {
            await resetRuntimeStoresForConfirmationWorkflow()
            let persistence = CountingPersistenceCoordinator()
            persistence.errorToThrow = error
            let engine = availableImportEngine(persistence)

            let result = await engine.commitPreparedImport(try await engine.prepareImport(from: AuthenticSourceTestSupport.axisBankCSV()))

            #expect(!result.persisted)
            #expect(result.errorMessage == error.localizedDescription)
            #expect(DocumentStore.shared.rows.isEmpty)
            #expect(TransactionStore.shared.transactions.isEmpty)
            #expect(AccountStore.shared.accounts.isEmpty)
        }
    }

    @Test func sprint27OutcomePresentationStillReflectsCommitResults() async throws {
        let success = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "axis.csv",
                transactionCount: 2,
                validationPassed: true,
                persisted: true,
                errorMessage: nil
            )
        )
        let persistenceFailure = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "axis.csv",
                transactionCount: 2,
                validationPassed: true,
                persisted: false,
                errorMessage: "Repository write failed."
            )
        )

        #expect(success.validationStatus == "Validation Passed")
        #expect(success.persistenceStatus == "Persistence Succeeded")
        #expect(success.allowsViewingTransactions)
        #expect(persistenceFailure.validationStatus == "Validation Passed")
        #expect(persistenceFailure.persistenceStatus == "Persistence Failed")
        #expect(!persistenceFailure.allowsViewingTransactions)
    }

    @Test func exactFingerprintUsesOnlyReaderProducedUTF8Text() {
        let original = ExactStatementFingerprint(text: "Label,Value\nAlpha,Beta\n")
        let renamed = ExactStatementFingerprint(text: "Label,Value\nAlpha,Beta\n")
        let whitespaceChanged = ExactStatementFingerprint(text: "Label,Value\nAlpha,Beta \n")

        #expect(original.algorithm == "ledgerforge.raw-text.sha256.v1")
        #expect(original.digest.count == 64)
        #expect(original.digest == renamed.digest)
        #expect(original.byteCount == renamed.byteCount)
        #expect(original.digest != whitespaceChanged.digest)
    }

    @Test func previouslyImportedOutcomeIsDistinctAndDoesNotRequireHydration() {
        let previous = PreviouslyImportedStatement(
            importSessionId: "prior-session",
            completedAtISO: "2026-07-14T09:00:00Z",
            transactionCount: 81,
            accountId: "account-prior",
            accountDisplayName: "Axis Bank INR"
        )
        let result = ImportEngineResult(
            fileName: "renamed.csv",
            transactionCount: 81,
            validationPassed: true,
            persisted: false,
            errorMessage: nil,
            accountId: previous.accountId,
            importSessionId: previous.importSessionId,
            previousImport: previous,
            recoveryRoute: .reviewRequired(.exactStatementDuplicate)
        )
        let presentation = ImportOutcomePresentation(result: result)

        #expect(!result.succeeded)
        #expect(!result.requiresHydration)
        #expect(presentation.persistenceStatus == "Previously Imported")
        #expect(presentation.isPreviouslyImported)
        #expect(presentation.previousImportCompletedAtISO == previous.completedAtISO)
        #expect(presentation.previousAccountDisplayName == previous.accountDisplayName)
        #expect(!presentation.allowsViewingTransactions)
    }

    @Test func newSuccessIsAlreadyCanonicallyHydrated() {
        let result = ImportEngineResult(
            fileName: "axis.csv",
            transactionCount: 81,
            validationPassed: true,
            persisted: true,
            errorMessage: nil
        )

        #expect(!result.requiresHydration)
        #expect(result.hydrationOutcome == .committedAndHydrated)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticCreationNamePersistsThroughSQLiteReopenAndBlankNameWritesNoAccount() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-name-confirmation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("confirmation.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let workspaceID = "name-confirmation"
        let accounts = AccountStore()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo,
            accountStore: accounts, transactionStore: TransactionStore(), categoryStore: CategoryStore(),
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
            workspaceId: workspaceID, categoryReconciliationGate: nil, participatesInLifecycleGate: false
        )
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Account name confirmation")
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
            rejectedAttemptHydration: { _ = try hydrator.stageHydration() }
        )
        let source = try AuthenticSourceTestSupport.axisBankCSV()
        let blank = try await engine.prepareImport(from: source)
        let rejected = await engine.commitPreparedImport(blank, accountChoice: .createNewAccount(displayName: " \n "))
        #expect(!rejected.persisted)
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
        #expect(try sqlite.database.queryInt("SELECT COUNT(*) FROM account_identifiers;") == 0)

        let prepared = try await engine.prepareImport(from: source)
        let result = await engine.commitPreparedImport(prepared, accountChoice: .createNewAccount(displayName: "  Everyday bank  "))
        #expect(result.persisted)
        let accountID = try #require(result.accountId)
        let saved = try #require(try provider.accountRepo.account(id: accountID))
        #expect(saved.name == "Everyday bank")
        #expect(saved.accountType == "bank" && saved.nativeCurrency == prepared.detectedCurrency)
        #expect(accounts.accounts.first?.name == "Everyday bank")

        let duplicate = try await engine.prepareImport(from: source)
        let replay = await engine.commitPreparedImport(duplicate, accountChoice: .createNewAccount(displayName: "Must not rename"))
        #expect(!replay.persisted)
        #expect(try provider.accountRepo.account(id: accountID) == saved)
        sqlite.database.close()
        let reopened = try SQLiteRepositoryProvider(path: path)
        defer { reopened.database.close() }
        #expect(try reopened.accountRepo.account(id: accountID) == saved)
    }

    @Test(.globalRuntimeStateIsolation)
    func competingSameProcessConfirmationsProduceOneFinancialHistory() async throws {
        let provider = InMemoryRepositoryProvider()
        let firstCoordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            generationToken: provider.generationToken,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-competing-confirmations",
                workspaceName: "Competing Confirmations"
            )
        )
        let secondCoordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            generationToken: provider.generationToken,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-competing-confirmations",
                workspaceName: "Competing Confirmations"
            )
        )
        let firstEngine = availableImportEngine(firstCoordinator, providerGeneration: provider.generationToken)
        let secondEngine = availableImportEngine(secondCoordinator, providerGeneration: provider.generationToken)
        let source = try AuthenticSourceTestSupport.axisBankCSV()
        let first = try await firstEngine.prepareImport(from: source)
        let second = try await secondEngine.prepareImport(from: source)

        async let firstResult = firstEngine.commitPreparedImport(first, accountChoice: .createNewAccount(displayName: "Imported review account"))
        async let secondResult = secondEngine.commitPreparedImport(second, accountChoice: .createNewAccount(displayName: "Imported review account"))
        let results = await [firstResult, secondResult]

        #expect(results.filter(\.persisted).count == 1)
        #expect(results.filter { $0.previousImport != nil }.count == 1)
        #expect(try provider.accountRepo.accounts(workspaceId: "workspace-competing-confirmations").count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: "workspace-competing-confirmations").count == first.transactionCount)
        let successfulSessionIDs = [first, second].compactMap { prepared in
            try? provider.importSessionRepo.importSession(id: prepared.importSession.id.uuidString)
        }.compactMap { $0 }.filter { $0.validationStatus == "passed" }.map(\.id)
        #expect(successfulSessionIDs.count == 1)
        let prior = try #require(try provider.importSessionRepo.priorImportedStatement(
            algorithm: first.fingerprint.algorithm,
            fingerprint: first.fingerprint.digest
        ))
        #expect(prior.importSessionId == successfulSessionIDs[0])
        #expect(prior.transactionCount == first.transactionCount)
    }
}

@MainActor
private final class CountingPersistenceCoordinator: ImportPersistenceCoordinating {
    private(set) var persistCallCount = 0
    private(set) var legacyPersistCallCount = 0
    private(set) var fingerprintedPersistCallCount = 0
    private(set) var capturedFinancialDocument: FinancialDocument?
    private(set) var capturedImportSession: ImportSession?
    private(set) var capturedValidation: ImportValidationResult?
    private(set) var capturedFingerprint: ExactStatementFingerprint?
    var errorToThrow: Error?
    var resultOverride: ImportPersistenceResult?

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        legacyPersistCallCount += 1
        return try persist(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation
        )
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        nil
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        fingerprintedPersistCallCount += 1
        capturedFingerprint = fingerprint
        return try persist(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation
        )
    }

    private func persist(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        persistCallCount += 1
        capturedFinancialDocument = financialDocument
        capturedImportSession = importSession
        capturedValidation = validation

        if let errorToThrow {
            throw errorToThrow
        }

        if let resultOverride {
            return resultOverride
        }

        return ImportPersistenceResult(
            persisted: validation.passed,
            workspaceId: validation.passed ? "workspace-confirmation-test" : nil,
            accountId: validation.passed ? "account-confirmation-test" : nil,
            importSessionId: validation.passed ? importSession.id.uuidString : nil,
            transactionCount: validation.passed ? financialDocument.transactions.count : 0
        )
    }
}

@MainActor
private func resetRuntimeStoresForConfirmationWorkflow() async {
    LedgerForgeApp.configureInMemoryPersistenceForTesting()
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
    DocumentStore.shared.clear()
    await Task.yield()
}

@MainActor
private func availableImportEngine(_ persistence: ImportPersistenceCoordinating, providerGeneration: ProviderGenerationToken? = nil) -> ImportEngine {
    ImportEngine(
        importPersistenceCoordinator: persistence,
        persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
        providerGenerationProvider: { providerGeneration ?? DatabaseProvider.shared.generationToken },
        forcedHydration: {
            RepositoryStoreHydrationResult(
                didHydrate: true,
                accountCount: 0,
                transactionCount: 0,
                importSessionCount: 0,
                importAttemptCount: 0
            )
        }
    )
}

private enum ConfirmationPersistenceError: Error, LocalizedError {
    case writeFailed

    var errorDescription: String? {
        "Repository write failed."
    }
}
