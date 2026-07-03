final class StatementParserRegistry {

    static let shared = StatementParserRegistry()

    private let parsers: [StatementParser] = [

        AxisStatementParser(),

        UnknownStatementParser()

    ]

}
