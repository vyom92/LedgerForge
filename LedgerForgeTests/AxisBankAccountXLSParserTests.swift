import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisBankAccountXLSParserTests {
    @Test(.globalRuntimeStateIsolation)
    func ordinaryEnginePreparationUsesReaderProjectionAndDefersPersistence() async throws {
        let provider = DatabaseProvider(inMemory: true)
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-axis-xls-preparation",
                workspaceName: "Axis XLS Preparation"
            )
        )
        let coordinator = DefaultImportCoordinator(
            readerRegistry: DefaultReaderRegistry(readers: [
                DetectableAxisXLSReader()
            ])
        )
        let engine = ImportEngine(
            importCoordinator: coordinator,
            importPersistenceCoordinator: persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate:
                DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )
        let sourceURL = FixtureLocator.axisXLS(
            "axis_bank_nro_account_statement_baseline.xls"
        )

        let prepared = try await engine.prepareImport(from: sourceURL)
        defer { engine.cancelPreparedImport(prepared) }

        #expect(prepared.detectedInstitution == .axis)
        #expect(prepared.detectedDocumentType == .bankAccount)
        #expect(prepared.financialDocument.metadata.fileFormat == .xls)
        #expect(prepared.parserName == "Axis Bank Account XLS")
        #expect(prepared.transactionCount == 16)
        #expect(prepared.validation.passed)
        #expect(prepared.fingerprint.algorithm == SourceContentSnapshot.algorithm)
        #expect(prepared.fingerprintSet.duplicateAuthority?.algorithm == SourceContentSnapshot.algorithm)
        #expect(try provider.workspaceRepo.workspace(id: "workspace-axis-xls-preparation") == nil)
        #expect(try provider.accountRepo.accounts(workspaceId: "workspace-axis-xls-preparation").isEmpty)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: "workspace-axis-xls-preparation").isEmpty)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: "workspace-axis-xls-preparation").isEmpty)
    }

    @Test func committedFixturesMatchIndependentOrderedFinancialEvidence() async throws {
        let fixtures = [
            (
                "axis_bank_nro_account_statement_baseline.xls",
                "axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.expected.json"
            ),
            (
                "axis_bank_nro_account_statement_extended.xls",
                "axis_bank_nro_account_statement_extended.expected.json"
            )
        ]
        for (xlsName, expectedName) in fixtures {
            let expected = try XLSTestExpectation.load(expectedName)
            let financial = try await parsed(xlsName)
            #expect(financial.parserName == "Axis Bank Account XLS")
            #expect(financial.metadata.fileFormat == .xls)
            #expect(financial.bookedCurrency?.code == "INR")
            #expect(financial.transactions.count == expected.transactionCount)
            #expect(financial.financialIdentifiers.map(\.normalizedValue) == [
                expected.verifiedAccountIdentifier.value
            ])
            let expectedStart = try StatementDate.axisNRE(expected.statementStartDate)
            let expectedEnd = try StatementDate.axisNRE(expected.statementEndDate)
            #expect(financial.declaredStatementPeriod?.start == expectedStart)
            #expect(financial.declaredStatementPeriod?.end == expectedEnd)

            for (index, pair) in zip(financial.transactions, expected.transactions).enumerated() {
                let transaction = pair.0
                let evidence = pair.1
                let expectedDate = try StatementDate.axisNRE(evidence.transactionDate)
                let expectedDebit = try Self.decimal(evidence.debit)
                let expectedCredit = try Self.decimal(evidence.credit)
                let expectedBalance = try Self.decimal(evidence.runningBalance)
                #expect(evidence.ordinal == index + 1)
                #expect(transaction.statementDate == expectedDate)
                #expect(transaction.description == evidence.description)
                #expect((transaction.debit ?? 0) == expectedDebit)
                #expect((transaction.credit ?? 0) == expectedCredit)
                #expect(transaction.balance == expectedBalance)
                #expect(transaction.currency == "INR")
                #expect(transaction.financialDateRole == .transactionDate)
                #expect(transaction.statementTimezoneEvidence == .iana("Asia/Kolkata"))
                #expect(transaction.sourceProvenance.first?.sourceOrdinal == index + 18)
                #expect(transaction.sourceProvenance.first?.parserProfileID == "axis.bank-account.xls")
                #expect(transaction.sourceProvenance.first?.parserProfileVersion == "1")
            }
            #expect(ImportValidator.validate(financialDocument: financial).passed)
        }
    }

    @Test func parserRejectsMalformedMoneyAmbiguousDirectionAndNearMatchLayout() throws {
        let malformedMoney = try normalized(
            XLSFixtureTestSupport.syntheticRaw(transaction: [
                "1", "04-04-2026", "REF", "Axis test", "bad", "", "100.00", "9999"
            ])
        )
        #expect(throws: AxisBankAccountXLSParserError.malformedMonetaryValue(sourceOrdinal: 4)) {
            try AxisBankAccountXLSParser().parse(document: malformedMoney)
        }

        let ambiguous = try normalized(
            XLSFixtureTestSupport.syntheticRaw(transaction: [
                "1", "04-04-2026", "REF", "Axis test", "1.00", "1.00", "100.00", "9999"
            ])
        )
        #expect(throws: AxisBankAccountXLSParserError.ambiguousDirection(sourceOrdinal: 4)) {
            try AxisBankAccountXLSParser().parse(document: ambiguous)
        }
    }

    @Test func parserSelectionUsesOrdinaryDetectorClassifierRouteForDetectableXLS() async throws {
        let raw = XLSFixtureTestSupport.syntheticRaw()
        let normalization = try AxisBankAccountXLSNormalizer().normalize(rawDocument: raw)
        let institution = try await SignatureInstitutionDetector().detectInstitution(in: raw)
        let classification = try await StatementClassificationDetector().classify(
            document: raw,
            institution: institution
        )
        let selection = StatementParserSelector().selectParser(
            for: normalization.document,
            institution: institution,
            classification: classification
        )
        #expect(institution.institutionCode == Institution.axis.rawValue)
        #expect(classification.documentType == .bankStatement)
        #expect(selection.parser is AxisBankAccountXLSParser)
        #expect(selection.legacyMetadata.fileFormat == .xls)
    }

    private func parsed(_ fixture: String) async throws -> FinancialDocument {
        let raw = try await XLSFixtureTestSupport.read(fixture)
        let normalization = try AxisBankAccountXLSNormalizer().normalize(rawDocument: raw)
        return try AxisBankAccountXLSParser().parse(
            document: NormalizedDocument(
                document: normalization.document,
                metadata: DocumentMetadata(
                    institution: .axis,
                    documentType: .bankAccount,
                    fileFormat: .xls,
                    confidence: 0.95
                ),
                rows: normalization.rows,
                header: normalization.header,
                sourceContext: normalization.sourceContext
            )
        )
    }

    private func normalized(_ raw: RawDocument) throws -> NormalizedDocument {
        let normalization = try AxisBankAccountXLSNormalizer().normalize(rawDocument: raw)
        return NormalizedDocument(
            document: normalization.document,
            metadata: DocumentMetadata(
                institution: .axis,
                documentType: .bankAccount,
                fileFormat: .xls,
                confidence: 0.95
            ),
            rows: normalization.rows,
            header: normalization.header,
            sourceContext: normalization.sourceContext
        )
    }

    private static func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }
}

private struct DetectableAxisXLSReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["xls"]

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        let raw = try await LegacyXLSDocumentReader().read(
            request: request,
            snapshot: snapshot,
            password: password
        )
        guard case .tabular(let sheet) = raw.content,
              let firstRow = sheet.rows.first,
              let firstCell = firstRow.cells.first else {
            throw ImportError.invalidDocument(message: "Detectable XLS test fixture is malformed.")
        }
        var rows = sheet.rows
        var cells = firstRow.cells
        cells[0] = RawTabularCell(
            sourceRow: firstCell.sourceRow,
            sourceColumn: firstCell.sourceColumn,
            value: .string("Axis Bank")
        )
        rows[0] = RawTabularRow(sourceRow: firstRow.sourceRow, cells: cells)
        return RawDocument(
            id: raw.id,
            sourceURL: raw.sourceURL,
            fileName: raw.fileName,
            fileExtension: raw.fileExtension,
            content: .tabular(
                RawTabularSheet(
                    name: sheet.name,
                    visibility: sheet.visibility,
                    columnCount: sheet.columnCount,
                    rows: rows
                )
            ),
            extractedAt: raw.extractedAt
        )
    }
}

enum XLSFixtureTestSupport {
    static func read(_ fileName: String) async throws -> RawDocument {
        let url = FixtureLocator.axisXLS(fileName)
        let snapshot = SourceContentSnapshot(bytes: try Data(contentsOf: url))
        defer { snapshot.invalidate() }
        return try await LegacyXLSDocumentReader().read(
            request: ImportRequest(fileURL: url),
            snapshot: snapshot,
            password: nil
        )
    }

    static func syntheticRaw(
        header: [String]? = ["SRL NO"] + AxisBankAccountXLSNormalizer.logicalHeader,
        duplicateHeader: Bool = false,
        transaction: [String] = [
            "1", "04-04-2026", "REF", "Axis test", "", "1.00", "101.00", "9999"
        ],
        trailingRows: [[String]] = []
    ) -> RawDocument {
        var values = [
            ["Axis Bank Statement of Account"],
            ["Statement of Account No - 921234567890123 for the period (From : 01-04-2026 To : 30-06-2026)"]
        ]
        if let header { values.append(header) }
        values.append(transaction)
        values.append([])
        values.append(contentsOf: trailingRows)
        if duplicateHeader, let header { values.insert(header, at: 3) }

        let columnCount = max(8, values.map(\.count).max() ?? 0)
        let rows = values.enumerated().map { rowIndex, rowValues in
            RawTabularRow(
                sourceRow: rowIndex + 1,
                cells: (0..<columnCount).map { columnIndex in
                    let text = rowValues.indices.contains(columnIndex)
                        ? rowValues[columnIndex]
                        : ""
                    let value: RawTabularCellValue = text.isEmpty
                        ? .blank
                        : .string(text)
                    return RawTabularCell(
                        sourceRow: rowIndex + 1,
                        sourceColumn: columnIndex + 1,
                        value: value
                    )
                }
            )
        }
        let url = URL(fileURLWithPath: "/tmp/synthetic-axis.xls")
        return RawDocument(
            sourceURL: url,
            fileName: url.lastPathComponent,
            fileExtension: "xls",
            content: .tabular(
                RawTabularSheet(
                    name: "visible",
                    visibility: .visible,
                    columnCount: columnCount,
                    rows: rows
                )
            )
        )
    }
}

private struct XLSTestExpectation: Decodable {
    let transactionCount: Int
    let transactions: [TransactionEvidence]
    let statementStartDate: String
    let statementEndDate: String
    let verifiedAccountIdentifier: IdentifierEvidence

    static func load(_ name: String) throws -> XLSTestExpectation {
        try JSONDecoder().decode(
            XLSTestExpectation.self,
            from: Data(contentsOf: FixtureLocator.axisExpected(name))
        )
    }

    enum CodingKeys: String, CodingKey {
        case transactionCount = "transaction_count"
        case transactions = "canonical_ordered_transactions"
        case statementStartDate = "statement_start_date"
        case statementEndDate = "statement_end_date"
        case verifiedAccountIdentifier = "verified_account_identifier"
    }
}

private struct TransactionEvidence: Decodable {
    let ordinal: Int
    let transactionDate: String
    let description: String
    let debit: String
    let credit: String
    let runningBalance: String

    enum CodingKeys: String, CodingKey {
        case ordinal, description, debit, credit
        case transactionDate = "transaction_date"
        case runningBalance = "running_balance"
    }
}

private struct IdentifierEvidence: Decodable {
    let value: String
}
