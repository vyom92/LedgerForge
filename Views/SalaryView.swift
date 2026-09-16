import AppKit
import SwiftUI

struct SalaryView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var viewModel: SalaryWorkspaceViewModel
    @ObservedObject var referenceSession: AlDarReferenceSession
    @ObservedObject private var salaryStore: SalaryStore = .shared
    @State private var section = "This Month"
    @State private var confirmingDiscard = false
    @State private var showingFXDatePicker = false
    @State private var fxDateSelection = Date()
    @State private var billDateRowID: String?
    @State private var billDateSelection = Date()
    @State private var showingINRFunds = false
    @State private var showingManualFX = false
    @State private var showingDeductions = true

    private var amountWidth: CGFloat {
        let values = viewModel.plan.balances.compactMap(\.money)
            + (viewModel.plan.qatarCommitments + viewModel.plan.indiaCommitments).map(\.money)
            + viewModel.plan.deductions.map(\.money)
            + [viewModel.plan.expectedFixedEarnings, viewModel.plan.expectedVariableEarnings]
        let font = theme.typography.nativeFont(.body, tabularDigits: true)
        return max(140, ceil(values.map { (MoneyFormatting.display($0) as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0) + 24)
    }
    private var minimumColumn: CGFloat {
        let label = ("Variable earnings" as NSString).size(withAttributes: [.font: theme.typography.nativeFont(.body)]).width
        return max(450, label + amountWidth + 160)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, min(1280, geometry.size.width - theme.spacing.pagePadding * 2))
            let wide = width >= minimumColumn * 2 + 18
            let columnWidth = wide ? (width - 18) / 2 : width
            let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 18)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header(width: width)
                    HStack(spacing: 4) {
                        planningSectionButton("Monthly plan", value: "This Month", icon: "calendar")
                        planningSectionButton("Salary History", value: "Salary History", icon: "clock.arrow.circlepath")
                    }.padding(4).frame(maxWidth: 400)
                        .background(theme.palette.controlSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
                        .accessibilityElement(children: .contain).accessibilityLabel("Planning section")
                }.frame(width: width, alignment: .leading)
                    .padding(.horizontal, theme.spacing.pagePadding).padding(.top, 12).padding(.bottom, 12)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                    if section == "This Month" {
                        if let error = viewModel.errorMessage { Text(error).foregroundStyle(LFTheme.warning).font(theme.typography.secondary) }
                        let referenceWidth = AlDarFXCard.minimumWidth(theme: theme, legs: referenceSession.legs)
                        let inlineOverview = width >= max(780, amountWidth * 3 + 100) + referenceWidth + 18
                        let overviewWidth = inlineOverview ? width - referenceWidth - 18 : width
                        let overviewLayout = inlineOverview
                            ? AnyLayout(HStackLayout(alignment: .top, spacing: 18))
                            : AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                        overviewLayout {
                            monthlyOverview(width: overviewWidth)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            AlDarFXCard(session: referenceSession)
                                .frame(width: inlineOverview ? referenceWidth : nil, alignment: .leading)
                        }
                        if viewModel.plan.calculationVersion == .budgetV1 {
                            layout {
                                qatarColumn(width: columnWidth).frame(maxWidth: .infinity, alignment: .leading)
                                indiaColumn(width: columnWidth).frame(maxWidth: .infinity, alignment: .leading)
                            }.disabled(!viewModel.canEdit)
                            Text("Your estimates stay separate from imported payslips. Save when you’re ready.")
                                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        }
                    } else { history }
                }.frame(width: width, alignment: .leading).padding(theme.spacing.pagePadding)
                    .font(theme.typography.body)
                }
            }
        }
        .confirmationDialog("Discard this draft and reload the current database?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard and reload", role: .destructive) { viewModel.discardAndReload() }
            Button("Keep draft", role: .cancel) {}
        }
        .onAppear {
            viewModel.plannerOpened()
            viewModel.receiveSharedReference(referenceSession.legs[.inr])
            showingINRFunds = viewModel.plan.balances.contains { $0.nativeCurrency.code == "INR" && $0.included }
            showingManualFX = viewModel.plan.referenceMode == .manual
        }
        .onReceive(referenceSession.$legs) { viewModel.receiveSharedReference($0[.inr]) }
        .onChange(of: viewModel.month) { _, _ in
            showingINRFunds = viewModel.plan.balances.contains { $0.nativeCurrency.code == "INR" && $0.included }
            showingManualFX = viewModel.plan.referenceMode == .manual
        }
    }

    @ViewBuilder private func monthlyOverview(width: CGFloat) -> some View {
        if viewModel.plan.calculationVersion == .legacy {
            LFPanel(title: "Your saved monthly plan") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Continue with your saved estimates in the new worksheet. Your saved plan stays as it is until you choose Save.")
                        .font(theme.typography.body)
                    valueRow("Expected net salary", viewModel.calculation.expectedNet, truth: "Saved estimate")
                    valueRow("Previously planned investment", viewModel.plan.plannedInvestment, truth: "From your saved plan")
                    valueRow("Saved amount left over", viewModel.calculation.finalQARBuffer, truth: "From your saved plan")
                    Button("Open monthly worksheet") { viewModel.adoptBudgetPlanning() }
                        .lfSecondaryAction().disabled(!viewModel.canEdit)
                }
            }
        } else {
            comparison(width: width)
        }
    }


    private func header(width: CGFloat) -> some View {
        let layout = width >= 640 ? AnyLayout(HStackLayout(alignment: .center, spacing: 16)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
        return VStack(alignment: .leading, spacing: 8) {
            layout {
                HStack(spacing: 12) {
                    Menu {
                        ForEach(1...12, id: \.self) { number in
                            Button(monthNames[number - 1]) { selectPlanningMonth(number, year: viewModel.month.year) }
                                .disabled(viewModel.month.year < 2026 || (viewModel.month.year == 2026 && number < 9))
                        }
                        let earlier = viewModel.availableMonths.filter { !SalaryWorkspaceViewModel.planningMonths.contains($0) }
                        if !earlier.isEmpty {
                            Divider()
                            Menu("Saved history") {
                                ForEach(earlier, id: \.self) { month in
                                    Button(fullMonthTitle(month)) { viewModel.switchMonth(to: month) }
                                }
                            }
                        }
                    } label: {
                        Label(monthNames[viewModel.month.month - 1], systemImage: "calendar")
                            .font(theme.typography.body.weight(.semibold)).foregroundStyle(theme.palette.primaryText)
                    }.lfMenuAction().accessibilityLabel("Planning month")
                    Menu {
                        ForEach(2026...2099, id: \.self) { year in
                            Button(String(year)) {
                                selectPlanningMonth(year == 2026 ? max(9, viewModel.month.month) : viewModel.month.month, year: year)
                            }
                        }
                    } label: {
                        Text(String(viewModel.month.year))
                            .font(theme.typography.body.weight(.semibold)).foregroundStyle(theme.palette.primaryText)
                    }.lfMenuAction().accessibilityLabel("Planning year").accessibilityValue(String(viewModel.month.year))
                }.disabled(viewModel.saveState == .saving || viewModel.saveState == .committedNeedsRefresh)
                HStack(spacing: 12) {
                    Text(!SalaryWorkspaceViewModel.planningMonths.contains(viewModel.month) ? "Saved plan · read only" : viewModel.statusText)
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    Spacer(minLength: 4)
                    Button("Save") { viewModel.save() }.keyboardShortcut("s", modifiers: .command)
                        .lfPrimaryAction().tint(theme.palette.accent).disabled(!viewModel.canSave)
                }
            }
            if viewModel.saveState == .committedNeedsRefresh {
                Button("Reload saved plan") { viewModel.retryCanonicalRefresh() }.lfSecondaryAction()
            } else if [.providerChanged, .canonicalChanged, .committedToPreviousProvider].contains(viewModel.saveState) {
                Button("Discard draft and reload") { confirmingDiscard = true }.lfSecondaryAction()
            }
        }
    }

    private var monthNames: [String] { ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"] }
    private func fullMonthTitle(_ month: SelectedStatementMonth) -> String { "\(monthNames[month.month - 1]) \(month.year)" }
    private func selectPlanningMonth(_ number: Int, year: Int) {
        if let month = try? SelectedStatementMonth(year: year, month: number) { viewModel.switchMonth(to: month) }
    }

    private func planningSectionButton(_ title: String, value: String, icon: String) -> some View {
        let selected = section == value
        return Button { section = value } label: {
            Label(title, systemImage: icon).font(theme.typography.button)
                .frame(maxWidth: .infinity).padding(.horizontal, 10).padding(.vertical, 8)
                .foregroundStyle(theme.palette.primaryText)
                .background(selected ? theme.palette.navigationSelected : .clear,
                            in: RoundedRectangle(cornerRadius: theme.radius.control))
                .contentShape(RoundedRectangle(cornerRadius: theme.radius.control))
        }.buttonStyle(LFPlainActionStyle()).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func comparison(width: CGFloat) -> some View {
        let calculation = viewModel.calculation
        let usesFunds = calculation.selectedINRLiquidity?.amount != 0 && calculation.selectedINRLiquidity != nil
        let layout = width >= max(780, amountWidth * 3 + 100)
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        return LFPanel(title: "Your month at a glance", systemImage: "calendar") {
            layout {
                summary("Available to send", calculation.transferablePrincipal,
                        secondary: calculation.estimatedINR, secondaryLabel: "Estimated INR", context: "After Qatar bills, savings kept in CBQ and the transfer fee")
                summary(usesFunds ? "India still to fund" : "India requirement",
                        usesFunds ? calculation.indiaFundingShortfall : calculation.indiaCommitments,
                        secondary: calculation.requiredQARPrincipal, secondaryLabel: "Required QAR", context: "To cover the bills you’ve included")
                summary((calculation.finalQARBuffer?.amount ?? 0) < 0 ? "Funding gap" : "Funding surplus",
                        calculation.finalQARBuffer, secondary: nil, context: "After covering India and keeping your CBQ reserve")
            }
            if let deficit = calculation.signedPotentialCapacity, deficit.amount < 0 {
                Label("Qatar shortfall: \(display(deficit))", systemImage: "exclamationmark.circle").font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            }
            if !viewModel.hasValidCalculation { Text("Complete the highlighted entries to calculate.").font(theme.typography.secondary).foregroundStyle(LFTheme.warning) }
        }
    }

    private func summary(_ label: String, _ amount: Money?, secondary: Money?, secondaryLabel: String? = nil, context: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(theme.typography.body.weight(.semibold))
            LFCompleteValue(lineHeight: theme.typography.lineHeight(.headlineMoney)) {
                Text(display(amount)).font(theme.typography.font(.headlineMoney, tabularDigits: true).weight(.semibold))
                    .foregroundStyle((amount?.amount ?? 0) < 0 ? LFTheme.warning : theme.palette.primaryText)
            }
            if let secondaryLabel { Text(secondary.map(display) ?? "\(secondaryLabel) unavailable").font(theme.typography.font(.body, tabularDigits: true)) }
            Text(context).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func countryHeading(_ flag: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 10) {
            Text(flag).font(theme.typography.sectionTitle).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(theme.typography.sectionTitle)
                Text(subtitle).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
        }.padding(.bottom, 4)
    }

    private func sectionHeading(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon).font(theme.typography.body.weight(.semibold))
            .foregroundStyle(theme.palette.primaryText).padding(.top, 5)
    }

    private func qatarColumn(width: CGFloat) -> some View {
        LFPanel(contentSpacing: 16) {
            countryHeading("🇶🇦", "In Qatar", "What comes in, what stays and what you can send")
            sectionHeading("Starting balance · pre-salary", "building.columns")
            balances(currency: "QAR", width: width)
            valueRow("Starting funds", viewModel.calculation.selectedQARLiquidity, truth: "")
            Divider()
            sectionHeading("Expected salary", "briefcase")
            moneyRow("Fixed earnings", field: .fixed, width: width)
            moneyRow("Variable earnings", field: .variable, width: width)
            DisclosureGroup(isExpanded: $showingDeductions) {
                deductions(width: width)
            } label: {
                HStack {
                    Text("Deductions")
                    Spacer(minLength: 8)
                    Text(display(viewModel.calculation.totalDeductions)).font(theme.typography.font(.body, tabularDigits: true))
                }
            }
            valueRow("Take-home estimate", viewModel.calculation.expectedNet, truth: "")
            Divider()
            sectionHeading("Bills in Qatar", "list.bullet.rectangle")
            commitmentRows(region: "qatar", values: viewModel.plan.qatarCommitments, width: width)
            valueRow("Total bills", viewModel.calculation.qatarCommitments, truth: "")
            Divider()
            moneyRow("Keep in CBQ", field: .reserve, width: width)
            Text("Money to leave in your account after everything is paid.").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            moneyRow("Transfer fee", field: .fee, width: width)
            valueRow("Available to send", viewModel.calculation.transferablePrincipal, truth: "After bills, CBQ reserve and one transfer fee")
        }
    }

    private func indiaColumn(width: CGFloat) -> some View {
        LFPanel(contentSpacing: 16) {
            countryHeading("🇮🇳", "In India", "The bills and payments you want to cover")
            sectionHeading("Bills in India", "list.bullet.rectangle")
            commitmentRows(region: "india", values: viewModel.plan.indiaCommitments, width: width)
            valueRow("Total needed", viewModel.calculation.indiaCommitments, truth: "")
            Divider()
            DisclosureGroup("Use money already in India", isExpanded: $showingINRFunds) {
                balances(currency: "INR", width: width)
            }
            if let funds = viewModel.calculation.selectedINRLiquidity, funds.amount != 0 {
                valueRow("Using existing funds", funds, truth: "")
            }
            valueRow("Still to fund", viewModel.calculation.indiaFundingShortfall, truth: "")
            valueRow("QAR needed", viewModel.calculation.requiredQARPrincipal, truth: "Transfer amount · fee is shown in Qatar")
            Divider()
            DisclosureGroup(viewModel.plan.referenceMode == .manual ? "Your rate · change" : "Al Dar rate · change", isExpanded: $showingManualFX) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Use your own rate for this month").font(theme.typography.body.weight(.medium))
                    input("INR for 1 QAR", key: "fx.rate", binding: Binding(get: { viewModel.rawText["fx.rate"] ?? "" }, set: { viewModel.setFX(rateText: $0, dateText: viewModel.rawText["fx.date"] ?? "") }))
                    manualFXObservationDate
                    Button("Use Al Dar instead") { viewModel.useSharedAlDar() }.lfSecondaryAction()
                }.padding(.top, 6)
            }.font(theme.typography.secondary)
            if viewModel.plan.referenceMode == .alDar && viewModel.plan.effectiveAlDarReference == nil {
                Label("Al Dar’s INR rate is unavailable. Qatar amounts are still shown; you can use your own rate if needed.", systemImage: "info.circle")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private func moneyRow(_ title: String, field: SalaryWorkspaceViewModel.MoneyField, width: CGFloat) -> some View {
        let layout = width >= minimumColumn ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        return layout {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
            input(title, key: field.rawValue, placeholder: "0", currency: "QAR", binding: Binding(get: { viewModel.amountInputText(field.rawValue) }, set: { _ = viewModel.updateMoney(field, text: $0) }))
                .frame(maxWidth: amountWidth)
        }.frame(maxWidth: max(540, amountWidth + 220), alignment: .leading)
    }

    private func input(_ title: String, key: String, placeholder: String? = nil, currency: String? = nil, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            TextField(title, text: Binding(get: { binding.wrappedValue }, set: { value in
                // AppKit can echo the displayed blank on focus. An untouched
                // zero stays untouched until the owner actually changes text.
                if value != binding.wrappedValue { binding.wrappedValue = value }
            }), prompt: Text(placeholder ?? title))
                .font(theme.typography.body).multilineTextAlignment(placeholder == "0" ? .trailing : .leading).lfTextField()
                .accessibilityLabel(title).accessibilityIdentifier("planner." + key)
            if let error = viewModel.fieldErrors[key] {
                Text(error).font(theme.typography.secondary).foregroundStyle(LFTheme.warning).fixedSize(horizontal: false, vertical: true)
            } else if let currency, let words = PlannerInputCodec.amountInWords(binding.wrappedValue, currency: currency, locale: .current) {
                Text(words).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Amount in words: " + words)
            }
        }
    }

    private func balances(currency: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let accounts = viewModel.eligibleAccounts.filter { $0.nativeCurrency.code == currency }
            if accounts.isEmpty { Text("No eligible \(currency) bank accounts.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText) }
            ForEach(accounts, id: \.id) { account in
                let balance = viewModel.plan.balances.first { $0.accountID == account.repositoryAccountId }
                let key = "balance.\(account.repositoryAccountId ?? "")"
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(account.nickname ?? account.name, isOn: Binding(get: { balance?.included ?? false }, set: { viewModel.setAccountIncluded(account, included: $0) }))
                    if currency == "QAR" || balance?.included == true {
                        HStack {
                            input("Planning balance", key: key, placeholder: "0", currency: currency, binding: Binding(get: { viewModel.amountInputText(key) }, set: { viewModel.setManualBalance(account, text: $0) })).frame(maxWidth: amountWidth)
                            Button("Capture current") { viewModel.captureAccountBalance(account) }.lfSecondaryAction()
                        }
                        Text(balance.map { viewModel.provenanceText($0.provenance) } ?? "Enter a planning balance").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                        if viewModel.unavailableCurrentBalanceAccountIDs.contains(account.repositoryAccountId ?? "") {
                            Text("Couldn’t refresh this balance. Your estimate is unchanged.").font(theme.typography.caption).foregroundStyle(LFTheme.warning)
                        }
                    }
                }
            }
            ForEach(viewModel.plan.balances.filter { balance in balance.nativeCurrency.code == currency && !accounts.contains(where: { $0.repositoryAccountId == balance.accountID }) }) { balance in
                Text("Saved balance · \(display(balance.money))").foregroundStyle(LFTheme.warning)
            }
        }
    }

    private func deductions(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.plan.deductions) { row in
                let layout = width >= minimumColumn ? AnyLayout(HStackLayout(alignment: .top, spacing: 8)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
                layout {
                    input("Deduction name", key: "deduction.label.\(row.id)", binding: Binding(get: { viewModel.rawText["deduction.label.\(row.id)"] ?? row.label }, set: { viewModel.editDeduction(id: row.id, label: $0) }))
                    input("Deduction QAR", key: "deduction.amount.\(row.id)", placeholder: "0", currency: "QAR", binding: Binding(get: { viewModel.amountInputText("deduction.amount.\(row.id)") }, set: { viewModel.editDeduction(id: row.id, amount: $0) })).frame(maxWidth: amountWidth)
                    Button(role: .destructive) { viewModel.removeDeduction(id: row.id) } label: { Image(systemName: "minus.circle") }.lfIconAction().accessibilityLabel("Remove deduction")
                }
                Toggle("This month only", isOn: Binding(get: { !row.recurs }, set: { viewModel.editDeduction(id: row.id, recurs: !$0) }))
                    .font(theme.typography.caption)
            }
            Button { viewModel.addDeduction() } label: { Label("Add deduction", systemImage: "plus") }.lfSecondaryAction()
        }.padding(.top, 6)
    }

    private func commitmentRows(region: String, values: [FundingPlanCommitment], width: CGFloat) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(values) { value in
                    let layout = width >= minimumColumn ? AnyLayout(HStackLayout(alignment: .top, spacing: 8)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
                    layout {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Toggle("Include", isOn: Binding(get: { value.included }, set: { viewModel.editCommitment(region: region, id: value.id, field: "included", text: String($0)) })).labelsHidden().accessibilityLabel("Include \(value.label)")
                            input("Bill name", key: "label.\(value.id)", binding: Binding(get: { viewModel.rawText["label.\(value.id)"] ?? value.label }, set: { viewModel.editCommitment(region: region, id: value.id, field: "label", text: $0) }))
                        }
                        HStack(alignment: .top, spacing: 10) {
                            input("\(value.money.currency.code) amount", key: "amount.\(value.id)", placeholder: "0", currency: value.money.currency.code, binding: Binding(get: { viewModel.amountInputText("amount.\(value.id)") }, set: { viewModel.editCommitment(region: region, id: value.id, field: "amount", text: $0) })).frame(maxWidth: amountWidth)
                            billDateButton(value, region: region)
                        }
                    }
                    DisclosureGroup(value.remark.isEmpty ? "Details" : value.remark) {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("This month only", isOn: Binding(get: { !value.recurs }, set: { viewModel.setCommitmentDetails(region: region, id: value.id, recurs: !$0) }))
                            if value.recurs {
                                Toggle("Reduced for this month only", isOn: Binding(get: { value.temporaryCarryBasis != nil }, set: { viewModel.setCommitmentDetails(region: region, id: value.id, temporary: $0) }))
                                Text(value.temporaryCarryBasis.map { "Next month retains \(MoneyFormatting.display($0)). Edit the remaining amount above." } ?? "Use this when part of a bill is already paid. Next month keeps the full amount.")
                                    .foregroundStyle(theme.palette.secondaryText)
                            }
                            TextField("Day / remark (optional)", text: Binding(get: { value.remark }, set: { viewModel.setCommitmentDetails(region: region, id: value.id, remark: $0) })).lfTextField()
                            let cards = viewModel.eligibleCommitmentAccounts.filter { $0.nativeCurrency.code == value.money.currency.code }
                            Picker("Related card", selection: Binding(get: { value.fundingAccountID ?? "" }, set: { viewModel.editCommitment(region: region, id: value.id, field: "account", text: $0) })) {
                                Text("None").tag("")
                                ForEach(cards, id: \.id) { Text($0.nickname ?? $0.name).tag($0.repositoryAccountId ?? "") }
                                if let id = value.fundingAccountID, !cards.contains(where: { $0.repositoryAccountId == id }) { Text(viewModel.retainedCommitmentAccountLabel(id: id)).tag(id) }
                            }
                            Button("Remove bill", role: .destructive) { viewModel.removeCommitment(region: region, id: value.id) }
                                .lfSecondaryAction()
                        }.font(theme.typography.secondary)
                    }.font(theme.typography.caption)
                    Divider()
                }
                Button { viewModel.addCommitment(region: region) } label: { Label("Add bill", systemImage: "plus") }.lfSecondaryAction()
            }
    }

    private func billDateButton(_ row: FundingPlanCommitment, region: String) -> some View {
        Button {
            billDateSelection = viewModel.billDatePickerValue(for: row)
            billDateRowID = row.id
        } label: {
            Label(row.dueDate(in: viewModel.month)?.presentation ?? "No date", systemImage: "calendar")
                .font(theme.typography.secondary).fixedSize().padding(.vertical, 5)
        }
        .lfIconAction().foregroundStyle(theme.palette.primaryText)
        .accessibilityLabel("Due date for \(row.label)").accessibilityValue(row.dueDate(in: viewModel.month)?.presentation ?? "No date")
        .popover(isPresented: Binding(get: { billDateRowID == row.id }, set: { if !$0 { billDateRowID = nil } })) {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("First due date", selection: $billDateSelection, displayedComponents: .date)
                    .datePickerStyle(.graphical).environment(\.calendar, Calendar(identifier: .gregorian))
                Text("Repeats on this day each month. Shorter months use their last day.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                HStack {
                    Button("Remove date") { viewModel.setBillDate(region: region, id: row.id, date: nil); billDateRowID = nil }
                        .lfSecondaryAction().disabled(row.dueDate == nil)
                    Spacer()
                    Button("Cancel") { billDateRowID = nil }.lfSecondaryAction().keyboardShortcut(.cancelAction)
                    Button("Use date") { viewModel.setBillDate(region: region, id: row.id, date: billDateSelection); billDateRowID = nil }
                        .lfPrimaryAction().keyboardShortcut(.defaultAction)
                }
            }.padding().frame(width: max(380, theme.typography.size(.button) * 28))
        }
    }

    private func display(_ money: Money?) -> String {
        viewModel.hasValidCalculation ? money.map { MoneyFormatting.display($0) } ?? "Unavailable" : "Incomplete"
    }

    private var manualFXObservationDate: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                fxDateSelection = viewModel.manualFXPickerDate()
                showingFXDatePicker = true
            } label: {
                HStack {
                    Text(viewModel.manualFXObservationDateTitle)
                    Spacer()
                    Image(systemName: "calendar")
                }.contentShape(Rectangle())
            }
            .buttonStyle(LFPlainActionStyle()).lfTextField()
            .accessibilityLabel("Observed date").accessibilityValue(viewModel.rawText["fx.date"] ?? "Not selected")
            .accessibilityIdentifier("planner.fx.date")
            .popover(isPresented: $showingFXDatePicker) {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker("Observed date", selection: $fxDateSelection, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                    HStack {
                        Button("Clear") {
                            viewModel.setFX(rateText: viewModel.rawText["fx.rate"] ?? "", dateText: "")
                            showingFXDatePicker = false
                        }.lfSecondaryAction().disabled((viewModel.rawText["fx.date"] ?? "").isEmpty)
                        Spacer()
                        Button("Cancel") { showingFXDatePicker = false }.lfSecondaryAction().keyboardShortcut(.cancelAction)
                        Button("Use date") {
                            viewModel.setManualFXObservationDate(fxDateSelection)
                            showingFXDatePicker = false
                        }.lfPrimaryAction().keyboardShortcut(.defaultAction)
                    }
                }.padding().frame(width: max(380, theme.typography.size(.button) * 28))
            }
            if let error = viewModel.fieldErrors["fx.date"] {
                Text(error).font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            }
        }
    }

    private func moneyInput(_ label: String, _ field: SalaryWorkspaceViewModel.MoneyField, _ provenance: FundingPlanValueProvenance) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack { Text(label); Spacer(); Text("QAR").foregroundStyle(theme.palette.secondaryText)
                input(label, key: field.rawValue, placeholder: "0", currency: "QAR", binding: Binding(
                    get: { viewModel.amountInputText(field.rawValue) },
                    set: { _ = viewModel.updateMoney(field, text: $0) }
                )).frame(maxWidth: 150)
            }
            Text(viewModel.provenanceText(provenance)).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Salary History").font(theme.typography.formTitle.weight(.semibold))
            if salaryStore.statements.isEmpty {
                LFPanel(title: "From payslip") {
                    Text("No accepted Qatar Airways salary statements.").foregroundStyle(theme.palette.secondaryText)
                }
            }
            ForEach(viewModel.historyGroups, id: \.month) { group in
                LFPanel(title: SalaryWorkspaceViewModel.monthTitle(group.month)) {
                    textValueRow("Salary actuals", MoneyFormatting.display(group.actual), truth: "Total from payslips")
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(group.statements) { statement in
                            DisclosureGroup {
                                salaryStatementDetail(statement)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(statement.evidence.kind.displayName).font(theme.typography.sectionTitle)
                                        Text("Pay period \(SalaryWorkspaceViewModel.monthTitle(statement.evidence.financialPeriod)) · Print date \(statement.evidence.printDate?.canonical ?? "Not printed")")
                                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                                    }
                                    Spacer()
                                    Text(MoneyFormatting.display(statement.evidence.printedPaymentTotal)).font(theme.typography.font(.headlineMoney, tabularDigits: true))
                                }
                            }
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func salaryStatementDetail(_ statement: SalaryStatement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From payslip").font(theme.typography.secondary.weight(.semibold)).foregroundStyle(LFTheme.info)
            Text("Qatar Airways")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Text("Earnings").font(theme.typography.body.weight(.semibold))
            ForEach(statement.evidence.earnings, id: \.sourceOrdinal) { component in
                LFInfoRow(title: "\(component.sourceOrdinal). \(component.sourceLabel)", value: MoneyFormatting.display(component.money), textRole: .formBody)
                    .monospacedDigit()
            }
            Text("Deductions").font(theme.typography.body.weight(.semibold))
            if statement.evidence.printedDeductionsTotal == nil {
                Text("No deduction section or total printed in source").foregroundStyle(theme.palette.secondaryText)
            } else {
                ForEach(statement.evidence.deductions, id: \.sourceOrdinal) { component in
                    LFInfoRow(title: "\(component.sourceOrdinal). \(component.sourceLabel)", value: MoneyFormatting.display(component.money), textRole: .formBody)
                        .monospacedDigit()
                }
            }
            Divider()
            valueRow("Printed earnings", statement.evidence.printedEarningsTotal, truth: "From payslip")
            if let deductions = statement.evidence.printedDeductionsTotal { valueRow("Printed deductions", deductions, truth: "From payslip") }
            valueRow("Printed net", statement.evidence.printedNet, truth: "From payslip")
            valueRow("Printed payment total", statement.evidence.printedPaymentTotal, truth: "From payslip")
        }.padding(.top, 8)
    }

    private func valueRow(_ label: String, _ money: Money?, truth: String) -> some View {
        textValueRow(label, (section == "Salary History" || viewModel.hasValidCalculation) ? money.map { MoneyFormatting.display($0) } ?? "Incomplete" : "Incomplete", truth: truth)
    }

    private func textValueRow(_ label: String, _ value: String, truth: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.valueGutter) {
                VStack(alignment: .leading, spacing: 2) { Text(label); if !truth.isEmpty { Text(truth).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText) } }
                Spacer(minLength: 0)
                Text(value).font(theme.typography.font(.body, tabularDigits: true).weight(.semibold)).fixedSize()
            }
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                Text(label)
                LFCompleteValue(lineHeight: theme.typography.lineHeight(.formBody)) {
                    Text(value).font(theme.typography.font(.body, tabularDigits: true).weight(.semibold))
                }
                if !truth.isEmpty { Text(truth).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText) }
            }
        }
        .foregroundStyle(value == "Incomplete" ? LFTheme.warning : theme.palette.primaryText)
    }
}
