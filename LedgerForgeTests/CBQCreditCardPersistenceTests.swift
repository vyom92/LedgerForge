import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct CBQCreditCardPersistenceTests {
    @Test(.globalRuntimeStateIsolation)
    func sourceByteCardGraphIsAtomicObservableAndHydratableInBothProviders() throws {
        try verifyPersistence(inMemory: true)
        try verifyPersistence(inMemory: false)
    }

    private func verifyPersistence(inMemory: Bool) throws {
        let workspaceID = "cbq-card-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-CBQ-Card-\(UUID().uuidString)", isDirectory: true)
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

        let document = try syntheticDocument()
        let validation = ImportValidator.validate(financialDocument: document)
        #expect(validation.passed)
        let session = ImportSession(
            fileName: document.sourceDocument.filename,
            institution: .cbq,
            documentType: .creditCard,
            parserName: "CBQ Credit Card PDF",
            transactionCount: document.transactions.count,
            validation: validation
        )
        let fingerprints = fingerprintSet(label: "accepted")
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "CBQ card acceptance")
        )
        let result = try coordinator.persistValidatedImport(
            financialDocument: document,
            importSession: session,
            validation: validation,
            fingerprintSet: fingerprints,
            accountChoice: .createNewCardLiabilityAccountAndInstrument,
            providerGeneration: provider.generationToken
        )
        #expect(result.persisted)
        #expect(result.transactionCount == 4)
        try verifyGraph(
            provider: provider,
            workspaceID: workspaceID,
            transactionCount: 4,
            statementCount: 1,
            sectionCount: 2,
            expectedLiabilityBalance: try Money(amount: -92, currency: "QAR")
        )

        let duplicateSession = ImportSession(
            fileName: document.sourceDocument.filename,
            institution: .cbq,
            documentType: .creditCard,
            parserName: "CBQ Credit Card PDF",
            transactionCount: document.transactions.count,
            validation: validation
        )
        let duplicate = try coordinator.persistValidatedImport(
            financialDocument: document,
            importSession: duplicateSession,
            validation: validation,
            fingerprintSet: fingerprints,
            accountChoice: .createNewCardLiabilityAccountAndInstrument,
            providerGeneration: provider.generationToken
        )
        #expect(!duplicate.persisted)
        try verifyGraph(
            provider: provider,
            workspaceID: workspaceID,
            transactionCount: 4,
            statementCount: 1,
            sectionCount: 2,
            expectedLiabilityBalance: try Money(amount: -92, currency: "QAR")
        )

        let secondDocument = try syntheticDocument(
            month: "12",
            statementDay: "31",
            dueDate: "15/01/26",
            previousBalance: "92.00",
            currentBalance: "84.00"
        )
        let secondValidation = ImportValidator.validate(financialDocument: secondDocument)
        #expect(secondValidation.passed)
        let secondSession = ImportSession(
            fileName: secondDocument.sourceDocument.filename,
            institution: .cbq,
            documentType: .creditCard,
            parserName: "CBQ Credit Card PDF",
            transactionCount: secondDocument.transactions.count,
            validation: secondValidation
        )
        let second = try coordinator.persistValidatedImport(
            financialDocument: secondDocument,
            importSession: secondSession,
            validation: secondValidation,
            fingerprintSet: fingerprintSet(label: "second"),
            accountChoice: nil,
            providerGeneration: provider.generationToken
        )
        #expect(second.persisted)
        #expect(second.accountId == result.accountId)
        #expect(second.transactionCount == 4)
        try verifyGraph(
            provider: provider,
            workspaceID: workspaceID,
            transactionCount: 8,
            statementCount: 2,
            sectionCount: 4,
            expectedLiabilityBalance: try Money(amount: -84, currency: "QAR")
        )

        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
            let reopened = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
            try verifyGraph(
                provider: reopened,
                workspaceID: workspaceID,
                transactionCount: 8,
                statementCount: 2,
                sectionCount: 4,
                expectedLiabilityBalance: try Money(amount: -84, currency: "QAR")
            )
            try reopenedSQLite.database.checkpointAndClose()
        }
    }

    private func verifyGraph(
        provider: DatabaseProvider,
        workspaceID: String,
        transactionCount: Int,
        statementCount: Int,
        sectionCount: Int,
        expectedLiabilityBalance: Money
    ) throws {
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == transactionCount)
        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == 2)
        #expect(card.instruments.allSatisfy { $0.lifecycleStateCode == CardInstrumentLifecycleState.unknown.rawValue })
        #expect(card.relationships.isEmpty)
        #expect(card.statements.count == statementCount)
        #expect(card.sections.count == sectionCount)
        #expect(card.sectionObservations.count == sectionCount)
        #expect(card.transactionEvidence.count == transactionCount)
        #expect(card.transactionEvidence.allSatisfy { $0.summaryMembershipCode != nil })
        #expect(card.transactionEvidence.contains {
            $0.rowScopeCode == CardTransactionScope.accountLevel.persistenceCode &&
                $0.documentScopedSectionId != nil && $0.instrumentId == nil
        })
        #expect(card.semanticGroups.isEmpty)
        #expect(card.semanticProjections.isEmpty)
        #expect(card.semanticMembers.isEmpty)

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
        #expect(hydrated.accounts.first?.currentBalanceMoney == expectedLiabilityBalance)
        #expect(hydrated.transactions.count == transactionCount)
        #expect(hydrated.cardSnapshot.instruments.count == 2)
        #expect(hydrated.cardSnapshot.statements.count == statementCount)
        #expect(hydrated.cardSnapshot.transactionEvidence.count == transactionCount)
    }

    private func syntheticDocument(
        month: String = "11",
        statementDay: String = "30",
        dueDate: String = "15/12/25",
        previousBalance: String = "100.00",
        currentBalance: String = "92.00"
    ) throws -> FinancialDocument {
        let pages = [
            """
            Card Account Reference
            470012345678901
            Statement Date \(statementDay)/\(month)/25
            Statement Period 01/\(month)/25 to \(statementDay)/\(month)/25
            Payment Due Date \(dueDate)
            Previous Outstanding Balance \(previousBalance)\n            Amount Billed 12.00\n            Payment Received CR 20.00\n            Current Outstanding Balance \(currentBalance)
            Diners Club
            Card Number Card Holder Name Product Card Limit
            1234XXXXXXXX5678 FICTIONAL HOLDER Diners Club FICTIONAL PRODUCT 5000.00
            Post Date Purchase
            Date Description & Referance Foreign Currency Amount in QAR
            02/\(month)/25 01/\(month)/25 Paid using bankDirect CR 20.00
            04/\(month)/25 03/\(month)/25 FICTIONAL PURCHASE ONE 5.00
            05/\(month)/25 04/\(month)/25 continuation narration
            Continued on next page...
            """,
            """
            Diners Club
            Card Number Card Holder Name Product Card Limit
            1234XXXXXXXX5678 FICTIONAL HOLDER Diners Club FICTIONAL PRODUCT 5000.00
            Post Date Purchase
            Date Description & Referance Foreign Currency Amount in QAR
            06/\(month)/25 05/\(month)/25 FICTIONAL PURCHASE TWO 4.00
            DINERS-TOTAL CR 11.00
            Mastercard Platinum
            Card Number Card Holder Name Product Card Limit
            4321XXXXXXXX8765 FICTIONAL HOLDER Mastercard Platinum FICTIONAL PRODUCT 7000.00
            08/\(month)/25 07/\(month)/25 CASH ADVANCE FEE 3.00
            MASTERCARD-TOTAL 3.00
            XXXX End of Statement
            """,
            fictionalCBQApprovedTail(version: "v1")
        ]
        let normalized = try CBQCreditCardPDFNormalizer().normalize(
            text: pages.joined(separator: "\n"),
            pageTexts: pages,
            fileURL: URL(fileURLWithPath: "/tmp/fictional-cbq-card.pdf")
        )
        return try CBQCreditCardPDFParser().parse(document: NormalizedDocument(
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
    }

    private func fingerprintSet(label: String) -> PreparedDocumentFingerprintSet {
        func digest(_ value: String) -> String {
            SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
        }
        return PreparedDocumentFingerprintSet(fingerprints: [
            VersionedDocumentFingerprint(
                algorithm: ExactStatementFingerprint.algorithm,
                digest: digest("raw-\(label)"),
                byteCount: Int64(label.utf8.count),
                isDuplicateAuthority: false
            ),
            VersionedDocumentFingerprint(
                algorithm: SourceContentSnapshot.algorithm,
                digest: digest("source-\(label)"),
                byteCount: Int64(label.utf8.count),
                isDuplicateAuthority: true
            )
        ])
    }
}
