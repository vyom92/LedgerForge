import AppKit
import SwiftUI

/// The same public observations and local direction controls in both destinations.
struct AlDarFXCard: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: AlDarReferenceSession
    var showsRefresh = true
    @State private var reversed: Set<Int> = []
    private let pairs: [AlDarPair] = [.qarINR, .qarUSD, .usdINR]

    static func minimumWidth(theme: LFTheme, legs: [AlDarCurrency: AlDarUnitReference]) -> CGFloat {
        let font = theme.typography.nativeFont(.body, tabularDigits: true)
        let line = AlDarPair.allCases.map { pair in
            "1 \(pair.currencies.0) → \(pair.displayedRate(legs) ?? "Unavailable") \(pair.currencies.1)"
        }.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let flags = ("🇶🇦🇮🇳" as NSString).size(withAttributes: [.font: font]).width
        return max(336, ceil(line + flags + theme.typography.compactControlMinimum + 40 + 2 * theme.spacing.panelPadding))
    }

    var body: some View {
        LFPanel(contentSpacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Al Dar reference rates", systemImage: "arrow.left.arrow.right.circle.fill")
                    .font(theme.typography.body.weight(.semibold))
                    .foregroundStyle(theme.palette.primaryText)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    freshnessBadge(at: context.date)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(pairs.indices, id: \.self) { index in
                    rateRow(index: index)
                }
            }
            if !session.failures.isEmpty {
                Label("Couldn’t update \(session.failures.map(\.rawValue).sorted().joined(separator: " and ")). \(session.legs.isEmpty ? "No previous rates are available." : "Last fetched rates are still shown.")", systemImage: "exclamationmark.circle")
                    .font(theme.typography.caption).foregroundStyle(LFTheme.warning)
            }
            if showsRefresh {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    if let feedback = session.refreshFeedback {
                        Text(feedback.message)
                            .font(theme.typography.caption)
                            .foregroundStyle(feedback.isWarning ? LFTheme.warning : theme.palette.secondaryText)
                            .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
                    }
                    Button { session.refreshManually() } label: {
                        Label(session.refreshing.isEmpty ? "Refresh" : "Refreshing…", systemImage: "arrow.clockwise")
                            .fixedSize()
                    }
                    .lfSecondaryAction().disabled(!session.refreshing.isEmpty)
                    .accessibilityLabel("Refresh Al Dar reference rates")
                }
            }
            DisclosureGroup("About these rates") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("For estimates. Al Dar returns INR and USD for QAR 1. Cross and reversed pairs are calculated from those references; they are not separate transfer quotes. Al Dar does not supply a market timestamp.")
                    ForEach(AlDarCurrency.allCases, id: \.self) { currency in
                        if let leg = session.legs[currency] {
                            Text("1 QAR → \(leg.returned.rawToken) \(currency.rawValue) · fetched \(leg.fetchedAtISO)")
                        }
                    }
                }.font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText).textSelection(.enabled)
            }.font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        }
        .onAppear { session.opened() }
    }

    private func rateRow(index: Int) -> some View {
        let pair = reversed.contains(index) ? pairs[index].inverse : pairs[index]
        let (from, to) = pair.currencies
        return HStack(spacing: 8) {
            Text(flag(from)).accessibilityHidden(true)
            Text("1 \(from)").font(theme.typography.body)
            Image(systemName: "arrow.right").font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText).accessibilityHidden(true)
            Text(flag(to)).accessibilityHidden(true)
            Text(pair.displayedRate(session.legs).map { "\($0) \(to)" } ?? "Unavailable")
                .font(theme.typography.font(.body, tabularDigits: true).weight(.semibold))
                .fixedSize(horizontal: true, vertical: false)
            Button {
                if reversed.contains(index) { reversed.remove(index) } else { reversed.insert(index) }
            } label: { Image(systemName: "arrow.left.arrow.right") }
                .lfIconAction()
                .accessibilityLabel("Reverse \(from) to \(to)").help("Reverse this currency pair")
        }
        .foregroundStyle(theme.palette.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func freshnessBadge(at date: Date) -> some View {
        Group {
            if let fetched = session.legs.values.map(\.fetchedAt).min() {
                let age = AlDarReferenceAge(fetchedAt: fetched, now: date)
                let color = freshnessColor(age)
                let partial = session.legs.count < AlDarCurrency.allCases.count
                Label((partial ? "Partial · " : "") + age.caption, systemImage: "clock")
                    .foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(LinearGradient(colors: [color.opacity(0.16), color.opacity(0.05)], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    .help("Age of the older fetched rate. Individual fetch details are in About these rates.")
            } else {
                Text(session.refreshing.isEmpty ? "No rates yet" : "Fetching rates…")
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }.font(theme.typography.caption).fixedSize(horizontal: false, vertical: true)
    }

    private func flag(_ currency: String) -> String {
        switch currency { case "QAR": "🇶🇦"; case "INR": "🇮🇳"; case "USD": "🇺🇸"; default: "" }
    }

    private func freshnessColor(_ age: AlDarReferenceAge) -> Color {
        let position = age.colorPosition
        let first = (position <= 1 ? NSColor.systemGreen : NSColor.systemYellow).usingColorSpace(.deviceRGB)!
        let second = (position <= 1 ? NSColor.systemYellow : NSColor.systemRed).usingColorSpace(.deviceRGB)!
        let progress = CGFloat(position <= 1 ? position : position - 1)
        return Color(red: Double(first.redComponent + (second.redComponent - first.redComponent) * progress),
                     green: Double(first.greenComponent + (second.greenComponent - first.greenComponent) * progress),
                     blue: Double(first.blueComponent + (second.blueComponent - first.blueComponent) * progress))
    }
}
