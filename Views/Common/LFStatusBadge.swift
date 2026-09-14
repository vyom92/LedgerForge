//
//  LFStatusBadge.swift
//  LedgerForge
//

import SwiftUI

struct LFStatusBadge: View {
    @Environment(\.lfTheme) private var theme
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(theme.typography.finePrint.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
    }
}
