protocol StatementParser {

    var institution: String { get }

    func canParse(_ document: Document) -> Bool

    func parse(_ document: Document) throws -> [Transaction]

}
