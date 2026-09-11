import SwiftUI

/// Structural presentation only. ContentView retains every workflow owner and root lifecycle modifier.
struct AppShellView<Sidebar: View, Toolbar: View, ProfileWarning: View, AvailabilityBanner: View, Destination: View>: View {
    let selectedSection: AppShellSection
    let availabilityState: ApplicationDataState
    let permitsMutation: Bool
    private let sidebar: () -> Sidebar
    private let toolbar: () -> Toolbar
    private let profileWarning: () -> ProfileWarning
    private let availabilityBanner: () -> AvailabilityBanner
    private let destination: () -> Destination

    init(
        selectedSection: AppShellSection,
        availabilityState: ApplicationDataState,
        permitsMutation: Bool,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder toolbar: @escaping () -> Toolbar,
        @ViewBuilder profileWarning: @escaping () -> ProfileWarning,
        @ViewBuilder availabilityBanner: @escaping () -> AvailabilityBanner,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.selectedSection = selectedSection
        self.availabilityState = availabilityState
        self.permitsMutation = permitsMutation
        self.sidebar = sidebar
        self.toolbar = toolbar
        self.profileWarning = profileWarning
        self.availabilityBanner = availabilityBanner
        self.destination = destination
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar()

            Rectangle()
                .fill(LFTheme.divider)
                .frame(width: 1)

            VStack(spacing: 0) {
                toolbar()

                Rectangle()
                    .fill(LFTheme.divider)
                    .frame(height: 1)

                profileWarning()

                if !permitsMutation { availabilityBanner() }
                if permitsDestinationPresentation {
                    destination().disabled(
                        !permitsMutation
                            && selectedSection != .settings
                            && selectedSection != .developer
                    )
                } else {
                    Spacer()
                    Text(
                        availabilityState == .loading
                            ? "Loading canonical data…"
                            : "Data is unavailable"
                    )
                    .font(.title2)
                    .foregroundStyle(LFTheme.textSecondary)
                    Spacer()
                }
            }
            .frame(minWidth: selectedSection == .transactions ? 0 : 900, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: selectedSection == .transactions ? 1024 : 1180,
            minHeight: selectedSection == .transactions ? 736 : 760
        )
        .background(LFTheme.backgroundGradient)
        .foregroundStyle(LFTheme.text)
        .preferredColorScheme(.dark)
    }

    private var permitsDestinationPresentation: Bool {
        selectedSection == .transactions
            || selectedSection == .settings
            || selectedSection == .developer
            || availabilityState == .current
            || availabilityState == .empty
            || availabilityState == .retainedNonCurrent
    }
}

struct AppShellSidebar: View {
    let selectedSection: AppShellSection
    let developerConsoleVisible: Bool
    let latestImportActivity: ImportActivityPresentation
    let selectSection: (AppShellSection) -> Void
    var isCollapsed = false
    var allowsCollapse = false
    var toggleCollapsed: () -> Void = {}
    @State private var hoveredSection: AppShellSection?
    @FocusState private var focusedSection: AppShellSection?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                appMark

                if !isCollapsed {
                    Text("LedgerForge")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 24)

            sidebarGroup(AppShellSection.ordinaryNavigation)

            if developerConsoleVisible {
                sidebarSeparator
                sidebarButton(.developer)
            }

            Spacer()

            sidebarFooter
        }
        .padding(.horizontal, isCollapsed ? 10 : (allowsCollapse ? 12 : 18))
        .padding(.vertical, 18)
        .frame(width: isCollapsed ? 64 : (allowsCollapse ? 208 : 242))
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x070B15), Color(hex: 0x091427)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var appMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LFTheme.primaryGradient)
                .frame(width: 34, height: 34)
            Image(systemName: "hexagon.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.92))
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LFTheme.backgroundDeep)
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Last import")
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
                    Text(latestImportActivity.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                    Label(latestImportActivity.status, systemImage: latestImportActivity.iconName)
                        .font(.caption2)
                        .foregroundStyle(latestImportActivity.tone.color)
                        .lineLimit(2)
                }
            }
            Divider().overlay(LFTheme.divider)
            if allowsCollapse {
                Button(action: toggleCollapsed) {
                    if isCollapsed {
                        Image(systemName: "sidebar.left")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    } else {
                        Label("Collapse sidebar", systemImage: "sidebar.left")
                            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    }
                }
                .buttonStyle(.bordered)
                .help(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
                .accessibilityLabel(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
            } else {
                Label("Collapse", systemImage: "chevron.left")
                    .font(.subheadline)
                    .foregroundStyle(LFTheme.textSecondary)
            }
        }
        .padding(.bottom, 4)
    }

    private var sidebarSeparator: some View {
        Rectangle()
            .fill(LFTheme.divider)
            .frame(height: 1)
            .padding(.vertical, 14)
    }

    private func sidebarGroup(_ sections: [AppShellSection]) -> some View {
        VStack(spacing: 5) {
            ForEach(sections, id: \.self) { section in
                sidebarButton(section)
            }
        }
    }

    private func sidebarButton(_ section: AppShellSection) -> some View {
        Button {
            selectSection(section)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22)
                if !isCollapsed {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: selectedSection == section ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(.horizontal, isCollapsed ? 10 : 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedSection == section ? AnyShapeStyle(LFTheme.primaryGradient) : AnyShapeStyle(hoveredSection == section ? Color.white.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedSection == section ? .white : LFTheme.text)
        .accessibilityLabel(section.rawValue)
        .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
        .help(section.rawValue)
        .focused($focusedSection, equals: section)
        .onHover { hoveredSection = $0 ? section : nil }
        .overlay {
            if focusedSection == section {
                RoundedRectangle(cornerRadius: 7).stroke(Color(hex: 0xB2A3FF), lineWidth: 2).padding(-2)
            }
        }
    }
}

struct AppShellToolbar: View {
    let section: AppShellSection
    let subtitle: String
    let importActionIsDisabled: Bool
    let requestImport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.rawValue)
                    .font(.system(size: 27, weight: .semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(LFTheme.textSecondary)
            }

            Spacer(minLength: 24)

            Button(action: requestImport) {
                Label("Import Statement", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minWidth: 176)
                    .background(LFTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .disabled(importActionIsDisabled)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(LFTheme.backgroundDeep.opacity(0.72))
    }
}
