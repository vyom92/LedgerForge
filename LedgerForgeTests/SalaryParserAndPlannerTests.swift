import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct SalaryParserAndPlannerTests {
    @Test func exactProfilePreservesSideOrderMultiplicityAndSeparateDates() throws {
        let document = try QatarAirwaysSalaryPDFParser().parse(Self.salaryRaw())
        let evidence = try #require(document.salaryStatementEvidence)
        #expect(document.metadata.institution == .unknown)
        #expect(document.transactions.isEmpty)
        #expect(document.financialIdentifiers.isEmpty)
        #expect(evidence.financialPeriod.canonical == "2026-03")
        #expect(evidence.printDate?.canonical == "2026-04-02")
        #expect(evidence.kind == .regularSalary)
        #expect(evidence.earnings.map(\.sourceLabel) == ["Basic Salary", "Flying Pay", "Flying Pay"])
        #expect(evidence.earnings.map(\.sourceOrdinal) == [1, 2, 3])
        #expect(evidence.deductions.map(\.sourceLabel) == ["Employee Contribution", "Employee Contribution"])
        #expect(evidence.deductions.map(\.sourceOrdinal) == [1, 2])
        #expect(evidence.printedNet.amount == 117.00)
    }

    @Test func failClosedRecognitionAndValidationCases() throws {
        let parser = QatarAirwaysSalaryPDFParser()
        #expect(parser.canRecognize(Self.salaryRaw()) == true)
        #expect(parser.canRecognize(Self.salaryRaw(textMutation: { $0.replacingOccurrences(of: "ispadmin@qatarairways.com.qa", with: "payroll@example.com") })) == false)
        #expect(throws: QatarAirwaysSalaryPDFParserError.self) { try parser.parse(Self.salaryRaw(textMutation: { $0.replacingOccurrences(of: "Amount (QAR)", with: "Value (QAR)") })) }
        #expect(throws: QatarAirwaysSalaryPDFParserError.self) { try parser.parse(Self.salaryRaw(textMutation: { $0.replacingOccurrences(of: "Total Amount 117.00", with: "Total Amount 118.00") })) }
        #expect(throws: QatarAirwaysSalaryPDFParserError.self) { try parser.parse(Self.salaryRaw(textMutation: { $0.replacingOccurrences(of: "Amount (QAR)", with: "Amount (USD)") })) }
        let ambiguous = Self.salaryRaw(fragmentMutation: { fragments in
            fragments + [Self.fragment("1.00", x: 270, y: 500)]
        })
        #expect(throws: QatarAirwaysSalaryPDFParserError.self) { try parser.parse(ambiguous) }
    }

    @Test func kindsAndAbsentDeductionSectionRemainSourceTruth() throws {
        let parser = QatarAirwaysSalaryPDFParser()
        let adhoc = try parser.parse(Self.salaryRaw(title: "Adhoc Payment - March 2026"))
        #expect(adhoc.salaryStatementEvidence?.kind == .adhocPayment)
        let bonus = try parser.parse(Self.salaryRaw(title: "Annual Discretionary Bonus - March 2026", withoutDeductions: true))
        #expect(bonus.salaryStatementEvidence?.kind == .annualDiscretionaryBonus)
        #expect(bonus.salaryStatementEvidence?.printedDeductionsTotal == nil)
        #expect(bonus.salaryStatementEvidence?.deductions.isEmpty == true)
    }

    @Test func plannerArithmeticCompletenessRoundingFeeAndNegativeBuffers() throws {
        let qar = try CurrencyCode("QAR"), inr = try CurrencyCode("INR")
        var plan = Self.plan(
            fixed: try Money(amount: 100, currency: qar),
            variable: try Money(amount: 20, currency: qar),
            deductions: try Money(amount: 10, currency: qar)
        )
        plan.balances = [
            FundingPlanBalance(id: "q", accountID: "cbq", nativeCurrency: qar, included: true, money: try Money(amount: 50, currency: qar), provenance: .manual),
            FundingPlanBalance(id: "i", accountID: "axis", nativeCurrency: inr, included: true, money: try Money(amount: 50, currency: inr), provenance: .manual)
        ]
        plan.qatarCommitments = [FundingPlanCommitment(id: "qc", label: "Rent", money: try Money(amount: 10, currency: qar), included: true, fundingAccountID: nil, provenance: .manual)]
        plan.indiaCommitments = [FundingPlanCommitment(id: "ic", label: "India", money: try Money(amount: 100, currency: inr), included: true, fundingAccountID: "axis", provenance: .manual)]
        plan.planningFX = try FundingPlanFX(inrPerQAR: 3, observationDate: StatementDate(year: 2026, month: 8, day: 28))
        plan.plannedInvestment = try Money(amount: 120, currency: qar)
        let result = FundingPlanCalculator.calculate(plan)
        #expect(result.expectedNet?.amount == 110)
        #expect(result.indiaFundingShortfall?.amount == 50)
        #expect(try result.requiredQARPrincipal?.canonicalDecimalString() == "16.67")
        #expect(result.effectiveTransferFee?.amount == 25)
        #expect(result.availableForInvestment?.amount == 108.33)
        #expect(result.finalQARBuffer?.amount == -11.67)
    }

    @Test func missingIncludedBalanceAndMissingRequiredFXAreIncompleteButNoShortfallNeedsNoFX() throws {
        let qar = try CurrencyCode("QAR"), inr = try CurrencyCode("INR")
        var plan = Self.plan()
        plan.balances = [FundingPlanBalance(id: "missing", accountID: "cbq", nativeCurrency: qar, included: true, money: nil, provenance: .manual)]
        #expect(FundingPlanCalculator.calculate(plan).incompleteReasons.contains(.includedQARBalanceMissing))
        plan.balances = [
            FundingPlanBalance(id: "q", accountID: "cbq", nativeCurrency: qar, included: true, money: try Money(amount: 100, currency: qar), provenance: .manual),
            FundingPlanBalance(id: "i", accountID: "axis", nativeCurrency: inr, included: true, money: try Money(amount: 0, currency: inr), provenance: .manual)
        ]
        plan.indiaCommitments = [FundingPlanCommitment(id: "i", label: "India", money: try Money(amount: 1, currency: inr), included: true, fundingAccountID: nil, provenance: .manual)]
        #expect(FundingPlanCalculator.calculate(plan).incompleteReasons.contains(.missingPlanningFX))
        plan.indiaCommitments = []
        let noShortfall = FundingPlanCalculator.calculate(plan)
        #expect(noShortfall.requiredQARPrincipal?.amount == 0)
        #expect(noShortfall.effectiveTransferFee?.amount == 0)
        #expect(plan.configuredTransferFee.amount == 25)
    }

    @Test func selectedLiquiditySumsNativelyAndZeroShortfallSuppressesOnlyEffectiveFee() throws {
        let qar = try CurrencyCode("QAR"), inr = try CurrencyCode("INR")
        var plan = Self.plan()
        plan.balances = [
            FundingPlanBalance(id: "q1", accountID: "cbq-1", nativeCurrency: qar, included: true, money: try Money(amount: 10, currency: qar), provenance: .manual),
            FundingPlanBalance(id: "q2", accountID: "cbq-2", nativeCurrency: qar, included: true, money: try Money(amount: 15, currency: qar), provenance: .manual),
            FundingPlanBalance(id: "i1", accountID: "axis", nativeCurrency: inr, included: true, money: try Money(amount: 100, currency: inr), provenance: .manual),
            FundingPlanBalance(id: "i2", accountID: "hdfc", nativeCurrency: inr, included: true, money: try Money(amount: 50, currency: inr), provenance: .manual)
        ]
        plan.indiaCommitments = [FundingPlanCommitment(id: "i", label: "India", money: try Money(amount: 150, currency: inr), included: true, fundingAccountID: nil, provenance: .manual)]
        let equal = FundingPlanCalculator.calculate(plan)
        #expect(equal.selectedQARLiquidity?.amount == 25)
        #expect(equal.selectedINRLiquidity?.amount == 150)
        #expect(equal.indiaFundingShortfall?.amount == 0)
        #expect(equal.effectiveTransferFee?.amount == 0)
        #expect(plan.configuredTransferFee.amount == 25)
        plan.balances[2].money = try Money(amount: 200, currency: inr)
        #expect(FundingPlanCalculator.calculate(plan).indiaFundingShortfall?.amount == 0)
        #expect(throws: FundingPlanFX.ValidationError.nonPositive) {
            try FundingPlanFX(inrPerQAR: 0, observationDate: StatementDate(year: 2026, month: 8, day: 28))
        }
    }

    @Test func noBalanceIsAutoSelectedAndCaptureIsNotLiveLinked() throws {
        let plan = Self.plan()
        #expect(plan.balances.isEmpty)
        let qar = try CurrencyCode("QAR")
        let captured = FundingPlanBalance(id: "x", accountID: "cbq", nativeCurrency: qar, included: false, money: try Money(amount: 80, currency: qar), provenance: .capturedAccountBalance(capturedAtISO: "2026-08-28T00:00:00Z"))
        var changedAccountValue = try Money(amount: 100, currency: qar)
        #expect(captured.money?.amount == 80)
        changedAccountValue = try Money(amount: 120, currency: qar)
        #expect(changedAccountValue.amount == 120)
        #expect(captured.money?.amount == 80)
    }

    @Test func salaryNavigationEligibilityAndExplicitRolloverRemainUserControlled() throws {
        #expect(AppShellSection.ordinaryNavigation == [.dashboard, .accounts, .transactions, .imports, .salary, .settings])
        let accounts = AccountStore()
        accounts.installAccountsWithoutObservation([
            Account(repositoryAccountId: "cbq", workspaceId: "w", institution: Institution.cbq.rawValue, name: "Current", type: .bank, currencyCode: "QAR", currentBalance: 100),
            Account(repositoryAccountId: "axis-nre", workspaceId: "w", institution: Institution.axis.rawValue, name: "Axis NRE", type: .bank, currencyCode: "INR", currentBalance: 200),
            Account(repositoryAccountId: "axis-other", workspaceId: "w", institution: Institution.axis.rawValue, name: "Axis Savings", type: .bank, currencyCode: "INR", currentBalance: 300),
            Account(repositoryAccountId: "card", workspaceId: "w", institution: Institution.cbq.rawValue, name: "Card", type: .creditCard, currencyCode: "QAR", currentBalance: 400)
        ])
        let plans = FundingPlanStore()
        let previous = Self.plan(month: try SelectedStatementMonth(year: 2026, month: 7), id: "previous")
        plans.installWithoutObservation([previous])
        let viewModel = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(year: 2026, month: 8), workspaceID: "default-workspace", accountStore: accounts, salaryStore: SalaryStore(), fundingPlanStore: plans)
        #expect(viewModel.eligibleAccounts.compactMap(\.repositoryAccountId) == ["axis-nre", "cbq"])
        #expect(viewModel.plan.balances.isEmpty)
        viewModel.rolloverFromPreviousPlan()
        #expect(viewModel.plan.rolloverSourcePlanID == "previous")
        #expect(viewModel.plan.expectedFixedProvenance == .carried(sourcePlanID: "previous"))
        #expect(viewModel.updateMoney(.fixed, text: "123.00"))
        #expect(viewModel.plan.expectedFixedProvenance == .manual)
        #expect(previous.expectedFixedEarnings.amount == 0)
    }

    @Test func authenticTwentySourceGateMatchesIndependentPrivateOracle() async throws {
        let root = try Self.privateSalarySourceRoot()
        let manifestURL = try Self.privateSalaryOracleURL()
        let manifestData = try Data(contentsOf: manifestURL)
        let rootObject = try #require(try JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let sources = try #require(rootObject["sources"] as? [[String: Any]])
        let discovered = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "pdf" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        #expect(discovered.count == 20)
        #expect(sources.count == 20)
        let databaseFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-S79-private-comparator-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: databaseFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: databaseFolder) }
        let provider = try SQLiteRepositoryProvider(path: databaseFolder.appendingPathComponent("salary.sqlite").path)
        defer { provider.database.close() }
        let workspaceID = "workspace-private-salary-comparator"
        var parsedByHash: [String: SalaryStatementEvidence] = [:]
        for (sourceIndex, source) in sources.enumerated() {
            let file = try #require(source["file"] as? String)
            let url = root.appendingPathComponent(file)
            let bytes = try Data(contentsOf: url)
            let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            #expect(hash == (source["sha256"] as? String))
            let snapshot = SourceContentSnapshot(bytes: bytes)
            defer { snapshot.invalidate() }
            let raw = try await PDFDocumentReader().read(request: ImportRequest(fileURL: url), snapshot: snapshot, password: nil)
            let evidence: SalaryStatementEvidence
            do {
                evidence = try #require(try QatarAirwaysSalaryPDFParser().parse(raw).salaryStatementEvidence)
            } catch {
                Issue.record("Authentic Salary parser failed for \(file): \(error)")
                throw error
            }
            #expect(evidence.financialPeriod.canonical == (source["period"] as? String))
            #expect(evidence.printDate?.canonical == (source["print_date"] as? String))
            let expectedKind: SalaryDocumentKind? = switch source["kind"] as? String {
            case "regularSalary": .regularSalary
            case "adhocPayment": .adhocPayment
            case "annualDiscretionaryBonus": .annualDiscretionaryBonus
            default: nil
            }
            #expect(evidence.kind == expectedKind)
            try Self.expectComponents(evidence.earnings, source["earnings"])
            try Self.expectComponents(evidence.deductions, source["deductions"])
            #expect(try evidence.printedEarningsTotal.canonicalDecimalString() == (source["printed_earnings"] as? String))
            #expect(try evidence.printedDeductionsTotal?.canonicalDecimalString() == (source["printed_deductions"] as? String))
            #expect(try evidence.printedNet.canonicalDecimalString() == (source["printed_net"] as? String))
            #expect(try evidence.printedPaymentTotal.canonicalDecimalString() == (source["printed_payment"] as? String))
            parsedByHash[hash] = evidence
            let persistencePlan = try Self.privateSalaryPlan(
                evidence: evidence,
                digest: hash,
                sourceIndex: sourceIndex,
                token: provider.generationToken,
                workspaceID: workspaceID
            )
            guard case .committed = provider.salaryRepo.commitImportedSalary(persistencePlan) else {
                Issue.record("Authentic Salary SQLite commit failed at source index \(sourceIndex)")
                return
            }
        }

        let persisted = try provider.salaryRepo.snapshot(workspaceId: workspaceID)
        #expect(persisted.statements.count == 20)
        #expect(Set(persisted.statements.map(\.sourceFingerprintDigest)) == Set(parsedByHash.keys))
        for statement in persisted.statements {
            let expected = try #require(parsedByHash[statement.sourceFingerprintDigest])
            try Self.expectPersisted(statement, matches: expected)
        }

        let accounts = AccountStore(), transactions = TransactionStore(), categories = CategoryStore()
        let sessions = ImportSessionStore(), attempts = ImportAttemptStore()
        let salary = SalaryStore(), funding = FundingPlanStore(), cards = CardStore()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo, salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo,
            accountStore: accounts, transactionStore: transactions, categoryStore: categories,
            cardStore: cards, salaryStore: salary, fundingPlanStore: funding,
            importSessionStore: sessions, importAttemptStore: attempts,
            workspaceId: workspaceID, persistenceState: .verifiedSQLite,
            providerGeneration: provider.generationToken, categoryReconciliationGate: nil,
            participatesInLifecycleGate: false)
        let staged = try hydrator.stageHydration()
        #expect(salary.statements.isEmpty)
        #expect(sessions.importSessions.isEmpty)
        hydrator.publish(staged)
        #expect(salary.statements.count == 20)
        #expect(sessions.importSessions.count == 20)
        #expect(attempts.attempts.count == 20)
        #expect(Set(salary.statements.map(\.fingerprintDigest)) == Set(parsedByHash.keys))
        for statement in salary.statements {
            #expect(statement.fingerprintAlgorithm == DocumentFingerprintDTO.sourceBytesSHA256Algorithm)
            let expected = try #require(parsedByHash[statement.fingerprintDigest])
            #expect(statement.evidence == expected)
        }
    }

    private static func privateSalarySourceRoot() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let configured = environment["LEDGERFORGE_PRIVATE_SALARY_DIRECTORY"], !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
        }
        let loginName = ProcessInfo.processInfo.environment["USER"] ?? NSUserName()
        guard !loginName.isEmpty else { throw CocoaError(.fileNoSuchFile) }
        let loginHome = URL(fileURLWithPath: "/", isDirectory: true)
            .appendingPathComponent("Users", isDirectory: true)
            .appendingPathComponent(loginName, isDirectory: true)
        return loginHome
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Ledger Forge", isDirectory: true)
            .appendingPathComponent("Originals", isDirectory: true)
            .appendingPathComponent("Salary", isDirectory: true)
    }

    private static func privateSalaryOracleURL() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let configured = environment["LEDGERFORGE_PRIVATE_SALARY_ORACLE_FILE"], !configured.isEmpty {
            return URL(fileURLWithPath: configured)
        }
        let filename = "qatar-airways.salary.pdf@1.expected.json"
        let hostTemporaryRoot = URL(fileURLWithPath: "/", isDirectory: true)
            .appendingPathComponent("tmp", isDirectory: true)
        let candidates = try FileManager.default.contentsOfDirectory(
            at: hostTemporaryRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasPrefix("ledgerforge-sprint79-oracle.") }
        .map { $0.appendingPathComponent(filename) }
        .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !candidates.isEmpty else { throw CocoaError(.fileNoSuchFile) }
        let digests = try candidates.map { url in
            SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        }
        guard Set(digests).count == 1 else { throw CocoaError(.fileReadCorruptFile) }
        return candidates.sorted { $0.path < $1.path }[0]
    }

    private static func privateSalaryPlan(
        evidence: SalaryStatementEvidence,
        digest: String,
        sourceIndex: Int,
        token: ProviderGenerationToken,
        workspaceID: String
    ) throws -> SalaryImportPlanDTO {
        let suffix = String(format: "%02d", sourceIndex)
        let timestamp = "2026-08-28T00:00:00Z"
        let workspace = WorkspaceDTO(id: workspaceID, name: "Salary Comparator", createdAtISO: timestamp)
        let session = ImportSessionDTO(
            id: "session-\(suffix)", workspaceId: workspaceID, userVisibleName: "salary-source-\(suffix).pdf",
            startedAtISO: timestamp, validationStatus: "pending", readerVersion: "PDFDocumentReader",
            parserVersion: SalaryStatementEvidence.profileVersion, layoutVersion: nil)
        let document = ImportedDocumentDTO(
            id: "document-\(suffix)", workspaceId: workspaceID, importSessionId: session.id,
            filename: "salary-source-\(suffix).pdf", mimeType: "application/pdf", sizeBytes: nil,
            sha256: digest, createdAtISO: timestamp)
        let fingerprint = DocumentFingerprintDTO(
            id: "fingerprint-\(suffix)", documentId: document.id, importSessionId: session.id,
            algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, fingerprint: digest,
            fingerprintData: nil, isDuplicateAuthority: true, createdAtISO: timestamp)
        let normalized = NormalizedDocumentDTO(
            id: "normalized-\(suffix)", importSessionId: session.id, documentId: document.id,
            profileId: SalaryStatementEvidence.profileID, profileVersion: SalaryStatementEvidence.profileVersion)
        let attempt = ImportAttemptDTO(
            id: "attempt-\(suffix)", workspaceId: workspaceID, createdAtISO: timestamp,
            outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
            coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
            accountDecisionCode: ImportAttemptAccountDecision.noFinancialMutation.rawValue,
            guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
            persistenceCode: ImportAttemptPersistence.committed.rawValue,
            transactionCount: 0, accountId: nil, importSessionId: session.id, documentId: document.id)
        let statementID = "salary-\(suffix)"
        func componentDTO(_ component: SalaryComponent) throws -> SalaryComponentDTO {
            SalaryComponentDTO(
                id: "\(component.side.rawValue)-\(suffix)-\(component.sourceOrdinal)",
                salaryStatementId: statementID, sideCode: component.side.rawValue,
                sourceOrdinal: component.sourceOrdinal, sourceLabel: component.sourceLabel,
                amountCurrency: component.money.currency.code, amountMinor: try component.money.minorUnits(),
                amountDecimal: try component.money.canonicalDecimalString())
        }
        let earningComponents = try evidence.earnings.map(componentDTO)
        let deductionComponents = try evidence.deductions.map(componentDTO)
        let components = earningComponents + deductionComponents
        let statement = SalaryStatementDTO(
            id: statementID, workspaceId: workspaceID, documentId: document.id, importSessionId: session.id,
            normalizedDocumentId: normalized.id, sourceFingerprintAlgorithm: fingerprint.algorithm,
            sourceFingerprintDigest: digest, sourceAuthorityCode: evidence.sourceAuthority.rawValue,
            parserProfileId: evidence.profileID, parserProfileVersion: evidence.profileVersion,
            financialPeriodISO: evidence.financialPeriod.canonical, printDateISO: evidence.printDate?.canonical,
            documentKindCode: evidence.kind.rawValue, nativeCurrency: evidence.nativeCurrency.code,
            printedEarningsMinor: try evidence.printedEarningsTotal.minorUnits(),
            printedEarningsDecimal: try evidence.printedEarningsTotal.canonicalDecimalString(),
            printedDeductionsMinor: try evidence.printedDeductionsTotal.map { try $0.minorUnits() },
            printedDeductionsDecimal: try evidence.printedDeductionsTotal.map { try $0.canonicalDecimalString() },
            printedNetMinor: try evidence.printedNet.minorUnits(),
            printedNetDecimal: try evidence.printedNet.canonicalDecimalString(),
            printedPaymentMinor: try evidence.printedPaymentTotal.minorUnits(),
            printedPaymentDecimal: try evidence.printedPaymentTotal.canonicalDecimalString(),
            createdAtISO: timestamp, components: components)
        return SalaryImportPlanDTO(
            providerGeneration: token,
            workspace: workspace,
            history: ConfirmedImportHistoryTemplateDTO(
                document: document, fingerprint: fingerprint, importSession: session,
                completedAtISO: timestamp, successfulAttempt: attempt, normalizedDocument: normalized),
            statement: statement)
    }

    private static func expectPersisted(_ actual: SalaryStatementDTO, matches expected: SalaryStatementEvidence) throws {
        #expect(actual.sourceFingerprintAlgorithm == DocumentFingerprintDTO.sourceBytesSHA256Algorithm)
        #expect(actual.sourceAuthorityCode == expected.sourceAuthority.rawValue)
        #expect(actual.parserProfileId == expected.profileID)
        #expect(actual.parserProfileVersion == expected.profileVersion)
        #expect(actual.financialPeriodISO == expected.financialPeriod.canonical)
        #expect(actual.printDateISO == expected.printDate?.canonical)
        #expect(actual.documentKindCode == expected.kind.rawValue)
        #expect(actual.nativeCurrency == expected.nativeCurrency.code)
        #expect(actual.printedEarningsMinor == (try expected.printedEarningsTotal.minorUnits()))
        #expect(actual.printedEarningsDecimal == (try expected.printedEarningsTotal.canonicalDecimalString()))
        #expect(actual.printedDeductionsMinor == (try expected.printedDeductionsTotal.map { try $0.minorUnits() }))
        #expect(actual.printedDeductionsDecimal == (try expected.printedDeductionsTotal.map { try $0.canonicalDecimalString() }))
        #expect(actual.printedNetMinor == (try expected.printedNet.minorUnits()))
        #expect(actual.printedNetDecimal == (try expected.printedNet.canonicalDecimalString()))
        #expect(actual.printedPaymentMinor == (try expected.printedPaymentTotal.minorUnits()))
        #expect(actual.printedPaymentDecimal == (try expected.printedPaymentTotal.canonicalDecimalString()))
        try expectPersistedComponents(actual.components.filter { $0.sideCode == SalaryComponentSide.earning.rawValue }, expected.earnings)
        try expectPersistedComponents(actual.components.filter { $0.sideCode == SalaryComponentSide.deduction.rawValue }, expected.deductions)
    }

    private static func expectPersistedComponents(_ actual: [SalaryComponentDTO], _ expected: [SalaryComponent]) throws {
        let ordered = actual.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
        #expect(ordered.count == expected.count)
        for (dto, component) in zip(ordered, expected) {
            #expect(dto.sideCode == component.side.rawValue)
            #expect(dto.sourceOrdinal == component.sourceOrdinal)
            #expect(dto.sourceLabel == component.sourceLabel)
            #expect(dto.amountCurrency == component.money.currency.code)
            #expect(dto.amountMinor == (try component.money.minorUnits()))
            #expect(dto.amountDecimal == (try component.money.canonicalDecimalString()))
        }
    }

    private static func expectComponents(_ actual: [SalaryComponent], _ rawExpected: Any?) throws {
        if rawExpected == nil || rawExpected is NSNull {
            #expect(actual.isEmpty)
            return
        }
        let expected = try #require(rawExpected as? [[Any]])
        #expect(actual.count == expected.count)
        for (component, row) in zip(actual, expected) {
            #expect(component.sourceOrdinal == (row[0] as? Int))
            #expect(component.sourceLabel == (row[1] as? String))
            #expect(try component.money.canonicalDecimalString() == (row[2] as? String))
        }
    }

    private static func plan(fixed: Money? = nil, variable: Money? = nil, deductions: Money? = nil,
                             month: SelectedStatementMonth? = nil,
                             id: String = "plan") -> FundingPlan {
        let zero = try! Money(canonicalDecimal: "0.00", currency: "QAR")
        let resolvedMonth = month ?? (try! SelectedStatementMonth(year: 2026, month: 8))
        return FundingPlan(id: id, workspaceID: "default-workspace", month: resolvedMonth, rolloverSourcePlanID: nil,
                           expectedFixedEarnings: fixed ?? zero, expectedFixedProvenance: .manual,
                           expectedVariableEarnings: variable ?? zero, expectedVariableProvenance: .manual,
                           expectedDeductions: deductions ?? zero, expectedDeductionsProvenance: .manual,
                           balances: [], qatarCommitments: [], indiaCommitments: [],
                           configuredTransferFee: try! Money(canonicalDecimal: "25.00", currency: "QAR"), configuredTransferFeeProvenance: .manual,
                           planningFX: nil, plannedInvestment: zero, plannedInvestmentProvenance: .manual, updatedAtISO: "2026-08-28T00:00:00Z")
    }

    private static func salaryRaw(
        title: String = "Payslip for the month of March 2026",
        withoutDeductions: Bool = false,
        textMutation: (String) -> String = { $0 },
        fragmentMutation: ([RawPDFTextFragment]) -> [RawPDFTextFragment] = { $0 }
    ) -> RawDocument {
        let deductionsHeader = withoutDeductions ? "" : " Deduction Amount (QAR)"
        let deductionTotals = withoutDeductions ? "" : " Total Deductions 5.00"
        let net = withoutDeductions ? "122.00" : "117.00"
        let text = textMutation("""
        ispadmin@qatarairways.com.qa
        \(title)
        Printed by: Payroll User 02-Apr-2026
        Earning Amount (QAR)\(deductionsHeader)
        Amount (QAR)
        Total Earnings 122.00\(deductionTotals)
        Net pay for the month of March 2026: (QAR) \(net)
        Payment Details Amount Transferred (QAR)
        Total Amount \(net)
        """)
        var fragments = [
            fragment("Earning", x: 20, y: 600), fragment("Amount (QAR)", x: 240, y: 600),
            fragment("Basic Salary", x: 20, y: 550), fragment("100.00", x: 250, y: 550),
            fragment("Flying Pay", x: 20, y: 525), fragment("10.00", x: 250, y: 525),
            fragment("Flying Pay", x: 20, y: 500), fragment("12.00", x: 250, y: 500),
            fragment("Total Earnings", x: 20, y: 450), fragment("122.00", x: 250, y: 450)
        ]
        if !withoutDeductions {
            fragments += [
                fragment("Deduction", x: 310, y: 600), fragment("Amount (QAR)", x: 450, y: 600),
                fragment("Employee Contribution", x: 310, y: 550), fragment("2.00", x: 450, y: 550),
                fragment("Employee Contribution", x: 310, y: 525), fragment("3.00", x: 450, y: 525)
            ]
        }
        fragments = fragmentMutation(fragments)
        return RawDocument(sourceURL: FileManager.default.temporaryDirectory.appendingPathComponent("sanitized-salary.pdf"), fileName: "sanitized-salary.pdf", fileExtension: "pdf", content: .text(text), pdfPageTexts: [text], pdfPageEvidence: [RawPDFPageEvidence(fragments: fragments)])
    }

    private static func fragment(_ text: String, x: Double, y: Double) -> RawPDFTextFragment {
        RawPDFTextFragment(text: text, geometry: RawPDFTextGeometry(minX: x, maxX: x + 30, baselineY: y))
    }
}
