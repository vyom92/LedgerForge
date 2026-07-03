//
// LedgerForge
// DocumentMetadata.swift
// Version: 0.1.0
//

import Foundation

enum Institution: String, CaseIterable {

    case axis = "Axis Bank"
    case hdfc = "HDFC Bank"
    case cbq = "Commercial Bank of Qatar"
    case amex = "American Express"

    case unknown = "Unknown"

}

enum DocumentType: String, CaseIterable {

    case bankAccount = "Bank Account"
    case creditCard = "Credit Card"
    case salarySlip = "Salary Slip"
    case investment = "Investment"
    case tax = "Tax"
    case unknown = "Unknown"

}

enum FileFormat: String, CaseIterable {

    case csv = "CSV"
    case pdf = "PDF"
    case xls = "XLS"
    case xlsx = "XLSX"

    case unknown = "Unknown"

}

struct DocumentMetadata {

    let institution: Institution

    let documentType: DocumentType

    let fileFormat: FileFormat

    let confidence: Double

}
