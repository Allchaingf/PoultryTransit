//
//  DashboardView.swift
//  PoultryTransit
//
//  Screen 1 — Today Overview. Live status across groups, the day's checklist
//  progress, alerts, the next transport, open tasks and low stock — all
//  derived from the store. Actions: Add Record / Open Analytics.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    var switchTab: (AppTab) -> Void

    @State private var showQuickAdd = false
    @State private var showAnalytics = false
    @State private var toast: String?

    private var checklistProgress: Double {
        guard !store.checklistItems.isEmpty else { return 0 }
        let done = store.checklistItems.filter { store.isChecklistDone($0) }.count
        return Double(done) / Double(store.checklistItems.count)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {

                header

                // Actions
                DualActionBar(
                    primaryTitle: "Add Record", primaryIcon: "plus.circle.fill",
                    primaryAction: { showQuickAdd = true },
                    secondaryTitle: "Open Analytics", secondaryIcon: "chart.bar.fill",
                    secondaryAction: { showAnalytics = true })

                NavigationLink(destination: WeeklyAnalyticsView(), isActive: $showAnalytics) { EmptyView() }.hidden()

                // Stat tiles
                HStack(spacing: 12) {
                    StatTile(value: "\(store.totalBirds)", label: "Birds", icon: "chicken", tint: PT.primary)
                    StatTile(value: "\(store.groups.count)", label: "Groups", icon: "square.stack.3d.up.fill", tint: PT.amber)
                    StatTile(value: "\(store.zones.count)", label: "Zones", icon: "map.fill", tint: PT.clay)
                }

                scenarioCards

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .navigationBarTitle("Today Overview", displayMode: .inline)
        .ptScreenBackground()
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView(asSheet: true).environmentObject(store).environmentObject(prefs)
        }
        .toast($toast)
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(PT.heroGradient)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting).font(PTFont.rounded(14, .semibold)).foregroundColor(.white.opacity(0.85))
                    Text("Farm workspace").font(PTFont.rounded(24, .bold)).foregroundColor(.white)
                    Text(scenarioLine).font(PTFont.caption).foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                ChickenSilhouette().fill(Color.white.opacity(0.9))
                    .frame(width: 64, height: 54)
            }
            .padding(18)
        }
        .frame(height: 120)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" } else if h < 18 { return "Good afternoon" } else { return "Good evening" }
    }
    private var scenarioLine: String {
        switch prefs.primaryScenario {
        case "inventory": return "Focused on supplies & stock"
        case "movement": return "Focused on transport & routes"
        case "observation": return "Focused on health & observation"
        default: return "Focused on planning your day"
        }
    }

    // MARK: Today checklist card

    @ViewBuilder
    private var scenarioCards: some View {
        switch prefs.primaryScenario {
        case "inventory":
            if prefs.selectedMetrics.contains("Cost") { lowStockCard }
            todayCard
            alertsCard
            tasksCard
            if let t = store.upcomingTransport { transportCard(t) }
        case "movement":
            if let t = store.upcomingTransport { transportCard(t) }
            if prefs.selectedMetrics.contains("Route time") { routeTimeCard }
            todayCard
            alertsCard
            tasksCard
            if prefs.selectedMetrics.contains("Cost") { lowStockCard }
        case "observation":
            alertsCard
            todayCard
            if prefs.selectedMetrics.contains("Care activity") || prefs.selectedMetrics.contains("Care consistency") {
                activityCard
            }
            tasksCard
            if let t = store.upcomingTransport { transportCard(t) }
            if prefs.selectedMetrics.contains("Cost") { lowStockCard }
        default: // planning
            todayCard
            alertsCard
            tasksCard
            if let t = store.upcomingTransport { transportCard(t) }
            if prefs.selectedMetrics.contains("Cost") { lowStockCard }
            if prefs.selectedMetrics.contains("Care activity") || prefs.selectedMetrics.contains("Care consistency") {
                activityCard
            }
            if prefs.selectedMetrics.contains("Route time") { routeTimeCard }
        }
    }

    // MARK: Today checklist card

    private var todayCard: some View {
        PTCard {
            HStack(spacing: 16) {
                ProgressRing(progress: checklistProgress, tint: PT.primary, size: 80)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily care").font(PTFont.headline).foregroundColor(PT.ink)
                    Text("\(store.checklistItems.filter { store.isChecklistDone($0) }.count) of \(store.checklistItems.count) checks done")
                        .font(PTFont.subhead).foregroundColor(PT.inkSoft)
                    if prefs.selectedMetrics.contains("Care consistency") {
                        StatusChip(text: "Consistency \(Int(store.careConsistency() * 100))%",
                                   color: PT.success, icon: "checkmark.seal.fill")
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: Alerts

    private var alertsCard: some View {
        let flags = store.liveRiskFlags()
        return PTCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Alerts", systemImage: "exclamationmark.triangle.fill")
                        .font(PTFont.headline).foregroundColor(PT.ink)
                    Spacer()
                    NavigationLink(destination: RiskFlagsView()) {
                        Text("Review").font(PTFont.callout).foregroundColor(PT.primary)
                    }
                }
                if flags.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(PT.success)
                        Text("All clear — nothing needs attention.").font(PTFont.subhead).foregroundColor(PT.inkSoft)
                    }
                } else {
                    ForEach(flags.prefix(3)) { flag in
                        HStack(spacing: 10) {
                            Circle().fill(flag.severity.color).frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(flag.title).font(PTFont.callout).foregroundColor(PT.ink).lineLimit(1)
                                Text(flag.detail).font(PTFont.caption).foregroundColor(PT.inkSoft).lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                    if flags.count > 3 {
                        Text("+\(flags.count - 3) more").font(PTFont.caption).foregroundColor(PT.inkFaint)
                    }
                }
            }
        }
    }

    // MARK: Transport

    private func transportCard(_ t: TransportLoad) -> some View {
        NavigationLink(destination: TransportPrepView()) {
            PTCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Next transport", systemImage: "shippingbox.fill")
                            .font(PTFont.headline).foregroundColor(PT.ink)
                        Spacer()
                        StatusChip(text: t.confirmed ? "Confirmed" : "Pending",
                                   color: t.confirmed ? PT.success : PT.warning, filled: t.confirmed)
                    }
                    Text(t.title).font(PTFont.callout).foregroundColor(PT.ink)
                    HStack(spacing: 14) {
                        miniStat("\(t.crateCount)", "crates", "shippingbox")
                        miniStat("\(t.totalBirds)", "birds", "chicken")
                        miniStat("\(t.stops.count)", "stops", "mappin.and.ellipse")
                        miniStat(FarmStore.dateShort(t.departure), "departs", "clock")
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func miniStat(_ v: String, _ l: String, _ icon: String) -> some View {
        VStack(spacing: 3) {
            IconGlyph(name: icon, size: 13, color: PT.primary)
            Text(v).font(PTFont.captionBold).foregroundColor(PT.ink)
            Text(l).font(.system(size: 9, design: .rounded)).foregroundColor(PT.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Tasks

    private var tasksCard: some View {
        let open = store.openTasksToday.prefix(3)
        return PTCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Open tasks", systemImage: "list.bullet.rectangle")
                        .font(PTFont.headline).foregroundColor(PT.ink)
                    Spacer()
                    NavigationLink(destination: TaskBoardView()) {
                        Text("All").font(PTFont.callout).foregroundColor(PT.primary)
                    }
                }
                if open.isEmpty {
                    Text("No open tasks. Nicely done.").font(PTFont.subhead).foregroundColor(PT.inkSoft)
                } else {
                    ForEach(Array(open)) { task in
                        HStack(spacing: 10) {
                            Button {
                                if let i = store.tasks.firstIndex(where: { $0.id == task.id }) {
                                    store.tasks[i].isDone.toggle(); store.saveAll()
                                }
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(task.isDone ? PT.success : PT.inkFaint)
                            }
                            Text(task.title).font(PTFont.callout).foregroundColor(PT.ink).lineLimit(1)
                            Spacer()
                            StatusChip(text: task.priority.title, color: task.priority.color)
                        }
                    }
                }
            }
        }
    }

    // MARK: Low stock

    private var lowStockCard: some View {
        let low = store.lowStock
        return Group {
            if !low.isEmpty {
                PTCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Low stock", systemImage: "tray.full.fill")
                                .font(PTFont.headline).foregroundColor(PT.ink)
                            Spacer()
                            NavigationLink(destination: InventoryShelfView()) {
                                Text("Inventory").font(PTFont.callout).foregroundColor(PT.primary)
                            }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(low) { item in
                                    StatusChip(text: "\(item.name) · \(FarmStore.num(item.quantity))\(item.unit)",
                                               color: PT.danger, icon: item.categoryIcon())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Activity chart

    private var activityCard: some View {
        let data = store.careCountsByDay(days: 7)
        return PTCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Care activity · 7 days").font(PTFont.headline).foregroundColor(PT.ink)
                LineChartView(points: data.map { Double($0.count) },
                              labels: data.map { weekday($0.date) },
                              tint: PT.primary)
            }
        }
    }

    // MARK: Route time

    private var routeTimeCard: some View {
        PTCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Route time", systemImage: "clock.fill")
                        .font(PTFont.headline).foregroundColor(PT.ink)
                    Spacer()
                    NavigationLink(destination: RoutePlannerView()) {
                        Text("Routes").font(PTFont.callout).foregroundColor(PT.primary)
                    }
                }
                if store.routes.isEmpty {
                    Text("No routes created yet.").font(PTFont.subhead).foregroundColor(PT.inkSoft)
                } else {
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            if let avg = store.averageRouteMinutes {
                                Text("~\(avg)").font(PTFont.title).foregroundColor(PT.success)
                                Text("avg real min").font(PTFont.caption).foregroundColor(PT.inkSoft)
                            } else {
                                Text("—").font(PTFont.title).foregroundColor(PT.inkFaint)
                                Text("avg real min").font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 4) {
                            Text("\(store.totalRouteMinutes)").font(PTFont.title).foregroundColor(PT.primary)
                            Text("est. min").font(PTFont.caption).foregroundColor(PT.inkSoft)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 4) {
                            Text("\(store.routeRuns.count)").font(PTFont.title).foregroundColor(PT.amber)
                            Text("runs").font(PTFont.caption).foregroundColor(PT.inkSoft)
                        }.frame(maxWidth: .infinity)
                    }
                    if store.averageRouteMinutes == nil {
                        Text("Run a route to record real timing.")
                            .font(PTFont.caption).foregroundColor(PT.inkFaint)
                    }
                }
            }
        }
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EE"; return String(f.string(from: date).prefix(2))
    }
}
