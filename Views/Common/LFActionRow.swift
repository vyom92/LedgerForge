//
//  LFActionRow.swift
//  LedgerForge
//

import SwiftUI

struct LFActionRow: View {
    let title: String
    let systemImage: String
    var color: Color = LFTheme.text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 20)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(LFTheme.textSecondary)
            }
            .font(.subheadline)
            .foregroundStyle(color)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }
}
