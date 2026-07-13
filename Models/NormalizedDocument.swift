//
//  NormalizedDocument.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//


//
// LedgerForge
// NormalizedDocument.swift
// Version: 0.1.0
//

import Foundation

struct NormalizedDocument {

    struct SourceFragment {

        let sourceOrdinal: Int

        let text: String

    }

    struct SourceContext {

        let preTransactionFragments: [SourceFragment]

        static let empty = SourceContext(preTransactionFragments: [])

    }

    let document: Document

    let metadata: DocumentMetadata

    let rows: [NormalizedRow]

    let sourceContext: SourceContext

    init(
        document: Document,
        metadata: DocumentMetadata,
        rows: [NormalizedRow],
        sourceContext: SourceContext = .empty
    ) {
        self.document = document
        self.metadata = metadata
        self.rows = rows
        self.sourceContext = sourceContext
    }

}
