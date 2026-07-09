//
//  LFFilterChip.swift
//  LedgerForge
//

import SwiftUI

struct LFFilterChip: View {
    let title: String
    var value: String? = nil
    var width: CGFloat? = nil
    var surface: Color = LFTheme.surface
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            if let value {
                Text(value)
                    .foregroundStyle(LFTheme.text)
            }
            Spacer(minLength: value == nil ? 0 : 8)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: width)
        .background(surface)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(LFTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
