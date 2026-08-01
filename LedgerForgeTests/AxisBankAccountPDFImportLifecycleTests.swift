import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct AxisBankAccountPDFImportLifecycleTests {
    @Test(.globalRuntimeStateIsolation)
    func ordinaryURLPreparationUsesPDFSourceByteAuthorityAndDefersPersistence() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let persistence = AxisPDFImportPersistenceProbe()
        let generation = ProviderGenerationToken()
        let engine = makeEngine(
            persistence: persistence,
            generation: generation
        )
        let sourceURL = FixtureLocator.axisPDF(
            "axis_bank_nro_account_statement_baseline.pdf"
        )
        let sourceBytes = try Data(contentsOf: sourceURL)

        let prepared = try await engine.prepareImport(from: sourceURL)

        #expect(prepared.detectedInstitution == .axis)
        #expect(prepared.detectedDocumentType == .bankAccount)
        #expect(prepared.financialDocument.metadata.fileFormat == .pdf)
        #expect(prepared.financialDocument.sourceDocument.fileType == "PDF")
        #expect(prepared.parserName == "Axis Bank Account PDF")
        #expect(prepared.validation.passed)
        #expect(prepared.transactionCount == 16)
        #expect(prepared.validation.openingBalance == Decimal(string: "76799.39"))
        #expect(prepared.validation.debitTotal == Decimal(string: "111172.00"))
        #expect(prepared.validation.creditTotal == Decimal(string: "61850.61"))
        #expect(prepared.validation.closingBalance == Decimal(string: "27478.00"))
        #expect(prepared.providerGeneration == generation)
        #expect(persistence.persistInvocationCount == 0)

        let sourceFingerprint = try #require(
            prepared.fingerprintSet.fingerprints.first {
                $0.algorithm == SourceContentSnapshot.algorithm
            }
        )
        let rawTextFingerprint = try #require(
            prepared.fingerprintSet.fingerprints.first {
                $0.algorithm == ExactStatementFingerprint.algorithm
            }
        )
        #expect(prepared.fingerprintSet.fingerprints.count == 2)
        #expect(sourceFingerprint.isDuplicateAuthority)
        #expect(!rawTextFingerprint.isDuplicateAuthority)
        #expect(sourceFingerprint.byteCount == Int64(sourceBytes.count))
        #expect(prepared.fingerprint.algorithm == sourceFingerprint.algorithm)
        #expect(prepared.fingerprint.digest == sourceFingerprint.digest)
        #expect(prepared.fingerprint.byteCount == sourceFingerprint.byteCount)
        #expect(persistence.advisoryFingerprints == [prepared.fingerprint])

        let result = await engine.commitPreparedImport(
            prepared,
            accountChoice: .createNewAccount
        )

        #expect(result.succeeded)
        #expect(result.transactionCount == 16)
        #expect(persistence.persistInvocationCount == 1)
        #expect(persistence.persistedFingerprintSet == prepared.fingerprintSet)
        #expect(persistence.persistedGeneration == generation)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func byteDifferentPDFsWithEqualExtractedTextRemainDistinctExactSources() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-AxisPDF-ByteIdentity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let fixtureURL = FixtureLocator.axisPDF(
            "axis_bank_nro_account_statement_baseline.pdf"
        )
        let firstURL = directory.appendingPathComponent("first.pdf")
        let secondURL = directory.appendingPathComponent("renamed.pdf")
        let firstBytes = try Data(contentsOf: fixtureURL)
        try firstBytes.write(to: firstURL)
        var secondBytes = firstBytes
        secondBytes.append(Data("\n% LedgerForge byte-identity test\n".utf8))
        try secondBytes.write(to: secondURL)

        let persistence = AxisPDFImportPersistenceProbe()
        let engine = makeEngine(
            persistence: persistence,
            generation: ProviderGenerationToken()
        )
        let first = try await engine.prepareImport(from: firstURL)
        let firstRawText = try #require(first.fingerprintSet.fingerprints.first {
            $0.algorithm == ExactStatementFingerprint.algorithm
        })
        let firstSource = try #require(first.fingerprintSet.duplicateAuthority)
        engine.cancelPreparedImport(first)

        let second = try await engine.prepareImport(from: secondURL)
        defer { engine.cancelPreparedImport(second) }
        let secondRawText = try #require(second.fingerprintSet.fingerprints.first {
            $0.algorithm == ExactStatementFingerprint.algorithm
        })
        let secondSource = try #require(second.fingerprintSet.duplicateAuthority)

        #expect(first.rawContents == second.rawContents)
        #expect(firstRawText.digest == secondRawText.digest)
        #expect(!firstRawText.isDuplicateAuthority)
        #expect(!secondRawText.isDuplicateAuthority)
        #expect(firstSource.algorithm == SourceContentSnapshot.algorithm)
        #expect(secondSource.algorithm == SourceContentSnapshot.algorithm)
        #expect(firstSource.digest != secondSource.digest)
        #expect(firstSource.byteCount != secondSource.byteCount)
        #expect(first.fingerprint != second.fingerprint)
        #expect(persistence.persistInvocationCount == 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func alteredPDFRawTextOrDuplicateAuthorityRejectsBeforePersistence() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let persistence = AxisPDFImportPersistenceProbe()
        let engine = makeEngine(
            persistence: persistence,
            generation: ProviderGenerationToken()
        )
        let sourceURL = FixtureLocator.axisPDF(
            "axis_bank_nro_account_statement_baseline.pdf"
        )

        let original = try await engine.prepareImport(from: sourceURL)
        let rawTextMutated = copy(
            original,
            rawContents: original.rawContents + "\nmutated after preparation",
            fingerprintSet: original.fingerprintSet
        )
        let rawTextResult = await engine.commitPreparedImport(rawTextMutated)

        #expect(
            rawTextResult.errorMessage ==
                ImportEngineCommitError.sourceSnapshotIntegrityFailed.localizedDescription
        )
        #expect(persistence.persistInvocationCount == 0)

        let second = try await engine.prepareImport(from: sourceURL)
        let alteredAuthority = PreparedDocumentFingerprintSet(
            fingerprints: second.fingerprintSet.fingerprints.map {
                VersionedDocumentFingerprint(
                    algorithm: $0.algorithm,
                    digest: $0.digest,
                    byteCount: $0.byteCount,
                    isDuplicateAuthority:
                        $0.algorithm == ExactStatementFingerprint.algorithm
                )
            }
        )
        let authorityMutated = copy(
            second,
            rawContents: second.rawContents,
            fingerprintSet: alteredAuthority
        )
        let authorityResult = await engine.commitPreparedImport(authorityMutated)

        #expect(
            authorityResult.errorMessage ==
                ImportEngineCommitError.sourceSnapshotIntegrityFailed.localizedDescription
        )
        #expect(persistence.persistInvocationCount == 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func ordinaryRenamedSameBytesPDFReimportPreservesAcceptedGraph() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "LedgerForge-AxisPDF-OrdinaryDuplicate-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let bytes = try Data(contentsOf: FixtureLocator.axisPDF(
            "axis_bank_nro_account_statement_baseline.pdf"
        ))
        let firstURL = directory.appendingPathComponent("first.pdf")
        let renamedURL = directory.appendingPathComponent("renamed.pdf")
        try bytes.write(to: firstURL)
        try bytes.write(to: renamedURL)

        let sqlite = try SQLiteRepositoryProvider(
            path: directory.appendingPathComponent("duplicate.sqlite").path
        )
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(
            sqlite,
            protectsGeneration: false
        )
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-axis-pdf-ordinary-duplicate",
                workspaceName: "Axis PDF Ordinary Duplicate"
            )
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: {
                RepositoryStoreHydrationResult(
                    didHydrate: true,
                    accountCount: 1,
                    transactionCount: 16,
                    importSessionCount: 1,
                    importAttemptCount: 1
                )
            },
            rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate:
                DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )

        let firstPrepared = try await engine.prepareImport(from: firstURL)
        #expect(firstPrepared.advisoryPreviousImport == nil)
        let firstResult = await engine.commitPreparedImport(
            firstPrepared,
            accountChoice: .createNewAccount
        )
        #expect(firstResult.succeeded)

        let acceptedGraphBefore = try acceptedPDFGraphCounts(sqlite.database)
        let transactionsBefore = try provider.transactionRepo.trustedTransactions(
            workspaceId: "workspace-axis-pdf-ordinary-duplicate"
        )

        let duplicatePrepared = try await engine.prepareImport(from: renamedURL)
        #expect(
            duplicatePrepared.advisoryPreviousImport?.importSessionId ==
                firstResult.importSessionId
        )
        let duplicateResult = await engine.commitPreparedImport(duplicatePrepared)

        #expect(!duplicateResult.succeeded)
        #expect(
            duplicateResult.previousImport?.importSessionId ==
                firstResult.importSessionId
        )
        #expect(try acceptedPDFGraphCounts(sqlite.database) == acceptedGraphBefore)
        #expect(
            try provider.transactionRepo.trustedTransactions(
                workspaceId: "workspace-axis-pdf-ordinary-duplicate"
            ) == transactionsBefore
        )
        let attempts = try provider.importSessionRepo.importAttempts(
            workspaceId: "workspace-axis-pdf-ordinary-duplicate"
        )
        #expect(attempts.count == 2)
        #expect(attempts.filter {
            $0.outcomeCode == ImportAttemptOutcome.exactStatementDuplicate.rawValue
        }.count == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func hostilePDFPreparationsLeaveZeroAcceptedSQLiteResidue() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "LedgerForge-AxisPDF-HostilePreparation-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let sqlite = try SQLiteRepositoryProvider(
            path: directory.appendingPathComponent("hostile.sqlite").path
        )
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(
            sqlite,
            protectsGeneration: false
        )
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-axis-pdf-hostile",
                workspaceName: "Axis PDF Hostile Preparation"
            )
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate:
                DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )
        let statement = syntheticValidStatement()
        let hostileSources = [
            statement.replacingOccurrences(
                of: "Statement of Axis Account No",
                with: "Axis Bank Account Summary No"
            ),
            statement.replacingOccurrences(
                of: "Statement of Axis Account No : 123456789012345",
                with: "Axis Bank Credit Card Statement : 123456789012345"
            ),
            statement.replacingOccurrences(
                of: "Statement of Axis Account No",
                with: "Statement of Other Bank Account No"
            ),
            statement.replacingOccurrences(
                of: "Tran Date Chq No Particulars Debit Credit Balance Init.",
                with: "Tran Date Chq No Particulars Credit Debit Balance Init."
            ),
            statement.replacingOccurrences(
                of: " for the period (From : 01-04-2026 To : 30-06-2026)",
                with: ""
            ),
            statement.replacingOccurrences(
                of: "Statement of Axis Account No : 123456789012345",
                with: "Statement of Axis Account No : XXXXX1234"
            ),
            statement.replacingOccurrences(
                of: "OPENING BALANCE 100.00\n",
                with: ""
            ),
            statement.replacingOccurrences(
                of: "TRANSACTION TOTAL 25.00 10.00\n",
                with: ""
            ),
            statement.replacingOccurrences(
                of: "CLOSING BALANCE 85.00",
                with: ""
            ),
            statement.replacingOccurrences(
                of: "CLOSING BALANCE 85.00",
                with: "TRANSACTION TOTAL 25.00 11.00\nCLOSING BALANCE 85.00"
            ),
            statement.replacingOccurrences(
                of: "25.00 75.00 4437",
                with: "25.00 not-a-balance 4437"
            ),
            statement.replacingOccurrences(
                of: "01-04-2026 -",
                with: "32-04-2026 -"
            ),
            statement.replacingOccurrences(
                of: "25.00 75.00 4437",
                with: "25.0 75.00 4437"
            ),
            statement.replacingOccurrences(
                of: "25.00 75.00 4437",
                with: "25.00 74.00 4437"
            ),
            statement.replacingOccurrences(
                of: "25.00 75.00 4437",
                with: "25.00 25.00 75.00 4437"
            ),
            statement.replacingOccurrences(
                of: "02-04-2026 -",
                with: "3 Apr, 2026 INCOMPLETE FUTURE ROW\n02-04-2026 -"
            ),
            statement.replacingOccurrences(
                of: "Tran Date Chq No Particulars Debit Credit Balance Init.",
                with: "Tran Date Chq No Particulars Debit Credit Init."
            ),
            statement.replacingOccurrences(
                of: "Tran Date Chq No Particulars Debit Credit Balance Init.",
                with: "Statement of Axis Account No : 123456789012346 for the period (From : 01-04-2026 To : 30-06-2026)\nTran Date Chq No Particulars Debit Credit Balance Init."
            ),
            statement.replacingOccurrences(
                of: "TRANSACTION TOTAL 25.00 10.00",
                with: "TRANSACTION TOTAL 25.00 9.00"
            )
        ]

        let malformedURL = directory.appendingPathComponent("malformed.pdf")
        try Data("%PDF-1.7\ntruncated".utf8).write(to: malformedURL)
        do {
            let unexpected = try await engine.prepareImport(from: malformedURL)
            engine.cancelPreparedImport(unexpected)
            Issue.record("Expected malformed PDF preparation to fail closed.")
            try assertZeroAcceptedPDFResidue(sqlite.database)
        } catch {
            try assertZeroAcceptedPDFResidue(sqlite.database)
        }

        for (index, source) in hostileSources.enumerated() {
            let url = directory.appendingPathComponent("hostile-\(index).pdf")
            try writeSelectablePDF(source, to: url)

            do {
                let unexpected = try await engine.prepareImport(from: url)
                engine.cancelPreparedImport(unexpected)
                Issue.record("Expected hostile PDF preparation \(index) to fail closed.")
                try assertZeroAcceptedPDFResidue(sqlite.database)
            } catch {
                try assertZeroAcceptedPDFResidue(sqlite.database)
            }
        }
    }

    private func makeEngine(
        persistence: ImportPersistenceCoordinating,
        generation: ProviderGenerationToken
    ) -> ImportEngine {
        ImportEngine(
            importPersistenceCoordinator: persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: {
                .intentionalNonDurable(.testMemory)
            },
            providerGenerationProvider: { generation },
            forcedHydration: {
                RepositoryStoreHydrationResult(
                    didHydrate: true,
                    accountCount: 1,
                    transactionCount: 16,
                    importSessionCount: 1,
                    importAttemptCount: 1
                )
            },
            rejectedAttemptHydration: {}
        )
    }

    private func copy(
        _ prepared: PreparedImport,
        rawContents: String,
        fingerprintSet: PreparedDocumentFingerprintSet
    ) -> PreparedImport {
        PreparedImport(
            id: prepared.id,
            sourceURL: prepared.sourceURL,
            rawContents: rawContents,
            fileName: prepared.fileName,
            detectedInstitution: prepared.detectedInstitution,
            detectedDocumentType: prepared.detectedDocumentType,
            parserName: prepared.parserName,
            financialDocument: prepared.financialDocument,
            validation: prepared.validation,
            importSession: prepared.importSession,
            fingerprint: prepared.fingerprint,
            sourceSnapshot: prepared.sourceSnapshot,
            fingerprintSet: fingerprintSet,
            advisoryPreviousImport: prepared.advisoryPreviousImport,
            providerGeneration: prepared.providerGeneration
        )
    }

    private func syntheticValidStatement() -> String {
        """
        Axis Bank
        Scheme: NRO
        Statement of Axis Account No : 123456789012345 for the period (From : 01-04-2026 To : 30-06-2026)
        Tran Date Chq No Particulars Debit Credit Balance Init.
        Br
        OPENING BALANCE 100.00
        01-04-2026 - UPI/P2M/000000000101/TEST PAYMENT 25.00 75.00 4437
        02-04-2026 - UPI/P2A/000000000102/TEST CREDIT 10.00 85.00 4437
        TRANSACTION TOTAL 25.00 10.00
        CLOSING BALANCE 85.00
        """
    }

    private func writeSelectablePDF(
        _ text: String,
        to url: URL
    ) throws {
        let buffer = NSMutableData()
        guard let consumer = CGDataConsumer(data: buffer as CFMutableData) else {
            throw AxisPDFSyntheticDocumentError.creationFailed
        }
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(
            consumer: consumer,
            mediaBox: &mediaBox,
            nil
        ) else {
            throw AxisPDFSyntheticDocumentError.creationFailed
        }

        context.beginPDFPage(nil)
        context.textMatrix = .identity
        let font = CTFontCreateWithName("Courier" as CFString, 8, nil)
        for (index, sourceLine) in text.components(separatedBy: .newlines)
            .enumerated() {
            let attributes = [
                kCTFontAttributeName: font
            ] as CFDictionary
            guard let attributed = CFAttributedStringCreate(
                nil,
                sourceLine as CFString,
                attributes
            ) else {
                throw AxisPDFSyntheticDocumentError.creationFailed
            }
            let line = CTLineCreateWithAttributedString(attributed)
            context.textPosition = CGPoint(
                x: 24,
                y: mediaBox.height - 36 - (CGFloat(index) * 14)
            )
            CTLineDraw(line, context)
        }
        context.endPDFPage()
        context.closePDF()
        try (buffer as Data).write(to: url, options: .atomic)
    }

    private func assertZeroAcceptedPDFResidue(
        _ database: SQLiteDatabase
    ) throws {
        for table in [
            "workspaces",
            "institutions",
            "currencies",
            "accounts",
            "account_identifiers",
            "account_identifier_observations",
            "documents",
            "document_fingerprints",
            "import_sessions",
            "normalized_documents",
            "normalized_rows",
            "transactions",
            "transaction_raw_rows",
            "transaction_event_identities",
            "account_balance_snapshots",
            "partial_import_summaries",
            "incoming_row_dispositions",
            "import_attempts"
        ] {
            #expect(
                try database.queryInt("SELECT COUNT(*) FROM \(table);") == 0,
                "Expected zero accepted residue in \(table)."
            )
        }
    }

    private func acceptedPDFGraphCounts(
        _ database: SQLiteDatabase
    ) throws -> [String: Int] {
        var result: [String: Int] = [:]
        for table in [
            "workspaces",
            "accounts",
            "account_identifiers",
            "account_identifier_observations",
            "documents",
            "document_fingerprints",
            "import_sessions",
            "normalized_documents",
            "normalized_rows",
            "transactions",
            "transaction_raw_rows",
            "transaction_event_identities",
            "account_balance_snapshots"
        ] {
            result[table] = try database.queryInt(
                "SELECT COUNT(*) FROM \(table);"
            )
        }
        return result
    }
}

private enum AxisPDFSyntheticDocumentError: Error {
    case creationFailed
}

private final class AxisPDFImportPersistenceProbe: ImportPersistenceCoordinating {
    private(set) var advisoryFingerprints: [ExactStatementFingerprint] = []
    private(set) var persistInvocationCount = 0
    private(set) var persistedFingerprintSet: PreparedDocumentFingerprintSet?
    private(set) var persistedGeneration: ProviderGenerationToken?

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func priorImportedStatement(
        fingerprint: ExactStatementFingerprint
    ) throws -> PreviouslyImportedStatement? {
        advisoryFingerprints.append(fingerprint)
        return nil
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        persistInvocationCount += 1
        persistedFingerprintSet = fingerprintSet
        persistedGeneration = providerGeneration
        return ImportPersistenceResult(
            persisted: true,
            workspaceId: "axis-pdf-lifecycle-workspace",
            accountId: "axis-pdf-lifecycle-account",
            importSessionId: importSession.id.uuidString,
            transactionCount: financialDocument.transactions.count
        )
    }
}
