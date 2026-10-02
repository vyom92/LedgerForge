import SwiftUI

/// Selection is presentation-only and never changes the planner's funding month.
struct SalaryHistoryView: View {
    @Environment(\.lfTheme) private var theme
    let groups: [(month: SelectedStatementMonth, statements: [SalaryStatement], actual: Money)]
    @Binding var selectedStatementID: String?

    private var selected: SalaryStatement? {
        groups.flatMap(\.statements).first { $0.id == selectedStatementID } ?? groups.first?.statements.first
    }

    var body: some View {
        GeometryReader { geometry in
            let historyWidth = max(220, theme.typography.size(.body) * 16)
            let wide = geometry.size.width >= historyWidth + 620
            let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 18)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            layout {
                if wide {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Salary history").font(theme.typography.sectionTitle)
                            Text("Printed salary totals").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                            ForEach(groups, id: \.month) { group in
                                monthRow(group)
                                Divider()
                            }
                        }.padding(16)
                    }.frame(width: historyWidth).lfSurface(.standard)
                        .accessibilityLabel("Salary history months")
                } else {
                    Picker("Salary source", selection: Binding(get: { selected?.id ?? "" }, set: { selectedStatementID = $0 })) {
                        ForEach(groups, id: \.month) { group in
                            ForEach(group.statements) { statement in
                                Text("\(AppDateDisplay.month(group.month.canonical)) · \(statement.evidence.kind.displayName) · Printed \(statement.evidence.printDate?.presentation ?? "date unavailable")").tag(statement.id)
                            }
                        }
                    }.pickerStyle(.menu).tint(theme.palette.primaryText)
                        .font(theme.typography.body).accessibilityLabel("Salary history month and source")
                }
                ScrollView {
                    if let selected {
                        detail(selected, width: wide ? geometry.size.width - historyWidth - 18 : geometry.size.width)
                            .id(selected.id)
                    } else {
                        LFPanel(title: "Salary history") {
                            Text("No salary statements imported.").foregroundStyle(theme.palette.secondaryText)
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Selected payslip")
            }
        }.font(theme.typography.body).foregroundStyle(theme.palette.primaryText)
    }

    private func monthRow(_ group: (month: SelectedStatementMonth, statements: [SalaryStatement], actual: Money)) -> some View {
        let isSelected = selected?.evidence.financialPeriod == group.month
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                selectedStatementID = group.statements.first?.id
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(monthTitle(group.month)).font(theme.typography.body.weight(.semibold))
                    Text(MoneyFormatting.display(group.actual)).font(theme.typography.sectionTitle).monospacedDigit()
                    if group.statements.count > 1 {
                        Text("\(group.statements.count) salary records").font(theme.typography.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    .background(isSelected ? theme.palette.navigationSelected : .clear, in: RoundedRectangle(cornerRadius: theme.radius.control))
            }.buttonStyle(LFPlainActionStyle()).accessibilityAddTraits(isSelected ? .isSelected : [])
            if isSelected && group.statements.count > 1 {
                ForEach(group.statements) { statement in
                    Button { selectedStatementID = statement.id } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(statement.evidence.kind.displayName)
                            Text("Printed \(statement.evidence.printDate?.presentation ?? "date unavailable")")
                                .foregroundStyle(theme.palette.secondaryText)
                            Text(MoneyFormatting.display(statement.evidence.printedPaymentTotal)).monospacedDigit()
                        }.font(theme.typography.secondary).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(selected?.id == statement.id ? theme.palette.controlSurface : .clear, in: RoundedRectangle(cornerRadius: theme.radius.control))
                    }.buttonStyle(LFPlainActionStyle()).accessibilityAddTraits(selected?.id == statement.id ? .isSelected : [])
                }
            }
        }
    }

    private func detail(_ statement: SalaryStatement, width: CGFloat) -> some View {
        let evidence = statement.evidence
        let columns = width >= max(720, theme.typography.size(.body) * 48)
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
        let totals = width >= 620 ? AnyLayout(HStackLayout(alignment: .top, spacing: 20)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        return LFPanel(contentSpacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(monthTitle(evidence.financialPeriod)).font(theme.typography.pageTitle)
                Text("\(evidence.sourceAuthority.displayName) · \(evidence.kind.displayName)")
                Text("Pay period \(AppDateDisplay.month(evidence.financialPeriod.canonical)) · Printed \(evidence.printDate?.presentation ?? "date unavailable")")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            totals {
                printedTotal("Printed earnings", evidence.printedEarningsTotal, color: LFTheme.success)
                printedTotal("Printed deductions", evidence.printedDeductionsTotal, color: theme.palette.primaryText)
                printedTotal("Printed net", evidence.printedNet, color: theme.palette.primaryText)
            }.padding(14).background(theme.palette.controlSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
            columns {
                components("Earnings", values: evidence.earnings, color: LFTheme.success)
                components("Deductions", values: evidence.deductions, color: theme.palette.primaryText,
                           empty: evidence.printedDeductionsTotal == nil ? "No deduction section or total printed in source" : "No deduction lines printed")
            }
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text("Printed payment total").foregroundStyle(theme.palette.secondaryText)
                Spacer(minLength: 16)
                Text(MoneyFormatting.display(evidence.printedPaymentTotal)).font(theme.typography.body.weight(.semibold)).monospacedDigit()
            }
            if evidence.printedPaymentTotal != evidence.printedNet {
                Label("Printed payment total differs from printed net. Review the source amounts above.", systemImage: "exclamationmark.circle")
                    .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            }
        }
    }

    private func printedTotal(_ title: String, _ money: Money?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Text(money.map { MoneyFormatting.display($0) } ?? "Not printed")
                .font(theme.typography.sectionTitle).monospacedDigit().foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func components(_ title: String, values: [SalaryComponent], color: Color, empty: String = "") -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(theme.typography.sectionTitle)
            Divider()
            if values.isEmpty { Text(empty).foregroundStyle(theme.palette.secondaryText) }
            ForEach(values, id: \.sourceOrdinal) { component in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    componentLabel(component.sourceLabel).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(MoneyFormatting.display(component.money)).monospacedDigit().foregroundStyle(color)
                        .fixedSize(horizontal: true, vertical: false)
                }.padding(.vertical, 3).textSelection(.enabled)
            }
        }.frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func componentLabel(_ label: String) -> some View {
        if let reference = label.range(of: "(Tkt.No:") {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(label[..<reference.lowerBound]))
                Text(String(label[reference.lowerBound...]))
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }.accessibilityElement(children: .ignore).accessibilityLabel(label)
        } else {
            Text(label)
        }
    }

    private func monthTitle(_ month: SelectedStatementMonth) -> String {
        let names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return "\(names[month.month - 1]) \(month.year)"
    }
}
