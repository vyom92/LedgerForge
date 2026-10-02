// LedgerForge
// DeveloperConsoleView.swift
// Version: 0.0.4

import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

struct DeveloperConsoleView: View {
    @Environment(\.lfTheme) private var theme

    @ObservedObject var console = DeveloperConsole.shared
    @ObservedObject private var accountStore = AccountStore.shared
    @ObservedObject private var transactionStore = TransactionStore.shared
#if DEBUG
    @ObservedObject private var profileViewModel: DeveloperDatabaseProfileViewModel

    init(
        profileViewModel: DeveloperDatabaseProfileViewModel
    ) {
        self.profileViewModel = profileViewModel
    }
#endif

    // Filters
    @State private var filters = DeveloperConsole.Filters()
    @State private var selectedLevel: LevelPicker = .all
    @State private var selectedCategory: CategoryPicker = .all

    // UI State
    @State private var hydrationStatus = "Not refreshed in console"
    @State private var latestRefreshResult = "No console refresh yet"
    @State private var actionError: String?
    @State private var isRunningRepositoryAction = false
    @State private var showsResetConfirmation = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - theme.spacing.pagePadding * 2)
            let pairedMinimum = max(1200, theme.typography.size(.body) * 70)
            let paired = width >= pairedMinimum
            let diagnosticsWidth = paired ? max(0, width - theme.spacing.sectionGap) * 0.70 : width
            let logHeight = max(380, geometry.size.height - 340)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    LFSettingsPageHeader("Developer Console", subtitle: "Advanced diagnostics and inspection")
                    environmentRow

                    LFSettingsColumns(availableWidth: width, leadingFraction: 0.70, minimumWidth: pairedMinimum) {
                        diagnosticsPanel(availableWidth: diagnosticsWidth, logHeight: logHeight)
                    } trailing: {
                        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
#if DEBUG
                            databaseProfilePanel
#endif
                            runtimePanel
                        }
                    }
                }
                .frame(width: width, alignment: .topLeading)
                .padding(theme.spacing.pagePadding)
            }
        }
#if DEBUG
        .confirmationDialog(
            profileViewModel.resetActionLabel.map { "\($0)?" } ?? "Reset Development Profile?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            if let resetActionLabel = profileViewModel.resetActionLabel {
                Button(resetActionLabel, role: .destructive) {
                    resetActiveProfile()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the active development profile is recreated. Current Database is never reset by this control.")
        }
#endif
        .onChange(of: selectedLevel) { _, _ in
            applyLevelFilter()
        }
        .onChange(of: selectedCategory) { _, _ in
            applyCategoryFilter()
        }
    }

    private var runtimeSnapshot: DeveloperConsoleSnapshot {
        DeveloperConsole.runtimeSnapshot(
            persistenceState: DatabaseProvider.shared.persistenceState,
            hydrationStatus: hydrationStatus,
            latestRefreshResult: latestRefreshResult,
            accountStore: accountStore,
            transactionStore: transactionStore
        )
    }

    private var displayedEntries: [DeveloperLogEntry] {
        let filtered = console.filteredEntries(using: filters)
        return DeveloperConsole.newestFirst(filtered)
    }

    private var persistenceColor: Color {
        switch DatabaseProvider.shared.persistenceState {
        case .verifiedSQLite: LFTheme.info
        case .unavailable: LFTheme.danger
        case .intentionalNonDurable: LFTheme.warning
        }
    }

    private var environmentBadges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: theme.spacing.controlGap) {
                LFInlineBadge(title: "Environment: Local", color: LFTheme.success)
                LFInlineBadge(title: DatabaseProvider.shared.persistenceState.displayName, color: persistenceColor)
            }
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                LFInlineBadge(title: "Environment: Local", color: LFTheme.success)
                LFInlineBadge(title: DatabaseProvider.shared.persistenceState.displayName, color: persistenceColor)
            }
        }
    }

    private var environmentRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: theme.spacing.sectionGap) {
                environmentBadges
                Spacer(minLength: theme.spacing.sectionGap)
                consoleTimestamp
            }
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                environmentBadges
                consoleTimestamp
            }
        }
    }

    private var consoleTimestamp: some View {
        Text(Self.timeFormatter.string(from: Date()))
            .font(theme.typography.diagnosticText)
            .foregroundStyle(theme.palette.secondaryText)
            .padding(.horizontal, theme.spacing.controlGap)
            .padding(.vertical, theme.spacing.small)
            .background(theme.palette.controlSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
            .fixedSize(horizontal: true, vertical: false)
            .help("UTC time at the latest view update.")
    }

    private func diagnosticsPanel(availableWidth: CGFloat, logHeight: CGFloat) -> some View {
        let innerWidth = max(0, availableWidth - theme.spacing.panelPadding * 2)
        let tabular = innerWidth >= max(720, theme.typography.size(.secondary) * 52)
        let headerLayout = innerWidth >= max(700, theme.typography.size(.body) * 38)
            ? AnyLayout(HStackLayout(alignment: .center, spacing: theme.spacing.controlGap))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.controlGap))
        return LFPanel {
            headerLayout {
                HStack(spacing: theme.spacing.controlGap) {
                    Text("Diagnostics").font(theme.typography.sectionTitle)
                    LFInlineBadge(title: "\(displayedEntries.count) shown", color: theme.palette.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                logActions(availableWidth: innerWidth)
            }
            logFilters(availableWidth: innerWidth)
            consoleLogTable(tabular: tabular, height: logHeight)
        }
    }

    private func logFilters(availableWidth: CGFloat) -> some View {
        let paired = availableWidth >= max(670, theme.typography.size(.body) * 36)
        let layout = paired
            ? AnyLayout(HStackLayout(alignment: .bottom, spacing: theme.spacing.controlGap))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.controlGap))
        return layout {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                filterLabel("Level")
                Picker("Level", selection: $selectedLevel) {
                    Text("All Levels").tag(LevelPicker.all)
                    Text("Debug").tag(LevelPicker.debug)
                    Text("Info").tag(LevelPicker.info)
                    Text("Warning").tag(LevelPicker.warning)
                    Text("Error").tag(LevelPicker.error)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(theme.palette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: paired ? max(150, theme.typography.size(.secondary) * 12) : nil)

            VStack(alignment: .leading, spacing: theme.spacing.small) {
                filterLabel("Category")
                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag(CategoryPicker.all)
                    Text("Application").tag(CategoryPicker.application)
                    Text("Import").tag(CategoryPicker.`import`)
                    Text("Parser").tag(CategoryPicker.parser)
                    Text("Validation").tag(CategoryPicker.validation)
                    Text("Database").tag(CategoryPicker.database)
                    Text("Runtime").tag(CategoryPicker.runtime)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(theme.palette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: paired ? max(180, theme.typography.size(.secondary) * 14) : nil)

            HStack(spacing: theme.spacing.controlGap) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.palette.secondaryText)
                    .accessibilityHidden(true)
                TextField("Search diagnostics…", text: $filters.searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search diagnostics")
                    .help("Search diagnostic messages and their visible metadata.")
            }
            .font(theme.typography.body)
            .padding(.horizontal, theme.spacing.controlGap)
            .padding(.vertical, theme.spacing.small)
            .frame(maxWidth: .infinity, minHeight: theme.typography.compactControlMinimum)
            .background(theme.palette.contentSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.control)
                    .strokeBorder(theme.palette.border, lineWidth: 1)
            }
        }
    }

    private func filterLabel(_ title: String) -> some View {
        Text(title)
            .font(theme.typography.secondary.weight(.semibold))
            .foregroundStyle(theme.palette.secondaryText)
    }

    private var sequenceWidth: CGFloat { max(30, theme.typography.size(.secondary) * 3) }
    private var timestampWidth: CGFloat { max(132, theme.typography.size(.secondary) * 11) }
    private var levelWidth: CGFloat { max(66, theme.typography.size(.secondary) * 5.5) }
    private var categoryWidth: CGFloat { max(104, theme.typography.size(.secondary) * 8) }

    private var logColumnHeadings: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
            Text("#").frame(width: sequenceWidth, alignment: .leading)
            Text("Time (UTC)").frame(width: timestampWidth, alignment: .leading)
            Text("Level").frame(width: levelWidth, alignment: .leading)
            Text("Category").frame(width: categoryWidth, alignment: .leading)
            Text("Message").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(theme.typography.secondary.weight(.semibold))
        .foregroundStyle(theme.palette.secondaryText)
        .padding(.horizontal, theme.spacing.controlGap)
    }

    private func consoleLogTable(tabular: Bool, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            if tabular {
                logColumnHeadings
                Divider().overlay(theme.palette.divider)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: theme.spacing.small) {
                    if console.entries.isEmpty {
                        consoleEmptyState(
                            title: "No console messages",
                            message: "Runtime diagnostics appear here when import, validation or hydration emits messages.",
                            systemImage: "terminal"
                        )
                    } else if displayedEntries.isEmpty {
                        consoleEmptyState(
                            title: "No matching console messages",
                            message: "Search filters the visible messages only.",
                            systemImage: "magnifyingglass"
                        )
                    } else {
                        ForEach(displayedEntries) { entry in
                            logRow(entry, tabular: tabular)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: height)
        }
    }

    private func consoleEmptyState(title: String, message: String, systemImage: String) -> some View {
        VStack(spacing: theme.spacing.controlGap) {
            Image(systemName: systemImage)
                .font(theme.typography.emptyStateIcon)
                .foregroundStyle(theme.palette.secondaryText)
            Text(title).font(theme.typography.formHeading)
            Text(message)
                .font(theme.typography.body)
                .foregroundStyle(theme.palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private func logRow(_ entry: DeveloperLogEntry, tabular: Bool) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            if tabular {
                HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                    Text("\(entry.sequence)")
                        .font(theme.typography.diagnosticText)
                        .foregroundStyle(theme.palette.secondaryText)
                        .frame(width: sequenceWidth, alignment: .leading)
                    logTimestamp(entry.timestamp)
                        .frame(width: timestampWidth, alignment: .leading)
                    levelBadge(entry.level)
                        .frame(width: levelWidth, alignment: .leading)
                    Text(entry.category.rawValue)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.palette.secondaryText)
                        .frame(width: categoryWidth, alignment: .leading)
                    logMessage(entry)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: theme.spacing.controlGap) {
                        Text("#\(entry.sequence)")
                        Text(Self.timeFormatter.string(from: entry.timestamp))
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Text("#\(entry.sequence)")
                        Text(Self.timeFormatter.string(from: entry.timestamp))
                    }
                }
                .font(theme.typography.diagnosticText)
                .foregroundStyle(theme.palette.secondaryText)
                HStack(spacing: theme.spacing.controlGap) {
                    levelBadge(entry.level)
                    Text(entry.category.rawValue)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.palette.secondaryText)
                }
                logMessage(entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.controlGap)
        .background(theme.palette.controlSurface.opacity(0.35), in: RoundedRectangle(cornerRadius: theme.radius.control))
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
    }

    private func logTimestamp(_ timestamp: Date) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(Self.rowDateFormatter.string(from: timestamp))
                .foregroundStyle(theme.palette.primaryText)
            Text(Self.rowTimeFormatter.string(from: timestamp))
                .foregroundStyle(theme.palette.secondaryText)
        }
        .font(theme.typography.diagnosticText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.timeFormatter.string(from: timestamp))
    }

    private func logMessage(_ entry: DeveloperLogEntry) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text(DiagnosticPrivacy.text(entry.message))
                .font(theme.typography.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let metadataText = DeveloperConsole.metadataText(for: entry) {
                DisclosureGroup("Details") {
                    Text(metadataText)
                        .font(theme.typography.diagnosticDetail)
                        .foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .font(theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func levelBadge(_ level: DeveloperLogLevel) -> some View {
        let color: Color = {
            switch level {
            case .debug: return theme.palette.secondaryText
            case .info: return LFTheme.info
            case .warning: return LFTheme.warning
            case .error: return LFTheme.danger
            }
        }()
        return Text(level.rawValue)
            .font(theme.typography.secondary.weight(.semibold))
            .padding(.horizontal, theme.spacing.controlGap)
            .padding(.vertical, theme.spacing.small)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: theme.radius.control))
            .foregroundStyle(color)
    }

    private func logActions(availableWidth: CGFloat) -> some View {
        let layout = availableWidth >= max(400, theme.typography.size(.body) * 22)
            ? AnyLayout(HStackLayout(spacing: theme.spacing.controlGap))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.controlGap))
        return layout {
            LFConsoleButton(
                title: "Copy All",
                systemImage: "doc.on.doc",
                minWidth: 104,
                fill: theme.palette.controlSurface
            ) {
                copyAllLogs()
            }
            .help("Copy the complete diagnostic history, including entries hidden by filters.")

            LFConsoleButton(
                title: "Clear diagnostics",
                systemImage: "trash",
                fill: theme.palette.controlSurface,
                foreground: LFTheme.danger
            ) {
                console.clear()
                filters = DeveloperConsole.Filters()
                selectedLevel = .all
                selectedCategory = .all
            }
        }
    }

    private var runtimePanel: some View {
        let snapshot = runtimeSnapshot
        return LFPanel(title: "Runtime & repository") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                Grid(alignment: .leading, horizontalSpacing: theme.spacing.controlGap, verticalSpacing: theme.spacing.controlGap) {
                    GridRow {
                        filterLabel("Source")
                        filterLabel("Accounts").frame(maxWidth: .infinity, alignment: .trailing)
                        filterLabel("Transactions").frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Divider().gridCellColumns(3)
                    GridRow {
                        Text("Runtime").font(theme.typography.body.weight(.semibold))
                        Text(snapshot.accountCount.formatted()).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(snapshot.transactionCount.formatted()).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(theme.typography.body.monospacedDigit())
                }
                Text("Counts reflect the loaded data.")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)

                Divider().overlay(theme.palette.divider)
                filterLabel("Persistence status")
                Text(snapshot.persistenceState.statusMessage)
                    .font(theme.typography.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let guidance = snapshot.persistenceState.recoveryGuidance {
                    Text(guidance)
                        .font(theme.typography.body)
                        .foregroundStyle(LFTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().overlay(theme.palette.divider)
                Text("Console refresh").font(theme.typography.body.weight(.semibold))
                Text(snapshot.hydrationStatus)
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
                Text(snapshot.latestRefreshResult)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                LFConsoleButton(
                    title: "Reload Data",
                    systemImage: "arrow.clockwise",
                    fill: theme.palette.controlSurface,
                    isFullWidth: true,
                    isDisabled: isRunningRepositoryAction
                ) {
                    reloadData()
                }
                .padding(.top, theme.spacing.small)

                if let actionError {
                    Text(actionError)
                        .font(theme.typography.secondary)
                        .foregroundStyle(LFTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

#if DEBUG
    private var databaseProfilePanel: some View {
        LFPanel(title: "Database context") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                LFInfoRow(title: "Active database", value: profileViewModel.activeProfileLabel, verticalPadding: 4)
                if let sourceSchema = profileViewModel.activeSourceSchemaLabel {
                    LFInfoRow(title: "Source schema", value: sourceSchema, verticalPadding: 4)
                }
                LFInfoRow(title: "Schema", value: profileViewModel.currentSchemaLabel, verticalPadding: 4)

                Divider().overlay(theme.palette.divider)
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    filterLabel("Switch to")
                    Picker(
                        "Switch to database profile",
                        selection: Binding(
                            get: { profileViewModel.selectedProfileKind },
                            set: { profileViewModel.selectProfile($0) }
                        )
                    ) {
                        ForEach(DevelopmentDatabaseProfileKind.allCases, id: \.rawValue) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(theme.palette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if profileViewModel.showsMigrationSourceSelection {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        filterLabel("Source version")
                        Picker(
                            "Source Version",
                            selection: Binding(
                                get: { profileViewModel.selectedMigrationSourceVersion },
                                set: { profileViewModel.selectMigrationSourceVersion($0) }
                            )
                        ) {
                            ForEach(profileViewModel.availableMigrationSourceVersions, id: \.self) { version in
                                Text("V\(version)").tag(version)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(theme.palette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                LFConsoleButton(
                    title: "Activate selected profile",
                    systemImage: "arrow.triangle.2.circlepath",
                    fill: theme.palette.accent,
                    foreground: theme.palette.primaryText,
                    isFullWidth: true,
                    showsBorder: false,
                    isDisabled: isRunningRepositoryAction || DevelopmentDatabaseLifecycleCoordinator.shared.isOperationInProgress
                ) {
                    profileViewModel.activateSelectedProfile()
                }
                .padding(.top, theme.spacing.small)

                if let resetActionLabel = profileViewModel.resetActionLabel {
                    LFConsoleButton(
                        title: resetActionLabel,
                        systemImage: "exclamationmark.triangle",
                        fill: LFTheme.danger,
                        foreground: theme.palette.primaryText,
                        isFullWidth: true,
                        showsBorder: false,
                        isDisabled: isRunningRepositoryAction || DevelopmentDatabaseLifecycleCoordinator.shared.isOperationInProgress
                    ) {
                        showsResetConfirmation = true
                    }
                }

                if let message = profileViewModel.operationState.message {
                    Text(message)
                        .font(theme.typography.secondary)
                        .foregroundStyle(LFTheme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
#endif

    private func applyLevelFilter() {
        switch selectedLevel {
        case .all:
            filters.level = .all
        case .debug:
            filters.level = .exact(.debug)
        case .info:
            filters.level = .exact(.info)
        case .warning:
            filters.level = .exact(.warning)
        case .error:
            filters.level = .exact(.error)
        }
    }

    private func applyCategoryFilter() {
        switch selectedCategory {
        case .all:
            filters.category = .all
        case .application:
            filters.category = .exact(.application)
        case .`import`:
            filters.category = .exact(.`import`)
        case .parser:
            filters.category = .exact(.parser)
        case .validation:
            filters.category = .exact(.validation)
        case .database:
            filters.category = .exact(.database)
        case .runtime:
            filters.category = .exact(.runtime)
        }
    }

    private func reloadData() {
        isRunningRepositoryAction = true
        actionError = nil
        do {
            let result = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
            hydrationStatus = result.didHydrate ? "Forced refresh completed" : "No refresh required"
            latestRefreshResult = "\(result.accountCount) account(s), \(result.transactionCount) transaction(s)"
            DeveloperConsole.shared.info(.runtime, "Runtime refresh completed", metadata: ["accountCount": "\(result.accountCount)", "transactionCount": "\(result.transactionCount)"])
        } catch {
            hydrationStatus = "Forced refresh failed"
            latestRefreshResult = "Refresh failed"
            actionError = "Runtime refresh is unavailable."
            let failure = ApplicationAvailability.shared.failure ?? RuntimeDiagnostic.failure(error, operation: "canonical reload", stage: "snapshot validation")
            actionError = failure.summary + ". " + failure.nextAction
            if !DatabaseProvider.shared.persistenceState.isUsable {
                RuntimeDiagnostic.record(RuntimeDiagnostic.failure(error, operation: "developer forced refresh", stage: "provider availability", effect: "canonical data not loaded", relatedRoot: DatabaseProvider.shared.failureContext), category: .runtime)
            }
        }
        isRunningRepositoryAction = false
    }

#if DEBUG
    private func resetActiveProfile() {
        isRunningRepositoryAction = true
        actionError = nil
        profileViewModel.resetActiveProfile()
        let resetCommitted = profileViewModel.operationState == .resetSucceeded
            || profileViewModel.operationState == .resetSucceededWithCleanupWarning
        hydrationStatus = resetCommitted
            ? "Profile reset hydration completed"
            : "Profile reset unavailable"
        latestRefreshResult = profileViewModel.operationState.message ?? "Profile reset completed"
        actionError = resetCommitted
            ? nil
            : profileViewModel.operationState.message
        isRunningRepositoryAction = false
    }
#endif

    private func copyAllLogs() {
        let text = console.completeLogText
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        DeveloperConsole.shared.info(.application, "Copied complete diagnostic history")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yy HH:mm:ss.SSS 'UTC'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let rowDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let rowTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - Picker Models

private enum LevelPicker: Hashable {
    case all, debug, info, warning, error
}

private enum CategoryPicker: Hashable {
    case all, application, `import`, parser, validation, database, runtime
}

struct DeveloperConsoleView_Previews: PreviewProvider {
    static var previews: some View {
#if DEBUG
        DeveloperConsoleView(profileViewModel: DeveloperDatabaseProfileViewModel())
#else
        DeveloperConsoleView()
#endif
    }
}
