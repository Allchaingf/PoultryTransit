//
//  MoreViews.swift
//  PoultryTransit
//
//  "More" hub + Inventory (8), Cost Tracker (9), Task Board (10),
//  Reminder Queue (11), Notes Board (12), Photo Markup (13), Risk Flags (14).
//

import SwiftUI

// MARK: - Hub

struct MoreHubView: View {
    @EnvironmentObject var store: FarmStore

    var body: some View {
        ScreenScaffold(title: "More",
                       subtitle: "Inventory, costs, tasks, notes, analytics and reports.") {
            SectionHeader(title: "Operations")
            HubGrid {
                HubLinkCard(title: "Supplies", subtitle: "\(store.inventory.count) items",
                            icon: "shippingbox.fill", tint: PT.amber,
                            badge: store.lowStock.isEmpty ? nil : "\(store.lowStock.count)") { InventoryShelfView() }
                HubLinkCard(title: "Farm Costs", subtitle: "Track spending",
                            icon: "dollarsign.circle.fill", tint: PT.success) { CostTrackerView() }
                HubLinkCard(title: "Farm Tasks", subtitle: "\(store.tasks.filter { !$0.isDone }.count) open",
                            icon: "list.bullet.rectangle", tint: PT.primary) { TaskBoardView() }
                HubLinkCard(title: "Reminders", subtitle: "\(store.reminders.filter { $0.isEnabled }.count) active",
                            icon: "bell.fill", tint: PT.clay) { ReminderQueueView() }
                HubLinkCard(title: "Notes", subtitle: "\(store.notes.count) cards",
                            icon: "note.text", tint: PT.info) { NotesBoardView() }
                HubLinkCard(title: "Photo Notes", subtitle: "\(store.photoNotes.count) photos",
                            icon: "photo.fill", tint: Color(hex: "8E6FB3")) { PhotoMarkupView() }
                HubLinkCard(title: "Farm Alerts", subtitle: "Risks & flags",
                            icon: "exclamationmark.triangle.fill", tint: PT.danger,
                            badge: store.liveRiskFlags().isEmpty ? nil : "\(store.liveRiskFlags().count)") { RiskFlagsView() }
            }

            SectionHeader(title: "Analytics & reports")
            HubGrid {
                HubLinkCard(title: "Weekly Trends", subtitle: "Care, cost & records",
                            icon: "chart.bar.fill", tint: PT.primary) { WeeklyAnalyticsView() }
                HubLinkCard(title: "Compare Groups", subtitle: "Load across groups",
                            icon: "chart.bar.xaxis", tint: PT.amber) { TrendCompareView() }
                HubLinkCard(title: "Farm Report", subtitle: "Build & export PDF",
                            icon: "doc.text.fill", tint: PT.clay) { ReportBuilderView() }
                HubLinkCard(title: "Preferences", subtitle: "Units, theme, notifications",
                            icon: "gearshape.fill", tint: PT.inkSoft) { SettingsView() }
            }
        }
    }
}

// MARK: - Screen 8: Inventory Shelf

struct InventoryShelfView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @State private var editor: EditorItem<InventoryItem>?
    @State private var onlyLow = false
    @State private var filter = "All"
    @State private var toast: String?
    @State private var deleteTarget: InventoryItem?

    private var items: [InventoryItem] {
        store.inventory.filter { (filter == "All" || $0.category == filter) && (!onlyLow || $0.isLow) }
    }

    var body: some View {
        ScreenScaffold(title: "Supplies") {
            DualActionBar(primaryTitle: "Add Item", primaryIcon: "plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: onlyLow ? "Show All" : "Low Stock",
                          secondaryIcon: "exclamationmark.triangle.fill",
                          secondaryAction: { withAnimation { onlyLow.toggle() } })

            SegChips(options: ["All"] + InventoryItem.categories, selection: $filter)

            if items.isEmpty {
                EmptyStateView(icon: "shippingbox.fill", title: onlyLow ? "No low items" : "No supplies",
                               message: onlyLow ? "Everything is above its minimum level." : "Track feed, litter, supplements, hardware and drinkers.",
                               actionTitle: onlyLow ? nil : "Add Item") { editor = .new() }
            } else {
                ForEach(items) { item in
                    RowCard {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill((item.isLow ? PT.danger : PT.primary).opacity(0.15)).frame(width: 42, height: 42)
                                Image(systemName: item.categoryIcon()).foregroundColor(item.isLow ? PT.danger : PT.primary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(PTFont.callout).foregroundColor(PT.ink)
                                Text("\(item.category) · min \(FarmStore.num(item.minLevel)) \(item.unit)")
                                    .font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(FarmStore.num(item.quantity)) \(item.unit)")
                                    .font(PTFont.headline).foregroundColor(item.isLow ? PT.danger : PT.ink)
                                if item.isLow { StatusChip(text: "Low", color: PT.danger, filled: true) }
                            }
                        }
                    }
                    .onTapGesture { editor = .edit(item) }
                    .contextMenu {
                        Button { editor = .edit(item) } label: { Label("Edit", systemImage: "pencil") }
                        Button { adjust(item, +1) } label: { Label("Add 1", systemImage: "plus") }
                        Button { adjust(item, -1) } label: { Label("Remove 1", systemImage: "minus") }
                        Button(role: .destructive) { deleteTarget = item } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(item: $editor) { target in AddInventorySheet(editing: target.value, toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { item in
            let count = store.relatedCountForInventoryItem(item.id)
            return Alert(
                title: Text("Delete \"\(item.name)\"?"),
                message: Text(count > 0
                    ? "\(count) feed log\(count == 1 ? "" : "s") reference this item. The link will be cleared."
                    : "This item has no related records."),
                primaryButton: .destructive(Text("Delete")) { store.deleteInventoryItem(item.id) },
                secondaryButton: .cancel()
            )
        }
        .toast($toast)
    }

    private func adjust(_ item: InventoryItem, _ delta: Double) {
        guard let i = store.inventory.firstIndex(where: { $0.id == item.id }) else { return }
        store.inventory[i].quantity = max(0, store.inventory[i].quantity + delta)
        store.inventory[i].updatedAt = Date(); store.saveAll()
    }
}

private struct AddInventorySheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: InventoryItem? = nil
    @Binding var toast: String?
    @State private var name = ""
    @State private var category = InventoryItem.categories[0]
    @State private var quantity = "10"
    @State private var unit = "kg"
    @State private var minLevel = "5"

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedUnit: String { unit.trimmingCharacters(in: .whitespaces) }
    private var quantityValue: Double? { Double(quantity.trimmingCharacters(in: .whitespaces)) }
    private var minLevelValue: Double? { Double(minLevel.trimmingCharacters(in: .whitespaces)) }
    private var quantityValid: Bool { (quantityValue ?? 0) > 0 }
    private var minLevelValid: Bool { if let m = minLevelValue { return m >= 0 } else { return false } }
    private var canSave: Bool { !trimmedName.isEmpty && !trimmedUnit.isEmpty && quantityValid && minLevelValid }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Item" : "Edit Item",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: canSave) {
            FormRow(label: "Name") { PTTextField(placeholder: "e.g. Layer Pellets", text: $name, icon: "tag.fill") }
            FormRow(label: "Category") { SegChips(options: InventoryItem.categories, selection: $category) }
            HStack(spacing: 12) {
                FormRow(label: "Quantity") { PTTextField(placeholder: "10", text: $quantity, keyboard: .decimalPad) }
                FormRow(label: "Unit") { PTTextField(placeholder: "kg", text: $unit) }
            }
            if !quantity.isEmpty && !quantityValid {
                fieldError("Quantity must be a number greater than 0.")
            }
            if unit.isEmpty {
                fieldError("Enter a unit (kg, bag, pcs…).")
            }
            FormRow(label: "Minimum level") { PTTextField(placeholder: "5", text: $minLevel, keyboard: .decimalPad, icon: "arrow.down.to.line") }
            if !minLevel.isEmpty && !minLevelValid {
                fieldError("Minimum level must be a number of 0 or more.")
            }
        }
        .onAppear {
            if let it = editing {
                name = it.name; category = it.category
                quantity = FarmStore.num(it.quantity); unit = it.unit; minLevel = FarmStore.num(it.minLevel)
            }
        }
    }
    private func fieldError(_ text: String) -> some View {
        Text(text).font(PTFont.caption).foregroundColor(PT.danger)
    }
    private func save() {
        guard let q = quantityValue, let m = minLevelValue else { return }
        if let it = editing, let i = store.inventory.firstIndex(where: { $0.id == it.id }) {
            store.inventory[i].name = trimmedName
            store.inventory[i].category = category
            store.inventory[i].quantity = q
            store.inventory[i].unit = trimmedUnit
            store.inventory[i].minLevel = m
            store.inventory[i].updatedAt = Date()
            toast = "Item updated"
        } else {
            store.inventory.append(InventoryItem(name: trimmedName, category: category,
                                                 quantity: q, unit: trimmedUnit, minLevel: m))
            toast = "Item added"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 9: Cost Tracker

struct CostTrackerView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @State private var editor: EditorItem<Cost>?
    @State private var showMonth = false
    @State private var deleteTarget: Cost?
    @State private var toast: String?

    var body: some View {
        ScreenScaffold(title: "Farm Costs") {
            DualActionBar(primaryTitle: "Add Cost", primaryIcon: "plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: "View Month", secondaryIcon: "calendar",
                          secondaryAction: { withAnimation { showMonth.toggle() } })

            PTCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This month").font(PTFont.subhead).foregroundColor(PT.inkSoft)
                    Text(prefs.money(store.monthCost)).font(PTFont.largeTitle).foregroundColor(PT.ink)
                    Text("\(store.costs.count) entries total").font(PTFont.caption).foregroundColor(PT.inkFaint)
                }
            }

            if showMonth, !store.costsByCategory().isEmpty {
                PTCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("By category").font(PTFont.headline).foregroundColor(PT.ink)
                        DonutChartView(segments: store.costsByCategory().enumerated().map { (i, c) in
                            (c.category, c.total, catColor(i))
                        })
                    }
                }
            }

            PTCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weekly spend").font(PTFont.headline).foregroundColor(PT.ink)
                    BarChartView(values: store.costsByWeek().map { ($0.label, $0.total) }, tint: PT.success,
                                 unitPrefix: prefs.currency)
                }
            }

            SectionHeader(title: "Recent costs")
            if store.costs.isEmpty {
                EmptyStateView(icon: "dollarsign.circle.fill", title: "No costs",
                               message: "Add costs by category to see weekly and per-group spending.",
                               actionTitle: "Add Cost") { editor = .new() }
            } else {
                ForEach(store.costs.sorted { $0.date > $1.date }) { c in
                    RowCard {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(PT.success.opacity(0.15)).frame(width: 38, height: 38)
                                Image(systemName: "tag.fill").foregroundColor(PT.success).font(.system(size: 14))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.category).font(PTFont.callout).foregroundColor(PT.ink)
                                Text("\(FarmStore.dateShort(c.date))\(c.groupID != nil ? " · \(store.groupName(c.groupID))" : "")\(c.note.isEmpty ? "" : " · \(c.note)")")
                                    .font(PTFont.caption).foregroundColor(PT.inkSoft).lineLimit(1)
                            }
                            Spacer()
                            Text(prefs.money(c.amount)).font(PTFont.headline).foregroundColor(PT.ink)
                        }
                    }
                    .onTapGesture { editor = .edit(c) }
                    .contextMenu {
                        Button { editor = .edit(c) } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { deleteTarget = c } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(item: $editor) { target in AddCostSheet(editing: target.value, toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { c in
            Alert(title: Text("Delete this cost?"),
                  message: Text("\(c.category) · \(prefs.money(c.amount))"),
                  primaryButton: .destructive(Text("Delete")) {
                      store.costs.removeAll { $0.id == c.id }; store.saveAll()
                  },
                  secondaryButton: .cancel())
        }
        .toast($toast)
    }

    private func catColor(_ i: Int) -> Color {
        [PT.primary, PT.amber, PT.clay, PT.info, PT.neutral][i % 5]
    }
}

private struct AddCostSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: Cost? = nil
    @Binding var toast: String?
    @State private var category = Cost.categories[0]
    @State private var amount = ""
    @State private var date = Date()
    @State private var groupID: UUID?
    @State private var note = ""

    private var amountValue: Double? { Double(amount.trimmingCharacters(in: .whitespaces)) }
    private var amountValid: Bool { (amountValue ?? 0) > 0 }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Cost" : "Edit Cost",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: amountValid) {
            FormRow(label: "Category") { SegChips(options: Cost.categories, selection: $category) }
            FormRow(label: "Amount") { PTTextField(placeholder: "0", text: $amount, keyboard: .decimalPad, icon: "dollarsign.circle") }
            if !amount.isEmpty && !amountValid {
                Text("Amount must be a number greater than 0.")
                    .font(PTFont.caption).foregroundColor(PT.danger)
            }
            FormRow(label: "Date") { DatePicker("", selection: $date, displayedComponents: .date).labelsHidden() }
            FormRow(label: "Group (optional)") { GroupPicker(selection: $groupID, allowNone: true) }
            FormRow(label: "Note") { PTTextField(placeholder: "Optional", text: $note, icon: "text.alignleft") }
        }
        .onAppear {
            if let c = editing {
                category = c.category; amount = FarmStore.num(c.amount)
                date = c.date; groupID = c.groupID; note = c.note
            }
        }
    }
    private func save() {
        guard let a = amountValue else { return }
        if let c = editing, let i = store.costs.firstIndex(where: { $0.id == c.id }) {
            store.costs[i].category = category
            store.costs[i].amount = a
            store.costs[i].date = date
            store.costs[i].groupID = groupID
            store.costs[i].note = note
            toast = "Cost updated"
        } else {
            store.costs.insert(Cost(category: category, amount: a, date: date, groupID: groupID, note: note), at: 0)
            toast = "Cost added"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 10: Task Board

struct TaskBoardView: View {
    @EnvironmentObject var store: FarmStore
    @State private var editor: EditorItem<FarmTask>?
    @State private var deleteTarget: FarmTask?
    @State private var toast: String?

    var body: some View {
        ScreenScaffold(title: "Farm Tasks") {
            DualActionBar(primaryTitle: "New Task", primaryIcon: "plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: "Set Priority", secondaryIcon: "arrow.up.arrow.down.circle.fill",
                          secondaryAction: bumpFirst)

            if store.tasks.isEmpty {
                EmptyStateView(icon: "list.bullet.rectangle", title: "No tasks",
                               message: "Add repair, purchase, cleaning or control tasks with priorities and zones.",
                               actionTitle: "New Task") { editor = .new() }
            } else {
                ForEach(Severity.allCases.reversed()) { sev in
                    let group = store.tasks.filter { $0.priority == sev }
                    if !group.isEmpty {
                        HStack(spacing: 8) {
                            Circle().fill(sev.color).frame(width: 10, height: 10)
                            Text("\(sev.title) priority").font(PTFont.title2).foregroundColor(PT.ink)
                            Spacer()
                            Text("\(group.filter { !$0.isDone }.count) open").font(PTFont.caption).foregroundColor(PT.inkFaint)
                        }
                        ForEach(group) { task in taskRow(task) }
                    }
                }
            }
        }
        .sheet(item: $editor) { target in AddTaskSheet(editing: target.value, toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { task in
            Alert(title: Text("Delete \"\(task.title)\"?"),
                  message: Text("Priority \(task.priority.title)"),
                  primaryButton: .destructive(Text("Delete")) {
                      store.tasks.removeAll { $0.id == task.id }; store.saveAll()
                  },
                  secondaryButton: .cancel())
        }
        .toast($toast)
    }

    private func taskRow(_ task: FarmTask) -> some View {
        RowCard {
            HStack(spacing: 12) {
                Button { toggle(task) } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22)).foregroundColor(task.isDone ? PT.success : PT.inkFaint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).font(PTFont.callout).foregroundColor(PT.ink).strikethrough(task.isDone)
                    HStack(spacing: 6) {
                        if let z = task.zoneID { Text(store.zoneName(z)).font(PTFont.caption).foregroundColor(PT.inkSoft) }
                        if let d = task.dueDate {
                            Text("· \(FarmStore.dateShort(d))").font(PTFont.caption)
                                .foregroundColor(task.isOverdue ? PT.danger : PT.inkSoft)
                        }
                    }
                }
                Spacer()
                Button { cyclePriority(task) } label: {
                    StatusChip(text: task.priority.title, color: task.priority.color, filled: true)
                }
            }
        }
        .contextMenu {
            Button { editor = .edit(task) } label: { Label("Edit", systemImage: "pencil") }
            Button { cyclePriority(task) } label: { Label("Change priority", systemImage: "arrow.up.arrow.down") }
            Button(role: .destructive) { deleteTarget = task } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func toggle(_ task: FarmTask) {
        if let i = store.tasks.firstIndex(where: { $0.id == task.id }) { store.tasks[i].isDone.toggle(); store.saveAll() }
    }
    private func cyclePriority(_ task: FarmTask) {
        guard let i = store.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let order: [Severity] = [.low, .medium, .high]
        let next = order[(order.firstIndex(of: store.tasks[i].priority)! + 1) % 3]
        store.tasks[i].priority = next; store.saveAll()
    }
    private func bumpFirst() {
        if let i = store.tasks.firstIndex(where: { !$0.isDone && $0.priority != .high }) {
            store.tasks[i].priority = .high; store.saveAll()
            toast = "Raised: \(store.tasks[i].title)"
        } else { toast = "No task to raise" }
    }
}

private struct AddTaskSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: FarmTask? = nil
    @Binding var toast: String?
    @State private var title = ""
    @State private var priority: Severity = .medium
    @State private var hasDue = true
    @State private var due = Date()
    @State private var zoneID: UUID?

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        SheetScaffold(title: editing == nil ? "New Task" : "Edit Task",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: !trimmedTitle.isEmpty) {
            FormRow(label: "Title") { PTTextField(placeholder: "e.g. Repair run fence", text: $title, icon: "list.bullet.rectangle") }
            FormRow(label: "Priority") {
                HStack(spacing: 8) {
                    ForEach(Severity.allCases) { s in
                        Button { priority = s } label: { Text(s.title) }
                            .buttonStyle(ChipButtonStyle(isSelected: priority == s))
                    }
                }
            }
            Toggle("Has due date", isOn: $hasDue).toggleStyle(PTToggleStyle())
            if hasDue {
                FormRow(label: "Due date") { DatePicker("", selection: $due, displayedComponents: .date).labelsHidden() }
            }
            FormRow(label: "Zone (optional)") { ZonePicker(selection: $zoneID, allowNone: true) }
        }
        .onAppear {
            if let t = editing {
                title = t.title; priority = t.priority; zoneID = t.zoneID
                if let d = t.dueDate { hasDue = true; due = d } else { hasDue = false }
            }
        }
    }
    private func save() {
        if let t = editing, let i = store.tasks.firstIndex(where: { $0.id == t.id }) {
            store.tasks[i].title = trimmedTitle
            store.tasks[i].priority = priority
            store.tasks[i].dueDate = hasDue ? due : nil
            store.tasks[i].zoneID = zoneID
            toast = "Task updated"
        } else {
            store.tasks.append(FarmTask(title: trimmedTitle, priority: priority, dueDate: hasDue ? due : nil, zoneID: zoneID))
            toast = "Task added"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 11: Reminder Queue

struct ReminderQueueView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @State private var editor: EditorItem<Reminder>?
    @State private var deleteTarget: Reminder?
    @State private var toast: String?

    var body: some View {
        ScreenScaffold(title: "Local Reminders") {
            DualActionBar(primaryTitle: "Add Reminder", primaryIcon: "plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: "Snooze", secondaryIcon: "zzz",
                          secondaryAction: snoozeNext)

            if !prefs.notificationsEnabled {
                PTCard {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash.fill").foregroundColor(PT.warning)
                        Text("Notifications are off in Settings. Reminders won't fire until enabled.")
                            .font(PTFont.caption).foregroundColor(PT.inkSoft)
                    }
                }
            }

            if store.reminders.isEmpty {
                EmptyStateView(icon: "bell.fill", title: "No reminders",
                               message: "Add local morning, evening, transport or cleaning reminders. No account needed.",
                               actionTitle: "Add Reminder") { editor = .new() }
            } else {
                ForEach(store.reminders.sorted { $0.time < $1.time }) { r in
                    RowCard {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill((r.isEnabled ? PT.primary : PT.inkFaint).opacity(0.15)).frame(width: 42, height: 42)
                                Image(systemName: r.icon()).foregroundColor(r.isEnabled ? PT.primary : PT.inkFaint)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title).font(PTFont.callout).foregroundColor(PT.ink)
                                Text("\(r.kind) · \(timeString(r.time))").font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { r.isEnabled },
                                set: { newVal in setEnabled(r, newVal) }
                            )).labelsHidden()
                        }
                    }
                    .contextMenu {
                        Button { editor = .edit(r) } label: { Label("Edit", systemImage: "pencil") }
                        Button { NotificationManager.shared.snooze(r, minutes: 15); toast = "Snoozed 15 min" } label: { Label("Snooze 15m", systemImage: "zzz") }
                        Button(role: .destructive) { deleteTarget = r } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(item: $editor) { target in AddReminderSheet(editing: target.value, toast: $toast).environmentObject(store).environmentObject(prefs) }
        .alert(item: $deleteTarget) { r in
            Alert(title: Text("Delete \"\(r.title)\"?"),
                  message: Text("\(r.kind) · \(timeString(r.time))"),
                  primaryButton: .destructive(Text("Delete")) {
                      NotificationManager.shared.cancel(r)
                      store.reminders.removeAll { $0.id == r.id }; store.saveAll()
                  },
                  secondaryButton: .cancel())
        }
        .toast($toast)
    }

    private func setEnabled(_ r: Reminder, _ on: Bool) {
        guard let i = store.reminders.firstIndex(where: { $0.id == r.id }) else { return }
        store.reminders[i].isEnabled = on; store.saveAll()
        if on && prefs.notificationsEnabled {
            NotificationManager.shared.requestAuthorization { _ in
                NotificationManager.shared.schedule(store.reminders[i])
            }
            toast = "Reminder scheduled"
        } else {
            NotificationManager.shared.cancel(r)
            toast = "Reminder off"
        }
    }
    private func snoozeNext() {
        guard let r = store.reminders.filter({ $0.isEnabled }).sorted(by: { $0.time < $1.time }).first else {
            toast = "No active reminder"; return
        }
        NotificationManager.shared.snooze(r, minutes: 15)
        toast = "Snoozed '\(r.title)' 15 min"
    }
}

private struct AddReminderSheet: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @Environment(\.presentationMode) var presentation
    var editing: Reminder? = nil
    @Binding var toast: String?
    @State private var title = ""
    @State private var kind = Reminder.kinds[0]
    @State private var time = Date()

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Reminder" : "Edit Reminder",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: !trimmedTitle.isEmpty) {
            FormRow(label: "Title") { PTTextField(placeholder: "e.g. Morning feed", text: $title, icon: "bell.fill") }
            FormRow(label: "Kind") { SegChips(options: Reminder.kinds, selection: $kind) }
            FormRow(label: "Time") { DatePicker("", selection: $time, displayedComponents: .hourAndMinute).labelsHidden() }
        }
        .onAppear {
            if let r = editing { title = r.title; kind = r.kind; time = r.time }
        }
    }
    private func save() {
        if let r = editing, let i = store.reminders.firstIndex(where: { $0.id == r.id }) {
            // Cancel the old schedule, then apply edits and reschedule if still enabled.
            NotificationManager.shared.cancel(r)
            store.reminders[i].title = trimmedTitle
            store.reminders[i].kind = kind
            store.reminders[i].time = time
            store.saveAll()
            if prefs.notificationsEnabled && store.reminders[i].isEnabled {
                let updated = store.reminders[i]
                NotificationManager.shared.requestAuthorization { _ in NotificationManager.shared.schedule(updated) }
            }
            toast = "Reminder updated"
        } else {
            let r = Reminder(title: trimmedTitle, time: time, kind: kind)
            store.reminders.append(r); store.saveAll()
            if prefs.notificationsEnabled {
                NotificationManager.shared.requestAuthorization { _ in NotificationManager.shared.schedule(r) }
            }
            toast = "Reminder added"
        }
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 12: Notes Board

struct NotesBoardView: View {
    @EnvironmentObject var store: FarmStore
    @State private var editor: EditorItem<FarmNote>?
    @State private var tagFilter = "All"
    @State private var onlyLinked = false
    @State private var deleteTarget: FarmNote?
    @State private var toast: String?

    private var notes: [FarmNote] {
        store.notes
            .filter { tagFilter == "All" || $0.tag == tagFilter }
            .filter { !onlyLinked || $0.zoneID != nil || $0.groupID != nil }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScreenScaffold(title: "Structured Notes") {
            DualActionBar(primaryTitle: "Add Note", primaryIcon: "plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: onlyLinked ? "Show All" : "Linked Only", secondaryIcon: "link",
                          secondaryAction: { withAnimation { onlyLinked.toggle() } })

            SegChips(options: ["All"] + FarmNote.tags, selection: $tagFilter)

            if notes.isEmpty {
                EmptyStateView(icon: "note.text", title: "No notes",
                               message: "Notes are cards with a zone, group, tag and date — easy to find later.",
                               actionTitle: "Add Note") { editor = .new() }
            } else {
                ForEach(notes) { n in noteCard(n) }
            }
        }
        .sheet(item: $editor) { target in AddNoteSheet(editing: target.value, toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { n in
            Alert(title: Text("Delete \"\(n.title)\"?"),
                  message: Text(n.tag),
                  primaryButton: .destructive(Text("Delete")) {
                      store.notes.removeAll { $0.id == n.id }; store.saveAll()
                  },
                  secondaryButton: .cancel())
        }
        .toast($toast)
    }

    private func noteCard(_ n: FarmNote) -> some View {
        RowCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(n.title).font(PTFont.headline).foregroundColor(PT.ink)
                    Spacer()
                    StatusChip(text: n.tag, color: PT.info)
                }
                if !n.body.isEmpty {
                    Text(n.body).font(PTFont.subhead).foregroundColor(PT.inkSoft)
                }
                HStack(spacing: 8) {
                    if n.zoneID != nil {
                        Label(store.zoneName(n.zoneID), systemImage: "map")
                            .font(PTFont.caption).foregroundColor(PT.primary)
                    }
                    if n.groupID != nil {
                        HStack(spacing: 3) {
                            IconGlyph(name: "chicken", size: 11, color: PT.clay)
                            Text(store.groupName(n.groupID)).font(PTFont.caption)
                        }
                        .foregroundColor(PT.clay)
                    }
                    Spacer()
                    Text(FarmStore.dateShort(n.date)).font(PTFont.caption).foregroundColor(PT.inkFaint)
                }
            }
        }
        .onTapGesture { editor = .edit(n) }
        .contextMenu {
            Button { editor = .edit(n) } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { deleteTarget = n } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

private struct AddNoteSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: FarmNote? = nil
    @Binding var toast: String?
    @State private var title = ""
    @State private var body_ = ""
    @State private var tag = FarmNote.tags[0]
    @State private var zoneID: UUID?
    @State private var groupID: UUID?

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Note" : "Edit Note",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: !trimmedTitle.isEmpty) {
            FormRow(label: "Title") { PTTextField(placeholder: "Note title", text: $title, icon: "tag.fill") }
            FormRow(label: "Body") { PTTextField(placeholder: "Details", text: $body_, icon: "text.alignleft") }
            FormRow(label: "Tag") { SegChips(options: FarmNote.tags, selection: $tag) }
            FormRow(label: "Link to zone") { ZonePicker(selection: $zoneID, allowNone: true) }
            FormRow(label: "Link to group") { GroupPicker(selection: $groupID, allowNone: true) }
        }
        .onAppear {
            if let n = editing {
                title = n.title; body_ = n.body; tag = n.tag; zoneID = n.zoneID; groupID = n.groupID
            }
        }
    }
    private func save() {
        if let n = editing, let i = store.notes.firstIndex(where: { $0.id == n.id }) {
            store.notes[i].title = trimmedTitle
            store.notes[i].body = body_
            store.notes[i].tag = tag
            store.notes[i].zoneID = zoneID
            store.notes[i].groupID = groupID
            toast = "Note updated"
        } else {
            store.notes.insert(FarmNote(title: trimmedTitle, body: body_, zoneID: zoneID, groupID: groupID, tag: tag), at: 0)
            toast = "Note added"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 13: Photo Markup

struct PhotoMarkupView: View {
    @EnvironmentObject var store: FarmStore
    @State private var showPicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var editing: PhotoNote?
    @State private var showSourceDialog = false
    @State private var deleteTarget: PhotoNote?
    @State private var toast: String?

    var body: some View {
        ScreenScaffold(title: "Photo Notes") {
            DualActionBar(primaryTitle: "Attach Photo", primaryIcon: "photo.on.rectangle.angled",
                          primaryAction: { showSourceDialog = true },
                          secondaryTitle: "Mark Area", secondaryIcon: "scope",
                          secondaryAction: { editing = store.photoNotes.first; if editing == nil { toast = "Attach a photo first" } })

            if store.photoNotes.isEmpty {
                EmptyStateView(icon: "photo.fill", title: "No photos",
                               message: "Attach a coop or yard photo and mark a problem spot tied to a note.",
                               actionTitle: "Attach Photo") { showSourceDialog = true }
            } else {
                ForEach(store.photoNotes) { note in
                    Button { editing = note } label: { photoCard(note) }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button { editing = note } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) { deleteTarget = note } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
        }
        .sheet(isPresented: $showSourceDialog) {
            PhotoSourceSheet(onChosen: { source in
                showSourceDialog = false
                pickerSource = source
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showPicker = true }
            }, onCancel: { showSourceDialog = false })
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(sourceType: pickerSource) { img in
                let data = img.jpegData(compressionQuality: 0.6)
                let note = PhotoNote(imageData: data, caption: "", markerX: 0.5, markerY: 0.5, hasMarker: false)
                store.photoNotes.insert(note, at: 0); store.saveAll()
                editing = note
                toast = "Photo attached"
            }
        }
        .sheet(item: $editing) { note in PhotoMarkEditor(note: note, toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { note in
            Alert(title: Text("Delete this photo?"),
                  message: Text(note.caption.isEmpty ? "This photo note will be removed." : note.caption),
                  primaryButton: .destructive(Text("Delete")) {
                      store.photoNotes.removeAll { $0.id == note.id }; store.saveAll()
                  },
                  secondaryButton: .cancel())
        }
        .toast($toast)
    }

    private func photoCard(_ note: PhotoNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if let data = note.imageData, let ui = UIImage(data: data) {
                    GeometryReader { geo in
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: geo.size.width, height: 180).clipped()
                        if note.hasMarker {
                            markerView
                                .position(x: geo.size.width * CGFloat(note.markerX), y: 180 * CGFloat(note.markerY))
                        }
                    }
                    .frame(height: 180)
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(PT.subtle).frame(height: 180)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !note.caption.isEmpty {
                Text(note.caption).font(PTFont.subhead).foregroundColor(PT.ink)
            }
            Text(FarmStore.dateShort(note.date)).font(PTFont.caption).foregroundColor(PT.inkFaint)
        }
        .padding(10)
        .background(PT.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PT.stroke, lineWidth: 1))
    }

    private var markerView: some View {
        ZStack {
            Circle().stroke(PT.danger, lineWidth: 3).frame(width: 30, height: 30)
            Circle().fill(PT.danger).frame(width: 8, height: 8)
        }
    }
}

private struct PhotoMarkEditor: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    let note: PhotoNote
    @Binding var toast: String?
    @State private var marker: CGPoint = .zero
    @State private var hasMarker = false
    @State private var caption = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Tap the photo to mark a problem area")
                        .font(PTFont.caption).foregroundColor(PT.inkSoft)
                    if let data = note.imageData, let ui = UIImage(data: data) {
                        GeometryReader { geo in
                            ZStack(alignment: .topLeading) {
                                Image(uiImage: ui).resizable().scaledToFit()
                                    .frame(width: geo.size.width)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                if hasMarker {
                                    ZStack {
                                        Circle().stroke(PT.danger, lineWidth: 4).frame(width: 38, height: 38)
                                        Circle().fill(PT.danger).frame(width: 10, height: 10)
                                    }
                                    .position(marker)
                                }
                            }
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                                marker = v.location; hasMarker = true
                                // store relative
                                relX = Double(v.location.x / geo.size.width)
                                relY = Double(v.location.y / imgHeight(ui, width: geo.size.width))
                            })
                        }
                        .frame(height: imgHeight(ui, width: UIScreen.main.bounds.width - 36))
                    }
                    FormRow(label: "Caption") { PTTextField(placeholder: "Describe the issue", text: $caption, icon: "text.alignleft") }
                    Button(action: save) { Label("Save markup", systemImage: "checkmark.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(18)
            }
            .ptScreenBackground()
            .navigationBarTitle("Mark Area", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentation.wrappedValue.dismiss() })
            .onAppear {
                caption = note.caption
                hasMarker = note.hasMarker
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @State private var relX: Double = 0.5
    @State private var relY: Double = 0.5

    private func imgHeight(_ img: UIImage, width: CGFloat) -> CGFloat {
        guard img.size.width > 0 else { return 220 }
        return width * img.size.height / img.size.width
    }
    private func save() {
        guard let i = store.photoNotes.firstIndex(where: { $0.id == note.id }) else { return }
        store.photoNotes[i].caption = caption
        store.photoNotes[i].hasMarker = hasMarker
        store.photoNotes[i].markerX = relX
        store.photoNotes[i].markerY = relY
        store.saveAll()
        toast = "Markup saved"
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 14: Risk Flags

struct RiskFlagsView: View {
    @EnvironmentObject var store: FarmStore
    @State private var filter = "All"
    @State private var toast: String?

    private var flags: [RiskFlag] {
        let all = store.liveRiskFlags()
        return filter == "All" ? all : all.filter { $0.severity.title == filter }
    }

    var body: some View {
        ScreenScaffold(title: "Farm Alerts") {
            DualActionBar(primaryTitle: "Review Flags", primaryIcon: "list.bullet.rectangle",
                          primaryAction: { filter = "All" },
                          secondaryTitle: "Resolve", secondaryIcon: "checkmark.seal.fill",
                          secondaryAction: resolveManual)

            HStack(spacing: 10) {
                summaryPill("High", store.liveRiskFlags().filter { $0.severity == .high }.count, PT.danger)
                summaryPill("Medium", store.liveRiskFlags().filter { $0.severity == .medium }.count, PT.warning)
                summaryPill("Low", store.liveRiskFlags().filter { $0.severity == .low }.count, PT.info)
            }

            SegChips(options: ["All", "High", "Medium", "Low"], selection: $filter)

            if flags.isEmpty {
                EmptyStateView(icon: "checkmark.shield.fill", title: "All clear",
                               message: "No active alerts. New risks appear from overdue tasks, low stock, overload and flags.")
            } else {
                ForEach(flags) { flag in
                    RowCard {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(flag.severity.color.opacity(0.15)).frame(width: 40, height: 40)
                                Image(systemName: sourceIcon(flag.source)).foregroundColor(flag.severity.color)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(flag.title).font(PTFont.callout).foregroundColor(PT.ink)
                                Text(flag.detail).font(PTFont.caption).foregroundColor(PT.inkSoft).lineLimit(2)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                StatusChip(text: flag.severity.title, color: flag.severity.color)
                                if flag.source == "Manual" {
                                    Button { resolve(flag) } label: {
                                        Text("Resolve").font(PTFont.caption).foregroundColor(PT.success)
                                    }
                                } else {
                                    Text(flag.source).font(.system(size: 9, design: .rounded)).foregroundColor(PT.inkFaint)
                                }
                            }
                        }
                    }
                }
            }
        }
        .toast($toast)
    }

    private func summaryPill(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)").font(PTFont.title).foregroundColor(color)
            Text(label).font(PTFont.caption).foregroundColor(PT.inkSoft)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(color.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    private func sourceIcon(_ source: String) -> String {
        switch source {
        case "Overdue": return "clock.fill"
        case "Low stock": return "shippingbox.fill"
        case "Overload": return "exclamationmark.triangle.fill"
        case "Observation": return "eye.fill"
        default: return "flag.fill"
        }
    }
    private func resolve(_ flag: RiskFlag) {
        if let i = store.riskFlags.firstIndex(where: { $0.id == flag.id }) {
            store.riskFlags[i].isResolved = true; store.saveAll(); toast = "Resolved"
        }
    }
    private func resolveManual() {
        let manual = store.riskFlags.filter { !$0.isResolved }
        guard let first = manual.first else { toast = "No manual flags to resolve"; return }
        resolve(first)
    }
}

// MARK: - Photo source picker (iPad-safe replacement for ActionSheet)

private struct PhotoSourceSheet: View {
    let onChosen: (UIImagePickerController.SourceType) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Attach a photo").font(PTFont.headline).foregroundColor(PT.ink).padding(.top, 20)
                Button {
                    onChosen(.photoLibrary)
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        onChosen(.camera)
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
            .ptScreenBackground()
            .navigationBarTitle("Choose Source", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel", action: onCancel).foregroundColor(PT.inkSoft))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Time helper

func timeString(_ date: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
}
