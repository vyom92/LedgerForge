//
//  LFPanel.swift
//  LedgerForge
//

import SwiftUI
import AppKit

enum LFPanelVariant {
    case standard
    case inspector
    case subtle
}

/// Ordinary cards share one material/edge/padding implementation. Pages supply
/// their existing contents and can keep a subordinate custom heading in content.
struct LFPanel<Content: View>: View {
    @Environment(\.lfTheme) private var theme
    let title: String?
    let systemImage: String?
    let trailing: AnyView?
    let variant: LFPanelVariant
    let contentSpacing: CGFloat?
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        systemImage: String? = nil,
        trailing: AnyView? = nil,
        variant: LFPanelVariant = .standard,
        contentSpacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing
        self.variant = variant
        self.contentSpacing = contentSpacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing ?? theme.spacing.sectionGap) {
            if title != nil || trailing != nil {
                HStack(spacing: theme.spacing.controlGap) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(theme.typography.panelIcon)
                            .foregroundStyle(theme.palette.secondaryText)
                            .accessibilityHidden(true)
                    }
                    if let title {
                        Text(title)
                            .font(theme.typography.sectionTitle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    trailing
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.panelPadding)
        .lfSurface(variant)
    }
}

private struct LFSurface: ViewModifier {
    @Environment(\.lfTheme) private var theme
    let variant: LFPanelVariant

    private var wash: Color {
        switch variant {
        case .standard: theme.materials.cardWash.opacity(theme.materials.cardWeight)
        case .inspector: theme.palette.inspectorSurface.opacity(theme.materials.inspectorWeight)
        case .subtle: theme.palette.raisedSurface.opacity(theme.materials.cardWeight)
        }
    }

    func body(content: Content) -> some View {
        content
            .background(wash, in: RoundedRectangle(cornerRadius: theme.radius.panel))
            .background(theme.materials.content, in: RoundedRectangle(cornerRadius: theme.radius.panel))
            .overlay {
                if variant != .subtle {
                    RoundedRectangle(cornerRadius: theme.radius.panel)
                        .strokeBorder(theme.palette.panelEdge, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.panel))
            .shadow(color: variant == .subtle ? .clear : theme.materials.shadow, radius: 12, y: 4)
    }
}

extension View {
    func lfSurface(_ variant: LFPanelVariant = .standard) -> some View {
        modifier(LFSurface(variant: variant))
    }
}

/// A single theme owner for in-app actions. Native menus and confirmation
/// dialogs keep their platform interaction; commands and enablement stay local.
enum LFActionKind: Equatable { case primary, secondary, icon, positive, negative }

enum LFConnectionStatus: String {
    case connected = "Connected", disconnected = "Disconnected", error = "Error"
    var color: Color {
        switch self {
        case .connected: LFTheme.success
        case .disconnected: .yellow
        case .error: LFTheme.danger
        }
    }
}

/// Row/selection buttons already own their themed surface. Add a consistent
/// press response without turning each selectable row into a filled action.
struct LFPlainActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

/// The arrow, label and surrounding row are one native button. Disclosure
/// content stays outside that button so its own controls keep their actions.
struct LFDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .frame(width: 12)
                        .accessibilityHidden(true)
                    configuration.label
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(LFDisclosureButtonStyle())
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")

            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 20)
                    .disclosureGroupStyle(LFDisclosureGroupStyle())
            }
        }
    }
}

private struct LFDisclosureButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LFDisclosureButtonBody(configuration: configuration)
    }
}

private struct LFDisclosureButtonBody: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(minHeight: max(32, theme.typography.compactControlMinimum))
            .foregroundStyle(theme.palette.primaryText)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.control)
                    .fill(theme.palette.primaryText.opacity(isEnabled ? (configuration.isPressed ? 0.10 : isHovered ? 0.05 : 0) : 0))
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: theme.radius.control)
                        .strokeBorder(theme.interaction.focusRing, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.65)
            .onHover { isHovered = $0 }
    }
}

struct LFActionButtonStyle: ButtonStyle {
    var kind: LFActionKind = .secondary
    var wide = false

    func makeBody(configuration: Configuration) -> some View {
        LFActionButtonBody(configuration: configuration, kind: kind, wide: wide)
    }
}

private struct LFActionButtonBody: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false
    let configuration: ButtonStyleConfiguration
    let kind: LFActionKind
    let wide: Bool

    private var destructive: Bool { configuration.role == .destructive || kind == .negative }
    private var semanticColor: Color? { destructive ? LFTheme.danger : kind == .positive ? LFTheme.success : nil }
    private var surface: AnyShapeStyle {
        if let semanticColor { return AnyShapeStyle(semanticColor.opacity(0.20)) }
        switch kind {
        case .primary, .secondary: return AnyShapeStyle(theme.palette.secondaryAction)
        case .icon: return AnyShapeStyle(theme.palette.controlSurface)
        case .positive, .negative: return AnyShapeStyle(theme.palette.secondaryAction)
        }
    }

    var body: some View {
        configuration.label
            .font(theme.typography.button)
            .foregroundStyle(semanticColor ?? theme.palette.primaryText)
            .padding(.horizontal, wide ? 32 : kind == .icon ? 8 : 12)
            .padding(.vertical, wide ? 13 : kind == .icon ? 6 : 8)
            .frame(minWidth: wide ? 180 : kind == .icon ? theme.typography.compactControlMinimum : nil,
                   minHeight: theme.typography.compactControlMinimum)
            .background(surface, in: RoundedRectangle(cornerRadius: theme.radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.control)
                    .fill(theme.palette.primaryText.opacity(isEnabled ? (configuration.isPressed ? 0.10 : isHovered ? 0.05 : 0) : 0))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.control)
                    .strokeBorder(isFocused ? theme.interaction.focusRing : semanticColor?.opacity(0.65) ?? theme.palette.border, lineWidth: isFocused ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: theme.radius.control))
            .opacity(isEnabled ? 1 : 0.65)
            .onHover { isHovered = $0 }
    }
}

/// Owner-preferred native dropdown appearance, shared by all menu triggers.
private struct LFMenuAction: ViewModifier {
    @Environment(\.lfTheme) private var theme

    func body(content: Content) -> some View {
        content
            .buttonStyle(LFActionButtonStyle())
            .buttonBorderShape(.roundedRectangle(radius: theme.radius.control))
            .tint(theme.palette.primaryText)
            .foregroundStyle(theme.palette.primaryText)
            .font(theme.typography.button)
    }
}

extension View {
    func lfPrimaryAction() -> some View { buttonStyle(LFActionButtonStyle(kind: .primary)) }
    func lfSecondaryAction() -> some View { buttonStyle(LFActionButtonStyle()) }
    func lfIconAction() -> some View { buttonStyle(LFActionButtonStyle(kind: .icon)) }
    func lfConnectAction() -> some View { buttonStyle(LFActionButtonStyle(kind: .positive)) }
    func lfDisconnectAction() -> some View { buttonStyle(LFActionButtonStyle(kind: .negative)) }
    func lfMenuAction() -> some View { modifier(LFMenuAction()) }
}

/// Native editable controls keep their bindings and responder behavior. Only
/// the surrounding surface and the ordinary field focus cue are shared.
private struct LFInputSurface: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .modifier(LFInputAppearance(isFocused: isFocused))
            .focused($isFocused)
    }
}

private struct LFInputAppearance: ViewModifier {
    @Environment(\.lfTheme) private var theme
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, theme.spacing.small)
            .padding(.vertical, theme.spacing.micro)
            .background(theme.palette.controlSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.control)
                    .strokeBorder(isFocused ? theme.interaction.focusRing : theme.palette.border, lineWidth: isFocused ? 2 : 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func lfTextField() -> some View { modifier(LFInputSurface()) }

}

/// One continuous native backdrop and color wash behind the shared header and
/// destination canvas. Foreground content stays outside this compositing layer.
struct LFChromeBackdrop: View {
    @Environment(\.lfTheme) private var theme

    var body: some View {
        ZStack {
            theme.palette.canvas
            LFMaterialBackdrop(material: .headerView)
            theme.materials.chromeTint
        }
        .allowsHitTesting(false)
    }
}

/// Background only: samples the actual desktop without owning windows, input,
/// lifecycle or financial state. Used by the existing shell and Dashboard cards.
struct LFMaterialBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.wantsLayer = true
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = cornerRadius > 0
    }
}
