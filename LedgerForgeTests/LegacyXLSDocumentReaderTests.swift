import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct LegacyXLSDocumentReaderTests {
    @Test func readerSupportsExactlyXLS() {
        #expect(LegacyXLSDocumentReader().supportedFileExtensions == ["xls"])
    }

    @Test func readerRejectsInvalidAndTruncatedOLE2() async throws {
        let invalidURL = URL(fileURLWithPath: "/tmp/invalid.xls")
        await expectFailure(
            requestURL: invalidURL,
            bytes: Data("not an OLE container".utf8),
            expected: .invalidDocument(message: "XLS workbook is malformed or unsupported.")
        )

        let source = try Data(contentsOf: FixtureLocator.fixturesRoot.appendingPathComponent("LegacyXLS/formula_cell.xls"))
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
        let workspaceID = "workspace-rejected-generic-xls"
        let provider = DatabaseProvider(inMemory: true)
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: workspaceID,
                workspaceName: "Rejected Generic XLS"
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
