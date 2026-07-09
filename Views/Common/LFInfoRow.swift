//
//  LFInfoRow.swift
//  LedgerForge
//

import SwiftUI

struct LFInfoRow: View {
    let title: String
    let value: String
    var titleWidth: CGFloat? = nil
    var verticalPadding: CGFloat = 6

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: titleWidth, alignment: .leading)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
        .padding(.vertical, verticalPadding)
    }
}
