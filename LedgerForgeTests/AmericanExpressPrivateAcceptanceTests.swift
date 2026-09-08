import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// Required acceptance for the encrypted American Express originals. The
/// manifest is an independently frozen source oracle; production output is
/// compared only after the source bytes have been checked against that oracle.
/// No private value is committed, printed, or used as a fixture.
@MainActor
struct AmericanExpressPrivateAcceptanceTests {
    @Test
    func explicitPrivateContextPresenceTreatsEmptyValuesAsRequested() {
        #expect(PrivateAmexContext.explicitContextRequested(in: [
            PrivateAmexContext.rootKey: ""
        ]))
        #expect(PrivateAmexContext.explicitContextRequested(in: [
            PrivateAmexContext.passwordKey: "   "
        ]))
        #expect(!PrivateAmexContext.explicitContextRequested(in: [:]))
    }

    @Test
    func malformedPrivateContextFailsClosed() {
        #expect(throws: PrivateAcceptanceError.self) {
            try PrivateAmexContext.load(environment: [
                PrivateAmexContext.rootKey: " ",
                PrivateAmexContext.passwordKey: "\n",
                PrivateAmexContext.oracleKey: ""
            ])
        }
        #expect(throws: PrivateAcceptanceError.self) {
            try PrivateAmexContext.load(environment: [
                PrivateAmexContext.rootKey: "/tmp",
                PrivateAmexContext.passwordKey: "x"
            ])
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func completePrivateCorpusMatchesFrozenOracleAndImportCampaigns() async throws {
        let context = try PrivateAmexContext.load()
        let sources = try context.loadSources()
        try context.validateManifest(sources: sources)

        // The first pass is deliberately preparation-only. It exercises the
        // real encrypted snapshot, password orchestration, PDFKit reader,
        // routing, normalizer, parser, and validation for every source before
        // any account or card state is created.
        try await verifyProductionAgainstOracle(sources: sources, password: context.password)

        let chronological = sources.sorted {
            ($0.oracle.statementPeriod.start, $0.oracle.basename) <
                ($1.oracle.statementPeriod.start, $1.oracle.basename)
        }
        let reverse = Array(chronological.reversed())
        let mixed = chronological.sorted {
            ($0.oracle.sourceSHA256, $0.oracle.basename) <
                ($1.oracle.sourceSHA256, $1.oracle.basename)
        }

        var baseline: String?
        for inMemory in [true, false] {
            for (name, order) in [
                ("chronological", chronological),
                ("reverse", reverse),
                ("mixed", mixed)
            ] {
                let result = try await runCampaign(
                    sources: order,
                    inMemory: inMemory,
                    password: context.password,
                    name: name
                )
                if let baseline {
                    #expect(result == baseline)
                } else {
                    baseline = result
                }
            }
            try await verifyExactDuplicate(
                source: try #require(chronological.first),
                inMemory: inMemory,
                password: context.password
            )
        }
    }

    private func verifyProductionAgainstOracle(
        sources: [PrivateAmexSource],
        password: String
    ) async throws {
        let runtime = try makeRuntime(
            workspaceID: "amex-private-oracle-\(UUID().uuidString)",
            inMemory: true,
            password: password
        )
        defer { runtime.cleanup() }

        var failures = 0
        for source in sources {
            do {
            let prepared = try await runtime.engine.prepareImport(from: source.url)
            defer { runtime.engine.cancelPreparedImport(prepared) }
            guard prepared.validation.passed,
                  prepared.detectedInstitution == .amex,
                  prepared.detectedDocumentType == .creditCard,
                  prepared.parserName == "American Express Credit Card PDF" else {
                throw PrivateAcceptanceError.productionRejectedSource
            }
            try compare(prepared: prepared, to: source.oracle)
            } catch {
                failures += 1
                Issue.record("\(source.url.lastPathComponent): \(error)")
            }
        }
        guard failures == 0 else { throw PrivateAcceptanceError.productionRejectedSource }
    }

    private func compare(
        prepared: PreparedImport,
        to oracle: OracleSource
    ) throws {
        let document = prepared.financialDocument
        let recomputedSourceFingerprint = try prepared.sourceSnapshot.recomputedSourceByteFingerprint()
        guard recomputedSourceFingerprint.algorithm == SourceContentSnapshot.algorithm,
              recomputedSourceFingerprint.digest == oracle.sourceSHA256,
              recomputedSourceFingerprint.byteCount == oracle.sourceByteSize,
              prepared.sourceSnapshot.sourceByteFingerprint == recomputedSourceFingerprint,
              let duplicateAuthority = prepared.fingerprintSet.duplicateAuthority,
              duplicateAuthority.algorithm == SourceContentSnapshot.algorithm,
              duplicateAuthority.digest == oracle.sourceSHA256,
              duplicateAuthority.byteCount == oracle.sourceByteSize else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        guard document.sourceDocument.filename == oracle.basename,
              document.bookedCurrency?.code == oracle.nativeCurrency,
              document.declaredStatementPeriod?.start.canonical == oracle.statementPeriod.start,
              document.declaredStatementPeriod?.end.canonical == oracle.statementPeriod.end,
              document.transactions.count == oracle.rows.count,
              let evidence = document.cardStatementEvidence,
              evidence.statementDate?.canonical == oracle.statementDate,
              evidence.declaredStatementPeriod?.start.canonical == oracle.statementPeriod.start,
              evidence.declaredStatementPeriod?.end.canonical == oracle.statementPeriod.end,
              evidence.nativeCurrency.code == oracle.nativeCurrency,
              evidence.accountSourceIdentityObservations.count == 1,
              evidence.accountSourceIdentityObservations[0].value == oracle.identity.membershipNumberMasked,
              evidence.reconciliationRuleIdentifier == CardStatementEvidence.amexQARReconciliationRule else {
            throw PrivateAcceptanceError.productionMismatchAt("statement-metadata")
        }

        guard let dueDate = evidence.summary(code: "due_date")?.date,
              dueDate.canonical == oracle.dueDate,
              moneyMatches(evidence.summary(code: "previous_balance")?.money, oracle.summary.previousBalance),
              moneyMatches(evidence.summary(code: "new_credits")?.money, oracle.summary.newCredits),
              moneyMatches(evidence.summary(code: "new_debits")?.money, oracle.summary.newDebits),
              moneyMatches(evidence.summary(code: "new_balance")?.money, oracle.summary.newBalance),
              oracle.summary.reconciliationResidual == 0,
              oracle.summary.oracleCalculated.statementEquationResidualMinorUnits == 0 else {
            throw PrivateAcceptanceError.productionMismatchAt("summary")
        }
        let previous = try materialize(oracle.summary.previousBalance)
        let credits = try materialize(oracle.summary.newCredits)
        let debits = try materialize(oracle.summary.newDebits)
        let balance = try materialize(oracle.summary.newBalance)
        guard try (previous - credits) + debits == balance else {
            throw PrivateAcceptanceError.productionMismatchAt("summary-equation")
        }

        guard evidence.instrumentSections.count == oracle.sections.count else {
            throw PrivateAcceptanceError.productionMismatchAt("section-envelope")
        }
        let sectionsByID = Dictionary(uniqueKeysWithValues: evidence.instrumentSections.map {
            ($0.documentScopedSectionID, $0)
        })
        for (index, pair) in zip(evidence.instrumentSections, oracle.sections).enumerated() {
            let actual = pair.0
            let expected = pair.1
            let expectedPrinted = try #require(expected.printedTotals.count == expected.printedTotalCount
                ? expected.printedTotals.first : nil)
            let expectedComparison = try #require(expected.oracleCalculated.printedTotalComparisons.count == expected.printedTotalCount
                ? expected.oracleCalculated.printedTotalComparisons.first : nil)
            guard expected.oracleCalculated.allPrintedTotalsMatch,
                  expected.oracleCalculated.rowCount == expected.rowOrdinals.count,
                  expectedComparison.matches,
                  expectedComparison.currency == expectedPrinted.currency,
                  expectedComparison.sourceDecimal == expectedPrinted.sourceDecimal,
                  expectedComparison.page == expectedPrinted.page,
                  expectedComparison.line == expectedPrinted.line,
                  expectedComparison.lineText == expectedPrinted.lineText,
                  expectedComparison.residualMinorUnits == 0,
                  expectedComparison.calculatedSignedMinorUnits == expected.oracleCalculated.netActivity.minorUnits,
                  actual.sourceOrdinal == index + 1,
                  actual.documentScopedSectionID == AmericanExpressCreditCardPDFNormalizer.instrumentSectionID(ordinal: index + 1),
                  actual.sourceIdentityObservations.count == 1,
                  actual.sourceIdentityObservations[0].value == expected.accountMasked,
                  digest(actual.sourceIdentityObservations[0].value) == expected.accountKeyHash,
                  let expectedHolderDigest = oracle.holderLabelDigest(for: expected),
                  let actualHolderLabel = actual.holderLabel,
                  digest(actualHolderLabel) == expectedHolderDigest,
                  moneyMatches(actual.signedNetTotal, expected.oracleCalculated.netActivity),
                  expectedPrinted.currency == oracle.nativeCurrency,
                  (try? actual.signedNetTotal.minorUnits()) == expectedComparison.printedSignedMinorUnits else {
                throw PrivateAcceptanceError.productionMismatchAt("section-values")
            }
            let actualSectionEvents = evidence.transactionAnnotations.compactMap { annotation -> Transaction? in
                guard annotation.documentScopedSectionID == actual.documentScopedSectionID else { return nil }
                return document.transactions.first(where: { $0.id == annotation.parserTransactionID })
            }
            let actualRowOrdinals = actualSectionEvents.compactMap { $0.sourceProvenance.first?.sourceOrdinal }
            let actualCalculatedMinor = actualSectionEvents.reduce(Int64.zero) { partial, transaction in
                partial + ((try? transaction.money.minorUnits()) ?? 0)
            }
            guard actualRowOrdinals == expected.rowOrdinals,
                  actualCalculatedMinor == expected.oracleCalculated.netActivity.minorUnits,
                  expectedComparison.printedSignedMinorUnits - actualCalculatedMinor == expectedComparison.residualMinorUnits else {
                throw PrivateAcceptanceError.productionMismatchAt("section-membership")
            }
        }

        guard evidence.transactionAnnotations.count == oracle.rows.count else {
            throw PrivateAcceptanceError.productionMismatchAt("annotation-envelope")
        }
        let annotations = Dictionary(uniqueKeysWithValues: evidence.transactionAnnotations.map {
            ($0.parserTransactionID, $0)
        })
        for (transaction, expected) in zip(document.transactions, oracle.rows) {
            guard transaction.sourceProvenance.count == 1,
                  let provenance = transaction.sourceProvenance.first,
                  let annotation = annotations[transaction.id] else {
                throw PrivateAcceptanceError.productionMismatchAt("row-provenance")
            }
            guard provenance.sourceOrdinal == expected.globalSourceOrdinal else {
                throw PrivateAcceptanceError.productionMismatchAt("row-ordinal")
            }
            guard provenance.sourcePage == expected.page else {
                throw PrivateAcceptanceError.productionMismatchAt("row-page")
            }
            guard provenance.parserProfileID == AmericanExpressCreditCardPDFParser.profileID,
                  provenance.parserProfileVersion == AmericanExpressCreditCardPDFParser.profileVersion else {
                throw PrivateAcceptanceError.productionMismatchAt("row-profile")
            }
            guard transaction.statementDate?.canonical == expected.postingDate,
                  transaction.financialDateRole == .postingDate else {
                throw PrivateAcceptanceError.productionMismatchAt("row-date")
            }
            guard annotation.sourceTransactionDate.canonical == expected.transactionDate else {
                throw PrivateAcceptanceError.productionMismatchAt("row-source-date")
            }
            guard transaction.reference == expected.sourceReference else {
                throw PrivateAcceptanceError.productionMismatchAt("row-reference")
            }
            guard annotation.liabilityEffect == expected.liabilityEffect,
                  annotation.financialScope.persistenceCode == expected.financialScope else {
                throw PrivateAcceptanceError.productionMismatchAt("row-semantics")
            }
            let moneyMatchesExpected = moneyMatches(transaction.money, expected.signedPostedMoney)
            // Oracle v6 records both the source-canonical description (space
            // joined) and the raw line-segment digest. Compare both: the
            // canonical form proves the exact source text while the raw form
            // preserves production's newline-delimited continuation semantics.
            let descriptionRawDigest = digest(transaction.description)
            let descriptionCanonicalDigest = digest(transaction.description.replacingOccurrences(of: "\n", with: " "))
            let descriptionMatchesExpected = descriptionRawDigest == expected.descriptionSourceRawSegmentsSHA256
            let descriptionCanonicalMatchesExpected = descriptionCanonicalDigest == digest(expected.descriptionSourceExact)
            let originalMoneyMatchesExpected = moneyMatches(annotation.originalMerchantMoney, expected.signedOriginalMoney)
            guard moneyMatchesExpected,
                  descriptionMatchesExpected,
                  descriptionCanonicalMatchesExpected,
                  originalMoneyMatchesExpected else {
                throw PrivateAcceptanceError.productionMismatchAt(
                    "row \(expected.globalSourceOrdinal): money=\(moneyMatchesExpected), rawDescription=\(descriptionMatchesExpected), canonicalDescription=\(descriptionCanonicalMatchesExpected), originalMoney=\(originalMoneyMatchesExpected); actual description=\(transaction.description), source description=\(expected.descriptionSourceExact); actual original=\(String(describing: annotation.originalMerchantMoney)), source original=\(String(describing: expected.signedOriginalMoney))"
                )
            }

            if let expectedSectionAccount = expected.sectionAccountMasked {
                guard let sectionID = annotation.documentScopedSectionID,
                      let section = sectionsByID[sectionID],
                      section.sourceIdentityObservations.first?.value == expectedSectionAccount,
                      expected.sectionAccountKeyHash == digest(expectedSectionAccount),
                      section.sourceIdentityObservations.first.map({ digest($0.value) }) == expected.sectionAccountKeyHash else {
                    throw PrivateAcceptanceError.productionMismatchAt("row-section")
                }
            } else {
                guard annotation.documentScopedSectionID == nil,
                      annotation.financialScope == .accountLevel else {
                    throw PrivateAcceptanceError.productionMismatchAt("row-account")
                }
            }
        }
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func runCampaign(
        sources: [PrivateAmexSource],
        inMemory: Bool,
        password: String,
        name: String
    ) async throws -> String {
        let workspaceID = "amex-private-\(name)-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let runtime = try makeRuntime(workspaceID: workspaceID, inMemory: inMemory, password: password)
        defer { runtime.cleanup() }

        let expected = try CampaignExpectation(sources: sources)
        var accountID: String?
        var importedPeriods = Set<String>()

        let cancelled = try await runtime.engine.prepareImport(from: try #require(sources.first).url)
        runtime.engine.cancelPreparedImport(cancelled)
        #expect(try runtime.provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        #expect(try runtime.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
        #expect(try runtime.provider.cardRepo.snapshot(workspaceId: workspaceID).statements.isEmpty)

        for source in sources {
            let prepared = try await runtime.engine.prepareImport(from: source.url)
            defer { runtime.engine.cancelPreparedImport(prepared) }
            guard prepared.validation.passed else {
                throw PrivateAcceptanceError.productionRejectedSource
            }
            let periodKey = source.oracle.periodKey
            let supporting = importedPeriods.contains(periodKey)
            let choice: ImportAccountChoice?
            if supporting {
                guard let first = sources.first(where: { $0.oracle.periodKey == periodKey }),
                      first.oracle.isFinanciallyEquivalent(to: source.oracle) else {
                    throw PrivateAcceptanceError.oracleMismatch
                }
                choice = nil
            } else if let accountID {
                choice = try explicitSectionChoice(
                    document: prepared.financialDocument,
                    accountID: accountID,
                    provider: runtime.provider,
                    workspaceID: workspaceID
                )
            } else {
                choice = .createNewCardLiabilityAccountAndInstrument
            }

            let result = await runtime.engine.commitPreparedImport(prepared, accountChoice: choice)
            #expect(result.hydrationOutcome == .committedAndHydrated, "\(source.url.lastPathComponent): \(result.errorMessage ?? "no error")")
            guard result.persisted else { throw PrivateAcceptanceError.persistenceRejectedSource }
            if supporting {
                guard result.isEquivalentSupportingSource, result.transactionCount == 0 else {
                    throw PrivateAcceptanceError.semanticEquivalenceMismatch
                }
            } else {
                guard !result.isEquivalentSupportingSource,
                      result.transactionCount == source.oracle.rows.count else {
                    throw PrivateAcceptanceError.semanticEquivalenceMismatch
                }
                importedPeriods.insert(periodKey)
            }
            if let accountID {
                guard result.accountId == accountID else { throw PrivateAcceptanceError.persistenceGraphMismatch }
            } else {
                accountID = result.accountId
            }
        }

        for source in sources {
            let replay = try await runtime.engine.prepareImport(from: source.url)
            defer { runtime.engine.cancelPreparedImport(replay) }
            let result = await runtime.engine.commitPreparedImport(replay)
            #expect(!result.persisted && result.previousImport != nil)
        }
        let digestBefore = try verifyFinalState(
            runtime: runtime,
            sources: sources,
            workspaceID: workspaceID,
            expected: expected
        )

        if let sqlite = runtime.sqlite, let sqlitePath = runtime.sqlitePath {
            try sqlite.database.checkpointAndClose()
            let reopenedSQLite = try SQLiteRepositoryProvider(path: sqlitePath.path)
            let reopenedProvider = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
            let reopenedRuntimeHydrator = makeHydrator(provider: reopenedProvider, workspaceID: workspaceID)
            let reopenedDigest = try verifyFinalState(
                provider: reopenedProvider,
                hydrator: reopenedRuntimeHydrator,
                sources: sources,
                workspaceID: workspaceID,
                expected: expected
            )
            guard reopenedDigest == digestBefore else {
                throw PrivateAcceptanceError.persistenceGraphMismatchAt("reopen-digest-expected-\(digestBefore.prefix(8))-actual-\(reopenedDigest.prefix(8))")
            }
            try reopenedSQLite.database.checkpointAndClose()
        }
        return digestBefore
    }

    private func verifyExactDuplicate(
        source: PrivateAmexSource,
        inMemory: Bool,
        password: String
    ) async throws {
        let workspaceID = "amex-private-duplicate-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let runtime = try makeRuntime(workspaceID: workspaceID, inMemory: inMemory, password: password)
        defer { runtime.cleanup() }
        let first = try await runtime.engine.prepareImport(from: source.url)
        defer { runtime.engine.cancelPreparedImport(first) }
        let firstResult = await runtime.engine.commitPreparedImport(first,
            accountChoice: .createNewCardLiabilityAccountAndInstrument)
        guard firstResult.persisted else { throw PrivateAcceptanceError.persistenceRejectedSource }
        runtime.engine.cancelPreparedImport(first)

        let duplicate = try await runtime.engine.prepareImport(from: source.url)
        defer { runtime.engine.cancelPreparedImport(duplicate) }
        let duplicateResult = await runtime.engine.commitPreparedImport(duplicate)
        // Exact-source duplicate attempts are rejected without a second
        // mutation; the coordinator reports the prior accepted row count.
        let duplicateRows = try runtime.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count
        let duplicateCard = try runtime.provider.cardRepo.snapshot(workspaceId: workspaceID)
        let duplicateStatements = duplicateCard.statements.count
        let duplicateAccountObservations = duplicateCard.sourceObservations.filter {
            $0.subjectKind == CardSourceIdentitySubject.liabilityAccount.rawValue
        }
        guard !duplicateResult.persisted,
              duplicateResult.transactionCount == source.oracle.rows.count,
              duplicateRows == source.oracle.rows.count,
              duplicateStatements == 1,
              duplicateAccountObservations.count == 1,
              duplicateAccountObservations.allSatisfy({
                  $0.observationKind == "amex_membership_number" &&
                      digest($0.sourceValue) == digest(source.oracle.identity.membershipNumberMasked)
              }) else {
            throw PrivateAcceptanceError.persistenceGraphMismatch
        }
        // The rejected exact duplicate must leave exactly one source document
        // and one source-byte fingerprint authority behind.
        try verifyPersistedSourceDocuments(
            provider: runtime.provider,
            sources: [source],
            workspaceID: workspaceID
        )
    }

    private func explicitSectionChoice(
        document: FinancialDocument,
        accountID: String,
        provider: DatabaseProvider,
        workspaceID: String
    ) throws -> ImportAccountChoice {
        guard let evidence = document.cardStatementEvidence else {
            throw PrivateAcceptanceError.productionMismatch
        }
        let snapshot = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        let choices = try Dictionary(uniqueKeysWithValues: evidence.instrumentSections.map { section in
            guard let incoming = section.sourceIdentityObservations.first?.value else {
                throw PrivateAcceptanceError.productionMismatch
            }
            let instrumentIDs = Set(snapshot.sectionObservations.compactMap { observation -> String? in
                guard observation.sourceValue == incoming,
                      let durableSection = snapshot.sections.first(where: { $0.id == observation.cardStatementSectionId }),
                      snapshot.instruments.contains(where: {
                          $0.id == durableSection.instrumentId && $0.liabilityAccountId == accountID
                      }) else { return nil }
                return durableSection.instrumentId
            })
            if instrumentIDs.count > 1 { throw PrivateAcceptanceError.persistenceGraphMismatch }
            if let instrumentID = instrumentIDs.first {
                return (section.documentScopedSectionID, ImportCardInstrumentChoice.reuseExistingInstrument(instrumentId: instrumentID))
            }
            return (section.documentScopedSectionID, ImportCardInstrumentChoice.createNewInstrument())
        })
        return .useExistingCardLiabilityAccountSections(accountId: accountID, sectionChoices: choices)
    }

    private func verifyFinalState(
        runtime: PrivateRuntime,
        sources: [PrivateAmexSource],
        workspaceID: String,
        expected: CampaignExpectation
    ) throws -> String {
        try verifyPersistedSourceDocuments(
            provider: runtime.provider,
            sources: sources,
            workspaceID: workspaceID
        )
        try verifyCounts(provider: runtime.provider, sources: sources, workspaceID: workspaceID, expected: expected)
        let hydrated = try runtime.hydrator.stageHydration()
        try verifyHydrated(hydrated, expected: expected, newest: expected.newest)
        try verifyHydratedSourceRows(hydrated, sources: sources)
        let providerLines = try providerCoreLines(provider: runtime.provider, workspaceID: workspaceID)
        let hydratedLines = hydratedCoreLines(hydrated)
        let providerDigest = digest(providerLines)
        let hydratedDigest = digest(hydratedLines)
        guard providerDigest == hydratedDigest else {
            let firstDifference = zip(providerLines, hydratedLines).enumerated().first(where: { $0.element.0 != $0.element.1 })
            let index = firstDifference?.offset ?? min(providerLines.count, hydratedLines.count)
            let providerLineDigest = index < providerLines.count ? digest(providerLines[index]).prefix(8) : "missing"
            let hydratedLineDigest = index < hydratedLines.count ? digest(hydratedLines[index]).prefix(8) : "missing"
            throw PrivateAcceptanceError.persistenceGraphMismatchAt("runtime-digest-expected-\(providerDigest.prefix(8))-actual-\(hydratedDigest.prefix(8))-index-\(index)-provider-\(providerLineDigest)-hydrated-\(hydratedLineDigest)-counts-\(providerLines.count)-\(hydratedLines.count)")
        }
        return providerDigest
    }

    private func verifyFinalState(
        provider: DatabaseProvider,
        hydrator: RepositoryStoreHydrator,
        sources: [PrivateAmexSource],
        workspaceID: String,
        expected: CampaignExpectation
    ) throws -> String {
        try verifyPersistedSourceDocuments(
            provider: provider,
            sources: sources,
            workspaceID: workspaceID
        )
        try verifyCounts(provider: provider, sources: sources, workspaceID: workspaceID, expected: expected)
        let hydrated = try hydrator.stageHydration()
        try verifyHydrated(hydrated, expected: expected, newest: expected.newest)
        try verifyHydratedSourceRows(hydrated, sources: sources)
        let providerLines = try providerCoreLines(provider: provider, workspaceID: workspaceID)
        let hydratedLines = hydratedCoreLines(hydrated)
        let providerDigest = digest(providerLines)
        let hydratedDigest = digest(hydratedLines)
        guard providerDigest == hydratedDigest else {
            let firstDifference = zip(providerLines, hydratedLines).enumerated().first(where: { $0.element.0 != $0.element.1 })
            let index = firstDifference?.offset ?? min(providerLines.count, hydratedLines.count)
            let providerLineDigest = index < providerLines.count ? digest(providerLines[index]).prefix(8) : "missing"
            let hydratedLineDigest = index < hydratedLines.count ? digest(hydratedLines[index]).prefix(8) : "missing"
            throw PrivateAcceptanceError.persistenceGraphMismatchAt("reopen-runtime-digest-expected-\(providerDigest.prefix(8))-actual-\(hydratedDigest.prefix(8))-index-\(index)-provider-\(providerLineDigest)-hydrated-\(hydratedLineDigest)-counts-\(providerLines.count)-\(hydratedLines.count)")
        }
        return providerDigest
    }

    /// The card statement count alone is not source-document authority. For
    /// every accepted source, resolve the persisted source-bytes fingerprint
    /// through the repository and bind it to one durable document/statement
    /// pair. This proves both exact digest membership and durable document
    /// cardinality without exposing private source values in diagnostics.
    private func verifyPersistedSourceDocuments(
        provider: DatabaseProvider,
        sources: [PrivateAmexSource],
        workspaceID: String
    ) throws {
        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        let expectedSourceDigests = sources.map { $0.oracle.sourceSHA256 }
        var persistedDocumentIDs = Set<String>()
        var persistedSourceDigests = Set<String>()
        for source in sources {
            guard let prior = try provider.importSessionRepo.priorImportedStatement(
                algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
                fingerprint: source.oracle.sourceSHA256
            ),
                  let statement = card.statements.first(where: { $0.importSessionId == prior.importSessionId }),
                  let document = try provider.importSessionRepo.importedDocument(id: statement.documentId),
                  document.workspaceId == workspaceID,
                  document.id == statement.documentId,
                  document.importSessionId == statement.importSessionId,
                  document.filename == source.oracle.basename,
                  document.sizeBytes == Int64(source.oracle.sourceByteSize),
                  prior.transactionCount == source.oracle.rows.count else {
                throw PrivateAcceptanceError.persistenceGraphMismatchAt("source-document")
            }
            persistedDocumentIDs.insert(document.id)
            persistedSourceDigests.insert(source.oracle.sourceSHA256)
        }
        guard persistedDocumentIDs.count == expectedSourceDigests.count,
              persistedSourceDigests == Set(expectedSourceDigests),
              card.statements.count == persistedDocumentIDs.count else {
            throw PrivateAcceptanceError.persistenceGraphMismatchAt("source-document-envelope")
        }
    }

    private func verifyCounts(
        provider: DatabaseProvider,
        sources: [PrivateAmexSource],
        workspaceID: String,
        expected: CampaignExpectation
    ) throws {
        guard try provider.accountRepo.accounts(workspaceId: workspaceID).count == 1,
              try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == expected.canonicalRowCount else {
            throw PrivateAcceptanceError.persistenceGraphMismatchAt("count-envelope")
        }
        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        let accountObservations = card.sourceObservations.filter {
            $0.subjectKind == "liability_account"
        }
        let countChecks: [(String, Bool)] = [
            ("instruments", card.instruments.count == expected.instrumentCount),
            // Identity observations are source-scoped evidence. Every
            // accepted statement therefore contributes one durable account
            // observation, while CampaignExpectation proves that all source
            // values resolve to the same membership identity.
            ("account-observations-\(accountObservations.count)", accountObservations.count == expected.sourceCount),
            ("account-observation-kind", accountObservations.count == expected.sourceCount && accountObservations.allSatisfy { $0.observationKind == "amex_membership_number" }),
            ("account-observation-digest", accountObservations.count == expected.sourceCount && accountObservations.allSatisfy { digest($0.sourceValue) == expected.membershipDigest }),
            ("relationships", card.relationships.isEmpty),
            ("statements", card.statements.count == sources.count),
            ("sections", card.sections.count == expected.allSourceSectionCount),
            ("section-observations", card.sectionObservations.count == expected.allSourceSectionCount),
            ("transaction-evidence", card.transactionEvidence.count == expected.canonicalRowCount),
            ("semantic-projections", card.semanticProjections.count == sources.count),
            ("semantic-groups", card.semanticGroups.count == expected.uniqueStatementCount),
            ("semantic-members", card.semanticMembers.count == sources.count),
            ("supporting-members", card.semanticMembers.filter({ $0.role == .supporting }).count == expected.supportingSourceCount),
            ("semantic-events", card.semanticProjections.reduce(0, { $0 + $1.events.count }) == expected.allSourceRowCount)
        ]
        let failedChecks = countChecks.filter { !$0.1 }.map(\.0).joined(separator: ",")
        guard failedChecks.isEmpty else {
            throw PrivateAcceptanceError.persistenceGraphMismatchAt("count-envelope-failed-\(failedChecks)")
        }
    }

    private func verifyHydrated(
        _ hydrated: RepositoryRuntimeSnapshot,
        expected: CampaignExpectation,
        newest: OracleSource
    ) throws {
        let expectedBalance = try Money.fromMinorUnits(
            -newest.summary.newBalance.minorUnits,
            currency: newest.nativeCurrency
        )
        guard hydrated.accounts.count == 1,
              hydrated.accounts.first?.currentBalanceMoney == expectedBalance,
              hydrated.transactions.count == expected.canonicalRowCount,
              hydrated.cardSnapshot.instruments.count == expected.instrumentCount,
              hydrated.cardSnapshot.statements.count == expected.sourceCount else {
            throw PrivateAcceptanceError.persistenceGraphMismatch
        }
    }

    private func verifyHydratedSourceRows(_ snapshot: RepositoryRuntimeSnapshot, sources: [PrivateAmexSource]) throws {
        let transactions = try Dictionary(uniqueKeysWithValues: snapshot.transactions.map {
            (try #require($0.repositoryTransactionId), $0)
        })
        for source in sources {
            let statement = try #require(snapshot.cardSnapshot.statements.first {
                $0.period?.start.canonical == source.oracle.statementPeriod.start &&
                $0.period?.end.canonical == source.oracle.statementPeriod.end
            })
            #expect(statement.statementDate?.canonical == source.oracle.statementDate)
            #expect(statement.dueDate?.canonical == source.oracle.dueDate)
            #expect(statement.parserProfileID == AmericanExpressCreditCardPDFParser.profileID)
            #expect(statement.parserProfileVersion == AmericanExpressCreditCardPDFParser.profileVersion)
            let actual = try snapshot.cardSnapshot.transactionEvidence.filter { $0.statementID == statement.id }.map { annotation in
                let row = try #require(transactions[annotation.transactionID])
                let account = statement.sections.first { $0.documentScopedSectionID == annotation.documentScopedSectionID }?
                    .sourceObservations.first?.value
                #expect(row.sourceProvenance.contains {
                    $0.parserProfileID == AmericanExpressCreditCardPDFParser.profileID &&
                    $0.parserProfileVersion == AmericanExpressCreditCardPDFParser.profileVersion
                })
                return semanticRowKey([row.statementDate?.canonical ?? "", annotation.sourceTransactionDate.canonical,
                    row.description.replacingOccurrences(of: "\n", with: " "), row.reference ?? "", moneyKey(row.money),
                    moneyKey(annotation.originalMerchantMoney), annotation.liabilityEffect.rawValue,
                    annotation.financialScope.persistenceCode, account ?? ""])
            }
            let expected = try source.oracle.rows.map { row in
                semanticRowKey([row.postingDate, row.transactionDate, row.descriptionSourceExact, row.sourceReference ?? "",
                    moneyKey(try materialize(row.signedPostedMoney)),
                    moneyKey(try row.signedOriginalMoney.map(materialize)), row.liabilityEffect?.rawValue ?? "",
                    row.financialScope, row.sectionAccountMasked ?? ""])
            }
            #expect(actual.sorted() == expected.sorted(), "\(source.url.lastPathComponent): hydrated source rows")
        }
    }

    private func semanticRowKey(_ values: [String]) -> String {
        values.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    private func makeRuntime(
        workspaceID: String,
        inMemory: Bool,
        password: String
    ) throws -> PrivateRuntime {
        let provider: DatabaseProvider
        let sqlite: SQLiteRepositoryProvider?
        let sqlitePath: URL?
        let folder: URL?
        if inMemory {
            provider = DatabaseProvider(inMemory: true)
            sqlite = nil
            sqlitePath = nil
            folder = nil
        } else {
            let path = FileManager.default.temporaryDirectory
                .appendingPathComponent("ledgerforge-amex-private-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            let sqliteFile = path.appendingPathComponent("acceptance.sqlite")
            let opened = try SQLiteRepositoryProvider(path: sqliteFile.path)
            provider = DatabaseProvider.verifiedSQLite(opened, protectsGeneration: false)
            sqlite = opened
            sqlitePath = sqliteFile
            folder = path
        }
        let passwordStore = InMemoryStatementPasswordCredentialStore(passwords: [
            Institution.amex.statementPasswordCredentialScope: password
        ])
        let passwordProvider = DefaultPasswordProvider(
            credentialStore: passwordStore,
            supportedInstitutionCodes: [Institution.amex.statementPasswordCredentialScope],
            challenge: { _ in throw PrivateAcceptanceError.unexpectedPasswordChallenge }
        )
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Private acceptance")
        )
        let hydrator = makeHydrator(provider: provider, workspaceID: workspaceID)
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: passwordProvider
            ),
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
            rejectedAttemptHydration: { _ = try hydrator.stageHydration() },
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )
        return PrivateRuntime(
            provider: provider,
            coordinator: coordinator,
            engine: engine,
            hydrator: hydrator,
            sqlite: sqlite,
            sqlitePath: sqlitePath,
            cleanup: {
                sqlite?.database.close()
                if let folder { try? FileManager.default.removeItem(at: folder) }
            }
        )
    }

    private func makeHydrator(provider: DatabaseProvider, workspaceID: String) -> RepositoryStoreHydrator {
        RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo,
            fundingPlanRepo: provider.fundingPlanRepo,
            accountStore: AccountStore(),
            transactionStore: TransactionStore(),
            categoryStore: CategoryStore(),
            cardStore: CardStore(),
            salaryStore: SalaryStore(),
            fundingPlanStore: FundingPlanStore(),
            importSessionStore: ImportSessionStore(),
            importAttemptStore: ImportAttemptStore(),
            workspaceId: workspaceID,
            categoryReconciliationGate: nil,
            participatesInLifecycleGate: false
        )
    }

    private func moneyMatches(_ actual: Money?, _ expected: OracleMoney?) -> Bool {
        guard let actual, let expected else { return actual == nil && expected == nil }
        return actual.currency.code == expected.currency && (try? actual.minorUnits()) == expected.minorUnits
    }

    private func moneyMatches(_ actual: Money, _ expected: OracleMoney) -> Bool {
        actual.currency.code == expected.currency && (try? actual.minorUnits()) == expected.minorUnits
    }

    private func materialize(_ value: OracleMoney) throws -> Money {
        try Money.fromMinorUnits(value.minorUnits, currency: value.currency)
    }

    private func providerCoreLines(provider: DatabaseProvider, workspaceID: String) throws -> [String] {
        var lines = [String]()
        for account in try provider.accountRepo.accounts(workspaceId: workspaceID) {
            let accountType = account.accountType == "credit_card" ? "creditCard" : (account.accountType ?? "")
            lines.append("account|\(account.name)|\(accountType)|\(account.nativeCurrency)")
        }
        for transaction in try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID) {
            let raw = transaction.rawRows.sorted { ($0.sourceOrdinal ?? 0) < ($1.sourceOrdinal ?? 0) }
                .map { "\($0.sourceOrdinal ?? 0):\($0.normalizedRecordDigest ?? "")" }
                .joined(separator: ",")
            lines.append([
                "tx", transaction.postedDateISO, transaction.financialDateRole,
                transaction.reference ?? "", transaction.description ?? "",
                transaction.nativeCurrency, "\(transaction.amountMinor)", transaction.direction, raw
            ].joined(separator: "|"))
        }
        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        let statementKeys = Dictionary(uniqueKeysWithValues: card.statements.map { ($0.id, $0) })
        for statement in card.statements.sorted(by: { statementKey($0) < statementKey($1) }) {
            lines.append("statement|\(statementKey(statement))|\(statement.statementCurrency)|\(statement.sourceRowCount)|\(statement.parserProfileId)|\(statement.parserProfileVersion)|\(statement.reconciliationRuleCode)")
            for summary in card.summaryComponents.filter({ $0.cardStatementId == statement.id }).sorted(by: { $0.componentCode < $1.componentCode }) {
                let money = if let currency = summary.moneyCurrency, let minor = summary.moneyMinor {
                    "\(currency):\(minor)"
                } else {
                    ""
                }
                lines.append("summary|\(statementKey(statement))|\(summary.componentCode)|\(money)|\(summary.dateISO ?? "")")
            }
        }
        for section in card.sections.sorted(by: { ($0.sourceOrdinal, $0.documentScopedSectionId) < ($1.sourceOrdinal, $1.documentScopedSectionId) }) {
            let values = card.sectionObservations.filter { $0.cardStatementSectionId == section.id }.map(\.sourceValue).sorted().joined(separator: ",")
            let holderDigest = digest(section.holderLabel ?? "")
            lines.append("section|\(statementKeys[section.cardStatementId].map(statementKey) ?? "")|\(section.documentScopedSectionId)|\(section.sourceOrdinal)|\(section.signedTotalCurrency):\(section.signedTotalMinor)|holder:\(holderDigest)|\(values)")
        }
        for observation in card.sourceObservations
            .filter({ $0.subjectKind == "liability_account" })
            .sorted(by: { ($0.observationKind, $0.sourceValue) < ($1.observationKind, $1.sourceValue) }) {
            let key = sourceObservationKey(
                subject: observation.subjectKind,
                kind: observation.observationKind,
                value: observation.sourceValue
            )
            lines.append("account-source|\(digest(key))")
        }
        for evidence in card.transactionEvidence.sorted(by: { ($0.sourceTransactionDateISO, $0.documentScopedSectionId ?? "") < ($1.sourceTransactionDateISO, $1.documentScopedSectionId ?? "") }) {
            let originalMoney = if let currency = evidence.originalCurrency, let minor = evidence.originalAmountMinor {
                "\(currency):\(minor)"
            } else {
                ""
            }
            lines.append("evidence|\(evidence.rowScopeCode)|\(evidence.documentScopedSectionId ?? "")|\(evidence.liabilityEffectCode)|\(evidence.sourceTransactionDateISO)|\(originalMoney)")
        }
        return lines
    }

    private func hydratedCoreLines(_ snapshot: RepositoryRuntimeSnapshot) -> [String] {
        var lines = snapshot.accounts.map {
            "account|\($0.name)|\($0.type.rawValue)|\($0.nativeCurrency.code)"
        }
        for transaction in snapshot.transactions {
            let raw = transaction.sourceProvenance.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
                .map { "\($0.sourceOrdinal):\($0.normalizedRecordDigest)" }
                .joined(separator: ",")
            lines.append([
                "tx", transaction.statementDate?.canonical ?? "", transaction.financialDateRole.rawValue,
                transaction.reference ?? "", transaction.description, transaction.money.currency.code,
                "\((try? transaction.money.minorUnits()) ?? 0)", transaction.cardLiabilityEffect?.rawValue ?? "", raw
            ].joined(separator: "|"))
        }
        for statement in snapshot.cardSnapshot.statements.sorted(by: { ($0.statementDate?.canonical ?? "", $0.id) < ($1.statementDate?.canonical ?? "", $1.id) }) {
            let key = "\(statement.statementDate?.canonical ?? "")|\(statement.period?.start.canonical ?? "")|\(statement.period?.end.canonical ?? "")"
            lines.append("statement|\(key)|\(statement.currency.code)|\(statement.sourceRowCount)|\(statement.parserProfileID)|\(statement.parserProfileVersion)|\(statement.reconciliationRuleCode)")
            for summary in statement.summaryComponents.sorted(by: { $0.persistenceCode < $1.persistenceCode }) {
                lines.append("summary|\(key)|\(summary.persistenceCode)|\(moneyKey(summary.money))|\(summary.date?.canonical ?? "")")
            }
            for section in statement.sections.sorted(by: { ($0.sourceOrdinal, $0.documentScopedSectionID) < ($1.sourceOrdinal, $1.documentScopedSectionID) }) {
                let values = section.sourceObservations.map(\.value).sorted().joined(separator: ",")
                let holderDigest = digest(section.holderLabel ?? "")
                lines.append("section|\(key)|\(section.documentScopedSectionID)|\(section.sourceOrdinal)|\(moneyKey(section.signedTotal))|holder:\(holderDigest)|\(values)")
            }
        }
        for observation in snapshot.cardSnapshot.sourceObservations
            .filter({ $0.subject == .liabilityAccount })
            .sorted(by: { ($0.kind.rawValue, $0.value) < ($1.kind.rawValue, $1.value) }) {
            let key = sourceObservationKey(
                subject: observation.subject.rawValue,
                kind: observation.kind.rawValue,
                value: observation.value
            )
            lines.append("account-source|\(digest(key))")
        }
        for evidence in snapshot.cardSnapshot.transactionEvidence.sorted(by: { ($0.sourceTransactionDate.canonical, $0.documentScopedSectionID ?? "") < ($1.sourceTransactionDate.canonical, $1.documentScopedSectionID ?? "") }) {
            lines.append("evidence|\(evidence.financialScope.persistenceCode)|\(evidence.documentScopedSectionID ?? "")|\(evidence.liabilityEffect.rawValue)|\(evidence.sourceTransactionDate.canonical)|\(moneyKey(evidence.originalMerchantMoney))")
        }
        return lines
    }

    private func statementKey(_ statement: CardStatementDTO) -> String {
        "\(statement.statementDateISO ?? "")|\(statement.statementStartDateISO ?? "")|\(statement.statementEndDateISO ?? "")"
    }

    private func moneyKey(_ money: Money?) -> String {
        guard let money else { return "" }
        return "\(money.currency.code):\((try? money.minorUnits()) ?? 0)"
    }

    private func digest(_ lines: [String]) -> String {
        SHA256.hash(data: Data(lines.sorted().joined(separator: "\u{1F}" ).utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    private func sourceObservationKey(subject: String, kind: String, value: String) -> String {
        "\(subject)|\(kind)|\(value)"
    }
}

@MainActor
private struct PrivateRuntime {
    let provider: DatabaseProvider
    let coordinator: DefaultImportPersistenceCoordinator
    let engine: ImportEngine
    let hydrator: RepositoryStoreHydrator
    let sqlite: SQLiteRepositoryProvider?
    let sqlitePath: URL?
    let cleanup: () -> Void
}

private enum PrivateAcceptanceError: Error {
    case malformedContext
    case malformedOracle
    case unreadableSource
    case unlockFailed
    case oracleMismatch
    case productionMismatch
    case productionMismatchAt(String)
    case productionRejectedSource
    case persistenceRejectedSource
    case persistenceGraphMismatch
    case persistenceGraphMismatchAt(String)
    case semanticEquivalenceMismatch
    case unexpectedPasswordChallenge
}

private struct PrivateAmexContext {
    static let rootKey = "LEDGERFORGE_PRIVATE_AMEX_ROOT"
    static let passwordKey = "LEDGERFORGE_PRIVATE_AMEX_PASSWORD"
    static let oracleKey = "LEDGERFORGE_PRIVATE_AMEX_ORACLE_PATH"
    static let oracleSHAKey = "LEDGERFORGE_PRIVATE_AMEX_ORACLE_SHA256"

    let root: URL
    let password: String
    let oracleURL: URL
    let manifest: OracleManifest

    static var explicitContextRequested: Bool {
        explicitContextRequested(in: ProcessInfo.processInfo.environment)
    }

    /// Presence of any private-context key is an explicit opt-in, even when
    /// the value is empty or whitespace. This keeps malformed requests from
    /// silently disabling the acceptance lane through the test's conditional
    /// enablement predicate; `load(environment:)` then fails closed.
    static func explicitContextRequested(in environment: [String: String]) -> Bool {
        [rootKey, passwordKey, oracleKey, oracleSHAKey].contains { environment[$0] != nil }
    }

    static func load() throws -> PrivateAmexContext {
        try load(environment: ProcessInfo.processInfo.environment)
    }

    static func load(environment: [String: String]) throws -> PrivateAmexContext {
        guard let rootRaw = environment[rootKey],
              let password = environment[passwordKey],
              let oracleRaw = environment[oracleKey],
              let frozenOracleSHA256 = environment[oracleSHAKey],
              frozenOracleSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw PrivateAcceptanceError.malformedContext
        }
        let rootValue = rootRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let oracleValue = oracleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rootValue.isEmpty,
              !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !oracleValue.isEmpty else {
            throw PrivateAcceptanceError.malformedContext
        }
        let root = URL(fileURLWithPath: rootValue, isDirectory: true)
        let oracleURL = URL(fileURLWithPath: oracleValue)
        var rootIsDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &rootIsDirectory), rootIsDirectory.boolValue else {
            throw PrivateAcceptanceError.malformedContext
        }
        var oracleIsDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: oracleURL.path, isDirectory: &oracleIsDirectory), !oracleIsDirectory.boolValue else {
            throw PrivateAcceptanceError.malformedContext
        }
        let oracleBytes = try Data(contentsOf: oracleURL, options: [.mappedIfSafe])
        let oracleSHA = SHA256.hash(data: oracleBytes).map { String(format: "%02x", $0) }.joined()
        guard oracleSHA == frozenOracleSHA256 else { throw PrivateAcceptanceError.malformedOracle }
        let manifest = try JSONDecoder().decode(OracleManifest.self, from: oracleBytes)
        guard manifest.sources.isEmpty == false else { throw PrivateAcceptanceError.malformedOracle }
        return PrivateAmexContext(root: root, password: password, oracleURL: oracleURL, manifest: manifest)
    }

    func loadSources() throws -> [PrivateAmexSource] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter {
            $0.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame &&
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard Set(urls.map(\.lastPathComponent)) == Set(manifest.sources.map(\.basename)), urls.count == manifest.sources.count else {
            throw PrivateAcceptanceError.malformedOracle
        }
        let byName = Dictionary(uniqueKeysWithValues: manifest.sources.map { ($0.basename, $0) })
        return try urls.map { url in
            guard let oracle = byName[url.lastPathComponent] else { throw PrivateAcceptanceError.malformedOracle }
            return try PrivateAmexSource(url: url, oracle: oracle, password: password)
        }
    }

    func validateManifest(sources: [PrivateAmexSource]) throws {
        guard manifest.aggregate.statementCount == sources.count,
              manifest.aggregate.financialRowCount == sources.reduce(0, { $0 + $1.oracle.rows.count }),
              manifest.aggregate.sectionCount == sources.reduce(0, { $0 + $1.oracle.sections.count }),
              manifest.aggregate.foreignMoneyRowCount == sources.reduce(0, { $0 + $1.oracle.rows.filter { $0.originalForeignMoney != nil }.count }),
              manifest.aggregate.reconciliationFailureCount == 0,
              manifest.aggregate.sectionFailureCount == 0 else {
            throw PrivateAcceptanceError.malformedOracle
        }
        for source in sources {
            guard source.oracle.summary.reconciliationResidual == 0,
                  source.oracle.summary.oracleCalculated.statementEquationResidualMinorUnits == 0,
                  source.oracle.rows.allSatisfy({ $0.globalSourceOrdinal > 0 }),
                  source.oracle.sections.enumerated().allSatisfy({ $0.element.rowOrdinals.allSatisfy { $0 > 0 } }) else {
                throw PrivateAcceptanceError.malformedOracle
            }
        }
    }
}

private struct PrivateAmexSource {
    let url: URL
    let oracle: OracleSource

    init(url: URL, oracle: OracleSource, password: String) throws {
        let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard bytes.count == oracle.sourceByteSize, digest == oracle.sourceSHA256 else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        guard let pdf = PDFDocument(data: bytes) else { throw PrivateAcceptanceError.unreadableSource }
        let lockedBefore = pdf.isLocked
        if lockedBefore {
            guard pdf.unlock(withPassword: password) else { throw PrivateAcceptanceError.unlockFailed }
        }
        let lockedAfter = pdf.isLocked
        let nativeTextPageCount = (0..<pdf.pageCount).filter {
            guard let text = pdf.page(at: $0)?.string else { return false }
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        guard lockedBefore == oracle.lockedBeforeUnlock,
              lockedAfter == oracle.lockedAfterUnlock,
              oracle.encrypted == lockedBefore,
              oracle.unlockSuccess == !lockedAfter,
              pdf.pageCount == oracle.pageCount,
              nativeTextPageCount == oracle.nativeTextPageCount else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        self.url = url
        self.oracle = oracle
    }
}

private struct CampaignExpectation {
    let sourceCount: Int
    let uniqueStatementCount: Int
    let canonicalRowCount: Int
    let allSourceRowCount: Int
    let instrumentCount: Int
    let allSourceSectionCount: Int
    let supportingSourceCount: Int
    let membershipDigest: String
    let newest: OracleSource

    init(sources: [PrivateAmexSource]) throws {
        var canonical = [PrivateAmexSource]()
        var seen = Set<String>()
        for source in sources {
            let key = source.oracle.periodKey
            if seen.insert(key).inserted {
                canonical.append(source)
            } else if let existing = canonical.first(where: { $0.oracle.periodKey == key }),
                      !existing.oracle.isFinanciallyEquivalent(to: source.oracle) {
                throw PrivateAcceptanceError.oracleMismatch
            }
        }
        guard let newest = canonical.max(by: { $0.oracle.statementDate < $1.oracle.statementDate }) else {
            throw PrivateAcceptanceError.malformedOracle
        }
        self.sourceCount = sources.count
        self.uniqueStatementCount = canonical.count
        self.canonicalRowCount = canonical.reduce(0) { $0 + $1.oracle.rows.count }
        self.allSourceRowCount = sources.reduce(0) { $0 + $1.oracle.rows.count }
        self.instrumentCount = Set(canonical.flatMap { $0.oracle.sections.map(\.accountMasked) }).count
        self.allSourceSectionCount = sources.reduce(0) { $0 + $1.oracle.sections.count }
        self.supportingSourceCount = sources.count - canonical.count
        let memberships = Set(canonical.map { $0.oracle.identity.membershipNumberMasked })
        guard memberships.count == 1,
              let membership = memberships.first else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        self.membershipDigest = SHA256.hash(data: Data(membership.utf8))
            .map { String(format: "%02x", $0) }.joined()
        self.newest = newest.oracle
    }
}

private struct OracleManifest: Decodable {
    let sources: [OracleSource]
    let aggregate: OracleAggregate
}

private struct OracleAggregate: Decodable {
    let statementCount: Int
    let financialRowCount: Int
    let sectionCount: Int
    let foreignMoneyRowCount: Int
    let reconciliationFailureCount: Int
    let sectionFailureCount: Int
}

private struct OracleSource: Decodable {
    let basename: String
    let sourceByteSize: Int
    let sourceSHA256: String
    let encrypted: Bool
    let lockedBeforeUnlock: Bool
    let lockedAfterUnlock: Bool
    let unlockSuccess: Bool
    let pageCount: Int
    let nativeTextPageCount: Int
    let statementDate: String
    let statementPeriod: OraclePeriod
    let dueDate: String
    let nativeCurrency: String
    let identity: OracleIdentity
    let summary: OracleSummary
    let pages: [OraclePage]
    let sections: [OracleSection]
    let rows: [OracleRow]

    enum CodingKeys: String, CodingKey {
        case basename, sourceByteSize, sourceSHA256, encrypted, lockedBeforeUnlock, lockedAfterUnlock, unlockSuccess
        case pageCount, nativeTextPageCount, statementDate, statementPeriod, dueDate, nativeCurrency
        case membershipLiabilityIdentityEvidence, summary, pages, sections, rows
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        basename = try values.decode(String.self, forKey: .basename)
        sourceByteSize = try values.decode(Int.self, forKey: .sourceByteSize)
        sourceSHA256 = try values.decode(String.self, forKey: .sourceSHA256)
        encrypted = try values.decode(Bool.self, forKey: .encrypted)
        lockedBeforeUnlock = try values.decode(Bool.self, forKey: .lockedBeforeUnlock)
        lockedAfterUnlock = try values.decode(Bool.self, forKey: .lockedAfterUnlock)
        unlockSuccess = try values.decode(Bool.self, forKey: .unlockSuccess)
        pageCount = try values.decode(Int.self, forKey: .pageCount)
        nativeTextPageCount = try values.decode(Int.self, forKey: .nativeTextPageCount)
        statementDate = try values.decode(String.self, forKey: .statementDate)
        statementPeriod = try values.decode(OraclePeriod.self, forKey: .statementPeriod)
        dueDate = try values.decode(String.self, forKey: .dueDate)
        nativeCurrency = try values.decode(String.self, forKey: .nativeCurrency)
        identity = try values.decode(OracleIdentity.self, forKey: .membershipLiabilityIdentityEvidence)
        summary = try values.decode(OracleSummary.self, forKey: .summary)
        pages = try values.decode([OraclePage].self, forKey: .pages)
        sections = try values.decode([OracleSection].self, forKey: .sections)
        rows = try values.decode([OracleRow].self, forKey: .rows)
    }

    var periodKey: String { "\(statementPeriod.start)/\(statementPeriod.end)" }

    func isFinanciallyEquivalent(to other: OracleSource) -> Bool {
        statementDate == other.statementDate && statementPeriod == other.statementPeriod &&
            dueDate == other.dueDate && nativeCurrency == other.nativeCurrency && identity == other.identity &&
            summary == other.summary && sections == other.sections && rows == other.rows
    }

    func holderLabelDigest(for section: OracleSection) -> String? {
        let associatedHeaders = pages
            .flatMap(\.sectionHeaderOccurrences)
            .filter { $0.accountKeyHash == section.accountKeyHash }
        guard associatedHeaders.count == section.occurrences.count,
              !associatedHeaders.isEmpty else { return nil }
        let holders = associatedHeaders.compactMap { occurrence -> String? in
            let prefix = "New Transactions For "
            let suffix = " Card Account Number:"
            guard occurrence.headerText.hasPrefix(prefix),
                  let suffixRange = occurrence.headerText.range(of: suffix),
                  suffixRange.lowerBound > occurrence.headerText.index(occurrence.headerText.startIndex, offsetBy: prefix.count) else {
                return nil
            }
            let holderStart = occurrence.headerText.index(occurrence.headerText.startIndex, offsetBy: prefix.count)
            let holder = occurrence.headerText[holderStart..<suffixRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return holder.isEmpty ? nil : String(holder)
        }
        guard holders.count == associatedHeaders.count,
              let first = holders.first,
              holders.allSatisfy({ $0 == first }) else { return nil }
        return SHA256.hash(data: Data(first.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private struct OraclePage: Decodable {
    let sectionHeaderOccurrences: [OracleSectionHeaderOccurrence]
}

private struct OracleSectionHeaderOccurrence: Decodable {
    let accountKeyHash: String
    let headerText: String
}

private struct OraclePeriod: Decodable, Equatable {
    let start: String
    let end: String
}

private struct OracleIdentity: Decodable, Equatable {
    let membershipNumberMasked: String
}

private struct OracleMoney: Decodable, Equatable {
    let currency: String
    let minorUnits: Int64

    init(currency: String, minorUnits: Int64) {
        self.currency = currency
        self.minorUnits = minorUnits
    }

    private enum CodingKeys: String, CodingKey {
        case currency, minorUnits, unscaledIntegerAtSourceDisplayedScale
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        currency = try values.decode(String.self, forKey: .currency)
        if let minorUnits = try values.decodeIfPresent(Int64.self, forKey: .minorUnits) {
            self.minorUnits = minorUnits
        } else {
            self.minorUnits = try values.decode(Int64.self, forKey: .unscaledIntegerAtSourceDisplayedScale)
        }
    }
}

private struct OracleSummary: Decodable, Equatable {
    let previousBalance: OracleMoney
    let newCredits: OracleMoney
    let newDebits: OracleMoney
    let newBalance: OracleMoney
    let reconciliationResidual: Int
    let oracleCalculated: OracleSummaryCalculation
}

private struct OracleSummaryCalculation: Decodable, Equatable {
    let statementEquationResidualMinorUnits: Int64
}

private struct OracleSection: Decodable, Equatable {
    let accountMasked: String
    let accountKeyHash: String
    let occurrences: [OracleSectionOccurrence]
    let printedTotalCount: Int
    let printedTotals: [OraclePrintedTotal]
    let rowOrdinals: [Int]
    let oracleCalculated: OracleSectionCalculation
}

private struct OracleSectionOccurrence: Decodable, Equatable {
    let page: Int
    let line: Int
}

private struct OraclePrintedTotal: Decodable, Equatable {
    let currency: String
    let sourceDecimal: String
    let page: Int
    let line: Int
    let lineText: String
}

private struct OracleSectionCalculation: Decodable, Equatable {
    let allPrintedTotalsMatch: Bool
    let netActivity: OracleMoney
    let printedTotalComparisons: [OraclePrintedTotalComparison]
    let rowCount: Int
}

private struct OraclePrintedTotalComparison: Decodable, Equatable {
    let calculatedSignedMinorUnits: Int64
    let currency: String
    let line: Int
    let lineText: String
    let matches: Bool
    let page: Int
    let printedSignedMinorUnits: Int64
    let residualMinorUnits: Int64
    let sourceDecimal: String
}

private struct OracleRow: Decodable, Equatable {
    let globalSourceOrdinal: Int
    let page: Int
    let transactionDate: String
    let postingDate: String
    let sourceReference: String?
    let descriptionSourceExact: String
    let descriptionSourceRawSegmentsSHA256: String
    let postedNativeMoney: OracleMoney
    let creditDebitLiabilityDirection: String
    let financialScope: String
    let sectionAccountMasked: String?
    let sectionAccountKeyHash: String?
    let originalForeignMoney: OracleMoney?

    var liabilityEffect: CardLiabilityEffect? {
        switch creditDebitLiabilityDirection {
        case "liability_increase": return .increasesAmountOwed
        case "liability_decrease": return .decreasesAmountOwed
        default: return nil
        }
    }

    var signedPostedMoney: OracleMoney {
        OracleMoney(
            currency: postedNativeMoney.currency,
            minorUnits: liabilityEffect == .decreasesAmountOwed
                ? -postedNativeMoney.minorUnits
                : postedNativeMoney.minorUnits
        )
    }

    var signedOriginalMoney: OracleMoney? {
        guard let originalForeignMoney else { return nil }
        return OracleMoney(
            currency: originalForeignMoney.currency,
            minorUnits: liabilityEffect == .decreasesAmountOwed
                ? -originalForeignMoney.minorUnits
                : originalForeignMoney.minorUnits
        )
    }
}
