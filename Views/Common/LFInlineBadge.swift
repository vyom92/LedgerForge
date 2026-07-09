//
//  LFInlineBadge.swift
//  LedgerForge
//

import SwiftUI

struct LFInlineBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(LFTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
