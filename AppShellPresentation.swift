import SwiftUI
import AppKit
#if DEBUG
import OSLog
#endif

/// Destination-specific constraints preserve the accepted Transactions and
/// other-screen minima while allowing Dashboard's single-column composition.
enum AppShellSizing {
    static func minimumSize(for section: AppShellSection) -> CGSize {
        switch section {
        case .dashboard: CGSize(width: 640, height: 608)
        case .transactions: CGSize(width: 1024, height: 736)
        case .settings: CGSize(width: 760, height: 608)
        default: CGSize(width: 1180, height: 760)
        }
    }

    static func dashboardUsesRail(at width: CGFloat) -> Bool { width < 1000 }

#if DEBUG
    /// Nonfinancial dimensions make selected-destination window constraints
    /// inspectable during native validation without changing window behavior.
    @MainActor
    static func recordWindowGeometry(for section: AppShellSection) {
        guard let window = NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) else { return }
        let size = window.frame.size
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "LedgerForge", category: "WindowLayout")
            .debug("Destination=\(section.rawValue, privacy: .public) window=\(size.width, privacy: .public)x\(size.height, privacy: .public)")
    }
#endif
}

#if DEBUG
/// Opt-in observation of one sidebar action through the next destination draw.
/// It has no provider, preference, or financial-data access.
@MainActor
private enum NavigationPerformanceProbe {
    static let enabled = ProcessInfo.processInfo.environment["LEDGERFORGE_NAVIGATION_PROBE"] == "1"
    private static let logger = Logger(subsystem: "com.vyom.LedgerForge", category: "NavigationPerformance")
    private static var pending: (from: AppShellSection, to: AppShellSection, started: TimeInterval)?

    static func begin(from: AppShellSection, to: AppShellSection) {
        guard enabled, from != to else { return }
        pending = (from, to, ProcessInfo.processInfo.systemUptime)
    }

    static func didDraw(_ section: AppShellSection) {
        guard let measurement = pending, measurement.to == section else { return }
        pending = nil
        let milliseconds = (ProcessInfo.processInfo.systemUptime - measurement.started) * 1_000
        logger.notice("Navigation \(measurement.from.rawValue, privacy: .public) -> \(section.rawValue, privacy: .public) first_draw_ms=\(milliseconds, privacy: .public)")
    }
}

private struct NavigationDrawProbe: NSViewRepresentable {
    let section: AppShellSection

    func makeNSView(context: Context) -> DrawView { DrawView() }

    func updateNSView(_ view: DrawView, context: Context) {
        view.section = section
        view.needsDisplay = true
    }

    final class DrawView: NSView {
        var section = AppShellSection.dashboard
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func draw(_ dirtyRect: NSRect) {
            NavigationPerformanceProbe.didDraw(section)
        }
    }
}
#endif

/// Structural presentation only. ContentView retains every workflow owner and root lifecycle modifier.
struct AppShellView<Sidebar: View, Toolbar: View, ProfileWarning: View, AvailabilityBanner: View, Destination: View>: View {
    @Environment(\.lfTheme) private var theme
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
                .fill(theme.palette.divider)
                .frame(width: 1)
                .ignoresSafeArea(.container, edges: .top)

            VStack(spacing: 0) {
                toolbar()

                Rectangle()
                    .fill(theme.palette.divider)
                    .frame(height: 1)
                    .opacity(0)

                profileWarning()

                if !permitsMutation { availabilityBanner() }
                if permitsDestinationPresentation {
                    destination().disabled(
                        !permitsMutation
                            && selectedSection != .dashboard
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
                    .font(theme.typography.formTitle)
                    .foregroundStyle(theme.palette.secondaryText)
                    Spacer()
                }
            }
            .frame(minWidth: selectedSection == .transactions || selectedSection == .dashboard || selectedSection == .settings ? 0 : 900, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: AppShellSizing.minimumSize(for: selectedSection).width,
            minHeight: AppShellSizing.minimumSize(for: selectedSection).height
        )
        .background {
            LFChromeBackdrop()
                .ignoresSafeArea()
        }
        .foregroundStyle(theme.palette.primaryText)
        .preferredColorScheme(.dark)
#if DEBUG
        .overlay(alignment: .topLeading) {
            if NavigationPerformanceProbe.enabled {
                NavigationDrawProbe(section: selectedSection)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
#endif
    }

    private var permitsDestinationPresentation: Bool {
        selectedSection == .dashboard
            || selectedSection == .transactions
            || selectedSection == .settings
            || selectedSection == .developer
            || availabilityState == .current
            || availabilityState == .empty
            || availabilityState == .retainedNonCurrent
    }
}

struct AppShellSidebar: View {
    @Environment(\.lfTheme) private var theme
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
                        .font(theme.typography.formSection.weight(.semibold))
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
        .padding(.horizontal, isCollapsed ? theme.spacing.railPadding : theme.spacing.expandedSidebarPadding)
        .padding(.vertical, 18)
        .frame(width: isCollapsed ? theme.spacing.railWidth : theme.spacing.expandedSidebarWidth)
        .frame(maxHeight: .infinity)
        .background {
            ZStack {
                LFMaterialBackdrop(material: .sidebar)
                theme.materials.sidebarTint
            }
            .ignoresSafeArea(.container, edges: .top)
            .allowsHitTesting(false)
        }
    }

    private var appMark: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Last import")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.palette.secondaryText)
                    Text(latestImportActivity.title)
                        .font(theme.typography.caption.weight(.semibold))
                        .lineLimit(2)
                    Label(latestImportActivity.status, systemImage: latestImportActivity.iconName)
                        .font(theme.typography.caption)
                        .foregroundStyle(latestImportActivity.tone.color)
                        .lineLimit(2)
                }
            }
            Divider().overlay(theme.palette.divider)
            if allowsCollapse {
                Button(action: toggleCollapsed) {
                    if isCollapsed {
                        Image(systemName: "sidebar.left")
                            .frame(maxWidth: .infinity, minHeight: theme.typography.compactControlMinimum)
                    } else {
                        Label("Collapse sidebar", systemImage: "sidebar.left")
                            .frame(maxWidth: .infinity, minHeight: theme.typography.compactControlMinimum, alignment: .leading)
                    }
                }
                .lfSecondaryAction()
                .font(theme.typography.secondary)
                .help(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
                .accessibilityLabel(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
            } else if !isCollapsed {
                Label("Collapse", systemImage: "chevron.left")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
        .padding(.bottom, 4)
    }

    private var sidebarSeparator: some View {
        Rectangle()
            .fill(theme.palette.divider)
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
#if DEBUG
            NavigationPerformanceProbe.begin(from: selectedSection, to: section)
#endif
            selectSection(section)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(theme.typography.sectionIcon.weight(.medium))
                    .frame(width: 22)
                if !isCollapsed {
                    Text(section.rawValue)
                        .font(theme.typography.body.weight(selectedSection == section ? .semibold : .regular))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, isCollapsed ? theme.spacing.railPadding : theme.spacing.expandedSidebarPadding)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.control)
                    .fill(selectedSection == section ? theme.interaction.navigationSelected : (hoveredSection == section ? theme.interaction.navigationHover : Color.clear))
            }
            .overlay {
                if selectedSection == section {
                    RoundedRectangle(cornerRadius: theme.radius.control)
                        .strokeBorder(theme.interaction.navigationEdge, lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: theme.radius.control))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.palette.primaryText)
        .accessibilityLabel(section.rawValue)
        .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
        .help(section.rawValue)
        .focused($focusedSection, equals: section)
        .onHover { hoveredSection = $0 ? section : nil }
        .overlay {
            if focusedSection == section {
                RoundedRectangle(cornerRadius: theme.radius.control).stroke(theme.interaction.focusRing, lineWidth: 2).padding(-2)
            }
        }
    }
}

struct AppShellToolbar: View {
    @Environment(\.lfTheme) private var theme
    let section: AppShellSection
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.rawValue)
                    .font(theme.typography.pageTitle)
                Text(subtitle)
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
            }

            Spacer(minLength: 24)
        }
        .padding(.horizontal, theme.spacing.pagePadding)
        .padding(.vertical, theme.spacing.pagePadding)
    }
}
