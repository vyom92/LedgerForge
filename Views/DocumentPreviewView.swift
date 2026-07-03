//
//  DocumentPreviewView.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//


//
// LedgerForge
// DocumentPreviewView.swift
// Version: 0.0.7
//

import SwiftUI

struct DocumentPreviewView: View {

    @ObservedObject var store = DocumentStore.shared

    var body: some View {

        VStack(alignment: .leading) {

            Text("Document Preview")
                .font(.headline)

            Divider()

            ScrollView {

                LazyVStack(alignment: .leading, spacing: 4) {

                    ForEach(Array(store.rows.prefix(100).enumerated()),
                            id: \.offset) { index, row in

                        HStack(alignment: .top) {

                            Text("\(index + 1)")
                                .frame(width: 40, alignment: .trailing)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            Text(row)
                                .font(.system(.body,
                                              design: .monospaced))
                                .frame(maxWidth: .infinity,
                                       alignment: .leading)

                        }

                    }

                }

            }

        }
        .padding()

    }

}

#Preview {
    DocumentPreviewView()
}
