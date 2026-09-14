//
//  LFFilterChip.swift
//  LedgerForge
//

import SwiftUI

struct LFFilterChip: View {
    @Environment(\.lfTheme) private var theme
    let title: String
    var value: String? = nil
    var width: CGFloat? = nil
    var surface: Color? = nil
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            if let value {
                Text(value)
                    .foregroundStyle(theme.palette.primaryText)
            }
            Spacer(minLength: value == nil ? 0 : 8)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(theme.typography.finePrint)
            }
        }
        .font(theme.typography.formCaption)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: width)
        .background(surface ?? theme.palette.controlSurface)
        .overlay(RoundedRectangle(cornerRadius: theme.radius.control).stroke(theme.palette.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
    }
}
