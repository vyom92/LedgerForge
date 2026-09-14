//
//  LFEmptyState.swift
//  LedgerForge
//

import SwiftUI

struct LFEmptyState: View {
    @Environment(\.lfTheme) private var theme
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
                .font(theme.typography.emptyStateIcon)
                .foregroundStyle(theme.palette.accentHover)
            Text(title)
                .font(theme.typography.formHeading)
            Text(message)
                .font(theme.typography.formBody)
                .foregroundStyle(theme.palette.secondaryText)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(theme.palette.primaryAction)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

struct LFCompactEmptyState: View {
    @Environment(\.lfTheme) private var theme
    let message: String
    var minHeight: CGFloat = 80

    var body: some View {
        Text(message)
            .font(theme.typography.formCaption)
            .foregroundStyle(theme.palette.secondaryText)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
    }
}
