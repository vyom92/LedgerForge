import Foundation

struct AxisBaselineExpectation: Decodable {
    let institution: String
    let accountType: String
    let currency: String
    let expectedParser: String
    let transactionCount: Int
    let debitTotal: String
    let creditTotal: String
    let rawDRColumnTotal: String
    let rawCRColumnTotal: String
    let openingBalance: String
    let closingBalance: String
    let firstTransactionDate: String
    let lastTransactionDate: String
    let validationResult: String
    let notes: [String]

    static func axisBankNREBaseline() throws -> AxisBaselineExpectation {
        let url = FixtureLocator.axisExpected("axis_bank_nre_account_statement_baseline.expected.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AxisBaselineExpectation.self, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case institution
        case accountType = "account_type"
        case currency
        case expectedParser = "expected_parser"
        case transactionCount = "transaction_count"
        case debitTotal = "debit_total"
        case creditTotal = "credit_total"
        case rawDRColumnTotal = "raw_dr_column_total"
        case rawCRColumnTotal = "raw_cr_column_total"
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
        case firstTransactionDate = "first_transaction_date"
        case lastTransactionDate = "last_transaction_date"
        case validationResult = "validation_result"
        case notes
    }
}
