//
// LedgerForge
// AxisBankAccountPDFNormalizer.swift
// Version: 0.1.0
//

import Foundation

enum AxisBankAccountPDFColumn: Int, CaseIterable {
    case date
    case chequeReference
    case particulars
    case sourceDebit
    case sourceCredit
    case collapsedAmount
    case balance
    case branchCode
    case openingBalance
    case printedDebitTotal
    case printedCreditTotal
    case closingBalance

    static let normalizedHeader = [
        "Tran Date",
        "Chq No",
        "Particulars",
        "Debit",
        "Credit",
        "Posted Amount",
        "Balance",
        "Init. Br",
        "Opening Balance",
        "Printed Debit Total",
        "Printed Credit Total",
        "Closing Balance"
    ]
}

enum AxisBankAccountPDFTitleEvidenceError: Error, Equatable {
    case notTitle
    case malformedAccountIdentifier
    case malformedDeclaredPeriod
    case unconsumedFinancialPrefix
}

struct AxisBankAccountPDFTitleEvidence: Equatable {
    let accountIdentifier: String
    let periodStartText: String
    let periodEndText: String
    let recognizedSourceText: String

    static let marker = "Statement of Axis Account No"

    static func parse(
        _ sourceText: String
    ) throws -> AxisBankAccountPDFTitleEvidence {
        let text = sourceText.collapsingWhitespace
        guard let markerRange = text.range(of: marker) else {
            throw AxisBankAccountPDFTitleEvidenceError.notTitle
        }
        let discardedPrefix = String(text[..<markerRange.lowerBound])
            .collapsingWhitespace
        guard !AxisBankAccountPDFNormalizer.looksFinancial(discardedPrefix) else {
            throw AxisBankAccountPDFTitleEvidenceError.unconsumedFinancialPrefix
        }
        let recognizedSourceText = String(text[markerRange.lowerBound...])

        let pattern =
            #"^Statement of Axis Account No\s*:\s*(\S+)\s+for the period\s*\(From\s*:\s*(\S+)\s+To\s*:\s*(\S+)\)\s*$"#
        guard let captures = recognizedSourceText.captures(matching: pattern),
              captures.count == 3 else {
            throw AxisBankAccountPDFTitleEvidenceError.malformedDeclaredPeriod
        }

        let accountIdentifier = captures[0]
        guard accountIdentifier.count == 15,
              accountIdentifier.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw AxisBankAccountPDFTitleEvidenceError.malformedAccountIdentifier
        }

        do {
            _ = try AxisBankAccountSourceEvidence.declaredStatementPeriod(
                startText: captures[1],
                endText: captures[2]
            )
        } catch {
            throw AxisBankAccountPDFTitleEvidenceError.malformedDeclaredPeriod
        }

        return AxisBankAccountPDFTitleEvidence(
            accountIdentifier: accountIdentifier,
            periodStartText: captures[1],
            periodEndText: captures[2],
            recognizedSourceText: recognizedSourceText
        )
    }
}

enum AxisBankAccountPDFNormalizationError: Error, Equatable, LocalizedError {
    case missingTitle
    case malformedAccountIdentifier(sourceOrdinal: Int)
    case malformedDeclaredPeriod(sourceOrdinal: Int)
    case conflictingTitleEvidence
    case missingTableHeader
    case changedColumnOrder(sourceOrdinal: Int)
    case duplicateInitialHeader
    case missingOpeningBalance
    case missingTransactionTotal
    case missingClosingBalance
    case malformedTerminalValue(sourceOrdinal: Int)
    case duplicateTerminalSection
    case invalidSectionOrder
    case noTransactions
    case malformedDate(sourceOrdinal: Int)
    case incompleteTransaction(sourceOrdinal: Int)
    case missingBalance(sourceOrdinal: Int)
    case missingBranch(sourceOrdinal: Int)
    case malformedDecimal(sourceOrdinal: Int)
    case unconsumedFinancialContent(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "The exact Axis bank-account PDF title is missing."
        case .malformedAccountIdentifier(let sourceOrdinal):
            return "Axis PDF account evidence on source line \(sourceOrdinal) is malformed."
        case .malformedDeclaredPeriod(let sourceOrdinal):
            return "Axis PDF statement-period evidence on source line \(sourceOrdinal) is malformed."
        case .conflictingTitleEvidence:
            return "Axis PDF title, account, or period evidence is duplicated or conflicting."
        case .missingTableHeader:
            return "The exact Axis PDF transaction-table header is missing."
        case .changedColumnOrder(let sourceOrdinal):
            return "Axis PDF table columns on source line \(sourceOrdinal) do not match the approved order."
        case .duplicateInitialHeader:
            return "Axis PDF contains more than one initial table header."
        case .missingOpeningBalance:
            return "Axis PDF is missing OPENING BALANCE."
        case .missingTransactionTotal:
            return "Axis PDF is missing TRANSACTION TOTAL."
        case .missingClosingBalance:
            return "Axis PDF is missing CLOSING BALANCE."
        case .malformedTerminalValue(let sourceOrdinal):
            return "Axis PDF terminal evidence on source line \(sourceOrdinal) is malformed."
        case .duplicateTerminalSection:
            return "Axis PDF contains a repeated or conflicting terminal section."
        case .invalidSectionOrder:
            return "Axis PDF financial sections are not in the approved order."
        case .noTransactions:
            return "Axis PDF contains no supported transaction rows."
        case .malformedDate(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) has a malformed date."
        case .incompleteTransaction(let sourceOrdinal):
            return "Axis PDF transaction beginning on source line \(sourceOrdinal) is incomplete."
        case .missingBalance(let sourceOrdinal):
            return "Axis PDF transaction beginning on source line \(sourceOrdinal) has no running balance."
        case .missingBranch(let sourceOrdinal):
            return "Axis PDF transaction beginning on source line \(sourceOrdinal) has no Init. Br evidence."
        case .malformedDecimal(let sourceOrdinal):
            return "Axis PDF financial value on source line \(sourceOrdinal) is malformed."
        case .unconsumedFinancialContent(let sourceOrdinal):
            return "Axis PDF has unconsumed financial-looking content on source line \(sourceOrdinal)."
        }
    }
}

struct AxisBankAccountPDFNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow?
    let sourceContext: NormalizedDocument.SourceContext
}

final class AxisBankAccountPDFNormalizer {

    private struct PhysicalLine {
        let index: Int
        let text: String

        var sourceOrdinal: Int { index + 1 }
        var normalizedText: String { text.collapsingWhitespace }
    }

    private struct HeaderOccurrence {
        let startIndex: Int
        let consumedIndices: Set<Int>
    }

    private struct TerminalEvidence {
        let index: Int
        let values: [String]
    }

    private struct ParsedTransaction {
        let sourceOrdinal: Int
        let date: String
        let chequeReference: String
        let particulars: String
        let sourceDebit: String
        let sourceCredit: String
        let collapsedAmount: String
        let balance: String
        let branchCode: String
    }

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func normalize(
        text: String,
        fileURL: URL
    ) throws -> AxisBankAccountPDFNormalizationResult {
        let lines = text.components(separatedBy: .newlines)
            .enumerated()
            .map { PhysicalLine(index: $0.offset, text: $0.element) }

        let title = try titleEvidence(in: lines)
        let headers = try headerOccurrences(in: lines)
        guard !headers.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.missingTableHeader
        }

        let opening = try terminalEvidence(
            prefix: Self.openingPrefix,
            pattern: #"^OPENING BALANCE\s+("# + Self.moneyPattern + #")\s*$"#,
            missing: .missingOpeningBalance,
            in: lines
        )
        let transactionTotal = try terminalEvidence(
            prefix: Self.totalPrefix,
            pattern: #"^TRANSACTION TOTAL\s+("# + Self.moneyPattern + #")\s+("# + Self.moneyPattern + #")\s*$"#,
            missing: .missingTransactionTotal,
            in: lines
        )
        let closing = try terminalEvidence(
            prefix: Self.closingPrefix,
            pattern: #"^CLOSING BALANCE\s+("# + Self.moneyPattern + #")\s*$"#,
            missing: .missingClosingBalance,
            in: lines
        )

        guard let initialHeader = headers.first(where: {
            $0.startIndex > title.line.index && $0.startIndex < opening.index
        }) else {
            throw AxisBankAccountPDFNormalizationError.invalidSectionOrder
        }
        let initialHeaderCount = headers.filter {
            $0.startIndex > title.line.index && $0.startIndex < opening.index
        }.count
        guard initialHeaderCount == 1 else {
            throw AxisBankAccountPDFNormalizationError.duplicateInitialHeader
        }
        guard title.line.index < initialHeader.startIndex,
              initialHeader.startIndex < opening.index,
              opening.index < transactionTotal.index,
              transactionTotal.index < closing.index else {
            throw AxisBankAccountPDFNormalizationError.invalidSectionOrder
        }

        try rejectFinancialContent(
            in: lines,
            from: lines.startIndex,
            to: title.line.index
        )
        try rejectFinancialContent(
            in: lines,
            from: title.line.index + 1,
            to: initialHeader.startIndex
        )
        let initialHeaderEnd =
            (initialHeader.consumedIndices.max() ?? initialHeader.startIndex) + 1
        try rejectFinancialContent(
            in: lines,
            from: initialHeaderEnd,
            to: opening.index
        )
        try rejectFinancialContent(
            in: lines,
            from: transactionTotal.index + 1,
            to: closing.index
        )

        let repeatedHeaders = headers.filter {
            $0.startIndex > opening.index && $0.startIndex < transactionTotal.index
        }
        let allowedHeaderStarts = Set(
            [initialHeader.startIndex] + repeatedHeaders.map(\.startIndex)
        )
        guard headers.allSatisfy({
            allowedHeaderStarts.contains($0.startIndex)
        }) else {
            throw AxisBankAccountPDFNormalizationError.invalidSectionOrder
        }
        let repeatedHeaderIndices = repeatedHeaders.reduce(into: Set<Int>()) {
            $0.formUnion($1.consumedIndices)
        }

        let parsedTransactions = try transactions(
            in: lines,
            from: opening.index + 1,
            to: transactionTotal.index,
            repeatedHeaderIndices: repeatedHeaderIndices
        )
        guard !parsedTransactions.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.noTransactions
        }

        for line in lines where line.index > closing.index {
            if Self.looksFinancial(line.normalizedText) {
                throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                    sourceOrdinal: line.sourceOrdinal
                )
            }
        }

        let openingBalance = Self.canonicalMoneyText(opening.values[0])
        let printedDebitTotal = Self.canonicalMoneyText(transactionTotal.values[0])
        let printedCreditTotal = Self.canonicalMoneyText(transactionTotal.values[1])
        let closingBalance = Self.canonicalMoneyText(closing.values[0])

        let rows = parsedTransactions.enumerated().map { index, transaction in
            var values = [
                transaction.date,
                transaction.chequeReference,
                transaction.particulars,
                transaction.sourceDebit,
                transaction.sourceCredit,
                transaction.collapsedAmount,
                transaction.balance,
                transaction.branchCode,
                "",
                "",
                "",
                ""
            ]

            if index == parsedTransactions.startIndex {
                values[AxisBankAccountPDFColumn.openingBalance.rawValue] = openingBalance
            }
            if index == parsedTransactions.index(before: parsedTransactions.endIndex) {
                values[AxisBankAccountPDFColumn.printedDebitTotal.rawValue] = printedDebitTotal
                values[AxisBankAccountPDFColumn.printedCreditTotal.rawValue] = printedCreditTotal
                values[AxisBankAccountPDFColumn.closingBalance.rawValue] = closingBalance
            }

            return NormalizedRow(
                rowNumber: transaction.sourceOrdinal,
                values: values
            )
        }

        var document = Document(
            filename: fileURL.lastPathComponent,
            url: fileURL,
            fileType: FileFormat.pdf.rawValue,
            importedAt: now()
        )
        document.rowCount = lines.count
        document.headerRow = initialHeader.startIndex + 1
        document.firstTransactionRow = parsedTransactions[0].sourceOrdinal
        document.columnCount = AxisBankAccountPDFColumn.allCases.count
        document.encoding = "PDFKit selectable text"

        return AxisBankAccountPDFNormalizationResult(
            document: document,
            rows: rows,
            header: NormalizedRow(
                rowNumber: initialHeader.startIndex + 1,
                values: AxisBankAccountPDFColumn.normalizedHeader
            ),
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: [
                    NormalizedDocument.SourceFragment(
                        sourceOrdinal: title.line.sourceOrdinal,
                        text: title.evidence.recognizedSourceText
                    )
                ]
            )
        )
    }

    private func titleEvidence(
        in lines: [PhysicalLine]
    ) throws -> (line: PhysicalLine, evidence: AxisBankAccountPDFTitleEvidence) {
        var matches: [(PhysicalLine, AxisBankAccountPDFTitleEvidence)] = []

        for line in lines {
            do {
                matches.append((line, try AxisBankAccountPDFTitleEvidence.parse(line.text)))
            } catch AxisBankAccountPDFTitleEvidenceError.notTitle {
                continue
            } catch AxisBankAccountPDFTitleEvidenceError.malformedAccountIdentifier {
                throw AxisBankAccountPDFNormalizationError.malformedAccountIdentifier(
                    sourceOrdinal: line.sourceOrdinal
                )
            } catch AxisBankAccountPDFTitleEvidenceError.malformedDeclaredPeriod {
                throw AxisBankAccountPDFNormalizationError.malformedDeclaredPeriod(
                    sourceOrdinal: line.sourceOrdinal
                )
            } catch AxisBankAccountPDFTitleEvidenceError.unconsumedFinancialPrefix {
                throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                    sourceOrdinal: line.sourceOrdinal
                )
            }
        }

        guard !matches.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.missingTitle
        }
        guard matches.count == 1, let match = matches.first else {
            throw AxisBankAccountPDFNormalizationError.conflictingTitleEvidence
        }
        return (line: match.0, evidence: match.1)
    }

    private func headerOccurrences(
        in lines: [PhysicalLine]
    ) throws -> [HeaderOccurrence] {
        var occurrences: [HeaderOccurrence] = []
        var index = 0

        while index < lines.count {
            let text = lines[index].normalizedText
            if text == Self.completeHeader {
                occurrences.append(
                    HeaderOccurrence(
                        startIndex: index,
                        consumedIndices: [index]
                    )
                )
                index += 1
                continue
            }
            if text == Self.splitHeader {
                guard lines.indices.contains(index + 1),
                      lines[index + 1].normalizedText == "Br" else {
                    throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                        sourceOrdinal: lines[index].sourceOrdinal
                    )
                }
                occurrences.append(
                    HeaderOccurrence(
                        startIndex: index,
                        consumedIndices: [index, index + 1]
                    )
                )
                index += 2
                continue
            }
            if Self.looksLikeTableHeader(text) {
                throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                    sourceOrdinal: lines[index].sourceOrdinal
                )
            }
            index += 1
        }

        return occurrences
    }

    private func terminalEvidence(
        prefix: String,
        pattern: String,
        missing: AxisBankAccountPDFNormalizationError,
        in lines: [PhysicalLine]
    ) throws -> TerminalEvidence {
        let candidates = lines.filter {
            $0.normalizedText.hasPrefix(prefix)
        }
        guard !candidates.isEmpty else {
            throw missing
        }
        guard candidates.count == 1, let candidate = candidates.first else {
            throw AxisBankAccountPDFNormalizationError.duplicateTerminalSection
        }
        guard let values = candidate.normalizedText.captures(matching: pattern) else {
            throw AxisBankAccountPDFNormalizationError.malformedTerminalValue(
                sourceOrdinal: candidate.sourceOrdinal
            )
        }
        return TerminalEvidence(index: candidate.index, values: values)
    }

    private func transactions(
        in lines: [PhysicalLine],
        from startIndex: Int,
        to endIndex: Int,
        repeatedHeaderIndices: Set<Int>
    ) throws -> [ParsedTransaction] {
        var groups: [[PhysicalLine]] = []
        var current: [PhysicalLine] = []
        var ignoringBoundedNonFinancialBlock = false

        for index in startIndex..<endIndex {
            guard lines.indices.contains(index) else { continue }
            let line = lines[index]
            let text = line.normalizedText
            if repeatedHeaderIndices.contains(index) {
                ignoringBoundedNonFinancialBlock = false
                continue
            }
            if text.isEmpty {
                continue
            }

            if Self.startsWithDate(text) {
                ignoringBoundedNonFinancialBlock = false
                if !current.isEmpty {
                    groups.append(current)
                }
                current = [line]
            } else if Self.startsWithDateLikeToken(text) {
                throw AxisBankAccountPDFNormalizationError
                    .unconsumedFinancialContent(
                        sourceOrdinal: line.sourceOrdinal
                    )
            } else if Self.startsIgnorableNonFinancialBlock(text) {
                ignoringBoundedNonFinancialBlock = true
            } else if text.hasPrefix("Legend:") && Self.looksFinancial(text) {
                throw AxisBankAccountPDFNormalizationError
                    .unconsumedFinancialContent(
                        sourceOrdinal: line.sourceOrdinal
                    )
            } else if ignoringBoundedNonFinancialBlock {
                if Self.looksFinancial(text) {
                    throw AxisBankAccountPDFNormalizationError
                        .unconsumedFinancialContent(
                            sourceOrdinal: line.sourceOrdinal
                        )
                }
                continue
            } else {
                guard !current.isEmpty else {
                    throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                        sourceOrdinal: line.sourceOrdinal
                    )
                }
                current.append(line)
            }
        }

        if !current.isEmpty {
            groups.append(current)
        }

        return try groups.map(parseTransaction)
    }

    private func parseTransaction(
        _ group: [PhysicalLine]
    ) throws -> ParsedTransaction {
        guard let first = group.first,
              let dateCapture = first.normalizedText.captures(
                  matching: #"^(\d{2}-\d{2}-\d{4})(?:\s+(.*))?$"#
              ),
              dateCapture.count == 2 else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: group.first?.sourceOrdinal ?? 0
            )
        }

        let dateText = dateCapture[0]
        do {
            _ = try StatementDate.axisNRE(dateText)
        } catch {
            throw AxisBankAccountPDFNormalizationError.malformedDate(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        let content = ([dateCapture[1]] + group.dropFirst().map(\.normalizedText))
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let tokens = content.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count >= 3 else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        guard let branch = tokens.last,
              branch.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw AxisBankAccountPDFNormalizationError.missingBranch(
                sourceOrdinal: first.sourceOrdinal
            )
        }
        let branchIndex = tokens.index(before: tokens.endIndex)
        guard branchIndex > tokens.startIndex else {
            throw AxisBankAccountPDFNormalizationError.missingBalance(
                sourceOrdinal: first.sourceOrdinal
            )
        }
        let balanceIndex = tokens.index(before: branchIndex)
        guard Self.isMoneyText(tokens[balanceIndex]) else {
            throw AxisBankAccountPDFNormalizationError.missingBalance(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        var selectedIndices: Set<Int> = [branchIndex, balanceIndex]
        var sourceDebit = ""
        var sourceCredit = ""
        var collapsedAmount = ""

        let beforeBalance = tokens[..<balanceIndex]
        guard !beforeBalance.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        let immediatelyBeforeBalance = beforeBalance.index(before: beforeBalance.endIndex)
        if tokens[immediatelyBeforeBalance] == "-",
           immediatelyBeforeBalance > beforeBalance.startIndex {
            let debitIndex = beforeBalance.index(before: immediatelyBeforeBalance)
            if Self.isMoneyText(tokens[debitIndex]) {
                sourceDebit = Self.canonicalMoneyText(tokens[debitIndex])
                selectedIndices.formUnion([debitIndex, immediatelyBeforeBalance])
            }
        } else if Self.isMoneyText(tokens[immediatelyBeforeBalance]) {
            if immediatelyBeforeBalance > beforeBalance.startIndex {
                let secondBeforeBalance = beforeBalance.index(before: immediatelyBeforeBalance)
                if tokens[secondBeforeBalance] == "-" {
                    sourceCredit = Self.canonicalMoneyText(tokens[immediatelyBeforeBalance])
                    selectedIndices.formUnion([secondBeforeBalance, immediatelyBeforeBalance])
                } else if Self.isMoneyText(tokens[secondBeforeBalance]) {
                    sourceDebit = Self.canonicalMoneyText(tokens[secondBeforeBalance])
                    sourceCredit = Self.canonicalMoneyText(tokens[immediatelyBeforeBalance])
                    selectedIndices.formUnion([secondBeforeBalance, immediatelyBeforeBalance])
                } else {
                    collapsedAmount = Self.canonicalMoneyText(tokens[immediatelyBeforeBalance])
                    selectedIndices.insert(immediatelyBeforeBalance)
                }
            } else {
                collapsedAmount = Self.canonicalMoneyText(tokens[immediatelyBeforeBalance])
                selectedIndices.insert(immediatelyBeforeBalance)
            }
        }

        if sourceDebit.isEmpty && sourceCredit.isEmpty && collapsedAmount.isEmpty {
            guard let amountIndex = beforeBalance.indices.reversed().first(where: {
                Self.isMoneyText(tokens[$0])
            }) else {
                throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                    sourceOrdinal: first.sourceOrdinal
                )
            }
            collapsedAmount = Self.canonicalMoneyText(tokens[amountIndex])
            selectedIndices.insert(amountIndex)
        }

        var narrativeTokens = tokens.indices.compactMap {
            selectedIndices.contains($0) ? nil : tokens[$0]
        }
        guard !narrativeTokens.contains(where: { Self.isMoneyText($0) }) else {
            throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                sourceOrdinal: first.sourceOrdinal
            )
        }
        var chequeReference = ""
        if let firstNarrativeToken = narrativeTokens.first,
           Self.isChequeReference(firstNarrativeToken) {
            chequeReference = firstNarrativeToken
            narrativeTokens.removeFirst()
        }
        let particulars = narrativeTokens.joined(separator: " ")
        guard !particulars.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        return ParsedTransaction(
            sourceOrdinal: first.sourceOrdinal,
            date: dateText,
            chequeReference: chequeReference,
            particulars: particulars,
            sourceDebit: sourceDebit,
            sourceCredit: sourceCredit,
            collapsedAmount: collapsedAmount,
            balance: Self.canonicalMoneyText(tokens[balanceIndex]),
            branchCode: branch
        )
    }

    private func rejectFinancialContent(
        in lines: [PhysicalLine],
        from startIndex: Int,
        to endIndex: Int
    ) throws {
        guard startIndex < endIndex else { return }

        for index in startIndex..<endIndex where lines.indices.contains(index) {
            let line = lines[index]
            if Self.looksFinancial(line.normalizedText) {
                throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                    sourceOrdinal: line.sourceOrdinal
                )
            }
        }
    }

    private static func startsWithDate(
        _ text: String
    ) -> Bool {
        text.range(
            of: #"^\d{2}-\d{2}-\d{4}(?:\s|$)"#,
            options: .regularExpression
        ) != nil
    }

    private static func startsWithDateLikeToken(
        _ text: String
    ) -> Bool {
        text.range(
            of: #"^(?:\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}|\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}(?:[-/.][A-Z]{3,9}[-/.]|\s+[A-Z]{3,9},?\s+)\d{2,4}|[A-Z]{3,9}\s+\d{1,2},?\s+\d{2,4})(?:\s|$|[,;:])"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func isChequeReference(
        _ token: String
    ) -> Bool {
        if token == "-" {
            return true
        }
        return (4...20).contains(token.count) &&
            token.allSatisfy({ $0.isASCII && $0.isNumber })
    }

    private static func isMoneyText(
        _ text: String
    ) -> Bool {
        text.range(
            of: #"^"# + moneyPattern + #"$"#,
            options: .regularExpression
        ) != nil
    }

    private static func canonicalMoneyText(
        _ text: String
    ) -> String {
        var value = text.replacingOccurrences(of: ",", with: "")
        if value.hasPrefix("-.") {
            value.insert("0", at: value.index(after: value.startIndex))
        } else if value.hasPrefix(".") {
            value.insert("0", at: value.startIndex)
        }
        return value
    }

    private static func looksLikeTableHeader(
        _ text: String
    ) -> Bool {
        let labels = [
            "Tran Date", "Chq No", "Particulars",
            "Debit", "Credit", "Balance", "Init."
        ]
        return labels.filter { text.contains($0) }.count >= 4
    }

    private static func startsIgnorableNonFinancialBlock(
        _ text: String
    ) -> Bool {
        text == "Legend" ||
            text == "Legend:" ||
            text == "++++ End of Statement ++++" ||
            text.range(
                of: #"^Page\s+[0-9]+\s+of\s+[0-9]+$"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
    }

    static func looksFinancial(
        _ text: String
    ) -> Bool {
        guard !text.isEmpty else { return false }
        if text.hasPrefix(openingPrefix) ||
            text.hasPrefix(totalPrefix) ||
            text.hasPrefix(closingPrefix) ||
            looksLikeTableHeader(text) {
            return true
        }
        if startsWithDateLikeToken(text) {
            return true
        }

        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        for token in tokens where looksLikeMoneyToken(token) {
            return true
        }
        return false
    }

    private static func looksLikeMoneyToken(
        _ token: String
    ) -> Bool {
        let decorations = CharacterSet(charactersIn: ",;:()[]{}₹$€£")
        let undecorated = token.trimmingCharacters(in: decorations)
        return !undecorated.isEmpty && isMoneyText(undecorated)
    }

    private static let splitHeader =
        "Tran Date Chq No Particulars Debit Credit Balance Init."
    private static let completeHeader =
        "Tran Date Chq No Particulars Debit Credit Balance Init. Br"
    private static let openingPrefix = "OPENING BALANCE"
    private static let totalPrefix = "TRANSACTION TOTAL"
    private static let closingPrefix = "CLOSING BALANCE"
    private static let moneyPattern =
        #"-?(?:(?:[0-9]{1,3}(?:,[0-9]{3})+)|[0-9]+)?\.[0-9]{2}"#
}

private extension String {
    var collapsingWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    func captures(
        matching pattern: String
    ) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: self,
                  range: NSRange(startIndex..., in: self)
              ),
              match.range == NSRange(startIndex..., in: self) else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: self) else {
                return ""
            }
            return String(self[range])
        }
    }
}
