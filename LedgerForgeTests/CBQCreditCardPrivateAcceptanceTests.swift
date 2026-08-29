import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// Opt-in production-path acceptance for the private encrypted CBQ corpus.
/// The private root is supplied only at runtime; the credential must already exist
/// in the ordinary production Keychain scope and is consumed only through
/// `DefaultPasswordProvider`. Encrypted source bytes traverse the ordinary snapshot,
/// coordinator, PDFKit reader, normalizer, parser, validator, persistence, and
/// hydration boundaries. No private path, credential, source value, decrypted PDF,
/// or row is committed or printed.
@MainActor
@Suite(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "LEDGERFORGE_PRIVATE_CBQ_TEXT_DIRECTORY"
        ]?.isEmpty == false,
        "Requires the private CBQ credit-card corpus"
    )
)
struct CBQCreditCardPrivateAcceptanceTests {
    // Keep the historical root key so existing private-context wiring remains compatible.
    // The value is now treated as the CBQ private root, not as a text-fixture directory.
    private static let rootEnvironmentKey = "LEDGERFORGE_PRIVATE_CBQ_TEXT_DIRECTORY"

    @Test(.globalRuntimeStateIsolation)
    func completePrivateCorpusMatchesProductionGrammarAndAggregateOracle() async throws {
        guard let rootPath = ProcessInfo.processInfo.environment[Self.rootEnvironmentKey],
              !rootPath.isEmpty else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let urls = try privateCardPDFs(root: root)
        guard urls.count == 8 else { throw PrivateCBQAcceptanceError.unexpectedCorpusShape }

        let passwordProvider = DefaultPasswordProvider(
            supportedInstitutionCodes: [Institution.cbq.statementPasswordCredentialScope],
            challenge: { _ in throw PrivateCBQAcceptanceError.credentialUnavailable }
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

        for url in urls {
            do {
                let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
                guard let lockedDocument = PDFDocument(data: bytes), lockedDocument.isLocked else {
                    throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                }

                let request = ImportRequest(fileURL: url)
                let directSnapshot = SourceContentSnapshot(bytes: bytes)
                let raw = try await PDFDocumentReader().read(
                    request: request,
                    snapshot: directSnapshot,
                    password: password
                )
                guard let pages = raw.pdfPageTexts, pages.count == 3,
                      let positioned = raw.pdfPageEvidence, positioned.count == 3,
                      positioned.allSatisfy({ !$0.fragments.isEmpty }) else {
                    throw PrivateCBQAcceptanceError.unexpectedCorpusShape
                }
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
                      prepared.rawContents == rawText,
                      prepared.sourceSnapshot.sourceByteFingerprint == directSnapshot.sourceByteFingerprint else {
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
                rowMismatchCount += financialMismatchCount(
                    oracleRows: oracle.rows,
                    normalizedRows: normalized.rows,
                    document: document,
                    evidence: evidence
                )
                sectionMismatchCount += independentSectionMismatchCount(oracle: oracle, evidence: evidence)
                summaryMismatchCount += independentSummaryMismatchCount(oracle: oracle, evidence: evidence)
                sources.append(PrivateCBQSource(
                    document: document,
                    fingerprintSet: prepared.fingerprintSet,
                    oracleRowCount: oracle.rows.count
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
        #expect(productionRowCounts == oracleRowCounts)
        #expect(productionRowCounts.reduce(0, +) == expectedCanonicalTransactionCount)
        print("CBQ_PRIVATE_ACCEPTANCE sources=8 canonicalTransactions=\(expectedCanonicalTransactionCount)")
        #expect(rowMismatchCount == 0)
        #expect(sectionMismatchCount == 0)
        #expect(summaryMismatchCount == 0)
        #expect(documents.prefix(4).allSatisfy {
            $0.cardStatementEvidence?.reconciliationRuleIdentifier == CardStatementEvidence.cbqV1QARReconciliationRule
        })
        #expect(documents.suffix(4).allSatisfy {
            $0.cardStatementEvidence?.reconciliationRuleIdentifier == CardStatementEvidence.cbqV2QARReconciliationRule
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

        var validAdjacentContinuities = 0
        for (earlier, later) in zip(documents, documents.dropFirst()) {
            let earlierEvidence = try #require(earlier.cardStatementEvidence)
            let laterEvidence = try #require(later.cardStatementEvidence)
            let earlierPeriod = try #require(earlierEvidence.declaredStatementPeriod)
            let laterPeriod = try #require(laterEvidence.declaredStatementPeriod)
            let calendar = Calendar(identifier: .gregorian)
            let endDate = try #require(calendar.date(from: DateComponents(
                year: earlierPeriod.end.year, month: earlierPeriod.end.month, day: earlierPeriod.end.day
            )))
            let startDate = try #require(calendar.date(from: DateComponents(
                year: laterPeriod.start.year, month: laterPeriod.start.month, day: laterPeriod.start.day
            )))
            if calendar.date(byAdding: .day, value: 1, to: endDate) == startDate {
                validAdjacentContinuities += 1
            }
        }
        #expect(validAdjacentContinuities == 6)

        let mixedIndices = [7, 2, 5, 0, 6, 1, 4, 3]
        let mixed = mixedIndices.map { chronologicalSources[$0] }
        for inMemory in [true, false] {
            try runCampaign(
                chronologicalSources,
                expectedTransactionCount: expectedCanonicalTransactionCount,
                inMemory: inMemory,
                label: "chronological"
            )
            try runCampaign(
                chronologicalSources.reversed(),
                expectedTransactionCount: expectedCanonicalTransactionCount,
                inMemory: inMemory,
                label: "reverse"
            )
            try runCampaign(
                mixed,
                expectedTransactionCount: expectedCanonicalTransactionCount,
                inMemory: inMemory,
                label: "mixed"
            )
        }
    }

    private func privateCardPDFs(root: URL) throws -> [URL] {
        let creditCards = root.appendingPathComponent("CreditCards", isDirectory: true)
        var isDirectory: ObjCBool = false
        let directory = FileManager.default.fileExists(atPath: creditCards.path, isDirectory: &isDirectory) && isDirectory.boolValue
            ? creditCards
            : root
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true &&
                url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame &&
                url.lastPathComponent.hasPrefix("CardStatement-")
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func runCampaign<S: Sequence>(
        _ sourceSequence: S,
        expectedTransactionCount: Int,
        inMemory: Bool,
        label: String
    ) throws where S.Element == PrivateCBQSource {
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
        var accountID: String?
        for source in sources {
            let validation = ImportValidator.validate(financialDocument: source.document)
            guard validation.passed else { throw PrivateCBQAcceptanceError.productionRejectedSource }
            let session = ImportSession(
                fileName: source.document.sourceDocument.filename,
                institution: .cbq,
                documentType: .creditCard,
                parserName: "CBQ Credit Card PDF",
                transactionCount: source.document.transactions.count,
                validation: validation
            )
            let choice: ImportAccountChoice
            if let accountID {
                choice = try reuseChoice(
                    document: source.document,
                    accountID: accountID,
                    provider: provider,
                    workspaceID: workspaceID
                )
            } else {
                choice = .createNewCardLiabilityAccountAndInstrument
            }
            let result = try coordinator.persistValidatedImport(
                financialDocument: source.document,
                importSession: session,
                validation: validation,
                fingerprintSet: source.fingerprintSet,
                accountChoice: choice,
                providerGeneration: provider.generationToken
            )
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

        let duplicateSource = try #require(sources.first)
        let duplicateValidation = ImportValidator.validate(financialDocument: duplicateSource.document)
        let duplicateSession = ImportSession(
            fileName: duplicateSource.document.sourceDocument.filename,
            institution: .cbq,
            documentType: .creditCard,
            parserName: "CBQ Credit Card PDF",
            transactionCount: duplicateSource.document.transactions.count,
            validation: duplicateValidation
        )
        let duplicate = try coordinator.persistValidatedImport(
            financialDocument: duplicateSource.document,
            importSession: duplicateSession,
            validation: duplicateValidation,
            fingerprintSet: duplicateSource.fingerprintSet,
            accountChoice: nil,
            providerGeneration: provider.generationToken
        )
        #expect(!duplicate.persisted)

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
            expectedTransactionCount: expectedTransactionCount,
            newestBalance: newestBalance
        )
        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
            let reopened = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
            try verifyCampaignGraph(
                provider: reopened,
                workspaceID: workspaceID,
                expectedTransactionCount: expectedTransactionCount,
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
        expectedTransactionCount: Int,
        newestBalance: Money
    ) throws {
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == expectedTransactionCount)
        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == 2)
        #expect(card.instruments.allSatisfy { $0.lifecycleStateCode == CardInstrumentLifecycleState.unknown.rawValue })
        #expect(card.relationships.isEmpty)
        #expect(card.statements.count == 8)
        #expect(card.sections.count == 16)
        #expect(card.transactionEvidence.count == expectedTransactionCount)
        #expect(card.semanticGroups.isEmpty && card.semanticProjections.isEmpty && card.semanticMembers.isEmpty)

        let hydrator = RepositoryStoreHydrator(
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
        let hydrated = try hydrator.stageHydration()
        let expectedLiability = try Money(amount: -newestBalance.amount, currency: newestBalance.currency)
        #expect(hydrated.accounts.first?.currentBalanceMoney == expectedLiability)
        #expect(hydrated.transactions.count == expectedTransactionCount)
        #expect(hydrated.cardSnapshot.instruments.count == 2)
        #expect(hydrated.cardSnapshot.statements.count == 8)
    }

    private func independentOracle(
        pages: [String],
        positioned: [RawPDFPageEvidence]
    ) throws -> PrivateCBQOracle {
        var rows = [PrivateCBQOracleRow]()
        var sectionTotals = [Int: Money]()
        var sectionOrdinal: Int?
        let rowPattern = #"^(\d{2}/\d{2}/\d{2})\s+(\d{2}/\d{2}/\d{2})\s+(.+)$"#

        for (pageOffset, page) in pages.enumerated() {
            let lines = page.components(separatedBy: .newlines).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            var index = 0
            while index < lines.count {
                let line = lines[index]
                if line.range(of: "Diners Club", options: .caseInsensitive) != nil,
                   line.range(of: #"[0-9X*]{8,}"#, options: .regularExpression) != nil {
                    sectionOrdinal = 1
                    index += 1
                    continue
                }
                if line.range(of: "Mastercard Platinum", options: .caseInsensitive) != nil,
                   line.range(of: #"[0-9X*]{8,}"#, options: .regularExpression) != nil {
                    sectionOrdinal = 2
                    index += 1
                    continue
                }
                if let total = try oracleSectionTotal(line) {
                    guard let currentOrdinal = sectionOrdinal else {
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
                        let startsSection = (
                            candidate.range(of: "Diners Club", options: .caseInsensitive) != nil ||
                            candidate.range(of: "Mastercard Platinum", options: .caseInsensitive) != nil
                        ) && candidate.range(of: #"[0-9X*]{8,}"#, options: .regularExpression) != nil
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
                    index += 1
                    continue
                }
                rows.append(PrivateCBQOracleRow(
                    sourceOrdinal: rows.count + 1,
                    sourcePage: pageOffset + 1,
                    postingDate: try shortDate(values[0]),
                    purchaseDate: try shortDate(values[1]),
                    effect: tail.effect,
                    postedMoney: tail.postedMoney,
                    originalMoney: tail.originalMoney,
                    accountLevel: tail.description.hasPrefix("Paid using bankDirect"),
                    sectionOrdinal: activeSection
                ))
                index = tailEndIndex + 1
            }
        }
        guard sectionTotals.count == 2 else { throw PrivateCBQAcceptanceError.unexpectedCorpusShape }
        return PrivateCBQOracle(
            rows: rows,
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
            if transaction.sourceProvenance.first?.sourceOrdinal != oracle.sourceOrdinal ||
                transaction.statementDate != oracle.postingDate ||
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
            let printed = oracle.sectionTotals[section.sourceOrdinal]
            let oracleRows = oracle.rows.filter { $0.sectionOrdinal == section.sourceOrdinal }
            let calculated = try? Money.aggregate(oracleRows.map(\.postedMoney))
            if printed == nil || section.signedNetTotal != printed || calculated != printed {
                mismatch += 1
            }
        }
        return mismatch + abs(evidence.instrumentSections.count - oracle.sectionTotals.count)
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
            let previous = try oracleLabeledMoney("Previous Outstanding Balance", in: bounded)
            let billed = try oracleLabeledMoney("Amount Billed", in: bounded)
            let payment = try positive(oracleLabeledMoney("Payment Received", in: bounded))
            let current = try oracleLabeledMoney("Current Outstanding Balance", in: bounded)
            guard previous.amount + billed.amount - payment.amount == current.amount else {
                throw PrivateCBQAcceptanceError.unexpectedCorpusShape
            }
            return [
                "previous_balance": previous,
                "amount_billed": billed,
                "payment_received": payment,
                "new_balance": current
            ]
        }

        let values = try positionedV2SummaryValues(positioned)
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
        return try StatementDate(year: 2000 + year, month: month, day: day)
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
    let document: FinancialDocument
    let fingerprintSet: PreparedDocumentFingerprintSet
    let oracleRowCount: Int
}

@MainActor
private struct PrivateCBQOracleTail {
    let description: String
    let effect: CardLiabilityEffect
    let postedMoney: Money
    let originalMoney: Money?
}

@MainActor
private struct PrivateCBQOracleRow {
    let sourceOrdinal: Int
    let sourcePage: Int
    let postingDate: StatementDate
    let purchaseDate: StatementDate
    let effect: CardLiabilityEffect
    let postedMoney: Money
    let originalMoney: Money?
    let accountLevel: Bool
    let sectionOrdinal: Int
}

@MainActor
private struct PrivateCBQOracle {
    let rows: [PrivateCBQOracleRow]
    let sectionTotals: [Int: Money]
    let summary: [String: Money]
}
