//
//  SettingsView.swift
//  PoultryTransit
//
//  Screen 24 — App Preferences. Only app settings: theme, units, local
//  notifications, colour markers and sample-data control. No account, no
//  profile. Every control has a real, persisted, visible effect.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var prefs: AppPreferences
    @AppStorage("hasCompletedOnboarding") private var onboarded = true

    @State private var notifStatus = "Checking…"
    @State private var showResetAlert = false
    @State private var showClearAlert = false
    @State private var toast: String?

    private let currencies = ["$", "€", "£", "₴"]

    var body: some View {
        ScreenScaffold(title: "App Preferences") {
            DualActionBar(primaryTitle: "Change Units", primaryIcon: "ruler.fill",
                          primaryAction: toggleUnitSystem,
                          secondaryTitle: "Reset Sample Data", secondaryIcon: "arrow.counterclockwise",
                          secondaryAction: { showResetAlert = true })

            // Appearance
            settingsCard("Appearance", icon: "paintbrush.fill") {
                FormRow(label: "Theme") {
                    HStack(spacing: 8) {
                        ForEach(ThemeChoice.allCases) { choice in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { prefs.theme = choice }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: choice.icon).font(.system(size: 18, weight: .semibold))
                                    Text(choice.title).font(PTFont.caption)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .foregroundColor(prefs.theme == choice ? .white : PT.ink)
                                .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(prefs.theme == choice ? PT.primary : PT.subtle))
                            }
                        }
                    }
                }
                Toggle("Colour markers for groups", isOn: $prefs.colorLabelsEnabled).toggleStyle(PTToggleStyle())
            }

            // Units
            settingsCard("Units", icon: "ruler") {
                FormRow(label: "Weight") {
                    HStack(spacing: 8) {
                        unitChip("Kilograms", "kg", $prefs.weightUnit)
                        unitChip("Pounds", "lb", $prefs.weightUnit)
                    }
                }
                FormRow(label: "Length") {
                    HStack(spacing: 8) {
                        unitChip("Metres", "m", $prefs.lengthUnit)
                        unitChip("Feet", "ft", $prefs.lengthUnit)
                    }
                }
                FormRow(label: "Currency") {
                    HStack(spacing: 8) {
                        ForEach(currencies, id: \.self) { c in
                            Button { prefs.currency = c } label: { Text(c).font(PTFont.headline) }
                                .buttonStyle(ChipButtonStyle(isSelected: prefs.currency == c))
                        }
                    }
                }
                Text("Example: \(prefs.weight(80)) · \(prefs.length(9)) · \(prefs.money(64))")
                    .font(PTFont.caption).foregroundColor(PT.inkFaint)
            }

            // Notifications
            settingsCard("Local Notifications", icon: "bell.fill") {
                Toggle("Enable reminders", isOn: Binding(
                    get: { prefs.notificationsEnabled },
                    set: { setNotifications($0) }
                )).toggleStyle(PTToggleStyle())
                HStack {
                    Text("Permission").font(PTFont.callout).foregroundColor(PT.ink)
                    Spacer()
                    StatusChip(text: notifStatus, color: notifStatus == "Authorized" ? PT.success : PT.warning)
                }
                Button {
                    NotificationManager.shared.resyncAll(store.reminders, enabled: prefs.notificationsEnabled)
                    toast = "Reminders re-synced"
                } label: { Label("Re-sync all reminders", systemImage: "arrow.triangle.2.circlepath") }
                    .buttonStyle(SecondaryButtonStyle())
            }

            // Workspace focus
            settingsCard("Workspace focus", icon: "scope") {
                FormRow(label: "Primary scenario") {
                    SegChips(options: AppPreferences.scenarios.map { $0.capitalized },
                             selection: Binding(
                                get: { prefs.primaryScenario.capitalized },
                                set: { prefs.primaryScenario = $0.lowercased() }))
                }
                FormRow(label: "Dashboard metrics") {
                    VStack(spacing: 8) {
                        ForEach(AppPreferences.allMetrics, id: \.self) { m in
                            let on = prefs.selectedMetrics.contains(m)
                            Button { toggleMetric(m) } label: {
                                HStack {
                                    Text(m).font(PTFont.callout).foregroundColor(PT.ink)
                                    Spacer()
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(on ? PT.primary : PT.stroke)
                                }
                                .padding(11).background(PT.subtle).clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }

            // Data
            settingsCard("Data", icon: "externaldrive.fill") {
                dataStat("Groups", store.groups.count)
                dataStat("Care entries", store.careEntries.count)
                dataStat("Costs", store.costs.count)
                dataStat("Photos", store.photoNotes.count)
                Button { showResetAlert = true } label: {
                    Label("Reset to sample data", systemImage: "arrow.counterclockwise")
                }.buttonStyle(SecondaryButtonStyle())
                Button { showClearAlert = true } label: {
                    Label("Clear all data", systemImage: "trash")
                }.buttonStyle(SecondaryButtonStyle(tint: PT.danger))
                Button { onboarded = false } label: {
                    Label("Replay onboarding", systemImage: "sparkles")
                }.buttonStyle(SecondaryButtonStyle(tint: PT.amber))
            }

            // About
            PTCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PT.heroGradient).frame(width: 44, height: 44)
                            Image(systemName: "shippingbox.fill").foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Poultry Transit").font(PTFont.headline).foregroundColor(PT.ink)
                            Text("Version 1.0 · Offline · No account").font(PTFont.caption).foregroundColor(PT.inkSoft)
                        }
                    }
                    Text("All records are stored locally on this device. There is no profile, login or cloud sync.")
                        .font(PTFont.caption).foregroundColor(PT.inkFaint)
                }
            }
        }
        .onAppear(perform: refreshNotifStatus)
        .alert(isPresented: $showResetAlert) {
            Alert(title: Text("Reset sample data?"),
                  message: Text("This replaces all current records with the built-in sample workspace."),
                  primaryButton: .destructive(Text("Reset")) { resetSample() },
                  secondaryButton: .cancel())
        }
        // second alert via overlay trick
        .background(
            EmptyView().alert(isPresented: $showClearAlert) {
                Alert(title: Text("Clear all data?"),
                      message: Text("This permanently deletes every record on this device."),
                      primaryButton: .destructive(Text("Clear")) { clearAll() },
                      secondaryButton: .cancel())
            }
        )
        .toast($toast)
    }

    // MARK: Builders

    private func settingsCard<C: View>(_ title: String, icon: String, @ViewBuilder content: @escaping () -> C) -> some View {
        PTCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: icon).font(PTFont.headline).foregroundColor(PT.ink)
                content()
            }
        }
    }
    private func unitChip(_ label: String, _ value: String, _ binding: Binding<String>) -> some View {
        Button { binding.wrappedValue = value } label: { Text(label) }
            .buttonStyle(ChipButtonStyle(isSelected: binding.wrappedValue == value))
    }
    private func dataStat(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label).font(PTFont.callout).foregroundColor(PT.ink)
            Spacer()
            Text("\(count)").font(PTFont.headline).foregroundColor(PT.inkSoft)
        }
    }

    // MARK: Actions

    private func toggleUnitSystem() {
        let metric = prefs.weightUnit == "kg"
        prefs.weightUnit = metric ? "lb" : "kg"
        prefs.lengthUnit = metric ? "ft" : "m"
        toast = metric ? "Switched to imperial" : "Switched to metric"
    }
    private func toggleMetric(_ m: String) {
        if let i = prefs.selectedMetrics.firstIndex(of: m) {
            if prefs.selectedMetrics.count > 1 { prefs.selectedMetrics.remove(at: i) }
        } else { prefs.selectedMetrics.append(m) }
    }
    private func setNotifications(_ on: Bool) {
        prefs.notificationsEnabled = on
        if on {
            NotificationManager.shared.requestAuthorization { granted in
                refreshNotifStatus()
                if granted {
                    NotificationManager.shared.resyncAll(store.reminders, enabled: true)
                    toast = "Notifications on"
                } else {
                    toast = "Allow notifications in iOS Settings"
                }
            }
        } else {
            NotificationManager.shared.cancelAll()
            toast = "Notifications off"
        }
    }
    private func refreshNotifStatus() {
        NotificationManager.shared.authorizationStatus { status in
            switch status {
            case .authorized, .provisional, .ephemeral: notifStatus = "Authorized"
            case .denied:
                notifStatus = "Denied"
                if prefs.notificationsEnabled { prefs.notificationsEnabled = false }
            default: notifStatus = "Not set"
            }
        }
    }
    private func resetSample() {
        store.resetAll()
        store.loadSampleData()
        NotificationManager.shared.resyncAll(store.reminders, enabled: prefs.notificationsEnabled)
        toast = "Sample data restored"
    }
    private func clearAll() {
        NotificationManager.shared.cancelAll()
        store.resetAll(keepChecklistTemplate: true)
        toast = "All data cleared"
    }
}
