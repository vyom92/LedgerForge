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
            Text("⌘K")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.05))
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
    }
}
