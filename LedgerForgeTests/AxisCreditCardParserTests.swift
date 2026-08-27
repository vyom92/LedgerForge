import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisCreditCardParserTests {
    @Test func exactPDFRowsPreserveDateAndLiabilityDirection() throws {
        let text = """
        AXIS CREDIT CARD STATEMENT
        Credit Card Number: 4111 XXXX XXXX 0001
        Selected Statement Month: Jun 2026
        Opening Balance INR1,000.00
        Credit Limit INR2,000.00
        Total Payment Due INR1,100.00
        Minimum Payment Due INR100.00
        Payment Due Date 08 Jul '26
        Date Transaction Details Amount (INR) Debit/Credit
        """
        let tagged = Self.taggedTransactionTable(rows: [
            ["31 May '26", "Prior purchase", "INR50.00", "Debit"],
            ["02 Jun '26", "Purchase", "INR100.00", "Debit"],
            ["03 Jun '26", "Refund", "INR50.00", "Credit"]
        ])
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: text, pageTexts: [text], taggedTables: [tagged],
            fileURL: URL(fileURLWithPath: "/tmp/axis.pdf")
        )
        let metadata = DocumentMetadata(institution: .axis, documentType: .creditCard, fileFormat: .pdf, confidence: 1)
        let document = try AxisCreditCardPDFParser().parse(document: NormalizedDocument(
            document: normalized.document, metadata: metadata, rows: normalized.rows,
            header: normalized.header, sourceContext: normalized.sourceContext
        ))
        #expect(document.transactions.count == 3)
        #expect(document.transactions[0].financialDateRole == .transactionDate)
        #expect(document.transactions[0].money.amount == 50)
        #expect(document.transactions[2].money.amount == -50)
        #expect(document.cardStatementEvidence?.reconciliationRuleIdentifier == CardStatementEvidence.axisINRRowLedgerReconciliationRule)
        #expect(normalized.presentation == .appPDF)
    }

    @Test func appPDFActiveLoansTableIsExcludedByLogicalHeader() throws {
        let text = """
        AXIS CREDIT CARD STATEMENT
        Credit Card Number: 4111 XXXX XXXX 0001
        Selected Statement Month: Jun 2026
        Opening Balance INR1,000.00
        Credit Limit INR2,000.00
        Total Payment Due INR1,100.00
        Minimum Payment Due INR100.00
        Payment Due Date 08 Jul '26
        Date Transaction Details Amount (INR) Debit/Credit
        Active Loans Summary
        """
        let transactionTable = Self.taggedTransactionTable(rows: [
            ["02 Jun '26", "Purchase", "INR100.00", "Debit"]
        ])
        let loansTable = Self.taggedTable(
            header: ["Active Loans Summary", "Loan Details", "Amount", "Status"],
            rows: [["03 Jun '26", "Loan-shaped row", "INR50.00", "Debit"]]
        )
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: text, pageTexts: [text], taggedTables: [transactionTable, loansTable],
            fileURL: URL(fileURLWithPath: "/tmp/axis-app.pdf")
        )
        #expect(normalized.rows.count == 1)
        #expect(normalized.rows[0].values[1] == "Purchase")
        #expect(normalized.presentation == .appPDF)
    }

    @Test func appTaggedHeaderOwnsLayoutWhenVisualTextIsLetterSpaced() throws {
        let text = Self.appPDFText
            .replacingOccurrences(of: "AXIS CREDIT CARD", with: "AXIS C R E D I T C A R D")
            .replacingOccurrences(
                of: "Credit Card Number",
                with: "C r e d i t C a r d N u m b e r"
            )
            .replacingOccurrences(
                of: "Date Transaction Details Amount (INR) Debit/Credit",
                with: "Date\nTransaction Details\nAmount (INR)\nDebit/Credit"
            )
        let tagged = Self.taggedTransactionTable(rows: [
            ["02 Jun '26", "Purchase", "INR100.00", "Debit"]
        ])

        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: text,
            pageTexts: [text],
            taggedTables: [tagged],
            fileURL: URL(fileURLWithPath: "/tmp/axis-app-letter-spaced.pdf")
        )

        #expect(normalized.rows.count == 1)
        #expect(normalized.rows[0].values[1] == "Purchase")
        #expect(normalized.presentation == .appPDF)
        let parsed = try AxisCreditCardPDFParser().parse(document: NormalizedDocument(
            document: normalized.document,
            metadata: DocumentMetadata(
                institution: .axis,
                documentType: .creditCard,
                fileFormat: .pdf,
                confidence: 1
            ),
            rows: normalized.rows,
            header: normalized.header,
            sourceContext: normalized.sourceContext
        ))
        #expect(parsed.cardStatementEvidence?.accountSourceIdentityObservations.isEmpty == true)
    }

    @Test func traditionalPDFActiveLoansBoundaryExcludesLoanShapedRows() throws {
        let base = Self.traditionalSummaryPageEvidence()
        let transaction = Self.traditionalTransactionFragments(
            y: 430,
            description: ["Fictional", "Purchase"],
            category: "Retail",
            amountFragments: ["100.00", "Debit"]
        )
        let activeLoansHeader: [RawPDFTextFragment] = [
            Self.rectangular("Active Loans Summary", x: 140, y: 410)
        ]
        let loanShapedRow = Self.traditionalTransactionFragments(
            y: 390,
            description: ["Excluded", "Loan"],
            category: "Loan",
            amountFragments: ["500.00", "Debit"]
        )
        let evidence = RawPDFPageEvidence(
            fragments: base.fragments.filter { $0.y != 430 } +
                transaction + activeLoansHeader + loanShapedRow
        )

        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: Self.traditionalGeometryText,
            pageTexts: [Self.traditionalGeometryText],
            pageEvidence: [evidence],
            fileURL: URL(fileURLWithPath: "/tmp/traditional-active-loans-boundary.pdf")
        )

        #expect(normalized.rows.count == 1)
        #expect(normalized.rows.first?.values[1] == "Fictional Purchase")
        #expect(normalized.presentation == .traditionalPDF)
    }

    @Test func appPDFMultilineDetailsRemainOneLogicalTransaction() throws {
        let text = Self.appPDFText
        let tagged = Self.taggedTransactionTable(
            rows: [["02 Jun '26", "ignored", "INR100.00", "Debit"]],
            detailBlocks: [0: ["First detail block", "second detail block"]]
        )
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: text, pageTexts: [text], taggedTables: [tagged],
            fileURL: URL(fileURLWithPath: "/tmp/axis-app.pdf")
        )
        #expect(normalized.rows.count == 1)
        #expect(normalized.rows[0].values[1] == "First detail block second detail block")
    }

    @Test func appPDFMissingOrAmbiguousTaggedEvidenceFailsClosed() throws {
        let text = Self.appPDFText
        do {
            _ = try AxisCreditCardPDFNormalizer().normalize(
                text: text, pageTexts: [text], taggedTables: nil,
                fileURL: URL(fileURLWithPath: "/tmp/axis-app.pdf")
            )
            Issue.record("Expected missing tagged transaction evidence to fail closed.")
        } catch let error as AxisCreditCardPDFNormalizationError {
            guard case .malformedTaggedTable = error else {
                Issue.record("Expected malformedTaggedTable, got \(error).")
                return
            }
        }

        let table = Self.taggedTransactionTable(rows: [["02 Jun '26", "Purchase", "INR100.00", "Debit"]])
        do {
            _ = try AxisCreditCardPDFNormalizer().normalize(
                text: text, pageTexts: [text], taggedTables: [table, table],
                fileURL: URL(fileURLWithPath: "/tmp/axis-app.pdf")
            )
            Issue.record("Expected ambiguous tagged transaction evidence to fail closed.")
        } catch let error as AxisCreditCardPDFNormalizationError {
            guard case .malformedTaggedTable = error else {
                Issue.record("Expected malformedTaggedTable, got \(error).")
                return
            }
        }
    }

    @Test func appPDFMalformedCellSourceShapeFailsClosedWithoutGeometryFallback() throws {
        let text = Self.appPDFText
        var table = Self.taggedTransactionTable(rows: [["02 Jun '26", "Purchase", "INR100.00", "Debit"]])
        let malformed = RawPDFTaggedCellEvidence(
            role: .data,
            children: [.markedContent(.init(pageNumber: 1, mcid: 90, textBlocks: ["02 Jun '26"], rectangleCount: 1))]
        )
        table = RawPDFTaggedTableEvidence(rows: [
            table.rows[0],
            RawPDFTaggedRowEvidence(cells: [malformed] + Array(table.rows[1].cells.dropFirst()))
        ])
        do {
            _ = try AxisCreditCardPDFNormalizer().normalize(
                text: text, pageTexts: [text], taggedTables: [table],
                fileURL: URL(fileURLWithPath: "/tmp/axis-app.pdf")
            )
            Issue.record("Expected malformed tagged cell shape to fail closed.")
        } catch let error as AxisCreditCardPDFNormalizationError {
            guard case .malformedTransaction(sourceOrdinal: 1) = error else {
                Issue.record("Expected malformedTransaction(1), got \(error).")
                return
            }
        }
    }

    @Test func contradictoryPDFPresentationHeadersFailClosedWhileOptionalAppDatesRemainEnrichment() throws {
        let tagged = Self.taggedTransactionTable(rows: [
            ["02 Jun '26", "Purchase", "INR100.00", "Debit"]
        ])
        let mixed = Self.appPDFText + "\nDate Transaction Details Merchant Category Amount (Rs.)"
        #expect(throws: AxisCreditCardPDFNormalizationError.changedHeader) {
            try AxisCreditCardPDFNormalizer().normalize(
                text: mixed,
                pageTexts: [mixed],
                taggedTables: [tagged],
                fileURL: URL(fileURLWithPath: "/tmp/mixed-axis-layout.pdf")
            )
        }

        let appWithExactDate = Self.appPDFText.replacingOccurrences(
            of: "Selected Statement Month: Jun 2026",
            with: "Selected Statement Month: Jun 2026\nStatement Date 30/06/2026"
        )
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: appWithExactDate,
            pageTexts: [appWithExactDate],
            taggedTables: [tagged],
            fileURL: URL(fileURLWithPath: "/tmp/app-with-optional-date.pdf")
        )
        let fragments = try Self.fragments(normalized, format: .pdf)
        #expect(fragments["SELECTED_STATEMENT_MONTH"] == "2026-06")
        #expect(fragments["STATEMENT_DATE"] == "30/06/2026")
    }

    @Test func xlsxUsesExactPhysicalColumnsAndRejectsShiftedOrTrailingEvidence() throws {
        let ok = try AxisCreditCardXLSXNormalizer().normalize(rawDocument: Self.axisXLSXRaw())
        #expect(ok.rows.count == 1)
        #expect(ok.rows[0].values[2] == "100.00")

        let explicitReserved = try AxisCreditCardXLSXNormalizer().normalize(rawDocument: Self.axisXLSXRaw(explicitReserved: true))
        #expect(explicitReserved.rows.count == 1)

        for bad in [
            Self.axisXLSXRaw(overrides: [3: "INR100.00", 4: ""]),
            Self.axisXLSXRaw(overrides: [5: "", 6: "Debit"]),
            Self.axisXLSXRaw(overrides: [4: ""]),
            Self.axisXLSXRaw(overrides: [7: "Unexpected evidence"])
        ] {
            #expect(throws: AxisCreditCardXLSXNormalizationError.self) {
                try AxisCreditCardXLSXNormalizer().normalize(rawDocument: bad)
            }
        }

        let footer = try AxisCreditCardXLSXNormalizer().normalize(rawDocument: Self.axisXLSXRaw(includeFooter: true))
        #expect(footer.rows.count == 1)
        let trailing = RawTabularRow(sourceRow: 5, cells: [
            RawTabularCell(sourceRow: 5, sourceColumn: 2, value: .string("Unexpected trailing note"))
        ])
        #expect(throws: AxisCreditCardXLSXNormalizationError.malformedTransaction(sourceOrdinal: 5)) {
            try AxisCreditCardXLSXNormalizer().normalize(rawDocument: Self.axisXLSXRaw(includeFooter: true, trailingRows: [trailing]))
        }
    }

    @Test func appSelectedMonthSurvivesAuthenticPDFKitGlyphDisplacement() {
        let samples: [(String, String)] = [
            ("Selected St\ntement Month\na\nJ\nn 2026\na\nPayment Summary", "2026-01"),
            ("Selected St\ntement Month\na\nM\ny 2026\na\nPayment Summary", "2026-05"),
            ("Selected St\ntement Month\na\nFe\nb 2026\nPayment Summary", "2026-02")
        ]
        for (text, expected) in samples {
            let fragments = AxisCreditCardPDFNormalizer.sourceFragments(from: text)
            #expect(fragments.contains { $0.text == "SELECTED_STATEMENT_MONTH\t\(expected)" })
        }

        let malformed = AxisCreditCardPDFNormalizer.sourceFragments(
            from: "Selected St\ntement Month\na\nJ\nx 2026\na\nPayment Summary"
        )
        #expect(!malformed.contains { $0.text.hasPrefix("SELECTED_STATEMENT_MONTH\t") })
    }

    @Test func xlsxSelectedMonthRemainsMonthEvidenceWithoutInventedPeriod() throws {
        let sourceFragments = AxisCreditCardPDFNormalizer.sourceFragments(
            from: "Selected Statement Month: Jun 2026"
        )
        let normalized = NormalizedDocument(
            document: Document(
                filename: "axis.xlsx",
                url: URL(fileURLWithPath: "/tmp/axis.xlsx"),
                fileType: FileFormat.xlsx.rawValue,
                importedAt: Date(timeIntervalSince1970: 0)
            ),
            metadata: DocumentMetadata(
                institution: .axis,
                documentType: .creditCard,
                fileFormat: .xlsx,
                confidence: 1
            ),
            rows: [],
            sourceContext: .init(preTransactionFragments: sourceFragments)
        )
        let fragments = AxisCreditCardParserSupport.fragments(normalized)
        #expect(fragments["SELECTED_STATEMENT_MONTH"] == "2026-06")
        #expect(try AxisCreditCardParserSupport.period(fragments) == nil)
        #expect(try AxisCreditCardParserSupport.selectedStatementMonth(fragments)?.canonical == "2026-06")
    }

    @Test func appSummaryContractUsesOnlySourceAuthorizedEvidenceAcrossPDFAndXLSX() throws {
        let tagged = Self.taggedTransactionTable(rows: [["02 Jun '26", "Purchase", "INR100.00", "Debit"]])
        let normalizedPDF = try AxisCreditCardPDFNormalizer().normalize(
            text: Self.appPDFText, pageTexts: [Self.appPDFText], taggedTables: [tagged],
            fileURL: URL(fileURLWithPath: "/tmp/axis-app.pdf")
        )
        let pdf = try AxisCreditCardPDFParser().parse(document: NormalizedDocument(
            document: normalizedPDF.document,
            metadata: DocumentMetadata(institution: .axis, documentType: .creditCard, fileFormat: .pdf, confidence: 1),
            rows: normalizedPDF.rows, header: normalizedPDF.header, sourceContext: normalizedPDF.sourceContext
        ))

        var xlsxFragments = AxisCreditCardPDFNormalizer.sourceFragments(from: Self.appPDFText)
        xlsxFragments.append(.init(sourceOrdinal: 0, text: "FORMAT\txlsx"))
        let xlsxRow = NormalizedRow(rowNumber: 7, values: [
            "2026-06-02", "Purchase", "100.00", CardLiabilityEffect.increasesAmountOwed.rawValue,
            "account_level", "", "", "", ""
        ])
        let xlsxDocument = Document(
            filename: "axis.xlsx", url: URL(fileURLWithPath: "/tmp/axis.xlsx"),
            fileType: FileFormat.xlsx.rawValue, importedAt: Date(timeIntervalSince1970: 0)
        )
        let xlsx = try AxisCreditCardXLSXParser().parse(document: NormalizedDocument(
            document: xlsxDocument,
            metadata: DocumentMetadata(institution: .axis, documentType: .creditCard, fileFormat: .xlsx, confidence: 1),
            rows: [xlsxRow], header: NormalizedRow(rowNumber: 6, values: AxisCreditCardXLSXNormalizer.logicalHeader),
            sourceContext: .init(preTransactionFragments: xlsxFragments)
        ))

        let expectedCodes: Set<String> = [
            "previous_balance", "axis_total_payment_due", "due_date"
        ]
        for document in [pdf, xlsx] {
            let evidence = try #require(document.cardStatementEvidence)
            #expect(evidence.instrumentSections.isEmpty)
            #expect(evidence.accountSourceIdentityObservations.isEmpty)
            #expect(evidence.reconciliationRuleIdentifier == CardStatementEvidence.axisINRRowLedgerReconciliationRule)
            #expect(Set(evidence.summaryComponents.map(\.persistenceCode)) == expectedCodes)
            #expect(evidence.selectedStatementMonth?.canonical == "2026-06")
            #expect(evidence.statementDate == nil)
            #expect(ImportValidator.validate(financialDocument: document).passed)
        }
    }

    @Test func missingOptionalAppSummaryOperandsDoNotRejectExactTransactions() throws {
        let tagged = Self.taggedTransactionTable(rows: [["02 Jun '26", "Purchase", "INR100.00", "Debit"]])
        for sourceLine in ["Opening Balance INR1,000.00\n", "Total Payment Due INR1,100.00\n"] {
            let text = Self.appPDFText.replacingOccurrences(of: sourceLine, with: "")
            let normalized = try AxisCreditCardPDFNormalizer().normalize(
                text: text, pageTexts: [text], taggedTables: [tagged],
                fileURL: URL(fileURLWithPath: "/tmp/axis-app.pdf")
            )
            let document = try AxisCreditCardPDFParser().parse(document: NormalizedDocument(
                document: normalized.document,
                metadata: DocumentMetadata(institution: .axis, documentType: .creditCard, fileFormat: .pdf, confidence: 1),
                rows: normalized.rows, header: normalized.header, sourceContext: normalized.sourceContext
            ))
            #expect(document.transactions.count == 1)
            let evidence = try #require(document.cardStatementEvidence)
            #expect(Set(evidence.summaryComponents.map(\.persistenceCode)).isSubset(of: [
                "previous_balance", "axis_total_payment_due", "due_date"
            ]))
            #expect(ImportValidator.validate(financialDocument: document).passed)
        }
    }

    @Test func temporalFieldsRemainSeparatelyOwnedWithoutFallbacks() throws {
        let distinct = try Self.parseEvidence([
            Self.fragment("STATEMENT_DATE", "30/06/2026"),
            Self.fragment("PAYMENT_DUE_DATE", "08/07/2026")
        ])
        #expect(distinct.statementDate?.canonical == "2026-06-30")
        #expect(distinct.summary(code: "due_date")?.date?.canonical == "2026-07-08")

        let equal = try Self.parseEvidence([
            Self.fragment("STATEMENT_DATE", "30/06/2026"),
            Self.fragment("PAYMENT_DUE_DATE", "08/07/2026")
        ])
        #expect(equal.statementDate?.canonical == "2026-06-30")
        #expect(equal.summary(code: "due_date")?.date?.canonical == "2026-07-08")

        let statementOnly = try Self.parseEvidence([Self.fragment("SELECTED_STATEMENT_MONTH", "2026-06")])
        #expect(statementOnly.statementDate == nil)
        #expect(statementOnly.selectedStatementMonth?.canonical == "2026-06")
        #expect(statementOnly.declaredStatementPeriod == nil)

        let appOnly = try Self.parseEvidence([
            Self.fragment("SELECTED_STATEMENT_MONTH", "2026-06"),
            Self.fragment("PAYMENT_DUE_DATE", "08/07/2026")
        ])
        #expect(appOnly.statementDate == nil)
        #expect(appOnly.declaredStatementPeriod == nil)
        #expect(appOnly.selectedStatementMonth?.canonical == "2026-06")
        #expect(appOnly.summary(code: "axis_statement_generation_date") == nil)
        #expect(appOnly.summary(code: "due_date")?.date?.canonical == "2026-07-08")
    }

    @Test func selectedMonthAloneDoesNotInventStatementDayOrPeriod() throws {
        let evidence = try Self.parseEvidence([
            Self.fragment("SELECTED_STATEMENT_MONTH", "2026-06")
        ])

        #expect(evidence.selectedStatementMonth?.canonical == "2026-06")
        #expect(evidence.statementDate == nil)
        #expect(evidence.declaredStatementPeriod == nil)
    }

    @Test func duplicateSourceFragmentsAreEqualOrConflictAndOrderIndependent() throws {
        for key in ["TOTAL_PAYMENT_DUE"] {
            let equal = Self.fragmentDocument([Self.fragment(key,"100.00"), Self.fragment(key,"100.00")])
            #expect(try AxisCreditCardParserSupport.validatedFragments(equal)[key] == "100.00")
            for values in [["100.00","101.00"],["101.00","100.00"]] {
                let conflict = Self.fragmentDocument([Self.fragment(key,values[0]), Self.fragment(key,values[1])])
                #expect(AxisCreditCardParserSupport.fragments(conflict)["__AXIS_FRAGMENT_CONFLICTS__"] != nil)
                #expect(throws: AxisCreditCardPDFParserError.malformedSourceEvidence) {
                    _ = try AxisCreditCardParserSupport.validatedFragments(conflict)
                }
            }
        }
        for key in ["PAYMENT_DUE_DATE", "STATEMENT_DATE"] {
            let equal = Self.fragmentDocument([Self.fragment(key,"30/06/2026"), Self.fragment(key,"30/06/2026")])
            #expect(try AxisCreditCardParserSupport.validatedFragments(equal)[key] == "30/06/2026")
            let conflict = Self.fragmentDocument([Self.fragment(key,"30/06/2026"), Self.fragment(key,"01/07/2026")])
            #expect(AxisCreditCardParserSupport.fragments(conflict)["__AXIS_FRAGMENT_CONFLICTS__"] != nil)
            #expect(throws: AxisCreditCardPDFParserError.malformedSourceEvidence) {
                _ = try AxisCreditCardParserSupport.validatedFragments(conflict)
            }
        }
    }

    @Test func traditionalSplitAmountAndDirectionPreserveOnlyOwnedDescription() throws {
        let normalized = try Self.normalizeTraditional(rows: [
            Self.traditionalTransactionFragments(
                y: 430,
                description: ["Fictional", "Shop"],
                category: "Retail",
                amountFragments: ["100.00", "Debit"]
            )
        ])

        let row = try #require(normalized.rows.first)
        #expect(normalized.rows.count == 1)
        #expect(row.values[1] == "Fictional Shop")
        #expect(!row.values[1].contains("Retail"))
        #expect(row.values[2] == "100.00")
        #expect(row.values[3] == CardLiabilityEffect.increasesAmountOwed.rawValue)
    }

    @Test func traditionalWideHeaderRetainsDescriptionAtOwnedLeadingEdge() throws {
        let source = Self.traditionalSummaryPageEvidence()
        let evidence = RawPDFPageEvidence(fragments: source.fragments.compactMap { fragment in
            if fragment.y == 430 { return nil }
            guard fragment.text == "Transaction Details",
                  let geometry = fragment.geometry else { return fragment }
            return RawPDFTextFragment(
                text: fragment.text,
                geometry: .init(
                    minX: geometry.minX,
                    maxX: 340,
                    baselineY: geometry.baselineY
                )
            )
        } + [
            Self.rectangular("02/06/2026", x: 50, y: 430),
            Self.rectangular("Left-aligned", x: 111, y: 430),
            Self.rectangular("Narration", x: 220, y: 430),
            Self.rectangular("Retail", x: 350, y: 430),
            Self.rectangular("100.00", x: 520, y: 430),
            Self.rectangular("Debit", x: 590, y: 430)
        ])
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: Self.traditionalGeometryText,
            pageTexts: [Self.traditionalGeometryText],
            pageEvidence: [evidence],
            fileURL: URL(fileURLWithPath: "/tmp/traditional-wide-header.pdf")
        )

        let row = try #require(normalized.rows.first)
        #expect(normalized.rows.count == 1)
        #expect(row.values[1] == "Left-aligned Narration")
        #expect(!row.values[1].contains("Retail"))
    }

    @Test func traditionalDuplicateFinancialKeysKeepDistinctSourceDescriptions() throws {
        let normalized = try Self.normalizeTraditional(rows: [
            Self.traditionalTransactionFragments(
                y: 430,
                description: ["First", "Narration"],
                category: "Retail",
                amountFragments: ["100.00", "Debit"]
            ),
            Self.traditionalTransactionFragments(
                y: 410,
                description: ["Second", "Narration"],
                category: "Services",
                amountFragments: ["100.00", "Debit"]
            )
        ])

        #expect(normalized.rows.count == 2)
        #expect(normalized.rows.map { $0.values[0] } == ["02/06/2026", "02/06/2026"])
        #expect(normalized.rows.map { $0.values[1] } == ["First Narration", "Second Narration"])
        #expect(normalized.rows.map { $0.values[2] } == ["100.00", "100.00"])
    }

    @Test func traditionalAmbiguousAmountDirectionEvidenceFailsClosed() throws {
        #expect(throws: AxisCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: 1)) {
            try Self.normalizeTraditional(rows: [
                Self.traditionalTransactionFragments(
                    y: 430,
                    description: ["Ambiguous", "Narration"],
                    category: "Retail",
                    amountFragments: ["100.00", "Debit", "200.00", "Credit"]
                )
            ])
        }
    }

    @Test func traditionalMissingDirectionNeverFallsBackToWholeVisualRow() throws {
        #expect(throws: AxisCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: 1)) {
            try Self.normalizeTraditional(rows: [
                Self.traditionalTransactionFragments(
                    y: 430,
                    description: ["Missing", "Direction"],
                    category: "Retail",
                    amountFragments: ["100.00"]
                )
            ])
        }
    }

    @Test func traditionalSummaryUsesExactOwnedColumnsInsteadOfFlattenedNeighbors() throws {
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: Self.traditionalGeometryText,
            pageTexts: [Self.traditionalGeometryText],
            pageEvidence: [Self.traditionalSummaryPageEvidence()],
            fileURL: URL(fileURLWithPath: "/tmp/traditional-geometry.pdf")
        )
        let fragments = try Self.fragments(normalized, format: .pdf)
        #expect(fragments["OPENING_BALANCE"] == "1000.00")
        for removedKey in ["PAYMENTS", "CREDITS", "PURCHASES", "CASH_ADVANCE", "OTHER_DEBIT_CHARGES", "MINIMUM_PAYMENT_DUE", "CREDIT_LIMIT"] {
            #expect(fragments[removedKey] == nil)
        }
        #expect(fragments["TOTAL_PAYMENT_DUE"] == "1100.00")
        #expect(fragments["PERIOD"] == "01/06/2026\t30/06/2026")
    }

    @Test func traditionalSummaryRecognizesExactSplitHeaderTokensWithoutGapInference() throws {
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: Self.traditionalGeometryText,
            pageTexts: [Self.traditionalGeometryText],
            pageEvidence: [Self.splitTraditionalSummaryHeaderEvidence()],
            fileURL: URL(fileURLWithPath: "/tmp/traditional-split-summary-headers.pdf")
        )
        let fragments = try Self.fragments(normalized, format: .pdf)
        #expect(fragments["OPENING_BALANCE"] == "1000.00")
        #expect(fragments["MINIMUM_PAYMENT_DUE"] == nil)
        #expect(fragments["CREDIT_LIMIT"] == nil)
    }

    @Test func traditionalSummaryOwnsOuterAlignedMoneyAndUniqueSecondRowGroups() throws {
        let source = Self.traditionalSummaryPageEvidence()
        var shifted: [RawPDFTextFragment] = []
        for fragment in source.fragments {
            guard let geometry = fragment.geometry else {
                shifted.append(fragment)
                continue
            }
            switch geometry.baselineY {
            case 680 where fragment.text == "1000.00 Dr":
                // The authentic first balance value can be narrower and
                // farther left than its wide header phrase. Keep its Money and
                // direction as separate source rectangles.
                shifted.append(.init(
                    text: "1000.00",
                    geometry: .init(minX: 0, maxX: 45, baselineY: 660)
                ))
                shifted.append(.init(
                    text: "Dr",
                    geometry: .init(minX: 80, maxX: 90, baselineY: 660)
                ))
            case 680:
                shifted.append(.init(
                    text: fragment.text,
                    geometry: .init(
                        minX: geometry.minX,
                        maxX: geometry.maxX,
                        baselineY: 660
                    )
                ))
            case 500:
                shifted.append(.init(
                    text: fragment.text,
                    geometry: .init(
                        minX: geometry.minX,
                        maxX: geometry.maxX,
                        baselineY: 480
                    )
                ))
            default:
                shifted.append(fragment)
            }
        }
        shifted.append(.init(
            text: "decorative",
            geometry: .init(minX: 260, maxX: 300, baselineY: 680)
        ))
        shifted.append(.init(
            text: "separator",
            geometry: .init(minX: 260, maxX: 300, baselineY: 500)
        ))
        shifted.append(.init(
            text: "non-financial note",
            geometry: .init(minX: -100, maxX: -10, baselineY: 660)
        ))

        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: Self.traditionalGeometryText,
            pageTexts: [Self.traditionalGeometryText],
            pageEvidence: [.init(fragments: shifted)],
            fileURL: URL(fileURLWithPath: "/tmp/traditional-bounded-value-rows.pdf")
        )
        let fragments = try Self.fragments(normalized, format: .pdf)
        #expect(fragments["OPENING_BALANCE"] == "1000.00")
        #expect(fragments["PAYMENTS"] == nil)
        #expect(fragments["OTHER_DEBIT_CHARGES"] == nil)
        #expect(fragments["MINIMUM_PAYMENT_DUE"] == nil)
        #expect(fragments["CREDIT_LIMIT"] == nil)
    }

    @Test func traditionalSummaryOmitsCompetingOrOutOfBoundOptionalValueGroups() throws {
        let source = Self.traditionalSummaryPageEvidence()
        let competingBalance = source.fragments.compactMap { fragment -> RawPDFTextFragment? in
            guard let geometry = fragment.geometry, geometry.baselineY == 680 else { return nil }
            return .init(
                text: fragment.text == "120.00" ? "121.00" : fragment.text,
                geometry: .init(
                    minX: geometry.minX,
                    maxX: geometry.maxX,
                    baselineY: 690
                )
            )
        }
        let competing = try AxisCreditCardPDFNormalizer().normalize(
            text: Self.traditionalGeometryText,
            pageTexts: [Self.traditionalGeometryText],
            pageEvidence: [.init(fragments: source.fragments + competingBalance)],
            fileURL: URL(fileURLWithPath: "/tmp/traditional-competing-value-groups.pdf")
        )
        #expect(competing.rows.count == 1)
        #expect(try Self.fragments(competing, format: .pdf)["OPENING_BALANCE"] == nil)

        var outOfBoundCredit = source.fragments.map { fragment -> RawPDFTextFragment in
            guard let geometry = fragment.geometry, geometry.baselineY == 500 else { return fragment }
            return .init(
                text: fragment.text,
                geometry: .init(
                    minX: geometry.minX,
                    maxX: geometry.maxX,
                    baselineY: 470
                )
            )
        }
        outOfBoundCredit.append(.init(
            text: "first spacer",
            geometry: .init(minX: 250, maxX: 300, baselineY: 500)
        ))
        outOfBoundCredit.append(.init(
            text: "second spacer",
            geometry: .init(minX: 250, maxX: 300, baselineY: 490)
        ))
        let outOfBound = try AxisCreditCardPDFNormalizer().normalize(
            text: Self.traditionalGeometryText,
            pageTexts: [Self.traditionalGeometryText],
            pageEvidence: [.init(fragments: outOfBoundCredit)],
            fileURL: URL(fileURLWithPath: "/tmp/traditional-out-of-bound-credit.pdf")
        )
        #expect(outOfBound.rows.count == 1)
        #expect(try Self.fragments(outOfBound, format: .pdf)["CREDIT_LIMIT"] == nil)
    }

    @Test func equalFlattenedPaymentCannotReplaceMissingOwnedOptionalColumn() throws {
        let equalGeneric = Self.traditionalGeometryText.replacingOccurrences(
            of: "Payments INR901.00",
            with: "Payments INR120.00"
        )
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: equalGeneric,
            pageTexts: [equalGeneric],
            pageEvidence: [Self.traditionalSummaryPageEvidence(paymentsX: 205)],
            fileURL: URL(fileURLWithPath: "/tmp/traditional-missing-owned-payment.pdf")
        )
        #expect(normalized.rows.count == 1)
        #expect(try Self.fragments(normalized, format: .pdf)["PAYMENTS"] == nil)
    }

    @Test func appTaggedTableOwnsDuplicateDescriptionsAndOrder() throws {
        let tagged = Self.taggedTransactionTable(rows: [
            ["02 Jun '26", "Tagged second", "INR100.00", "Debit"],
            ["02 Jun '26", "Tagged first", "INR100.00", "Debit"]
        ])
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: Self.appPDFText,
            pageTexts: [Self.appPDFText],
            taggedTables: [tagged],
            fileURL: URL(fileURLWithPath: "/tmp/app-duplicate-financial-key.pdf")
        )
        #expect(normalized.rows.map { $0.values[1] } == ["Tagged second", "Tagged first"])
        #expect(normalized.rows.allSatisfy {
            $0.values[4] == "account_level" && $0.values[5].isEmpty
        })
    }

    @Test func axisCardRulePrecedesBroadAxisAccountRule() {
        let text = "AXIS BANK CREDIT CARD NUMBER TOTAL PAYMENT DUE DATE TRANSACTION DETAILS AMOUNT (INR) DEBIT/CREDIT"
        let result = SignatureInstitutionDetector().detect(from: text)
        #expect(result.metadata.institution == .axis)
        #expect(result.metadata.documentType == .creditCard)
    }

    private static let appPDFText = """
    AXIS CREDIT CARD STATEMENT
    Credit Card Number: 4111 XXXX XXXX 0001
    Selected Statement Month: Jun 2026
    Opening Balance INR1,000.00
    Credit Limit INR2,000.00
    Total Payment Due INR1,100.00
    Minimum Payment Due INR100.00
    Payment Due Date 08 Jul '26
    Date Transaction Details Amount (INR) Debit/Credit
    """

    private static let traditionalGeometryText = """
    AXIS BANK CREDIT CARD STATEMENT
    Credit Card Number: 4111 XXXX XXXX 0001
    Statement Date 30/06/2026
    Statement Period 01/06/2026 to 30/06/2026
    Opening Balance INR1,000.00
    Payments INR901.00
    Credits INR902.00
    Purchase INR200.00
    Cash Advance INR903.00
    Other Debit/Charges INR10.00
    Total Payment Due INR1,100.00
    Minimum Payment Due INR904.00
    Payment Due Date 08/07/2026
    Statement Generation Date 30/06/2026
    Credit Limit INR9,050.00
    Date Transaction Details Merchant Category Amount (Rs.)
    02/06/2026 Fictional Shop Retail 100.00 Debit
    """

    private static func traditionalSummaryPageEvidence(
        paymentsX: Double = 150
    ) -> RawPDFPageEvidence {
        func fragment(
            _ text: String,
            x: Double,
            y: Double,
            width: Double = 60
        ) -> RawPDFTextFragment {
            RawPDFTextFragment(
                text: text,
                geometry: .init(minX: x, maxX: x + width, baselineY: y)
            )
        }
        return RawPDFPageEvidence(fragments: [
            fragment("Previous Balance", x: 50, y: 700),
            fragment("- Payments", x: 150, y: 700),
            fragment("- Credits", x: 250, y: 700),
            fragment("+ Purchase", x: 350, y: 700),
            fragment("+ Cash Advance", x: 450, y: 700),
            fragment("+ Other Debit/Charges", x: 550, y: 700),
            fragment("1000.00 Dr", x: 50, y: 680),
            fragment("120.00", x: paymentsX, y: 680),
            fragment("30.00", x: 250, y: 680),
            fragment("200.00", x: 350, y: 680),
            fragment("40.00", x: 450, y: 680),
            fragment("10.00", x: 550, y: 680),
            fragment("Total Payment Due", x: 50, y: 640, width: 80),
            fragment("Minimum Payment Due", x: 180, y: 640, width: 80),
            fragment("Statement Period", x: 310, y: 640, width: 80),
            fragment("Payment Due Date", x: 450, y: 640, width: 80),
            fragment("Statement Generation Date", x: 580, y: 640, width: 90),
            fragment("1100.00 Dr", x: 50, y: 620),
            fragment("100.00 Dr", x: 180, y: 620),
            fragment("01/06/2026 - 30/06/2026", x: 310, y: 620, width: 110),
            fragment("08/07/2026", x: 450, y: 620),
            fragment("30/06/2026", x: 580, y: 620),
            fragment("Minimum Payment Due", x: 50, y: 580, width: 80),
            fragment("777.00", x: 50, y: 560),
            fragment("Credit Limit", x: 50, y: 520, width: 70),
            fragment("Available Credit Limit", x: 180, y: 520, width: 90),
            fragment("Available Cash Limit", x: 350, y: 520, width: 90),
            fragment("2000.00", x: 50, y: 500),
            fragment("1500.00", x: 180, y: 500),
            fragment("500.00", x: 350, y: 500),
            fragment("Date", x: 50, y: 450),
            fragment("Transaction Details", x: 140, y: 450, width: 80),
            fragment("Merchant Category", x: 350, y: 450, width: 80),
            fragment("Amount (Rs.)", x: 520, y: 450, width: 70),
            fragment("02/06/2026", x: 50, y: 430),
            fragment("Fictional Shop", x: 140, y: 430),
            fragment("Retail", x: 350, y: 430),
            fragment("100.00 Debit", x: 520, y: 430)
        ])
    }

    private static func normalizeTraditional(
        rows: [[RawPDFTextFragment]]
    ) throws -> AxisCreditCardPDFNormalizationResult {
        let base = traditionalSummaryPageEvidence()
        let evidence = RawPDFPageEvidence(
            fragments: base.fragments.filter { $0.y != 430 } + rows.flatMap { $0 }
        )
        return try AxisCreditCardPDFNormalizer().normalize(
            text: traditionalGeometryText,
            pageTexts: [traditionalGeometryText],
            pageEvidence: [evidence],
            fileURL: URL(fileURLWithPath: "/tmp/traditional-transaction-mechanics.pdf")
        )
    }

    private static func traditionalTransactionFragments(
        y: Double,
        description: [String],
        category: String,
        amountFragments: [String]
    ) -> [RawPDFTextFragment] {
        var result: [RawPDFTextFragment] = [
            Self.rectangular("02/06/2026", x: 50, y: y)
        ]
        result += description.enumerated().map { index, text in
            Self.rectangular(text, x: 140 + (Double(index) * 70), y: y)
        }
        result.append(Self.rectangular(category, x: 350, y: y))
        result += amountFragments.enumerated().map { index, text in
            Self.rectangular(text, x: 520 + (Double(index) * 70), y: y)
        }
        return result
    }

    private static func rectangular(
        _ text: String,
        x: Double,
        y: Double
    ) -> RawPDFTextFragment {
        RawPDFTextFragment(
            text: text,
            geometry: .init(minX: x, maxX: x + max(8, Double(text.count) * 7), baselineY: y)
        )
    }

    private static func splitTraditionalSummaryHeaderEvidence() -> RawPDFPageEvidence {
        let source = traditionalSummaryPageEvidence()
        let splitLabels: [String: [String]] = [
            "Previous Balance": ["Previous", "Balance"],
            "- Payments": ["Payments"],
            "- Credits": ["Credits"],
            "+ Purchase": ["Purchase"],
            "+ Cash Advance": ["Cash", "Advance"],
            "+ Other Debit/Charges": ["Other", "Debit", "/", "Charges"],
            "Total Payment Due": ["Total", "Payment", "Due"],
            "Minimum Payment Due": ["Minimum", "Payment", "Due"],
            "Statement Period": ["Statement", "Period"],
            "Payment Due Date": ["Payment", "Due", "Date"],
            "Statement Generation Date": ["Statement", "Generation", "Date"],
            "Credit Limit": ["Credit", "Limit"],
            "Available Credit Limit": ["Available", "Credit", "Limit"],
            "Available Cash Limit": ["Available", "Cash", "Limit"]
        ]
        return RawPDFPageEvidence(fragments: source.fragments.flatMap { fragment in
            guard let pieces = splitLabels[fragment.text],
                  let geometry = fragment.geometry else { return [fragment] }
            return pieces.enumerated().map { index, piece in
                RawPDFTextFragment(
                    text: piece,
                    geometry: .init(
                        minX: geometry.minX + (Double(index) * 22),
                        maxX: geometry.minX + (Double(index) * 22) + 10,
                        baselineY: geometry.baselineY
                    )
                )
            }
        })
    }

    private static func fragment(_ key:String,_ value:String)->NormalizedDocument.SourceFragment { .init(sourceOrdinal:1,text:"\(key)\t\(value)") }
    private static func fragmentDocument(_ f:[NormalizedDocument.SourceFragment])->NormalizedDocument {
        NormalizedDocument(document:Document(filename:"axis.pdf",url:URL(fileURLWithPath:"/tmp/axis.pdf"),fileType:FileFormat.pdf.rawValue,importedAt:Date(timeIntervalSince1970:0)),metadata:DocumentMetadata(institution:.axis,documentType:.creditCard,fileFormat:.pdf,confidence:1),rows:[],sourceContext:.init(preTransactionFragments:f))
    }
    private static func parseEvidence(_ extra:[NormalizedDocument.SourceFragment]) throws -> CardStatementEvidence {
        let row=NormalizedRow(rowNumber:1,values:["2026-06-02","Fictional purchase","100.00",CardLiabilityEffect.increasesAmountOwed.rawValue,"account_level","","","",""])
        let d=Document(filename:"axis.pdf",url:URL(fileURLWithPath:"/tmp/axis.pdf"),fileType:FileFormat.pdf.rawValue,importedAt:Date(timeIntervalSince1970:0))
        let parsed=try AxisCreditCardPDFParser().parse(document:NormalizedDocument(document:d,metadata:DocumentMetadata(institution:.axis,documentType:.creditCard,fileFormat:.pdf,confidence:1),rows:[row],header:NormalizedRow(rowNumber:1,values:AxisCreditCardPDFNormalizer.logicalHeader),sourceContext:.init(preTransactionFragments:extra)))
        guard let evidence=parsed.cardStatementEvidence else { throw AxisCreditCardPDFParserError.malformedSourceEvidence }
        return evidence
    }
    private static func fragments(_ n:AxisCreditCardPDFNormalizationResult,format:FileFormat) throws->[String:String] {
        try AxisCreditCardParserSupport.validatedFragments(NormalizedDocument(document:n.document,metadata:DocumentMetadata(institution:.axis,documentType:.creditCard,fileFormat:format,confidence:1),rows:n.rows,header:n.header,sourceContext:n.sourceContext))
    }
    private static func axisXLSXRaw(creditLimit:String?="Credit Limit INR2,000.00",explicitReserved:Bool=false,overrides:[Int:String]=[:],includeFooter:Bool=false,trailingRows:[RawTabularRow]=[])->RawDocument {
        var rows:[RawTabularRow]=[]
        if let creditLimit { rows.append(.init(sourceRow:1,cells:[.init(sourceRow:1,sourceColumn:3,value:.string(creditLimit))])) }
        var h:[Int:RawTabularCellValue]=[1:.string("Date"),2:.string("Transaction Details"),4:.string("Amount (INR)"),5:.string("Debit/Credit")]
        if explicitReserved { h[3] = .blank; h[6] = .blank }
        rows.append(.init(sourceRow:2,cells:h.keys.sorted().map{.init(sourceRow:2,sourceColumn:$0,value:h[$0]!)}))
        var t=[1:"02 Jun '26",2:"Purchase",4:"INR100.00",5:"Debit"]
        if explicitReserved { t[3]=""; t[6]="" }
        for (k,v) in overrides { t[k]=v }
        rows.append(.init(sourceRow:3,cells:t.keys.sorted().map{ let v=t[$0]!; return .init(sourceRow:3,sourceColumn:$0,value:v.isEmpty ? .blank:.string(v)) }))
        var merges:[RawTabularMergedRange]=[]
        if includeFooter { rows.append(.init(sourceRow:4,cells:[.init(sourceRow:4,sourceColumn:1,value:.string("End of statement"))])); merges.append(.init(reference:"A4:F4",startRow:4,startColumn:1,endRow:4,endColumn:6)) }
        rows += trailingRows
        return RawDocument(sourceURL:URL(fileURLWithPath:"/tmp/axis.xlsx"),fileName:"axis.xlsx",fileExtension:"xlsx",content:.tabular(.init(name:"Sheet1",visibility:.visible,columnCount:max(6,t.keys.max() ?? 6),rows:rows,mergedRanges:merges)))
    }

    private static func taggedTransactionTable(
        rows: [[String]],
        detailBlocks: [Int: [String]] = [:]
    ) -> RawPDFTaggedTableEvidence {
        taggedTable(
            header: ["Date", "Transaction Details", "Amount (INR)", "Debit/Credit"],
            rows: rows,
            detailBlocks: detailBlocks
        )
    }

    private static func taggedTable(
        header: [String],
        rows: [[String]],
        detailBlocks: [Int: [String]] = [:]
    ) -> RawPDFTaggedTableEvidence {
        var nextMCID = 1
        func cell(role: RawPDFTaggedCellRole, blocks: [String]) -> RawPDFTaggedCellEvidence {
            defer { nextMCID += 2 }
            return RawPDFTaggedCellEvidence(
                role: role,
                children: [
                    .markedContent(.init(
                        pageNumber: 1, mcid: nextMCID,
                        textBlocks: [], rectangleCount: 1
                    )),
                    .structure(.init(
                        role: "NonStruct",
                        markedContent: [.init(
                            pageNumber: 1, mcid: nextMCID + 1,
                            textBlocks: blocks, rectangleCount: 0
                        )]
                    ))
                ]
            )
        }
        let headerRow = RawPDFTaggedRowEvidence(cells: header.map { cell(role: .header, blocks: [$0]) })
        let dataRows = rows.enumerated().map { rowIndex, values in
            RawPDFTaggedRowEvidence(cells: values.enumerated().map { columnIndex, value in
                let blocks = columnIndex == 1 ? (detailBlocks[rowIndex] ?? [value]) : [value]
                return cell(role: .data, blocks: blocks)
            })
        }
        return RawPDFTaggedTableEvidence(rows: [headerRow] + dataRows)
    }

}

@Suite
@MainActor
struct AxisCreditCardAppSummaryContractTests {
    @Test
    func sourceAuthorizedEvidenceAcrossPDFAndXLSX() throws {
        try AxisCreditCardParserTests().appSummaryContractUsesOnlySourceAuthorizedEvidenceAcrossPDFAndXLSX()
    }

    @Test
    func missingOptionalReconciliationOperandPreservesTransactions() throws {
        try AxisCreditCardParserTests().missingOptionalAppSummaryOperandsDoNotRejectExactTransactions()
    }
}
