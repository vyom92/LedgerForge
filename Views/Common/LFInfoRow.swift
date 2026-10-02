//
//  LFInfoRow.swift
//  LedgerForge
//

import SwiftUI
import AppKit

/// Standard menu subtitles retain identifying context that SwiftUI Menu drops
/// from a two-line label. Selection remains owned by the caller's binding.
struct LFAccountMenu: NSViewRepresentable {
    struct Option {
        let id: String
        let title: String
        let detail: String
        let selected: Bool
        init(id: String, title: String, detail: String, selected: Bool = false) {
            self.id = id; self.title = title; self.detail = detail; self.selected = selected
        }
    }
    @Environment(\.lfTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    var allTitle: String? = nil
    let options: [Option]
    let onSelect: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.open(_:)))
        button.bezelStyle = .rounded
        button.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
        button.imagePosition = .imageTrailing
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        button.title = title
        button.font = theme.typography.nativeFont(.button)
        button.contentTintColor = NSColor(theme.palette.primaryText)
        button.isEnabled = isEnabled
        button.setAccessibilityLabel(title)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSButton, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? nsView.intrinsicContentSize.width,
               height: max(theme.typography.compactControlMinimum, nsView.intrinsicContentSize.height))
    }
    @MainActor final class Coordinator: NSObject {
        var parent: LFAccountMenu
        init(_ parent: LFAccountMenu) { self.parent = parent }
        @objc func open(_ button: NSButton) {
            let menu = NSMenu()
            menu.font = parent.theme.typography.nativeFont(.body)
            if let allTitle = parent.allTitle {
                let all = NSMenuItem(title: allTitle, action: #selector(select(_:)), keyEquivalent: "")
                all.target = self
                menu.addItem(all)
                menu.addItem(.separator())
            }
            for option in parent.options {
                let item = NSMenuItem(title: option.title, action: #selector(select(_:)), keyEquivalent: "")
                item.subtitle = option.detail
                item.state = option.selected ? .on : .off
                item.representedObject = option.id
                item.target = self
                menu.addItem(item)
            }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 2), in: button)
        }
        @objc func select(_ item: NSMenuItem) { parent.onSelect(item.representedObject as? String) }
    }
}

/// Single-account form control using the same native subtitle menu. The
/// caller retains the existing account ID binding and eligible account list.
struct LFAccountPicker: View {
    let label: String
    let placeholder: String
    @Binding var selection: String
    let options: [LFAccountMenu.Option]
    var allowsEmptySelection = true

    var body: some View {
        LabeledContent(label) {
            LFAccountMenu(title: options.first { $0.id == selection }?.title ?? placeholder,
                allTitle: allowsEmptySelection ? placeholder : nil,
                options: options.map { .init(id: $0.id, title: $0.title, detail: $0.detail, selected: $0.id == selection) }) {
                    selection = $0 ?? ""
                }
                .accessibilityLabel(label)
        }
    }
}

/// The saved name is its own label; disambiguation never rewrites it.
struct LFAccountLabel: View {
    @Environment(\.lfTheme) private var theme
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).fixedSize(horizontal: false, vertical: true)
            if !detail.isEmpty {
                Text(detail).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
        }.help(detail)
    }
}

/// Preserve a chosen one-line value even when it cannot fit the full available
/// width. Ordinary values stay inline; only actual overflow scrolls horizontally.
struct LFCompleteValue<Content: View>: View {
    let lineHeight: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content.fixedSize(horizontal: true, vertical: true)
            ScrollView(.horizontal) {
                content.fixedSize(horizontal: true, vertical: true)
            }
            .frame(height: lineHeight + 16)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// One compact label/value relationship for comparable display rows. Grid
/// sizes the value column from the largest actual value, with a bounded gutter.
/// A label and its context form one row, so neither can spread into spare height.
/// Narrow containers reflow without shrinking their Money.
struct LFLabelValueGroup<Rows: RandomAccessCollection, Label: View, Value: View, Context: View>: View where Rows.Element: Identifiable {
    @Environment(\.lfTheme) private var theme
    let rows: Rows
    var rowSpacing: CGFloat? = nil
    var valueRole: LFFontRole = .rowTitle
    @ViewBuilder let label: (Rows.Element) -> Label
    @ViewBuilder let value: (Rows.Element) -> Value
    @ViewBuilder let context: (Rows.Element) -> Context

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Grid(alignment: .leading, horizontalSpacing: theme.spacing.valueGutter, verticalSpacing: rowSpacing ?? theme.spacing.rowGap) {
                ForEach(rows) { row in
                    GridRow(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: theme.spacing.micro) {
                            label(row)
                            context(row)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        value(row)
                            .fixedSize(horizontal: true, vertical: false)
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: rowSpacing ?? theme.spacing.rowGap) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        label(row).fixedSize(horizontal: false, vertical: true)
                        LFCompleteValue(lineHeight: theme.typography.lineHeight(valueRole)) {
                            value(row)
                        }
                        context(row).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct LFInfoRow: View {
    @Environment(\.lfTheme) private var theme
    let title: String
    let value: String
    var titleWidth: CGFloat? = nil
    var verticalPadding: CGFloat = 6
    var textRole: LFFontRole = .formCaption

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                Text(title)
                    .foregroundStyle(theme.palette.secondaryText)
                    .frame(width: titleWidth, alignment: .leading)
                Spacer(minLength: 0)
                Text(value)
                    .fixedSize(horizontal: true, vertical: false)
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                Text(title).foregroundStyle(theme.palette.secondaryText)
                Text(value).fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(theme.typography.font(textRole))
        .padding(.vertical, verticalPadding)
    }
}
