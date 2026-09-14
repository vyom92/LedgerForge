//
//  LFTheme.swift
//  LedgerForge
//

import SwiftUI
import AppKit
import CoreText

/// Presentation values only. One dark value is supplied at the app root.
/// Resolved from the single app-owned appearance preference value.
struct LFTheme: Sendable {
    var palette = Palette()
    var typography = Typography()
    var spacing = Spacing()
    var radius = Radius()
    var materials = Materials()
    var interaction: InteractionStates { InteractionStates(palette: palette) }

    static let dark = LFTheme()

    struct Palette: Sendable {
        // Owner's rendered native calibration. Opaque surfaces use these values.
        var canvas = Color(hex: 0x0F1324)
        var contentSurface = Color(hex: 0x191F32)
        var controlSurface = Color(hex: 0x1D2235)
        var raisedSurface = Color(hex: 0x252D41)
        var secondaryAction = Color(hex: 0x3F4251)
        var navigationSelected = Color(hex: 0x3A3274)
        var primaryText = Color(hex: 0xF4F6FE)

        // Unmeasured roles retain the current native candidate's values.
        var secondaryText = Color(hex: 0xABB7C9)
        var tertiaryText: Color { secondaryText.opacity(0.65) }
        var accent = Color(hex: 0x7C4DFF)
        var accentHover = Color(hex: 0x9A68FF)
        var dataSelection = Color(hex: 0x3B4C71)
        var dataSelectionInactive = Color(hex: 0x3B4C71)
        var actionGradientEnd = Color(hex: 0x4338CA)
        var border = Color.white.opacity(0.11)
        var divider = Color.white.opacity(0.08)
        var fieldBorder = Color(hex: 0x77869C)
        var tableBorder = Color(hex: 0x38445A)
        var focusRing = Color(hex: 0xB2A3FF)
        var institutionMark = Color(hex: 0xB0165B)

        var contentSurfaceAlternate: Color { raisedSurface.opacity(0.70) }
        var inspectorSurface = Color(hex: 0x191F32)
        var disabledAction: Color { secondaryAction.opacity(0.55) }
        var primaryAction: LinearGradient {
            LinearGradient(colors: [accent, actionGradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        var panelEdge: LinearGradient {
            LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    struct Typography: Sendable {
        var family: String?
        var sizes: [LFFontRole: Double] = [:]

        func size(_ role: LFFontRole) -> CGFloat { CGFloat(sizes[role] ?? role.approvedSize) }

        /// Rendering and native measurement use this exact descriptor, including
        /// weight and tabular digits. No separate AppKit measurement font exists.
        func nativeFont(_ role: LFFontRole, tabularDigits: Bool = false) -> NSFont {
            let pointSize = size(role)
            let usesTabularDigits = tabularDigits || role.usesTabularDigits
            guard let family else {
                return usesTabularDigits
                    ? NSFont.monospacedDigitSystemFont(ofSize: pointSize, weight: role.weight)
                    : NSFont.systemFont(ofSize: pointSize, weight: role.weight)
            }
            var attributes: [NSFontDescriptor.AttributeName: Any] = [
                .family: family, .traits: [NSFontDescriptor.TraitKey.weight: role.weight.rawValue]
            ]
            if usesTabularDigits {
                attributes[.featureSettings] = [[
                    NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                    NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector
                ]]
            }
            return NSFont(descriptor: NSFontDescriptor(fontAttributes: attributes), size: pointSize)
                ?? NSFont.systemFont(ofSize: pointSize, weight: role.weight)
        }

        func font(_ role: LFFontRole, tabularDigits: Bool = false) -> Font {
            Font(nativeFont(role, tabularDigits: tabularDigits))
        }
        func lineHeight(_ role: LFFontRole) -> CGFloat {
            let font = nativeFont(role)
            return ceil(font.ascender - font.descender + font.leading)
        }
        var tableRowMinimum: CGFloat {
            max(lineHeight(.tableBody) + lineHeight(.caption) + 3,
                max(lineHeight(.tableMoney), lineHeight(.secondary))) + 12
        }
        var compactControlMinimum: CGFloat { max(32, lineHeight(.secondary) + 12) }
        var pageTitle: Font { font(.pageTitle) }
        var sectionTitle: Font { font(.sectionTitle) }
        var headlineMoney: Font { font(.headlineMoney) }
        var rowTitle: Font { font(.rowTitle) }
        var body: Font { font(.body) }
        var secondary: Font { font(.secondary) }
        var caption: Font { font(.caption) }
        var button: Font { font(.button) }
        var tableBody: Font { font(.tableBody) }
        var tableMoney: Font { font(.tableMoney) }
        var tableSummary: Font { font(.tableSummary) }
        var formTitle: Font { font(.formTitle) }
        var formSection: Font { font(.formSection) }
        var formHeading: Font { font(.formHeading) }
        var formBody: Font { font(.formBody) }
        var formCallout: Font { font(.formCallout) }
        var formCaption: Font { font(.formCaption) }
        var finePrint: Font { font(.finePrint) }
        var tableSortIcon = Font.system(size: 10, weight: .medium)
        var tableSelectionMark = Font.system(size: 10, weight: .bold)
        var domainIcon = Font.system(size: 28)
        var sectionIcon = Font.system(size: 18)
        var panelIcon = Font.system(size: 24, weight: .medium)
        var emptyStateIcon = Font.system(size: 34)
        var dropTargetIcon = Font.system(size: 42, weight: .light)
        var diagnosticText = Font.system(.caption, design: .monospaced)
        var diagnosticDetail = Font.system(.caption2, design: .monospaced)
    }

    struct Spacing: Sendable {
        var micro: CGFloat = 4
        var small: CGFloat = 8
        var rowGap: CGFloat = 8
        var controlGap: CGFloat = 12
        var sectionGap: CGFloat = 16
        var panelPadding: CGFloat = 16
        var pagePadding: CGFloat = 24
        var valueGutter: CGFloat = 24
        var majorModuleGap: CGFloat = 32
        var expandedSidebarWidth: CGFloat = 208
        var expandedSidebarPadding: CGFloat = 12
        var railWidth: CGFloat = 64
        var railPadding: CGFloat = 10
    }

    struct Radius: Sendable {
        var control: CGFloat = 6
        var panel: CGFloat = 10
        var popover: CGFloat = 12
    }

    struct Materials: Sendable {
        var content: Material = .regular
        // Calibrated wash over regular material, not sampled #252D41 given a
        // second opacity. Native material still responds to its surroundings.
        var cardWash = Color(hex: 0x273349)
        var cardWeight = 0.70
        var inspectorWeight = 0.86
        var shadow = Color.black.opacity(0.16)
        var backgroundWeight = 0.86
        var sidebarStartWeight = 0.84
        var sidebarEndWeight = 0.82
        var chromeStart = Color(hex: 0x091125)
        var chromeEnd = Color(hex: 0x151D2E)
        var sidebarStart = Color(hex: 0x182139)
        var sidebarEnd = Color(hex: 0x222E48)
        var chromeTint: LinearGradient {
            LinearGradient(colors: [chromeStart.opacity(backgroundWeight), chromeEnd.opacity(backgroundWeight)], startPoint: .top, endPoint: .bottom)
        }
        var sidebarTint: LinearGradient {
            LinearGradient(colors: [sidebarStart.opacity(sidebarStartWeight), sidebarEnd.opacity(sidebarEndWeight)], startPoint: .top, endPoint: .bottom)
        }
    }

    struct InteractionStates: Sendable {
        let palette: Palette
        var navigationSelected: Color { palette.navigationSelected }
        var navigationHover: Color { Color.white.opacity(0.08) }
        var navigationEdge: Color { palette.accentHover.opacity(0.65) }
        var dataRowNormal: Color { palette.contentSurface }
        var dataRowAlternate: Color { palette.contentSurfaceAlternate }
        // 63/66/81 was sampled on Hide details, not the selected data row.
        var dataRowSelectedActive: Color { palette.dataSelection.opacity(0.92) }
        var dataRowSelectedInactive: Color { palette.dataSelectionInactive.opacity(0.62) }
        var dataRowHover: Color { palette.raisedSurface }
        var dataBadge: Color { palette.dataSelection.opacity(0.45) }
        var dataIcon: Color { palette.dataSelection.opacity(0.55) }
        var focusRing: Color { palette.focusRing }

        func dataRow(selected: Bool, active: Bool, alternate: Bool = false, hovered: Bool = false) -> Color {
            if selected { return active ? dataRowSelectedActive : dataRowSelectedInactive }
            if hovered { return dataRowHover }
            return alternate ? dataRowAlternate : dataRowNormal
        }
    }

    // Semantic meanings also serve non-View presentation enums. Do not inject
    // visual environment state into financial or workflow models.
    static let success = Color(hex: 0x22C55E)
    static let danger = Color(hex: 0xEF4444)
    static let warning = Color(hex: 0xF59E0B)
    static let info = Color(hex: 0x38BDF8)
}

private struct LFThemeKey: EnvironmentKey {
    static let defaultValue = LFTheme.dark
}

extension EnvironmentValues {
    var lfTheme: LFTheme {
        get { self[LFThemeKey.self] }
        set { self[LFThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
