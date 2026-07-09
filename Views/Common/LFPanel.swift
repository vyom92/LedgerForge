//
//  LFPanel.swift
//  LedgerForge
//

import SwiftUI

struct LFPanel<Content: View>: View {
    let title: String?
    let trailing: AnyView?
    @ViewBuilder let content: Content

    init(title: String? = nil, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || trailing != nil {
                HStack {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    Spacer()
                    trailing
                }
            }

            content
        }
        .padding(16)
        .background(LFTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(LFTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
