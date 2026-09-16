import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// Required acceptance for the encrypted American Express originals. The
/// oracle is independently interpreted from original PDFKit evidence in memory;
/// production output is compared only after those source controls reconcile.
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
                PrivateAmexContext.passwordKey: "\n"
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
        let context = try await PrivateAmexContext.load()
        let sources = try context.loadSources()
        try context.validateCorpus(sources: sources)

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
        // Confirm the multi-card statement first, then let the ordinary review
        // resolve later single-card statements from those confirmed sections.
        let automatic = chronological.sorted {
            if $0.oracle.sections.count != $1.oracle.sections.count {
                return $0.oracle.sections.count > $1.oracle.sections.count
            }
            return $0.oracle.periodKey < $1.oracle.periodKey
        }
        let mixed = chronological.sorted {
            ($0.oracle.sourceSHA256, $0.oracle.basename) <
                ($1.oracle.sourceSHA256, $1.oracle.basename)
        }

        var baseline: String?
        for inMemory in [true, false] {
            for (name, order) in [
                ("automatic", automatic),
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
                    "row \(expected.globalSourceOrdinal): money=\(moneyMatchesExpected), rawDescription=\(descriptionMatchesExpected), canonicalDescription=\(descriptionCanonicalMatchesExpected), originalMoney=\(originalMoneyMatchesExpected)"
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
        var automaticSingleSectionReuses = 0

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
                if name == "automatic",
                   case .matchedExisting(let reviewedID) = try runtime.engine.reviewPreparedImport(prepared) {
                    #expect(reviewedID == accountID)
                    choice = nil
                    if source.oracle.sections.count == 1 { automaticSingleSectionReuses += 1 }
                } else {
                    choice = try explicitSectionChoice(
                        document: prepared.financialDocument,
                        accountID: accountID,
                        provider: runtime.provider,
                        workspaceID: workspaceID
                    )
                }
            } else {
                choice = .createNewCardLiabilityAccountAndInstrument(displayName: "Imported review card")
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

        if name == "automatic" {
            #expect(try #require(sources.first).oracle.sections.count > 1)
            #expect(automaticSingleSectionReuses > 0)
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
            accountChoice: .createNewCardLiabilityAccountAndInstrument(displayName: "Imported review card"))
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
    case sourceOracleFailure(String)
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

    let root: URL
    let password: String

    static func explicitContextRequested(in environment: [String: String]) -> Bool {
        [rootKey, passwordKey].contains { environment[$0] != nil }
    }

    static func load() async throws -> Self {
        var environment = ProcessInfo.processInfo.environment
        if environment[passwordKey] == nil {
            environment[passwordKey] = try await KeychainStatementPasswordCredentialStore().password(
                institutionCode: Institution.amex.statementPasswordCredentialScope
            )
        }
        return try load(environment: environment)
    }

    static func load(environment: [String: String]) throws -> Self {
        guard let rawRoot = environment[rootKey],
              let password = environment[passwordKey] else {
            throw PrivateAcceptanceError.malformedContext
        }

        let rootPath = rawRoot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rootPath.isEmpty,
              !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PrivateAcceptanceError.malformedContext
        }

        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard root.resolvingSymlinksInPath().path.hasPrefix("/Users/vyom/Documents/Ledger Forge/Originals/"),
              FileManager.default.fileExists(
            atPath: root.path,
            isDirectory: &isDirectory
        ),
        isDirectory.boolValue else {
            throw PrivateAcceptanceError.malformedContext
        }

        return Self(root: root, password: password)
    }

    func loadSources() throws -> [PrivateAmexSource] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        .filter {
            $0.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame &&
                (try? $0.resourceValues(forKeys: [.isRegularFileKey])
                    .isRegularFile) == true
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard urls.count == 20 else {
            throw PrivateAcceptanceError.malformedOracle
        }

        return try urls.map {
            try PrivateAmexSource(url: $0, password: password)
        }
    }

    func validateCorpus(sources: [PrivateAmexSource]) throws {
        let rows = sources.reduce(0) { $0 + $1.oracle.rows.count }
        let sections = sources.reduce(0) { $0 + $1.oracle.sections.count }
        let foreignRows = sources.reduce(0) {
            $0 + $1.oracle.rows.filter {
                $0.originalForeignMoney != nil
            }.count
        }

        guard sources.count == 20,
              rows == 902,
              sections == 31,
              foreignRows == 456,
              sources.allSatisfy({
                  $0.oracle.summary.reconciliationResidual == 0 &&
                      $0.oracle.summary.oracleCalculated
                      .statementEquationResidualMinorUnits == 0 &&
                      $0.oracle.sections.allSatisfy {
                          $0.oracleCalculated.allPrintedTotalsMatch &&
                          $0.oracleCalculated.printedTotalComparisons
                              .allSatisfy(\.matches)
                      }
              }) else {
            throw PrivateAcceptanceError.malformedOracle
        }
    }
}

private struct PrivateAmexSource {
    let url: URL
    let oracle: OracleSource

    init(url: URL, password: String) throws {
        let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard let pdf = PDFDocument(data: bytes) else {
            throw PrivateAcceptanceError.unreadableSource
        }

        let lockedBeforeUnlock = pdf.isLocked
        let unlockSuccess = !lockedBeforeUnlock ||
            pdf.unlock(withPassword: password)
        let lockedAfterUnlock = pdf.isLocked

        guard unlockSuccess, !lockedAfterUnlock else {
            throw PrivateAcceptanceError.unlockFailed
        }

        self.url = url
        self.oracle = try IndependentAmexOracleBuilder.make(
            fileName: url.lastPathComponent,
            sourceBytes: bytes,
            lockedBeforeUnlock: lockedBeforeUnlock,
            lockedAfterUnlock: lockedAfterUnlock,
            unlockSuccess: unlockSuccess,
            pdf: pdf
        )
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

private struct OracleSource: Equatable {
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

    var periodKey: String {
        "\(statementPeriod.start)/\(statementPeriod.end)"
    }

    func isFinanciallyEquivalent(to other: OracleSource) -> Bool {
        statementDate == other.statementDate &&
            statementPeriod == other.statementPeriod &&
            dueDate == other.dueDate &&
            nativeCurrency == other.nativeCurrency &&
            identity == other.identity &&
            summary == other.summary &&
            sections == other.sections &&
            rows == other.rows
    }

    func holderLabelDigest(for section: OracleSection) -> String? {
        let headers = pages
            .flatMap(\.sectionHeaderOccurrences)
            .filter { $0.accountKeyHash == section.accountKeyHash }

        guard headers.count == section.occurrences.count,
              !headers.isEmpty else {
            return nil
        }

        let prefix = "New Transactions For "
        let suffix = " Card Account Number:"
        let holders = headers.compactMap { header -> String? in
            guard header.headerText.hasPrefix(prefix),
                  let suffixRange = header.headerText.range(of: suffix) else {
                return nil
            }
            let start = header.headerText.index(
                header.headerText.startIndex,
                offsetBy: prefix.count
            )
            let holder = header.headerText[start..<suffixRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return holder.isEmpty ? nil : String(holder)
        }

        guard holders.count == headers.count,
              let first = holders.first,
              holders.allSatisfy({ $0 == first }) else {
            return nil
        }

        return IndependentAmexOracleBuilder.sha256(Data(first.utf8))
    }
}

private struct OraclePage: Equatable {
    let sectionHeaderOccurrences: [OracleSectionHeaderOccurrence]
}

private struct OracleSectionHeaderOccurrence: Equatable {
    let accountKeyHash: String
    let headerText: String
}

private struct OraclePeriod: Equatable {
    let start: String
    let end: String
}

private struct OracleIdentity: Equatable {
    let membershipNumberMasked: String
}

private struct OracleMoney: Equatable {
    let currency: String
    let minorUnits: Int64
}

private struct OracleSummary: Equatable {
    let previousBalance: OracleMoney
    let newCredits: OracleMoney
    let newDebits: OracleMoney
    let newBalance: OracleMoney
    let reconciliationResidual: Int
    let oracleCalculated: OracleSummaryCalculation
}

private struct OracleSummaryCalculation: Equatable {
    let statementEquationResidualMinorUnits: Int64
}

private struct OracleSection: Equatable {
    let accountMasked: String
    let accountKeyHash: String
    let occurrences: [OracleSectionOccurrence]
    let printedTotalCount: Int
    let printedTotals: [OraclePrintedTotal]
    let rowOrdinals: [Int]
    let oracleCalculated: OracleSectionCalculation
}

private struct OracleSectionOccurrence: Equatable {
    let page: Int
    let line: Int
}

private struct OraclePrintedTotal: Equatable {
    let currency: String
    let sourceDecimal: String
    let page: Int
    let line: Int
    let lineText: String
}

private struct OracleSectionCalculation: Equatable {
    let allPrintedTotalsMatch: Bool
    let netActivity: OracleMoney
    let printedTotalComparisons: [OraclePrintedTotalComparison]
    let rowCount: Int
}

private struct OraclePrintedTotalComparison: Equatable {
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

private struct OracleRow: Equatable {
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

private enum IndependentAmexOracleBuilder {
    private static let nativeCurrency = "QAR"

    private static let scales: [String: Int] = [
        "AED": 2,
        "AUD": 2,
        "BHD": 3,
        "BRL": 2,
        "CHF": 2,
        "CNY": 2,
        "EUR": 2,
        "GBP": 2,
        "IDR": 2,
        "INR": 2,
        "KRW": 0,
        "NZD": 2,
        "QAR": 2,
        "USD": 2,
        "XPF": 0,
        "ZAR": 2
    ]

    private static let membershipPattern =
        #"Membership Number\s+Statement date\s+Statement Period\s+([0-9X-]+)\s+(\d{2}/\d{2}/\d{2})\s+(\d{2}/\d{2}/\d{2}) to (\d{2}/\d{2}/\d{2})"#

    private static let summaryPattern =
        #"Previous Balance\s+New Credits\s+New Debits\s+New Balance\s+Due Date\s+- \(QAR\) \+ \(QAR\) = \(QAR\)\s+(?:\(QAR\)\s+)?([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+(\d{2}/\d{2}/\d{2})"#

    private static let sectionPattern =
        #"^New Transactions For (.+?) Card Account Number: ([0-9X-]+)$"#

    private static let totalPattern =
        #"^Total of New Transactions For (.+?) ([0-9]+(?:,[0-9]{3})*\.\d{2})(?: ?(CR))?$"#

    private static let rowPattern =
        #"^(\d{2}-[A-Za-z]{3}-\d{4}) (\d{2}-[A-Za-z]{3}-\d{4}) (.+)$"#

    private static let foreignAmountPattern =
        #"^([0-9]+(?:,[0-9]{3})*(?:\.\d+)?) ([A-Z]{3})(?: (CR))? ([0-9]+(?:,[0-9]{3})*\.\d{2})(?: (CR))?$"#

    private static let postedAmountPattern =
        #"^([0-9]+(?:,[0-9]{3})*\.\d{2})(?: (CR))?$"#

    private struct OpenSection {
        let holder: String
        let accountMasked: String
        let page: Int
        let line: Int
        var rowOrdinals: [Int]
        var signedRowMinorUnits: [Int64]
    }

    private struct ParsedSectionTotal {
        let holder: String
        let amount: String
        let isCredit: Bool
        let page: Int
        let line: Int
        let sourceLine: String
    }

    static func make(
        fileName: String,
        sourceBytes: Data,
        lockedBeforeUnlock: Bool,
        lockedAfterUnlock: Bool,
        unlockSuccess: Bool,
        pdf: PDFDocument
    ) throws -> OracleSource {
        let pageTexts = try (0..<pdf.pageCount).map { index -> String in
            guard let text = pdf.page(at: index)?.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PrivateAcceptanceError.unreadableSource
            }
            return text
        }

        let joined = pageTexts.joined(separator: "\n")
        guard joined.contains("The Platinum Card (QAR)"),
              joined.contains("Statement of Account"),
              joined.contains("AMEX (MIDDLE EAST) B.S.C. (C)"),
              joined.contains("Transaction Date"),
              joined.contains("Posting Date"),
              joined.contains("Non QAR Spending"),
              joined.contains("Amount in QAR") else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 86")
        }

        let membership = try uniqueCapture(membershipPattern, in: joined)
        guard membership.count == 4 else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 91")
        }

        let summaryMatches = pageTexts.flatMap {
            captures(summaryPattern, in: $0)
        }
        guard summaryMatches.count == 1,
              let summaryValues = summaryMatches.first,
              summaryValues.count == 5 else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 100")
        }

        let summary = try makeSummary(summaryValues)
        let parsed = try parsePages(pageTexts)

        let statementDate = try canonicalShortDate(membership[1])
        let periodStart = try canonicalShortDate(membership[2])
        let periodEnd = try canonicalShortDate(membership[3])
        let dueDate = try canonicalShortDate(summaryValues[4])

        return OracleSource(
            basename: fileName,
            sourceByteSize: sourceBytes.count,
            sourceSHA256: sha256(sourceBytes),
            encrypted: lockedBeforeUnlock,
            lockedBeforeUnlock: lockedBeforeUnlock,
            lockedAfterUnlock: lockedAfterUnlock,
            unlockSuccess: unlockSuccess,
            pageCount: pdf.pageCount,
            nativeTextPageCount: pageTexts.count,
            statementDate: statementDate,
            statementPeriod: OraclePeriod(
                start: periodStart,
                end: periodEnd
            ),
            dueDate: dueDate,
            nativeCurrency: nativeCurrency,
            identity: OracleIdentity(
                membershipNumberMasked: membership[0]
            ),
            summary: summary,
            pages: parsed.pages,
            sections: parsed.sections,
            rows: parsed.rows
        )
    }

    private static func parsePages(
        _ pageTexts: [String]
    ) throws -> (
        pages: [OraclePage],
        sections: [OracleSection],
        rows: [OracleRow]
    ) {
        var pages = [OraclePage]()
        var rows = [OracleRow]()
        var openSection: OpenSection?
        var completedSections = [(
            header: OpenSection,
            total: ParsedSectionTotal
        )]()

        for (pageIndex, pageText) in pageTexts.enumerated() {
            let page = pageIndex + 1
            let lines = pageText
                .components(separatedBy: .newlines)
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }

            var headers = [OracleSectionHeaderOccurrence]()
            var lineIndex = 0

            while lineIndex < lines.count {
                let line = lines[lineIndex]

                if let fields = capture(sectionPattern, in: line),
                   fields.count == 2 {
                    guard openSection == nil else {
                        throw PrivateAcceptanceError.sourceOracleFailure("builder line 172")
                    }

                    let accountHash = sha256(Data(fields[1].utf8))
                    headers.append(
                        OracleSectionHeaderOccurrence(
                            accountKeyHash: accountHash,
                            headerText: line
                        )
                    )
                    openSection = OpenSection(
                        holder: fields[0],
                        accountMasked: fields[1],
                        page: page,
                        line: lineIndex + 1,
                        rowOrdinals: [],
                        signedRowMinorUnits: []
                    )
                    lineIndex += 1
                    continue
                }

                if let fields = capture(totalPattern, in: line),
                   fields.count == 3 {
                    guard let section = openSection,
                          section.holder == fields[0] else {
                        throw PrivateAcceptanceError.sourceOracleFailure("builder line 198")
                    }

                    completedSections.append((
                        header: section,
                        total: ParsedSectionTotal(
                            holder: fields[0],
                            amount: fields[1],
                            isCredit: fields[2] == "CR",
                            page: page,
                            line: lineIndex + 1,
                            sourceLine: line
                        )
                    ))
                    openSection = nil
                    lineIndex += 1
                    continue
                }

                guard let start = capture(rowPattern, in: line),
                      start.count == 3 else {
                    lineIndex += 1
                    continue
                }

                let transactionDate = try canonicalLongDate(start[0])
                let postingDate = try canonicalLongDate(start[1])
                var block = [start[2]]
                lineIndex += 1

                while lineIndex < lines.count {
                    let candidate = lines[lineIndex]
                    if capture(rowPattern, in: candidate) != nil ||
                        capture(sectionPattern, in: candidate) != nil ||
                        capture(totalPattern, in: candidate) != nil {
                        break
                    }
                    block.append(candidate)
                    lineIndex += 1
                }

                let parsed = try row(
                    ordinal: rows.count + 1,
                    page: page,
                    transactionDate: transactionDate,
                    postingDate: postingDate,
                    lines: block,
                    section: openSection
                )
                rows.append(parsed)

                if var section = openSection {
                    section.rowOrdinals.append(parsed.globalSourceOrdinal)
                    section.signedRowMinorUnits.append(
                        parsed.signedPostedMoney.minorUnits
                    )
                    openSection = section
                }
            }

            pages.append(
                OraclePage(sectionHeaderOccurrences: headers)
            )
        }

        guard openSection == nil else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 264")
        }

        let sections = try completedSections.map {
            try makeSection(header: $0.header, total: $0.total)
        }

        let accountedSectionRows = Set(
            sections.flatMap(\.rowOrdinals)
        )
        guard accountedSectionRows.isSubset(
            of: Set(rows.map(\.globalSourceOrdinal))
        ) else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 277")
        }

        return (pages, sections, rows)
    }

    private static func row(
        ordinal: Int,
        page: Int,
        transactionDate: String,
        postingDate: String,
        lines: [String],
        section: OpenSection?
    ) throws -> OracleRow {
        var posted: OracleMoney?
        var original: OracleMoney?
        var effect: String?
        var reference: String?
        var details = [String]()
        var footerSeen = false

        for line in lines {
            if line.hasPrefix("This Card is issued by AMEX (Middle East)") {
                footerSeen = true
                continue
            }

            if let fields = capture(foreignAmountPattern, in: line),
               fields.count == 5 {
                guard posted == nil,
                      original == nil,
                      fields[2].isEmpty == fields[4].isEmpty else {
                    throw PrivateAcceptanceError.sourceOracleFailure("builder line 309")
                }

                original = try money(
                    fields[0],
                    currency: fields[1]
                )
                posted = try money(
                    fields[3],
                    currency: nativeCurrency
                )
                effect = fields[4].isEmpty
                    ? "liability_increase"
                    : "liability_decrease"
                continue
            }

            if let fields = capture(postedAmountPattern, in: line),
               fields.count == 2 {
                guard posted == nil else {
                    throw PrivateAcceptanceError.sourceOracleFailure("builder line 329")
                }

                posted = try money(
                    fields[0],
                    currency: nativeCurrency
                )
                effect = fields[1].isEmpty
                    ? "liability_increase"
                    : "liability_decrease"
                continue
            }

            if line == "Reference:" || line.hasPrefix("Reference: ") {
                let raw = line.hasPrefix("Reference: ")
                    ? String(line.dropFirst("Reference: ".count))
                    : ""
                let value = raw.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !value.isEmpty, reference == nil else {
                    throw PrivateAcceptanceError.sourceOracleFailure("builder line 350")
                }
                reference = value
                continue
            }

            // Footer text is not transaction narration. PDFKit can emit it
            // before the final amount line; retaining amount/reference parsing
            // after the marker preserves the row while excluding footer prose.
            if !footerSeen, !line.isEmpty,
               !isPreamble(line) {
                details.append(line)
            }
        }

        guard let posted,
              let effect,
              !details.isEmpty else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 368")
        }

        let rawDescription = details.joined(separator: "\n")
        let canonicalDescription = details.joined(separator: " ")
        let account = section?.accountMasked

        return OracleRow(
            globalSourceOrdinal: ordinal,
            page: page,
            transactionDate: transactionDate,
            postingDate: postingDate,
            sourceReference: reference,
            descriptionSourceExact: canonicalDescription,
            descriptionSourceRawSegmentsSHA256: sha256(
                Data(rawDescription.utf8)
            ),
            postedNativeMoney: posted,
            creditDebitLiabilityDirection: effect,
            financialScope: account == nil
                ? "account_level"
                : "instrument_level",
            sectionAccountMasked: account,
            sectionAccountKeyHash: account.map {
                sha256(Data($0.utf8))
            },
            originalForeignMoney: original
        )
    }

    private static func makeSection(
        header: OpenSection,
        total: ParsedSectionTotal
    ) throws -> OracleSection {
        guard header.holder == total.holder else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 403")
        }

        let calculated = header.signedRowMinorUnits.reduce(0, +)
        let magnitude = try money(
            total.amount,
            currency: nativeCurrency
        ).minorUnits
        let printed = total.isCredit ? -magnitude : magnitude
        let residual = printed - calculated
        let accountHash = sha256(Data(header.accountMasked.utf8))

        let printedTotal = OraclePrintedTotal(
            currency: nativeCurrency,
            sourceDecimal: total.amount,
            page: total.page,
            line: total.line,
            lineText: total.sourceLine
        )

        let comparison = OraclePrintedTotalComparison(
            calculatedSignedMinorUnits: calculated,
            currency: nativeCurrency,
            line: total.line,
            lineText: total.sourceLine,
            matches: residual == 0,
            page: total.page,
            printedSignedMinorUnits: printed,
            residualMinorUnits: residual,
            sourceDecimal: total.amount
        )

        guard residual == 0 else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 436")
        }

        return OracleSection(
            accountMasked: header.accountMasked,
            accountKeyHash: accountHash,
            occurrences: [
                OracleSectionOccurrence(
                    page: header.page,
                    line: header.line
                )
            ],
            printedTotalCount: 1,
            printedTotals: [printedTotal],
            rowOrdinals: header.rowOrdinals,
            oracleCalculated: OracleSectionCalculation(
                allPrintedTotalsMatch: true,
                netActivity: OracleMoney(
                    currency: nativeCurrency,
                    minorUnits: calculated
                ),
                printedTotalComparisons: [comparison],
                rowCount: header.rowOrdinals.count
            )
        )
    }

    private static func makeSummary(
        _ values: [String]
    ) throws -> OracleSummary {
        guard values.count == 5 else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 467")
        }

        let previous = try money(values[0], currency: nativeCurrency)
        let credits = try money(values[1], currency: nativeCurrency)
        let debits = try money(values[2], currency: nativeCurrency)
        let balance = try money(values[3], currency: nativeCurrency)

        let expected = previous.minorUnits -
            credits.minorUnits +
            debits.minorUnits
        let residual = balance.minorUnits - expected

        guard residual == 0 else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 481")
        }

        return OracleSummary(
            previousBalance: previous,
            newCredits: credits,
            newDebits: debits,
            newBalance: balance,
            reconciliationResidual: 0,
            oracleCalculated: OracleSummaryCalculation(
                statementEquationResidualMinorUnits: 0
            )
        )
    }

    private static func money(
        _ sourceDecimal: String,
        currency: String
    ) throws -> OracleMoney {
        guard let scale = scales[currency] else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 501")
        }

        let cleaned = sourceDecimal.replacingOccurrences(
            of: ",",
            with: ""
        )
        let parts = cleaned.split(
            separator: ".",
            omittingEmptySubsequences: false
        )

        guard parts.count <= 2,
              let whole = Int64(parts[0]),
              whole >= 0 else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 516")
        }

        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard fraction.count <= scale,
              fraction.allSatisfy(\.isNumber) else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 522")
        }

        let paddedFraction = fraction.padding(
            toLength: scale,
            withPad: "0",
            startingAt: 0
        )
        let fractionUnits: Int64
        if scale == 0 {
            fractionUnits = 0
        } else {
            guard let value = Int64(paddedFraction) else {
                throw PrivateAcceptanceError.sourceOracleFailure("builder line 535")
            }
            fractionUnits = value
        }

        let multiplier = Int64(pow(10.0, Double(scale)))
        let (scaledWhole, overflow) = whole.multipliedReportingOverflow(
            by: multiplier
        )
        let (minorUnits, addingOverflow) = scaledWhole.addingReportingOverflow(
            fractionUnits
        )

        guard !overflow, !addingOverflow else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 549")
        }

        return OracleMoney(
            currency: currency,
            minorUnits: minorUnits
        )
    }

    private static func canonicalShortDate(
        _ source: String
    ) throws -> String {
        let parts = source.split(separator: "/")
        guard parts.count == 3,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let year = Int(parts[2]),
              (1...31).contains(day),
              (1...12).contains(month),
              (0...99).contains(year) else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 569")
        }

        return String(
            format: "%04d-%02d-%02d",
            2_000 + year,
            month,
            day
        )
    }

    private static func canonicalLongDate(
        _ source: String
    ) throws -> String {
        let parts = source.split(separator: "-")
        let months = [
            "jan", "feb", "mar", "apr", "may", "jun",
            "jul", "aug", "sep", "oct", "nov", "dec"
        ]

        guard parts.count == 3,
              let day = Int(parts[0]),
              let month = months.firstIndex(
                of: parts[1].lowercased()
              ),
              let year = Int(parts[2]),
              (1...31).contains(day) else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 596")
        }

        return String(
            format: "%04d-%02d-%02d",
            year,
            month + 1,
            day
        )
    }

    private static func isPreamble(_ line: String) -> Bool {
        if [
            "Transaction Date Posting Date Details Non QAR Spending Amount in QAR",
            "Previous Balance",
            "New Credits",
            "New Debits",
            "New Balance",
            "Due Date"
        ].contains(line) {
            return true
        }

        return line.range(
            of: #"^- \(QAR\) \+ \(QAR\) = \(QAR\)(?: \(QAR\))? [0-9]+(?:,[0-9]{3})*\.\d{2}(?: [0-9]+(?:,[0-9]{3})*\.\d{2}){0,3}(?: \d{2}/\d{2}/\d{2})?$"#,
            options: .regularExpression
        ) != nil
    }

    private static func captures(
        _ pattern: String,
        in value: String
    ) -> [[String]] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.anchorsMatchLines]
        ) else {
            return []
        }

        return regex.matches(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ).map { match in
            (1..<match.numberOfRanges).map { index in
                guard let range = Range(
                    match.range(at: index),
                    in: value
                ) else {
                    return ""
                }
                return String(value[range])
            }
        }
    }

    private static func capture(
        _ pattern: String,
        in value: String
    ) -> [String]? {
        captures(pattern, in: value).first
    }

    private static func uniqueCapture(
        _ pattern: String,
        in value: String
    ) throws -> [String] {
        let values = captures(pattern, in: value)
        guard let result = values.first,
              values.allSatisfy({ $0 == result }) else {
            throw PrivateAcceptanceError.sourceOracleFailure("builder line 666")
        }
        return result
    }

    static func sha256(_ value: Data) -> String {
        SHA256.hash(data: value)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
