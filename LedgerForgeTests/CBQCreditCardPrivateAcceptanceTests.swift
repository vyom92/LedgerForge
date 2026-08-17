import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Opt-in aggregate-only acceptance for task-local text extracted from the
/// private encrypted CBQ corpus. The directory is supplied at runtime; no
/// private path, credential, source value, or row is committed or printed.
@MainActor
struct CBQCreditCardPrivateAcceptanceTests {
    private static let directoryEnvironmentKey = "LEDGERFORGE_PRIVATE_CBQ_TEXT_DIRECTORY"
    private static let expectedChronologicalRowCounts = [15, 19, 28, 14, 11, 18, 12, 16]

    @Test(.globalRuntimeStateIsolation)
    func completePrivateCorpusMatchesProductionGrammarAndAggregateOracle() throws {
        guard let directoryPath = ProcessInfo.processInfo.environment[Self.directoryEnvironmentKey] else {
            return
        }
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter {
            $0.pathExtension.caseInsensitiveCompare("txt") == .orderedSame &&
                $0.lastPathComponent.hasPrefix("source-")
        }.sorted { numericOrdinal($0) < numericOrdinal($1) }
        guard urls.count == 8 else { throw PrivateCBQAcceptanceError.unexpectedCorpusShape }

        var sources = [PrivateCBQSource]()
        var rowCounts = [Int]()
        var rowMismatchCount = 0
        var sectionMismatchCount = 0
        var summaryMismatchCount = 0
        for url in urls {
            let source = try String(contentsOf: url, encoding: .utf8)
            let pages = try splitPages(source)
            let normalized = try CBQCreditCardPDFNormalizer().normalize(
                text: pages.joined(separator: "\n"),
                pageTexts: pages,
                fileURL: URL(fileURLWithPath: "/private/cbq-card-source.pdf")
            )
            let document = try CBQCreditCardPDFParser().parse(document: NormalizedDocument(
                document: normalized.document,
                metadata: DocumentMetadata(
                    institution: .cbq,
                    documentType: .creditCard,
                    fileFormat: .pdf,
                    confidence: 1
                ),
                rows: normalized.rows,
                header: normalized.header,
                sourceContext: normalized.sourceContext
            ))
            guard ImportValidator.validate(financialDocument: document).passed,
                  let evidence = document.cardStatementEvidence,
                  evidence.instrumentSections.count == 2,
                  evidence.transactionAnnotations.count == document.transactions.count else {
                throw PrivateCBQAcceptanceError.productionRejectedSource
            }
            let oracle = try independentOracle(pages: pages)
            rowMismatchCount += financialMismatchCount(
                oracleRows: oracle.rows,
                normalizedRows: normalized.rows,
                document: document,
                evidence: evidence
            )
            sectionMismatchCount += independentSectionMismatchCount(
                oracle: oracle,
                evidence: evidence
            )
            summaryMismatchCount += independentSummaryMismatchCount(
                oracle: oracle,
                evidence: evidence
            )
            sources.append(PrivateCBQSource(
                document: document,
                fingerprintSet: fingerprintSet(source: source)
            ))
            rowCounts.append(document.transactions.count)
        }

        let documents = sources.map(\.document)
        #expect(rowCounts == Self.expectedChronologicalRowCounts)
        #expect(rowCounts.reduce(0, +) == 133)
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

        let chronological = documents.sorted {
            $0.cardStatementEvidence!.declaredStatementPeriod.start <
                $1.cardStatementEvidence!.declaredStatementPeriod.start
        }
        var validAdjacentContinuities = 0
        for (earlier, later) in zip(chronological, chronological.dropFirst()) {
            let earlierEvidence = try #require(earlier.cardStatementEvidence)
            let laterEvidence = try #require(later.cardStatementEvidence)
            let calendar = Calendar(identifier: .gregorian)
            let endDate = try #require(calendar.date(from: DateComponents(
                year: earlierEvidence.declaredStatementPeriod.end.year,
                month: earlierEvidence.declaredStatementPeriod.end.month,
                day: earlierEvidence.declaredStatementPeriod.end.day
            )))
            let startDate = try #require(calendar.date(from: DateComponents(
                year: laterEvidence.declaredStatementPeriod.start.year,
                month: laterEvidence.declaredStatementPeriod.start.month,
                day: laterEvidence.declaredStatementPeriod.start.day
            )))
            let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: endDate
            )
            if nextDay == startDate {
                validAdjacentContinuities += 1
            }
        }
        #expect(validAdjacentContinuities == 6)

        let chronologicalSources = sources.sorted {
            $0.document.cardStatementEvidence!.declaredStatementPeriod.start <
                $1.document.cardStatementEvidence!.declaredStatementPeriod.start
        }
        let mixedIndices = [7, 2, 5, 0, 6, 1, 4, 3]
        let mixed = mixedIndices.map { chronologicalSources[$0] }
        for inMemory in [true, false] {
            try runCampaign(chronologicalSources, inMemory: inMemory, label: "chronological")
            try runCampaign(chronologicalSources.reversed(), inMemory: inMemory, label: "reverse")
            try runCampaign(mixed, inMemory: inMemory, label: "mixed")
        }
    }

    private func runCampaign<S: Sequence>(
        _ sourceSequence: S,
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
            $0.document.cardStatementEvidence!.statementDate <
                $1.document.cardStatementEvidence!.statementDate
        })
        let newestBalance = try #require(
            newest.document.cardStatementEvidence?.summary(code: "new_balance")?.money
        )
        try verifyCampaignGraph(
            provider: provider,
            workspaceID: workspaceID,
            newestBalance: newestBalance
        )
        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
            let reopened = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
            try verifyCampaignGraph(
                provider: reopened,
                workspaceID: workspaceID,
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
        newestBalance: Money
    ) throws {
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 133)
        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == 2)
        #expect(card.instruments.allSatisfy { $0.lifecycleStateCode == CardInstrumentLifecycleState.unknown.rawValue })
        #expect(card.relationships.isEmpty)
        #expect(card.statements.count == 8)
        #expect(card.sections.count == 16)
        #expect(card.transactionEvidence.count == 133)
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
        #expect(hydrated.transactions.count == 133)
        #expect(hydrated.cardSnapshot.instruments.count == 2)
        #expect(hydrated.cardSnapshot.statements.count == 8)
    }

    private func fingerprintSet(source: String) -> PreparedDocumentFingerprintSet {
        func digest(_ bytes: Data) -> String {
            SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        }
        let sourceBytes = Data(source.utf8)
        let rawBytes = Data(("native-text\n" + source).utf8)
        return PreparedDocumentFingerprintSet(fingerprints: [
            VersionedDocumentFingerprint(
                algorithm: ExactStatementFingerprint.algorithm,
                digest: digest(rawBytes),
                byteCount: Int64(rawBytes.count),
                isDuplicateAuthority: false
            ),
            VersionedDocumentFingerprint(
                algorithm: SourceContentSnapshot.algorithm,
                digest: digest(sourceBytes),
                byteCount: Int64(sourceBytes.count),
                isDuplicateAuthority: true
            )
        ])
    }

    private func independentOracle(pages: [String]) throws -> PrivateCBQOracle {
        var rows = [PrivateCBQOracleRow]()
        var sectionTotals = [Int: Money]()
        var sectionOrdinal: Int?
        for (pageOffset, page) in pages.enumerated() {
            for rawLine in page.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.range(of: "Diners Club", options: .caseInsensitive) != nil,
                   line.range(of: #"[0-9X*]{8,}"#, options: .regularExpression) != nil {
                    sectionOrdinal = 1
                    continue
                }
                if line.range(of: "Mastercard Platinum", options: .caseInsensitive) != nil,
                   line.range(of: #"[0-9X*]{8,}"#, options: .regularExpression) != nil {
                    sectionOrdinal = 2
                    continue
                }
                if let total = try oracleSectionTotal(line) {
                    guard let currentOrdinal = sectionOrdinal else { throw PrivateCBQAcceptanceError.unexpectedCorpusShape }
                    sectionTotals[currentOrdinal] = total
                    sectionOrdinal = nil
                    continue
                }
                guard let values = captures(
                    #"^(\d{2}/\d{2}/\d{2})\s+(\d{2}/\d{2}/\d{2})\s+(.+)$"#,
                    in: line
                ), values.count == 3, let sectionOrdinal,
                      let tail = try oracleMoneyTail(values[2]) else { continue }
                rows.append(PrivateCBQOracleRow(
                    sourceOrdinal: rows.count + 1,
                    sourcePage: pageOffset + 1,
                    postingDate: try shortDate(values[0]),
                    purchaseDate: try shortDate(values[1]),
                    effect: tail.effect,
                    postedMoney: tail.postedMoney,
                    originalMoney: tail.originalMoney,
                    accountLevel: tail.description.hasPrefix("Paid using bankDirect"),
                    sectionOrdinal: sectionOrdinal
                ))
            }
        }
        guard sectionTotals.count == 2 else { throw PrivateCBQAcceptanceError.unexpectedCorpusShape }
        return PrivateCBQOracle(
            rows: rows,
            sectionTotals: sectionTotals,
            summary: try independentSummary(pages: pages)
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

    private func independentSummary(pages: [String]) throws -> [String: Money] {
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

        let candidates = preamble.components(separatedBy: .newlines).filter {
            $0.contains("=") && $0.filter { $0 == "+" }.count == 3 &&
                $0.filter { $0 == "-" }.count == 2
        }
        guard candidates.count == 1 else { throw PrivateCBQAcceptanceError.unexpectedCorpusShape }
        let moneyPattern = #"\)?[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?\(?"#
        guard let expression = try? NSRegularExpression(pattern: moneyPattern) else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        let line = candidates[0]
        let tokens = expression.matches(in: line, range: NSRange(line.startIndex..., in: line)).compactMap {
            Range($0.range, in: line).map { String(line[$0]) }
        }
        guard tokens.count == 7 else { throw PrivateCBQAcceptanceError.unexpectedCorpusShape }
        let values = try tokens.map(oracleSummaryMoney)
        let current = values[0]
        let purchases = try positive(values[1])
        let installment = try positive(values[2])
        let fees = try positive(values[3])
        let previous = values[4]
        let payment = try positive(values[5])
        let credit = try positive(values[6])
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

    private func splitPages(_ source: String) throws -> [String] {
        var pages = [String]()
        var current = [String]()
        for line in source.components(separatedBy: .newlines) {
            current.append(line)
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == String(pages.count + 1) {
                pages.append(current.joined(separator: "\n"))
                current = []
            }
        }
        guard pages.count == 3,
              current.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw PrivateCBQAcceptanceError.unexpectedCorpusShape
        }
        return pages
    }

    private func numericOrdinal(_ url: URL) -> Int {
        Int(url.deletingPathExtension().lastPathComponent.split(separator: "-").last ?? "") ?? 0
    }
}

private enum PrivateCBQAcceptanceError: Error {
    case unexpectedCorpusShape
    case productionRejectedSource
    case persistenceRejectedSource
    case persistenceGraphMismatch
}

@MainActor
private struct PrivateCBQSource {
    let document: FinancialDocument
    let fingerprintSet: PreparedDocumentFingerprintSet
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
