//
//  AnalyticsViews.swift
//  PoultryTransit
//
//  Analytics & reports: Weekly Trends (16), Compare Groups (17),
//  Farm Report builder with PDF export (18).
//

import SwiftUI

// MARK: - Screen 16: Weekly Analytics

struct WeeklyAnalyticsView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @State private var compareWeeks = false
    @State private var metric = "All"

    private var careThisWeek: Int { careCount(weekOffset: 0) }
    private var careLastWeek: Int { careCount(weekOffset: -1) }
    private var costThisWeek: Double { costSum(weekOffset: 0) }
    private var costLastWeek: Double { costSum(weekOffset: -1) }

    var body: some View {
        ScreenScaffold(title: "Weekly Trends") {
            DualActionBar(primaryTitle: compareWeeks ? "Hide Compare" : "Compare Weeks",
                          primaryIcon: "arrow.left.arrow.right",
                          primaryAction: { withAnimation { compareWeeks.toggle() } },
                          secondaryTitle: "Filter", secondaryIcon: "slider.horizontal.3",
                          secondaryAction: cycleFilter)

            SegChips(options: ["All", "Care", "Cost", "Records"], selection: $metric)

            if compareWeeks {
                PTCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This week vs last").font(PTFont.headline).foregroundColor(PT.ink)
                        compareRow("Care entries", careThisWeek, careLastWeek, prefix: "")
                        compareRow("Cost", Int(costThisWeek), Int(costLastWeek), prefix: prefs.currency)
                    }
                }
            }

            if metric == "All" || metric == "Care" {
                chartCard("Care activity · 7 days") {
                    let d = store.careCountsByDay(days: 7)
                    LineChartView(points: d.map { Double($0.count) }, labels: d.map { wd($0.date) }, tint: PT.primary)
                }
            }
            if prefs.selectedMetrics.contains("Care consistency") && (metric == "All" || metric == "Care") {
                chartCard("Care consistency") {
                    HStack(spacing: 16) {
                        ProgressRing(progress: store.careConsistency(), tint: PT.success, size: 84)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(Int(store.careConsistency() * 100))% checks done").font(PTFont.callout).foregroundColor(PT.ink)
                            Text("Across the last 7 days").font(PTFont.caption).foregroundColor(PT.inkSoft)
                        }
                        Spacer()
                    }
                }
            }
            if metric == "All" || metric == "Cost" {
                chartCard("Weekly spend") {
                    BarChartView(values: store.costsByWeek().map { ($0.label, $0.total) }, tint: PT.success, unitPrefix: prefs.currency)
                }
            }
            if metric == "All" || metric == "Records" {
                chartCard("Records per day · 7 days") {
                    let d = store.careCountsByDay(days: 7)
                    BarChartView(values: d.map { (wd($0.date), Double($0.count)) }, tint: PT.amber)
                }
            }

            chartCard("Stock levels") {
                if store.inventory.isEmpty {
                    Text("No inventory tracked yet.").font(PTFont.subhead).foregroundColor(PT.inkSoft)
                } else {
                    BarChartView(values: store.inventory.map { (String($0.name.prefix(6)), $0.quantity) }, tint: PT.clay)
                }
            }
        }
    }

    private func chartCard<C: View>(_ title: String, @ViewBuilder content: @escaping () -> C) -> some View {
        PTCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(PTFont.headline).foregroundColor(PT.ink)
                content()
            }
        }
    }
    private func compareRow(_ label: String, _ now: Int, _ prev: Int, prefix: String) -> some View {
        let delta = now - prev
        return HStack {
            Text(label).font(PTFont.callout).foregroundColor(PT.ink)
            Spacer()
            Text("\(prefix)\(now)").font(PTFont.headline).foregroundColor(PT.ink)
            StatusChip(text: "\(delta >= 0 ? "+" : "")\(delta)",
                       color: delta == 0 ? PT.neutral : (delta > 0 ? PT.success : PT.danger),
                       icon: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
        }
    }
    private func cycleFilter() {
        let order = ["All", "Care", "Cost", "Records"]
        metric = order[(order.firstIndex(of: metric)! + 1) % order.count]
    }
    private func wd(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EE"; return String(f.string(from: date).prefix(2))
    }
    private func careCount(weekOffset: Int) -> Int {
        let cal = Calendar.current
        guard let ref = cal.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) else { return 0 }
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ref)
        return store.careEntries.filter {
            let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.date)
            return c.weekOfYear == comps.weekOfYear && c.yearForWeekOfYear == comps.yearForWeekOfYear
        }.count
    }
    private func costSum(weekOffset: Int) -> Double {
        let cal = Calendar.current
        guard let ref = cal.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) else { return 0 }
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ref)
        return store.costs.filter {
            let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.date)
            return c.weekOfYear == comps.weekOfYear && c.yearForWeekOfYear == comps.yearForWeekOfYear
        }.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Screen 17: Trend Compare

struct TrendCompareView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @State private var selected: Set<UUID> = []
    @State private var applied: [UUID] = []
    @State private var compareMetric = "Cost"
    @State private var toast: String?

    private let metrics = ["Cost", "Care", "Birds", "Observations"]

    var body: some View {
        ScreenScaffold(title: "Compare Groups") {
            DualActionBar(primaryTitle: "Select Groups", primaryIcon: "checkmark.circle",
                          primaryAction: selectAll,
                          secondaryTitle: "Apply", secondaryIcon: "chart.bar.fill",
                          secondaryAction: apply)

            FormRow(label: "Groups to compare") {
                VStack(spacing: 8) {
                    ForEach(store.groups) { g in
                        Button { toggle(g.id) } label: {
                            HStack(spacing: 10) {
                                Circle().fill(g.color).frame(width: 12, height: 12)
                                Text(g.name).font(PTFont.callout).foregroundColor(PT.ink)
                                Spacer()
                                Image(systemName: selected.contains(g.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selected.contains(g.id) ? PT.primary : PT.stroke)
                            }
                            .padding(12).background(PT.subtle).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }.buttonStyle(PlainButtonStyle())
                    }
                    if store.groups.isEmpty {
                        Text("Create groups first.").font(PTFont.caption).foregroundColor(PT.inkFaint)
                    }
                }
            }

            FormRow(label: "Metric") { SegChips(options: metrics, selection: $compareMetric) }

            if applied.isEmpty {
                EmptyStateView(icon: "chart.bar.xaxis", title: "Nothing applied",
                               message: "Select groups and tap Apply to compare their load.")
            } else {
                PTCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(compareMetric) by group").font(PTFont.headline).foregroundColor(PT.ink)
                        ForEach(applied, id: \.self) { gid in
                            if let g = store.group(gid) {
                                let val = value(for: gid)
                                let maxVal = max(applied.map { value(for: $0) }.max() ?? 1, 1)
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Circle().fill(g.color).frame(width: 10, height: 10)
                                        Text(g.name).font(PTFont.caption).foregroundColor(PT.ink)
                                        Spacer()
                                        Text(displayValue(val)).font(PTFont.captionBold).foregroundColor(PT.inkSoft)
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(PT.subtle).frame(height: 16)
                                            Capsule().fill(g.color).frame(width: geo.size.width * CGFloat(val / maxVal), height: 16)
                                        }
                                    }.frame(height: 16)
                                }
                            }
                        }
                    }
                }
            }
        }
        .toast($toast)
        .onAppear { if applied.isEmpty { selected = Set(store.groups.map { $0.id }) } }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
    private func selectAll() { selected = Set(store.groups.map { $0.id }); toast = "All groups selected" }
    private func apply() {
        applied = store.groups.map { $0.id }.filter { selected.contains($0) }
        toast = applied.isEmpty ? "Select at least one group" : "Applied"
    }
    private func value(for gid: UUID) -> Double {
        switch compareMetric {
        case "Cost": return store.costForGroup(gid)
        case "Care": return Double(store.careCountForGroup(gid))
        case "Birds": return Double(store.group(gid)?.count ?? 0)
        case "Observations": return Double(store.observations.filter { $0.groupID == gid }.count)
        default: return 0
        }
    }
    private func displayValue(_ v: Double) -> String {
        compareMetric == "Cost" ? prefs.money(v) : FarmStore.num(v)
    }
}

// MARK: - Screen 18: Report Builder

struct ReportBuilderView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @State private var period = "This month"
    @State private var sections: [(heading: String, lines: [String])] = []
    @State private var generated = false
    @State private var pdfURL: URL?
    @State private var showShare = false
    @State private var toast: String?

    private let periods = ["This week", "This month", "All time"]

    var body: some View {
        ScreenScaffold(title: "Farm Report") {
            FormRow(label: "Period") { SegChips(options: periods, selection: $period) }

            DualActionBar(primaryTitle: "Generate Report", primaryIcon: "doc.text.magnifyingglass",
                          primaryAction: generate,
                          secondaryTitle: "Export PDF", secondaryIcon: "square.and.arrow.up",
                          secondaryAction: exportPDF)

            if !generated {
                EmptyStateView(icon: "doc.text.fill", title: "No report yet",
                               message: "Pick a period and generate a report of events, costs, tasks and alerts.")
            } else {
                ForEach(sections.indices, id: \.self) { i in
                    PTCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(sections[i].heading).font(PTFont.headline).foregroundColor(PT.ink)
                            Divider()
                            if sections[i].lines.isEmpty {
                                Text("— none —").font(PTFont.subhead).foregroundColor(PT.inkFaint)
                            } else {
                                ForEach(sections[i].lines, id: \.self) { line in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle().fill(PT.primary).frame(width: 6, height: 6).padding(.top, 6)
                                        Text(line).font(PTFont.subhead).foregroundColor(PT.ink)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = pdfURL { ActivityView(items: [url]) }
        }
        .toast($toast)
    }

    private func inPeriod(_ date: Date) -> Bool {
        let cal = Calendar.current
        switch period {
        case "This week": return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        case "This month": return cal.isDate(date, equalTo: Date(), toGranularity: .month)
        default: return true
        }
    }

    private func generate() {
        var result: [(String, [String])] = []

        result.append(("Overview", [
            "Groups: \(store.groups.count)  ·  Birds: \(store.totalBirds)",
            "Zones: \(store.zones.count)",
            "Care consistency (7d): \(Int(store.careConsistency() * 100))%"
        ]))

        let events = store.careEntries.filter { inPeriod($0.date) }
        result.append(("Care events (\(events.count))", events.prefix(12).map {
            "\(FarmStore.dateShort($0.date)) · \($0.type)\($0.groupID != nil ? " · \(store.groupName($0.groupID))" : "")\($0.note.isEmpty ? "" : " — \($0.note)")"
        }))

        let costs = store.costs.filter { inPeriod($0.date) }
        let total = costs.reduce(0) { $0 + $1.amount }
        var costLines = costs.prefix(12).map {
            "\(FarmStore.dateShort($0.date)) · \($0.category) · \(prefs.money($0.amount))\($0.note.isEmpty ? "" : " — \($0.note)")"
        }
        costLines.append("Total: \(prefs.money(total))")
        result.append(("Costs (\(costs.count))", costLines))

        result.append(("Open tasks", store.tasks.filter { !$0.isDone }.map {
            "\($0.priority.title) · \($0.title)\($0.dueDate != nil ? " · due \(FarmStore.dateShort($0.dueDate!))" : "")"
        }))

        result.append(("Active alerts", store.liveRiskFlags().map {
            "[\($0.severity.title)] \($0.title) — \($0.detail)"
        }))

        if let t = store.upcomingTransport {
            result.append(("Next transport", [
                "\(t.title) · departs \(dateTime(t.departure))",
                "\(t.crateCount) crates · \(t.totalBirds) birds · \(t.stops.count) stops",
                "Status: \(t.confirmed ? "Confirmed" : "Pending")"
            ]))
        }

        withAnimation { sections = result; generated = true }
        toast = "Report generated"
    }

    private func exportPDF() {
        if !generated { generate() }
        let title = "Farm Report · \(period)"
        if let url = PDFReportBuilder.build(title: title, sections: sections) {
            pdfURL = url
            showShare = true
        } else {
            toast = "Could not build PDF"
        }
    }
}
