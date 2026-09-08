import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// Required production-path acceptance for the private encrypted CBQ corpus.
/// The private root and (for an isolated acceptance run) a temporary password are
/// supplied only at runtime.  When no password override is supplied, the ordinary
/// production Keychain scope is used through `DefaultPasswordProvider`. Encrypted source bytes traverse the ordinary snapshot,
/// coordinator, PDFKit reader, normalizer, parser, validator, persistence, and
/// hydration boundaries. No private path, credential, source value, decrypted PDF,
/// or row is committed or printed.
@MainActor
struct CBQCreditCardPrivateAcceptanceTests {
    // Keep the historical root key so existing private-context wiring remains compatible.
    // The value is now treated as the CBQ private root, not as a text-fixture directory.
    private static let rootEnvironmentKey = "LEDGERFORGE_PRIVATE_CBQ_TEXT_DIRECTORY"

    @Test(.globalRuntimeStateIsolation)
    func completePrivateCorpusMatchesProductionGrammarAndIndependentOracle() async throws {
        guard let rootPath = ProcessInfo.processInfo.environment[Self.rootEnvironmentKey],
              !rootPath.isEmpty else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let urls = try privateCardPDFs(root: root)
        guard urls.count == 19 else { throw PrivateCBQAcceptanceError.unexpectedCorpusShape }

        let environment = ProcessInfo.processInfo.environment
        let temporaryPassword = environment["LEDGERFORGE_PRIVATE_CBQ_PASSWORD"]
            .flatMap { $0.isEmpty ? nil : $0 }
        let credentialStore: any StatementPasswordCredentialStore
        if let temporaryPassword {
            // The override is intentionally runtime-only.  It keeps this
            // authentic-corpus acceptance independent of a developer
            // Keychain item without placing a credential in source control.
            credentialStore = InMemoryStatementPasswordCredentialStore(
                passwords: [Institution.cbq.statementPasswordCredentialScope: temporaryPassword]
            )
        } else {
            credentialStore = KeychainStatementPasswordCredentialStore()
        }
        let passwordProvider = DefaultPasswordProvider(
            credentialStore: credentialStore,
            supportedInstitutionCodes: [Institution.cbq.statementPasswordCredentialScope],
            challenge: { _ in temporaryPassword }
        )
        let credentialProbe = ImportRequest(
            fileURL: URL(fileURLWithPath: "/cbq-authentic-credential-probe.pdf")
        )
        let canonicalCandidates = try await passwordProvider
            .rememberedPasswordCandidates(for: credentialProbe)
            .filter { candidate in
                candidate.origins.contains { origin in
                    guard case .canonical(let scope) = origin else { return false }
                    return scope == Institution.cbq.statementPasswordCredentialScope
                }
            }
        guard canonicalCandidates.count == 1 else {
            throw PrivateCBQAcceptanceError.credentialUnavailable
        }
        let password = canonicalCandidates[0].value

        let preparationProvider = DatabaseProvider(inMemory: true)
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: passwordProvider
            ),
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(
                databaseProvider: preparationProvider,
                mapper: ImportPersistenceMapper(
                    workspaceId: "cbq-authentic-preparation-\(UUID().uuidString)",
                    workspaceName: "CBQ authentic preparation"
                )
            ),
            persistenceStateProvider: { preparationProvider.persistenceState },
            providerGenerationProvider: { preparationProvider.generationToken },
            forcedHydration: {
                RepositoryStoreHydrationResult(didHydrate: true, accountCount: 0, transactionCount: 0)
            },
            rejectedAttemptHydration: {}
        )

        var sources = [PrivateCBQSource]()
        var rowMismatchCount = 0
        var sectionMismatchCount = 0
        var summaryMismatchCount = 0
        var physicalPageCount = 0

        for url in urls {
            do {
                let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
                guard let lockedDocument = PDFDocument(data: bytes), lockedDocument.isLocked else {
                    throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                }

                let request = ImportRequest(fileURL: url)
                let directSnapshot = SourceContentSnapshot(bytes: bytes)
                defer { directSnapshot.invalidate() }
                let raw = try await PDFDocumentReader().read(
                    request: request,
                    snapshot: directSnapshot,
                    password: password
                )
                guard let pages = raw.pdfPageTexts,
                      !pages.isEmpty,
                      pages.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                      let positioned = raw.pdfPageEvidence,
                      positioned.count == pages.count else {
                    throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                }
                physicalPageCount += pages.count
                let rawText = pages.joined(separator: "\n")
                guard rawText.range(
                    of: #"Statement Period\s+\d{2}/\d{2}/\d{4}\s*-\s*\d{2}/\d{2}/\d{4}"#,
                    options: .regularExpression
                ) != nil,
                rawText.range(
                    of: #"Statement Date\s+\d{1,2}\s+[A-Za-z]+,\s*\d{4}"#,
                    options: .regularExpression
                ) != nil,
                rawText.range(
                    of: #"Payment Due Date\s+\d{1,2}\s+[A-Za-z]+,\s*\d{4}"#,
                    options: .regularExpression
                ) != nil else {
                    throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                }

                let prepared = try await engine.prepareImport(from: url)
                defer { engine.cancelPreparedImport(prepared) }
                guard prepared.validation.passed,
                      prepared.detectedInstitution == .cbq,
                      prepared.detectedDocumentType == .creditCard,
                      prepared.parserName == "CBQ Credit Card PDF",
                      prepared.rawContents == rawText,
                      prepared.sourceSnapshot.sourceByteFingerprint == directSnapshot.sourceByteFingerprint,
                      prepared.financialDocument.transactions.allSatisfy({ transaction in
                          guard transaction.sourceProvenance.count == 1,
                                let provenance = transaction.sourceProvenance.first else {
                              return false
                          }
                          return provenance.parserProfileID == CBQCreditCardPDFParser.profileID &&
                              provenance.parserProfileVersion == CBQCreditCardPDFParser.profileVersion
                      }) else {
                    throw PrivateCBQAcceptanceError.productionRejectedSource
                }

                let normalized = try CBQCreditCardPDFNormalizer().normalize(
                    text: rawText,
                    pageTexts: pages,
                    fileURL: url
                )
                let document = prepared.financialDocument
                guard let evidence = document.cardStatementEvidence,
                      evidence.instrumentSections.count == 2,
                      evidence.transactionAnnotations.count == document.transactions.count else {
                    throw PrivateCBQAcceptanceError.productionRejectedSource
                }
                let oracle = try independentOracle(pages: pages, positioned: positioned)
                #expect(evidence.statementDate == oracle.statementDate)
                #expect(evidence.declaredStatementPeriod == oracle.period)
                #expect(evidence.summary(code: "due_date")?.date == oracle.dueDate)
                rowMismatchCount += financialMismatchCount(
                    oracleRows: oracle.rows,
                    normalizedRows: normalized.rows,
                    document: document,
                    evidence: evidence
                )
                sectionMismatchCount += independentSectionMismatchCount(oracle: oracle, evidence: evidence)
                summaryMismatchCount += independentSummaryMismatchCount(oracle: oracle, evidence: evidence)
                sources.append(PrivateCBQSource(
                    url: url,
                    document: document,
                    fingerprintSet: prepared.fingerprintSet,
                    oracle: oracle,
                    oracleRowCount: oracle.rows.count,
                    physicalPageCount: pages.count
                ))
            } catch let error as PrivateCBQAcceptanceError {
                throw error
            } catch {
                throw PrivateCBQAcceptanceError.productionRejectedSource
            }
        }

        let chronologicalSources = sources.sorted {
            $0.document.cardStatementEvidence!.declaredStatementPeriod!.start <
                $1.document.cardStatementEvidence!.declaredStatementPeriod!.start
        }
        let documents = chronologicalSources.map(\.document)
        let productionRowCounts = documents.map { $0.transactions.count }
        let oracleRowCounts = chronologicalSources.map(\.oracleRowCount)
        let expectedCanonicalTransactionCount = oracleRowCounts.reduce(0, +)
        let expectedSectionCount = documents.reduce(0) {
            $0 + ($1.cardStatementEvidence?.instrumentSections.count ?? 0)
        }
        #expect(documents.count == 19)
        #expect(physicalPageCount == 58)
        #expect(expectedCanonicalTransactionCount == 352)
        #expect(expectedSectionCount == 38)
        #expect(productionRowCounts == oracleRowCounts)
        #expect(productionRowCounts.reduce(0, +) == expectedCanonicalTransactionCount)
        print("CBQ_PRIVATE_ACCEPTANCE sources=\(documents.count) pages=\(physicalPageCount) canonicalTransactions=\(expectedCanonicalTransactionCount)")
        #expect(rowMismatchCount == 0)
        #expect(sectionMismatchCount == 0)
        #expect(summaryMismatchCount == 0)
        #expect(documents.allSatisfy {
            guard let rule = $0.cardStatementEvidence?.reconciliationRuleIdentifier else { return false }
            return rule == CardStatementEvidence.cbqV1QARReconciliationRule ||
                rule == CardStatementEvidence.cbqV2QARReconciliationRule
        })
        let accountValues = documents.flatMap {
            $0.cardStatementEvidence?.accountSourceIdentityObservations.map(\.value) ?? []
        }
        let instrumentValues = documents.flatMap {
            $0.cardStatementEvidence?.instrumentSections.flatMap {
                $0.sourceIdentityObservations.map(\.value)
            } ?? []
        }
        #expect(Set(accountValues).count == 1)
        #expect(Set(instrumentValues).count == 2)

        #expect(zip(documents, documents.dropFirst()).allSatisfy { pair in
            let earlierDocument = pair.0
            let laterDocument = pair.1
            guard let earlier = earlierDocument.cardStatementEvidence?.declaredStatementPeriod,
                  let later = laterDocument.cardStatementEvidence?.declaredStatementPeriod else {
                return false
            }
            return earlier.start <= later.start
        })

        let mixed = deterministicMixedOrder(chronologicalSources)
        for inMemory in [true, false] {
            try await runCampaign(
                chronologicalSources,
                password: password,
                expectedTransactionCount: expectedCanonicalTransactionCount,
                expectedStatementCount: documents.count,
                expectedSectionCount: expectedSectionCount,
                inMemory: inMemory,
                label: "chronological"
            )
            try await runCampaign(
                chronologicalSources.reversed(),
                password: password,
                expectedTransactionCount: expectedCanonicalTransactionCount,
                expectedStatementCount: documents.count,
                expectedSectionCount: expectedSectionCount,
                inMemory: inMemory,
                label: "reverse"
            )
            try await runCampaign(
                mixed,
                password: password,
                expectedTransactionCount: expectedCanonicalTransactionCount,
                expectedStatementCount: documents.count,
                expectedSectionCount: expectedSectionCount,
                inMemory: inMemory,
                label: "mixed"
            )
        }
    }

    private func deterministicMixedOrder(_ sources: [PrivateCBQSource]) -> [PrivateCBQSource] {
        var mixed = [PrivateCBQSource]()
        mixed.reserveCapacity(sources.count)
        var lower = 0
        var upper = sources.count
        while lower < upper {
            upper -= 1
            mixed.append(sources[upper])
            if lower < upper {
                mixed.append(sources[lower])
                lower += 1
            }
        }
        return mixed
    }

    private func privateCardPDFs(root: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }

        // Enumerate every directory entry, including hidden metadata.  The
        // private corpus contract permits only the nineteen statement PDFs
        // and the filesystem's known .DS_Store metadata entry.  In
        // particular, do not filter first and accidentally hide an
        // unexpected PDF, sidecar, directory, or second metadata file.
        let entries = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: []
        )
        var pdfs = [URL]()
        for entry in entries {
            let values = try entry.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            if entry.lastPathComponent == ".DS_Store" {
                guard values.isRegularFile == true else {
                    throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                }
                continue
            }
            guard values.isRegularFile == true,
                  values.isDirectory != true,
                  entry.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame,
                  entry.lastPathComponent.hasPrefix("CardStatement-") else {
                throw PrivateCBQAcceptanceError.unexpectedCorpusShape
            }
            pdfs.append(entry)
        }
        guard pdfs.count == 19 else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        return pdfs.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func runCampaign<S: Sequence>(
        _ sourceSequence: S,
        password: String,
        expectedTransactionCount: Int,
        expectedStatementCount: Int,
        expectedSectionCount: Int,
        inMemory: Bool,
        label: String
    ) async throws where S.Element == PrivateCBQSource {
        let sources = Array(sourceSequence)
        let workspaceID = "cbq-private-\(label)-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-CBQ-Private-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = folder.appendingPathComponent("acceptance.sqlite")
        let sqlite: SQLiteRepositoryProvider?
        let provider: DatabaseProvider
        if inMemory {
            sqlite = nil
            provider = DatabaseProvider(inMemory: true)
        } else {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let opened = try SQLiteRepositoryProvider(path: databaseURL.path)
            sqlite = opened
            provider = DatabaseProvider.verifiedSQLite(opened, protectsGeneration: false)
        }
        defer {
            sqlite?.database.close()
            if !inMemory { try? FileManager.default.removeItem(at: folder) }
        }

        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Private CBQ acceptance")
        )
        let hydrator = makeHydrator(provider: provider, workspaceID: workspaceID)
        let credentials = InMemoryStatementPasswordCredentialStore(passwords:
            [Institution.cbq.statementPasswordCredentialScope: password])
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(),
                passwordProvider: DefaultPasswordProvider(credentialStore: credentials,
                    supportedInstitutionCodes: [Institution.cbq.statementPasswordCredentialScope], challenge: { _ in nil })),
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
            rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )
        let cancelled = try await engine.prepareImport(from: try #require(sources.first).url)
        engine.cancelPreparedImport(cancelled)
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
        #expect(try provider.cardRepo.snapshot(workspaceId: workspaceID).statements.isEmpty)
        var accountID: String?
        for source in sources {
            let prepared = try await engine.prepareImport(from: source.url)
            defer { engine.cancelPreparedImport(prepared) }
            guard prepared.validation.passed else { throw PrivateCBQAcceptanceError.productionRejectedSource }
            #expect(prepared.fingerprintSet == source.fingerprintSet)
            let choice: ImportAccountChoice
            if let accountID {
                choice = try reuseChoice(
                    document: prepared.financialDocument,
                    accountID: accountID,
                    provider: provider,
                    workspaceID: workspaceID
                )
            } else {
                choice = .createNewCardLiabilityAccountAndInstrument
            }
            let result = await engine.commitPreparedImport(prepared, accountChoice: choice)
            #expect(result.hydrationOutcome == .committedAndHydrated, "\(source.url.lastPathComponent): \(result.errorMessage ?? "no error")")
            guard result.persisted, result.transactionCount == source.document.transactions.count else {
                throw PrivateCBQAcceptanceError.persistenceRejectedSource
            }
            if let accountID {
                guard result.accountId == accountID else {
                    throw PrivateCBQAcceptanceError.persistenceGraphMismatch
                }
            } else {
                accountID = result.accountId
            }
        }

        for duplicateSource in sources {
            let prepared = try await engine.prepareImport(from: duplicateSource.url)
            defer { engine.cancelPreparedImport(prepared) }
            let duplicate = await engine.commitPreparedImport(prepared)
            #expect(!duplicate.persisted)
            #expect(duplicate.previousImport != nil)
        }

        let newest = try #require(sources.max {
            $0.document.cardStatementEvidence!.statementDate! <
                $1.document.cardStatementEvidence!.statementDate!
        })
        let newestBalance = try #require(
            newest.document.cardStatementEvidence?.summary(code: "new_balance")?.money
        )
        try verifyCampaignGraph(
            provider: provider,
            workspaceID: workspaceID,
            sources: sources,
            expectedTransactionCount: expectedTransactionCount,
            expectedStatementCount: expectedStatementCount,
            expectedSectionCount: expectedSectionCount,
            newestBalance: newestBalance
        )
        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
            let reopened = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
            try verifyCampaignGraph(
                provider: reopened,
                workspaceID: workspaceID,
                sources: sources,
                expectedTransactionCount: expectedTransactionCount,
                expectedStatementCount: expectedStatementCount,
                expectedSectionCount: expectedSectionCount,
                newestBalance: newestBalance
            )
            try reopenedSQLite.database.checkpointAndClose()
        }
    }

    private func reuseChoice(
        document: FinancialDocument,
        accountID: String,
        provider: DatabaseProvider,
        workspaceID: String
    ) throws -> ImportAccountChoice {
        let evidence = try #require(document.cardStatementEvidence)
        let snapshot = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        let choices = try Dictionary(uniqueKeysWithValues: evidence.instrumentSections.map { section in
            let sourceValue = try #require(section.sourceIdentityObservations.first?.value)
            let matches = Set(snapshot.sectionObservations.compactMap { observation -> String? in
                guard observation.sourceValue == sourceValue,
                      let durableSection = snapshot.sections.first(where: {
                          $0.id == observation.cardStatementSectionId
                      }),
                      snapshot.instruments.contains(where: {
                          $0.id == durableSection.instrumentId && $0.liabilityAccountId == accountID
                      }) else { return nil }
                return durableSection.instrumentId
            })
            guard matches.count == 1, let instrumentID = matches.first else {
                throw PrivateCBQAcceptanceError.persistenceGraphMismatch
            }
            let choice: ImportCardInstrumentChoice = .reuseExistingInstrument(instrumentId: instrumentID)
            return (section.documentScopedSectionID, choice)
        })
        return .useExistingCardLiabilityAccountSections(accountId: accountID, sectionChoices: choices)
    }

    private func verifyCampaignGraph(
        provider: DatabaseProvider,
        workspaceID: String,
        sources: [PrivateCBQSource],
        expectedTransactionCount: Int,
        expectedStatementCount: Int,
        expectedSectionCount: Int,
        newestBalance: Money
    ) throws {
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == expectedTransactionCount)
        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == 2)
        #expect(card.instruments.allSatisfy { $0.lifecycleStateCode == CardInstrumentLifecycleState.unknown.rawValue })
        #expect(card.relationships.isEmpty)
        #expect(card.statements.count == expectedStatementCount)
        #expect(card.sections.count == expectedSectionCount)
        #expect(card.transactionEvidence.count == expectedTransactionCount)
        #expect(card.semanticGroups.isEmpty && card.semanticProjections.isEmpty && card.semanticMembers.isEmpty)

        let hydrated = try makeHydrator(provider: provider, workspaceID: workspaceID).stageHydration()
        let expectedLiability = try Money(amount: -newestBalance.amount, currency: newestBalance.currency)
        #expect(hydrated.accounts.first?.currentBalanceMoney == expectedLiability)
        #expect(hydrated.transactions.count == expectedTransactionCount)
        #expect(hydrated.cardSnapshot.instruments.count == 2)
        #expect(hydrated.cardSnapshot.statements.count == expectedStatementCount)
        let transactions = try Dictionary(uniqueKeysWithValues: hydrated.transactions.map {
            (try #require($0.repositoryTransactionId), $0)
        })
        for source in sources {
            let statement = try #require(hydrated.cardSnapshot.statements.first { $0.period == source.oracle.period })
            #expect(statement.parserProfileID == CBQCreditCardPDFParser.profileID)
            #expect(statement.parserProfileVersion == CBQCreditCardPDFParser.profileVersion)
            #expect(statement.statementDate == source.oracle.statementDate)
            #expect(statement.dueDate == source.oracle.dueDate)
            #expect(statement.minimumAmountDue == source.oracle.summary["minimum_amount_due"])
            for (code, money) in source.oracle.summary {
                #expect(statement.summaryComponents.first { $0.persistenceCode == code }?.money == money)
            }
            let durableRows = hydrated.cardSnapshot.transactionEvidence.filter { $0.statementID == statement.id }
            let actual = try durableRows.map { annotation -> String in
                let transaction = try #require(transactions[annotation.transactionID])
                let section = statement.sections.first { $0.documentScopedSectionID == annotation.documentScopedSectionID }
                #expect(transaction.sourceProvenance.contains {
                    $0.parserProfileID == CBQCreditCardPDFParser.profileID &&
                    $0.parserProfileVersion == CBQCreditCardPDFParser.profileVersion
                })
                return try semanticRowKey(postingDate: try #require(transaction.statementDate),
                    purchaseDate: annotation.sourceTransactionDate, description: transaction.description,
                    reference: transaction.reference, money: transaction.money, originalMoney: annotation.originalMerchantMoney,
                    effect: annotation.liabilityEffect, accountLevel: annotation.financialScope == .accountLevel,
                    sectionOrdinal: try #require(section?.sourceOrdinal))
            }
            let expected = try source.oracle.rows.map {
                try semanticRowKey(postingDate: $0.postingDate, purchaseDate: $0.purchaseDate,
                    description: $0.description, reference: $0.reference, money: $0.postedMoney,
                    originalMoney: $0.originalMoney, effect: $0.effect, accountLevel: $0.accountLevel,
                    sectionOrdinal: $0.sectionOrdinal)
            }
            #expect(actual.sorted() == expected.sorted(), "\(source.url.lastPathComponent): hydrated source semantics")
        }
    }

    private func semanticRowKey(postingDate: StatementDate, purchaseDate: StatementDate,
        description: String, reference: String?, money: Money, originalMoney: Money?,
        effect: CardLiabilityEffect, accountLevel: Bool, sectionOrdinal: Int) throws -> String {
        let values = [postingDate.canonical, purchaseDate.canonical, description, reference ?? "",
            money.currency.code, try money.canonicalDecimalString(), originalMoney?.currency.code ?? "",
            try originalMoney?.canonicalDecimalString() ?? "", effect.rawValue,
            accountLevel ? "account" : "instrument", String(sectionOrdinal)]
        return values.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    private func makeHydrator(provider: DatabaseProvider, workspaceID: String) -> RepositoryStoreHydrator {
        RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            accountStore: AccountStore(),
            transactionStore: TransactionStore(),
            categoryStore: CategoryStore(),
            cardStore: CardStore(),
            importSessionStore: ImportSessionStore(),
            importAttemptStore: ImportAttemptStore(),
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false
        )
    }

    func independentOracle(
        pages: [String],
        positioned: [RawPDFPageEvidence]
    ) throws -> PrivateCBQOracle {
        var rows = [PrivateCBQOracleRow]()
        var sectionTotals = [Int: Money]()
        var sectionDescriptors = [Int: PrivateCBQOracleSectionDescriptor]()
        var sectionOrdinal: Int?
        var sawTermination = false
        let rowPattern = #"^(\d{2}/\d{2}/\d{2})\s+(\d{2}/\d{2}/\d{2})\s+(.+)$"#

        for (pageOffset, page) in pages.enumerated() {
            let lines = page.components(separatedBy: .newlines).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            var index = 0
            while index < lines.count {
                let line = lines[index]
                if sawTermination {
                    // The independent scan owns the complete physical source,
                    // including every line after End of Statement.  A row-like
                    // line, section/control marker, or duplicate terminator in
                    // that tail is financial evidence and must never be
                    // silently discarded as boilerplate.
                    guard !isPostTerminationFinancialEvidence(line) else {
                        throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                    }
                    index += 1
                    continue
                }
                if isEndOfStatement(line) {
                    guard sectionOrdinal == nil else {
                        throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                    }
                    sawTermination = true
                    index += 1
                    continue
                }
                if line.range(of: "Diners Club", options: .caseInsensitive) != nil ||
                    line.range(of: "Mastercard Platinum", options: .caseInsensitive) != nil {
                    guard let descriptor = oracleSectionDescriptor(line) else {
                        throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                    }
                    if let existing = sectionDescriptors.first(where: { $0.value.label == descriptor.label }) {
                        guard existing.value.card == descriptor.card,
                              existing.value.holderLabel == descriptor.holderLabel else {
                            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                        }
                        sectionOrdinal = existing.key
                    } else {
                        let ordinal = sectionDescriptors.count + 1
                        guard ordinal <= 2 else {
                            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                        }
                        sectionDescriptors[ordinal] = descriptor
                        sectionOrdinal = ordinal
                    }
                    index += 1
                    continue
                }
                if let total = try oracleSectionTotal(line) {
                    guard let currentOrdinal = sectionOrdinal,
                          sectionTotals[currentOrdinal] == nil else {
                        throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                    }
                    sectionTotals[currentOrdinal] = total
                    sectionOrdinal = nil
                    index += 1
                    continue
                }

                guard let values = captures(rowPattern, in: line),
                      values.count == 3,
                      let activeSection = sectionOrdinal else {
                    index += 1
                    continue
                }

                var assembledTail = values[2]
                var resolvedTail = try oracleMoneyTail(assembledTail)
                var tailEndIndex = index
                if resolvedTail == nil {
                    var probe = index + 1
                    while probe < lines.count {
                        let candidate = lines[probe]
                        if candidate.isEmpty {
                            probe += 1
                            continue
                        }
                        let startsAnotherRow = captures(rowPattern, in: candidate) != nil
                        let startsSection = oracleSectionDescriptor(candidate) != nil
                        let isSectionTotal = try oracleSectionTotal(candidate) != nil
                        let isStructuralBoundary = startsAnotherRow || startsSection || isSectionTotal ||
                            candidate == "Continued on next page..." ||
                            candidate.contains("End of Statement") ||
                            candidate.hasPrefix("Card Number Card Holder Name Product Card Limit") ||
                            candidate.hasPrefix("Post Date Purchase") ||
                            candidate.hasPrefix("Date Description & Referance")
                        if isStructuralBoundary { break }

                        assembledTail += " " + candidate
                        if let tail = try oracleMoneyTail(assembledTail) {
                            resolvedTail = tail
                            tailEndIndex = probe
                            break
                        }
                        probe += 1
                    }
                }

                guard let tail = resolvedTail else {
                    throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                }
                var description = tail.description
                var reference: String?
                var next = tailEndIndex + 1
                while next < lines.count {
                    let candidate = lines[next]
                    if candidate.isEmpty { next += 1; continue }
                    let isSectionTotal = try oracleSectionTotal(candidate) != nil
                    if captures(rowPattern, in: candidate) != nil ||
                        oracleSectionDescriptor(candidate) != nil ||
                        isSectionTotal ||
                        isEndOfStatement(candidate) ||
                        candidate == "Continued on next page..." ||
                        candidate.hasPrefix("Card Number Card Holder Name Product Card Limit") ||
                        candidate.hasPrefix("Post Date Purchase") ||
                        candidate.hasPrefix("Date Description & Referance") {
                        break
                    }
                    if candidate.hasPrefix("Reference:") {
                        guard reference == nil else {
                            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                        }
                        let value = String(candidate.dropFirst("Reference:".count))
                            .trimmingCharacters(in: .whitespaces)
                        guard !value.isEmpty else {
                            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                        }
                        reference = value
                    } else {
                        description += "\n" + candidate
                    }
                    next += 1
                }
                rows.append(PrivateCBQOracleRow(
                    sourceOrdinal: rows.count + 1,
                    sourcePage: pageOffset + 1,
                    postingDate: try shortDate(values[0]),
                    purchaseDate: try shortDate(values[1]),
                    description: description,
                    reference: reference,
                    effect: tail.effect,
                    postedMoney: tail.postedMoney,
                    originalMoney: tail.originalMoney,
                    accountLevel: tail.description.hasPrefix("Paid using bankDirect"),
                    sectionOrdinal: activeSection
                ))
                index = next
            }
        }
        guard sawTermination,
              sectionOrdinal == nil,
              sectionDescriptors.count == 2,
              sectionTotals.count == sectionDescriptors.count,
              Set(sectionDescriptors.values.map(\.label)) == Set(["Diners Club", "Mastercard Platinum"]),
              !rows.isEmpty else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        let sections = try sectionDescriptors.keys.sorted().map { ordinal -> PrivateCBQOracleSection in
            guard let descriptor = sectionDescriptors[ordinal],
                  let total = sectionTotals[ordinal] else {
                throw PrivateCBQAcceptanceError.unexpectedCorpusShape
            }
            return PrivateCBQOracleSection(
                sourceOrdinal: ordinal,
                label: descriptor.label,
                holderLabel: descriptor.holderLabel,
                card: descriptor.card,
                total: total
            )
        }
        return PrivateCBQOracle(
            statementDate: try oracleNamedDate(label: "Statement Date", pages: pages),
            period: try oraclePeriod(pages: pages),
            dueDate: try oracleNamedDate(label: "Payment Due Date", pages: pages),
            rows: rows,
            sections: sections,
            sectionTotals: sectionTotals,
            summary: try independentSummary(pages: pages, positioned: positioned)
        )
    }

    private func financialMismatchCount(
        oracleRows: [PrivateCBQOracleRow],
        normalizedRows: [NormalizedRow],
        document: FinancialDocument,
        evidence: CardStatementEvidence
    ) -> Int {
        let annotations = Dictionary(uniqueKeysWithValues: evidence.transactionAnnotations.map {
            ($0.parserTransactionID, $0)
        })
        let sectionOrdinals = Dictionary(uniqueKeysWithValues: evidence.instrumentSections.map {
            ($0.documentScopedSectionID, $0.sourceOrdinal)
        })
        var mismatch = abs(oracleRows.count - document.transactions.count) +
            abs(normalizedRows.count - document.transactions.count)
        for ((oracle, normalizedRow), transaction) in zip(zip(oracleRows, normalizedRows), document.transactions) {
            guard let annotation = annotations[transaction.id] else {
                mismatch += 1
                continue
            }
            let productionSection = annotation.documentScopedSectionID.flatMap { sectionOrdinals[$0] }
            let productionAccountLevel = annotation.financialScope == .accountLevel
            let productionPage = normalizedRow.values.count > 10 ? Int(normalizedRow.values[10]) : nil
            let normalizedReference: String?
            if normalizedRow.values.indices.contains(3) {
                normalizedReference = normalizedRow.values[3].isEmpty ? nil : normalizedRow.values[3]
            } else {
                normalizedReference = nil
            }
            if transaction.sourceProvenance.first?.sourceOrdinal != oracle.sourceOrdinal ||
                transaction.statementDate != oracle.postingDate ||
                transaction.description != oracle.description ||
                transaction.reference != oracle.reference ||
                normalizedRow.values.count <= 3 ||
                normalizedRow.values[2] != oracle.description ||
                normalizedReference != oracle.reference ||
                annotation.sourceTransactionDate != oracle.purchaseDate ||
                annotation.liabilityEffect != oracle.effect ||
                transaction.money != oracle.postedMoney ||
                annotation.originalMerchantMoney != oracle.originalMoney ||
                productionAccountLevel != oracle.accountLevel ||
                productionSection != oracle.sectionOrdinal ||
                productionPage != oracle.sourcePage {
                mismatch += 1
            }
        }
        return mismatch
    }

    private func independentSectionMismatchCount(
        oracle: PrivateCBQOracle,
        evidence: CardStatementEvidence
    ) -> Int {
        var mismatch = 0
        for section in evidence.instrumentSections {
            guard let expected = oracle.sections.first(where: {
                $0.sourceOrdinal == section.sourceOrdinal
            }) else {
                mismatch += 1
                continue
            }
            let oracleRows = oracle.rows.filter { $0.sectionOrdinal == section.sourceOrdinal }
            let calculated = try? Money.aggregate(oracleRows.map(\.postedMoney))
            let productionCard = section.sourceIdentityObservations.first {
                $0.kind == .cbqInstrumentMaskedCardNumber && $0.subject == .instrument
            }?.value
            if section.documentScopedSectionID != "instrument-section-\(expected.sourceOrdinal)" ||
                section.sourceOrdinal != expected.sourceOrdinal ||
                section.holderLabel != expected.holderLabel ||
                productionCard != expected.card ||
                section.sourceIdentityObservations.count != 1 ||
                section.reconciliationRuleIdentifier != CardInstrumentSectionEvidence.cbqSignedSourceMembershipRule ||
                section.signedNetTotal != expected.total ||
                calculated != expected.total {
                mismatch += 1
            }
        }
        return mismatch + abs(evidence.instrumentSections.count - oracle.sections.count)
    }

    private func independentSummaryMismatchCount(
        oracle: PrivateCBQOracle,
        evidence: CardStatementEvidence
    ) -> Int {
        var mismatch = 0
        for (code, expected) in oracle.summary {
            if evidence.summary(code: code)?.money != expected { mismatch += 1 }
        }
        return mismatch
    }

    private func independentSummary(
        pages: [String],
        positioned: [RawPDFPageEvidence]
    ) throws -> [String: Money] {
        let preamble = pages.joined(separator: "\n").components(separatedBy: "Diners Club").first ?? ""
        let bounded = preamble.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if bounded.contains("Previous Outstanding Balance") && bounded.contains("Amount Billed") {
            let minimum = try oracleMinimumAmountDue(in: preamble)
            let previous = try oracleLabeledMoney("Previous Outstanding Balance", in: bounded)
            let billed = try oracleLabeledMoney("Amount Billed", in: bounded)
            let payment = try positive(oracleLabeledMoney("Payment Received", in: bounded))
            let current = try oracleLabeledMoney("Current Outstanding Balance", in: bounded)
            guard previous.amount + billed.amount - payment.amount == current.amount else {
                throw PrivateCBQAcceptanceError.unexpectedCorpusShape
            }
            return [
                "minimum_amount_due": minimum,
                "previous_balance": previous,
                "amount_billed": billed,
                "payment_received": payment,
                "new_balance": current
            ]
        }

        let values = try positionedV2SummaryValues(positioned)
        let minimum = try oracleMinimumAmountDue(in: preamble)
        let previous = values[0]
        let payment = try positive(values[1])
        let credit = try positive(values[2])
        let purchases = try positive(values[3])
        let installment = try positive(values[4])
        let fees = try positive(values[5])
        let current = values[6]
        let labeledCurrent = try oracleLineBoundMoney("Total Statement Balance QAR", in: preamble)
        guard labeledCurrent == current else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        guard previous.amount - payment.amount - credit.amount + purchases.amount +
                installment.amount + fees.amount == current.amount else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        return [
            "minimum_amount_due": minimum,
            "purchases": purchases,
            "billed_installment": installment,
            "fees_charges": fees,
            "previous_balance": previous,
            "total_payment": payment,
            "credit_reversal": credit,
            "new_balance": current
        ]
    }

    private func positionedV2SummaryValues(_ pages: [RawPDFPageEvidence]) throws -> [Money] {
        let moneyPattern = #"^\)?[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?\(?$"#
        var candidates = [[RawPDFTextFragment]]()
        for page in pages {
            for row in positionedFragmentRows(from: page) {
                let rowText = row.map(\.text).joined(separator: " ")
                let moneyFragments = row.filter {
                    $0.text.range(of: moneyPattern, options: .regularExpression) != nil
                }
                if moneyFragments.count == 7,
                   rowText.filter({ $0 == "+" }).count == 3,
                   rowText.filter({ $0 == "-" }).count == 2,
                   rowText.contains("=") {
                    candidates.append(moneyFragments.sorted { $0.x < $1.x })
                }
            }
        }
        guard candidates.count == 1 else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        return try candidates[0].map { try oracleSummaryMoney($0.text) }
    }

    private func positionedFragmentRows(from evidence: RawPDFPageEvidence) -> [[RawPDFTextFragment]] {
        let ordered = evidence.fragments.enumerated().sorted { lhs, rhs in
            if abs(lhs.element.y - rhs.element.y) > 1.5 { return lhs.element.y > rhs.element.y }
            if abs(lhs.element.x - rhs.element.x) > 0.1 { return lhs.element.x < rhs.element.x }
            return lhs.offset < rhs.offset
        }
        var rows: [[(offset: Int, element: RawPDFTextFragment)]] = []
        for item in ordered {
            if let last = rows.indices.last,
               let anchor = rows[last].first?.element,
               abs(anchor.y - item.element.y) <= 1.5 {
                rows[last].append((item.offset, item.element))
            } else {
                rows.append([(item.offset, item.element)])
            }
        }
        return rows.map { row in
            row.sorted { lhs, rhs in
                if abs(lhs.element.x - rhs.element.x) > 0.1 { return lhs.element.x < rhs.element.x }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }
    }

    private func oracleLabeledMoney(_ label: String, in text: String) throws -> Money {
        let escaped = NSRegularExpression.escapedPattern(for: label)
        let token = #"(?:CR\s+)?\)?[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?\(?"#
        let matches = capturesAll(escaped + #"\s+("# + token + #")"#, in: text)
        guard matches.count == 1,
              let raw = matches[0].first(where: { !$0.isEmpty }) else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        return try oracleSummaryMoney(raw)
    }

    private func oracleLineBoundMoney(_ label: String, in text: String) throws -> Money {
        let escaped = NSRegularExpression.escapedPattern(for: label)
        let token = #"(?:CR\s+)?\)?[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?\(?"#
        let candidates = text.components(separatedBy: .newlines).compactMap { line -> String? in
            guard let values = captures(#"^\s*"# + escaped + #"\s+("# + token + #")\s*$"#, in: line),
                  let raw = values.first(where: { !$0.isEmpty }) else { return nil }
            return raw
        }
        guard candidates.count == 1 else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        return try oracleSummaryMoney(candidates[0])
    }

    private func oracleMinimumAmountDue(in text: String) throws -> Money {
        let money = #"(?:CR\s+)?\)?[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?\(?"#
        let pattern = #"^\s*Minimum Amount Due\s+QAR\s+("# + money + #")(?:\s+Payment Due Date\b.*)?\s*$"#
        let candidates = text.components(separatedBy: .newlines).compactMap { line -> String? in
            captures(pattern, in: line).flatMap { values in
                values.first(where: { !$0.isEmpty })
            }
        }
        guard candidates.count == 1 else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        return try oracleSummaryMoney(candidates[0])
    }

    private func oracleSummaryMoney(_ raw: String) throws -> Money {
        let upper = raw.uppercased()
        let negative = upper.hasPrefix("CR ") || (upper.hasPrefix(")") && upper.hasSuffix("("))
        let token = upper
            .replacingOccurrences(of: "CR ", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard let amount = Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")) else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        return try Money(amount: negative ? -amount : amount, currency: "QAR")
    }

    private func positive(_ money: Money) throws -> Money {
        try Money(amount: money.amount < .zero ? -money.amount : money.amount, currency: money.currency)
    }

    private func oracleSectionTotal(_ line: String) throws -> Money? {
        guard let values = captures(
            #"^(?:[A-Z0-9]+-Total|Total\s+(?:Diners Club|Mastercard Platinum))\s+(CR\s+)?([0-9]+(?:,[0-9]{3})*\.[0-9]{2})$"#,
            in: line
        ), values.count == 2 else { return nil }
        return try sourceMoney(values[1], currency: "QAR", negative: !values[0].isEmpty)
    }

    private func capturesAll(_ pattern: String, in text: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: text) else { return "" }
                return String(text[range])
            }
        }
    }

    private func oracleMoneyTail(_ value: String) throws -> PrivateCBQOracleTail? {
        let money = #"[0-9]+(?:,[0-9]{3})*\.[0-9]{2}"#
        if let fields = captures(
            #"^(.+?)\s+(CR\s+)?([A-Z]{3})\s+("# + money + #")\s+(CR\s+)?("# + money + #")$"#,
            in: value
        ), fields.count == 6 {
            let credit = !fields[1].isEmpty || !fields[4].isEmpty
            return PrivateCBQOracleTail(
                description: fields[0],
                effect: credit ? .decreasesAmountOwed : .increasesAmountOwed,
                postedMoney: try sourceMoney(fields[5], currency: "QAR", negative: credit),
                originalMoney: try sourceMoney(fields[3], currency: fields[2], negative: credit)
            )
        }
        if let fields = captures(
            #"^(.+?)\s+(CR\s+)?("# + money + #")$"#,
            in: value
        ), fields.count == 3 {
            let credit = !fields[1].isEmpty
            return PrivateCBQOracleTail(
                description: fields[0],
                effect: credit ? .decreasesAmountOwed : .increasesAmountOwed,
                postedMoney: try sourceMoney(fields[2], currency: "QAR", negative: credit),
                originalMoney: nil
            )
        }
        return nil
    }

    private func sourceMoney(_ value: String, currency: String, negative: Bool) throws -> Money {
        guard let amount = Decimal(
            string: value.replacingOccurrences(of: ",", with: ""),
            locale: Locale(identifier: "en_US_POSIX")
        ) else { throw PrivateCBQAcceptanceError.unexpectedCorpusShape }
        return try Money(amount: negative ? -amount : amount, currency: CurrencyCode(currency))
    }

    private func shortDate(_ value: String) throws -> StatementDate {
        let parts = value.split(separator: "/")
        guard parts.count == 3,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        return try StatementDate(year: year < 100 ? 2000 + year : year, month: month, day: day)
    }

    private func oraclePeriod(pages: [String]) throws -> DeclaredStatementPeriod {
        let fields = try #require(captures(#"Statement Period\s+(\d{2}/\d{2}/\d{4})\s*-\s*(\d{2}/\d{2}/\d{4})"#,
            in: pages.joined(separator: "\n")))
        return try DeclaredStatementPeriod(start: shortDate(fields[0]), end: shortDate(fields[1]))
    }

    private func oracleNamedDate(label: String, pages: [String]) throws -> StatementDate {
        let fields = try #require(captures(NSRegularExpression.escapedPattern(for: label) + #"\s+(\d{1,2})\s+([A-Za-z]+),\s*(\d{4})"#,
            in: pages.joined(separator: "\n")))
        let months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
        return try StatementDate(year: #require(Int(fields[2])), month: #require(months.firstIndex(of: fields[1].lowercased())) + 1,
            day: #require(Int(fields[0])))
    }

    private func oracleSectionDescriptor(_ line: String) -> PrivateCBQOracleSectionDescriptor? {
        let label: String
        if line.range(of: "Diners Club", options: .caseInsensitive) != nil {
            label = "Diners Club"
        } else if line.range(of: "Mastercard Platinum", options: .caseInsensitive) != nil {
            label = "Mastercard Platinum"
        } else {
            return nil
        }
        guard let labelRange = line.range(of: label, options: .caseInsensitive) else {
            return nil
        }
        let separators = CharacterSet(charactersIn: "\t |")
        for rawToken in line.components(separatedBy: separators).filter({ !$0.isEmpty }) {
            let normalized = rawToken.uppercased().replacingOccurrences(of: "*", with: "X")
            guard normalized.count >= 8,
                  normalized.contains("X"),
                  normalized.contains(where: \.isNumber),
                  normalized.allSatisfy({ $0.isNumber || $0 == "X" }),
                  let cardRange = line.range(of: rawToken, options: .caseInsensitive),
                  cardRange.upperBound <= labelRange.lowerBound else {
                continue
            }
            let holder = line[cardRange.upperBound..<labelRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return PrivateCBQOracleSectionDescriptor(
                label: label,
                holderLabel: holder.isEmpty ? nil : holder,
                card: normalized
            )
        }
        return nil
    }

    private func isEndOfStatement(_ line: String) -> Bool {
        line.range(
            of: #"^(?:X+|\*+|<+|>+|-+|=+|\s+)*End of Statement(?:X+|\*+|<+|>+|-+|=+|\s+)*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func isPostTerminationFinancialEvidence(_ line: String) -> Bool {
        if isEndOfStatement(line) ||
            captures(#"^\d{2}/\d{2}/(?:\d{2}|\d{4})\s+\d{2}/\d{2}/(?:\d{2}|\d{4})\s+.+$"#, in: line) != nil ||
            line.range(
                of: #"\b\d{1,2}/\d{1,2}/\d{2,4}\b.*(?:CR\s+)?[0-9]+(?:,[0-9]{3})*\.[0-9]{1,2}\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil ||
            oracleSectionDescriptor(line) != nil ||
            (try? oracleSectionTotal(line)) != nil {
            return true
        }

        let structuralHeaders = [
            "Card Account Reference",
            "Card Number Card Holder Name Product Card Limit",
            "Post Date Purchase Date",
            "Date Description & Referance",
            "Post Date Purchase Date Description & Referance"
        ]
        if structuralHeaders.contains(where: { line.hasPrefix($0) }) ||
            line.hasPrefix("Reference:") {
            return true
        }

        let controlLabels = [
            "Statement Date",
            "Statement Period",
            "Payment Due Date",
            "Previous Outstanding Balance",
            "Amount Billed",
            "Payment Received",
            "Current Outstanding Balance",
            "Total Statement Balance",
            "Minimum Amount Due",
            "Purchases",
            "Billed Installment",
            "Fees and Charges",
            "Total Payment",
            "Credit Reversal"
        ]
        if controlLabels.contains(where: { line.hasPrefix($0) }),
           line.range(
               of: #"\b[0-9]+(?:,[0-9]{3})*\.[0-9]{1,2}\b(?!\s*%)"#,
               options: [.regularExpression]
           ) != nil {
            return true
        }

        let compact = line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return compact.contains("=") && compact.filter({ $0 == "+" }).count == 3 &&
            compact.filter({ $0 == "-" }).count == 2
    }

    private func captures(_ pattern: String, in text: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        return (1..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range])
        }
    }


}

private enum PrivateCBQAcceptanceError: Error {
    case credentialUnavailable
    case unexpectedCorpusShape
    case productionRejectedSource
    case persistenceRejectedSource
    case persistenceGraphMismatch
}

@MainActor
private struct PrivateCBQSource {
    let url: URL
    let document: FinancialDocument
    let fingerprintSet: PreparedDocumentFingerprintSet
    let oracle: PrivateCBQOracle
    let oracleRowCount: Int
    let physicalPageCount: Int
}

@MainActor
private struct PrivateCBQOracleTail {
    let description: String
    let effect: CardLiabilityEffect
    let postedMoney: Money
    let originalMoney: Money?
}

@MainActor
private struct PrivateCBQOracleSectionDescriptor {
    let label: String
    let holderLabel: String?
    let card: String
}

@MainActor
struct PrivateCBQOracleSection {
    let sourceOrdinal: Int
    let label: String
    let holderLabel: String?
    let card: String
    let total: Money
}

@MainActor
struct PrivateCBQOracleRow {
    let sourceOrdinal: Int
    let sourcePage: Int
    let postingDate: StatementDate
    let purchaseDate: StatementDate
    let description: String
    let reference: String?
    let effect: CardLiabilityEffect
    let postedMoney: Money
    let originalMoney: Money?
    let accountLevel: Bool
    let sectionOrdinal: Int
}

@MainActor
struct PrivateCBQOracle {
    let statementDate: StatementDate
    let period: DeclaredStatementPeriod
    let dueDate: StatementDate
    let rows: [PrivateCBQOracleRow]
    let sections: [PrivateCBQOracleSection]
    let sectionTotals: [Int: Money]
    let summary: [String: Money]
}
