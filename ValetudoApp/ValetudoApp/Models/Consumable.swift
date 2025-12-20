import Foundation
import SwiftUI

struct Consumable: Codable, Identifiable {
    let `__class`: String?
    let type: String
    let subType: String?
    let remaining: ConsumableRemaining

    var id: String { "\(type)_\(subType ?? "main")" }

    enum CodingKeys: String, CodingKey {
        case `__class`, type, subType, remaining
    }
}

struct ConsumableRemaining: Codable {
    let value: Int
    let unit: String
}

// MARK: - Display Helpers
extension Consumable {
    var displayName: String {
        let base = type.localizedConsumableType
        if let sub = subType, sub != "main" && sub != "none" {
            return "\(base) (\(sub.localizedConsumableSubType))"
        }
        return base
    }

    var icon: String {
        switch type {
        case "brush": return "hurricane"
        case "filter": return "air.purifier"
        case "sensor", "cleaning": return "sensor"
        case "mop": return "drop.fill"
        case "bin": return "trash"
        default: return "wrench.and.screwdriver"
        }
    }

    var iconColor: Color {
        let percent = remainingPercent
        if percent > 50 { return .green }
        if percent > 20 { return .orange }
        return .red
    }

    var remainingPercent: Double {
        if remaining.unit == "percent" {
            return Double(remaining.value)
        }
        // Max values based on type and subType (Valetudo default reset values)
        let maxMinutes: Double
        switch (type, subType) {
        case ("brush", "main"): maxMinutes = 18000      // 300h main brush
        case ("brush", _): maxMinutes = 12000           // 200h side brush
        case ("filter", _): maxMinutes = 9000           // 150h filter
        case ("cleaning", "sensor"), ("sensor", _): maxMinutes = 1800  // 30h sensor
        case ("mop", _): maxMinutes = 12000             // 200h mop
        default: maxMinutes = 9000
        }
        return min(100, Double(remaining.value) / maxMinutes * 100)
    }

    var remainingDisplay: String {
        if remaining.unit == "percent" {
            return "\(remaining.value)%"
        }
        let hours = remaining.value / 60
        return "\(hours)h"
    }
}

// MARK: - Localization Extensions
extension String {
    var localizedConsumableType: String {
        switch self {
        case "brush": return String(localized: "consumable.brush")
        case "filter": return String(localized: "consumable.filter")
        case "sensor": return String(localized: "consumable.sensor")
        case "cleaning": return String(localized: "consumable.sensor")
        case "mop": return String(localized: "consumable.mop")
        case "bin": return String(localized: "consumable.bin")
        default: return self.capitalized
        }
    }

    var localizedConsumableSubType: String {
        switch self {
        case "main": return String(localized: "consumable.main")
        case "side_right": return String(localized: "consumable.side_right")
        case "side_left": return String(localized: "consumable.side_left")
        case "hepa": return "HEPA"
        default: return self.capitalized
        }
    }
}
