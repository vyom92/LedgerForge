import AppKit
import Combine
import CoreFoundation
import SwiftUI

/// Only nonfinancial interface overrides live here. The approved source colors
/// already use sRGB; the owner's rendered meter readings are not reinterpreted.
struct LFAppearanceColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 255) / 255
        green = Double((hex >> 8) & 255) / 255
        blue = Double(hex & 255) / 255
    }

    init?(components: [String: Any]) {
        guard components["space"] as? String == "sRGB",
              let r = Self.number(components["red"]),
              let g = Self.number(components["green"]),
              let b = Self.number(components["blue"]),
              [r, g, b].allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        red = r; green = g; blue = b
    }

    static func number(_ raw: Any?) -> Double? {
        guard let value = raw as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
        return value.doubleValue
    }

    init?(color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        red = Double(rgb.redComponent); green = Double(rgb.greenComponent); blue = Double(rgb.blueComponent)
    }

    private init(red: Double, green: Double, blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }
    var components: [String: Any] { ["space": "sRGB", "red": red, "green": green, "blue": blue] }

    /// Retain the approved differences between related surface variants.
    func offset(_ r: Double, _ g: Double, _ b: Double) -> Self {
        Self(red: min(1, max(0, red + r / 255)), green: min(1, max(0, green + g / 255)), blue: min(1, max(0, blue + b / 255)))
    }

    func mixedWithWhite(_ fraction: Double) -> Color {
        Color(.sRGB, red: red + (1 - red) * fraction, green: green + (1 - green) * fraction, blue: blue + (1 - blue) * fraction)
    }
}

enum LFAppearanceColorRole: String, CaseIterable, Identifiable {
    case accent, background, navigationHeader, card, raisedInspector, inputControl
    case primaryText, secondaryText, navigationSelection, selectedFocused, selectedUnfocused
    var id: String { rawValue }
    var title: String {
        switch self {
        case .accent: "Accent"
        case .background: "Window / content tint"
        case .navigationHeader: "Navigation / header tint"
        case .card: "Standard card"
        case .raisedInspector: "Raised / inspector"
        case .inputControl: "Input / neutral control"
        case .primaryText: "Primary text"
        case .secondaryText: "Secondary text"
        case .navigationSelection: "Selected navigation"
        case .selectedFocused: "Selected row · focused"
        case .selectedUnfocused: "Selected row · unfocused"
        }
    }
    var approved: LFAppearanceColor {
        let hex: UInt32
        switch self {
        case .accent: hex = 0x7C4DFF
        case .background: hex = 0x151D2E
        case .navigationHeader: hex = 0x091125
        case .card: hex = 0x273349
        case .raisedInspector: hex = 0x252D41
        case .inputControl: hex = 0x3F4251
        case .primaryText: hex = 0xF4F6FE
        case .secondaryText: hex = 0xABB7C9
        case .navigationSelection: hex = 0x3A3274
        case .selectedFocused, .selectedUnfocused: hex = 0x3B4C71
        }
        return LFAppearanceColor(hex: hex)
    }
}

enum LFFontRole: String, CaseIterable, Identifiable, Sendable {
    case pageTitle, sectionTitle, headlineMoney, rowTitle, body, secondary, caption, button
    case tableBody, tableMoney, tableSummary
    case formTitle, formSection, formHeading, formBody, formCallout, formCaption, finePrint
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pageTitle: "Page title"
        case .sectionTitle: "Section title"
        case .headlineMoney: "Headline financial value"
        case .rowTitle: "Row title"
        case .body: "Body text"
        case .secondary: "Supporting text"
        case .caption: "Caption"
        case .button: "Action label"
        case .tableBody: "Table body"
        case .tableMoney: "Table amount"
        case .tableSummary: "Table summary value"
        case .formTitle: "Form title"
        case .formSection: "Form section"
        case .formHeading: "Form heading"
        case .formBody: "Form body"
        case .formCallout: "Form callout"
        case .formCaption: "Form supporting text"
        case .finePrint: "Form detail"
        }
    }
    var approvedSize: Double {
        switch self {
        case .pageTitle, .headlineMoney: 28
        case .sectionTitle: 20
        case .rowTitle, .body: 16
        case .secondary, .button, .formHeading: 13
        case .caption, .formCallout: 12
        case .tableBody, .tableMoney: 14
        case .tableSummary: 18
        case .formTitle: 17
        case .formSection: 15
        case .formBody: 11
        case .formCaption, .finePrint: 10
        }
    }
    var weight: NSFont.Weight {
        switch self {
        case .pageTitle, .sectionTitle, .headlineMoney, .tableSummary: .semibold
        case .rowTitle, .button, .tableMoney, .finePrint: .medium
        case .formHeading: .bold
        default: .regular
        }
    }
    var usesTabularDigits: Bool { self == .headlineMoney || self == .tableMoney || self == .tableSummary }
}

struct LFAppearanceOverrides {
    var colors: [LFAppearanceColorRole: LFAppearanceColor] = [:]
    var family: String?
    var sizes: [LFFontRole: Double] = [:]
    var backgroundOpacity: Double?
    var cardOpacity: Double?
    var isEmpty: Bool { colors.isEmpty && family == nil && sizes.isEmpty && backgroundOpacity == nil && cardOpacity == nil }
}

@MainActor
final class LFAppearanceStore: ObservableObject {
    static let shared = LFAppearanceStore()
    static let defaultsKey = "LedgerForge.appearance.darkOverrides"
    @Published private(set) var overrides: LFAppearanceOverrides
    let installedFamilies: [String]
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        installedFamilies = NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        var value = LFAppearanceOverrides()
        if let stored = defaults.dictionary(forKey: Self.defaultsKey) {
            for (key, raw) in stored["colors"] as? [String: Any] ?? [:] {
                if let role = LFAppearanceColorRole(rawValue: key), let components = raw as? [String: Any], let color = LFAppearanceColor(components: components) { value.colors[role] = color }
            }
            if let family = stored["family"] as? String, !family.isEmpty { value.family = family }
            for (key, raw) in stored["sizes"] as? [String: Any] ?? [:] {
                if let role = LFFontRole(rawValue: key), let size = LFAppearanceColor.number(raw), Self.validSize(size) { value.sizes[role] = size }
            }
            if let opacity = LFAppearanceColor.number(stored["backgroundOpacity"]), Self.validOpacity(opacity) { value.backgroundOpacity = opacity }
            if let opacity = LFAppearanceColor.number(stored["cardOpacity"]), Self.validOpacity(opacity) { value.cardOpacity = opacity }
        }
        overrides = value
    }

    var missingFamily: String? {
        guard let family = overrides.family, !installedFamilies.contains(family) else { return nil }
        return family
    }
    func color(_ role: LFAppearanceColorRole) -> Color { (overrides.colors[role] ?? role.approved).color }
    func size(_ role: LFFontRole) -> Double { overrides.sizes[role] ?? role.approvedSize }
    var backgroundOpacity: Double { overrides.backgroundOpacity ?? 0.86 }
    var cardOpacity: Double { overrides.cardOpacity ?? 0.70 }

    func setColor(_ color: Color, for role: LFAppearanceColorRole) {
        guard let stored = LFAppearanceColor(color: color) else { return }
        overrides.colors[role] = stored
        persist()
    }
    func setFamily(_ family: String) {
        overrides.family = family.isEmpty ? nil : family
        persist()
    }
    static func validSize(_ value: Double) -> Bool { value.isFinite && value > 0 }
    private static func validOpacity(_ value: Double) -> Bool { value.isFinite && (0...1).contains(value) }
    func setSize(_ value: Double, for role: LFFontRole) {
        guard Self.validSize(value) else { return }
        overrides.sizes[role] = value
        persist()
    }
    func setOpacity(_ value: Double, background: Bool) {
        guard Self.validOpacity(value) else { return }
        if background { overrides.backgroundOpacity = value } else { overrides.cardOpacity = value }
        persist()
    }
    func restoreApprovedDefaults() {
        overrides = LFAppearanceOverrides()
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private func persist() {
        guard !overrides.isEmpty else { defaults.removeObject(forKey: Self.defaultsKey); return }
        var stored: [String: Any] = [
            "colors": Dictionary(uniqueKeysWithValues: overrides.colors.map { ($0.key.rawValue, $0.value.components) }),
            "sizes": Dictionary(uniqueKeysWithValues: overrides.sizes.map { ($0.key.rawValue, $0.value) })
        ]
        if let family = overrides.family { stored["family"] = family }
        if let opacity = overrides.backgroundOpacity { stored["backgroundOpacity"] = opacity }
        if let opacity = overrides.cardOpacity { stored["cardOpacity"] = opacity }
        defaults.set(stored, forKey: Self.defaultsKey)
    }

    var theme: LFTheme {
        var theme = LFTheme.dark
        theme.typography.family = missingFamily == nil ? overrides.family : nil
        theme.typography.sizes = overrides.sizes
        for (role, value) in overrides.colors {
            switch role {
            case .accent:
                theme.palette.accent = value.color
                theme.palette.accentHover = value.mixedWithWhite(0.22)
                theme.palette.actionGradientEnd = value.offset(-57, -21, -53).color
                theme.palette.focusRing = value.mixedWithWhite(0.48)
            case .background:
                theme.materials.chromeEnd = value.color
                theme.palette.canvas = value.offset(-6, -10, -10).color
            case .navigationHeader:
                theme.materials.chromeStart = value.color
                theme.materials.sidebarStart = value.offset(15, 16, 20).color
                theme.materials.sidebarEnd = value.offset(25, 29, 35).color
            case .card: theme.materials.cardWash = value.color
            case .raisedInspector:
                theme.palette.raisedSurface = value.color
                theme.palette.inspectorSurface = value.offset(-12, -14, -15).color
                theme.palette.contentSurface = value.offset(-12, -14, -15).color
            case .inputControl:
                theme.palette.secondaryAction = value.color
                theme.palette.controlSurface = value.offset(-34, -32, -28).color
            case .primaryText: theme.palette.primaryText = value.color
            case .secondaryText: theme.palette.secondaryText = value.color
            case .navigationSelection: theme.palette.navigationSelected = value.color
            case .selectedFocused: theme.palette.dataSelection = value.color
            case .selectedUnfocused: theme.palette.dataSelectionInactive = value.color
            }
        }
        if let opacity = overrides.backgroundOpacity {
            theme.materials.backgroundWeight = opacity
            // Preserve each approved material variant at 86%, with 0/100% endpoints.
            theme.materials.sidebarStartWeight = variantOpacity(opacity, approved: 0.84, baseline: 0.86)
            theme.materials.sidebarEndWeight = variantOpacity(opacity, approved: 0.82, baseline: 0.86)
        }
        if let opacity = overrides.cardOpacity {
            theme.materials.cardWeight = opacity
            theme.materials.inspectorWeight = variantOpacity(opacity, approved: 0.86, baseline: 0.70)
        }
        return theme
    }

    private func variantOpacity(_ value: Double, approved: Double, baseline: Double) -> Double {
        value <= baseline ? value / baseline * approved : approved + (value - baseline) / (1 - baseline) * (1 - approved)
    }
}
