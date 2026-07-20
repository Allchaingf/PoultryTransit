//
//  Models.swift
//  PoultryTransit
//
//  All Codable data structures + enums for the offline farm workspace.
//

import SwiftUI

// MARK: - Shared enums

enum Severity: String, Codable, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .low: return PT.info
        case .medium: return PT.warning
        case .high: return PT.danger
        }
    }
    var weight: Int { self == .high ? 3 : (self == .medium ? 2 : 1) }
}

enum Rating: String, Codable, CaseIterable, Identifiable {
    case good, fair, poor
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .good: return PT.success
        case .fair: return PT.warning
        case .poor: return PT.danger
        }
    }
}

// MARK: - Bird group

struct BirdGroup: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: String          // Layers, Broilers, Chicks, Ducks, Mixed...
    var count: Int
    var zoneID: UUID?
    var colorHex: String
    var createdAt: Date = Date()

    var color: Color { Color(hex: colorHex) }
    static let kinds = ["Layers", "Broilers", "Chicks", "Pullets", "Ducks", "Turkeys", "Mixed"]
    static let palette = ["3E8E7E", "F2A93B", "C76B4A", "4F86C6", "8E6FB3", "5BBF8A", "D9594C"]
}

// MARK: - Zone

struct Zone: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: String          // Coop, Yard, Run, Quarantine, Transport Point
    var order: Int
    var areaSqM: Double
    var perchLengthM: Double
    var note: String = ""

    static let kinds = ["Coop", "Yard", "Run", "Brooder", "Quarantine", "Transport Point"]
    var icon: String {
        switch kind {
        case "Coop": return "house.fill"
        case "Yard": return "leaf.fill"
        case "Run": return "figure.walk"
        case "Brooder": return "thermometer"
        case "Quarantine": return "cross.case.fill"
        case "Transport Point": return "shippingbox.fill"
        default: return "square.dashed"
        }
    }
}

// MARK: - Feed portion

struct FeedPortion: Identifiable, Codable, Hashable {
    var id = UUID()
    var groupID: UUID?
    var gramsPerBird: Double
    var feedsPerDay: Int
    var feedItemID: UUID?      // links to inventory feed item
    var date: Date = Date()
    var note: String = ""
}

// MARK: - Water & heat check

struct WaterCheck: Identifiable, Codable, Hashable {
    var id = UUID()
    var zoneID: UUID?
    var date: Date = Date()
    var waterOK: Bool
    var temperatureC: Double
    var ventilationOK: Bool
    var drinkersClean: Bool
    var note: String = ""
}

// MARK: - Health observation

struct Observation: Identifiable, Codable, Hashable {
    var id = UUID()
    var groupID: UUID?
    var date: Date = Date()
    var activity: Rating
    var appetite: Rating
    var appearance: Rating
    var symptom: String = ""
    var flagged: Bool = false
    var note: String = ""
}

// MARK: - Cleaning task

struct CleaningTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var zoneID: UUID?
    var type: String          // Litter, Sanitation, Full clean
    var dueDate: Date
    var isDone: Bool = false
    var completedDate: Date?

    static let types = ["Litter change", "Sanitation", "Full clean", "Disinfect drinkers"]
    var isOverdue: Bool { !isDone && dueDate < Calendar.current.startOfDay(for: Date()) }
}

// MARK: - Route

struct CareRoute: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var stopZoneIDs: [UUID]
    var minutesPerStop: Int
    var createdAt: Date = Date()
    var lastRunAt: Date?

    var estimatedMinutes: Int { stopZoneIDs.count * minutesPerStop }
}

/// A recorded pass through a route — measures real elapsed time and how many
/// checkpoints were actually completed (full vs. partial run).
struct RouteRun: Identifiable, Codable, Hashable {
    var id = UUID()
    var routeID: UUID
    var routeName: String
    var startedAt: Date
    var finishedAt: Date
    var completedStops: Int
    var totalStops: Int
    var partial: Bool

    var elapsedSeconds: Int { max(0, Int(finishedAt.timeIntervalSince(startedAt))) }
    /// Actual minutes, rounded to the nearest minute (never negative).
    var actualMinutes: Int { Int((Double(elapsedSeconds) / 60.0).rounded()) }
    /// Compact human duration, e.g. "0:48" or "12:05".
    var durationText: String {
        let m = elapsedSeconds / 60, s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Transport

struct Crate: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var birdCount: Int
    var hasWater: Bool
    var groupID: UUID?
}

struct TransportLoad: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var departure: Date
    var crates: [Crate]
    var stops: [String]
    var confirmed: Bool = false
    var note: String = ""

    var totalBirds: Int { crates.reduce(0) { $0 + $1.birdCount } }
    var crateCount: Int { crates.count }
    var watered: Int { crates.filter { $0.hasWater }.count }
}

// MARK: - Inventory

struct InventoryItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var category: String      // Feed, Litter, Supplement, Hardware, Drinker
    var quantity: Double
    var unit: String
    var minLevel: Double
    var updatedAt: Date = Date()

    static let categories = ["Feed", "Litter", "Supplement", "Hardware", "Drinker"]
    var isLow: Bool { quantity <= minLevel }
    func categoryIcon() -> String {
        switch category {
        case "Feed": return "leaf.fill"
        case "Litter": return "square.stack.3d.up.fill"
        case "Supplement": return "pills.fill"
        case "Hardware": return "wrench.and.screwdriver.fill"
        case "Drinker": return "drop.fill"
        default: return "shippingbox.fill"
        }
    }
}

// MARK: - Cost

struct Cost: Identifiable, Codable, Hashable {
    var id = UUID()
    var category: String      // Feed, Health, Equipment, Transport, Other
    var amount: Double
    var date: Date = Date()
    var groupID: UUID?
    var note: String = ""

    static let categories = ["Feed", "Health", "Equipment", "Transport", "Other"]
}

// MARK: - Task

struct FarmTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var priority: Severity
    var dueDate: Date?
    var zoneID: UUID?
    var isDone: Bool = false
    var createdAt: Date = Date()

    var isOverdue: Bool {
        guard let d = dueDate, !isDone else { return false }
        return d < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Reminder

struct Reminder: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var time: Date
    var kind: String          // Morning, Evening, Transport, Cleaning, Custom
    var isEnabled: Bool = true

    static let kinds = ["Morning", "Evening", "Transport", "Cleaning", "Custom"]
    var notifID: String { "reminder-\(id.uuidString)" }
    func icon() -> String {
        switch kind {
        case "Morning": return "sun.max.fill"
        case "Evening": return "moon.stars.fill"
        case "Transport": return "shippingbox.fill"
        case "Cleaning": return "sparkles"
        default: return "bell.fill"
        }
    }
}

// MARK: - Note

struct FarmNote: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var body: String
    var zoneID: UUID?
    var groupID: UUID?
    var tag: String
    var date: Date = Date()

    static let tags = ["General", "Repair", "Health", "Feed", "Transport", "Idea"]
}

// MARK: - Photo note

struct PhotoNote: Identifiable, Codable, Hashable {
    var id = UUID()
    var imageData: Data?
    var caption: String
    var markerX: Double       // 0...1 relative position
    var markerY: Double
    var hasMarker: Bool
    var date: Date = Date()
}

// MARK: - Risk flag (manual + derived)

struct RiskFlag: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var severity: Severity
    var source: String        // Overdue, Low stock, Overload, Observation, Manual
    var isResolved: Bool = false
    var date: Date = Date()
}

// MARK: - Daily review

struct DailyReviewRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var completedCount: Int
    var missedCount: Int
    var note: String = ""
}

// MARK: - Care entry (the central journal / quick add)

struct CareEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var type: String          // Feeding, Water, Cleaning, Move, Observation, Note
    var date: Date = Date()
    var groupID: UUID?
    var zoneID: UUID?
    var note: String = ""

    static let types = ["Feeding", "Water", "Cleaning", "Move", "Observation", "Note"]
    func icon() -> String {
        switch type {
        case "Feeding": return "leaf.fill"
        case "Water": return "drop.fill"
        case "Cleaning": return "sparkles"
        case "Move": return "arrow.left.arrow.right"
        case "Observation": return "eye.fill"
        default: return "note.text"
        }
    }
    var tint: Color {
        switch type {
        case "Feeding": return PT.amber
        case "Water": return PT.info
        case "Cleaning": return PT.primary
        case "Move": return PT.clay
        case "Observation": return Color(hex: "8E6FB3")
        default: return PT.neutral
        }
    }
}

// MARK: - Daily checklist

struct ChecklistItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var period: String        // Morning, Evening
    var icon: String
}

struct ChecklistDay: Identifiable, Codable, Hashable {
    var id = UUID()
    var dayKey: String        // yyyy-MM-dd
    var doneItemIDs: [UUID]
    var skippedToday: Bool = false
}

// MARK: - Capacity result

struct CapacityResult: Identifiable, Codable, Hashable {
    var id = UUID()
    var zoneName: String
    var areaSqM: Double
    var perchLengthM: Double
    var birdCount: Int
    var birdsPerSqM: Double
    var perchPerBirdCM: Double
    var status: String        // Comfortable, Near limit, Overloaded
    var date: Date = Date()

    var statusColor: Color {
        switch status {
        case "Comfortable": return PT.success
        case "Near limit": return PT.warning
        default: return PT.danger
        }
    }
}
