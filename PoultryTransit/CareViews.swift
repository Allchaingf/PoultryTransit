//
//  CareViews.swift
//  PoultryTransit
//
//  Care Logs section: hub + Feed Planner (2), Water Log (3),
//  Health Observation (4), Cleaning Schedule (5), Daily Care Checklist (23),
//  Daily Review (15) and Quick Add (19). Every action mutates the store.
//

import SwiftUI

// MARK: - Hub

struct CareHubView: View {
    @EnvironmentObject var store: FarmStore

    var body: some View {
        ScreenScaffold(title: "Care Logs",
                       subtitle: "Daily feeding, water, health and cleaning — kept in one journal.") {
            HubGrid {
                HubLinkCard(title: "Feed Planner", subtitle: "Portions & purchase forecast",
                            icon: "leaf.fill", tint: PT.amber) { FeedPlannerView() }
                HubLinkCard(title: "Water & Heat", subtitle: "Water, temp & ventilation",
                            icon: "drop.fill", tint: PT.info) { WaterLogView() }
                HubLinkCard(title: "Observation", subtitle: "Activity, appetite, flags",
                            icon: "eye.fill", tint: Color(hex: "8E6FB3"),
                            badge: store.flaggedObservations.isEmpty ? nil : "\(store.flaggedObservations.count)") { HealthObservationView() }
                HubLinkCard(title: "Clean Plan", subtitle: "Litter & sanitation cycles",
                            icon: "sparkles", tint: PT.primary,
                            badge: store.overdueCleaning.isEmpty ? nil : "\(store.overdueCleaning.count)") { CleaningScheduleView() }
                HubLinkCard(title: "Daily Checklist", subtitle: "Morning / evening checks",
                            icon: "list.bullet.rectangle", tint: PT.success) { DailyChecklistView() }
                HubLinkCard(title: "End of Day", subtitle: "Review & close the day",
                            icon: "moon.stars.fill", tint: PT.clay) { DailyReviewView() }
            }
            NavigationLink(destination: QuickAddView()) {
                Label("Quick add an entry", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
}

// MARK: - Screen 2: Feed Planner

struct FeedPlannerView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @State private var editor: EditorItem<FeedPortion>?
    @State private var showStock = false
    @State private var deleteTarget: FeedPortion?
    @State private var toast: String?

    private var feedItems: [InventoryItem] { store.inventory.filter { $0.category == "Feed" } }

    var body: some View {
        ScreenScaffold(title: "Feed Portions") {
            DualActionBar(primaryTitle: "Add Portion", primaryIcon: "plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: "Update Stock", secondaryIcon: "tray.and.arrow.down.fill",
                          secondaryAction: { showStock = true })

            // Forecast
            if !feedItems.isEmpty {
                PTCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Purchase forecast").font(PTFont.headline).foregroundColor(PT.ink)
                        ForEach(feedItems) { item in
                            let daily = dailyConsumption(for: item)
                            let days = daily > 0 ? item.quantity / daily : Double.infinity
                            HStack {
                                Image(systemName: "leaf.fill").foregroundColor(PT.amber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(PTFont.callout).foregroundColor(PT.ink)
                                    Text(daily > 0 ? "\(prefs.weight(daily))/day" : "no active portions")
                                        .font(PTFont.caption).foregroundColor(PT.inkSoft)
                                }
                                Spacer()
                                if daily > 0 {
                                    StatusChip(text: days.isFinite ? "~\(Int(days)) days" : "—",
                                               color: days < 5 ? PT.danger : (days < 12 ? PT.warning : PT.success))
                                }
                            }
                        }
                    }
                }
            }

            SectionHeader(title: "Portions", subtitle: "\(store.feedPortions.count) saved")
            if store.feedPortions.isEmpty {
                EmptyStateView(icon: "leaf.fill", title: "No portions yet",
                               message: "Add a feeding portion to plan daily feed and forecast purchasing.",
                               actionTitle: "Add Portion") { editor = .new() }
            } else {
                ForEach(store.feedPortions) { p in
                    RowCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.groupName(p.groupID)).font(PTFont.callout).foregroundColor(PT.ink)
                                Text("\(FarmStore.num(p.gramsPerBird)) g/bird × \(p.feedsPerDay)/day")
                                    .font(PTFont.caption).foregroundColor(PT.inkSoft)
                                if let item = store.inventory.first(where: { $0.id == p.feedItemID }) {
                                    Text("from \(item.name)").font(PTFont.caption).foregroundColor(PT.inkFaint)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(prefs.weight(dailyKg(p))).font(PTFont.headline).foregroundColor(PT.amber)
                                Text("per day").font(.system(size: 9, design: .rounded)).foregroundColor(PT.inkFaint)
                            }
                        }
                    }
                    .onTapGesture { editor = .edit(p) }
                    .contextMenu {
                        Button { editor = .edit(p) } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { deleteTarget = p } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(item: $editor) { target in AddPortionSheet(editing: target.value, toast: $toast).environmentObject(store) }
        .sheet(isPresented: $showStock) { UpdateStockSheet(toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { p in
            Alert(title: Text("Delete this portion?"),
                  message: Text("\(store.groupName(p.groupID)) · \(FarmStore.num(p.gramsPerBird)) g/bird"),
                  primaryButton: .destructive(Text("Delete")) {
                      store.feedPortions.removeAll { $0.id == p.id }; store.saveAll()
                  },
                  secondaryButton: .cancel())
        }
        .toast($toast)
    }

    private func dailyKg(_ p: FeedPortion) -> Double {
        let count = Double(store.group(p.groupID)?.count ?? 0)
        return p.gramsPerBird * Double(p.feedsPerDay) * count / 1000.0
    }
    private func dailyConsumption(for item: InventoryItem) -> Double {
        store.feedPortions.filter { $0.feedItemID == item.id }.reduce(0) { $0 + dailyKg($1) }
    }
}

private struct AddPortionSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: FeedPortion? = nil
    @Binding var toast: String?

    @State private var groupID: UUID?
    @State private var feedItemID: UUID?
    @State private var grams = "120"
    @State private var feedsPerDay = 2

    private var gramsValue: Double? { Double(grams.trimmingCharacters(in: .whitespaces)) }
    private var gramsValid: Bool { (gramsValue ?? 0) > 0 }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Portion" : "Edit Portion",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: groupID != nil && gramsValid) {
            FormRow(label: "Group") {
                GroupPicker(selection: $groupID)
            }
            FormRow(label: "Grams per bird") {
                PTTextField(placeholder: "120", text: $grams, keyboard: .numberPad, icon: "scalemass")
            }
            if !grams.isEmpty && !gramsValid {
                Text("Grams per bird must be a number greater than 0.")
                    .font(PTFont.caption).foregroundColor(PT.danger)
            }
            StepperField(label: "Feeds per day", value: $feedsPerDay, range: 1...6)
            FormRow(label: editing == nil ? "Feed item (stock to reduce)" : "Feed item") {
                FeedItemPicker(selection: $feedItemID)
            }
        }
        .onAppear {
            if let p = editing {
                groupID = p.groupID; feedItemID = p.feedItemID
                grams = FarmStore.num(p.gramsPerBird); feedsPerDay = p.feedsPerDay
            } else {
                groupID = store.groups.first?.id
                feedItemID = store.inventory.first(where: { $0.category == "Feed" })?.id
            }
        }
    }

    private func save() {
        guard let g = gramsValue else { return }
        if let p = editing, let i = store.feedPortions.firstIndex(where: { $0.id == p.id }) {
            store.feedPortions[i].groupID = groupID
            store.feedPortions[i].gramsPerBird = g
            store.feedPortions[i].feedsPerDay = feedsPerDay
            store.feedPortions[i].feedItemID = feedItemID
            store.saveAll()
            toast = "Portion updated"
        } else {
            let portion = FeedPortion(groupID: groupID, gramsPerBird: g, feedsPerDay: feedsPerDay, feedItemID: feedItemID)
            store.feedPortions.insert(portion, at: 0)
            // reduce stock by one day's consumption (only when creating a new portion)
            if let idx = store.inventory.firstIndex(where: { $0.id == feedItemID }) {
                let count = Double(store.group(groupID)?.count ?? 0)
                let dailyKg = g * Double(feedsPerDay) * count / 1000.0
                store.inventory[idx].quantity = max(0, store.inventory[idx].quantity - dailyKg)
                store.inventory[idx].updatedAt = Date()
            }
            store.saveAll()
            toast = "Portion saved · stock updated"
        }
        presentation.wrappedValue.dismiss()
    }
}

private struct UpdateStockSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    @Binding var toast: String?
    @State private var itemID: UUID?
    @State private var amount = "10"

    var body: some View {
        SheetScaffold(title: "Update Stock", onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: itemID != nil && (Double(amount) ?? 0) > 0) {
            FormRow(label: "Feed item") { FeedItemPicker(selection: $itemID) }
            FormRow(label: "Add quantity") {
                PTTextField(placeholder: "10", text: $amount, keyboard: .decimalPad, icon: "plus")
            }
        }
        .onAppear { itemID = store.inventory.first(where: { $0.category == "Feed" })?.id }
    }
    private func save() {
        if let idx = store.inventory.firstIndex(where: { $0.id == itemID }) {
            store.inventory[idx].quantity += Double(amount) ?? 0
            store.inventory[idx].updatedAt = Date()
            store.saveAll()
            toast = "Stock updated"
        }
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 3: Water Log

struct WaterLogView: View {
    @EnvironmentObject var store: FarmStore
    @State private var editor: EditorItem<WaterCheck>?
    @State private var deleteTarget: WaterCheck?
    @State private var toast: String?

    var body: some View {
        ScreenScaffold(title: "Water & Heat Notes") {
            DualActionBar(primaryTitle: "Log Check", primaryIcon: "checkmark.circle.fill",
                          primaryAction: { editor = .new() },
                          secondaryTitle: "Add Alert", secondaryIcon: "exclamationmark.triangle.fill",
                          secondaryAction: addAlert)

            if !store.waterChecks.isEmpty {
                PTCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Temperature trend").font(PTFont.headline).foregroundColor(PT.ink)
                        LineChartView(points: store.waterChecks.prefix(7).reversed().map { $0.temperatureC },
                                      labels: store.waterChecks.prefix(7).reversed().map { FarmStore.dateShort($0.date) },
                                      tint: PT.info)
                    }
                }
            }

            SectionHeader(title: "Recent checks")
            if store.waterChecks.isEmpty {
                EmptyStateView(icon: "drop.fill", title: "No checks logged",
                               message: "Log water, temperature and ventilation to catch problems early.",
                               actionTitle: "Log Check") { editor = .new() }
            } else {
                ForEach(store.waterChecks) { c in
                    RowCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(store.zoneName(c.zoneID)).font(PTFont.callout).foregroundColor(PT.ink)
                                Spacer()
                                Text(dateTime(c.date)).font(PTFont.caption).foregroundColor(PT.inkFaint)
                            }
                            HStack(spacing: 8) {
                                StatusChip(text: "\(FarmStore.num(c.temperatureC))°C", color: tempColor(c.temperatureC), icon: "thermometer")
                                StatusChip(text: c.waterOK ? "Water OK" : "Water low", color: c.waterOK ? PT.success : PT.danger)
                                StatusChip(text: c.ventilationOK ? "Vent OK" : "Vent low", color: c.ventilationOK ? PT.success : PT.warning)
                                StatusChip(text: c.drinkersClean ? "Drinkers" : "Clean drinkers", color: c.drinkersClean ? PT.success : PT.warning)
                            }
                            if !c.note.isEmpty {
                                Text(c.note).font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
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
        .sheet(item: $editor) { target in AddWaterCheckSheet(editing: target.value, toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { c in
            Alert(title: Text("Delete this check?"),
                  message: Text("\(store.zoneName(c.zoneID)) · \(FarmStore.num(c.temperatureC))°C"),
                  primaryButton: .destructive(Text("Delete")) {
                      store.waterChecks.removeAll { $0.id == c.id }; store.saveAll()
                  },
                  secondaryButton: .cancel())
        }
        .toast($toast)
    }

    private func tempColor(_ t: Double) -> Color {
        if t < 10 || t > 30 { return PT.danger }
        if t < 15 || t > 27 { return PT.warning }
        return PT.success
    }
    private func addAlert() {
        store.riskFlags.insert(RiskFlag(title: "Water / heat alert",
                                        detail: "Manual alert raised from Water Log",
                                        severity: .medium, source: "Manual"), at: 0)
        store.saveAll()
        toast = "Alert added to Risk Flags"
    }
}

private struct AddWaterCheckSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: WaterCheck? = nil
    @Binding var toast: String?
    @State private var zoneID: UUID?
    @State private var temp = "21"
    @State private var waterOK = true
    @State private var ventOK = true
    @State private var drinkers = true
    @State private var note = ""

    // Temperature must parse and stay within a sane poultry-housing range.
    private var tempValue: Double? { Double(temp.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
    private var tempValid: Bool { if let t = tempValue { return t >= -30 && t <= 60 } else { return false } }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Log Check" : "Edit Check",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: tempValid) {
            FormRow(label: "Zone") { ZonePicker(selection: $zoneID) }
            FormRow(label: "Temperature °C") {
                PTTextField(placeholder: "21", text: $temp, keyboard: .numbersAndPunctuation, icon: "thermometer")
            }
            if !temp.isEmpty && !tempValid {
                Text("Enter a temperature between -30°C and 60°C.")
                    .font(PTFont.caption).foregroundColor(PT.danger)
            }
            Toggle("Water level OK", isOn: $waterOK).toggleStyle(PTToggleStyle())
            Toggle("Ventilation OK", isOn: $ventOK).toggleStyle(PTToggleStyle())
            Toggle("Drinkers clean", isOn: $drinkers).toggleStyle(PTToggleStyle())
            FormRow(label: "Note") { PTTextField(placeholder: "Optional note", text: $note, icon: "text.alignleft") }
        }
        .onAppear {
            if let c = editing {
                zoneID = c.zoneID; temp = FarmStore.num(c.temperatureC)
                waterOK = c.waterOK; ventOK = c.ventilationOK; drinkers = c.drinkersClean; note = c.note
            } else {
                zoneID = store.zones.first?.id
            }
        }
    }
    private func save() {
        guard let t = tempValue else { return }
        if let c = editing, let i = store.waterChecks.firstIndex(where: { $0.id == c.id }) {
            store.waterChecks[i].zoneID = zoneID
            store.waterChecks[i].temperatureC = t
            store.waterChecks[i].waterOK = waterOK
            store.waterChecks[i].ventilationOK = ventOK
            store.waterChecks[i].drinkersClean = drinkers
            store.waterChecks[i].note = note
            toast = "Check updated"
        } else {
            let c = WaterCheck(zoneID: zoneID, waterOK: waterOK, temperatureC: t,
                               ventilationOK: ventOK, drinkersClean: drinkers, note: note)
            store.waterChecks.insert(c, at: 0)
            toast = "Check logged"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 4: Health Observation

struct HealthObservationView: View {
    @EnvironmentObject var store: FarmStore
    @State private var editor: EditorItem<Observation>?
    @State private var showFlag = false
    @State private var deleteTarget: Observation?
    @State private var toast: String?

    var body: some View {
        ScreenScaffold(title: "Observation Log",
                       subtitle: "Notes only — no medical diagnosis. Flag a group for re-check.") {
            DualActionBar(primaryTitle: "Add Symptom", primaryIcon: "plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: "Flag Group", secondaryIcon: "flag.fill",
                          secondaryAction: { showFlag = true })

            if store.observations.isEmpty {
                EmptyStateView(icon: "eye.fill", title: "No observations",
                               message: "Record activity, appetite and appearance to spot changes over time.",
                               actionTitle: "Add Symptom") { editor = .new() }
            } else {
                ForEach(store.observations) { o in
                    RowCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(store.groupName(o.groupID)).font(PTFont.callout).foregroundColor(PT.ink)
                                Spacer()
                                Button {
                                    toggleFlag(o)
                                } label: {
                                    Image(systemName: o.flagged ? "flag.fill" : "flag")
                                        .foregroundColor(o.flagged ? PT.danger : PT.inkFaint)
                                }
                            }
                            HStack(spacing: 8) {
                                ratingChip("Activity", o.activity)
                                ratingChip("Appetite", o.appetite)
                                ratingChip("Look", o.appearance)
                            }
                            if !o.symptom.isEmpty {
                                Text(o.symptom).font(PTFont.subhead).foregroundColor(PT.ink)
                            }
                            Text(dateTime(o.date)).font(PTFont.caption).foregroundColor(PT.inkFaint)
                        }
                    }
                    .onTapGesture { editor = .edit(o) }
                    .contextMenu {
                        Button { editor = .edit(o) } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { deleteTarget = o } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(item: $editor) { target in AddObservationSheet(editing: target.value, toast: $toast).environmentObject(store) }
        .sheet(isPresented: $showFlag) { FlagGroupSheet(toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { o in
            Alert(title: Text("Delete this observation?"),
                  message: Text("\(store.groupName(o.groupID)) · \(FarmStore.dateShort(o.date))"),
                  primaryButton: .destructive(Text("Delete")) {
                      store.observations.removeAll { $0.id == o.id }; store.saveAll()
                  },
                  secondaryButton: .cancel())
        }
        .toast($toast)
    }

    private func ratingChip(_ label: String, _ r: Rating) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9, design: .rounded)).foregroundColor(PT.inkFaint)
            StatusChip(text: r.title, color: r.color)
        }
    }
    private func toggleFlag(_ o: Observation) {
        if let i = store.observations.firstIndex(where: { $0.id == o.id }) {
            store.observations[i].flagged.toggle(); store.saveAll()
        }
    }
}

private struct AddObservationSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: Observation? = nil
    @Binding var toast: String?
    @State private var groupID: UUID?
    @State private var activity: Rating = .good
    @State private var appetite: Rating = .good
    @State private var appearance: Rating = .good
    @State private var symptom = ""
    @State private var flag = false

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Symptom" : "Edit Observation",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: groupID != nil) {
            FormRow(label: "Group") { GroupPicker(selection: $groupID) }
            ratingRow("Activity", $activity)
            ratingRow("Appetite", $appetite)
            ratingRow("Appearance", $appearance)
            FormRow(label: "Symptom / note") { PTTextField(placeholder: "e.g. less active", text: $symptom, icon: "text.alignleft") }
            Toggle("Flag for re-check", isOn: $flag).toggleStyle(PTToggleStyle())
        }
        .onAppear {
            if let o = editing {
                groupID = o.groupID; activity = o.activity; appetite = o.appetite
                appearance = o.appearance; symptom = o.symptom; flag = o.flagged
            } else {
                groupID = store.groups.first?.id
            }
        }
    }
    private func ratingRow(_ label: String, _ binding: Binding<Rating>) -> some View {
        FormRow(label: label) {
            HStack(spacing: 8) {
                ForEach(Rating.allCases) { r in
                    Button { binding.wrappedValue = r } label: { Text(r.title) }
                        .buttonStyle(ChipButtonStyle(isSelected: binding.wrappedValue == r))
                }
            }
        }
    }
    private func save() {
        if let o = editing, let i = store.observations.firstIndex(where: { $0.id == o.id }) {
            store.observations[i].groupID = groupID
            store.observations[i].activity = activity
            store.observations[i].appetite = appetite
            store.observations[i].appearance = appearance
            store.observations[i].symptom = symptom
            store.observations[i].flagged = flag
            toast = "Observation updated"
        } else {
            let o = Observation(groupID: groupID, activity: activity, appetite: appetite,
                                appearance: appearance, symptom: symptom, flagged: flag)
            store.observations.insert(o, at: 0)
            toast = "Observation saved"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

private struct FlagGroupSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    @Binding var toast: String?
    @State private var groupID: UUID?
    @State private var reason = ""

    var body: some View {
        SheetScaffold(title: "Flag Group", onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: groupID != nil) {
            FormRow(label: "Group to flag") { GroupPicker(selection: $groupID) }
            FormRow(label: "Reason") { PTTextField(placeholder: "Why re-check?", text: $reason, icon: "flag") }
        }
        .onAppear { groupID = store.groups.first?.id }
    }
    private func save() {
        let o = Observation(groupID: groupID, activity: .fair, appetite: .fair, appearance: .fair,
                            symptom: reason.isEmpty ? "Flagged for re-check" : reason, flagged: true)
        store.observations.insert(o, at: 0); store.saveAll()
        toast = "Group flagged"
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 5: Cleaning Schedule

struct CleaningScheduleView: View {
    @EnvironmentObject var store: FarmStore
    @State private var editor: EditorItem<CleaningTask>?
    @State private var deleteTarget: CleaningTask?
    @State private var toast: String?

    var body: some View {
        ScreenScaffold(title: "Clean Plan") {
            DualActionBar(primaryTitle: "Schedule Task", primaryIcon: "calendar.badge.plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: "Mark Clean", secondaryIcon: "checkmark.seal.fill",
                          secondaryAction: markNext)

            if store.cleaningTasks.isEmpty {
                EmptyStateView(icon: "sparkles", title: "Nothing scheduled",
                               message: "Plan litter changes and sanitation cycles. Overdue items show on the Dashboard.",
                               actionTitle: "Schedule Task") { editor = .new() }
            } else {
                ForEach(store.cleaningTasks.sorted { $0.dueDate < $1.dueDate }) { t in
                    RowCard {
                        HStack(spacing: 12) {
                            Button { toggle(t) } label: {
                                Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22)).foregroundColor(t.isDone ? PT.success : PT.inkFaint)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(t.title).font(PTFont.callout).foregroundColor(PT.ink)
                                    .strikethrough(t.isDone)
                                Text("\(t.type) · \(store.zoneName(t.zoneID))").font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(FarmStore.dateShort(t.dueDate)).font(PTFont.captionBold).foregroundColor(PT.ink)
                                if t.isOverdue { StatusChip(text: "Overdue", color: PT.danger, filled: true) }
                                else if t.isDone { StatusChip(text: "Done", color: PT.success) }
                            }
                        }
                    }
                    .onTapGesture { editor = .edit(t) }
                    .contextMenu {
                        Button { editor = .edit(t) } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { deleteTarget = t } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(item: $editor) { target in AddCleaningSheet(editing: target.value, toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { t in
            Alert(title: Text("Delete \"\(t.title)\"?"),
                  message: Text("\(t.type) · \(store.zoneName(t.zoneID))"),
                  primaryButton: .destructive(Text("Delete")) {
                      store.cleaningTasks.removeAll { $0.id == t.id }; store.saveAll()
                  },
                  secondaryButton: .cancel())
        }
        .toast($toast)
    }

    private func toggle(_ t: CleaningTask) {
        if let i = store.cleaningTasks.firstIndex(where: { $0.id == t.id }) {
            store.cleaningTasks[i].isDone.toggle()
            store.cleaningTasks[i].completedDate = store.cleaningTasks[i].isDone ? Date() : nil
            store.saveAll()
        }
    }
    private func markNext() {
        if let i = store.cleaningTasks.firstIndex(where: { !$0.isDone }) {
            store.cleaningTasks[i].isDone = true
            store.cleaningTasks[i].completedDate = Date()
            store.saveAll()
            toast = "Marked clean: \(store.cleaningTasks[i].title)"
        } else {
            toast = "Everything is already clean"
        }
    }
}

private struct AddCleaningSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: CleaningTask? = nil
    @Binding var toast: String?
    @State private var type = CleaningTask.types[0]
    @State private var zoneID: UUID?
    @State private var due = Date()

    var body: some View {
        SheetScaffold(title: editing == nil ? "Schedule Task" : "Edit Task",
                      onCancel: { presentation.wrappedValue.dismiss() }, onSave: save) {
            FormRow(label: "Type") { SegChips(options: CleaningTask.types, selection: $type) }
            FormRow(label: "Zone") { ZonePicker(selection: $zoneID) }
            FormRow(label: "Due date") {
                DatePicker("", selection: $due, displayedComponents: .date).labelsHidden()
            }
        }
        .onAppear {
            if let t = editing {
                type = t.type; zoneID = t.zoneID; due = t.dueDate
            } else {
                zoneID = store.zones.first?.id
            }
        }
    }
    private func save() {
        if let t = editing, let i = store.cleaningTasks.firstIndex(where: { $0.id == t.id }) {
            store.cleaningTasks[i].type = type
            store.cleaningTasks[i].title = type
            store.cleaningTasks[i].zoneID = zoneID
            store.cleaningTasks[i].dueDate = due
            toast = "Task updated"
        } else {
            store.cleaningTasks.append(CleaningTask(title: type, zoneID: zoneID, type: type, dueDate: due))
            toast = "Cleaning scheduled"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 23: Daily Care Checklist

struct DailyChecklistView: View {
    @EnvironmentObject var store: FarmStore
    @State private var toast: String?
    @State private var refresh = false

    private var progress: Double {
        guard !store.checklistItems.isEmpty else { return 0 }
        let done = store.checklistItems.filter { store.isChecklistDone($0) }.count
        return Double(done) / Double(store.checklistItems.count)
    }

    var body: some View {
        ScreenScaffold(title: "Morning / Evening Checks") {
            PTCard {
                HStack(spacing: 16) {
                    ProgressRing(progress: progress, tint: PT.success, size: 84)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Today's consistency").font(PTFont.headline).foregroundColor(PT.ink)
                        Text("\(store.checklistItems.filter { store.isChecklistDone($0) }.count)/\(store.checklistItems.count) complete")
                            .font(PTFont.subhead).foregroundColor(PT.inkSoft)
                        StatusChip(text: "7-day \(Int(store.careConsistency() * 100))%", color: PT.success, icon: "chart.bar.fill")
                    }
                    Spacer()
                }
            }

            DualActionBar(primaryTitle: "Mark Done", primaryIcon: "checkmark.circle.fill",
                          primaryAction: markAll,
                          secondaryTitle: "Skip Today", secondaryIcon: "xmark.circle.fill",
                          secondaryAction: skip)

            checklistSection("Morning", icon: "sun.max.fill")
            checklistSection("Evening", icon: "moon.stars.fill")
        }
        .toast($toast)
        .id(refresh)
    }

    private func checklistSection(_ period: String, icon: String) -> some View {
        let items = store.checklistItems.filter { $0.period == period }
        return VStack(alignment: .leading, spacing: 10) {
            Label(period, systemImage: icon).font(PTFont.title2).foregroundColor(PT.ink)
            ForEach(items) { item in
                let done = store.isChecklistDone(item)
                Button {
                    store.toggleChecklist(item: item)
                    refresh.toggle()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9).fill((done ? PT.success : PT.inkFaint).opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: item.icon).foregroundColor(done ? PT.success : PT.inkFaint)
                        }
                        Text(item.title).font(PTFont.callout).foregroundColor(PT.ink).strikethrough(done)
                        Spacer()
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22)).foregroundColor(done ? PT.success : PT.stroke)
                    }
                    .padding(13)
                    .background(PT.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PT.stroke, lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func markAll() {
        for item in store.checklistItems where !store.isChecklistDone(item) {
            store.toggleChecklist(item: item)
        }
        refresh.toggle()
        toast = "All checks marked done"
    }
    private func skip() {
        store.skipChecklistToday(); refresh.toggle()
        toast = "Skipped today"
    }
}

// MARK: - Screen 15: Daily Review

struct DailyReviewView: View {
    @EnvironmentObject var store: FarmStore
    @State private var showQuickAdd = false
    @State private var note = ""
    @State private var toast: String?

    private var doneChecks: Int { store.checklistItems.filter { store.isChecklistDone($0) }.count }
    private var missedChecks: Int { store.checklistItems.count - doneChecks }
    private var todaysEntries: Int { store.entries(on: Date()).count }

    var body: some View {
        ScreenScaffold(title: "End of Day Review") {
            PTCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("How today went").font(PTFont.headline).foregroundColor(PT.ink)
                    HStack(spacing: 12) {
                        reviewStat("\(doneChecks)", "Closed", PT.success, "checkmark.circle.fill")
                        reviewStat("\(missedChecks)", "Missed", missedChecks > 0 ? PT.warning : PT.success, "circle.dashed")
                        reviewStat("\(todaysEntries)", "Entries", PT.primary, "tray.full.fill")
                    }
                }
            }

            if !store.overdueTasks.isEmpty || !store.overdueCleaning.isEmpty {
                PTCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Still open", systemImage: "exclamationmark.circle.fill")
                            .font(PTFont.headline).foregroundColor(PT.ink)
                        ForEach(store.overdueTasks.prefix(3)) { t in
                            bullet(t.title, PT.warning)
                        }
                        ForEach(store.overdueCleaning.prefix(2)) { c in
                            bullet("Cleaning: \(c.title)", PT.warning)
                        }
                    }
                }
            }

            FormRow(label: "Day note") {
                PTTextField(placeholder: "Anything to remember about today?", text: $note, icon: "text.alignleft")
            }

            DualActionBar(primaryTitle: "Complete Day", primaryIcon: "checkmark.seal.fill",
                          primaryAction: complete,
                          secondaryTitle: "Add Missing", secondaryIcon: "plus.circle.fill",
                          secondaryAction: { showQuickAdd = true })

            if !store.reviews.isEmpty {
                SectionHeader(title: "Past reviews")
                ForEach(store.reviews.sorted { $0.date > $1.date }.prefix(7)) { r in
                    RowCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(FarmStore.dateShort(r.date)).font(PTFont.callout).foregroundColor(PT.ink)
                                if !r.note.isEmpty { Text(r.note).font(PTFont.caption).foregroundColor(PT.inkSoft).lineLimit(1) }
                            }
                            Spacer()
                            StatusChip(text: "\(r.completedCount) done", color: PT.success)
                            StatusChip(text: "\(r.missedCount) missed", color: r.missedCount > 0 ? PT.warning : PT.success)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showQuickAdd) { QuickAddView(asSheet: true).environmentObject(store) }
        .toast($toast)
    }

    private func reviewStat(_ v: String, _ l: String, _ c: Color, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(c).font(.system(size: 20, weight: .semibold))
            Text(v).font(PTFont.title).foregroundColor(PT.ink)
            Text(l).font(PTFont.caption).foregroundColor(PT.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
    private func bullet(_ text: String, _ c: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(text).font(PTFont.subhead).foregroundColor(PT.ink).lineLimit(1)
            Spacer()
        }
    }
    private func complete() {
        let rec = DailyReviewRecord(date: Date(), completedCount: doneChecks, missedCount: missedChecks, note: note)
        // replace today's record if exists
        store.reviews.removeAll { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
        store.reviews.append(rec); store.saveAll()
        note = ""
        toast = "Day completed & saved"
    }
}

// MARK: - Screen 19: Quick Add

struct QuickAddView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var asSheet = false
    @State private var type = CareEntry.types[0]
    @State private var groupID: UUID?
    @State private var zoneID: UUID?
    @State private var note = ""
    @State private var toast: String?

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormRow(label: "Entry type") { SegChips(options: CareEntry.types, selection: $type) }
                FormRow(label: "Group") { GroupPicker(selection: $groupID, allowNone: true) }
                FormRow(label: "Zone") { ZonePicker(selection: $zoneID, allowNone: true) }
                FormRow(label: "Note") { PTTextField(placeholder: "Add details (optional)", text: $note, icon: "text.alignleft") }

                DualActionBar(primaryTitle: "Save Entry", primaryIcon: "checkmark.circle.fill",
                              primaryAction: { save(close: true) },
                              secondaryTitle: "Add Another", secondaryIcon: "plus",
                              secondaryAction: { save(close: false) })
                    .padding(.top, 4)
            }
            .padding(18)
        }
        .ptScreenBackground()
        .navigationBarTitle("New Farm Entry", displayMode: .inline)
        .navigationBarItems(trailing: asSheet ? Button("Close") { presentation.wrappedValue.dismiss() } : nil)
        .toast($toast)
    }

    var body: some View {
        if asSheet {
            NavigationView { content }.navigationViewStyle(StackNavigationViewStyle())
        } else {
            content
        }
    }

    private func save(close: Bool) {
        let entry = CareEntry(type: type, groupID: groupID, zoneID: zoneID, note: note)
        store.logCare(entry)
        if close {
            presentation.wrappedValue.dismiss()
        } else {
            note = ""
            toast = "Saved — add another"
        }
    }
}

// MARK: - Shared pickers, toggle style, helpers

struct GroupPicker: View {
    @EnvironmentObject var store: FarmStore
    @AppStorage("pref.colorLabels") private var colorLabels = true
    @Binding var selection: UUID?
    var allowNone: Bool = false
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if allowNone {
                    chip(title: "None", color: PT.neutral, selected: selection == nil) { selection = nil }
                }
                ForEach(store.groups) { g in
                    chip(title: g.name, color: colorLabels ? g.color : PT.neutral,
                         selected: selection == g.id) { selection = g.id }
                }
                if store.groups.isEmpty && !allowNone {
                    Text("No groups yet").font(PTFont.caption).foregroundColor(PT.inkFaint)
                }
            }
        }
    }
    private func chip(title: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(title).font(PTFont.callout)
            }
            .foregroundColor(selected ? .white : PT.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(CapsuleFill(selected: selected))
        }
    }
}

struct ZonePicker: View {
    @EnvironmentObject var store: FarmStore
    @Binding var selection: UUID?
    var allowNone: Bool = false
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if allowNone {
                    Button { selection = nil } label: { Text("None") }
                        .buttonStyle(ChipButtonStyle(isSelected: selection == nil))
                }
                ForEach(store.zones) { z in
                    Button { selection = z.id } label: {
                        Label(z.name, systemImage: z.icon)
                    }
                    .buttonStyle(ChipButtonStyle(isSelected: selection == z.id))
                }
                if store.zones.isEmpty && !allowNone {
                    Text("No zones yet").font(PTFont.caption).foregroundColor(PT.inkFaint)
                }
            }
        }
    }
}

struct FeedItemPicker: View {
    @EnvironmentObject var store: FarmStore
    @Binding var selection: UUID?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.inventory.filter { $0.category == "Feed" }) { item in
                    Button { selection = item.id } label: { Text(item.name) }
                        .buttonStyle(ChipButtonStyle(isSelected: selection == item.id))
                }
                if store.inventory.filter({ $0.category == "Feed" }).isEmpty {
                    Text("No feed items").font(PTFont.caption).foregroundColor(PT.inkFaint)
                }
            }
        }
    }
}

struct PTToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { configuration.isOn.toggle() }
        } label: {
            HStack {
                configuration.label.font(PTFont.callout).foregroundColor(PT.ink)
                Spacer()
                ZStack {
                    Capsule().fill(configuration.isOn ? PT.primary : PT.stroke)
                        .frame(width: 46, height: 28)
                    Circle().fill(Color.white).frame(width: 22, height: 22)
                        .offset(x: configuration.isOn ? 9 : -9)
                        .shadow(radius: 1)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Reusable bottom-sheet scaffold with Cancel / Save chrome.
struct SheetScaffold<Content: View>: View {
    let title: String
    let onCancel: () -> Void
    let onSave: () -> Void
    var saveEnabled: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) { content() }
                    .padding(18)
            }
            .ptScreenBackground()
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel).foregroundColor(PT.inkSoft),
                trailing: Button(action: onSave) { Text("Save").bold() }
                    .disabled(!saveEnabled)
                    .foregroundColor(saveEnabled ? PT.primary : PT.inkFaint)
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Date/time formatting
func dateTime(_ date: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "MMM d · HH:mm"; return f.string(from: date)
}
