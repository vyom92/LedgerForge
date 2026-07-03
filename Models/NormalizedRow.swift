//
//  NormalizedRow.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//


//
// LedgerForge
// NormalizedRow.swift
// Version: 0.1.0
//

import Foundation

struct NormalizedRow: Identifiable {

    let id = UUID()

    /// Original row number in the imported document.
    let rowNumber: Int

    /// Column values in display order.
    let values: [String]

}
