import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct AxisSharedBankAccountProfileTests {
    private let workspaceID = "workspace-axis-shared-profile"

    @Test func productionPathAndIndependentOraclesAcceptSharedNREAndNROLayout() async throws {
        let provider = DatabaseProvider(inMemory: true)
        let coordinator = persistenceCoordinator(provider)
        let engine = importEngine(provider, coordinator: coordinator)
        let fixtures = [
            ("axis_bank_nre_account_statement_baseline.csv", 81),
            ("axis_bank_nre_account_statement_overlap.csv", 31),
            ("axis_bank_nro_account_statement_baseline_csv_source_truth.csv", 17),
            ("axis_bank_nro_account_statement_extended.csv", 20)
        ]

        var parsedIdentifiers: [String: String] = [:]
        for (name, count) in fixtures {
            let prepared = try await engine.prepareImport(from: FixtureLocator.axisCSV(name))
            let identifier = try #require(prepared.financialDocument.financialIdentifiers.first)

            #expect(prepared.detectedInstitution == .axis)
            #expect(prepared.detectedDocumentType == .bankAccount)
            #expect(prepared.parserName == "Axis Bank Account")
            #expect(prepared.transactionCount == count)
            #expect(prepared.validation.passed)
            #expect(prepared.detectedCurrency == "INR")
            #expect(prepared.financialDocument.financialIdentifiers.count == 1)
            #expect(identifier.kind == .institutionAccountId)
            #expect(identifier.strength == .strong)
            #expect(identifier.verificationState == .verified)
            #expect(identifier.provenance == .institutionStructuredField)
            #expect(prepared.financialDocument.transactions.allSatisfy {
                $0.statementTimezoneEvidence == .iana("Asia/Kolkata")
            })
            #expect(prepared.financialDocument.transactions.flatMap(\.sourceProvenance).allSatisfy {
                $0.parserProfileID == AxisBankAccountParser.profileID &&
                $0.parserProfileVersion == AxisBankAccountParser.profileVersion
            })
            parsedIdentifiers[name] = identifier.normalizedValue
        }

        #expect(parsedIdentifiers["axis_bank_nre_account_statement_baseline.csv"] ==
                parsedIdentifiers["axis_bank_nre_account_statement_overlap.csv"])
        #expect(parsedIdentifiers["axis_bank_nro_account_statement_baseline_csv_source_truth.csv"] ==
                parsedIdentifiers["axis_bank_nro_account_statement_extended.csv"])
        #expect(parsedIdentifiers["axis_bank_nre_account_statement_baseline.csv"] !=
                parsedIdentifiers["axis_bank_nro_account_statement_baseline_csv_source_truth.csv"])

        for (csv, expected) in [
            ("axis_bank_nro_account_statement_baseline_csv_source_truth.csv",
             "axis_bank_nro_account_statement_baseline_csv_source_truth.expected.json"),
            ("axis_bank_nro_account_statement_extended.csv",
             "axis_bank_nro_account_statement_extended.expected.json")
        ] {
            let oracle = try CleanRoomAxisBankCSVOracle.load(csv: csv, expected: expected)
            let prepared = try await engine.prepareImport(from: FixtureLocator.axisCSV(csv))
            #expect(oracle.transactions == prepared.financialDocument.transactions.map(CleanRoomAxisTransaction.init))
            #expect(oracle.openingBalance == prepared.validation.openingBalance)
            #expect(oracle.closingBalance == prepared.validation.closingBalance)
            #expect(oracle.debitTotal == prepared.validation.debitTotal)
            #expect(oracle.creditTotal == prepared.validation.creditTotal)
            #expect(oracle.runningBalanceFailures.isEmpty)
            #expect(oracle.accountIdentifier ==
                    prepared.financialDocument.financialIdentifiers.first?.normalizedValue)
        }
    }

    @Test func sharedRuntimeEnginePreservesAxisDebitCreditSemantics() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        defer {
            DatabaseProvider.shared.invalidateGeneration()
            DatabaseProvider.shared = .unavailable(reason: .notInitialized)
        }
        let prepared = try await ImportEngine.shared.prepareImport(
            from: FixtureLocator.axisCSV(
                "axis_bank_nro_account_statement_baseline_csv_source_truth.csv"
            )
        )

        #expect(prepared.validation.passed)
        #expect(prepared.financialDocument.transactions.first?.credit == Decimal(4_221))
        #expect(prepared.financialDocument.transactions.dropFirst().first?.debit == Decimal(500))
    }

    @Test func cleanRoomIdentityMatrixShowsCustomerContextIsNonAuthoritative() throws {
        let nreBaseline = try CleanRoomAxisIdentityEvidence.load(
            "axis_bank_nre_account_statement_baseline.csv"
        )
        let nreOverlap = try CleanRoomAxisIdentityEvidence.load(
            "axis_bank_nre_account_statement_overlap.csv"
        )
        let nroBaseline = try CleanRoomAxisIdentityEvidence.load(
            "axis_bank_nro_account_statement_baseline_csv_source_truth.csv"
        )
        let nroExtended = try CleanRoomAxisIdentityEvidence.load(
            "axis_bank_nro_account_statement_extended.csv"
        )

        #expect(nreBaseline.accountIdentifier == nreOverlap.accountIdentifier)
        #expect(nroBaseline.accountIdentifier == nroExtended.accountIdentifier)
        #expect(nreBaseline.accountIdentifier != nroBaseline.accountIdentifier)
        #expect(nreBaseline.customerID == nroBaseline.customerID)
        #expect(nroBaseline.customerID == nroExtended.customerID)
    }

    @Test func mapperDerivesOneExactProfileAndRejectsMissingMalformedOrConflictingPairs() async throws {
        let provider = DatabaseProvider(inMemory: true)
        let coordinator = persistenceCoordinator(provider)
        let prepared = try await importEngine(provider, coordinator: coordinator)
            .prepareImport(from: FixtureLocator.axisCSV("axis_bank_nro_account_statement_baseline_csv_source_truth.csv"))
        let mapper = ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Axis Shared Profile")
        let payload = try mapper.payload(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            accountId: "account-profile",
            fingerprint: prepared.fingerprint
        )

        #expect(payload.normalizedDocument.profileId == AxisBankAccountParser.profileID)
        #expect(payload.normalizedDocument.profileVersion == AxisBankAccountParser.profileVersion)
        #expect(payload.transactions.flatMap(\.rawRows).allSatisfy {
            $0.parserProfileId == AxisBankAccountParser.profileID &&
            $0.parserProfileVersion == AxisBankAccountParser.profileVersion
        })

        for (provenance, expectedError) in [
            (TransactionSourceProvenance(
                normalizedDocumentID: "document", normalizedRowID: "row", sourceOrdinal: 1,
                normalizedRecordDigest: String.normalizedRecordDigest(values: ["missing"]),
                parserProfileID: "", parserProfileVersion: "1"
            ), ImportPersistenceError.missingParserProfileProvenance),
            (TransactionSourceProvenance(
                normalizedDocumentID: "document", normalizedRowID: "row", sourceOrdinal: 1,
                normalizedRecordDigest: String.normalizedRecordDigest(values: ["malformed"]),
                parserProfileID: " axis.bank-account.csv", parserProfileVersion: "1"
            ), ImportPersistenceError.malformedParserProfileProvenance)
        ] {
            let invalid = replacingProvenance(
                in: prepared.financialDocument,
                first: provenance,
                remaining: provenance
            )
            #expect(throws: expectedError) {
                _ = try mapper.payload(
                    financialDocument: invalid,
                    importSession: prepared.importSession,
                    validation: prepared.validation,
                    accountId: "account-profile",
                    fingerprint: prepared.fingerprint
                )
            }
        }

        let first = prepared.financialDocument.transactions[0].sourceProvenance[0]
        let conflict = TransactionSourceProvenance(
            normalizedDocumentID: first.normalizedDocumentID,
            normalizedRowID: first.normalizedRowID,
            sourceOrdinal: first.sourceOrdinal,
            normalizedRecordDigest: first.normalizedRecordDigest,
            parserProfileID: "conflicting.profile",
            parserProfileVersion: "2"
        )
        let conflicting = replacingProvenance(
            in: prepared.financialDocument,
            first: first,
            remaining: conflict
        )
        #expect(throws: ImportPersistenceError.conflictingParserProfileProvenance) {
            _ = try mapper.payload(
                financialDocument: conflicting,
                importSession: prepared.importSession,
                validation: prepared.validation,
                accountId: "account-profile",
                fingerprint: prepared.fingerprint
            )
        }
        #expect(try provider.workspaceRepo.workspace(id: workspaceID) == nil)
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
    }

    @Test func distinctAccountLifecycleAndHydrationMatchSQLiteAndInMemory() async throws {
        try await withProviders { provider in
            let coordinator = persistenceCoordinator(provider)
            let engine = importEngine(provider, coordinator: coordinator)
            let nreFirst = try await engine.prepareImport(
                from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
            )
            let nroFirst = try await engine.prepareImport(
                from: FixtureLocator.axisCSV("axis_bank_nro_account_statement_baseline_csv_source_truth.csv")
            )
            let nreIdentifier = try #require(nreFirst.financialDocument.financialIdentifiers.first)
            let nroIdentifier = try #require(nroFirst.financialDocument.financialIdentifiers.first)

            let nreResult = try coordinator.persistValidatedImport(
                financialDocument: nreFirst.financialDocument,
                importSession: nreFirst.importSession,
                validation: nreFirst.validation,
                fingerprint: nreFirst.fingerprint,
                accountChoice: .createNewAccount,
                providerGeneration: provider.generationToken
            )
            let nreAccountID = try #require(nreResult.accountId)
            #expect(nreResult.persisted)
            let initialNROResolution = try FinancialIdentityResolver(
                accountRepository: provider.accountRepo,
                developerConsole: nil
            ).resolve(
                workspaceId: workspaceID,
                identifiers: nroFirst.financialDocument.financialIdentifiers
            )
            #expect(initialNROResolution == .noMatch)

            let nroResult = try coordinator.persistValidatedImport(
                financialDocument: nroFirst.financialDocument,
                importSession: nroFirst.importSession,
                validation: nroFirst.validation,
                fingerprint: nroFirst.fingerprint,
                accountChoice: .createNewAccount,
                providerGeneration: provider.generationToken
            )
            let nroAccountID = try #require(nroResult.accountId)
            #expect(nroResult.persisted)
            #expect(nreAccountID != nroAccountID)
            #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).count == 2)

            let nroLater = try await engine.prepareImport(
                from: FixtureLocator.axisCSV("axis_bank_nro_account_statement_extended.csv")
            )
            let laterNROResolution = try FinancialIdentityResolver(
                accountRepository: provider.accountRepo,
                developerConsole: nil
            ).resolve(
                workspaceId: workspaceID,
                identifiers: nroLater.financialDocument.financialIdentifiers
            )
            #expect(laterNROResolution == .resolved(accountId: nroAccountID))
            let nroLaterResult = try coordinator.persistValidatedImport(
                financialDocument: nroLater.financialDocument,
                importSession: nroLater.importSession,
                validation: nroLater.validation,
                fingerprint: nroLater.fingerprint,
                accountChoice: nil,
                providerGeneration: provider.generationToken
            )
            #expect(nroLaterResult.persisted)
            #expect(nroLaterResult.accountId == nroAccountID)

            let nreLater = try await engine.prepareImport(
                from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_overlap.csv")
            )
            let laterNREResolution = try FinancialIdentityResolver(
                accountRepository: provider.accountRepo,
                developerConsole: nil
            ).resolve(
                workspaceId: workspaceID,
                identifiers: nreLater.financialDocument.financialIdentifiers
            )
            #expect(laterNREResolution == .resolved(accountId: nreAccountID))
            let nreLaterResult = try coordinator.persistValidatedImport(
                financialDocument: nreLater.financialDocument,
                importSession: nreLater.importSession,
                validation: nreLater.validation,
                fingerprint: nreLater.fingerprint,
                accountChoice: nil,
                providerGeneration: provider.generationToken
            )
            #expect(!nreLaterResult.persisted)
            if case .existing(let count) = nreLaterResult.transactionEventBlock {
                #expect(count == 15)
            } else {
                Issue.record("Expected supported account-scoped event overlap blocking.")
            }

            let duplicate = try coordinator.persistValidatedImport(
                financialDocument: nroLater.financialDocument,
                importSession: nroLater.importSession,
                validation: nroLater.validation,
                fingerprint: nroLater.fingerprint,
                accountChoice: nil,
                providerGeneration: provider.generationToken
            )
            #expect(!duplicate.persisted)
            #expect(duplicate.previousImport != nil)

            let nreOwned = try provider.accountRepo.identifiers(
                accountId: nreAccountID, workspaceId: workspaceID
            )
            let nroOwned = try provider.accountRepo.identifiers(
                accountId: nroAccountID, workspaceId: workspaceID
            )
            #expect(nreOwned.count == 1 && nreOwned[0].identifier == nreIdentifier.normalizedValue)
            #expect(nroOwned.count == 1 && nroOwned[0].identifier == nroIdentifier.normalizedValue)
            #expect(try provider.accountRepo.accountIds(
                workspaceId: workspaceID,
                scheme: nreIdentifier.kind.rawValue,
                identifier: nreIdentifier.normalizedValue
            ) == [nreAccountID])
            #expect(try provider.accountRepo.accountIds(
                workspaceId: workspaceID,
                scheme: nroIdentifier.kind.rawValue,
                identifier: nroIdentifier.normalizedValue
            ) == [nroAccountID])

            resetRuntimeStores()
            let reconstructed = DatabaseProvider(
                workspaceRepo: provider.workspaceRepo,
                transactionRepo: provider.transactionRepo,
                accountRepo: provider.accountRepo,
                importSessionRepo: provider.importSessionRepo,
                confirmedImportRepo: provider.confirmedImportRepo,
                generationToken: provider.generationToken,
                persistenceState: provider.persistenceState
            )
            let hydration = try RepositoryStoreHydrator(
                databaseProvider: reconstructed,
                workspaceId: workspaceID,
                participatesInLifecycleGate: false
            ).hydrateIfNeeded()
            #expect(hydration.accountCount == 2)
            #expect(AccountStore.shared.accounts.count == 2)
            #expect(AccountStore.shared.accounts.allSatisfy {
                $0.name == "Axis Bank INR" && $0.type == .bank && $0.identitySummaries.count == 1
            })
            #expect(AccountStore.shared.accounts.flatMap(\.identitySummaries).allSatisfy {
                $0.redactedValue.hasPrefix("*") &&
                !$0.redactedValue.contains(nreIdentifier.normalizedValue) &&
                !$0.redactedValue.contains(nroIdentifier.normalizedValue)
            })
            #expect(!AccountStore.shared.accounts.map(\.name).joined().contains("NRE"))
            #expect(!AccountStore.shared.accounts.map(\.name).joined().contains("NRO"))
        }
    }

    @Test func historicalAxisNREProfileIsReadBackExactlyWithoutRewriting() throws {
        try withSynchronousProviders { provider in
            let base = confirmedImportPlan(
                generationToken: provider.generationToken,
                identifier: "LEGACY-AXIS-PROFILE",
                fingerprint: UUID().uuidString,
                suffix: UUID().uuidString
            )
            let plan = replacingProfile(
                in: base,
                id: "axis.nre.csv",
                version: "1"
            )
            guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
                Issue.record("Expected directly seeded historical profile to commit.")
                return
            }
            let transactions = try provider.transactionRepo.trustedTransactions(
                workspaceId: plan.workspace.id
            )
            #expect(transactions.count == 1)
            let transaction = try #require(transactions.first)
            let rawRow = try #require(transaction.rawRows.first)
            #expect(rawRow.parserProfileId == "axis.nre.csv")
            #expect(rawRow.parserProfileVersion == "1")
        }
    }

    @Test func sharedProfileConfirmedImportFailuresLeaveZeroAcceptedResidue() async throws {
        let preparationProvider = DatabaseProvider(inMemory: true)
        let preparationCoordinator = persistenceCoordinator(preparationProvider)
        let prepared = try await importEngine(
            preparationProvider,
            coordinator: preparationCoordinator
        ).prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        let mapper = ImportPersistenceMapper(
            workspaceId: workspaceID,
            workspaceName: "Axis Shared Profile"
        )

        for point in ConfirmedImportFailureInjectionPoint.allCases {
            let rawProvider = InMemoryRepositoryProvider()
            let plan = try mapper.confirmedImportPlan(
                financialDocument: prepared.financialDocument,
                importSession: prepared.importSession,
                validation: prepared.validation,
                fingerprint: prepared.fingerprint,
                providerGeneration: rawProvider.generationToken,
                advisoryIdentity: .noMatch,
                accountChoice: .createProposedAccount,
                selectedAccountId: "account-injected"
            )
            rawProvider.injectConfirmedImportFailure(after: point)

            #expect(rawProvider.confirmedImportRepo.commitConfirmedImport(plan) == .repositoryIntegrityConflict)
            #expect(try rawProvider.workspaceRepo.workspace(id: workspaceID) == nil)
            #expect(try rawProvider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
            #expect(try rawProvider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
            #expect(try rawProvider.importSessionRepo.importAttempts(workspaceId: workspaceID).isEmpty)
            #expect(try rawProvider.importSessionRepo.priorImportedStatement(
                algorithm: prepared.fingerprint.algorithm,
                fingerprint: prepared.fingerprint.digest
            ) == nil)
        }

        let sqliteFailures = [
            ("institutions", "INSERT"),
            ("workspaces", "INSERT"),
            ("accounts", "INSERT"),
            ("account_identifiers", "INSERT"),
            ("account_identifier_observations", "INSERT"),
            ("documents", "INSERT"),
            ("document_fingerprints", "INSERT"),
            ("import_sessions", "INSERT"),
            ("normalized_documents", "INSERT"),
            ("normalized_rows", "INSERT"),
            ("transactions", "INSERT"),
            ("transaction_raw_rows", "INSERT"),
            ("transaction_event_identities", "INSERT"),
            ("import_attempts", "INSERT"),
            ("import_sessions", "UPDATE")
        ]
        let residueTables = [
            "institutions", "workspaces", "accounts", "account_identifiers",
            "account_identifier_observations", "documents", "document_fingerprints",
            "import_sessions", "normalized_documents", "normalized_rows",
            "transactions", "transaction_raw_rows", "transaction_event_identities",
            "import_attempts"
        ]
        for (index, failure) in sqliteFailures.enumerated() {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("LedgerForge-AxisSQLiteFailure-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let provider = try SQLiteRepositoryProvider(
                path: folder.appendingPathComponent("failure.sqlite").path
            )
            defer { provider.database.close() }
            let plan = try mapper.confirmedImportPlan(
                financialDocument: prepared.financialDocument,
                importSession: prepared.importSession,
                validation: prepared.validation,
                fingerprint: prepared.fingerprint,
                providerGeneration: provider.generationToken,
                advisoryIdentity: .noMatch,
                accountChoice: .createProposedAccount,
                selectedAccountId: "account-sqlite-injected"
            )
            try provider.database.execute(
                sql: """
                CREATE TEMP TRIGGER injected_failure_\(index)
                BEFORE \(failure.1) ON \(failure.0)
                BEGIN
                    SELECT RAISE(ABORT, 'injected confirmed-import failure');
                END;
                """
            )

            #expect(provider.confirmedImportRepo.commitConfirmedImport(plan) == .repositoryIntegrityConflict)
            for table in residueTables {
                let count = try provider.database.query(
                    sql: "SELECT COUNT(*) FROM \(table);"
                ) { $0.int64(at: 0) ?? -1 }.first
                #expect(count == 0)
            }
        }
    }

    private func persistenceCoordinator(
        _ provider: DatabaseProvider
    ) -> DefaultImportPersistenceCoordinator {
        DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: workspaceID,
                workspaceName: "Axis Shared Profile"
            )
        )
    }

    private func importEngine(
        _ provider: DatabaseProvider,
        coordinator: DefaultImportPersistenceCoordinator
    ) -> ImportEngine {
        ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken }
        )
    }

    private func replacingProvenance(
        in document: FinancialDocument,
        first: TransactionSourceProvenance,
        remaining: TransactionSourceProvenance
    ) -> FinancialDocument {
        let transactions = document.transactions.enumerated().map { index, transaction in
            copy(transaction, provenance: [index == 0 ? first : remaining])
        }
        return FinancialDocument(
            id: document.id,
            sourceDocument: document.sourceDocument,
            metadata: document.metadata,
            parserName: document.parserName,
            bookedCurrency: document.bookedCurrency,
            transactions: transactions,
            financialIdentifiers: document.financialIdentifiers,
            selectionReasons: document.selectionReasons,
            createdAt: document.createdAt
        )
    }

    private func copy(
        _ transaction: Transaction,
        provenance: [TransactionSourceProvenance]
    ) -> Transaction {
        Transaction(
            statementDate: transaction.statementDate,
            description: transaction.description,
            debitMoney: transaction.debitMoney,
            creditMoney: transaction.creditMoney,
            money: transaction.money,
            runningBalanceMoney: transaction.runningBalanceMoney,
            account: transaction.account,
            sourceBank: transaction.sourceBank,
            sourceFile: transaction.sourceFile,
            id: transaction.id,
            repositoryTransactionId: transaction.repositoryTransactionId,
            financialDateRole: transaction.financialDateRole,
            statementTimezoneEvidence: transaction.statementTimezoneEvidence,
            sourceProvenance: provenance,
            repositoryAccountId: transaction.repositoryAccountId,
            repositoryImportSessionId: transaction.repositoryImportSessionId,
            verifiedAxisUPIEventEvidence: transaction.verifiedAxisUPIEventEvidence
        )
    }

    private func resetRuntimeStores() {
        AccountStore.shared.replaceAccounts([])
        TransactionStore.shared.replaceTransactions([])
        ImportSessionStore.shared.replaceImportSessions([])
        ImportAttemptStore.shared.replaceAttempts([])
    }
}

private struct CleanRoomAxisIdentityEvidence {
    let accountIdentifier: String
    let customerID: String

    static func load(_ fileName: String) throws -> Self {
        let text = try String(
            contentsOf: FixtureLocator.axisCSV(fileName),
            encoding: .utf8
        )
        let lines = text.components(separatedBy: .newlines)
        let accountPrefix = "Statement of Account No - "
        let periodMarker = " for the period ("
        let accountLine = try #require(lines.first { $0.hasPrefix(accountPrefix) })
        let accountRemainder = accountLine.dropFirst(accountPrefix.count)
        let period = try #require(accountRemainder.range(of: periodMarker))
        let accountIdentifier = String(accountRemainder[..<period.lowerBound])
        let customerPrefix = "Customer ID :- "
        let customerLine = try #require(lines.first { $0.hasPrefix(customerPrefix) })
        return Self(
            accountIdentifier: accountIdentifier,
            customerID: String(customerLine.dropFirst(customerPrefix.count))
        )
    }
}

private struct CleanRoomAxisTransaction: Equatable {
    let date: String
    let description: String
    let debit: Decimal?
    let credit: Decimal?
    let balance: Decimal?
    let sourceOrdinal: Int

    init(
        date: String,
        description: String,
        debit: Decimal?,
        credit: Decimal?,
        balance: Decimal?,
        sourceOrdinal: Int
    ) {
        self.date = date
        self.description = description
        self.debit = debit
        self.credit = credit
        self.balance = balance
        self.sourceOrdinal = sourceOrdinal
    }

    init(_ transaction: Transaction) {
        let date = transaction.statementDate!
        self.date = String(format: "%02d-%02d-%04d", date.day, date.month, date.year)
        self.description = transaction.description
        self.debit = transaction.debit
        self.credit = transaction.credit
        self.balance = transaction.balance
        self.sourceOrdinal = transaction.sourceProvenance[0].sourceOrdinal
    }
}

private struct CleanRoomAxisBankCSVOracle {
    let transactions: [CleanRoomAxisTransaction]
    let accountIdentifier: String
    let openingBalance: Decimal
    let closingBalance: Decimal
    let debitTotal: Decimal
    let creditTotal: Decimal
    let runningBalanceFailures: [Int]

    static func load(csv: String, expected: String) throws -> Self {
        let text = try String(
            contentsOf: FixtureLocator.axisCSV(csv),
            encoding: .utf8
        )
        let identity = try CleanRoomAxisIdentityEvidence.load(csv)
        let lines = text.components(separatedBy: .newlines)
        let headerIndex = try #require(lines.firstIndex {
            $0 == "Tran Date,CHQNO,PARTICULARS,DR,CR,BAL,SOL"
        })
        let transactions = lines.dropFirst(headerIndex + 1).enumerated().compactMap {
            offset, line -> CleanRoomAxisTransaction? in
            let cells = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            guard cells.count == 7,
                  cells[0].split(separator: "-").count == 3 else {
                return nil
            }
            return CleanRoomAxisTransaction(
                date: cells[0],
                description: cells[2],
                debit: Decimal(string: cells[3], locale: Locale(identifier: "en_US_POSIX")),
                credit: Decimal(string: cells[4], locale: Locale(identifier: "en_US_POSIX")),
                balance: Decimal(string: cells[5], locale: Locale(identifier: "en_US_POSIX")),
                sourceOrdinal: headerIndex + offset + 2
            )
        }
        let expectedData = try Data(contentsOf: FixtureLocator.axisExpected(expected))
        let expected = try JSONDecoder().decode(CleanRoomAxisExpected.self, from: expectedData)
        #expect(transactions == expected.transactions)
        let debitTotal = transactions.reduce(Decimal.zero) { $0 + ($1.debit ?? 0) }
        let creditTotal = transactions.reduce(Decimal.zero) { $0 + ($1.credit ?? 0) }
        let first = try #require(transactions.first)
        let opening = try #require(first.balance) + (first.debit ?? 0) - (first.credit ?? 0)
        var prior = opening
        var failures: [Int] = []
        for transaction in transactions {
            let expectedBalance = prior - (transaction.debit ?? 0) + (transaction.credit ?? 0)
            if expectedBalance != transaction.balance {
                failures.append(transaction.sourceOrdinal)
            }
            prior = transaction.balance ?? prior
        }
        return Self(
            transactions: transactions,
            accountIdentifier: identity.accountIdentifier,
            openingBalance: opening,
            closingBalance: try #require(transactions.last?.balance),
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            runningBalanceFailures: failures
        )
    }
}

private struct CleanRoomAxisExpected: Decodable {
    let transactions: [CleanRoomAxisTransaction]

    private enum CodingKeys: String, CodingKey {
        case transactions = "canonical_ordered_transactions"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try container.decode([Row].self, forKey: .transactions)
        transactions = rows.map {
            CleanRoomAxisTransaction(
                date: $0.date,
                description: $0.description,
                debit: $0.debit == "0" ? nil : Decimal(string: $0.debit),
                credit: $0.credit == "0" ? nil : Decimal(string: $0.credit),
                balance: Decimal(string: $0.balance),
                sourceOrdinal: $0.ordinal + 19
            )
        }
    }

    private struct Row: Decodable {
        let ordinal: Int
        let date: String
        let description: String
        let debit: String
        let credit: String
        let balance: String

        private enum CodingKeys: String, CodingKey {
            case ordinal
            case date = "transaction_date"
            case description
            case debit
            case credit
            case balance = "running_balance"
        }
    }
}

private func replacingProfile(
    in plan: ConfirmedImportPlanDTO,
    id: String,
    version: String
) -> ConfirmedImportPlanDTO {
    let document = plan.historyTemplate.normalizedDocument!
    let normalizedDocument = NormalizedDocumentDTO(
        id: document.id,
        importSessionId: document.importSessionId,
        documentId: document.documentId,
        profileId: id,
        profileVersion: version
    )
    let history = ConfirmedImportHistoryTemplateDTO(
        document: plan.historyTemplate.document,
        fingerprint: plan.historyTemplate.fingerprint,
        importSession: plan.historyTemplate.importSession,
        completedAtISO: plan.historyTemplate.completedAtISO,
        successfulAttempt: plan.historyTemplate.successfulAttempt,
        normalizedDocument: normalizedDocument,
        normalizedRows: plan.historyTemplate.normalizedRows
    )
    let templates = plan.transactionTemplates.map { template in
        let transaction = template.transaction
        return ConfirmedImportTransactionTemplateDTO(
            transaction: TransactionDTO(
                id: transaction.id,
                workspaceId: transaction.workspaceId,
                accountId: transaction.accountId,
                importSessionId: transaction.importSessionId,
                documentId: transaction.documentId,
                originalRowId: transaction.originalRowId,
                postedDateISO: transaction.postedDateISO,
                financialDateRole: transaction.financialDateRole,
                statementTimezoneEvidence: "iana:Asia/Kolkata",
                valueDateISO: transaction.valueDateISO,
                description: transaction.description,
                payee: transaction.payee,
                reference: transaction.reference,
                nativeCurrency: transaction.nativeCurrency,
                amountMinor: transaction.amountMinor,
                amountDecimal: transaction.amountDecimal,
                direction: transaction.direction,
                runningBalanceMinor: transaction.runningBalanceMinor,
                isReconciled: transaction.isReconciled,
                isTrusted: true,
                trustedAtISO: history.completedAtISO,
                createdAtISO: transaction.createdAtISO,
                updatedAtISO: transaction.updatedAtISO,
                rawRows: transaction.rawRows
            ),
            eventEvidence: template.eventEvidence
        )
    }
    return ConfirmedImportPlanDTO(
        providerGeneration: plan.providerGeneration,
        workspace: plan.workspace,
        proposedAccount: plan.proposedAccount,
        accountChoice: plan.accountChoice,
        advisoryIdentity: plan.advisoryIdentity,
        identifiers: plan.identifiers,
        historyTemplate: history,
        transactionTemplates: templates
    )
}

@MainActor
private func withProviders(
    _ body: (DatabaseProvider) async throws -> Void
) async throws {
    try await body(DatabaseProvider(inMemory: true))
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForge-AxisSharedProfile-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let sqlite = try SQLiteRepositoryProvider(
        path: folder.appendingPathComponent("axis-shared.sqlite").path
    )
    defer { sqlite.database.close() }
    try await body(.verifiedSQLite(sqlite, protectsGeneration: false))
}

private func withSynchronousProviders(
    _ body: (DatabaseProvider) throws -> Void
) throws {
    try body(DatabaseProvider(inMemory: true))
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForge-AxisLegacyProfile-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let sqlite = try SQLiteRepositoryProvider(
        path: folder.appendingPathComponent("axis-legacy.sqlite").path
    )
    defer { sqlite.database.close() }
    try body(.verifiedSQLite(sqlite, protectsGeneration: false))
}
