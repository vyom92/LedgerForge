import SwiftUI

/// The existing Settings destination is the live preview. These cards edit only
/// the one local appearance owner; they do not hold a second theme or draft.
struct LFAppearanceIntroduction: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var appearance: LFAppearanceStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: theme.spacing.sectionGap) {
                introduction
                Spacer(minLength: theme.spacing.sectionGap)
                restoreButton
            }
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                introduction
                restoreButton
            }
        }
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text("Appearance").font(theme.typography.sectionTitle)
            Text("Your dark interface. Changes apply immediately and stay on this Mac.")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private var restoreButton: some View {
        Button("Restore approved defaults", action: appearance.restoreApprovedDefaults)
            // Recovery stays legible even after an unhelpful custom text color.
            .lfSecondaryAction()
            .environment(\.lfTheme, LFTheme.dark)
            .help("Reset appearance only. All financial data and other settings stay unchanged.")
    }
}

struct LFAppearanceControls: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var appearance: LFAppearanceStore
    let availableWidth: CGFloat

    private var cardLayout: AnyLayout {
        availableWidth >= max(880, theme.typography.size(.secondary) * 60)
            ? AnyLayout(HStackLayout(alignment: .top, spacing: theme.spacing.sectionGap))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.sectionGap))
    }

    var body: some View {
        cardLayout {
            colorCard
            typographyCard
        }
    }

    private var colorCard: some View {
        LFPanel(title: "Colours & surfaces", systemImage: "paintpalette") {
            Text("One palette across every page. Financial status colours keep their meaning.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            colorRows([.accent])
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                colorGroup("Window & navigation", roles: [.background, .navigationHeader])
                opacityControl("Background tint opacity", background: true)
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                colorGroup("Cards & raised surfaces", roles: [.card, .raisedInspector])
                opacityControl("Card tint opacity", background: false)
            }
            colorGroup("Text, controls & selection", roles: [.inputControl, .primaryText, .secondaryText, .navigationSelection, .selectedFocused, .selectedUnfocused])
            Text("100% is an opaque tint. At 0%, the underlying native blur/material can still be visible.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func colorGroup(_ title: String, roles: [LFAppearanceColorRole]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(title).font(theme.typography.rowTitle)
            colorRows(roles)
        }
    }

    private func colorRows(_ roles: [LFAppearanceColorRole]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            ForEach(roles) { role in
                HStack(spacing: theme.spacing.small) {
                    Text(role.title)
                        .font(theme.typography.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: theme.spacing.small)
                    ColorPicker(role.title, selection: Binding(
                        get: { appearance.color(role) },
                        set: { appearance.setColor($0, for: role) }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 38)
                }
                .padding(.vertical, theme.spacing.micro)
            }
        }
    }

    private func opacityControl(_ title: String, background: Bool) -> some View {
        let binding = Binding<Double>(
            get: { background ? appearance.backgroundOpacity : appearance.cardOpacity },
            set: { appearance.setOpacity($0, background: background) }
        )
        return VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack {
                Text(title)
                Spacer()
                Text(binding.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit().foregroundStyle(theme.palette.secondaryText)
            }
            .font(theme.typography.secondary)
            Slider(value: binding, in: 0...1, step: 0.01)
                .accessibilityLabel(title)
        }
    }

    private var typographyCard: some View {
        LFPanel(title: "Typography", systemImage: "textformat") {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                Picker("Interface font", selection: Binding(
                    get: { appearance.overrides.family ?? "" },
                    set: { appearance.setFamily($0) }
                )) {
                    Text("System").tag("")
                    if let missing = appearance.missingFamily { Text("\(missing) — unavailable").tag(missing) }
                    ForEach(appearance.installedFamilies, id: \.self) { family in Text(family).tag(family) }
                }
                .pickerStyle(.menu)
                .font(theme.typography.secondary)
                if let missing = appearance.missingFamily {
                    Text("\(missing) is not installed. System is being used until you choose an installed family.")
                        .font(theme.typography.caption).foregroundStyle(LFTheme.warning)
                }
                Text("The quick brown fox · 0123456789")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            sizeGroup("Interface hierarchy", roles: [.pageTitle, .sectionTitle, .headlineMoney, .rowTitle, .body])
            sizeGroup("Supporting text", roles: [.secondary, .caption])
            sizeGroup("Dense tables", roles: [.tableBody, .tableMoney])
            DisclosureGroup("More text sizes") {
                sizeGroup(nil, roles: [.button, .tableSummary, .formTitle, .formSection, .formHeading, .formBody, .formCallout, .formCaption, .finePrint])
                    .padding(.top, theme.spacing.small)
            }
            .font(theme.typography.secondary)
            Text("Sizes are in points. Below 10 pt may be difficult to read. Existing weights stay in place; Money retains its full currency, sign and decimals.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sizeGroup(_ title: String?, roles: [LFFontRole]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            if let title { Text(title).font(theme.typography.rowTitle) }
            ForEach(roles) { role in
                LFAppearanceSizeSlider(role: role, appearance: appearance)
            }
        }
    }
}

private struct LFAppearanceSizeSlider: View {
    @Environment(\.lfTheme) private var theme
    let role: LFFontRole
    @ObservedObject var appearance: LFAppearanceStore

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            HStack(spacing: theme.spacing.controlGap) {
                Text(role.title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: theme.spacing.small)
                Text("\(appearance.size(role).formatted(.number.grouping(.never).precision(.fractionLength(0...2)))) pt")
                    .monospacedDigit()
                    .foregroundStyle(theme.palette.secondaryText)
            }
            .font(theme.typography.secondary)
            Slider(value: Binding(
                get: { appearance.size(role) },
                set: { appearance.setSize($0, for: role) }
            ), in: min(6, appearance.size(role))...max(48, appearance.size(role)), step: 1)
            .accessibilityLabel("\(role.title) size")
        }
        .padding(.vertical, theme.spacing.micro)
    }
}
