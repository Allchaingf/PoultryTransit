//
//  FarmStore.swift
//  PoultryTransit
//
//  Central repository / Model layer. Holds every data collection,
//  persists to UserDefaults as JSON, derives analytics and risk flags,
//  and seeds sample data. Injected app-wide as an EnvironmentObject.
//

import SwiftUI
import Combine

final class FarmStore: ObservableObject {

    // MARK: Published collections
    @Published var groups: [BirdGroup] = []
    @Published var zones: [Zone] = []
    @Published var feedPortions: [FeedPortion] = []
    @Published var waterChecks: [WaterCheck] = []
    @Published var observations: [Observation] = []
    @Published var cleaningTasks: [CleaningTask] = []
    @Published var routes: [CareRoute] = []
    @Published var transports: [TransportLoad] = []
    @Published var inventory: [InventoryItem] = []
    @Published var costs: [Cost] = []
    @Published var tasks: [FarmTask] = []
    @Published var reminders: [Reminder] = []
    @Published var notes: [FarmNote] = []
    @Published var photoNotes: [PhotoNote] = []
    @Published var riskFlags: [RiskFlag] = []
    @Published var reviews: [DailyReviewRecord] = []
    @Published var careEntries: [CareEntry] = []
    @Published var checklistItems: [ChecklistItem] = []
    @Published var checklistDays: [ChecklistDay] = []
    @Published var capacityResults: [CapacityResult] = []
    @Published var routeRuns: [RouteRun] = []

    private var isLoading = false
    private let defaults = UserDefaults.standard

    init() {
        load()
        if checklistItems.isEmpty { checklistItems = FarmStore.defaultChecklist }
    }

    // MARK: - Persistence

    private func key(_ name: String) -> String { "pt.\(name)" }

    private func save<T: Encodable>(_ value: T, _ name: String) {
        guard !isLoading else { return }
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key(name))
        }
    }

    private func read<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let data = defaults.data(forKey: key(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func saveAll() {
        save(groups, "groups"); save(zones, "zones"); save(feedPortions, "feed")
        save(waterChecks, "water"); save(observations, "obs"); save(cleaningTasks, "clean")
        save(routes, "routes"); save(transports, "transport"); save(inventory, "inventory")
        save(costs, "costs"); save(tasks, "tasks"); save(reminders, "reminders")
        save(notes, "notes"); save(photoNotes, "photos"); save(riskFlags, "risks")
        save(reviews, "reviews"); save(careEntries, "care"); save(checklistItems, "checkitems")
        save(checklistDays, "checkdays"); save(capacityResults, "capacity")
        save(routeRuns, "routeRuns")
    }

    private func load() {
        isLoading = true
        groups = read([BirdGroup].self, "groups") ?? []
        zones = read([Zone].self, "zones") ?? []
        feedPortions = read([FeedPortion].self, "feed") ?? []
        waterChecks = read([WaterCheck].self, "water") ?? []
        observations = read([Observation].self, "obs") ?? []
        cleaningTasks = read([CleaningTask].self, "clean") ?? []
        routes = read([CareRoute].self, "routes") ?? []
        transports = read([TransportLoad].self, "transport") ?? []
        inventory = read([InventoryItem].self, "inventory") ?? []
        costs = read([Cost].self, "costs") ?? []
        tasks = read([FarmTask].self, "tasks") ?? []
        reminders = read([Reminder].self, "reminders") ?? []
        notes = read([FarmNote].self, "notes") ?? []
        photoNotes = read([PhotoNote].self, "photos") ?? []
        riskFlags = read([RiskFlag].self, "risks") ?? []
        reviews = read([DailyReviewRecord].self, "reviews") ?? []
        careEntries = read([CareEntry].self, "care") ?? []
        checklistItems = read([ChecklistItem].self, "checkitems") ?? []
        checklistDays = read([ChecklistDay].self, "checkdays") ?? []
        capacityResults = read([CapacityResult].self, "capacity") ?? []
        routeRuns = read([RouteRun].self, "routeRuns") ?? []
        isLoading = false
    }

    // MARK: - Lookups

    func group(_ id: UUID?) -> BirdGroup? { groups.first { $0.id == id } }
    func zone(_ id: UUID?) -> Zone? { zones.first { $0.id == id } }
    func groupName(_ id: UUID?) -> String { group(id)?.name ?? "Unassigned" }
    func zoneName(_ id: UUID?) -> String { zone(id)?.name ?? "No zone" }

    var totalBirds: Int { groups.reduce(0) { $0 + $1.count } }

    // MARK: - Care log helpers

    func logCare(_ entry: CareEntry) {
        careEntries.insert(entry, at: 0)
        save(careEntries, "care")
    }

    func entries(on day: Date) -> [CareEntry] {
        careEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: - Today summary

    var overdueCleaning: [CleaningTask] { cleaningTasks.filter { $0.isOverdue } }
    var overdueTasks: [FarmTask] { tasks.filter { $0.isOverdue } }
    var lowStock: [InventoryItem] { inventory.filter { $0.isLow } }
    var openTasksToday: [FarmTask] {
        tasks.filter { !$0.isDone }.sorted { ($0.priority.weight) > ($1.priority.weight) }
    }
    var flaggedObservations: [Observation] { observations.filter { $0.flagged } }
    var upcomingTransport: TransportLoad? {
        transports.filter { $0.departure >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.departure < $1.departure }.first
    }

    // MARK: - Cascade delete helpers

    func relatedCountForGroup(_ id: UUID) -> Int {
        feedPortions.filter { $0.groupID == id }.count +
        observations.filter { $0.groupID == id }.count +
        costs.filter { $0.groupID == id }.count +
        notes.filter { $0.groupID == id }.count +
        transports.flatMap(\.crates).filter { $0.groupID == id }.count
    }

    func deleteGroup(_ id: UUID) {
        groups.removeAll { $0.id == id }
        feedPortions.removeAll { $0.groupID == id }
        observations.removeAll { $0.groupID == id }
        costs.removeAll { $0.groupID == id }
        for i in notes.indices where notes[i].groupID == id { notes[i].groupID = nil }
        for i in transports.indices {
            transports[i].crates.removeAll { $0.groupID == id }
        }
        saveAll()
    }

    func relatedCountForZone(_ id: UUID) -> Int {
        groups.filter { $0.zoneID == id }.count +
        waterChecks.filter { $0.zoneID == id }.count +
        cleaningTasks.filter { $0.zoneID == id }.count +
        tasks.filter { $0.zoneID == id }.count +
        notes.filter { $0.zoneID == id }.count +
        routes.filter { $0.stopZoneIDs.contains(id) }.count
    }

    func deleteZone(_ id: UUID) {
        zones.removeAll { $0.id == id }
        for i in groups.indices where groups[i].zoneID == id { groups[i].zoneID = nil }
        waterChecks.removeAll { $0.zoneID == id }
        cleaningTasks.removeAll { $0.zoneID == id }
        for i in tasks.indices where tasks[i].zoneID == id { tasks[i].zoneID = nil }
        for i in notes.indices where notes[i].zoneID == id { notes[i].zoneID = nil }
        for i in routes.indices { routes[i].stopZoneIDs.removeAll { $0 == id } }
        saveAll()
    }

    func relatedCountForInventoryItem(_ id: UUID) -> Int {
        feedPortions.filter { $0.feedItemID == id }.count
    }

    func deleteInventoryItem(_ id: UUID) {
        inventory.removeAll { $0.id == id }
        for i in feedPortions.indices where feedPortions[i].feedItemID == id {
            feedPortions[i].feedItemID = nil
        }
        saveAll()
    }

    // MARK: - Risk derivation (merges manual + derived live flags)

    func liveRiskFlags() -> [RiskFlag] {
        var result = riskFlags.filter { !$0.isResolved }
        for t in overdueCleaning {
            result.append(RiskFlag(title: "Overdue cleaning: \(t.title)",
                                   detail: "Due \(Self.dateShort(t.dueDate)) in \(zoneName(t.zoneID))",
                                   severity: .medium, source: "Overdue"))
        }
        for t in overdueTasks {
            result.append(RiskFlag(title: "Overdue task: \(t.title)",
                                   detail: "Priority \(t.priority.title)",
                                   severity: t.priority, source: "Overdue"))
        }
        for i in lowStock {
            result.append(RiskFlag(title: "Low stock: \(i.name)",
                                   detail: "\(Self.num(i.quantity)) \(i.unit) left (min \(Self.num(i.minLevel)))",
                                   severity: .medium, source: "Low stock"))
        }
        for o in flaggedObservations {
            result.append(RiskFlag(title: "Flagged group: \(groupName(o.groupID))",
                                   detail: o.symptom.isEmpty ? "Re-check requested" : o.symptom,
                                   severity: .high, source: "Observation"))
        }
        // overloaded zones from latest capacity results
        for c in capacityResults where c.status == "Overloaded" {
            result.append(RiskFlag(title: "Zone overload: \(c.zoneName)",
                                   detail: "\(Self.num(c.birdsPerSqM)) birds/m²",
                                   severity: .high, source: "Overload"))
        }
        return result.sorted { $0.severity.weight > $1.severity.weight }
    }

    // MARK: - Analytics

    /// Care entries grouped per day for the last `days` days (oldest→newest).
    func careCountsByDay(days: Int = 7) -> [(date: Date, count: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = careEntries.filter { cal.isDate($0.date, inSameDayAs: day) }.count
            return (day, count)
        }
    }

    func costsByWeek(weeks: Int = 6) -> [(label: String, total: Double)] {
        let cal = Calendar.current
        let today = Date()
        return (0..<weeks).reversed().map { offset in
            let weekStart = cal.date(byAdding: .weekOfYear, value: -offset, to: today)!
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
            let total = costs.filter {
                let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.date)
                return c.weekOfYear == comps.weekOfYear && c.yearForWeekOfYear == comps.yearForWeekOfYear
            }.reduce(0) { $0 + $1.amount }
            return ("W\(comps.weekOfYear ?? 0)", total)
        }
    }

    func costsByCategory() -> [(category: String, total: Double)] {
        Cost.categories.map { cat in
            (cat, costs.filter { $0.category == cat }.reduce(0) { $0 + $1.amount })
        }.filter { $0.total > 0 }
    }

    var monthCost: Double {
        let cal = Calendar.current
        return costs.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Care consistency: % of checklist items completed over the last 7 days.
    func careConsistency(days: Int = 7) -> Double {
        guard !checklistItems.isEmpty else { return 0 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var done = 0, total = 0
        for offset in 0..<days {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let key = Self.dayKey(day)
            total += checklistItems.count
            if let rec = checklistDays.first(where: { $0.dayKey == key }) {
                if rec.skippedToday { continue }
                done += rec.doneItemIDs.count
            }
        }
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    func costForGroup(_ id: UUID?) -> Double {
        costs.filter { $0.groupID == id }.reduce(0) { $0 + $1.amount }
    }
    func careCountForGroup(_ id: UUID?) -> Int {
        careEntries.filter { $0.groupID == id }.count
    }
    func tasksForZone(_ id: UUID?) -> Int {
        tasks.filter { $0.zoneID == id }.count
    }

    // MARK: - Route timing (estimated + real)

    /// Sum of *estimated* minutes across all routes (planned workload).
    var totalRouteMinutes: Int {
        routes.reduce(0) { $0 + $1.estimatedMinutes }
    }
    /// Routes that have at least one recorded run.
    var completedRoutes: Int {
        routes.filter { r in routeRuns.contains { $0.routeID == r.id } }.count
    }

    /// Recorded runs for one route, newest first.
    func runs(for routeID: UUID) -> [RouteRun] {
        routeRuns.filter { $0.routeID == routeID }.sorted { $0.finishedAt > $1.finishedAt }
    }
    /// Most recent recorded run for a route.
    func lastRun(for routeID: UUID) -> RouteRun? { runs(for: routeID).first }

    /// Average *real* minutes for a route across its runs, or nil if never run.
    func averageActualMinutes(for routeID: UUID) -> Int? {
        let mins = routeRuns.filter { $0.routeID == routeID }.map { $0.actualMinutes }
        guard !mins.isEmpty else { return nil }
        return Int((Double(mins.reduce(0, +)) / Double(mins.count)).rounded())
    }
    /// Average *real* minutes across every recorded run, or nil if none.
    var averageRouteMinutes: Int? {
        guard !routeRuns.isEmpty else { return nil }
        return Int((Double(routeRuns.map { $0.actualMinutes }.reduce(0, +)) / Double(routeRuns.count)).rounded())
    }

    /// Record a completed (or partial) route run and stamp the route's last-run time.
    func recordRouteRun(route: CareRoute, startedAt: Date, completedStops: Int) {
        let total = route.stopZoneIDs.count
        let run = RouteRun(routeID: route.id, routeName: route.name,
                           startedAt: startedAt, finishedAt: Date(),
                           completedStops: completedStops, totalStops: total,
                           partial: completedStops < total)
        routeRuns.insert(run, at: 0)
        if let i = routes.firstIndex(where: { $0.id == route.id }) {
            routes[i].lastRunAt = run.finishedAt
        }
        saveAll()
    }

    // MARK: - Checklist

    func todayChecklist() -> ChecklistDay {
        let key = Self.dayKey(Date())
        if let existing = checklistDays.first(where: { $0.dayKey == key }) { return existing }
        let fresh = ChecklistDay(dayKey: key, doneItemIDs: [])
        return fresh
    }

    func toggleChecklist(item: ChecklistItem) {
        let key = Self.dayKey(Date())
        if let idx = checklistDays.firstIndex(where: { $0.dayKey == key }) {
            if let i = checklistDays[idx].doneItemIDs.firstIndex(of: item.id) {
                checklistDays[idx].doneItemIDs.remove(at: i)
            } else {
                checklistDays[idx].doneItemIDs.append(item.id)
            }
            checklistDays[idx].skippedToday = false
        } else {
            var day = ChecklistDay(dayKey: key, doneItemIDs: [item.id])
            day.skippedToday = false
            checklistDays.append(day)
        }
        save(checklistDays, "checkdays")
    }

    func skipChecklistToday() {
        let key = Self.dayKey(Date())
        if let idx = checklistDays.firstIndex(where: { $0.dayKey == key }) {
            checklistDays[idx].skippedToday = true
            checklistDays[idx].doneItemIDs = []
        } else {
            checklistDays.append(ChecklistDay(dayKey: key, doneItemIDs: [], skippedToday: true))
        }
        save(checklistDays, "checkdays")
    }

    func isChecklistDone(_ item: ChecklistItem) -> Bool {
        let key = Self.dayKey(Date())
        return checklistDays.first(where: { $0.dayKey == key })?.doneItemIDs.contains(item.id) ?? false
    }

    // MARK: - Formatting helpers

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func dateShort(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }
    static func num(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value)) : String(format: "%.1f", value)
    }

    // MARK: - Default checklist

    static let defaultChecklist: [ChecklistItem] = [
        ChecklistItem(title: "Refill feeders", period: "Morning", icon: "leaf.fill"),
        ChecklistItem(title: "Fresh water", period: "Morning", icon: "drop.fill"),
        ChecklistItem(title: "Open coop doors", period: "Morning", icon: "lock.open.fill"),
        ChecklistItem(title: "Quick health scan", period: "Morning", icon: "eye.fill"),
        ChecklistItem(title: "Collect & tidy", period: "Evening", icon: "tray.fill"),
        ChecklistItem(title: "Top up litter", period: "Evening", icon: "square.stack.3d.up.fill"),
        ChecklistItem(title: "Close & secure doors", period: "Evening", icon: "lock.fill"),
        ChecklistItem(title: "Final water check", period: "Evening", icon: "drop.fill")
    ]

    // MARK: - Sample data + reset

    func resetAll(keepChecklistTemplate: Bool = true) {
        groups = []; zones = []; feedPortions = []; waterChecks = []; observations = []
        cleaningTasks = []; routes = []; transports = []; inventory = []; costs = []
        tasks = []; reminders = []; notes = []; photoNotes = []; riskFlags = []
        reviews = []; careEntries = []; checklistDays = []; capacityResults = []; routeRuns = []
        if !keepChecklistTemplate { checklistItems = FarmStore.defaultChecklist }
        saveAll()
    }

    func loadSampleData() {
        let cal = Calendar.current
        let now = Date()

        // Zones
        let coop = Zone(name: "Main Coop", kind: "Coop", order: 0, areaSqM: 24, perchLengthM: 9, note: "Primary layer house")
        let run = Zone(name: "Open Run", kind: "Run", order: 1, areaSqM: 60, perchLengthM: 0, note: "Daytime range")
        let quarantine = Zone(name: "Quarantine Pen", kind: "Quarantine", order: 2, areaSqM: 6, perchLengthM: 2, note: "New / sick birds")
        let dock = Zone(name: "Loading Dock", kind: "Transport Point", order: 3, areaSqM: 12, perchLengthM: 0, note: "Crate staging")
        zones = [coop, run, quarantine, dock]

        // Groups
        let layers = BirdGroup(name: "Brown Layers", kind: "Layers", count: 42, zoneID: coop.id, colorHex: "3E8E7E")
        let broilers = BirdGroup(name: "Broiler Batch A", kind: "Broilers", count: 60, zoneID: run.id, colorHex: "F2A93B")
        let chicks = BirdGroup(name: "Spring Chicks", kind: "Chicks", count: 25, zoneID: quarantine.id, colorHex: "C76B4A")
        groups = [layers, broilers, chicks]

        // Inventory
        inventory = [
            InventoryItem(name: "Layer Pellets", category: "Feed", quantity: 80, unit: "kg", minLevel: 40),
            InventoryItem(name: "Broiler Grower", category: "Feed", quantity: 30, unit: "kg", minLevel: 35),
            InventoryItem(name: "Pine Shavings", category: "Litter", quantity: 6, unit: "bales", minLevel: 3),
            InventoryItem(name: "Calcium Grit", category: "Supplement", quantity: 4, unit: "kg", minLevel: 5),
            InventoryItem(name: "Spare Drinkers", category: "Drinker", quantity: 8, unit: "pcs", minLevel: 4),
            InventoryItem(name: "Wire Clips", category: "Hardware", quantity: 50, unit: "pcs", minLevel: 20)
        ]

        // Costs (last few weeks)
        costs = [
            Cost(category: "Feed", amount: 64, date: cal.date(byAdding: .day, value: -2, to: now)!, groupID: layers.id, note: "Pellet refill"),
            Cost(category: "Health", amount: 18, date: cal.date(byAdding: .day, value: -5, to: now)!, groupID: chicks.id, note: "Vitamins"),
            Cost(category: "Transport", amount: 40, date: cal.date(byAdding: .day, value: -9, to: now)!, note: "Fuel + crates"),
            Cost(category: "Equipment", amount: 25, date: cal.date(byAdding: .day, value: -14, to: now)!, note: "New feeder"),
            Cost(category: "Feed", amount: 58, date: cal.date(byAdding: .day, value: -18, to: now)!, groupID: broilers.id)
        ]

        // Cleaning
        cleaningTasks = [
            CleaningTask(title: "Litter change", zoneID: coop.id, type: "Litter change", dueDate: cal.date(byAdding: .day, value: -1, to: now)!),
            CleaningTask(title: "Sanitize drinkers", zoneID: run.id, type: "Disinfect drinkers", dueDate: cal.date(byAdding: .day, value: 1, to: now)!),
            CleaningTask(title: "Full clean", zoneID: quarantine.id, type: "Full clean", dueDate: cal.date(byAdding: .day, value: 3, to: now)!)
        ]

        // Tasks
        tasks = [
            FarmTask(title: "Repair run fence", priority: .high, dueDate: cal.date(byAdding: .day, value: -1, to: now)!, zoneID: run.id),
            FarmTask(title: "Order layer pellets", priority: .medium, dueDate: cal.date(byAdding: .day, value: 2, to: now)!),
            FarmTask(title: "Weigh broiler batch", priority: .low, dueDate: cal.date(byAdding: .day, value: 4, to: now)!, zoneID: run.id)
        ]

        // Observations
        observations = [
            Observation(groupID: chicks.id, activity: .fair, appetite: .good, appearance: .fair, symptom: "Two chicks less active", flagged: true, note: "Watch overnight"),
            Observation(groupID: layers.id, activity: .good, appetite: .good, appearance: .good)
        ]

        // Water checks
        waterChecks = [
            WaterCheck(zoneID: coop.id, waterOK: true, temperatureC: 21, ventilationOK: true, drinkersClean: true),
            WaterCheck(zoneID: run.id, waterOK: true, temperatureC: 24, ventilationOK: true, drinkersClean: false, note: "Clean drinker B")
        ]

        // Route
        routes = [
            CareRoute(name: "Morning Round", stopZoneIDs: [coop.id, run.id, quarantine.id], minutesPerStop: 8)
        ]

        // Transport
        transports = [
            TransportLoad(title: "Broilers to market",
                          departure: cal.date(byAdding: .day, value: 2, to: now)!,
                          crates: [
                            Crate(label: "Crate 1", birdCount: 12, hasWater: true, groupID: broilers.id),
                            Crate(label: "Crate 2", birdCount: 12, hasWater: true, groupID: broilers.id),
                            Crate(label: "Crate 3", birdCount: 10, hasWater: false, groupID: broilers.id)
                          ],
                          stops: ["Weigh station", "Highway rest stop", "Market dock"],
                          note: "Leave before midday heat")
        ]

        // Notes
        notes = [
            FarmNote(title: "Coop ventilation", body: "Add a vent on the east wall before summer.", zoneID: coop.id, tag: "Repair"),
            FarmNote(title: "Chick growth", body: "Spring chicks ready to merge in ~2 weeks.", groupID: chicks.id, tag: "General")
        ]

        // Reminders
        reminders = [
            Reminder(title: "Morning feed & water", time: Self.timeToday(7, 0), kind: "Morning"),
            Reminder(title: "Evening lock-up", time: Self.timeToday(19, 30), kind: "Evening"),
            Reminder(title: "Transport prep check", time: Self.timeToday(6, 30), kind: "Transport", isEnabled: false)
        ]

        // Care entries spread over last 7 days
        var entries: [CareEntry] = []
        for offset in 0..<7 {
            let day = cal.date(byAdding: .day, value: -offset, to: now)!
            entries.append(CareEntry(type: "Feeding", date: day, groupID: layers.id, zoneID: coop.id, note: "AM feed"))
            entries.append(CareEntry(type: "Water", date: day, zoneID: run.id))
            if offset % 2 == 0 {
                entries.append(CareEntry(type: "Observation", date: day, groupID: broilers.id, zoneID: run.id))
            }
        }
        careEntries = entries.sorted { $0.date > $1.date }

        // Checklist progress for last few days
        var days: [ChecklistDay] = []
        for offset in 1..<5 {
            let day = cal.date(byAdding: .day, value: -offset, to: now)!
            let done = checklistItems.prefix(6 - offset).map { $0.id }
            days.append(ChecklistDay(dayKey: Self.dayKey(day), doneItemIDs: Array(done)))
        }
        checklistDays = days

        // Capacity result
        capacityResults = [
            CapacityResult(zoneName: "Main Coop", areaSqM: 24, perchLengthM: 9, birdCount: 42,
                           birdsPerSqM: 1.75, perchPerBirdCM: 21.4, status: "Comfortable")
        ]

        saveAll()
    }

    static func timeToday(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
