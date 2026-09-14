//
//  LFActionRow.swift
//  LedgerForge
//

import SwiftUI

struct LFActionRow: View {
    @Environment(\.lfTheme) private var theme
    let title: String
    let systemImage: String
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 20)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(theme.typography.finePrint)
                    .foregroundStyle(theme.palette.secondaryText)
            }
            .font(theme.typography.formBody)
            .foregroundStyle(color ?? theme.palette.primaryText)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }
}
