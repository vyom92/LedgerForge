import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct AxisRecognizedSourceEvidenceTests {

    @Test func malformedDateInFirstRecognizedTransactionRowFailsWithSourceRow() throws {
        try expectInvalidDateFailure(at: 0, sourceRow: 2)
    }

    @Test func malformedDateInMiddleRecognizedTransactionRowFailsWithSourceRow() throws {
        try expectInvalidDateFailure(at: 1, sourceRow: 3)
    }

    @Test func malformedDateInFinalRecognizedTransactionRowFailsWithSourceRow() throws {
        try expectInvalidDateFailure(at: 2, sourceRow: 4)
    }

    @Test func blankLinesSupportedFooterAndBalanceOnlyMaterialRemainHarmless() throws {
        let text = """
        AXIS BANK
        Statement of Account No - 930000000000001 for the period (From : 01-01-2026 To : 01-01-2026)
        Tran Date,CHQNO,PARTICULARS,DR,CR,BAL,SOL

        01-01-2026,-,Opening credit,,100.00,100.00,4437

        Unless the constituent reports a discrepancy this statement will be treated as correct.
        ,,,,,100.00,

        """
        let parsed = try parseCSV(text)

        #expect(parsed.transactions.count == 1)
        #expect(parsed.transactions.first?.credit == 100)
        #expect(parsed.transactions.first?.balance == 100)
    }

    @Test func validSingleRowStatementRemainsSupported() throws {
        let parsed = try parse(rows: [
            ["01-01-2026", "-", "Opening credit", "", "100.00", "100.00", "4437"]
        ])

        #expect(parsed.transactions.count == 1)
        #expect(ImportValidator.validate(financialDocument: parsed).passed)
    }

    @Test func populatedZeroDebitRemainsARecognizedTransaction() throws {
        let parsed = try parse(rows: [
            ["01-01-2026", "-", "Zero-value debit", "0.00", "", "100.00", "4437"]
        ])

        #expect(parsed.transactions.count == 1)
        #expect(parsed.transactions.first?.debit == 0)
        #expect(parsed.transactions.first?.credit == nil)
        #expect(parsed.transactions.first?.amount == 0)
        #expect(ImportValidator.validate(financialDocument: parsed).passed)
    }

    @Test func malformedRecognizedStructuredAccountEvidenceFailsTyped() throws {
        try expectIdentityFailure(
            sourceFragments: [
                "Statement of Account No - ABC123 for the period (From : 01-01-2026 To : 31-01-2026)"
            ],
            expectedDescription: "Axis account identifier evidence on source row 1 is malformed."
        )
    }

    @Test func distinctRecognizedAccountIdentifiersFailTyped() throws {
        try expectIdentityFailure(
            sourceFragments: [
                "Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)",
                "Statement of Account No - 987654321098765 for the period (From : 01-01-2026 To : 31-01-2026)"
            ],
            expectedDescription: "Axis account identifier evidence contains conflicting recognized values."
        )
    }

    @Test func recognizedEvidenceThatCannotConstructIdentifierFailsTyped() throws {
        try expectIdentityFailure(
            sourceFragments: [
                "Statement of Account No -  for the period (From : 01-01-2026 To : 31-01-2026)"
            ],
            expectedDescription: "Axis account identifier evidence on source row 1 cannot form a verified identifier."
        )
    }

    @Test func validUniqueRecognizedIdentifierRemainsUnchanged() throws {
        let parsed = try parse(
            rows: Self.validRows,
            sourceFragments: [
                "Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)",
                "Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)"
            ]
        )
        let identifier = try #require(parsed.financialIdentifiers.first)

        #expect(parsed.financialIdentifiers.count == 1)
        #expect(identifier.normalizedValue == "123456789012345")
        #expect(identifier.kind == .institutionAccountId)
        #expect(identifier.strength == .strong)
        #expect(identifier.verificationState == .verified)
        #expect(identifier.provenance == .institutionStructuredField)
    }

    @Test func unrelatedUnsupportedPreambleFragmentsRemainIgnored() throws {
        let parsed = try parse(
            rows: Self.validRows,
            sourceFragments: [
                "Customer ID - 000000000",
                "IFSC Code - UTIB0000000",
                "Account suffix - 0000"
            ]
        )

        #expect(parsed.transactions.count == Self.validRows.count)
        #expect(parsed.financialIdentifiers.isEmpty)
    }

    @Test func malformedDatesNeverProducePreparedImportOrReachPersistence() async throws {
        for malformedIndex in Self.validRows.indices {
            var rows = Self.validRows
            rows[malformedIndex][0] = "invalid-date"
            let url = try writeTemporaryCSV(
                named: "fictional-malformed-date-\(malformedIndex).csv",
                rows: rows,
                sourceFragments: [Self.validAccountEvidence]
            )
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

            await expectPreparationFailure(
                from: url,
                expectedDescription: "Axis CSV transaction row \(malformedIndex + 4) contains an invalid date."
            )
        }
    }

    @Test func malformedAndConflictingIdentityNeverProducePreparedImportOrReachPersistence() async throws {
        let cases: [(name: String, fragments: [String], expectedDescription: String)] = [
            (
                "malformed",
                ["Statement of Account No - ABC123 for the period (From : 01-01-2026 To : 31-01-2026)"],
                "Axis account identifier evidence on source row 2 is malformed."
            ),
            (
                "conflicting",
                [
                    "Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)",
                    "Statement of Account No - 987654321098765 for the period (From : 01-01-2026 To : 31-01-2026)"
                ],
                "Axis account identifier evidence contains conflicting recognized values."
            ),
            (
                "unconstructable",
                ["Statement of Account No -  for the period (From : 01-01-2026 To : 31-01-2026)"],
                "Axis account identifier evidence on source row 2 cannot form a verified identifier."
            )
        ]

        for evidenceCase in cases {
            let url = try writeTemporaryCSV(
                named: "fictional-identity-\(evidenceCase.name).csv",
                rows: Self.validRows,
                sourceFragments: evidenceCase.fragments
            )
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

            await expectPreparationFailure(
                from: url,
                expectedDescription: evidenceCase.expectedDescription
            )
        }
    }

    private func expectInvalidDateFailure(
        at malformedIndex: Int,
        sourceRow: Int
    ) throws {
        var rows = Self.validRows
        rows[malformedIndex][0] = "invalid-date"

        do {
            _ = try parse(rows: rows)
            Issue.record("Expected a typed invalid-date failure for Axis source row \(sourceRow).")
        } catch let error as AxisBankAccountParserError {
            #expect(error.localizedDescription == "Axis CSV transaction row \(sourceRow) contains an invalid date.")
        } catch {
            Issue.record("Expected AxisBankAccountParserError, received \(type(of: error)).")
        }
    }

    private func expectIdentityFailure(
        sourceFragments: [String],
        expectedDescription: String
    ) throws {
        do {
            _ = try parse(rows: Self.validRows, sourceFragments: sourceFragments)
            Issue.record("Expected recognized Axis account evidence to fail before FinancialDocument creation.")
        } catch let error as AxisBankAccountParserError {
            #expect(error.localizedDescription == expectedDescription)
        } catch {
            Issue.record("Expected AxisBankAccountParserError, received \(type(of: error)).")
        }
    }

    private func expectPreparationFailure(
        from url: URL,
        expectedDescription: String
    ) async {
        AccountStore.shared.replaceAccounts([])
        TransactionStore.shared.replaceTransactions([])
        DocumentStore.shared.clear()
        let persistence = PreparationPersistenceSpy()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { ProviderGenerationToken() }
        )

        do {
            _ = try await engine.prepareImport(from: url)
            Issue.record("Expected recognized malformed source evidence to block PreparedImport creation.")
        } catch let error as AxisBankAccountParserError {
            #expect(error.localizedDescription == expectedDescription)
        } catch {
            Issue.record("Expected AxisBankAccountParserError, received \(type(of: error)).")
        }

        #expect(persistence.priorFingerprintLookupCount == 0)
        #expect(persistence.reviewCallCount == 0)
        #expect(persistence.persistCallCount == 0)
        #expect(persistence.validationAttemptCallCount == 0)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
        #expect(DocumentStore.shared.rows.isEmpty)
    }

    private func parse(
        rows: [[String]],
        sourceFragments: [String] = []
    ) throws -> FinancialDocument {
        let sourceDocument = Document(
            filename: "fictional-axis-source.csv",
            url: URL(fileURLWithPath: "/tmp/fictional-axis-source.csv"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 0)
        )
        let normalized = NormalizedDocument(
            document: sourceDocument,
            metadata: Self.axisMetadata,
            rows: rows.enumerated().map { index, values in
                NormalizedRow(rowNumber: index + 2, values: values)
            },
            header: NormalizedRow(rowNumber: 1, values: Self.header),
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: sourceFragments.enumerated().map { index, text in
                    NormalizedDocument.SourceFragment(sourceOrdinal: index + 1, text: text)
                }
            )
        )
        return try AxisBankAccountParser().parse(document: normalized)
    }

    private func parseCSV(_ text: String) throws -> FinancialDocument {
        let url = URL(fileURLWithPath: "/tmp/fictional-axis-normalization.csv")
        let document = CSVAnalyzer().analyze(text: text, fileURL: url)
        let normalization = CSVNormalizer().normalizeWithSourceContext(text: text, document: document)
        return try AxisBankAccountParser().parse(
            document: NormalizedDocument(
                document: document,
                metadata: Self.axisMetadata,
                rows: normalization.rows,
                header: normalization.header,
                sourceContext: normalization.sourceContext
            )
        )
    }

    private func writeTemporaryCSV(
        named fileName: String,
        rows: [[String]],
        sourceFragments: [String]
    ) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Recognized-Evidence-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName)
        let text = (["AXIS BANK"] + sourceFragments + [Self.header.joined(separator: ",")] + rows.map { $0.joined(separator: ",") })
            .joined(separator: "\n")
        try Data(text.utf8).write(to: url)
        return url
    }

    private static let header = [
        "Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"
    ]

    private static let validRows = [
        ["01-01-2026", "-", "Opening credit", "", "100.00", "100.00", "4437"],
        ["02-01-2026", "-", "Supported debit", "25.00", "", "75.00", "4437"],
        ["03-01-2026", "-", "Supported credit", "", "10.00", "85.00", "4437"]
    ]

    private static let validAccountEvidence =
        "Statement of Account No - 123456789012345 for the period (From : 01-01-2026 To : 31-01-2026)"

    private static let axisMetadata = DocumentMetadata(
        institution: .axis,
        documentType: .bankAccount,
        fileFormat: .csv,
        confidence: 1
    )
}

private final class PreparationPersistenceSpy: ImportPersistenceCoordinating {
    private(set) var priorFingerprintLookupCount = 0
    private(set) var reviewCallCount = 0
    private(set) var persistCallCount = 0
    private(set) var validationAttemptCallCount = 0

    func priorImportedStatement(
        fingerprint: ExactStatementFingerprint
    ) throws -> PreviouslyImportedStatement? {
        priorFingerprintLookupCount += 1
        return nil
    }

    func reviewValidatedImport(
        financialDocument: FinancialDocument,
        validation: ImportValidationResult
    ) throws -> ImportIdentityReview {
        reviewCallCount += 1
        return .unavailable
    }

    func recordValidationFailure(fileName: String, transactionCount: Int) -> String? {
        validationAttemptCallCount += 1
        return nil
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        persistCallCount += 1
        return .skipped
    }
}
