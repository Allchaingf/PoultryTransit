//
//  GroupsViews.swift
//  PoultryTransit
//
//  Groups section: hub + Group Builder (20), Coop Zones (21) and
//  Space & Perch Capacity Calculator (22).
//

import SwiftUI

// MARK: - Hub

struct GroupsHubView: View {
    @EnvironmentObject var store: FarmStore
    @AppStorage("pref.colorLabels") private var colorLabels = true

    private func gColor(_ g: BirdGroup) -> Color { colorLabels ? g.color : PT.neutral }

    var body: some View {
        ScreenScaffold(title: "Groups & Zones",
                       subtitle: "Define bird groups and the zones that structure every checklist and route.") {
            HubGrid {
                HubLinkCard(title: "Bird Groups", subtitle: "\(store.groups.count) groups · \(store.totalBirds) birds",
                            icon: "chicken", tint: PT.primary) { GroupBuilderView() }
                HubLinkCard(title: "Farm Zones", subtitle: "\(store.zones.count) zones defined",
                            icon: "map.fill", tint: PT.clay) { CoopZonesView() }
                HubLinkCard(title: "Capacity", subtitle: "Space & perch check",
                            icon: "ruler.fill", tint: PT.amber) { CapacityCalculatorView() }
                HubLinkCard(title: "Quick Add", subtitle: "Log a movement or note",
                            icon: "plus.circle.fill", tint: PT.info) { QuickAddView() }
            }

            if !store.groups.isEmpty {
                SectionHeader(title: "Your groups")
                ForEach(store.groups) { g in
                    RowCard {
                        HStack(spacing: 12) {
                            Circle().fill(gColor(g)).frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.name).font(PTFont.callout).foregroundColor(PT.ink)
                                Text("\(g.kind) · \(store.zoneName(g.zoneID))").font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                            Spacer()
                            Text("\(g.count)").font(PTFont.title2).foregroundColor(gColor(g))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Screen 20: Group Builder

struct GroupBuilderView: View {
    @EnvironmentObject var store: FarmStore
    @AppStorage("pref.colorLabels") private var colorLabels = true
    @State private var showAdd = false
    @State private var editing: BirdGroup?
    @State private var toast: String?
    @State private var deleteTarget: BirdGroup?

    private func gColor(_ g: BirdGroup) -> Color { colorLabels ? g.color : PT.neutral }

    var body: some View {
        ScreenScaffold(title: "Bird Groups") {
            DualActionBar(primaryTitle: "Create Group", primaryIcon: "plus",
                          primaryAction: { editing = nil; showAdd = true },
                          secondaryTitle: "Edit Count", secondaryIcon: "slider.horizontal.3",
                          secondaryAction: { editing = store.groups.first; if editing != nil { showAdd = true } })

            if store.groups.isEmpty {
                EmptyStateView(icon: "chicken", title: "No groups",
                               message: "Create bird groups to power counts, filters and reports.",
                               actionTitle: "Create Group") { editing = nil; showAdd = true }
            } else {
                ForEach(store.groups) { g in
                    RowCard {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(gColor(g).opacity(0.2)).frame(width: 46, height: 46)
                                ChickenSilhouette().fill(gColor(g)).frame(width: 26, height: 22)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(g.name).font(PTFont.headline).foregroundColor(PT.ink)
                                Text("\(g.kind) · \(store.zoneName(g.zoneID))").font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(g.count)").font(PTFont.title).foregroundColor(gColor(g))
                                Text("birds").font(.system(size: 9, design: .rounded)).foregroundColor(PT.inkFaint)
                            }
                        }
                    }
                    .onTapGesture { editing = g; showAdd = true }
                    .contextMenu {
                        Button { editing = g; showAdd = true } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { deleteTarget = g } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            GroupEditorSheet(editing: editing, toast: $toast).environmentObject(store)
        }
        .alert(item: $deleteTarget) { g in
            let count = store.relatedCountForGroup(g.id)
            return Alert(
                title: Text("Delete \"\(g.name)\"?"),
                message: Text(count > 0
                    ? "This will also remove \(count) related record\(count == 1 ? "" : "s") (feed logs, observations, costs)."
                    : "This group has no related records."),
                primaryButton: .destructive(Text("Delete")) { store.deleteGroup(g.id) },
                secondaryButton: .cancel()
            )
        }
        .toast($toast)
    }
}

private struct GroupEditorSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    let editing: BirdGroup?
    @Binding var toast: String?

    @State private var name = ""
    @State private var kind = BirdGroup.kinds[0]
    @State private var count = 1
    @State private var zoneID: UUID?
    @State private var colorHex = BirdGroup.palette[0]

    var body: some View {
        SheetScaffold(title: editing == nil ? "Create Group" : "Edit Group",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
            FormRow(label: "Name") { PTTextField(placeholder: "e.g. Brown Layers", text: $name, icon: "tag.fill") }
            FormRow(label: "Type") { SegChips(options: BirdGroup.kinds, selection: $kind) }
            StepperField(label: "Bird count", value: $count, range: 1...100000, step: 1)
            FormRow(label: "Zone") { ZonePicker(selection: $zoneID, allowNone: true) }
            FormRow(label: "Colour marker") {
                HStack(spacing: 10) {
                    ForEach(BirdGroup.palette, id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                            .overlay(Circle().stroke(PT.ink, lineWidth: colorHex == hex ? 3 : 0))
                            .onTapGesture { colorHex = hex }
                    }
                }
            }
        }
        .onAppear {
            if let g = editing {
                name = g.name; kind = g.kind; count = g.count; zoneID = g.zoneID; colorHex = g.colorHex
            } else {
                zoneID = store.zones.first?.id
            }
        }
    }

    private func save() {
        if let g = editing, let idx = store.groups.firstIndex(where: { $0.id == g.id }) {
            store.groups[idx].name = name; store.groups[idx].kind = kind
            store.groups[idx].count = count; store.groups[idx].zoneID = zoneID
            store.groups[idx].colorHex = colorHex
            toast = "Group updated"
        } else {
            store.groups.append(BirdGroup(name: name, kind: kind, count: count, zoneID: zoneID, colorHex: colorHex))
            toast = "Group created"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 21: Coop Zones

struct CoopZonesView: View {
    @EnvironmentObject var store: FarmStore
    @State private var editor: EditorItem<Zone>?
    @State private var reordering = false
    @State private var toast: String?
    @State private var deleteTarget: Zone?

    private var sortedZones: [Zone] { store.zones.sorted { $0.order < $1.order } }

    var body: some View {
        ScreenScaffold(title: "Farm Zones") {
            DualActionBar(primaryTitle: "Add Zone", primaryIcon: "plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: reordering ? "Done" : "Reorder Zones",
                          secondaryIcon: reordering ? "checkmark" : "arrow.up.arrow.down",
                          secondaryAction: { withAnimation { reordering.toggle() } })

            if store.zones.isEmpty {
                EmptyStateView(icon: "map.fill", title: "No zones",
                               message: "Add coops, runs, quarantine and transport points to map your farm.",
                               actionTitle: "Add Zone") { editor = .new() }
            } else {
                ForEach(Array(sortedZones.enumerated()), id: \.element.id) { index, z in
                    RowCard {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(PT.primary.opacity(0.15)).frame(width: 40, height: 40)
                                Image(systemName: z.icon).foregroundColor(PT.primary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(z.name).font(PTFont.callout).foregroundColor(PT.ink)
                                Text("\(z.kind) · \(FarmStore.num(z.areaSqM)) m²").font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                            Spacer()
                            if reordering {
                                HStack(spacing: 6) {
                                    reorderButton("chevron.up", disabled: index == 0) { move(z, by: -1) }
                                    reorderButton("chevron.down", disabled: index == sortedZones.count - 1) { move(z, by: 1) }
                                }
                            } else {
                                StatusChip(text: "#\(index + 1)", color: PT.inkSoft)
                            }
                        }
                    }
                    .onTapGesture { if !reordering { editor = .edit(z) } }
                    .contextMenu {
                        Button { editor = .edit(z) } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { deleteTarget = z } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(item: $editor) { target in AddZoneSheet(editing: target.value, toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { z in
            let count = store.relatedCountForZone(z.id)
            return Alert(
                title: Text("Delete \"\(z.name)\"?"),
                message: Text(count > 0
                    ? "This zone is referenced by \(count) record\(count == 1 ? "" : "s") (groups, routes, tasks). References will be cleared."
                    : "This zone has no related records."),
                primaryButton: .destructive(Text("Delete")) { store.deleteZone(z.id) },
                secondaryButton: .cancel()
            )
        }
        .toast($toast)
    }

    private func reorderButton(_ icon: String, disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
                .foregroundColor(disabled ? PT.inkFaint : PT.primary)
                .frame(width: 32, height: 32).background(Circle().fill(PT.subtle))
        }.disabled(disabled)
    }

    private func move(_ zone: Zone, by offset: Int) {
        var arr = sortedZones
        guard let i = arr.firstIndex(where: { $0.id == zone.id }) else { return }
        let j = i + offset
        guard j >= 0, j < arr.count else { return }
        arr.swapAt(i, j)
        for (k, var z) in arr.enumerated() { z.order = k; if let idx = store.zones.firstIndex(where: { $0.id == z.id }) { store.zones[idx].order = k } }
        store.saveAll()
    }
}

private struct AddZoneSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: Zone? = nil
    @Binding var toast: String?
    @State private var name = ""
    @State private var kind = Zone.kinds[0]
    @State private var area = "20"
    @State private var perch = "6"
    @State private var note = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var areaValue: Double? { Double(area.trimmingCharacters(in: .whitespaces)) }
    private var perchValue: Double? { Double(perch.trimmingCharacters(in: .whitespaces)) }
    private var areaValid: Bool { (areaValue ?? 0) > 0 }
    // Perch may legitimately be 0 (yards/runs) but must be a valid, non-negative number.
    private var perchValid: Bool { if let p = perchValue { return p >= 0 } else { return false } }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Zone" : "Edit Zone",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: !trimmedName.isEmpty && areaValid && perchValid) {
            FormRow(label: "Name") { PTTextField(placeholder: "e.g. North Coop", text: $name, icon: "tag.fill") }
            FormRow(label: "Kind") { SegChips(options: Zone.kinds, selection: $kind) }
            FormRow(label: "Area (m²)") { PTTextField(placeholder: "20", text: $area, keyboard: .decimalPad, icon: "square.dashed") }
            if !area.isEmpty && !areaValid {
                fieldError("Area must be a number greater than 0.")
            }
            FormRow(label: "Perch length (m)") { PTTextField(placeholder: "6", text: $perch, keyboard: .decimalPad, icon: "ruler") }
            if !perch.isEmpty && !perchValid {
                fieldError("Perch length must be a number of 0 or more.")
            }
            FormRow(label: "Note") { PTTextField(placeholder: "Optional", text: $note, icon: "text.alignleft") }
        }
        .onAppear {
            if let z = editing {
                name = z.name; kind = z.kind
                area = FarmStore.num(z.areaSqM); perch = FarmStore.num(z.perchLengthM); note = z.note
            }
        }
    }
    private func fieldError(_ text: String) -> some View {
        Text(text).font(PTFont.caption).foregroundColor(PT.danger)
    }
    private func save() {
        guard let a = areaValue, let p = perchValue else { return }
        if let z = editing, let i = store.zones.firstIndex(where: { $0.id == z.id }) {
            store.zones[i].name = trimmedName; store.zones[i].kind = kind
            store.zones[i].areaSqM = a; store.zones[i].perchLengthM = p; store.zones[i].note = note
            toast = "Zone updated"
        } else {
            let order = (store.zones.map { $0.order }.max() ?? -1) + 1
            store.zones.append(Zone(name: trimmedName, kind: kind, order: order,
                                    areaSqM: a, perchLengthM: p, note: note))
            toast = "Zone added"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 22: Capacity Calculator

struct CapacityCalculatorView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @State private var zoneName = "Main Coop"
    @State private var area = "24"
    @State private var perch = "9"
    @State private var birds = "40"
    @State private var allowance = "0.25"   // m² per bird target
    @State private var result: CapacityResult?
    @State private var toast: String?

    var body: some View {
        ScreenScaffold(title: "Space & Perch Capacity",
                       subtitle: "Enter area, perch and bird count to check for overload.") {
            PTCard {
                VStack(alignment: .leading, spacing: 14) {
                    FormRow(label: "Zone label") { PTTextField(placeholder: "Main Coop", text: $zoneName, icon: "house.fill") }
                    HStack(spacing: 12) {
                        FormRow(label: "Area m²") { PTTextField(placeholder: "24", text: $area, keyboard: .decimalPad) }
                        FormRow(label: "Perch m") { PTTextField(placeholder: "9", text: $perch, keyboard: .decimalPad) }
                    }
                    HStack(spacing: 12) {
                        FormRow(label: "Birds") { PTTextField(placeholder: "40", text: $birds, keyboard: .numberPad) }
                        FormRow(label: "m² / bird target") { PTTextField(placeholder: "0.25", text: $allowance, keyboard: .decimalPad) }
                    }
                }
            }

            DualActionBar(primaryTitle: "Calculate", primaryIcon: "function",
                          primaryAction: calculate,
                          secondaryTitle: "Save Result", secondaryIcon: "tray.and.arrow.down.fill",
                          secondaryAction: saveResult)

            if let r = result {
                PTCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(r.zoneName).font(PTFont.headline).foregroundColor(PT.ink)
                            Spacer()
                            StatusChip(text: r.status, color: r.statusColor, filled: true,
                                       icon: r.status == "Comfortable" ? "checkmark" : "exclamationmark.triangle.fill")
                        }
                        HStack(spacing: 12) {
                            metric("\(FarmStore.num(r.birdsPerSqM))", "birds / m²", PT.primary)
                            metric("\(FarmStore.num(r.perchPerBirdCM)) cm", "perch / bird", PT.amber)
                            metric("\(r.birdCount)", "birds", PT.clay)
                        }
                        // visual density bar
                        GeometryReader { geo in
                            let ratio = min(r.birdsPerSqM / (1 / max(Double(allowance) ?? 0.25, 0.01)), 1.4)
                            ZStack(alignment: .leading) {
                                Capsule().fill(PT.subtle).frame(height: 14)
                                Capsule().fill(r.statusColor).frame(width: geo.size.width * CGFloat(min(ratio, 1)), height: 14)
                            }
                        }.frame(height: 14)
                        Text(advice(r)).font(PTFont.caption).foregroundColor(PT.inkSoft)
                    }
                }
            }

            if !store.capacityResults.isEmpty {
                SectionHeader(title: "Saved results")
                ForEach(store.capacityResults.sorted { $0.date > $1.date }) { r in
                    RowCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.zoneName).font(PTFont.callout).foregroundColor(PT.ink)
                                Text("\(FarmStore.num(r.birdsPerSqM)) birds/m² · \(FarmStore.dateShort(r.date))")
                                    .font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                            Spacer()
                            StatusChip(text: r.status, color: r.statusColor)
                        }
                    }
                    .contextMenu {
                        Button {
                            store.capacityResults.removeAll { $0.id == r.id }; store.saveAll()
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .toast($toast)
    }

    private func metric(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 5) {
            Text(v).font(PTFont.title2).foregroundColor(c)
            Text(l).font(PTFont.caption).foregroundColor(PT.inkSoft)
        }.frame(maxWidth: .infinity)
    }

    private func calculate() {
        let a = Double(area) ?? 0, pl = Double(perch) ?? 0
        let n = Double(birds) ?? 0
        guard let target = Double(allowance), target > 0 else {
            toast = "Enter a m² / bird target above 0"; return
        }
        guard a > 0, n > 0 else { toast = "Enter area and birds"; return }
        guard pl >= 0 else { toast = "Perch length can't be negative"; return }
        let density = n / a
        let perchPer = n > 0 ? (pl * 100 / n) : 0
        let maxBirds = a / max(target, 0.01)
        let status: String
        if n <= maxBirds * 0.85 { status = "Comfortable" }
        else if n <= maxBirds { status = "Near limit" }
        else { status = "Overloaded" }
        withAnimation(.spring()) {
            result = CapacityResult(zoneName: zoneName, areaSqM: a, perchLengthM: pl,
                                    birdCount: Int(n), birdsPerSqM: density,
                                    perchPerBirdCM: perchPer, status: status)
        }
    }

    private func saveResult() {
        guard let r = result else { calculate(); if result == nil { return }; return }
        store.capacityResults.insert(r, at: 0); store.saveAll()
        toast = "Result saved"
    }

    private func advice(_ r: CapacityResult) -> String {
        switch r.status {
        case "Overloaded": return "Density above target — consider moving birds or expanding the zone."
        case "Near limit": return "Close to the target allowance. Watch for crowding signs."
        default: return "Within a comfortable space allowance."
        }
    }
}
