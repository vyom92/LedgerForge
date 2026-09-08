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

import CryptoKit
import Foundation

struct NormalizedDocument {

    nonisolated enum SourceEvidenceError: Error, Equatable {
        case malformedFinancialRegion
        case malformedPrintedBankControls
    }

    /// Parser-profile-neutral proof that a normalizer completely classified a
    /// source-defined financial region. The source-unit and bounds are
    /// provenance only; cross-carrier semantic identity never depends on them.
    nonisolated struct ExhaustedFinancialRegionEvidence: Equatable, Sendable {
        static let signatureAlgorithm = "ledgerforge.financial-region.sha256.v1"

        let descriptor: String
        let sourceUnit: FinancialRegionSourceUnit
        let startOrdinal: Int
        let endOrdinal: Int
        let recognizedFinancialRowCount: Int
        let signature: String

        init(
            descriptor: String,
            sourceUnit: FinancialRegionSourceUnit,
            startOrdinal: Int,
            endOrdinal: Int,
            recognizedFinancialRowCount: Int,
            sourceRecords: [String]
        ) throws {
            let descriptor = descriptor.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !descriptor.isEmpty, startOrdinal > 0, endOrdinal >= startOrdinal,
                  recognizedFinancialRowCount >= 0, !sourceRecords.isEmpty else {
                throw SourceEvidenceError.malformedFinancialRegion
            }
            self.descriptor = descriptor
            self.sourceUnit = sourceUnit
            self.startOrdinal = startOrdinal
            self.endOrdinal = endOrdinal
            self.recognizedFinancialRowCount = recognizedFinancialRowCount
            let fields = [
                Self.signatureAlgorithm, sourceUnit.rawValue,
                String(startOrdinal), String(endOrdinal),
                String(recognizedFinancialRowCount)
            ] + sourceRecords
            let payload = fields.map { "\($0.utf8.count):\($0)" }.joined()
            self.signature = SHA256.hash(data: Data(payload.utf8))
                .map { String(format: "%02x", $0) }
                .joined()
        }

        func matches(normalizedFinancialRowCount: Int) -> Bool {
            recognizedFinancialRowCount == normalizedFinancialRowCount &&
                signature.utf8.count == 64 &&
                signature.unicodeScalars.allSatisfy {
                    CharacterSet(charactersIn: "0123456789abcdef").contains($0)
                }
        }
    }

    /// Actual printed bank-statement controls retained independently from
    /// normalized transaction rows. In particular, an empty transaction table
    /// cannot erase the source's opening/total/closing controls.
    nonisolated struct PrintedBankStatementControls: Equatable, Sendable {
        let profileID: String
        let profileVersion: String
        let sourceFormatCode: String
        let openingBalance: Money
        let debitTotal: Money
        let creditTotal: Money
        let closingBalance: Money
        let openingSourceOrdinal: Int
        let totalsSourceOrdinal: Int
        let closingSourceOrdinal: Int

        init(
            profileID: String,
            profileVersion: String,
            sourceFormatCode: String,
            openingBalance: Money,
            debitTotal: Money,
            creditTotal: Money,
            closingBalance: Money,
            openingSourceOrdinal: Int,
            totalsSourceOrdinal: Int,
            closingSourceOrdinal: Int
        ) throws {
            let values = [openingBalance, debitTotal, creditTotal, closingBalance]
            guard !profileID.isEmpty, !profileVersion.isEmpty, !sourceFormatCode.isEmpty,
                  Set(values.map(\.currency)).count == 1,
                  openingSourceOrdinal > 0,
                  openingSourceOrdinal < totalsSourceOrdinal,
                  totalsSourceOrdinal < closingSourceOrdinal else {
                throw SourceEvidenceError.malformedPrintedBankControls
            }
            self.profileID = profileID
            self.profileVersion = profileVersion
            self.sourceFormatCode = sourceFormatCode
            self.openingBalance = openingBalance
            self.debitTotal = debitTotal
            self.creditTotal = creditTotal
            self.closingBalance = closingBalance
            self.openingSourceOrdinal = openingSourceOrdinal
            self.totalsSourceOrdinal = totalsSourceOrdinal
            self.closingSourceOrdinal = closingSourceOrdinal
        }
    }

    struct SourceFragment {

        let sourceOrdinal: Int

        let text: String

    }

    struct SourceContext {

        let preTransactionFragments: [SourceFragment]

        let postTransactionFragments: [SourceFragment]

        let exhaustedFinancialRegion: ExhaustedFinancialRegionEvidence?

        let printedBankStatementControls: PrintedBankStatementControls?

        init(
            preTransactionFragments: [SourceFragment],
            postTransactionFragments: [SourceFragment] = [],
            exhaustedFinancialRegion: ExhaustedFinancialRegionEvidence? = nil,
            printedBankStatementControls: PrintedBankStatementControls? = nil
        ) {
            self.preTransactionFragments = preTransactionFragments
            self.postTransactionFragments = postTransactionFragments
            self.exhaustedFinancialRegion = exhaustedFinancialRegion
            self.printedBankStatementControls = printedBankStatementControls
        }

        static let empty = SourceContext(preTransactionFragments: [])

    }

    let document: Document

    let metadata: DocumentMetadata

    /// Parser-profile identity selected from source evidence.  Generic
    /// readers may leave this nil; a parser-produced zero-activity document
    /// must carry the exact registered profile into FinancialDocument.
    let parserProfileID: String?

    let parserProfileVersion: String?

    let rows: [NormalizedRow]

    let header: NormalizedRow?

    let sourceContext: SourceContext

    init(
        document: Document,
        metadata: DocumentMetadata,
        parserProfileID: String? = nil,
        parserProfileVersion: String? = nil,
        rows: [NormalizedRow],
        header: NormalizedRow? = nil,
        sourceContext: SourceContext = .empty
    ) {
        self.document = document
        self.metadata = metadata
        self.parserProfileID = parserProfileID
        self.parserProfileVersion = parserProfileVersion
        self.rows = rows
        self.header = header
        self.sourceContext = sourceContext
    }

}
