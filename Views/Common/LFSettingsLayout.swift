import SwiftUI

/// Settings destinations share page hierarchy while keeping each feature's
/// controls, state and actions in its existing view.
struct LFSettingsPageHeader<Actions: View>: View {
    @Environment(\.lfTheme) private var theme
    let title: String
    let subtitle: String
    private let actions: Actions

    init(_ title: String, subtitle: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    init(_ title: String, subtitle: String) where Actions == EmptyView {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                heading.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: theme.spacing.sectionGap)
                actions
            }
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                heading
                actions
            }
        }
        .padding(.bottom, theme.spacing.small)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(title).font(theme.typography.pageTitle)
            Text(subtitle)
                .font(theme.typography.body)
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Changing column arrangement doesn't replace the child views or their drafts.
struct LFSettingsColumns<Leading: View, Trailing: View>: View {
    @Environment(\.lfTheme) private var theme
    let availableWidth: CGFloat
    let leadingFraction: CGFloat
    let minimumWidth: CGFloat
    private let leading: Leading
    private let trailing: Trailing

    init(availableWidth: CGFloat, leadingFraction: CGFloat = 0.5,
         minimumWidth: CGFloat = 900,
         @ViewBuilder leading: () -> Leading,
         @ViewBuilder trailing: () -> Trailing) {
        self.availableWidth = availableWidth
        self.leadingFraction = leadingFraction
        self.minimumWidth = minimumWidth
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        let paired = availableWidth >= max(minimumWidth, theme.typography.size(.body) * 52)
        let contentWidth = max(0, availableWidth - theme.spacing.sectionGap)
        let layout = paired
            ? AnyLayout(HStackLayout(alignment: .top, spacing: theme.spacing.sectionGap))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.sectionGap))
        layout {
            leading
                .frame(width: paired ? contentWidth * leadingFraction : nil, alignment: .topLeading)
                .frame(maxWidth: paired ? nil : .infinity, alignment: .leading)
            trailing
                .frame(width: paired ? contentWidth * (1 - leadingFraction) : nil, alignment: .topLeading)
                .frame(maxWidth: paired ? nil : .infinity, alignment: .leading)
        }
    }
}
