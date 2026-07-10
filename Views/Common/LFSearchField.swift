//
//  LFSearchField.swift
//  LedgerForge
//

import SwiftUI

struct LFSearchField: View {
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LFTheme.textSecondary)
            Text(placeholder)
                .font(.subheadline)
                .foregroundStyle(LFTheme.textSecondary)
            Spacer()
            Text("Pending")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(LFTheme.surfaceRaised.opacity(LFTheme.placeholderOpacity))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LFTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(LFTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(LFTheme.placeholderOpacity)
        .help("Search is planned for a future sprint.")
    }
}
