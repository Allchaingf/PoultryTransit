//
//  RoutesViews.swift
//  PoultryTransit
//
//  Transit section: hub + Care Route planner (6) and Transport Prep (7).
//

import SwiftUI
import Combine

// MARK: - Hub

struct RoutesHubView: View {
    @EnvironmentObject var store: FarmStore

    var body: some View {
        ScreenScaffold(title: "Routes & Transport",
                       subtitle: "Plan care rounds and prepare poultry transport with crates and stops.") {
            HubGrid {
                HubLinkCard(title: "Care Route", subtitle: "\(store.routes.count) routes · timed rounds",
                            icon: "map.fill", tint: PT.primary) { RoutePlannerView() }
                HubLinkCard(title: "Transit Checklist", subtitle: transportSubtitle,
                            icon: "shippingbox.fill", tint: PT.clay,
                            badge: (store.upcomingTransport?.confirmed == false) ? "!" : nil) { TransportPrepView() }
            }

            if let t = store.upcomingTransport {
                SectionHeader(title: "Next departure")
                RowCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(t.title).font(PTFont.headline).foregroundColor(PT.ink)
                            Spacer()
                            StatusChip(text: t.confirmed ? "Confirmed" : "Pending",
                                       color: t.confirmed ? PT.success : PT.warning, filled: t.confirmed)
                        }
                        Text("\(t.crateCount) crates · \(t.totalBirds) birds · departs \(dateTime(t.departure))")
                            .font(PTFont.caption).foregroundColor(PT.inkSoft)
                    }
                }
            }
        }
    }

    private var transportSubtitle: String {
        if let t = store.upcomingTransport { return "\(t.crateCount) crates · \(t.totalBirds) birds" }
        return "Crates, water & stops"
    }
}

// MARK: - Screen 6: Route Planner

struct RoutePlannerView: View {
    @EnvironmentObject var store: FarmStore
    @State private var editor: EditorItem<CareRoute>?
    @State private var runningRoute: CareRoute?
    @State private var toast: String?
    @State private var deleteTarget: CareRoute?

    var body: some View {
        ScreenScaffold(title: "Care Route") {
            DualActionBar(primaryTitle: "Build Route", primaryIcon: "plus",
                          primaryAction: { editor = .new() },
                          secondaryTitle: "Start Round", secondaryIcon: "play.circle.fill",
                          secondaryAction: { runningRoute = store.routes.first; if runningRoute == nil { toast = "Build a route first" } })

            if store.routes.isEmpty {
                EmptyStateView(icon: "map.fill", title: "No routes",
                               message: "Build a walking order of zones. The app estimates the round time.",
                               actionTitle: "Build Route") { editor = .new() }
            } else {
                ForEach(store.routes) { r in
                    RowCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(r.name).font(PTFont.headline).foregroundColor(PT.ink)
                                Spacer()
                                StatusChip(text: "~\(r.estimatedMinutes) min", color: PT.primary, icon: "clock")
                            }
                            // checkpoint chips
                            HStack(spacing: 6) {
                                ForEach(Array(r.stopZoneIDs.enumerated()), id: \.offset) { idx, zid in
                                    HStack(spacing: 4) {
                                        Text("\(idx + 1)").font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .frame(width: 18, height: 18).background(Circle().fill(PT.primary))
                                        Text(store.zoneName(zid)).font(PTFont.caption).foregroundColor(PT.ink)
                                    }
                                    if idx < r.stopZoneIDs.count - 1 {
                                        Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(PT.inkFaint)
                                    }
                                }
                            }
                            // Real timing summary from recorded runs.
                            if let run = store.lastRun(for: r.id) {
                                HStack(spacing: 6) {
                                    Image(systemName: "stopwatch").font(.system(size: 10)).foregroundColor(PT.success)
                                    Text("Last \(run.durationText) (\(run.completedStops)/\(run.totalStops))")
                                        .font(PTFont.caption).foregroundColor(PT.ink)
                                    if run.partial {
                                        StatusChip(text: "Partial", color: PT.warning)
                                    } else {
                                        StatusChip(text: "Complete", color: PT.success)
                                    }
                                    if let avg = store.averageActualMinutes(for: r.id) {
                                        Text("· avg ~\(avg) min").font(PTFont.caption).foregroundColor(PT.inkFaint)
                                    }
                                }
                            }
                            HStack {
                                if let last = r.lastRunAt {
                                    Text("Last run \(dateTime(last))").font(PTFont.caption).foregroundColor(PT.inkFaint)
                                } else {
                                    Text("Not run yet").font(PTFont.caption).foregroundColor(PT.inkFaint)
                                }
                                Spacer()
                                Button { runningRoute = r } label: {
                                    Label("Start", systemImage: "play.fill").font(PTFont.caption)
                                }.foregroundColor(PT.primary)
                            }
                        }
                    }
                    .contextMenu {
                        Button { editor = .edit(r) } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { deleteTarget = r } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(item: $editor) { target in BuildRouteSheet(editing: target.value, toast: $toast).environmentObject(store) }
        .sheet(item: $runningRoute) { route in RouteRunView(route: route, toast: $toast).environmentObject(store) }
        .alert(item: $deleteTarget) { r in
            Alert(
                title: Text("Delete \"\(r.name)\"?"),
                message: Text("\(r.stopZoneIDs.count) stop\(r.stopZoneIDs.count == 1 ? "" : "s") · ~\(r.estimatedMinutes) min"),
                primaryButton: .destructive(Text("Delete")) {
                    store.routes.removeAll { $0.id == r.id }; store.saveAll()
                },
                secondaryButton: .cancel()
            )
        }
        .toast($toast)
    }
}

private struct BuildRouteSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: CareRoute? = nil
    @Binding var toast: String?
    @State private var name = "Morning Round"
    @State private var minutes = 8
    @State private var order: [UUID] = []

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    // Zones not yet in the route — prevents duplicate stops.
    private var availableZones: [Zone] {
        store.zones.sorted { $0.order < $1.order }.filter { !order.contains($0.id) }
    }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Build Route" : "Edit Route",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: !trimmedName.isEmpty && !order.isEmpty) {
            FormRow(label: "Route name") { PTTextField(placeholder: "Morning Round", text: $name, icon: "tag.fill") }
            StepperField(label: "Minutes per stop", value: $minutes, range: 1...60)

            FormRow(label: "Tap zones to add in order") {
                if availableZones.isEmpty {
                    Text(store.zones.isEmpty ? "Add zones first." : "All zones added.")
                        .font(PTFont.caption).foregroundColor(PT.inkFaint)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableZones) { z in
                                Button { if !order.contains(z.id) { order.append(z.id) } } label: {
                                    Label(z.name, systemImage: z.icon)
                                }.buttonStyle(ChipButtonStyle(isSelected: false))
                            }
                        }
                    }
                }
            }

            if !order.isEmpty {
                FormRow(label: "Route order (\(order.count) stops · ~\(order.count * minutes) min)") {
                    VStack(spacing: 8) {
                        ForEach(Array(order.enumerated()), id: \.offset) { idx, zid in
                            HStack(spacing: 10) {
                                Text("\(idx + 1)").font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white).frame(width: 22, height: 22)
                                    .background(Circle().fill(PT.primary))
                                Text(store.zoneName(zid)).font(PTFont.callout).foregroundColor(PT.ink)
                                Spacer()
                                Button { order.remove(at: idx) } label: {
                                    Image(systemName: "minus.circle.fill").foregroundColor(PT.danger)
                                }
                            }
                            .padding(10).background(PT.subtle)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
        }
        .onAppear {
            if let r = editing {
                name = r.name; minutes = r.minutesPerStop; order = r.stopZoneIDs
            }
        }
    }
    private func save() {
        if let r = editing, let i = store.routes.firstIndex(where: { $0.id == r.id }) {
            store.routes[i].name = trimmedName
            store.routes[i].minutesPerStop = minutes
            store.routes[i].stopZoneIDs = order
            toast = "Route updated"
        } else {
            store.routes.append(CareRoute(name: trimmedName, stopZoneIDs: order, minutesPerStop: minutes))
            toast = "Route built"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

private struct RouteRunView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    let route: CareRoute
    @Binding var toast: String?
    @State private var doneStops: Set<Int> = []
    @State private var startedAt = Date()
    @State private var now = Date()

    // Live elapsed timer while the round is in progress.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var allDone: Bool { !route.stopZoneIDs.isEmpty && doneStops.count == route.stopZoneIDs.count }
    private var elapsedText: String {
        let s = max(0, Int(now.timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PTCard {
                        HStack(spacing: 16) {
                            ProgressRing(progress: progress, tint: PT.primary, size: 80,
                                         label: "\(doneStops.count)/\(route.stopZoneIDs.count)")
                            VStack(alignment: .leading, spacing: 5) {
                                Text(route.name).font(PTFont.headline).foregroundColor(PT.ink)
                                Text("Estimated ~\(route.estimatedMinutes) min").font(PTFont.subhead).foregroundColor(PT.inkSoft)
                                StatusChip(text: "Elapsed \(elapsedText)", color: PT.primary, icon: "stopwatch")
                            }
                            Spacer()
                        }
                    }

                    ForEach(Array(route.stopZoneIDs.enumerated()), id: \.offset) { idx, zid in
                        Button {
                            if doneStops.contains(idx) { doneStops.remove(idx) } else { doneStops.insert(idx) }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill((doneStops.contains(idx) ? PT.success : PT.primary).opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    if doneStops.contains(idx) {
                                        Image(systemName: "checkmark").foregroundColor(PT.success).font(.system(size: 16, weight: .bold))
                                    } else {
                                        Text("\(idx + 1)").font(PTFont.headline).foregroundColor(PT.primary)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.zoneName(zid)).font(PTFont.callout).foregroundColor(PT.ink)
                                        .strikethrough(doneStops.contains(idx))
                                    Text("Checkpoint \(idx + 1)").font(PTFont.caption).foregroundColor(PT.inkSoft)
                                }
                                Spacer()
                            }
                            .padding(13).background(PT.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PT.stroke, lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Complete: only when every checkpoint is ticked.
                    Button(action: { finish(partial: false) }) { Label("Finish Complete", systemImage: "flag.checkered") }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!allDone)
                        .opacity(allDone ? 1 : 0.5)
                        .padding(.top, 6)

                    // End early: at least one stop, but not all — records a Partial run.
                    if doneStops.count >= 1 && !allDone {
                        Button(action: { finish(partial: true) }) { Label("End Early (Partial)", systemImage: "flag.slash") }
                            .buttonStyle(SecondaryButtonStyle())
                    }

                    Text(allDone ? "All checkpoints done — ready to complete."
                                 : "Complete unlocks after every checkpoint is ticked.")
                        .font(PTFont.caption).foregroundColor(PT.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(18)
            }
            .ptScreenBackground()
            .navigationBarTitle("Start Round", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentation.wrappedValue.dismiss() })
            .onAppear { startedAt = Date(); now = Date() }
            .onReceive(ticker) { now = $0 }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var progress: Double {
        route.stopZoneIDs.isEmpty ? 0 : Double(doneStops.count) / Double(route.stopZoneIDs.count)
    }
    private func finish(partial: Bool) {
        store.recordRouteRun(route: route, startedAt: startedAt, completedStops: doneStops.count)
        let label = partial ? "Partial route" : "Completed route"
        store.logCare(CareEntry(type: "Move",
                                note: "\(label): \(route.name) · \(doneStops.count)/\(route.stopZoneIDs.count) stops"))
        toast = partial ? "Partial round saved" : "Round completed & logged"
        presentation.wrappedValue.dismiss()
    }
}

// MARK: - Screen 7: Transport Prep

struct TransportPrepView: View {
    @EnvironmentObject var store: FarmStore
    @State private var selectedID: UUID?
    @State private var crateEditor: EditorItem<Crate>?
    @State private var loadEditor: EditorItem<TransportLoad>?
    @State private var deleteCrateTarget: Crate?
    @State private var newStop = ""
    @State private var toast: String?

    private var load: TransportLoad? {
        if let id = selectedID { return store.transports.first { $0.id == id } }
        return store.upcomingTransport ?? store.transports.first
    }

    var body: some View {
        ScreenScaffold(title: "Transit Checklist") {
            if store.transports.isEmpty {
                EmptyStateView(icon: "shippingbox.fill", title: "No transport planned",
                               message: "Create a load to prepare crates, water and stops for moving birds.",
                               actionTitle: "New Load") { loadEditor = .new() }
            } else if let load = load {
                // selector
                if store.transports.count > 1 {
                    SegChips(options: store.transports.map { $0.title },
                             selection: Binding(get: { load.title },
                                                set: { title in selectedID = store.transports.first { $0.title == title }?.id }))
                }

                // summary
                PTCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(load.title).font(PTFont.headline).foregroundColor(PT.ink)
                                Text("Departs \(dateTime(load.departure))").font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                            Spacer()
                            Button { loadEditor = .edit(load) } label: {
                                Image(systemName: "pencil").foregroundColor(PT.primary)
                                    .frame(width: 32, height: 32).background(Circle().fill(PT.subtle))
                            }
                            StatusChip(text: load.confirmed ? "Confirmed" : "Pending",
                                       color: load.confirmed ? PT.success : PT.warning, filled: load.confirmed,
                                       icon: load.confirmed ? "checkmark" : "clock")
                        }
                        HStack(spacing: 12) {
                            tStat("\(load.crateCount)", "crates", "shippingbox")
                            tStat("\(load.totalBirds)", "birds", "chicken")
                            tStat("\(load.watered)/\(load.crateCount)", "watered", "drop.fill")
                            tStat("\(load.stops.count)", "stops", "mappin")
                        }
                    }
                }

                // readiness checklist
                PTCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Readiness").font(PTFont.headline).foregroundColor(PT.ink)
                        readyRow("At least one crate added", load.crateCount > 0)
                        readyRow("Every crate has water", load.crateCount > 0 && load.watered == load.crateCount)
                        readyRow("Departure time set", load.departure > Date())
                        readyRow("Stops planned", !load.stops.isEmpty)
                        readyRow("Load confirmed", load.confirmed)
                    }
                }

                DualActionBar(primaryTitle: "Add Crate", primaryIcon: "plus",
                              primaryAction: { selectedID = load.id; crateEditor = .new() },
                              secondaryTitle: load.confirmed ? "Unconfirm" : "Confirm Load",
                              secondaryIcon: load.confirmed ? "xmark.seal" : "checkmark.seal.fill",
                              secondaryAction: { toggleConfirm(load) })

                // crates
                SectionHeader(title: "Crates")
                ForEach(load.crates) { crate in
                    RowCard {
                        HStack(spacing: 12) {
                            CrateShape().stroke(PT.clay, lineWidth: 2)
                                .frame(width: 42, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(crate.label).font(PTFont.callout).foregroundColor(PT.ink)
                                Text("\(crate.birdCount) birds · \(store.groupName(crate.groupID))")
                                    .font(PTFont.caption).foregroundColor(PT.inkSoft)
                            }
                            Spacer()
                            Button { toggleWater(load, crate) } label: {
                                Image(systemName: crate.hasWater ? "drop.fill" : "drop")
                                    .foregroundColor(crate.hasWater ? PT.info : PT.inkFaint)
                                    .frame(width: 34, height: 34).background(Circle().fill(PT.subtle))
                            }
                            Button { selectedID = load.id; crateEditor = .edit(crate) } label: {
                                Image(systemName: "pencil").foregroundColor(PT.primary)
                                    .frame(width: 34, height: 34).background(Circle().fill(PT.subtle))
                            }
                            Button { deleteCrateTarget = crate } label: {
                                Image(systemName: "trash").foregroundColor(PT.danger)
                                    .frame(width: 34, height: 34).background(Circle().fill(PT.danger.opacity(0.12)))
                            }
                        }
                    }
                }

                // stops
                SectionHeader(title: "Stops")
                ForEach(Array(load.stops.enumerated()), id: \.offset) { idx, stop in
                    RowCard {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill").foregroundColor(PT.primary)
                            Text(stop).font(PTFont.callout).foregroundColor(PT.ink)
                            Spacer()
                            Button { removeStop(load, idx) } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(PT.danger)
                            }
                        }
                    }
                }
                HStack(spacing: 10) {
                    PTTextField(placeholder: "Add a stop", text: $newStop, icon: "mappin")
                    Button { addStop(load) } label: {
                        Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(width: 46, height: 46).background(PT.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }

                Button { loadEditor = .new() } label: { Label("New load", systemImage: "plus.rectangle.on.folder") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .sheet(item: $crateEditor) { target in
            AddCrateSheet(loadID: selectedID ?? load?.id, editing: target.value, toast: $toast).environmentObject(store)
        }
        .sheet(item: $loadEditor) { target in
            NewLoadSheet(editing: target.value, toast: $toast).environmentObject(store)
        }
        .alert(item: $deleteCrateTarget) { crate in
            Alert(
                title: Text("Delete \"\(crate.label)\"?"),
                message: Text("\(crate.birdCount) birds in this crate."),
                primaryButton: .destructive(Text("Delete")) {
                    if let lid = load?.id, let i = store.transports.firstIndex(where: { $0.id == lid }) {
                        store.transports[i].crates.removeAll { $0.id == crate.id }; store.saveAll()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .toast($toast)
    }

    private func tStat(_ v: String, _ l: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            IconGlyph(name: icon, size: 14, color: PT.primary)
            Text(v).font(PTFont.captionBold).foregroundColor(PT.ink)
            Text(l).font(.system(size: 9, design: .rounded)).foregroundColor(PT.inkFaint)
        }.frame(maxWidth: .infinity)
    }
    private func readyRow(_ text: String, _ ok: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .foregroundColor(ok ? PT.success : PT.inkFaint)
            Text(text).font(PTFont.subhead).foregroundColor(ok ? PT.ink : PT.inkSoft)
            Spacer()
        }
    }

    private func idx(_ load: TransportLoad) -> Int? { store.transports.firstIndex { $0.id == load.id } }
    private func toggleConfirm(_ load: TransportLoad) {
        guard let i = idx(load) else { return }
        store.transports[i].confirmed.toggle(); store.saveAll()
        toast = store.transports[i].confirmed ? "Load confirmed" : "Confirmation removed"
    }
    private func toggleWater(_ load: TransportLoad, _ crate: Crate) {
        guard let i = idx(load), let c = store.transports[i].crates.firstIndex(where: { $0.id == crate.id }) else { return }
        store.transports[i].crates[c].hasWater.toggle(); store.saveAll()
    }
    private func addStop(_ load: TransportLoad) {
        let trimmed = newStop.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let i = idx(load) else { return }
        store.transports[i].stops.append(trimmed); store.saveAll(); newStop = ""
    }
    private func removeStop(_ load: TransportLoad, _ index: Int) {
        guard let i = idx(load) else { return }
        store.transports[i].stops.remove(at: index); store.saveAll()
    }
}

private struct AddCrateSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    let loadID: UUID?
    var editing: Crate? = nil
    @Binding var toast: String?
    @State private var label = ""
    @State private var count = 12
    @State private var hasWater = true
    @State private var groupID: UUID?

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Crate" : "Edit Crate",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: !label.trimmingCharacters(in: .whitespaces).isEmpty) {
            FormRow(label: "Crate label") { PTTextField(placeholder: "Crate 4", text: $label, icon: "shippingbox") }
            StepperField(label: "Bird count", value: $count, range: 1...200)
            FormRow(label: "Group") { GroupPicker(selection: $groupID, allowNone: true) }
            Toggle("Water provided", isOn: $hasWater).toggleStyle(PTToggleStyle())
        }
        .onAppear {
            if let c = editing {
                label = c.label; count = c.birdCount; hasWater = c.hasWater; groupID = c.groupID
            } else {
                groupID = store.groups.first?.id
                if label.isEmpty, let id = loadID, let load = store.transports.first(where: { $0.id == id }) {
                    label = "Crate \(load.crates.count + 1)"
                }
            }
        }
    }
    private func save() {
        guard let id = loadID, let i = store.transports.firstIndex(where: { $0.id == id }) else {
            presentation.wrappedValue.dismiss(); return
        }
        let name = label.trimmingCharacters(in: .whitespaces)
        if let c = editing, let ci = store.transports[i].crates.firstIndex(where: { $0.id == c.id }) {
            store.transports[i].crates[ci].label = name
            store.transports[i].crates[ci].birdCount = count
            store.transports[i].crates[ci].hasWater = hasWater
            store.transports[i].crates[ci].groupID = groupID
            toast = "Crate updated"
        } else {
            let crate = Crate(label: name.isEmpty ? "Crate \(store.transports[i].crates.count + 1)" : name,
                              birdCount: count, hasWater: hasWater, groupID: groupID)
            store.transports[i].crates.append(crate)
            toast = "Crate added"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}

private struct NewLoadSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentation
    var editing: TransportLoad? = nil
    @Binding var toast: String?
    @State private var title = ""
    @State private var departure = Date().addingTimeInterval(86400)

    var body: some View {
        SheetScaffold(title: editing == nil ? "New Load" : "Edit Load",
                      onCancel: { presentation.wrappedValue.dismiss() },
                      onSave: save, saveEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty) {
            FormRow(label: "Title") { PTTextField(placeholder: "e.g. Layers to buyer", text: $title, icon: "shippingbox.fill") }
            FormRow(label: "Departure") {
                DatePicker("", selection: $departure).labelsHidden()
            }
        }
        .onAppear {
            if let l = editing { title = l.title; departure = l.departure }
        }
    }
    private func save() {
        let name = title.trimmingCharacters(in: .whitespaces)
        if let l = editing, let i = store.transports.firstIndex(where: { $0.id == l.id }) {
            store.transports[i].title = name
            store.transports[i].departure = departure
            toast = "Load updated"
        } else {
            store.transports.insert(TransportLoad(title: name, departure: departure, crates: [], stops: []), at: 0)
            toast = "Load created"
        }
        store.saveAll()
        presentation.wrappedValue.dismiss()
    }
}
