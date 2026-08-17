import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct StatementEquivalenceProviderTests {
    @Test func bothOrdersRetainOneEventSetAcrossMemoryAndSQLite() async throws {
        let documents = try await pairedDocuments()

        for order in [documents, Array(documents.reversed())] {
            let memory = InMemoryRepositoryProvider()
            let memoryProvider = provider(memory)
            try assertEquivalentSequence(Array(order), provider: memoryProvider)

            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let databaseURL = folder.appendingPathComponent("equivalence.sqlite")
            var sqlite: SQLiteRepositoryProvider? = try SQLiteRepositoryProvider(path: databaseURL.path)
            try assertEquivalentSequence(Array(order), provider: provider(try #require(sqlite)))
            sqlite?.database.close()
            sqlite = nil

            let reopened = try SQLiteRepositoryProvider(path: databaseURL.path)
            defer { reopened.database.close() }
            let reopenedProvider = provider(reopened)
            try assertDurableShape(reopenedProvider)
            let snapshot = try RepositoryStoreHydrator(
                databaseProvider: reopenedProvider,
                workspaceId: "default-workspace",
                categoryReconciliationGate: nil,
                participatesInLifecycleGate: false
            ).stageHydration()
            #expect(snapshot.transactions.count == 4)
            #expect(snapshot.importSessions.count == 2)
            #expect(snapshot.importAttempts.count == 3)
        }
    }

    @Test func everySupportingWriteFailureRollsBackAcceptedResidue() async throws {
        let documents = try await pairedDocuments()

        for point in SupportingSourceFailureInjectionPoint.allCases {
            let memory = InMemoryRepositoryProvider()
            let runtime = provider(memory)
            let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: runtime)
            let first = try persist(documents[0], sequence: "failure-first-\(String(describing: point))", coordinator: coordinator, provider: runtime, createAccount: true)
            #expect(first.persisted)
            memory.injectSupportingSourceFailure(after: point)
            var didReject = false
            do {
                _ = try persist(documents[1], sequence: "failure-second-\(String(describing: point))", coordinator: coordinator, provider: runtime, createAccount: false)
            } catch {
                didReject = true
            }
            #expect(didReject)
            #expect(try runtime.transactionRepo.trustedTransactions(workspaceId: "default-workspace").count == 4)
            #expect(try runtime.importSessionRepo.statementFinancialProjections(workspaceId: "default-workspace").count == 1)
            #expect(try runtime.importSessionRepo.statementEquivalenceGroups(workspaceId: "default-workspace").count == 1)
            #expect(try runtime.importSessionRepo.statementEquivalenceMembers(workspaceId: "default-workspace").count == 1)
            #expect(try runtime.importSessionRepo.importAttempts(workspaceId: "default-workspace").filter {
                $0.persistenceCode == ImportAttemptPersistence.committed.rawValue
            }.count == 1)
        }
    }

    @Test func oneFieldCrossFormatMismatchRejectsWithoutFinancialResidue() async throws {
        let xls = try await pairedDocuments()[1]
        let mismatchPDF = try await parsedPDF(
            named: "hdfc_bank_account_pdf_v1_financial_mismatch_synthetic.pdf"
        )

        try runForEachProvider { runtime in
            let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: runtime)
            #expect(try persist(
                xls,
                sequence: "conflict-authoritative",
                coordinator: coordinator,
                provider: runtime,
                createAccount: true
            ).persisted)

            do {
                _ = try persist(
                    mismatchPDF,
                    sequence: "conflict-candidate",
                    coordinator: coordinator,
                    provider: runtime,
                    createAccount: false
                )
                Issue.record("Expected an exact cross-format projection conflict.")
            } catch let failure as ImportPersistenceCommitFailure {
                #expect(failure.originalError as? ImportPersistenceCoordinationError == .statementEquivalenceConflict)
                let attempt = try #require(runtime.importSessionRepo.importAttempts(workspaceId: "default-workspace").first {
                    $0.id == failure.importAttemptId
                })
                #expect(attempt.outcomeCode == ImportAttemptOutcome.statementEquivalenceConflict.rawValue)
                #expect(attempt.persistenceCode == ImportAttemptPersistence.rejectedRecorded.rawValue)
            }

            try assertOnlyAuthoritativeResidue(runtime)
        }
    }

    @Test func byteDifferentSameFormatRejectsWithoutFinancialResidue() async throws {
        let pdf = try await pairedDocuments()[0]

        try runForEachProvider { runtime in
            let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: runtime)
            #expect(try persist(
                pdf,
                sequence: "same-format-authoritative",
                coordinator: coordinator,
                provider: runtime,
                createAccount: true
            ).persisted)

            do {
                _ = try persist(
                    pdf,
                    sequence: "same-format-byte-different",
                    coordinator: coordinator,
                    provider: runtime,
                    createAccount: false
                )
                Issue.record("Expected a same-format equivalence rejection.")
            } catch let failure as ImportPersistenceCommitFailure {
                #expect(failure.originalError as? ImportPersistenceCoordinationError == .equivalentFormatAlreadyRecorded)
                let attempt = try #require(runtime.importSessionRepo.importAttempts(workspaceId: "default-workspace").first {
                    $0.id == failure.importAttemptId
                })
                #expect(attempt.outcomeCode == ImportAttemptOutcome.equivalentFormatAlreadyRecorded.rawValue)
                #expect(attempt.persistenceCode == ImportAttemptPersistence.rejectedRecorded.rawValue)
            }

            try assertOnlyAuthoritativeResidue(runtime)
        }
    }

    @Test func exactPreV10EventOverlapFailsClosedWithoutInventedEquivalence() async throws {
        let documents = try await pairedDocuments()

        try runForEachProvider { runtime in
            try seedPreV10History(documents[0], provider: runtime)
            let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: runtime)

            do {
                _ = try persist(
                    documents[1],
                    sequence: "pre-v10-candidate",
                    coordinator: coordinator,
                    provider: runtime,
                    createAccount: false
                )
                Issue.record("Expected missing pre-V10 equivalence evidence to block the import.")
            } catch let failure as ImportPersistenceCommitFailure {
                #expect(failure.originalError as? ImportPersistenceCoordinationError == .statementEquivalenceEvidenceUnavailable)
                let attempt = try #require(runtime.importSessionRepo.importAttempts(workspaceId: "default-workspace").first {
                    $0.id == failure.importAttemptId
                })
                #expect(attempt.outcomeCode == ImportAttemptOutcome.statementEquivalenceEvidenceUnavailable.rawValue)
                #expect(attempt.persistenceCode == ImportAttemptPersistence.rejectedRecorded.rawValue)
            }

            #expect(try runtime.transactionRepo.trustedTransactions(workspaceId: "default-workspace").count == 4)
            #expect(try runtime.importSessionRepo.statementFinancialProjections(workspaceId: "default-workspace").isEmpty)
            #expect(try runtime.importSessionRepo.statementEquivalenceGroups(workspaceId: "default-workspace").isEmpty)
            #expect(try runtime.importSessionRepo.statementEquivalenceMembers(workspaceId: "default-workspace").isEmpty)
            #expect(try runtime.importSessionRepo.importAttempts(workspaceId: "default-workspace").filter {
                $0.persistenceCode == ImportAttemptPersistence.committed.rawValue
            }.count == 1)
        }
    }

    private func assertEquivalentSequence(
        _ documents: [FinancialDocument],
        provider: DatabaseProvider
    ) throws {
        let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: provider)
        let first = try persist(documents[0], sequence: "first-\(documents[0].metadata.fileFormat.rawValue)", coordinator: coordinator, provider: provider, createAccount: true)
        #expect(first.persisted)
        #expect(first.transactionCount == 4)
        #expect(!first.isEquivalentSupportingSource)

        let second = try persist(documents[1], sequence: "second-\(documents[1].metadata.fileFormat.rawValue)", coordinator: coordinator, provider: provider, createAccount: false)
        #expect(second.persisted)
        #expect(second.transactionCount == 0)
        #expect(second.isEquivalentSupportingSource)
        try assertDurableShape(provider)

        let exactReimport = try persist(documents[1], sequence: "second-\(documents[1].metadata.fileFormat.rawValue)", coordinator: coordinator, provider: provider, createAccount: false)
        #expect(!exactReimport.persisted)
        #expect(exactReimport.previousImport != nil)
        #expect(try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: "default-workspace").count == 2)
    }

    private func assertDurableShape(_ provider: DatabaseProvider) throws {
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        let projections = try provider.importSessionRepo.statementFinancialProjections(workspaceId: "default-workspace")
        let groups = try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: "default-workspace")
        let members = try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: "default-workspace")
        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: "default-workspace")
        #expect(transactions.count == 4)
        #expect(projections.count == 2)
        #expect(groups.count == 1)
        #expect(members.count == 2)
        #expect(members.filter { $0.role == .authoritative }.count == 1)
        #expect(members.filter { $0.role == .supporting }.count == 1)
        #expect(Set(members.map(\.sourceFormatCode)) == ["pdf", "xls"])
        #expect(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue }.count == 1)
        #expect(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.equivalentSourceRecorded.rawValue }.count == 1)
        #expect(Set(transactions.compactMap(\.importSessionId)).count == 1)
    }

    private func assertOnlyAuthoritativeResidue(_ provider: DatabaseProvider) throws {
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace").count == 4)
        #expect(try provider.importSessionRepo.statementFinancialProjections(workspaceId: "default-workspace").count == 1)
        #expect(try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: "default-workspace").count == 1)
        let members = try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: "default-workspace")
        #expect(members.count == 1)
        #expect(members.first?.role == .authoritative)
    }

    private func runForEachProvider(_ body: (DatabaseProvider) throws -> Void) throws {
        let memory = InMemoryRepositoryProvider()
        try body(provider(memory))

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("equivalence.sqlite").path)
        defer { sqlite.database.close() }
        try body(provider(sqlite))
    }

    private func persist(
        _ document: FinancialDocument,
        sequence: String,
        coordinator: DefaultImportPersistenceCoordinator,
        provider: DatabaseProvider,
        createAccount: Bool
    ) throws -> ImportPersistenceResult {
        let validation = ImportValidator.validate(financialDocument: document)
        #expect(validation.passed)
        let session = ImportSession(
            fileName: "invented-\(sequence).\(document.metadata.fileFormat.rawValue.lowercased())",
            institution: .hdfc,
            documentType: .bankAccount,
            parserName: document.parserName,
            transactionCount: document.transactions.count,
            validation: validation
        )
        return try coordinator.persistValidatedImport(
            financialDocument: document,
            importSession: session,
            validation: validation,
            fingerprintSet: fingerprintSet(sequence),
            accountChoice: createAccount ? .createNewAccount : nil,
            providerGeneration: provider.generationToken
        )
    }

    private func seedPreV10History(
        _ document: FinancialDocument,
        provider: DatabaseProvider
    ) throws {
        let validation = ImportValidator.validate(financialDocument: document)
        #expect(validation.passed)
        let session = ImportSession(
            fileName: "invented-pre-v10.\(document.metadata.fileFormat.rawValue.lowercased())",
            institution: .hdfc,
            documentType: .bankAccount,
            parserName: document.parserName,
            transactionCount: document.transactions.count,
            validation: validation
        )
        let plan = try ImportPersistenceMapper().confirmedImportPlan(
            financialDocument: document,
            importSession: session,
            validation: validation,
            fingerprintSet: fingerprintSet("pre-v10-authoritative"),
            providerGeneration: provider.generationToken,
            advisoryIdentity: .noMatch,
            accountChoice: .createProposedAccount,
            selectedAccountId: "pre-v10-account"
        )
        let preV10Plan = ConfirmedImportPlanDTO(
            providerGeneration: plan.providerGeneration,
            workspace: plan.workspace,
            proposedAccount: plan.proposedAccount,
            accountChoice: plan.accountChoice,
            advisoryIdentity: plan.advisoryIdentity,
            identifiers: plan.identifiers,
            historyTemplate: plan.historyTemplate,
            transactionTemplates: plan.transactionTemplates,
            declaredStatementStartISO: plan.declaredStatementStartISO,
            declaredStatementEndISO: plan.declaredStatementEndISO,
            openingBalanceMinor: plan.openingBalanceMinor,
            openingBalanceDecimal: plan.openingBalanceDecimal,
            closingBalanceMinor: plan.closingBalanceMinor,
            closingBalanceDecimal: plan.closingBalanceDecimal,
            statementFinancialProjection: nil
        )
        #expect(provider.confirmedImportRepo.commitConfirmedImport(preV10Plan).description == "Confirmed import committed.")
    }

    private func fingerprintSet(_ seed: String) -> PreparedDocumentFingerprintSet {
        PreparedDocumentFingerprintSet(fingerprints: [
            VersionedDocumentFingerprint(
                algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm,
                digest: digest("raw-\(seed)"),
                byteCount: 100,
                isDuplicateAuthority: false
            ),
            VersionedDocumentFingerprint(
                algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
                digest: digest("bytes-\(seed)"),
                byteCount: 200,
                isDuplicateAuthority: true
            )
        ])
    }

    private func digest(_ seed: String) -> String {
        SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func provider(_ memory: InMemoryRepositoryProvider) -> DatabaseProvider {
        DatabaseProvider(
            workspaceRepo: memory.workspaceRepo,
            transactionRepo: memory.transactionRepo,
            categoryRepo: memory.categoryRepo,
            accountRepo: memory.accountRepo,
            cardRepo: memory.cardRepo,
            importSessionRepo: memory.importSessionRepo,
            confirmedImportRepo: memory.confirmedImportRepo,
            generationToken: memory.generationToken,
            persistenceState: .intentionalNonDurable(.testMemory)
        )
    }

    private func provider(_ sqlite: SQLiteRepositoryProvider) -> DatabaseProvider {
        DatabaseProvider(
            workspaceRepo: sqlite.workspaceRepo,
            transactionRepo: sqlite.transactionRepo,
            categoryRepo: sqlite.categoryRepo,
            accountRepo: sqlite.accountRepo,
            cardRepo: sqlite.cardRepo,
            importSessionRepo: sqlite.importSessionRepo,
            confirmedImportRepo: sqlite.confirmedImportRepo,
            generationToken: sqlite.generationToken,
            persistenceState: .verifiedSQLite
        )
    }

    private func pairedDocuments() async throws -> [FinancialDocument] {
        let pdf = try await parsedPDF(named: "hdfc_bank_account_pdf_v1_nre_synthetic.pdf")
        let xls = try HDFCBankAccountXLSParser().parse(
            document: await HDFCXLSFixtureTestSupport.normalized(HDFCXLSFixtureTestSupport.annualFixture)
        )
        return [pdf, xls]
    }

    private func parsedPDF(named name: String) async throws -> FinancialDocument {
        let pdfURL = FixtureLocator.hdfcSyntheticPDF(name)
        let bytes = try Data(contentsOf: pdfURL)
        let snapshot = SourceContentSnapshot(bytes: bytes)
        defer { snapshot.invalidate() }
        let raw = try await PDFDocumentReader().read(
            request: ImportRequest(fileURL: pdfURL),
            snapshot: snapshot,
            password: nil
        )
        let result = try HDFCBankAccountPDFNormalizer().normalize(
            text: raw.searchableText,
            sourceBytes: bytes,
            fileURL: pdfURL
        )
        let normalizedPDF = NormalizedDocument(
            document: result.document,
            metadata: DocumentMetadata(institution: .hdfc, documentType: .bankAccount, fileFormat: .pdf, confidence: 0.99),
            rows: result.rows,
            header: result.header,
            sourceContext: result.sourceContext
        )
        return try HDFCBankAccountPDFParser().parse(document: normalizedPDF)
    }
}
