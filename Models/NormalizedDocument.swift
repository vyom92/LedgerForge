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

    let document: Document

    let metadata: DocumentMetadata

    let rows: [NormalizedRow]

}
