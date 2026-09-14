//
//  LFInfoRow.swift
//  LedgerForge
//

import SwiftUI

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
