//
//  LFConsoleButton.swift
//  LedgerForge
//

import SwiftUI

struct LFConsoleButton: View {
    @Environment(\.lfTheme) private var theme
    let title: String
    let systemImage: String
    var minWidth: CGFloat? = nil
    var fill: Color
    var foreground: Color? = nil
    var isFullWidth: Bool = false
    var showsBorder: Bool = true
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(theme.typography.button)
                .frame(minWidth: minWidth)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(foreground ?? theme.palette.primaryText)
                .background(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.control)
                        .stroke(borderColor, lineWidth: showsBorder || isFocused ? 1 : 0)
                )
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
                .contentShape(RoundedRectangle(cornerRadius: theme.radius.control))
        }
        .buttonStyle(LFPlainActionStyle())
        .focused($isFocused)
        .focusable(!isDisabled)
        .onHover { isHovered = $0 }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .accessibilityLabel(Text(title))
    }

    private var backgroundFill: Color {
        guard isHovered && !isDisabled else {
            return fill
        }
        return fill.opacity(0.82)
    }

    private var borderColor: Color {
        isFocused ? theme.palette.accentHover : theme.palette.border
    }
}
