import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct HDFCBankAccountPDFAndProjectionTests {
    private struct PrivatePairKey: Hashable {
        let account: String
        let periodStart: StatementDate
        let periodEnd: StatementDate
        let currency: CurrencyCode
    }

    private struct PrivateParsedSource {
        let document: FinancialDocument
        let rawTextDigest: String
        let sourceBytesDigest: String
        let byteCount: Int64
    }

    @Test func syntheticNativePDFNormalizesAndParsesExactRetainedGrammar() async throws {
        let normalized = try await normalizedPDF()
        #expect(normalized.header?.values == HDFCBankAccountXLSNormalizer.logicalHeader)
        #expect(normalized.rows.count == 4)
        #expect(normalized.rows.map(\.values.count) == [7, 7, 7, 7])
        #expect(normalized.rows.map { $0.values[1] } == [
            "Synthetic debit event",
            "Synthetic credit event",
            "Synthetic reversal debit",
            "Synthetic reversal credit"
        ])
        #expect(normalized.rows.map { $0.values[2] } == ["REV0001", "CREDIT1", "REPEAT9", "REPEAT9"])
        #expect(normalized.rows.map { $0.values[4].isEmpty } == [false, true, false, true])
        #expect(normalized.rows.map { $0.values[5].isEmpty } == [true, false, true, false])

        let parsed = try HDFCBankAccountPDFParser().parse(document: normalized)
        #expect(parsed.parserName == "HDFC Bank Account PDF")
        #expect(parsed.bookedCurrency?.code == "INR")
        #expect(parsed.transactions.count == 4)
        #expect(parsed.financialIdentifiers.count == 1)
        #expect(parsed.financialIdentifiers[0].kind == .institutionAccountId)
        #expect(parsed.financialIdentifiers[0].normalizedValue == "11112222333344")
        #expect(parsed.transactions.allSatisfy {
            $0.sourceProvenance.first?.parserProfileID == HDFCBankAccountPDFParser.profileID &&
            $0.sourceProvenance.first?.parserProfileVersion == HDFCBankAccountPDFParser.profileVersion
        })
        #expect(ImportValidator.validate(financialDocument: parsed).passed)
    }

    @Test(.globalRuntimeStateIsolation)
    func ordinaryURLPreparationRoutesTheHDFCPDFProfile() async throws {
        let provider = DatabaseProvider(inMemory: true)
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-hdfc-pdf-v1",
                workspaceName: "HDFC PDF v1 Tests"
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

        let prepared = try await engine.prepareImport(
            from: FixtureLocator.hdfcSyntheticPDF(
                "hdfc_bank_account_pdf_v1_nre_synthetic.pdf"
            )
        )
        defer { engine.cancelPreparedImport(prepared) }

        #expect(prepared.detectedInstitution == .hdfc)
        #expect(prepared.detectedDocumentType == .bankAccount)
        #expect(prepared.financialDocument.metadata.fileFormat == .pdf)
        #expect(prepared.parserName == "HDFC Bank Account PDF")
        #expect(prepared.transactionCount == 4)
        #expect(prepared.validation.passed)
        #expect(
            prepared.fingerprintSet.duplicateAuthority?.algorithm
                == SourceContentSnapshot.algorithm
        )
        #expect(
            try provider.transactionRepo.trustedTransactions(
                workspaceId: "workspace-hdfc-pdf-v1"
            ).isEmpty
        )
    }

    @Test func pairedSyntheticPDFAndXLSProduceEqualFormatNeutralProjection() async throws {
        let pdf = try HDFCBankAccountPDFParser().parse(document: await normalizedPDF())
        let xls = try HDFCBankAccountXLSParser().parse(
            document: await HDFCXLSFixtureTestSupport.normalized(
                HDFCXLSFixtureTestSupport.annualFixture
            )
        )
        let pdfProjection = try StatementFinancialProjection.make(from: pdf)
        let xlsProjection = try StatementFinancialProjection.make(from: xls)

        #expect(pdfProjection == xlsProjection)
        #expect(pdfProjection.digest == xlsProjection.digest)
        #expect(pdfProjection.hasValidDigest())
        #expect(pdfProjection.eventCount == 4)
        #expect(pdfProjection.debitCount == 2)
        #expect(pdfProjection.creditCount == 2)
    }

    @Test func projectionDigestPreservesEventOrderButExcludesNarration() async throws {
        let source = try HDFCBankAccountPDFParser().parse(document: await normalizedPDF())
        let original = try StatementFinancialProjection.make(from: source)
        var reversedTransactions = source.transactions
        reversedTransactions.swapAt(0, 1)
        let reordered = FinancialDocument(
            sourceDocument: source.sourceDocument,
            metadata: source.metadata,
            parserName: source.parserName,
            bookedCurrency: source.bookedCurrency,
            declaredStatementPeriod: source.declaredStatementPeriod,
            transactions: reversedTransactions,
            financialIdentifiers: source.financialIdentifiers
        )
        #expect(try StatementFinancialProjection.make(from: reordered).digest != original.digest)

        var narrationChangedTransactions = source.transactions
        narrationChangedTransactions[0].description = "Different presentation-only narration"
        let narrationChanged = FinancialDocument(
            sourceDocument: source.sourceDocument,
            metadata: source.metadata,
            parserName: "Presentation-only parser label",
            bookedCurrency: source.bookedCurrency,
            declaredStatementPeriod: source.declaredStatementPeriod,
            transactions: narrationChangedTransactions,
            financialIdentifiers: source.financialIdentifiers
        )
        #expect(try StatementFinancialProjection.make(from: narrationChanged).digest == original.digest)
    }

    @Test func projectionDigestIsSensitiveToEveryFinancialField() async throws {
        let source = try HDFCBankAccountPDFParser().parse(document: await normalizedPDF())
        let original = try StatementFinancialProjection.make(from: source).digest
        let changedStatementDate = try replacingTransaction(in: source, at: 0) {
            try clone($0, statementDate: StatementDate(year: 2025, month: 4, day: 3))
        }
        let changedValueDate = try replacingTransaction(in: source, at: 0) {
            try clone($0, valueDate: StatementDate(year: 2025, month: 4, day: 2))
        }
        let changedDirection = try replacingTransaction(in: source, at: 0) { transaction in
            let magnitude = try #require(transaction.debitMoney)
            return try clone(
                transaction,
                debitMoney: .value(nil),
                creditMoney: .value(magnitude),
                money: Money(amount: magnitude.amount, currency: magnitude.currency)
            )
        }
        let changedAmount = try replacingTransaction(in: source, at: 0) { transaction in
            let currency = transaction.money.currency
            let magnitude = try Money(amount: 11.25, currency: currency)
            return try clone(
                transaction,
                debitMoney: .value(magnitude),
                creditMoney: .value(nil),
                money: Money(amount: -11.25, currency: currency)
            )
        }
        let changedBalance = try replacingTransaction(in: source, at: 0) { transaction in
            try clone(
                transaction,
                runningBalanceMoney: .value(Money(amount: 990.75, currency: transaction.money.currency))
            )
        }
        let changedReference = try replacingTransaction(in: source, at: 0) {
            try clone($0, reference: .value("DIFFERENT1"))
        }
        let nilReference = try replacingTransaction(in: source, at: 0) {
            try clone($0, reference: .value(nil))
        }
        let emptyReference = try replacingTransaction(in: source, at: 0) {
            try clone($0, reference: .value(""))
        }
        let changedPeriod = FinancialDocument(
            sourceDocument: source.sourceDocument,
            metadata: source.metadata,
            parserName: source.parserName,
            bookedCurrency: source.bookedCurrency,
            declaredStatementPeriod: try DeclaredStatementPeriod(
                start: StatementDate(year: 2025, month: 4, day: 2),
                end: try #require(source.declaredStatementPeriod?.end)
            ),
            transactions: source.transactions,
            financialIdentifiers: source.financialIdentifiers
        )
        let usd = try CurrencyCode("USD")
        let changedCurrencyTransactions = try source.transactions.map { transaction in
            try clone(
                transaction,
                debitMoney: .value(try transaction.debitMoney.map { try Money(amount: $0.amount, currency: usd) }),
                creditMoney: .value(try transaction.creditMoney.map { try Money(amount: $0.amount, currency: usd) }),
                money: Money(amount: transaction.money.amount, currency: usd),
                runningBalanceMoney: .value(try transaction.runningBalanceMoney.map { try Money(amount: $0.amount, currency: usd) })
            )
        }
        let changedCurrency = FinancialDocument(
            sourceDocument: source.sourceDocument,
            metadata: source.metadata,
            parserName: source.parserName,
            bookedCurrency: usd,
            declaredStatementPeriod: source.declaredStatementPeriod,
            transactions: changedCurrencyTransactions,
            financialIdentifiers: source.financialIdentifiers
        )

        let changedDigests = try [
            changedStatementDate,
            changedValueDate,
            changedDirection,
            changedAmount,
            changedBalance,
            changedReference,
            changedPeriod,
            changedCurrency
        ].map { try StatementFinancialProjection.make(from: $0).digest }
        #expect(changedDigests.allSatisfy { $0 != original })
        #expect(Set(changedDigests).count == changedDigests.count)
        #expect(try StatementFinancialProjection.make(from: nilReference).digest != StatementFinancialProjection.make(from: emptyReference).digest)
    }

    @Test func changedHeaderAndFinancialNearMatchFailClosed() async throws {
        await #expect(throws: HDFCBankAccountPDFNormalizationError.changedHeader) {
            _ = try await normalizedPDF(
                named: "hdfc_bank_account_pdf_v1_changed_header_synthetic.pdf"
            )
        }

        let mismatchDocument = try HDFCBankAccountPDFParser().parse(
            document: await normalizedPDF(
                named: "hdfc_bank_account_pdf_v1_financial_mismatch_synthetic.pdf"
            )
        )
        let spreadsheet = try HDFCBankAccountXLSParser().parse(
            document: await HDFCXLSFixtureTestSupport.normalized(
                HDFCXLSFixtureTestSupport.annualFixture
            )
        )
        #expect(try StatementFinancialProjection.make(from: mismatchDocument) != StatementFinancialProjection.make(from: spreadsheet))
    }

    @Test func repeatedPageHeaderPreservesOrderAndDualAmountFailsClosed() async throws {
        let repeatedHeaderDocument = try HDFCBankAccountPDFParser().parse(
            document: await normalizedPDF(
                named: "hdfc_bank_account_pdf_v1_repeated_header_synthetic.pdf"
            )
        )
        let spreadsheet = try HDFCBankAccountXLSParser().parse(
            document: await HDFCXLSFixtureTestSupport.normalized(
                HDFCXLSFixtureTestSupport.annualFixture
            )
        )
        #expect(repeatedHeaderDocument.transactions.count == 4)
        #expect(repeatedHeaderDocument.transactions.map { $0.sourceProvenance.first?.sourceOrdinal }.allSatisfy { $0 != nil })
        #expect(try StatementFinancialProjection.make(from: repeatedHeaderDocument) == StatementFinancialProjection.make(from: spreadsheet))

        do {
            _ = try await normalizedPDF(
                named: "hdfc_bank_account_pdf_v1_dual_amount_synthetic.pdf"
            )
            Issue.record("Expected the dual-populated amount row to fail closed.")
        } catch let error as HDFCBankAccountPDFNormalizationError {
            guard case .missingOrAmbiguousAmount = error else {
                Issue.record("Expected the typed dual-amount rejection.")
                return
            }
        }
    }

    @Test(
        .enabled(
            if: Self.privateOriginalContextConfigured,
            "Requires the private HDFC originals root"
        )
    )
    func privateOriginalPairsProduceExactProductionProjectionsWhenConfigured() async throws {
        let rootText: String
        if let configuredRoot = ProcessInfo.processInfo.environment["LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_ROOT"] {
            rootText = configuredRoot
        } else {
            let pointer = ProcessInfo.processInfo.environment["LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_FILE"]
                ?? "/tmp/lf_private_originals_root"
            guard FileManager.default.fileExists(atPath: pointer) else { return }
            rootText = try String(contentsOfFile: pointer, encoding: .utf8)
        }
        let root = URL(
            fileURLWithPath: rootText.trimmingCharacters(in: .whitespacesAndNewlines),
            isDirectory: true
        )
        let urls = (FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )?.allObjects as? [URL] ?? []).filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }

        var pdfs: [PrivatePairKey: PrivateParsedSource] = [:]
        var spreadsheets: [PrivatePairKey: PrivateParsedSource] = [:]
        var pdfNormalizedRows: [Int: [NormalizedRow]] = [:]
        var spreadsheetNormalizedRows: [Int: [NormalizedRow]] = [:]
        var pdfParseFailures = 0
        var pdfFailureBuckets: [String: Int] = [:]
        var spreadsheetParseFailures = 0

        for url in urls where url.pathExtension.lowercased() == "pdf" {
            let bytes = try Data(contentsOf: url)
            let snapshot = SourceContentSnapshot(bytes: bytes)
            defer { snapshot.invalidate() }
            let raw = try await PDFDocumentReader().read(
                request: ImportRequest(fileURL: url),
                snapshot: snapshot,
                password: nil
            )
            let collapsed = raw.searchableText.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            guard collapsed.localizedCaseInsensitiveContains("HDFC BANK LIMITED"),
                  collapsed.localizedCaseInsensitiveContains("STATEMENT OF ACCOUNT") else {
                continue
            }
            do {
                let result = try HDFCBankAccountPDFNormalizer().normalize(
                    text: raw.searchableText,
                    sourceBytes: bytes,
                    fileURL: url
                )
                let normalized = NormalizedDocument(
                    document: result.document,
                    metadata: DocumentMetadata(
                        institution: .hdfc,
                        documentType: .bankAccount,
                        fileFormat: .pdf,
                        confidence: 0.99
                    ),
                    rows: result.rows,
                    header: result.header,
                    sourceContext: result.sourceContext
                )
                pdfNormalizedRows[result.rows.count] = result.rows
                let document = try HDFCBankAccountPDFParser().parse(document: normalized)
                pdfs[try privatePairKey(document)] = PrivateParsedSource(
                    document: document,
                    rawTextDigest: digest(raw.searchableText),
                    sourceBytesDigest: digest(bytes),
                    byteCount: Int64(bytes.count)
                )
            } catch {
                pdfParseFailures += 1
                pdfFailureBuckets[Self.privatePDFFailureBucket(error), default: 0] += 1
            }
        }

        for url in urls where url.pathExtension.lowercased() == "xls" && url.path.lowercased().contains("hdfc") {
            let bytes = try Data(contentsOf: url)
            let snapshot = SourceContentSnapshot(bytes: bytes)
            defer { snapshot.invalidate() }
            do {
                let raw = try await LegacyXLSDocumentReader().read(
                    request: ImportRequest(fileURL: url),
                    snapshot: snapshot,
                    password: nil
                )
                let collapsed = raw.searchableText.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
                guard collapsed.localizedCaseInsensitiveContains("HDFC BANK"),
                      collapsed.localizedCaseInsensitiveContains("STATEMENT OF ACCOUNTS") else {
                    continue
                }
                let result = try HDFCBankAccountXLSNormalizer().normalize(rawDocument: raw)
                let normalized = NormalizedDocument(
                    document: result.document,
                    metadata: DocumentMetadata(
                        institution: .hdfc,
                        documentType: .bankAccount,
                        fileFormat: .xls,
                        confidence: 0.99
                    ),
                    rows: result.rows,
                    header: result.header,
                    sourceContext: result.sourceContext
                )
                spreadsheetNormalizedRows[result.rows.count] = result.rows
                let document = try HDFCBankAccountXLSParser().parse(document: normalized)
                spreadsheets[try privatePairKey(document)] = PrivateParsedSource(
                    document: document,
                    rawTextDigest: digest(raw.searchableText),
                    sourceBytesDigest: digest(bytes),
                    byteCount: Int64(bytes.count)
                )
            } catch {
                spreadsheetParseFailures += 1
            }
        }

        let keys = Set(pdfs.keys).intersection(spreadsheets.keys)
        let rowCounts = keys.compactMap { pdfs[$0]?.document.transactions.count }.sorted()
        let oraclePath = ProcessInfo.processInfo.environment["LEDGERFORGE_PRIVATE_HDFC_ORACLE_FILE"]
            ?? "/tmp/lf_hdfc_independent_projection_digests.json"
        guard FileManager.default.fileExists(atPath: oraclePath) else {
            Issue.record("Independent projection-oracle evidence is required for the private campaign.")
            return
        }
        let oracleDigests = try JSONDecoder().decode(
            [String: String].self,
            from: Data(contentsOf: URL(fileURLWithPath: oraclePath))
        )
        var missingOracleProjections = 0
        var productionPDFOracleMismatches = 0
        var productionSpreadsheetOracleMismatches = 0
        for key in keys {
            let oracleKey = [
                key.account,
                key.periodStart.canonical,
                key.periodEnd.canonical,
                key.currency.code
            ].joined(separator: "|")
            guard let oracleDigest = oracleDigests[oracleKey],
                  let pdf = pdfs[key],
                  let spreadsheet = spreadsheets[key] else {
                missingOracleProjections += 1
                continue
            }
            if try StatementFinancialProjection.make(from: pdf.document).digest != oracleDigest {
                productionPDFOracleMismatches += 1
            }
            if try StatementFinancialProjection.make(from: spreadsheet.document).digest != oracleDigest {
                productionSpreadsheetOracleMismatches += 1
            }
        }
        var normalizedFieldMismatches = Array(repeating: 0, count: 7)
        for rowCount in Set(pdfNormalizedRows.keys).intersection(spreadsheetNormalizedRows.keys) {
            guard let pdfRows = pdfNormalizedRows[rowCount],
                  let spreadsheetRows = spreadsheetNormalizedRows[rowCount] else { continue }
            for (pdfRow, spreadsheetRow) in zip(pdfRows, spreadsheetRows) {
                for index in [0, 2, 3] where pdfRow.values[index] != spreadsheetRow.values[index] {
                    normalizedFieldMismatches[index] += 1
                }
                for index in [4, 5, 6]
                where Decimal(
                    string: pdfRow.values[index].replacingOccurrences(of: ",", with: ""),
                    locale: Locale(identifier: "en_US_POSIX")
                ) != Decimal(
                    string: spreadsheetRow.values[index].replacingOccurrences(of: ",", with: ""),
                    locale: Locale(identifier: "en_US_POSIX")
                ) {
                    normalizedFieldMismatches[index] += 1
                }
            }
        }
        var projectionMismatches = 0
        var importCampaignFailures = 0
        for key in keys {
            guard let pdf = pdfs[key], let spreadsheet = spreadsheets[key] else { continue }
            if try StatementFinancialProjection.make(from: pdf.document) != StatementFinancialProjection.make(from: spreadsheet.document) {
                projectionMismatches += 1
            }
            importCampaignFailures += try verifyPrivateImportCampaign(
                first: pdf,
                second: spreadsheet
            )
            importCampaignFailures += try verifyPrivateImportCampaign(
                first: spreadsheet,
                second: pdf
            )
        }
        #expect(spreadsheetParseFailures == 0)
        #expect(pdfs.count == 4, "Private PDF rejection buckets: \(pdfFailureBuckets)")
        #expect(spreadsheets.count == 4)
        #expect(oracleDigests.count == 4)
        #expect(missingOracleProjections == 0)
        #expect(productionPDFOracleMismatches == 0)
        #expect(productionSpreadsheetOracleMismatches == 0)
        #expect(pdfNormalizedRows.keys.sorted() == [7, 16, 62, 76])
        #expect(spreadsheetNormalizedRows.keys.sorted() == [7, 16, 62, 76])
        #expect(normalizedFieldMismatches == Array(repeating: 0, count: 7), "Normalized field mismatch counts: \(normalizedFieldMismatches)")
        #expect(keys.count == 4)
        #expect(rowCounts == [7, 16, 62, 76])
        #expect(projectionMismatches == 0)
        #expect(importCampaignFailures == 0)
    }

    nonisolated private static var privateOriginalContextConfigured: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_ROOT"]?.isEmpty == false {
            return true
        }
        guard let pointer = environment["LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_FILE"],
              !pointer.isEmpty else {
            return false
        }
        return FileManager.default.fileExists(atPath: pointer)
    }

    private static func privatePDFFailureBucket(_ error: Error) -> String {
        if let error = error as? HDFCBankAccountPDFNormalizationError {
            switch error {
            case .unsupportedDocumentContent: return "unsupported_document_content"
            case .lockedDocument: return "locked_document"
            case .unsupportedNativeText: return "unsupported_native_text"
            case .missingTitle: return "missing_title"
            case .missingHeader: return "missing_header"
            case .changedHeader: return "changed_header"
            case .malformedPreamble: return "malformed_preamble"
            case .noTransactions: return "no_transactions"
            case .incompleteTransaction: return "incomplete_transaction"
            case .missingOrAmbiguousAmount: return "missing_or_ambiguous_amount"
            case .malformedSummary: return "malformed_summary"
            case .unconsumedFinancialContent: return "unconsumed_financial_content"
            }
        }
        if let error = error as? HDFCBankAccountXLSParserError {
            return "shared_" + String(describing: error).split(separator: "(", maxSplits: 1)[0]
        }
        if error is HDFCBankAccountPDFParserError { return "parser_reconciliation" }
        return "reader_or_unclassified"
    }

    private func verifyPrivateImportCampaign(
        first: PrivateParsedSource,
        second: PrivateParsedSource
    ) throws -> Int {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let databaseURL = folder.appendingPathComponent("private-campaign.sqlite")
        var sqlite: SQLiteRepositoryProvider? = try SQLiteRepositoryProvider(path: databaseURL.path)
        let runtime = databaseProvider(try #require(sqlite))
        let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: runtime)
        let expectedCount = first.document.transactions.count
        var failures = 0

        let authoritative = try persistPrivate(
            first,
            sequence: "authoritative",
            coordinator: coordinator,
            provider: runtime,
            accountChoice: .createNewAccount
        )
        if !authoritative.persisted || authoritative.transactionCount != expectedCount || authoritative.isEquivalentSupportingSource {
            failures += 1
        }
        let supporting = try persistPrivate(
            second,
            sequence: "supporting",
            coordinator: coordinator,
            provider: runtime,
            accountChoice: nil
        )
        if !supporting.persisted || supporting.transactionCount != 0 || !supporting.isEquivalentSupportingSource {
            failures += 1
        }

        let projections = try runtime.importSessionRepo.statementFinancialProjections(workspaceId: "default-workspace")
        let groups = try runtime.importSessionRepo.statementEquivalenceGroups(workspaceId: "default-workspace")
        let members = try runtime.importSessionRepo.statementEquivalenceMembers(workspaceId: "default-workspace")
        let transactions = try runtime.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        let attempts = try runtime.importSessionRepo.importAttempts(workspaceId: "default-workspace")
        if projections.count != 2 || groups.count != 1 || members.count != 2 || transactions.count != expectedCount || attempts.count != 2 {
            failures += 1
        }
        if members.filter({ $0.role == .authoritative }).count != 1 ||
            members.filter({ $0.role == .supporting }).count != 1 ||
            Set(members.map(\.sourceFormatCode)) != ["pdf", "xls"] ||
            Set(transactions.compactMap(\.importSessionId)) != [authoritative.importSessionId] {
            failures += 1
        }
        let supportingAttempt = attempts.first {
            $0.outcomeCode == ImportAttemptOutcome.equivalentSourceRecorded.rawValue
        }
        if supportingAttempt?.transactionCount != 0 ||
            supportingAttempt?.sourceRowCount != expectedCount ||
            supportingAttempt?.importedTransactionCount != 0 ||
            supportingAttempt?.recognizedExistingRowCount != expectedCount ||
            supportingAttempt?.blockedRowCount != 0 ||
            supportingAttempt?.relatedImportSessionId != authoritative.importSessionId {
            failures += 1
        }

        let exactReimport = try persistPrivate(
            second,
            sequence: "exact-reimport",
            coordinator: coordinator,
            provider: runtime,
            accountChoice: nil
        )
        let memberCountAfterReimport = try runtime.importSessionRepo
            .statementEquivalenceMembers(workspaceId: "default-workspace").count
        if exactReimport.persisted || exactReimport.previousImport == nil || memberCountAfterReimport != 2 {
            failures += 1
        }

        let durableCounts = try sqlite?.database.query(
            sql: "SELECT (SELECT COUNT(*) FROM accounts), (SELECT COUNT(*) FROM account_identifiers), (SELECT COUNT(*) FROM account_identifier_observations), (SELECT COUNT(*) FROM documents), (SELECT COUNT(*) FROM document_fingerprints WHERE algorithm = ?), (SELECT COUNT(*) FROM import_sessions), (SELECT COUNT(*) FROM statement_financial_projection_events), (SELECT COUNT(*) FROM categories);",
            params: [DocumentFingerprintDTO.sourceBytesSHA256Algorithm]
        ) { row in
            (0...7).map { Int(row.int64(at: Int32($0)) ?? -1) }
        }.first
        if durableCounts != [1, 1, 2, 2, 2, 2, expectedCount * 2, 0] {
            failures += 1
        }

        sqlite?.database.close()
        sqlite = nil
        let reopened = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopened.database.close() }
        let reopenedRuntime = databaseProvider(reopened)
        let snapshot = try RepositoryStoreHydrator(
            databaseProvider: reopenedRuntime,
            workspaceId: "default-workspace",
            categoryReconciliationGate: nil,
            participatesInLifecycleGate: false
        ).stageHydration()
        let reopenedProjectionCount = try reopenedRuntime.importSessionRepo
            .statementFinancialProjections(workspaceId: "default-workspace").count
        let reopenedMemberCount = try reopenedRuntime.importSessionRepo
            .statementEquivalenceMembers(workspaceId: "default-workspace").count
        if snapshot.transactions.count != expectedCount ||
            snapshot.importSessions.count != 2 ||
            snapshot.importAttempts.count != 3 ||
            reopenedProjectionCount != 2 ||
            reopenedMemberCount != 2 {
            failures += 1
        }
        return failures
    }

    private func persistPrivate(
        _ source: PrivateParsedSource,
        sequence: String,
        coordinator: DefaultImportPersistenceCoordinator,
        provider: DatabaseProvider,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        let validation = ImportValidator.validate(financialDocument: source.document)
        guard validation.passed else { throw ImportPersistenceError.validationFailed }
        let session = ImportSession(
            fileName: "private-acceptance-\(sequence).\(source.document.metadata.fileFormat.rawValue.lowercased())",
            institution: .hdfc,
            documentType: .bankAccount,
            parserName: source.document.parserName,
            transactionCount: source.document.transactions.count,
            validation: validation
        )
        return try coordinator.persistValidatedImport(
            financialDocument: source.document,
            importSession: session,
            validation: validation,
            fingerprintSet: PreparedDocumentFingerprintSet(fingerprints: [
                VersionedDocumentFingerprint(
                    algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm,
                    digest: source.rawTextDigest,
                    byteCount: source.byteCount,
                    isDuplicateAuthority: false
                ),
                VersionedDocumentFingerprint(
                    algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
                    digest: source.sourceBytesDigest,
                    byteCount: source.byteCount,
                    isDuplicateAuthority: true
                )
            ]),
            accountChoice: accountChoice,
            providerGeneration: provider.generationToken
        )
    }

    private func databaseProvider(_ sqlite: SQLiteRepositoryProvider) -> DatabaseProvider {
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

    private func digest(_ text: String) -> String {
        digest(Data(text.utf8))
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func normalizedPDF(
        named fileName: String = "hdfc_bank_account_pdf_v1_nre_synthetic.pdf"
    ) async throws -> NormalizedDocument {
        let url = FixtureLocator.hdfcSyntheticPDF(fileName)
        let bytes = try Data(contentsOf: url)
        let snapshot = SourceContentSnapshot(bytes: bytes)
        defer { snapshot.invalidate() }
        let raw = try await PDFDocumentReader().read(
            request: ImportRequest(fileURL: url),
            snapshot: snapshot,
            password: nil
        )
        let normalization = try HDFCBankAccountPDFNormalizer().normalize(
            text: raw.searchableText,
            sourceBytes: bytes,
            fileURL: url
        )
        return NormalizedDocument(
            document: normalization.document,
            metadata: DocumentMetadata(
                institution: .hdfc,
                documentType: .bankAccount,
                fileFormat: .pdf,
                confidence: 0.99
            ),
            rows: normalization.rows,
            header: normalization.header,
            sourceContext: normalization.sourceContext
        )
    }

    private func privatePairKey(_ document: FinancialDocument) throws -> PrivatePairKey {
        PrivatePairKey(
            account: try #require(document.financialIdentifiers.first?.normalizedValue),
            periodStart: try #require(document.declaredStatementPeriod?.start),
            periodEnd: try #require(document.declaredStatementPeriod?.end),
            currency: try #require(document.bookedCurrency)
        )
    }

    private enum ReferenceReplacement {
        case unchanged
        case value(String?)
    }

    private enum MoneyReplacement {
        case unchanged
        case value(Money?)
    }

    private func replacingTransaction(
        in document: FinancialDocument,
        at index: Int,
        transform: (Transaction) throws -> Transaction
    ) throws -> FinancialDocument {
        var transactions = document.transactions
        transactions[index] = try transform(transactions[index])
        return FinancialDocument(
            sourceDocument: document.sourceDocument,
            metadata: document.metadata,
            parserName: document.parserName,
            bookedCurrency: document.bookedCurrency,
            declaredStatementPeriod: document.declaredStatementPeriod,
            transactions: transactions,
            financialIdentifiers: document.financialIdentifiers
        )
    }

    private func clone(
        _ transaction: Transaction,
        statementDate: StatementDate? = nil,
        valueDate: StatementDate? = nil,
        reference: ReferenceReplacement = .unchanged,
        debitMoney: MoneyReplacement = .unchanged,
        creditMoney: MoneyReplacement = .unchanged,
        money: Money? = nil,
        runningBalanceMoney: MoneyReplacement = .unchanged
    ) throws -> Transaction {
        Transaction(
            statementDate: statementDate ?? transaction.statementDate,
            valueDate: valueDate ?? transaction.valueDate,
            description: transaction.description,
            reference: {
                switch reference {
                case .unchanged: return transaction.reference
                case .value(let value): return value
                }
            }(),
            debitMoney: {
                switch debitMoney {
                case .unchanged: return transaction.debitMoney
                case .value(let value): return value
                }
            }(),
            creditMoney: {
                switch creditMoney {
                case .unchanged: return transaction.creditMoney
                case .value(let value): return value
                }
            }(),
            money: money ?? transaction.money,
            runningBalanceMoney: {
                switch runningBalanceMoney {
                case .unchanged: return transaction.runningBalanceMoney
                case .value(let value): return value
                }
            }(),
            account: transaction.account,
            sourceBank: transaction.sourceBank,
            sourceFile: transaction.sourceFile,
            financialDateRole: transaction.financialDateRole,
            statementTimezoneEvidence: transaction.statementTimezoneEvidence,
            sourceProvenance: transaction.sourceProvenance
        )
    }
}
