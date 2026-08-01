import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct ImportPersistenceFormatAuthorityMapperTests {
    @Test
    func csvRawTextAuthorityPreservesHistoricalMapping() throws {
        let fixture = try makeFormatAuthorityFixture(format: .csv, seed: "csv-mapper")
        let fingerprints = formatAuthorityFingerprints(
            rawAuthority: true,
            sourceAuthority: false,
            rawSeed: "csv-mapper-raw",
            sourceSeed: "csv-mapper-source"
        )

        let payload = try ImportPersistenceMapper().payload(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation,
            accountId: "csv-mapper-account",
            fingerprintSet: fingerprints
        )
        let raw = try #require(fingerprints.fingerprints.first {
            $0.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm
        })

        #expect(payload.document.mimeType == "text/csv")
        #expect(payload.document.sizeBytes == raw.byteCount)
        #expect(payload.document.legacyRawTextSHA256 == raw.digest)
        #expect(payload.fingerprint.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm)
        #expect(payload.fingerprints == fingerprints.fingerprints.enumerated().map { index, fingerprint in
            DocumentFingerprintDTO(
                id: "fingerprint-\(fixture.importSession.id.uuidString.lowercased())-\(index)",
                documentId: payload.document.id,
                importSessionId: payload.importSession.id,
                algorithm: fingerprint.algorithm,
                fingerprint: fingerprint.digest,
                fingerprintData: nil,
                isDuplicateAuthority: fingerprint.isDuplicateAuthority,
                createdAtISO: payload.completedAtISO
            )
        })

        let legacyFingerprint = ExactStatementFingerprint(
            algorithm: raw.algorithm,
            digest: raw.digest,
            byteCount: raw.byteCount
        )
        let legacyPayload = try ImportPersistenceMapper().payload(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation,
            accountId: "csv-legacy-account",
            fingerprint: legacyFingerprint
        )
        #expect(legacyPayload.document.mimeType == "text/csv")
        #expect(legacyPayload.document.sizeBytes == raw.byteCount)
        #expect(legacyPayload.document.legacyRawTextSHA256 == raw.digest)
        #expect(legacyPayload.fingerprints.count == 1)
        #expect(legacyPayload.fingerprint.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm)
    }

    @Test
    func pdfSourceByteAuthorityUsesPDFMediaAndKeepsRawTextLegacySemantics() throws {
        let fixture = try makeFormatAuthorityFixture(format: .pdf, seed: "pdf-mapper")
        let fingerprints = formatAuthorityFingerprints(
            rawAuthority: false,
            sourceAuthority: true,
            rawSeed: "pdf-mapper-extracted-text",
            sourceSeed: "pdf-mapper-source-bytes"
        )

        let payload = try ImportPersistenceMapper().payload(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation,
            accountId: "pdf-mapper-account",
            fingerprintSet: fingerprints
        )
        let raw = try #require(fingerprints.fingerprints.first {
            $0.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm
        })
        let source = try #require(fingerprints.fingerprints.first {
            $0.algorithm == DocumentFingerprintDTO.sourceBytesSHA256Algorithm
        })

        #expect(raw.digest != source.digest)
        #expect(payload.document.mimeType == "application/pdf")
        #expect(payload.document.sizeBytes == source.byteCount)
        #expect(payload.document.legacyRawTextSHA256 == raw.digest)
        #expect(payload.document.legacyRawTextSHA256 != source.digest)
        #expect(payload.fingerprint.algorithm == DocumentFingerprintDTO.sourceBytesSHA256Algorithm)
        #expect(payload.fingerprints.map(\.algorithm) == [
            DocumentFingerprintDTO.rawTextSHA256Algorithm,
            DocumentFingerprintDTO.sourceBytesSHA256Algorithm
        ])
        #expect(payload.fingerprints.filter(\.isDuplicateAuthority).map(\.algorithm) == [
            DocumentFingerprintDTO.sourceBytesSHA256Algorithm
        ])
    }

    @Test
    func formatAuthorityMismatchesFailClosed() throws {
        let csv = try makeFormatAuthorityFixture(format: .csv, seed: "csv-wrong-authority")
        let pdf = try makeFormatAuthorityFixture(format: .pdf, seed: "pdf-wrong-authority")
        let sourceAuthority = formatAuthorityFingerprints(
            rawAuthority: false,
            sourceAuthority: true,
            rawSeed: "csv-wrong-raw",
            sourceSeed: "csv-wrong-source"
        )
        let rawAuthority = formatAuthorityFingerprints(
            rawAuthority: true,
            sourceAuthority: false,
            rawSeed: "pdf-wrong-raw",
            sourceSeed: "pdf-wrong-source"
        )

        #expect(throws: ImportPersistenceError.duplicateAuthorityFormatMismatch) {
            _ = try ImportPersistenceMapper().payload(
                financialDocument: csv.financialDocument,
                importSession: csv.importSession,
                validation: csv.validation,
                accountId: "csv-wrong-account",
                fingerprintSet: sourceAuthority
            )
        }
        #expect(throws: ImportPersistenceError.duplicateAuthorityFormatMismatch) {
            _ = try ImportPersistenceMapper().payload(
                financialDocument: pdf.financialDocument,
                importSession: pdf.importSession,
                validation: pdf.validation,
                accountId: "pdf-wrong-account",
                fingerprintSet: rawAuthority
            )
        }
    }

    @Test
    func invalidFingerprintMatricesAndUnknownFormatsFailClosed() throws {
        let pdf = try makeFormatAuthorityFixture(format: .pdf, seed: "pdf-invalid-matrix")
        let csv = try makeFormatAuthorityFixture(format: .csv, seed: "csv-invalid-matrix")
        let raw = VersionedDocumentFingerprint(
            algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm,
            digest: confirmedImportFixtureDigest(seed: "invalid-matrix-raw"),
            byteCount: 41,
            isDuplicateAuthority: false
        )
        let source = VersionedDocumentFingerprint(
            algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
            digest: confirmedImportFixtureDigest(seed: "invalid-matrix-source"),
            byteCount: 83,
            isDuplicateAuthority: false
        )

        #expect(throws: ImportPersistenceError.invalidFingerprintSet) {
            _ = try ImportPersistenceMapper().payload(
                financialDocument: csv.financialDocument,
                importSession: csv.importSession,
                validation: csv.validation,
                accountId: "missing-authority",
                fingerprintSet: PreparedDocumentFingerprintSet(fingerprints: [raw, source])
            )
        }
        #expect(throws: ImportPersistenceError.invalidFingerprintSet) {
            _ = try ImportPersistenceMapper().payload(
                financialDocument: csv.financialDocument,
                importSession: csv.importSession,
                validation: csv.validation,
                accountId: "multiple-authorities",
                fingerprintSet: PreparedDocumentFingerprintSet(fingerprints: [
                    VersionedDocumentFingerprint(
                        algorithm: raw.algorithm,
                        digest: raw.digest,
                        byteCount: raw.byteCount,
                        isDuplicateAuthority: true
                    ),
                    VersionedDocumentFingerprint(
                        algorithm: source.algorithm,
                        digest: source.digest,
                        byteCount: source.byteCount,
                        isDuplicateAuthority: true
                    )
                ])
            )
        }
        #expect(throws: ImportPersistenceError.invalidFingerprintSet) {
            _ = try ImportPersistenceMapper().payload(
                financialDocument: csv.financialDocument,
                importSession: csv.importSession,
                validation: csv.validation,
                accountId: "unsupported-algorithm",
                fingerprintSet: PreparedDocumentFingerprintSet(fingerprints: [
                    VersionedDocumentFingerprint(
                        algorithm: "ledgerforge.unsupported.sha256.v1",
                        digest: confirmedImportFixtureDigest(seed: "unsupported-algorithm"),
                        byteCount: 19,
                        isDuplicateAuthority: true
                    ),
                    raw
                ])
            )
        }
        #expect(throws: ImportPersistenceError.missingLegacyRawTextFingerprint) {
            _ = try ImportPersistenceMapper().payload(
                financialDocument: pdf.financialDocument,
                importSession: pdf.importSession,
                validation: pdf.validation,
                accountId: "pdf-missing-raw",
                fingerprintSet: PreparedDocumentFingerprintSet(fingerprints: [
                    VersionedDocumentFingerprint(
                        algorithm: source.algorithm,
                        digest: source.digest,
                        byteCount: source.byteCount,
                        isDuplicateAuthority: true
                    )
                ])
            )
        }

        let unknown = try makeFormatAuthorityFixture(
            format: .unknown,
            sourceFileType: "Unknown",
            seed: "unknown-format"
        )
        #expect(throws: ImportPersistenceError.unsupportedPreparedSourceFormat) {
            _ = try ImportPersistenceMapper().payload(
                financialDocument: unknown.financialDocument,
                importSession: unknown.importSession,
                validation: unknown.validation,
                accountId: "unknown-format",
                fingerprintSet: formatAuthorityFingerprints(
                    rawAuthority: true,
                    sourceAuthority: false,
                    rawSeed: "unknown-raw",
                    sourceSeed: "unknown-source"
                )
            )
        }

        let conflicting = try makeFormatAuthorityFixture(
            format: .pdf,
            sourceFileType: "CSV",
            seed: "conflicting-format"
        )
        #expect(throws: ImportPersistenceError.conflictingPreparedSourceFormat) {
            _ = try ImportPersistenceMapper().payload(
                financialDocument: conflicting.financialDocument,
                importSession: conflicting.importSession,
                validation: conflicting.validation,
                accountId: "conflicting-format",
                fingerprintSet: formatAuthorityFingerprints(
                    rawAuthority: false,
                    sourceAuthority: true,
                    rawSeed: "conflicting-raw",
                    sourceSeed: "conflicting-source"
                )
            )
        }
    }
}

@Suite(.serialized)
@MainActor
struct ImportPersistenceFormatAuthorityCoordinatorTests {
    @Test(arguments: FormatAuthorityProviderKind.allCases)
    func csvRawTextAuthorityAcceptanceHasProviderParity(
        providerKind: FormatAuthorityProviderKind
    ) throws {
        let context = try FormatAuthorityProviderContext(providerKind)
        defer { context.cleanup() }
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: context.provider,
            mapper: ImportPersistenceMapper(
                workspaceId: formatAuthorityWorkspaceID,
                workspaceName: "Format Authority Tests"
            )
        )
        let fixture = try makeFormatAuthorityFixture(
            format: .csv,
            seed: "\(providerKind.rawValue)-csv-acceptance"
        )
        let fingerprints = formatAuthorityFingerprints(
            rawAuthority: true,
            sourceAuthority: false,
            rawSeed: "\(providerKind.rawValue)-csv-acceptance-raw",
            sourceSeed: "\(providerKind.rawValue)-csv-acceptance-source"
        )

        let accepted = try coordinator.persistValidatedImport(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation,
            fingerprintSet: fingerprints,
            accountChoice: .createNewAccount,
            providerGeneration: context.provider.generationToken
        )

        #expect(accepted.persisted)
        #expect(accepted.importSessionId == fixture.importSession.id.uuidString)
        #expect(try context.provider.accountRepo.accounts(workspaceId: formatAuthorityWorkspaceID).count == 1)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: formatAuthorityWorkspaceID).count == 1)
        #expect(try context.provider.importSessionRepo.importAttempts(workspaceId: formatAuthorityWorkspaceID).count == 1)
        let authority = try #require(fingerprints.duplicateAuthority)
        #expect(authority.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm)
        #expect(try context.provider.importSessionRepo.priorImportedStatement(
            algorithm: authority.algorithm,
            fingerprint: authority.digest
        )?.importSessionId == fixture.importSession.id.uuidString)
    }

    @Test(arguments: FormatAuthorityProviderKind.allCases)
    func pdfAcceptanceAndExactReimportHaveProviderParity(
        providerKind: FormatAuthorityProviderKind
    ) throws {
        let context = try FormatAuthorityProviderContext(providerKind)
        defer { context.cleanup() }
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: context.provider,
            mapper: ImportPersistenceMapper(
                workspaceId: formatAuthorityWorkspaceID,
                workspaceName: "Format Authority Tests"
            )
        )
        let first = try makeFormatAuthorityFixture(
            format: .pdf,
            seed: "\(providerKind.rawValue)-pdf-first",
            identifierSeed: "\(providerKind.rawValue)-pdf-identity"
        )
        let duplicate = try makeFormatAuthorityFixture(
            format: .pdf,
            seed: "\(providerKind.rawValue)-pdf-renamed",
            identifierSeed: "\(providerKind.rawValue)-pdf-identity"
        )
        let fingerprints = formatAuthorityFingerprints(
            rawAuthority: false,
            sourceAuthority: true,
            rawSeed: "\(providerKind.rawValue)-pdf-extracted-text",
            sourceSeed: "\(providerKind.rawValue)-pdf-source-bytes"
        )
        let source = try #require(fingerprints.duplicateAuthority)
        let raw = try #require(fingerprints.fingerprints.first {
            $0.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm
        })

        let accepted = try coordinator.persistValidatedImport(
            financialDocument: first.financialDocument,
            importSession: first.importSession,
            validation: first.validation,
            fingerprintSet: fingerprints,
            accountChoice: .createNewAccount,
            providerGeneration: context.provider.generationToken
        )
        let acceptedGraphBeforeDuplicate = try acceptedPDFGraphSnapshot(
            context: context,
            acceptedSessionID: first.importSession.id.uuidString,
            duplicateSessionID: duplicate.importSession.id.uuidString,
            sourceAuthority: source,
            rawTextFingerprint: raw
        )
        let reimport = try coordinator.persistValidatedImport(
            financialDocument: duplicate.financialDocument,
            importSession: duplicate.importSession,
            validation: duplicate.validation,
            fingerprintSet: fingerprints,
            accountChoice: .createNewAccount,
            providerGeneration: context.provider.generationToken
        )
        let acceptedGraphAfterDuplicate = try acceptedPDFGraphSnapshot(
            context: context,
            acceptedSessionID: first.importSession.id.uuidString,
            duplicateSessionID: duplicate.importSession.id.uuidString,
            sourceAuthority: source,
            rawTextFingerprint: raw
        )

        #expect(accepted.persisted)
        #expect(!reimport.persisted)
        #expect(reimport.previousImport?.importSessionId == first.importSession.id.uuidString)
        #expect(acceptedGraphAfterDuplicate == acceptedGraphBeforeDuplicate)
        #expect(try context.provider.accountRepo.accounts(workspaceId: formatAuthorityWorkspaceID).count == 1)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: formatAuthorityWorkspaceID).count == 1)
        let attempts = try context.provider.importSessionRepo.importAttempts(
            workspaceId: formatAuthorityWorkspaceID
        )
        #expect(attempts.count == 2)
        #expect(attempts.filter {
            $0.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue
        }.count == 1)
        #expect(attempts.filter {
            $0.outcomeCode == ImportAttemptOutcome.exactStatementDuplicate.rawValue
        }.count == 1)
        #expect(try context.provider.importSessionRepo.priorImportedStatement(
            algorithm: source.algorithm,
            fingerprint: source.digest
        )?.importSessionId == first.importSession.id.uuidString)
        #expect(try context.provider.importSessionRepo.priorImportedStatement(
            algorithm: raw.algorithm,
            fingerprint: raw.digest
        ) == nil)

        if let sqlite = context.sqlite {
            let documents = try sqlite.database.query(
                sql: """
                    SELECT
                        mime_type,
                        size_bytes,
                        sha256,
                        storage_path,
                        extracted_text_snippet,
                        page_count
                    FROM documents;
                    """
            ) {
                (
                    mimeType: $0.string(at: 0),
                    sizeBytes: $0.int64(at: 1),
                    legacyRawTextSHA256: $0.string(at: 2),
                    storagePath: $0.string(at: 3),
                    extractedTextSnippet: $0.string(at: 4),
                    pageCount: $0.int64(at: 5)
                )
            }
            #expect(documents.count == 1)
            #expect(documents.first?.mimeType == "application/pdf")
            #expect(documents.first?.sizeBytes == source.byteCount)
            #expect(documents.first?.legacyRawTextSHA256 == raw.digest)
            #expect(documents.first?.legacyRawTextSHA256 != source.digest)
            #expect(documents.first?.storagePath == nil)
            #expect(documents.first?.extractedTextSnippet == nil)
            #expect(documents.first?.pageCount == nil)

            let persistedFingerprints = try sqlite.database.query(
                sql: "SELECT algorithm, fingerprint, is_duplicate_authority FROM document_fingerprints ORDER BY algorithm;"
            ) {
                ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.bool(at: 2))
            }
            #expect(persistedFingerprints.map(\.0) == [
                DocumentFingerprintDTO.rawTextSHA256Algorithm,
                DocumentFingerprintDTO.sourceBytesSHA256Algorithm
            ])
            #expect(persistedFingerprints.map(\.1) == [raw.digest, source.digest])
            #expect(persistedFingerprints.map(\.2) == [false, true])
        }
    }

    @Test
    func pdfSQLiteReopenReconstructsHydratedStoresAndParserProvenance() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "LedgerForge-PDF-FormatAuthority-Relaunch-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("relaunch.sqlite")

        let initialSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        let initialProvider = DatabaseProvider.verifiedSQLite(
            initialSQLite,
            protectsGeneration: false
        )
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: initialProvider,
            mapper: ImportPersistenceMapper(
                workspaceId: formatAuthorityWorkspaceID,
                workspaceName: "Format Authority Tests"
            )
        )
        let fixture = try makeFormatAuthorityFixture(
            format: .pdf,
            seed: "pdf-relaunch"
        )
        let fingerprints = formatAuthorityFingerprints(
            rawAuthority: false,
            sourceAuthority: true,
            rawSeed: "pdf-relaunch-raw",
            sourceSeed: "pdf-relaunch-source"
        )

        let accepted = try coordinator.persistValidatedImport(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation,
            fingerprintSet: fingerprints,
            accountChoice: .createNewAccount,
            providerGeneration: initialProvider.generationToken
        )
        #expect(accepted.persisted)
        initialSQLite.database.close()

        let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopenedSQLite.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(
            reopenedSQLite,
            protectsGeneration: false
        )
        let persisted = try reopenedProvider.transactionRepo
            .trustedTransactions(workspaceId: formatAuthorityWorkspaceID)
        let persistedTransaction = try #require(persisted.first)
        let persistedRawRow = try #require(persistedTransaction.rawRows.first)
        #expect(persisted.count == 1)
        #expect(persistedRawRow.parserProfileId == AxisBankAccountPDFParser.profileID)
        #expect(
            persistedRawRow.parserProfileVersion ==
                AxisBankAccountPDFParser.profileVersion
        )

        let accounts = AccountStore()
        let transactions = TransactionStore()
        let sessions = ImportSessionStore()
        let attempts = ImportAttemptStore()
        let categories = CategoryStore()
        let hydration = try RepositoryStoreHydrator(
            databaseProvider: reopenedProvider,
            accountStore: accounts,
            transactionStore: transactions,
            categoryStore: categories,
            importSessionStore: sessions,
            importAttemptStore: attempts,
            workspaceId: formatAuthorityWorkspaceID,
            categoryReconciliationGate: nil,
            participatesInLifecycleGate: false
        ).hydrateIfNeeded()

        #expect(hydration.didHydrate)
        #expect(hydration.accountCount == 1)
        #expect(hydration.transactionCount == 1)
        #expect(hydration.importSessionCount == 1)
        #expect(accounts.accounts.count == 1)
        #expect(transactions.transactions.count == 1)
        #expect(sessions.importSessions.count == 1)
        let hydratedProvenance = try #require(
            transactions.transactions.first?.sourceProvenance.first
        )
        #expect(
            hydratedProvenance.parserProfileID ==
                AxisBankAccountPDFParser.profileID
        )
        #expect(
            hydratedProvenance.parserProfileVersion ==
                AxisBankAccountPDFParser.profileVersion
        )
    }

    @Test(arguments: FormatAuthorityProviderKind.allCases)
    func crossFormatFinancialEquivalenceIsNotExactDuplicateSuppression(
        providerKind: FormatAuthorityProviderKind
    ) throws {
        let context = try FormatAuthorityProviderContext(providerKind)
        defer { context.cleanup() }
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: context.provider,
            mapper: ImportPersistenceMapper(
                workspaceId: formatAuthorityWorkspaceID,
                workspaceName: "Format Authority Tests"
            )
        )
        let identitySeed = "\(providerKind.rawValue)-cross-format-identity"
        let csv = try makeFormatAuthorityFixture(
            format: .csv,
            seed: "\(providerKind.rawValue)-cross-format-csv",
            identifierSeed: identitySeed
        )
        let pdf = try makeFormatAuthorityFixture(
            format: .pdf,
            seed: "\(providerKind.rawValue)-cross-format-pdf",
            identifierSeed: identitySeed
        )
        let sharedExtractedTextDigestSeed = "\(providerKind.rawValue)-same-financial-text"
        let csvFingerprints = formatAuthorityFingerprints(
            rawAuthority: true,
            sourceAuthority: false,
            rawSeed: sharedExtractedTextDigestSeed,
            sourceSeed: "\(providerKind.rawValue)-csv-source"
        )
        let pdfFingerprints = formatAuthorityFingerprints(
            rawAuthority: false,
            sourceAuthority: true,
            rawSeed: sharedExtractedTextDigestSeed,
            sourceSeed: "\(providerKind.rawValue)-pdf-source"
        )

        let csvResult = try coordinator.persistValidatedImport(
            financialDocument: csv.financialDocument,
            importSession: csv.importSession,
            validation: csv.validation,
            fingerprintSet: csvFingerprints,
            accountChoice: .createNewAccount,
            providerGeneration: context.provider.generationToken
        )
        let pdfResult = try coordinator.persistValidatedImport(
            financialDocument: pdf.financialDocument,
            importSession: pdf.importSession,
            validation: pdf.validation,
            fingerprintSet: pdfFingerprints,
            accountChoice: .createNewAccount,
            providerGeneration: context.provider.generationToken
        )

        #expect(csvResult.persisted)
        #expect(pdfResult.persisted)
        #expect(csvResult.accountId == pdfResult.accountId)
        #expect(try context.provider.accountRepo.accounts(workspaceId: formatAuthorityWorkspaceID).count == 1)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: formatAuthorityWorkspaceID).count == 2)
        #expect(try context.provider.importSessionRepo.importAttempts(workspaceId: formatAuthorityWorkspaceID).count == 2)

        let csvAuthority = try #require(csvFingerprints.duplicateAuthority)
        let pdfAuthority = try #require(pdfFingerprints.duplicateAuthority)
        #expect(csvAuthority.algorithm != pdfAuthority.algorithm)
        #expect(try context.provider.importSessionRepo.priorImportedStatement(
            algorithm: csvAuthority.algorithm,
            fingerprint: csvAuthority.digest
        )?.importSessionId == csv.importSession.id.uuidString)
        #expect(try context.provider.importSessionRepo.priorImportedStatement(
            algorithm: pdfAuthority.algorithm,
            fingerprint: pdfAuthority.digest
        )?.importSessionId == pdf.importSession.id.uuidString)
    }

    @Test
    func confirmedPlanFormatAuthorityMismatchesFailBeforeProviderCalls() throws {
        let backend = InMemoryRepositoryProvider()
        let recordingRepository = RecordingConfirmedImportRepository()
        let provider = DatabaseProvider(
            workspaceRepo: backend.workspaceRepo,
            transactionRepo: backend.transactionRepo,
            categoryRepo: backend.categoryRepo,
            accountRepo: backend.accountRepo,
            importSessionRepo: backend.importSessionRepo,
            confirmedImportRepo: recordingRepository,
            generationToken: backend.generationToken
        )
        let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: provider)

        let csvAuthorityPlan = confirmedImportPlan(
            generationToken: provider.generationToken,
            suffix: "coordinator-csv-authority"
        )
        let csvAuthorityPresentedAsPDF = replacingMimeType(
            in: csvAuthorityPlan,
            with: "application/pdf"
        )
        #expect(throws: ImportPersistenceCoordinationError.invalidFingerprint) {
            _ = try coordinator.persistReviewedPartialImport(
                reviewedPlan(from: csvAuthorityPresentedAsPDF, suffix: "csv-as-pdf")
            )
        }

        let pdfFixture = try makeFormatAuthorityFixture(
            format: .pdf,
            seed: "coordinator-pdf-authority"
        )
        let pdfPlan = try ImportPersistenceMapper().confirmedImportPlan(
            financialDocument: pdfFixture.financialDocument,
            importSession: pdfFixture.importSession,
            validation: pdfFixture.validation,
            fingerprintSet: formatAuthorityFingerprints(
                rawAuthority: false,
                sourceAuthority: true,
                rawSeed: "coordinator-pdf-raw",
                sourceSeed: "coordinator-pdf-source"
            ),
            providerGeneration: provider.generationToken,
            advisoryIdentity: .noMatch,
            accountChoice: .createProposedAccount,
            selectedAccountId: "coordinator-pdf-account"
        )
        let pdfAuthorityPresentedAsCSV = replacingMimeType(
            in: pdfPlan,
            with: "text/csv"
        )
        #expect(throws: ImportPersistenceCoordinationError.invalidFingerprint) {
            _ = try coordinator.persistReviewedPartialImport(
                reviewedPlan(from: pdfAuthorityPresentedAsCSV, suffix: "pdf-as-csv")
            )
        }

        let unknownFormatPlan = replacingMimeType(
            in: csvAuthorityPlan,
            with: "application/octet-stream"
        )
        #expect(throws: ImportPersistenceCoordinationError.invalidFingerprint) {
            _ = try coordinator.persistReviewedPartialImport(
                reviewedPlan(from: unknownFormatPlan, suffix: "unknown-format")
            )
        }

        let unsupportedAlgorithmPlan = replacingFingerprintAlgorithms(
            in: csvAuthorityPlan,
            with: "ledgerforge.unsupported.sha256.v1"
        )
        #expect(throws: ImportPersistenceCoordinationError.invalidFingerprint) {
            _ = try coordinator.persistReviewedPartialImport(
                reviewedPlan(
                    from: unsupportedAlgorithmPlan,
                    suffix: "unsupported-algorithm"
                )
            )
        }

        let missingAuthorityPlan = replacingAuthorityCount(
            in: csvAuthorityPlan,
            with: 0
        )
        #expect(throws: ImportPersistenceCoordinationError.invalidFingerprint) {
            _ = try coordinator.persistReviewedPartialImport(
                reviewedPlan(
                    from: missingAuthorityPlan,
                    suffix: "missing-authority"
                )
            )
        }

        let multipleAuthorityPlan = replacingAuthorityCount(
            in: csvAuthorityPlan,
            with: 2
        )
        #expect(throws: ImportPersistenceCoordinationError.invalidFingerprint) {
            _ = try coordinator.persistReviewedPartialImport(
                reviewedPlan(
                    from: multipleAuthorityPlan,
                    suffix: "multiple-authority"
                )
            )
        }

        #expect(recordingRepository.reviewCalls == 0)
        #expect(recordingRepository.commitCalls == 0)
        #expect(recordingRepository.reviewedCommitCalls == 0)
        for workspaceID in [
            csvAuthorityPresentedAsPDF.workspace.id,
            pdfAuthorityPresentedAsCSV.workspace.id,
            unknownFormatPlan.workspace.id,
            unsupportedAlgorithmPlan.workspace.id
        ] {
            #expect(try provider.workspaceRepo.workspace(id: workspaceID) == nil)
            #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
            #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspaceID).isEmpty)
        }
    }
}

private let formatAuthorityWorkspaceID = "workspace-format-authority-tests"

private struct FormatAuthorityFixture {
    let financialDocument: FinancialDocument
    let importSession: ImportSession
    let validation: ImportValidationResult
}

private struct AcceptedPDFGraphSnapshot: Equatable {
    let workspace: WorkspaceDTO?
    let accounts: [AccountDTO]
    let identifiers: [AccountIdentifierDTO]
    let transactions: [TransactionDTO]
    let acceptedSession: ImportSessionRecordDTO?
    let duplicateSession: ImportSessionRecordDTO?
    let authoritativePriorImport: PriorImportedStatementDTO?
    let rawTextPriorImport: PriorImportedStatementDTO?
    let sqliteAcceptedCounts: [String: Int]
    let sqliteDocuments: [String]
    let sqliteFingerprints: [String]
    let sqliteIdentifierObservations: [String]
    let sqliteBalanceSnapshots: [String]
}

@MainActor
private func acceptedPDFGraphSnapshot(
    context: FormatAuthorityProviderContext,
    acceptedSessionID: String,
    duplicateSessionID: String,
    sourceAuthority: VersionedDocumentFingerprint,
    rawTextFingerprint: VersionedDocumentFingerprint
) throws -> AcceptedPDFGraphSnapshot {
    let accounts = try context.provider.accountRepo.accounts(
        workspaceId: formatAuthorityWorkspaceID
    ).sorted { $0.id < $1.id }
    let identifiers = try accounts.flatMap { account in
        try context.provider.accountRepo.identifiers(
            accountId: account.id,
            workspaceId: formatAuthorityWorkspaceID
        )
    }.sorted { $0.id < $1.id }
    let transactions = try context.provider.transactionRepo.trustedTransactions(
        workspaceId: formatAuthorityWorkspaceID
    ).sorted { $0.id < $1.id }

    var sqliteAcceptedCounts: [String: Int] = [:]
    var sqliteDocuments: [String] = []
    var sqliteFingerprints: [String] = []
    var sqliteIdentifierObservations: [String] = []
    var sqliteBalanceSnapshots: [String] = []
    if let sqlite = context.sqlite {
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
            sqliteAcceptedCounts[table] = try sqlite.database.queryInt(
                "SELECT COUNT(*) FROM \(table);"
            )
        }
        sqliteDocuments = try sqlite.database.query(
            sql: """
                SELECT
                    id || '|' || COALESCE(import_session_id, '') || '|' ||
                    filename || '|' || COALESCE(mime_type, '') || '|' ||
                    COALESCE(CAST(size_bytes AS TEXT), '') || '|' || sha256 || '|' ||
                    COALESCE(storage_path, '') || '|' ||
                    COALESCE(extracted_text_snippet, '') || '|' ||
                    COALESCE(CAST(page_count AS TEXT), '')
                FROM documents
                ORDER BY id;
                """
        ) { $0.string(at: 0) ?? "" }
        sqliteFingerprints = try sqlite.database.query(
            sql: """
                SELECT
                    id || '|' || document_id || '|' ||
                    COALESCE(import_session_id, '') || '|' || algorithm || '|' ||
                    fingerprint || '|' || COALESCE(fingerprint_data, '') || '|' ||
                    CAST(is_duplicate_authority AS TEXT)
                FROM document_fingerprints
                ORDER BY id;
                """
        ) { $0.string(at: 0) ?? "" }
        sqliteIdentifierObservations = try sqlite.database.query(
            sql: """
                SELECT
                    id || '|' || ownership_id || '|' || import_session_id || '|' ||
                    document_id || '|' || parser_provenance_code || '|' ||
                    association_authority_code
                FROM account_identifier_observations
                ORDER BY id;
                """
        ) { $0.string(at: 0) ?? "" }
        sqliteBalanceSnapshots = try sqlite.database.query(
            sql: """
                SELECT
                    id || '|' || account_id || '|' || snapshot_date || '|' ||
                    CAST(balance_minor AS TEXT) || '|' || currency_code || '|' ||
                    COALESCE(source_import_session_id, '')
                FROM account_balance_snapshots
                ORDER BY id;
                """
        ) { $0.string(at: 0) ?? "" }
    }

    return AcceptedPDFGraphSnapshot(
        workspace: try context.provider.workspaceRepo.workspace(
            id: formatAuthorityWorkspaceID
        ),
        accounts: accounts,
        identifiers: identifiers,
        transactions: transactions,
        acceptedSession: try context.provider.importSessionRepo.importSession(
            id: acceptedSessionID
        ),
        duplicateSession: try context.provider.importSessionRepo.importSession(
            id: duplicateSessionID
        ),
        authoritativePriorImport: try context.provider.importSessionRepo
            .priorImportedStatement(
                algorithm: sourceAuthority.algorithm,
                fingerprint: sourceAuthority.digest
            ),
        rawTextPriorImport: try context.provider.importSessionRepo
            .priorImportedStatement(
                algorithm: rawTextFingerprint.algorithm,
                fingerprint: rawTextFingerprint.digest
            ),
        sqliteAcceptedCounts: sqliteAcceptedCounts,
        sqliteDocuments: sqliteDocuments,
        sqliteFingerprints: sqliteFingerprints,
        sqliteIdentifierObservations: sqliteIdentifierObservations,
        sqliteBalanceSnapshots: sqliteBalanceSnapshots
    )
}

private func makeFormatAuthorityFixture(
    format: FileFormat,
    sourceFileType: String? = nil,
    seed: String,
    identifierSeed: String? = nil
) throws -> FormatAuthorityFixture {
    let fileType = sourceFileType ?? format.rawValue
    let fileExtension: String
    let profileID: String
    let profileVersion: String
    switch format {
    case .csv:
        fileExtension = "csv"
        profileID = "axis.bank-account.csv"
        profileVersion = "2"
    case .pdf:
        fileExtension = "pdf"
        profileID = "axis.bank-account.pdf"
        profileVersion = "1"
    case .xls, .xlsx, .unknown:
        fileExtension = "dat"
        profileID = "unsupported.fixture"
        profileVersion = "1"
    }
    let filename = "format-authority-\(seed).\(fileExtension)"
    let provenance = TransactionSourceProvenance(
        normalizedDocumentID: "normalized-\(seed)",
        normalizedRowID: "row-\(seed)",
        sourceOrdinal: 1,
        normalizedRecordDigest: .normalizedRecordDigest(values: [
            "2026-07-30", "Authority fixture", "10.00", "90.00", seed
        ]),
        parserProfileID: profileID,
        parserProfileVersion: profileVersion
    )
    let transaction = Transaction(
        statementDate: try StatementDate(canonical: "2026-07-30"),
        description: "Authority fixture",
        debit: 10,
        credit: nil,
        amount: -10,
        balance: 90,
        currency: "INR",
        account: "Test account",
        sourceBank: "Axis Bank",
        sourceFile: filename,
        statementTimezoneEvidence: .iana("Asia/Kolkata"),
        sourceProvenance: [provenance]
    )
    let importedAt = Date(timeIntervalSince1970: 1_785_369_600)
    let financialDocument = FinancialDocument(
        sourceDocument: Document(
            filename: filename,
            url: URL(fileURLWithPath: "/tmp/\(filename)"),
            fileType: fileType,
            importedAt: importedAt
        ),
        metadata: DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: format,
            confidence: 1
        ),
        parserName: profileID,
        bookedCurrency: try CurrencyCode("INR"),
        transactions: [transaction],
        financialIdentifiers: [
            try FinancialIdentifier(
                kind: .institutionAccountId,
                rawValue: "AXIS-\((identifierSeed ?? seed).uppercased())",
                verificationState: .verified,
                provenance: .institutionStructuredField
            )
        ],
        selectionReasons: ["Format authority test fixture."],
        createdAt: importedAt
    )
    let validation = ImportValidator.validate(financialDocument: financialDocument)
    let importSession = ImportSession(
        importedAt: importedAt,
        fileName: filename,
        institution: .axis,
        documentType: .bankAccount,
        parserName: profileID,
        transactionCount: 1,
        validation: validation
    )
    return FormatAuthorityFixture(
        financialDocument: financialDocument,
        importSession: importSession,
        validation: validation
    )
}

private func formatAuthorityFingerprints(
    rawAuthority: Bool,
    sourceAuthority: Bool,
    rawSeed: String,
    sourceSeed: String
) -> PreparedDocumentFingerprintSet {
    PreparedDocumentFingerprintSet(fingerprints: [
        VersionedDocumentFingerprint(
            algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm,
            digest: confirmedImportFixtureDigest(seed: rawSeed),
            byteCount: 47,
            isDuplicateAuthority: rawAuthority
        ),
        VersionedDocumentFingerprint(
            algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
            digest: confirmedImportFixtureDigest(seed: sourceSeed),
            byteCount: 131,
            isDuplicateAuthority: sourceAuthority
        )
    ])
}

enum FormatAuthorityProviderKind: String, CaseIterable, Sendable {
    case inMemory
    case sqlite
}

@MainActor
private final class FormatAuthorityProviderContext {
    let provider: DatabaseProvider
    let sqlite: SQLiteRepositoryProvider?
    private let directory: URL?

    init(_ kind: FormatAuthorityProviderKind) throws {
        switch kind {
        case .inMemory:
            provider = DatabaseProvider(inMemory: true)
            sqlite = nil
            directory = nil
        case .sqlite:
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("LedgerForge-FormatAuthority-\(UUID().uuidString)")
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let sqlite = try SQLiteRepositoryProvider(
                path: directory.appendingPathComponent("authority.sqlite").path
            )
            provider = .verifiedSQLite(sqlite, protectsGeneration: false)
            self.sqlite = sqlite
            self.directory = directory
        }
    }

    func cleanup() {
        sqlite?.database.close()
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private func replacingMimeType(
    in plan: ConfirmedImportPlanDTO,
    with mimeType: String
) -> ConfirmedImportPlanDTO {
    let oldDocument = plan.historyTemplate.document
    let document = ImportedDocumentDTO(
        id: oldDocument.id,
        workspaceId: oldDocument.workspaceId,
        importSessionId: oldDocument.importSessionId,
        filename: oldDocument.filename,
        mimeType: mimeType,
        sizeBytes: oldDocument.sizeBytes,
        legacyRawTextSHA256: oldDocument.legacyRawTextSHA256,
        createdAtISO: oldDocument.createdAtISO
    )
    let history = ConfirmedImportHistoryTemplateDTO(
        document: document,
        fingerprints: plan.historyTemplate.fingerprints,
        importSession: plan.historyTemplate.importSession,
        completedAtISO: plan.historyTemplate.completedAtISO,
        successfulAttempt: plan.historyTemplate.successfulAttempt,
        normalizedDocument: plan.historyTemplate.normalizedDocument,
        normalizedRows: plan.historyTemplate.normalizedRows
    )
    return ConfirmedImportPlanDTO(
        providerGeneration: plan.providerGeneration,
        workspace: plan.workspace,
        proposedAccount: plan.proposedAccount,
        accountChoice: plan.accountChoice,
        advisoryIdentity: plan.advisoryIdentity,
        identifiers: plan.identifiers,
        historyTemplate: history,
        transactionTemplates: plan.transactionTemplates,
        declaredStatementStartISO: plan.declaredStatementStartISO,
        declaredStatementEndISO: plan.declaredStatementEndISO,
        openingBalanceMinor: plan.openingBalanceMinor,
        openingBalanceDecimal: plan.openingBalanceDecimal,
        closingBalanceMinor: plan.closingBalanceMinor,
        closingBalanceDecimal: plan.closingBalanceDecimal
    )
}

private func replacingFingerprintAlgorithms(
    in plan: ConfirmedImportPlanDTO,
    with algorithm: String
) -> ConfirmedImportPlanDTO {
    let oldHistory = plan.historyTemplate
    let fingerprints = oldHistory.fingerprints.map { fingerprint in
        DocumentFingerprintDTO(
            id: fingerprint.id,
            documentId: fingerprint.documentId,
            importSessionId: fingerprint.importSessionId,
            algorithm: algorithm,
            fingerprint: fingerprint.fingerprint,
            fingerprintData: fingerprint.fingerprintData,
            isDuplicateAuthority: fingerprint.isDuplicateAuthority,
            createdAtISO: fingerprint.createdAtISO
        )
    }
    let history = ConfirmedImportHistoryTemplateDTO(
        document: oldHistory.document,
        fingerprints: fingerprints,
        importSession: oldHistory.importSession,
        completedAtISO: oldHistory.completedAtISO,
        successfulAttempt: oldHistory.successfulAttempt,
        normalizedDocument: oldHistory.normalizedDocument,
        normalizedRows: oldHistory.normalizedRows
    )
    return ConfirmedImportPlanDTO(
        providerGeneration: plan.providerGeneration,
        workspace: plan.workspace,
        proposedAccount: plan.proposedAccount,
        accountChoice: plan.accountChoice,
        advisoryIdentity: plan.advisoryIdentity,
        identifiers: plan.identifiers,
        historyTemplate: history,
        transactionTemplates: plan.transactionTemplates,
        declaredStatementStartISO: plan.declaredStatementStartISO,
        declaredStatementEndISO: plan.declaredStatementEndISO,
        openingBalanceMinor: plan.openingBalanceMinor,
        openingBalanceDecimal: plan.openingBalanceDecimal,
        closingBalanceMinor: plan.closingBalanceMinor,
        closingBalanceDecimal: plan.closingBalanceDecimal
    )
}

private func replacingAuthorityCount(
    in plan: ConfirmedImportPlanDTO,
    with authorityCount: Int
) -> ConfirmedImportPlanDTO {
    precondition(authorityCount == 0 || authorityCount == 2)
    let oldHistory = plan.historyTemplate
    var fingerprints = oldHistory.fingerprints.map { fingerprint in
        DocumentFingerprintDTO(
            id: fingerprint.id,
            documentId: fingerprint.documentId,
            importSessionId: fingerprint.importSessionId,
            algorithm: fingerprint.algorithm,
            fingerprint: fingerprint.fingerprint,
            fingerprintData: fingerprint.fingerprintData,
            isDuplicateAuthority: authorityCount == 2,
            createdAtISO: fingerprint.createdAtISO
        )
    }
    if authorityCount == 2 {
        fingerprints.append(
            DocumentFingerprintDTO(
                id: "source-authority-\(plan.historyTemplate.document.id)",
                documentId: plan.historyTemplate.document.id,
                importSessionId: plan.historyTemplate.importSession.id,
                algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
                fingerprint: confirmedImportFixtureDigest(
                    seed: "multiple-authority-\(plan.historyTemplate.document.id)"
                ),
                fingerprintData: nil,
                isDuplicateAuthority: true,
                createdAtISO: plan.historyTemplate.completedAtISO
            )
        )
    }
    let history = ConfirmedImportHistoryTemplateDTO(
        document: oldHistory.document,
        fingerprints: fingerprints,
        importSession: oldHistory.importSession,
        completedAtISO: oldHistory.completedAtISO,
        successfulAttempt: oldHistory.successfulAttempt,
        normalizedDocument: oldHistory.normalizedDocument,
        normalizedRows: oldHistory.normalizedRows
    )
    return ConfirmedImportPlanDTO(
        providerGeneration: plan.providerGeneration,
        workspace: plan.workspace,
        proposedAccount: plan.proposedAccount,
        accountChoice: plan.accountChoice,
        advisoryIdentity: plan.advisoryIdentity,
        identifiers: plan.identifiers,
        historyTemplate: history,
        transactionTemplates: plan.transactionTemplates,
        declaredStatementStartISO: plan.declaredStatementStartISO,
        declaredStatementEndISO: plan.declaredStatementEndISO,
        openingBalanceMinor: plan.openingBalanceMinor,
        openingBalanceDecimal: plan.openingBalanceDecimal,
        closingBalanceMinor: plan.closingBalanceMinor,
        closingBalanceDecimal: plan.closingBalanceDecimal
    )
}

private func reviewedPlan(
    from plan: ConfirmedImportPlanDTO,
    suffix: String
) -> ReviewedPartialImportPlanDTO {
    ReviewedPartialImportPlanDTO(
        id: "reviewed-\(suffix)",
        basePlan: plan,
        existingAccountId: plan.proposedAccount.id,
        rows: [],
        sourceRowCount: 0,
        recognizedCount: 0,
        importedCount: 0,
        blockedCount: 0
    )
}

@MainActor
private final class RecordingConfirmedImportRepository: ConfirmedImportRepository {
    private(set) var reviewCalls = 0
    private(set) var commitCalls = 0
    private(set) var reviewedCommitCalls = 0

    func reviewPartialImport(_ plan: ConfirmedImportPlanDTO) -> PartialImportReviewResult {
        reviewCalls += 1
        return .unsupportedEvidence
    }

    func commitConfirmedImport(
        _ plan: ConfirmedImportPlanDTO
    ) -> ConfirmedImportRepositoryResult {
        commitCalls += 1
        return .repositoryIntegrityConflict
    }

    func commitReviewedPartialImport(
        _ plan: ReviewedPartialImportPlanDTO
    ) -> ConfirmedImportRepositoryResult {
        reviewedCommitCalls += 1
        return .repositoryIntegrityConflict
    }
}
