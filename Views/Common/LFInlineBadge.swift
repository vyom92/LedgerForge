//
//  LFInlineBadge.swift
//  LedgerForge
//

import SwiftUI

struct LFInlineBadge: View {
    @Environment(\.lfTheme) private var theme
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
        }
        .font(theme.typography.formCaption)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(theme.palette.raisedSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
    }
}
