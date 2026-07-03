//
// LedgerForge
// StatementParserRegistry.swift
// Version: 0.0.5
//

import Foundation

final class StatementParserRegistry {

    static let shared = StatementParserRegistry()

    private let parsers: [StatementParser]

    private init() {

        parsers = [

            AxisBankAccountParser()

        ]

    }

    func parser(
        for document: Document,
        metadata: DocumentMetadata
    ) -> StatementParser? {

        parsers.first {
            $0.canParse(document: document,
                        metadata: metadata)
        }

    }

}
