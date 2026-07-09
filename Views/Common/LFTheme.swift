//
//  LFTheme.swift
//  LedgerForge
//

import SwiftUI

enum LFTheme {
    static let background = Color(hex: 0x0B0F19)
    static let backgroundDeep = Color(hex: 0x07101E)
    static let surface = Color(hex: 0x111827).opacity(0.78)
    static let surfaceRaised = Color(hex: 0x1A2233).opacity(0.72)
    static let border = Color.white.opacity(0.11)
    static let divider = Color.white.opacity(0.08)
    static let primary = Color(hex: 0x7C4DFF)
    static let primaryHover = Color(hex: 0x9A68FF)
    static let success = Color(hex: 0x22C55E)
    static let danger = Color(hex: 0xEF4444)
    static let warning = Color(hex: 0xF59E0B)
    static let info = Color(hex: 0x38BDF8)
    static let text = Color(hex: 0xF3F6FF)
    static let textSecondary = Color(hex: 0x9AA4B2)

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: 0x07101E),
            Color(hex: 0x0B1326),
            Color(hex: 0x0B0F19)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        colors: [primary, Color(hex: 0x4338CA)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
