//
//  LFIconTile.swift
//  LedgerForge
//

import SwiftUI

struct LFIconTile: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 34
    var cornerRadius: CGFloat = 7
    var foregroundColor: Color = .white
    var opacity: Double = 0.85

    var body: some View {
        Image(systemName: systemImage)
            .foregroundStyle(foregroundColor)
            .frame(width: size, height: size)
            .background(color.opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
