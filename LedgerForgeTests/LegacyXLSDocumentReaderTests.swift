import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct LegacyXLSDocumentReaderTests {
    @Test func readerSupportsExactlyXLSAndPreservesBoundedTabularCells() async throws {
        let url = FixtureLocator.axisXLS("axis_bank_nro_account_statement_baseline.xls")
        let rawDocument = try await read(url)

        #expect(LegacyXLSDocumentReader().supportedFileExtensions == ["xls"])
        #expect(rawDocument.fileExtension == "xls")
        guard case .tabular(let sheet) = rawDocument.content else {
            Issue.record("Expected tabular XLS content.")
            return
        }
        #expect(sheet.name == "sanitized")
        #expect(sheet.visibility == .visible)
        #expect(sheet.rows.count == 62)
        #expect(sheet.columnCount == 8)
        #expect(sheet.rows[16].sourceRow == 17)
        #expect(sheet.rows[16].cells.map(\.sourceColumn) == Array(1...8))
        #expect(sheet.rows[16].cells.map(\.value.canonicalText) == [
            "SRL NO", "Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"
        ])
        #expect(sheet.rows[17].cells[0].value == .number("1"))
        #expect(sheet.rows[17].cells[4].value == .string(" "))
        #expect(sheet.rows[17].cells[5].value == .number("4221"))
        #expect(rawDocument.searchableText.contains("Tran Date"))
        #expect(rawDocument.searchableText.contains("PARTICULARS"))
    }

    @Test func readerUsesSnapshotBytesAndRawDocumentRetainsNoWorkbookBytes() async throws {
        let url = FixtureLocator.axisXLS("axis_bank_nro_account_statement_baseline.xls")
        let snapshot = SourceContentSnapshot(bytes: try Data(contentsOf: url))
        let rawDocument = try await LegacyXLSDocumentReader().read(
            request: ImportRequest(fileURL: url),
            snapshot: snapshot,
            password: nil
        )
        snapshot.invalidate()

        #expect(!rawDocument.searchableText.isEmpty)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try snapshot.withBytes { $0.count }
        }
        guard case .tabular = rawDocument.content else {
            Issue.record("Expected tabular content after snapshot invalidation.")
            return
        }
    }

    @Test func readerRejectsInvalidAndTruncatedOLE2() async throws {
        let invalidURL = URL(fileURLWithPath: "/tmp/invalid.xls")
        await expectFailure(
            requestURL: invalidURL,
            bytes: Data("not an OLE container".utf8),
            expected: .invalidDocument(message: "XLS workbook is malformed or unsupported.")
        )

        let source = try Data(contentsOf: FixtureLocator.axisXLS(
            "axis_bank_nro_account_statement_baseline.xls"
        ))
        await expectInvalidDocument(
            requestURL: URL(fileURLWithPath: "/tmp/truncated.xls"),
            bytes: source.prefix(source.count / 3)
        )
    }

    @Test func readerFailsClosedForEncryptedMultiSheetHiddenFormulaAndBooleanWorkbooks() async throws {
        let fixtures: [(String, ImportError)] = [
            ("unsupported_encryption.xls", .unsupportedStatement(message: "Encrypted XLS workbooks are unsupported.")),
            ("multiple_worksheets.xls", .unsupportedStatement(message: "XLS workbooks must contain exactly one worksheet.")),
            ("hidden_worksheet.xls", .unsupportedStatement(message: "Hidden XLS worksheets are unsupported.")),
            ("formula_cell.xls", .unsupportedStatement(message: "Formula cells are unsupported in XLS imports.")),
            ("boolean_cell.xls", .unsupportedStatement(message: "Boolean and error cells are unsupported in XLS imports."))
        ]
        for (name, expected) in fixtures {
            let url = FixtureLocator.fixturesRoot
                .appendingPathComponent("LegacyXLS")
                .appendingPathComponent(name)
            await expectFailure(
                requestURL: url,
                bytes: try Data(contentsOf: url),
                expected: expected
            )
        }
    }

    @Test func readerRejectsNonXLSExtensionsBeforeOpeningSnapshot() async throws {
        let snapshot = SourceContentSnapshot(bytes: Data([0]))
        do {
            _ = try await LegacyXLSDocumentReader().read(
                request: ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/source.xlsx")),
                snapshot: snapshot,
                password: nil
            )
            Issue.record("Expected XLSX rejection.")
        } catch let error as ImportError {
            #expect(error == .unsupportedFile(extension: "xlsx"))
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func rejectedXLSPreparationsLeaveZeroAcceptedRepositoryResidue() async throws {
        let workspaceID = "workspace-rejected-axis-xls"
        let provider = DatabaseProvider(inMemory: true)
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: workspaceID,
                workspaceName: "Rejected Axis XLS"
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
        for name in [
            "unsupported_encryption.xls",
            "multiple_worksheets.xls",
            "hidden_worksheet.xls",
            "formula_cell.xls",
            "boolean_cell.xls"
        ] {
            let url = FixtureLocator.fixturesRoot
                .appendingPathComponent("LegacyXLS")
                .appendingPathComponent(name)
            do {
                let unexpected = try await engine.prepareImport(from: url)
                engine.cancelPreparedImport(unexpected)
                Issue.record("Expected \(name) to fail during preparation.")
            } catch {
                // Expected: the reader fails closed before confirmation exists.
            }
            #expect(try provider.workspaceRepo.workspace(id: workspaceID) == nil)
            #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
            #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspaceID).isEmpty)
        }
    }

    private func read(_ url: URL) async throws -> RawDocument {
        let snapshot = SourceContentSnapshot(bytes: try Data(contentsOf: url))
        defer { snapshot.invalidate() }
        return try await LegacyXLSDocumentReader().read(
            request: ImportRequest(fileURL: url),
            snapshot: snapshot,
            password: nil
        )
    }

    private func expectFailure(
        requestURL: URL,
        bytes: Data,
        expected: ImportError
    ) async {
        let snapshot = SourceContentSnapshot(bytes: bytes)
        defer { snapshot.invalidate() }
        do {
            _ = try await LegacyXLSDocumentReader().read(
                request: ImportRequest(fileURL: requestURL),
                snapshot: snapshot,
                password: nil
            )
            Issue.record("Expected XLS reader failure.")
        } catch let error as ImportError {
            #expect(error == expected)
        } catch {
            Issue.record("Expected bounded ImportError, got \(error).")
        }
    }

    private func expectInvalidDocument(requestURL: URL, bytes: Data) async {
        let snapshot = SourceContentSnapshot(bytes: bytes)
        defer { snapshot.invalidate() }
        do {
            _ = try await LegacyXLSDocumentReader().read(
                request: ImportRequest(fileURL: requestURL),
                snapshot: snapshot,
                password: nil
            )
            Issue.record("Expected invalid XLS rejection.")
        } catch let error as ImportError {
            guard case .invalidDocument = error else {
                Issue.record("Expected invalidDocument, got \(error).")
                return
            }
        } catch {
            Issue.record("Expected bounded ImportError, got \(error).")
        }
    }
}
