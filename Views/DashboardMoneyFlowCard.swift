import AppKit
import SwiftUI

/// Read-only Dashboard entry point. Projection and source work stay outside
/// this view; inspection uses the existing exact-ID Transactions route.
struct DashboardMoneyFlowCard: View {
    @Environment(\.lfTheme) private var theme
    let projection: MoneyFlowProjection?
    @Binding var selectedMonth: SelectedStatementMonth
    @Binding var selectedCurrency: String
    let availableMonths: [SelectedStatementMonth]
    let availableCurrencies: [String]
    var isWorking = false
    var errorMessage: String?
    let onInspect: (MoneyFlowInspection) -> Void

    @State private var measure: MoneyFlowMeasure = .actualMovements
    @State private var showsList = false
    @State private var selection: MoneyFlowSelection?
    @State private var hovered: MoneyFlowSelection?
    @State private var showsCoverage = false
    @FocusState private var focused: MoneyFlowSelection?

    init(projection: MoneyFlowProjection?, selectedMonth: Binding<SelectedStatementMonth>,
         selectedCurrency: Binding<String>, availableMonths: [SelectedStatementMonth],
         availableCurrencies: [String], isWorking: Bool = false, errorMessage: String? = nil,
         onInspect: @escaping (MoneyFlowInspection) -> Void) {
        self.projection = projection
        _selectedMonth = selectedMonth
        _selectedCurrency = selectedCurrency
        self.availableMonths = availableMonths
        self.availableCurrencies = availableCurrencies
        self.isWorking = isWorking
        self.errorMessage = errorMessage
        self.onInspect = onInspect
    }

    private var current: MoneyFlowProjection? {
        guard let projection, projection.month == selectedMonth, projection.currency == selectedCurrency else { return nil }
        return projection
    }
    private var activeSelection: MoneyFlowSelection? { hovered ?? focused ?? selection }
    private var months: [SelectedStatementMonth] { Set(availableMonths + [selectedMonth]).sorted(by: >) }
    private var currencies: [String] { Set(availableCurrencies + [selectedCurrency]).filter { !$0.isEmpty }.sorted() }

    var body: some View {
        LFPanel(title: "Money flow", contentSpacing: theme.spacing.controlGap) {
            controls
            if isWorking, current != nil {
                HStack(spacing: theme.spacing.small) {
                    ProgressView().controlSize(.small)
                    Text("Updating money flow…").font(theme.typography.secondary)
                }
                .foregroundStyle(theme.palette.secondaryText)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let current {
                content(current)
                    .opacity(isWorking ? 0.6 : 1)
                    .disabled(isWorking)
            } else if isWorking {
                HStack(spacing: theme.spacing.small) {
                    ProgressView().controlSize(.small)
                    Text("Reading recorded movements…").font(theme.typography.secondary)
                }
                .foregroundStyle(theme.palette.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                .accessibilityLabel("Loading money flow")
            } else {
                Text("Money flow is unavailable until the ledger finishes loading.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
        }
        .accessibilityIdentifier("dashboard.moneyFlow")
        .onChange(of: selectedMonth) { clearSelection() }
        .onChange(of: selectedCurrency) { clearSelection() }
        .onChange(of: measure) { clearSelection() }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: theme.spacing.sectionGap) {
                monthControl
                currencyControl
                measureControl
                Spacer(minLength: 0)
                representationButton
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                HStack(alignment: .bottom, spacing: theme.spacing.controlGap) {
                    monthControl
                    currencyControl
                    Spacer(minLength: 0)
                }
                HStack(alignment: .bottom, spacing: theme.spacing.controlGap) {
                    measureControl
                    Spacer(minLength: 0)
                    representationButton
                }
            }
        }
    }

    private var monthControl: some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text("Calendar month").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            Picker("Calendar month", selection: $selectedMonth) {
                ForEach(months, id: \.self) { month in Text(monthTitle(month)).tag(month) }
            }
            .labelsHidden().pickerStyle(.menu).lfMenuAction()
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("dashboard.moneyFlow.month")
        }
    }

    private var currencyControl: some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text("Native currency").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            Picker("Native currency", selection: $selectedCurrency) {
                ForEach(currencies, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden().pickerStyle(.menu).lfMenuAction()
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("dashboard.moneyFlow.currency")
        }
    }

    private var measureControl: some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text("Measure").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            Picker("Money flow measure", selection: $measure) {
                ForEach(MoneyFlowMeasure.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden().pickerStyle(.menu).lfMenuAction()
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("dashboard.moneyFlow.measure")
        }
    }

    private var representationButton: some View {
        Button(showsList ? "Diagram" : "Flow list", systemImage: showsList ? "point.3.connected.trianglepath.dotted" : "list.bullet") {
            showsList.toggle(); clearSelection()
        }
        .lfSecondaryAction()
        .accessibilityIdentifier("dashboard.moneyFlow.representation")
    }

    @ViewBuilder private func content(_ projection: MoneyFlowProjection) -> some View {
        let graph = projection.graph(for: measure)
        if measure == .adjustedSpending { adjustedSummary(projection.adjustedAmounts) }
        Text(measure == .actualMovements
             ? "Recorded account and card movements · incoming and outgoing can differ."
             : "Purchases in this month, less their allocated refunds from any month.")
            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

        if graph.links.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                Text(measure == .actualMovements ? "No dated movements to show in this month." : "No recognised spending to show in this month.")
                    .font(theme.typography.body)
                Text("Choose another calendar month or native currency.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        } else {
            flowLegend(graph)
            GeometryReader { geometry in
                if showsList || geometry.size.width < minimumDiagramWidth {
                    flowList(graph, projection: projection)
                } else {
                    sankey(graph, projection: projection, width: geometry.size.width)
                }
            }
            .frame(height: 350)
            .accessibilityIdentifier("dashboard.moneyFlow.plot")
            selectionDetail(graph, projection: projection)
        }

        if measure == .actualMovements, !projection.conversionBridges.isEmpty {
            conversionBridges(projection.conversionBridges)
        }
        footer(projection, graph: graph)
    }

    private func flowLegend(_ graph: MoneyFlowGraph) -> some View {
        let order: [MoneyFlowRole] = [
            .income, .spending, .transfer, .cardPayment, .refund, .reversal,
            .outsideSpendingScope, .unresolved, .bank, .card, .periodBoundary, .conversionBoundary
        ]
        let roles = order.filter { role in graph.links.contains { $0.role == role } }
        let minimumWidth = max(180, theme.typography.nativeFont(.secondary).pointSize * 15)
        return VStack(alignment: .leading, spacing: theme.spacing.small) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: theme.spacing.sectionGap, alignment: .leading)],
                      alignment: .leading, spacing: theme.spacing.small) {
                ForEach(roles, id: \.rawValue) { role in
                    HStack(spacing: theme.spacing.small) {
                        flowSwatch(role)
                        Text(flowRoleTitle(role))
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .help(role.explanation)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(flowRoleTitle(role) + ". " + role.explanation)
                }
            }
            if roles.contains(.unresolved) {
                Text("Dashed flows: " + MoneyFlowRole.unresolved.explanation)
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("dashboard.moneyFlow.legend")
    }

    private func flowSwatch(_ role: MoneyFlowRole) -> some View {
        Rectangle()
            .fill(flowColor(role).opacity(role == .unresolved ? 0.22 : 1))
            .overlay {
                if role == .unresolved {
                    Rectangle().stroke(flowColor(role), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .frame(width: theme.spacing.valueGutter, height: theme.spacing.small)
            .accessibilityHidden(true)
    }

    private var minimumDiagramWidth: CGFloat {
        max(700, theme.typography.nativeFont(.body).pointSize * 48)
    }

    private func adjustedSummary(_ amounts: SpendingAmounts) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.valueGutter) {
                spendingMetric("Gross purchases", amount: amounts.gross)
                spendingMetric("Allocated refunds", amount: amounts.allocatedRefund)
                spendingMetric("Net spending", amount: amounts.net)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                spendingMetric("Gross purchases", amount: amounts.gross)
                spendingMetric("Allocated refunds", amount: amounts.allocatedRefund)
                spendingMetric("Net spending", amount: amounts.net)
            }
        }
    }

    private func spendingMetric(_ title: String, amount: Money) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            Text(MoneyFormatting.display(amount)).font(theme.typography.rowTitle).monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
        .help(exact(amount))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + ": " + exact(amount))
    }

    private func sankey(_ graph: MoneyFlowGraph, projection: MoneyFlowProjection, width: CGFloat) -> some View {
        let layout = MoneyFlowLayout(graph: graph, availableWidth: width,
            minimumNodeHeight: theme.typography.lineHeight(.body) * 2 + theme.typography.lineHeight(.secondary) * 2 + 12,
            labelWidth: max(142, theme.typography.nativeFont(.body).pointSize * 10.5))
        return ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                ForEach(layout.links) { placement in
                    if let link = graph.links.first(where: { $0.id == placement.id }), placement.thickness > 0 {
                        ribbon(link, placement: placement, graph: graph, projection: projection, size: layout.size)
                    }
                }
                ForEach(graph.nodes) { node in
                    if let placement = layout.nodes[node.id] {
                        nodeButton(node, placement: placement, graph: graph, projection: projection)
                            .frame(width: placement.labelRect.width, height: placement.labelRect.height)
                            .position(x: placement.labelRect.midX, y: placement.labelRect.midY)
                    }
                }
            }
            .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(measure.rawValue + ", " + monthTitle(projection.month) + ", " + projection.currency)
        }
        .scrollIndicators(.visible)
    }

    private func ribbon(_ link: MoneyFlowLink, placement: MoneyFlowLayout.LinkPlacement, graph: MoneyFlowGraph,
                        projection: MoneyFlowProjection, size: CGSize) -> some View {
        let identity = MoneyFlowSelection.link(link.id)
        let emphasized = activeSelection == identity || linkedToSelectedNode(link)
        let shape = MoneyFlowRibbon(start: placement.start, end: placement.end, thickness: placement.thickness)
        return Button { selection = identity } label: {
            shape
                .fill(flowColor(link.role).opacity(emphasized ? 0.96 : 0.82))
                .overlay {
                    shape.stroke(emphasized ? theme.interaction.focusRing : flowColor(link.role).opacity(0.95),
                        style: StrokeStyle(lineWidth: emphasized ? 1.5 : 0.5, dash: link.role == .unresolved ? [4, 3] : []))
                }
                .contentShape(MoneyFlowRibbon(start: placement.start, end: placement.end, thickness: max(8, placement.thickness)))
        }
        .buttonStyle(LFPlainActionStyle())
        .frame(width: size.width, height: size.height)
        .focused($focused, equals: identity)
        .onHover { hovered = $0 ? identity : nil }
        .help(linkDescription(link, graph: graph, projection: projection))
        .accessibilityLabel(linkDescription(link, graph: graph, projection: projection))
        .accessibilityHint("Selects this flow. Use View transactions to inspect its contributing records.")
        .accessibilityAddTraits(selection == identity ? .isSelected : [])
        .accessibilityIdentifier("dashboard.moneyFlow.link.\(link.id)")
    }

    private func nodeButton(_ node: MoneyFlowNode, placement: MoneyFlowLayout.NodePlacement,
                            graph: MoneyFlowGraph, projection: MoneyFlowProjection) -> some View {
        let identity = MoneyFlowSelection.node(node.id)
        let emphasized = activeSelection == identity
        return Button { selection = identity } label: {
            HStack(spacing: theme.spacing.small) {
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    Text(node.title).font(theme.typography.body).foregroundStyle(theme.palette.primaryText)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    if node.isAccount {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("In " + MoneyFormatting.number(node.incoming))
                            Text("Out " + MoneyFormatting.number(node.outgoing))
                        }
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText).monospacedDigit()
                    } else {
                        Text(MoneyFormatting.number(node.magnitude))
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText).monospacedDigit()
                    }
                    if node.role == .periodBoundary || node.role == .conversionBoundary || node.subtitle == "Same account · repeated endpoint" {
                        Text(node.subtitle ?? "").font(theme.typography.caption)
                            .foregroundStyle(theme.palette.secondaryText).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(flowColor(node.role))
                    .frame(width: MoneyFlowLayout.spineWidth, height: placement.barHeight)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 4)
            .background(emphasized ? theme.interaction.dataRowSelectedActive : theme.palette.contentSurface.opacity(0.94),
                        in: RoundedRectangle(cornerRadius: theme.radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.control)
                    .strokeBorder(emphasized ? theme.interaction.focusRing : .clear, lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(LFPlainActionStyle())
        .focused($focused, equals: identity)
        .onHover { hovered = $0 ? identity : nil }
        .help(nodeDescription(node, projection: projection))
        .accessibilityLabel(nodeDescription(node, projection: projection))
        .accessibilityHint("Selects this account or endpoint and its contributing records.")
        .accessibilityAddTraits(selection == identity ? .isSelected : [])
        .accessibilityIdentifier("dashboard.moneyFlow.node.\(node.id)")
    }

    private func flowList(_ graph: MoneyFlowGraph, projection: MoneyFlowProjection) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing.micro) {
                ForEach(graph.links.sorted { ($0.amount.amount, $0.id) > ($1.amount.amount, $1.id) }) { link in
                    let identity = MoneyFlowSelection.link(link.id)
                    let source = graph.nodes.first { $0.id == link.sourceID }?.title ?? ""
                    let target = graph.nodes.first { $0.id == link.targetID }?.title ?? ""
                    Button { selection = identity } label: {
                        VStack(alignment: .leading, spacing: theme.spacing.small) {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                                    Text(source + " → " + target).frame(maxWidth: .infinity, alignment: .leading)
                                    Text(MoneyFormatting.display(link.amount)).monospacedDigit().fixedSize()
                                }
                                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                                    Text(source + " → " + target)
                                    Text(MoneyFormatting.display(link.amount)).monospacedDigit()
                                }
                            }
                            HStack(spacing: theme.spacing.small) {
                                flowSwatch(link.role)
                                Text(flowRoleTitle(link.role))
                                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                            }
                        }
                        .font(theme.typography.body).foregroundStyle(theme.palette.primaryText)
                        .padding(theme.spacing.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(activeSelection == identity ? theme.interaction.dataRowSelectedActive : .clear,
                                    in: RoundedRectangle(cornerRadius: theme.radius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.radius.control)
                                .strokeBorder(focused == identity ? theme.interaction.focusRing : .clear, lineWidth: 1.5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(LFPlainActionStyle())
                    .focused($focused, equals: identity)
                    .onHover { hovered = $0 ? identity : nil }
                    .help(linkDescription(link, graph: graph, projection: projection))
                    .accessibilityLabel(linkDescription(link, graph: graph, projection: projection))
                    .accessibilityAddTraits(selection == identity ? .isSelected : [])
                    .accessibilityIdentifier("dashboard.moneyFlow.list.\(link.id)")
                }
            }
        }
        .accessibilityLabel("Money flow list, " + measure.rawValue)
    }

    @ViewBuilder private func selectionDetail(_ graph: MoneyFlowGraph, projection: MoneyFlowProjection) -> some View {
        if let detailSelection = selection ?? activeSelection, let detail = try? graph.detail(for: detailSelection) {
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: theme.spacing.controlGap) {
                    selectionText(detail, projection: projection)
                    Spacer(minLength: theme.spacing.small)
                    transactionButton(detail.allTransactionIDs, supportingIDs: detail.supportingIDs.subtracting(detail.transactionIDs))
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    selectionText(detail, projection: projection)
                    transactionButton(detail.allTransactionIDs, supportingIDs: detail.supportingIDs.subtracting(detail.transactionIDs))
                }
            }
            .accessibilityIdentifier("dashboard.moneyFlow.selection")
        } else {
            Text("Select an account or flow to inspect its exact amounts and transactions.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func selectionText(_ detail: MoneyFlowSelectionDetail, projection: MoneyFlowProjection) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(detail.title).font(theme.typography.rowTitle).fixedSize(horizontal: false, vertical: true)
            if let amount = detail.amount {
                Text(exact(amount)).font(theme.typography.tableMoney).monospacedDigit()
            } else if let incoming = detail.incoming, let outgoing = detail.outgoing {
                Text("Incoming " + exact(incoming) + " · Outgoing " + exact(outgoing))
                    .font(theme.typography.secondary).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            }
            if let amounts = detail.amounts {
                Text("Gross " + exact(amounts.gross) + " · Refunds " + exact(amounts.allocatedRefund) + " · Net " + exact(amounts.net))
                    .font(theme.typography.secondary).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            }
            Text(recordSummary(detail.transactionIDs, supporting: detail.supportingIDs, projection: projection))
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if detail.role == .unresolved {
                Text("A category labels a transaction. Income, spending and linked movements need their own financial interpretation.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                let groups = Dictionary(grouping: detail.transactionIDs.compactMap { projection.reviewRows[$0] }, by: \.explanation)
                ForEach(groups.keys.sorted(), id: \.self) { reason in
                    let rows = groups[reason] ?? []
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Text(reason)
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        let reviewIDs = Set(rows.map(\.id))
                        if reviewIDs != detail.allTransactionIDs {
                            Button("Review \(rows.count) \(rows.count == 1 ? "transaction" : "transactions")") {
                                inspect(reviewIDs)
                            }.lfSecondaryAction()
                        }
                        Text("Categories: " + Set(rows.map(\.source.categoryName)).sorted().joined(separator: ", "))
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }
                }
            }
            if !detail.refundDetails.isEmpty {
                Text(refundSummary(detail.refundDetails))
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .textSelection(.enabled)
    }

    private func transactionButton(_ ids: Set<String>, supportingIDs: Set<String> = []) -> some View {
        Button("View \(ids.count) \(ids.count == 1 ? "transaction" : "transactions")", systemImage: "arrow.right") {
            inspect(ids, supportingIDs: supportingIDs)
        }
        .lfSecondaryAction()
        .disabled(ids.isEmpty)
        .accessibilityIdentifier("dashboard.moneyFlow.transactions")
    }

    private func inspect(_ ids: Set<String>, supportingIDs: Set<String> = []) {
        guard let projection else { return }
        onInspect(projection.inspection(ids: ids, supportingIDs: supportingIDs))
    }

    private func conversionBridges(_ bridges: [MoneyFlowConversionBridge]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text("Reviewed currency bridges").font(theme.typography.rowTitle)
            ForEach(bridges) { bridge in
                Button { inspect(bridge.allTransactionIDs, supportingIDs: bridge.supportingIDs.subtracting(bridge.transactionIDs)) } label: {
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        Text(bridge.sent.accountTitle + " → " + bridge.received.accountTitle)
                            .font(theme.typography.body)
                        Text(exactMagnitude(bridge.sent.money) + " → " + exactMagnitude(bridge.received.money))
                            .font(theme.typography.tableMoney).monospacedDigit()
                        Text((bridge.sent.date?.presentation ?? "Date unavailable") + " → " +
                             (bridge.received.date?.presentation ?? "Date unavailable"))
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(LFPlainActionStyle())
                .help("Both actual native amounts are shown. No common-currency width or exchange rate is inferred.")
                .accessibilityHint("Opens both original transaction records.")
            }
        }
    }

    private func footer(_ projection: MoneyFlowProjection, graph: MoneyFlowGraph) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                coverageText(projection, graph: graph)
                Spacer(minLength: 0)
                coverageButton(projection)
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                coverageText(projection, graph: graph)
                coverageButton(projection)
            }
        }
    }

    private func coverageText(_ projection: MoneyFlowProjection, graph: MoneyFlowGraph) -> some View {
        Text("\(graph.transactionIDs.count) contributing records · " + coverageSummary(projection) +
             (projection.undatedTransactionIDs.isEmpty ? "" : " · \(projection.undatedTransactionIDs.count) undated records excluded"))
            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func coverageButton(_ projection: MoneyFlowProjection) -> some View {
        Button("Coverage & basis") { showsCoverage = true }
            .lfSecondaryAction().font(theme.typography.secondary)
            .accessibilityIdentifier("dashboard.moneyFlow.coverage")
            .popover(isPresented: $showsCoverage) {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                        HStack {
                            Text("Money flow basis").font(theme.typography.rowTitle)
                            Spacer()
                            Button("Close details", systemImage: "xmark") { showsCoverage = false }
                                .labelStyle(.iconOnly).lfSecondaryAction()
                                .keyboardShortcut(.cancelAction)
                        }
                        Text(monthTitle(projection.month) + " · " + projection.currency + " · All recorded accounts, including history-only accounts.")
                        Text("Actual movements use source dates. Account inflows and outflows can differ: no opening balance or savings residual is invented. Connections aggregate accounts; they do not trace a particular salary receipt.")
                        Text("Adjusted spending assigns allocated refunds to the original purchase month and category. Credit dates and account effects remain unchanged. Investment holdings are not funding movements.")
                        ForEach(projection.coverage) { account in
                            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                                Text(account.title + (account.isHistoryOnly ? " · History only" : "")).font(theme.typography.body)
                                Text(account.isComplete ? "Recorded source coverage spans this month." :
                                    "Coverage may have gaps" + (account.recordedThrough.map { " · recorded through " + $0.presentation } ?? "."))
                                    .foregroundStyle(theme.palette.secondaryText)
                            }
                        }
                        coverageRecords("Undated records outside the monthly graph", ids: projection.undatedTransactionIDs)
                        coverageRecords("Outside adjusted spending · retained in actual movements", ids: projection.excludedTransactionIDs)
                        coverageRecords("Records without a known bank/card direction", ids: projection.unknownDirectionIDs)
                        coverageRecords("Movements needing review", ids: projection.unresolvedTransactionIDs)
                        coverageRecords("Refund amounts needing allocation review", ids: projection.refundReviewTransactionIDs)
                    }
                    .font(theme.typography.secondary)
                    .padding(theme.spacing.panelPadding)
                }
                .frame(width: 500, height: 400)
            }
    }

    @ViewBuilder private func coverageRecords(_ title: String, ids: Set<String>) -> some View {
        if !ids.isEmpty {
            Button { showsCoverage = false; inspect(ids) } label: {
                HStack {
                    Text(title).multilineTextAlignment(.leading)
                    Spacer(minLength: theme.spacing.small)
                    Text("\(ids.count)").monospacedDigit()
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
            }
            .lfSecondaryAction()
        }
    }

    private func clearSelection() { selection = nil; hovered = nil; focused = nil }

    private func coverageSummary(_ projection: MoneyFlowProjection) -> String {
        if projection.coverage.isEmpty { return "No bank or card source coverage recorded" }
        return projection.coverage.contains { !$0.isComplete } ? "Coverage may have gaps" : "Recorded coverage spans this month"
    }

    private func linkedToSelectedNode(_ link: MoneyFlowLink) -> Bool {
        guard let activeSelection, case .node(let id) = activeSelection else { return false }
        return link.sourceID == id || link.targetID == id
    }

    private func flowColor(_ role: MoneyFlowRole) -> Color {
        switch role {
        case .income, .refund: flowInk(theme.financialPositive)
        case .spending: flowInk(theme.financialNegative)
        case .transfer: LFTheme.info
        case .cardPayment: flowInk(LFTheme.dark.palette.accentHover)
        case .unresolved: LFTheme.warning
        case .bank, .card, .reversal, .outsideSpendingScope: theme.palette.secondaryText
        case .conversionBoundary, .periodBoundary: theme.palette.fieldBorder
        }
    }

    private func flowInk(_ color: Color) -> Color {
        // Keep the existing hue roles while lifting dense ribbons off the panel.
        let base = NSColor(color)
        return Color(nsColor: base.blended(withFraction: 0.22, of: NSColor(theme.palette.primaryText)) ?? base)
    }

    private func flowRoleTitle(_ role: MoneyFlowRole) -> String {
        switch role {
        case .income: "Income"
        case .spending: "Spending"
        case .transfer: "Transfers"
        case .cardPayment: "Card payments"
        case .refund: "Refund credits"
        case .reversal: "Reversals"
        case .outsideSpendingScope: "Outside adjusted spending"
        case .unresolved: "Unresolved"
        case .bank: "Bank accounts"
        case .card: "Cards"
        case .periodBoundary: "Outside this month"
        case .conversionBoundary: "Currency conversion"
        }
    }

    private func linkDescription(_ link: MoneyFlowLink, graph: MoneyFlowGraph, projection: MoneyFlowProjection) -> String {
        let source = graph.nodes.first { $0.id == link.sourceID }?.title ?? ""
        let target = graph.nodes.first { $0.id == link.targetID }?.title ?? ""
        var text = source + " to " + target + ". " + exact(link.amount) + ". " + link.role.explanation + " "
        text += recordSummary(link.transactionIDs, supporting: link.supportingIDs, projection: projection)
        if let amounts = link.amounts {
            text += " Gross " + exact(amounts.gross) + ", allocated refunds " + exact(amounts.allocatedRefund) + ", net " + exact(amounts.net) + "."
        }
        if !link.refundDetails.isEmpty { text += " " + refundSummary(link.refundDetails) }
        return text
    }

    private func nodeDescription(_ node: MoneyFlowNode, projection: MoneyFlowProjection) -> String {
        node.title + (node.subtitle.map { ". " + $0 } ?? "") + ". Incoming " + exact(node.incoming) +
        ". Outgoing " + exact(node.outgoing) + ". " + recordSummary(node.transactionIDs, supporting: node.supportingIDs, projection: projection)
    }

    private func recordSummary(_ ids: Set<String>, supporting: Set<String>, projection: MoneyFlowProjection) -> String {
        let dates = ids.compactMap { projection.records[$0]?.date }.sorted()
        var result = "\(ids.count) actual \(ids.count == 1 ? "record" : "records")"
        if let first = dates.first, let last = dates.last {
            result += " · " + (first == last ? first.presentation : first.presentation + "–" + last.presentation)
        }
        let roles = Set(ids.compactMap { projection.records[$0]?.dateRole }).sorted()
        if !roles.isEmpty { result += " · " + roles.joined(separator: ", ") }
        if !supporting.isEmpty {
            result += " · \(supporting.count) supporting \(supporting.count == 1 ? "record" : "records")"
            let supportDates = supporting.compactMap { projection.records[$0]?.date }.sorted()
            if let first = supportDates.first, let last = supportDates.last {
                result += " (" + (first == last ? first.presentation : first.presentation + "–" + last.presentation) + ")"
            }
        }
        return result
    }

    private func refundSummary(_ details: [SpendingRefundDetail]) -> String {
        let dates = details.compactMap(\.creditDate).sorted()
        let dateText = dates.first.map { first in
            dates.last == first ? first.presentation : first.presentation + "–" + (dates.last?.presentation ?? first.presentation)
        } ?? "date unavailable"
        let residuals = Dictionary(details.map { ($0.creditTransactionID, $0.residual) }, uniquingKeysWith: { first, _ in first }).values
        let residual = try? Money.aggregate(Array(residuals))
        let allocated = try? Money.aggregate(details.map(\.allocated))
        return "\(details.count) refund \(details.count == 1 ? "allocation" : "allocations")" +
            (allocated.map { " · Allocated " + exact($0) } ?? "") + " · credit dates " + dateText +
            (residual.map { $0.amount > 0 ? " · Unallocated credit " + exact($0) : "" } ?? "")
    }

    private func monthTitle(_ month: SelectedStatementMonth) -> String {
        guard let date = try? StatementDate(year: month.year, month: month.month, day: 1),
              let instant = FinancialCalendar.instant(date) else { return month.canonical }
        var style = Date.FormatStyle().month(.wide).year()
        style.calendar = FinancialCalendar.calendar
        style.timeZone = FinancialCalendar.calendar.timeZone
        return instant.formatted(style)
    }

    private func exact(_ money: Money) -> String {
        // Values and accessibility retain the real currency scale even though
        // ordinary Dashboard labels follow its whole-unit display preference.
        money.currency.code + " " + ((try? money.canonicalDecimalString()) ?? NSDecimalNumber(decimal: money.amount).stringValue)
    }

    private func exactMagnitude(_ money: Money) -> String {
        (try? Money(amount: abs(money.amount), currency: money.currency)).map(exact) ?? exact(money)
    }
}

/// Geometry only. All Money arithmetic and financial grouping has completed
/// before conversion to points; no geometry value returns to the projection.
private struct MoneyFlowLayout {
    static let spineWidth: CGFloat = 7
    struct NodePlacement {
        let labelRect: CGRect
        let spineX: CGFloat
        let centerY: CGFloat
        let barHeight: CGFloat
    }
    struct LinkPlacement: Identifiable {
        let id: String
        let start: CGPoint
        let end: CGPoint
        let thickness: CGFloat
    }
    let size: CGSize
    let nodes: [String: NodePlacement]
    let links: [LinkPlacement]

    init(graph: MoneyFlowGraph, availableWidth: CGFloat, minimumNodeHeight: CGFloat, labelWidth: CGFloat) {
        let columns = Dictionary(grouping: graph.nodes, by: \.stage)
        let stages = columns.keys.sorted()
        let columnGap: CGFloat = 56, rowGap: CGFloat = 16, padding: CGFloat = 8
        let count = max(1, stages.count)
        let width = max(availableWidth, CGFloat(count) * labelWidth + CGFloat(count - 1) * columnGap + padding * 2)
        let maximumRows = columns.values.map(\.count).max() ?? 1
        let height = max(324, CGFloat(maximumRows) * minimumNodeHeight + CGFloat(maximumRows - 1) * rowGap + padding * 2)
        let availableHeight = height - padding * 2
        let amounts = Dictionary(uniqueKeysWithValues: graph.nodes.map {
            ($0.id, CGFloat(NSDecimalNumber(decimal: $0.magnitude.amount).doubleValue))
        })
        let maximumColumn = columns.values.map { $0.reduce(CGFloat.zero) { $0 + amounts[$1.id, default: 0] } }.max() ?? 0
        // One shared scale keeps the leading labels within the initial plot;
        // tall columns retain their readable rows in the scrollable layout.
        let initialFlowHeight: CGFloat = 324 - padding * 2
        var lower: CGFloat = 0, upper: CGFloat = maximumColumn > 0 ? min(availableHeight, initialFlowHeight) / maximumColumn : 0
        // Fit the exact-width ribbons around readable labels. The labels may
        // reserve extra space, but zero/small values never gain fake magnitude.
        for _ in 0..<24 {
            let scale = (lower + upper) / 2
            let fits = columns.values.allSatisfy { column in
                column.reduce(CGFloat.zero) { $0 + max(minimumNodeHeight, amounts[$1.id, default: 0] * scale) }
                    + CGFloat(max(0, column.count - 1)) * rowGap <= availableHeight
            }
            if fits { lower = scale } else { upper = scale }
        }
        let scale = lower
        var placements: [String: NodePlacement] = [:]
        let step = count > 1 ? (width - padding * 2 - labelWidth) / CGFloat(count - 1) : 0
        for (columnIndex, stage) in stages.enumerated() {
            let column = (columns[stage] ?? []).sorted {
                let left = amounts[$0.id, default: 0], right = amounts[$1.id, default: 0]
                return left == right ? ($0.title, $0.id) < ($1.title, $1.id) : left > right
            }
            var y = padding
            let x = padding + CGFloat(columnIndex) * step
            for node in column {
                let barHeight = amounts[node.id, default: 0] * scale
                let rowHeight = max(minimumNodeHeight, barHeight)
                placements[node.id] = .init(labelRect: .init(x: x, y: y, width: labelWidth, height: rowHeight),
                    spineX: x + labelWidth - 4 - Self.spineWidth / 2, centerY: y + rowHeight / 2, barHeight: barHeight)
                y += rowHeight + rowGap
            }
        }
        var outgoingOffsets: [String: CGFloat] = [:], incomingOffsets: [String: CGFloat] = [:]
        var ribbons: [LinkPlacement] = []
        let ordered = graph.links.sorted {
            let left = (placements[$0.sourceID]?.centerY ?? 0, placements[$0.targetID]?.centerY ?? 0, $0.id)
            let right = (placements[$1.sourceID]?.centerY ?? 0, placements[$1.targetID]?.centerY ?? 0, $1.id)
            return left < right
        }
        let nodeValues = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        for link in ordered {
            guard let source = placements[link.sourceID], let target = placements[link.targetID],
                  let sourceNode = nodeValues[link.sourceID], let targetNode = nodeValues[link.targetID] else { continue }
            let thickness = CGFloat(NSDecimalNumber(decimal: link.amount.amount).doubleValue) * scale
            let outHeight = CGFloat(NSDecimalNumber(decimal: sourceNode.outgoing.amount).doubleValue) * scale
            let inHeight = CGFloat(NSDecimalNumber(decimal: targetNode.incoming.amount).doubleValue) * scale
            let startY = source.centerY - outHeight / 2 + outgoingOffsets[link.sourceID, default: 0] + thickness / 2
            let endY = target.centerY - inHeight / 2 + incomingOffsets[link.targetID, default: 0] + thickness / 2
            ribbons.append(.init(id: link.id, start: .init(x: source.spineX + Self.spineWidth / 2, y: startY),
                end: .init(x: target.spineX - Self.spineWidth / 2, y: endY), thickness: thickness))
            outgoingOffsets[link.sourceID, default: 0] += thickness
            incomingOffsets[link.targetID, default: 0] += thickness
        }
        size = .init(width: width, height: height); nodes = placements; links = ribbons
    }
}

nonisolated private struct MoneyFlowRibbon: Shape {
    let start: CGPoint
    let end: CGPoint
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        guard thickness > 0 else { return Path() }
        let half = thickness / 2, bend = (end.x - start.x) * 0.48
        var path = Path()
        path.move(to: CGPoint(x: start.x, y: start.y - half))
        path.addCurve(to: CGPoint(x: end.x, y: end.y - half),
            control1: CGPoint(x: start.x + bend, y: start.y - half),
            control2: CGPoint(x: end.x - bend, y: end.y - half))
        path.addLine(to: CGPoint(x: end.x, y: end.y + half))
        path.addCurve(to: CGPoint(x: start.x, y: start.y + half),
            control1: CGPoint(x: end.x - bend, y: end.y + half),
            control2: CGPoint(x: start.x + bend, y: start.y + half))
        path.closeSubpath()
        return path
    }
}
