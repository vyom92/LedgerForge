import Foundation

enum QatarAirwaysSalaryPDFParserError: Error, Equatable, LocalizedError {
    case unsupportedSource
    case unsupportedHeading
    case unsupportedKind
    case unsupportedCurrency
    case missingGeometry
    case ambiguousSectionOwnership
    case malformedMoney
    case incompleteEvidence
    case contradictoryTotals

    var errorDescription: String? {
        switch self {
        case .unsupportedSource: return "The PDF is not the exact supported Qatar Airways salary source."
        case .unsupportedHeading: return "The Qatar Airways salary headings are unsupported."
        case .unsupportedKind: return "The Qatar Airways salary document kind is unsupported."
        case .unsupportedCurrency: return "The Qatar Airways salary source must be denominated in QAR."
        case .missingGeometry: return "The salary source does not contain the required positioned text evidence."
        case .ambiguousSectionOwnership: return "A salary component cannot be assigned unambiguously to Earnings or Deductions."
        case .malformedMoney: return "The salary source contains malformed Money."
        case .incompleteEvidence: return "The salary source is missing required evidence."
        case .contradictoryTotals: return "The salary source totals are contradictory."
        }
    }
}

struct QatarAirwaysSalaryPDFParser {
    static let name = "Qatar Airways Salary PDF Parser"

    func canRecognize(_ rawDocument: RawDocument) -> Bool {
        guard rawDocument.fileExtension == "pdf" else { return false }
        let text = rawDocument.searchableText
        return text.contains("ispadmin@qatarairways.com.qa")
            && text.contains("Payment Details")
            && text.contains("Amount Transferred (QAR)")
            && (text.contains("Payslip for the month of")
                || text.contains("Salary for the month of")
                || text.contains("Adhoc Payment -")
                || text.contains("Annual Discretionary Bonus -"))
    }

    func parse(_ rawDocument: RawDocument) throws -> FinancialDocument {
        guard canRecognize(rawDocument) else { throw QatarAirwaysSalaryPDFParserError.unsupportedSource }
        guard rawDocument.searchableText.contains("Amount (QAR)") else {
            if rawDocument.searchableText.range(of: #"Amount\s*\([A-Z]{3}\)"#, options: .regularExpression) != nil {
                throw QatarAirwaysSalaryPDFParserError.unsupportedCurrency
            }
            throw QatarAirwaysSalaryPDFParserError.unsupportedHeading
        }
        guard let pageEvidence = rawDocument.pdfPageEvidence, let firstPage = pageEvidence.first else {
            throw QatarAirwaysSalaryPDFParserError.missingGeometry
        }

        let text = rawDocument.searchableText
        let title = try parseTitle(in: text)
        let printDate = try parsePrintDate(in: text)
        let components = try parseComponents(from: firstPage)
        let printedEarnings = try money(match: #"Total\s+Earnings\s+([0-9][0-9,]*\.[0-9]{2})"#, in: text)
        let printedDeductions: Money?
        if text.range(of: #"Total\s+Deductions"#, options: .regularExpression) != nil {
            printedDeductions = try money(match: #"Total\s+Deductions\s+([0-9][0-9,]*\.[0-9]{2})"#, in: text)
        } else {
            printedDeductions = nil
        }
        let printedNet = try money(
            match: #"Net\s+pay(?:\s+for\s+the\s+month\s+of\s+[A-Za-z]+\s+[0-9]{4})?:\s*\(QAR\)\s+([0-9][0-9,]*\.[0-9]{2})"#,
            in: text
        )
        let printedPayment = try money(match: #"Total\s+Amount\s+([0-9][0-9,]*\.[0-9]{2})"#, in: text)

        let currency = try CurrencyCode("QAR")
        let evidence: SalaryStatementEvidence
        do {
            evidence = try SalaryStatementEvidence(
                sourceAuthority: .qatarAirways,
                financialPeriod: title.period,
                printDate: printDate,
                kind: title.kind,
                nativeCurrency: currency,
                earnings: components.earnings,
                deductions: components.deductions,
                printedEarningsTotal: printedEarnings,
                printedDeductionsTotal: printedDeductions,
                printedNet: printedNet,
                printedPaymentTotal: printedPayment
            )
        } catch is SalaryStatementEvidence.ValidationError {
            throw QatarAirwaysSalaryPDFParserError.contradictoryTotals
        }

        var sourceDocument = Document(
            filename: rawDocument.fileName,
            url: rawDocument.sourceURL,
            fileType: "PDF",
            importedAt: rawDocument.extractedAt
        )
        sourceDocument.rowCount = evidence.earnings.count + evidence.deductions.count
        sourceDocument.institution = nil
        sourceDocument.parserVersion = SalaryStatementEvidence.profileVersion
        sourceDocument.confidence = 1.0
        let metadata = DocumentMetadata(
            institution: .unknown,
            documentType: .salarySlip,
            fileFormat: .pdf,
            confidence: 1.0
        )
        return FinancialDocument(
            sourceDocument: sourceDocument,
            metadata: metadata,
            parserName: Self.name,
            bookedCurrency: currency,
            transactions: [],
            salaryStatementEvidence: evidence,
            selectionReasons: ["Matched exact qatar-airways.salary.pdf@1 source evidence."]
        )
    }

    private func parseTitle(in text: String) throws -> (kind: SalaryDocumentKind, period: SelectedStatementMonth) {
        let candidates: [(SalaryDocumentKind, String)] = [
            (.regularSalary, #"(?:Payslip|Salary)\s+for\s+the\s+month\s+of\s+([A-Za-z]+)\s+([0-9]{4})"#),
            (.adhocPayment, #"Adhoc\s+Payment\s+-\s+([A-Za-z]+)\s+([0-9]{4})"#),
            (.annualDiscretionaryBonus, #"Annual\s+Discretionary\s+Bonus\s+-\s+([A-Za-z]+)\s+([0-9]{4})"#)
        ]
        let matches = candidates.compactMap { kind, pattern -> (SalaryDocumentKind, SelectedStatementMonth)? in
            guard let values = captures(pattern, in: text), values.count == 2,
                  let month = monthNumber(values[0]), let year = Int(values[1]),
                  let period = try? SelectedStatementMonth(year: year, month: month) else { return nil }
            return (kind, period)
        }
        guard matches.count == 1, let match = matches.first else {
            throw QatarAirwaysSalaryPDFParserError.unsupportedKind
        }
        return match
    }

    private func parsePrintDate(in text: String) throws -> StatementDate {
        guard let values = captures(#"Printed\s+by:.*?([0-9]{2}-[A-Za-z]{3}-[0-9]{4})"#, in: text),
              let value = values.first else {
            throw QatarAirwaysSalaryPDFParserError.incompleteEvidence
        }
        let parts = value.split(separator: "-")
        guard parts.count == 3, let day = Int(parts[0]), let month = monthNumber(String(parts[1])),
              let year = Int(parts[2]), let date = try? StatementDate(year: year, month: month, day: day) else {
            throw QatarAirwaysSalaryPDFParserError.incompleteEvidence
        }
        return date
    }

    private struct MutableComponent {
        var label: String
        let amount: Money
    }

    private func parseComponents(from page: RawPDFPageEvidence) throws -> (earnings: [SalaryComponent], deductions: [SalaryComponent]) {
        let rows = groupedRows(page.fragments)
        guard let headerIndex = rows.firstIndex(where: { rowText($0).contains("Earning Amount (QAR)") }),
              let totalIndex = rows.firstIndex(where: { rowText($0).contains("Total Earnings") }),
              headerIndex < totalIndex else {
            throw QatarAirwaysSalaryPDFParserError.unsupportedHeading
        }
        let header = rowText(rows[headerIndex])
        let sourceHasDeductions = header.contains("Deduction Amount (QAR)")
        let deductionColumnX = sourceHasDeductions
            ? rows[headerIndex].first(where: { $0.text == "Deduction" })?.x
            : nil
        if sourceHasDeductions && deductionColumnX == nil {
            throw QatarAirwaysSalaryPDFParserError.ambiguousSectionOwnership
        }
        var earnings: [MutableComponent] = []
        var deductions: [MutableComponent] = []

        for row in rows[(headerIndex + 1)..<totalIndex] {
            let earningTokens = row.filter { token in deductionColumnX.map { token.x < $0 } ?? true }.sorted { $0.x < $1.x }
            let deductionTokens = row.filter { token in deductionColumnX.map { token.x >= $0 } ?? false }.sorted { $0.x < $1.x }
            try consume(tokens: earningTokens, into: &earnings)
            try consume(tokens: deductionTokens, into: &deductions)
        }
        guard !earnings.isEmpty else { throw QatarAirwaysSalaryPDFParserError.incompleteEvidence }
        if sourceHasDeductions != !deductions.isEmpty {
            throw QatarAirwaysSalaryPDFParserError.ambiguousSectionOwnership
        }
        let finalizedEarnings = try earnings.enumerated().map {
            try SalaryComponent(side: .earning, sourceOrdinal: $0.offset + 1, sourceLabel: $0.element.label, money: $0.element.amount)
        }
        let finalizedDeductions = try deductions.enumerated().map {
            try SalaryComponent(side: .deduction, sourceOrdinal: $0.offset + 1, sourceLabel: $0.element.label, money: $0.element.amount)
        }
        return (finalizedEarnings, finalizedDeductions)
    }

    private func consume(
        tokens: [RawPDFTextFragment],
        into components: inout [MutableComponent]
    ) throws {
        guard !tokens.isEmpty else { return }
        let amountTokens = tokens.filter { isMoneyToken($0.text) }
        if amountTokens.count > 1 { throw QatarAirwaysSalaryPDFParserError.ambiguousSectionOwnership }
        if let amountToken = amountTokens.first {
            let label = tokens.filter { !isMoneyToken($0.text) }.map(\.text).joined(separator: " ")
            guard !label.isEmpty else { throw QatarAirwaysSalaryPDFParserError.ambiguousSectionOwnership }
            components.append(MutableComponent(label: label, amount: try parseMoney(amountToken.text)))
            return
        }
        let continuation = tokens.map(\.text).joined(separator: " ")
        guard !continuation.isEmpty else { return }
        guard !components.isEmpty,
              !continuation.contains("Earnings"), !continuation.contains("Deductions") else {
            throw QatarAirwaysSalaryPDFParserError.ambiguousSectionOwnership
        }
        components[components.count - 1].label += " " + continuation
    }

    private func groupedRows(_ fragments: [RawPDFTextFragment]) -> [[RawPDFTextFragment]] {
        let ordered = fragments.enumerated().sorted {
            let leftY = $0.element.geometry?.baselineY ?? $0.element.y
            let rightY = $1.element.geometry?.baselineY ?? $1.element.y
            if abs(leftY - rightY) > 1.5 { return leftY > rightY }
            return $0.element.x < $1.element.x
        }
        var rows: [[RawPDFTextFragment]] = []
        var currentY: Double?
        for item in ordered.map(\.element) {
            let y = item.geometry?.baselineY ?? item.y
            if let currentY, abs(currentY - y) <= 1.5 {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
                currentY = y
            }
        }
        return rows.map { $0.sorted { $0.x < $1.x } }
    }

    private func rowText(_ row: [RawPDFTextFragment]) -> String {
        row.sorted { $0.x < $1.x }.map(\.text).joined(separator: " ")
    }

    private func money(match pattern: String, in text: String) throws -> Money {
        guard let values = captures(pattern, in: text), let value = values.first else {
            throw QatarAirwaysSalaryPDFParserError.incompleteEvidence
        }
        return try parseMoney(value)
    }

    private func parseMoney(_ source: String) throws -> Money {
        guard isMoneyToken(source),
              let amount = Decimal(string: source.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) else {
            throw QatarAirwaysSalaryPDFParserError.malformedMoney
        }
        do { return try Money(amount: amount, currency: "QAR") }
        catch { throw QatarAirwaysSalaryPDFParserError.malformedMoney }
    }

    private func isMoneyToken(_ value: String) -> Bool {
        value.range(of: #"^[0-9]+(?:,[0-9]{3})*\.[0-9]{2}$"#, options: .regularExpression) != nil
    }

    private func captures(_ pattern: String, in text: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func monthNumber(_ value: String) -> Int? {
        let names = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
        let normalized = value.lowercased()
        if let index = names.firstIndex(of: normalized) { return index + 1 }
        return names.firstIndex(where: { $0.hasPrefix(normalized) }).map { $0 + 1 }
    }
}
