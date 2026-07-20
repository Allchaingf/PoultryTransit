//
//  AppPreferences.swift
//  PoultryTransit
//
//  App-wide preferences (no account). Persists to UserDefaults and drives
//  theme, units, accent and notification behaviour reactively.
//

import SwiftUI
import Combine

enum ThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.fill"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

final class AppPreferences: ObservableObject {

    @Published var theme: ThemeChoice {
        didSet { defaults.set(theme.rawValue, forKey: "pref.theme") }
    }
    @Published var weightUnit: String {        // kg / lb
        didSet { defaults.set(weightUnit, forKey: "pref.weight") }
    }
    @Published var lengthUnit: String {        // m / ft
        didSet { defaults.set(lengthUnit, forKey: "pref.length") }
    }
    @Published var currency: String {
        didSet { defaults.set(currency, forKey: "pref.currency") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "pref.notif") }
    }
    @Published var colorLabelsEnabled: Bool {
        didSet { defaults.set(colorLabelsEnabled, forKey: "pref.colorLabels") }
    }
    @Published var primaryScenario: String {   // planning / inventory / movement / observation
        didSet { defaults.set(primaryScenario, forKey: "pref.scenario") }
    }
    @Published var selectedMetrics: [String] {
        didSet { defaults.set(selectedMetrics, forKey: "pref.metrics") }
    }

    private let defaults = UserDefaults.standard

    init() {
        theme = ThemeChoice(rawValue: defaults.string(forKey: "pref.theme") ?? "system") ?? .system
        weightUnit = defaults.string(forKey: "pref.weight") ?? "kg"
        lengthUnit = defaults.string(forKey: "pref.length") ?? "m"
        currency = defaults.string(forKey: "pref.currency") ?? "$"
        notificationsEnabled = defaults.object(forKey: "pref.notif") as? Bool ?? false
        colorLabelsEnabled = defaults.object(forKey: "pref.colorLabels") as? Bool ?? true
        primaryScenario = defaults.string(forKey: "pref.scenario") ?? "planning"
        selectedMetrics = defaults.stringArray(forKey: "pref.metrics") ?? ["Care activity", "Care consistency", "Cost"]
    }

    static let allMetrics = ["Care activity", "Care consistency", "Cost", "Route time"]
    static let scenarios = ["planning", "inventory", "movement", "observation"]

    // Unit-aware formatting
    func weight(_ kg: Double) -> String {
        if weightUnit == "lb" {
            return String(format: "%.1f lb", kg * 2.2046)
        }
        return "\(FarmStore.num(kg)) kg"
    }
    func length(_ meters: Double) -> String {
        if lengthUnit == "ft" {
            return String(format: "%.1f ft", meters * 3.2808)
        }
        return "\(FarmStore.num(meters)) m"
    }
    func money(_ amount: Double) -> String {
        "\(currency)\(FarmStore.num(amount))"
    }
}
