//
//  LFIconTile.swift
//  LedgerForge
//

import SwiftUI

struct LFIconTile: View {
    @Environment(\.lfTheme) private var theme
    let systemImage: String
    let color: Color
    var size: CGFloat = 34
    var cornerRadius: CGFloat? = nil
    var foregroundColor: Color = .white
    var opacity: Double = 0.85

    var body: some View {
        Image(systemName: systemImage)
            .foregroundStyle(foregroundColor)
            .frame(width: size, height: size)
            .background(color.opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? theme.radius.control))
    }
}
