//
//  LFEmptyState.swift
//  LedgerForge
//

import SwiftUI

struct LFEmptyState: View {
    let title: String
    let message: String
    let actionTitle: String?
    let systemImage: String
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        actionTitle: String? = nil,
        systemImage: String,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(LFTheme.primaryHover)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LFTheme.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(LFTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

struct LFCompactEmptyState: View {
    let message: String
    var minHeight: CGFloat = 80

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(LFTheme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
    }
}
