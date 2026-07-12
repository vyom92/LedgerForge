//
//  LFConsoleButton.swift
//  LedgerForge
//

import SwiftUI

struct LFConsoleButton: View {
    let title: String
    let systemImage: String
    var minWidth: CGFloat? = nil
    var fill: Color
    var foreground: Color = LFTheme.text
    var isFullWidth: Bool = false
    var showsBorder: Bool = true
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(minWidth: minWidth)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(foreground)
                .background(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(borderColor, lineWidth: showsBorder || isFocused ? 1 : 0)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
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
        isFocused ? LFTheme.primaryHover : LFTheme.border
    }
}
