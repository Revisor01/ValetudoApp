import Foundation

// MARK: - Robot Info
struct RobotInfo: Codable {
    let manufacturer: String?
    let modelName: String?
    let implementation: String?
}

// MARK: - Robot State
struct RobotStateResponse: Codable {
    let attributes: [RobotAttribute]
    let map: RobotMap?
}

// MARK: - Attributes
struct RobotAttribute: Codable {
    let `__class`: String
    let type: String?
    let subType: String?
    let value: String?
    let level: Int?
    let flag: String?

    enum CodingKeys: String, CodingKey {
        case `__class`
        case type, subType, value, level, flag
    }
}

enum StatusValue: String {
    case idle, cleaning, paused, returning, docked, error
    case charging, discharging, charged, none

    var localizationKey: String {
        switch self {
        case .idle: return "status.idle"
        case .cleaning: return "status.cleaning"
        case .paused: return "status.paused"
        case .returning: return "status.returning"
        case .docked: return "status.docked"
        case .charging: return "status.charging"
        case .error: return "status.error"
        default: return "status.idle"
        }
    }
}

// MARK: - Capabilities
typealias Capabilities = [String]

// MARK: - Segments (Rooms)
struct Segment: Codable, Identifiable, Hashable {
    let id: String
    let name: String?

    var displayName: String {
        name ?? "Room \(id)"
    }
}

// MARK: - Control Actions
enum BasicAction: String, Codable {
    case start, stop, pause, home
}

struct BasicControlRequest: Codable {
    let action: String
}

struct SegmentCleanRequest: Codable {
    let action: String
    let segment_ids: [String]
    let iterations: Int

    init(segmentIds: [String], iterations: Int = 1) {
        self.action = "start_segment_action"
        self.segment_ids = segmentIds
        self.iterations = iterations
    }
}

struct GoToRequest: Codable {
    let action: String
    let coordinates: Coordinate

    init(x: Int, y: Int) {
        self.action = "goto"
        self.coordinates = Coordinate(x: x, y: y)
    }
}

struct Coordinate: Codable {
    let x: Int
    let y: Int
}

// MARK: - Preset Control (Fan Speed / Water Usage)
struct PresetControlRequest: Codable {
    let name: String
}

enum FanSpeedPreset: String, CaseIterable, Identifiable {
    case off, min, low, medium, high, max, turbo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return String(localized: "fanspeed.off")
        case .min: return String(localized: "fanspeed.min")
        case .low: return String(localized: "fanspeed.low")
        case .medium: return String(localized: "fanspeed.medium")
        case .high: return String(localized: "fanspeed.high")
        case .max: return String(localized: "fanspeed.max")
        case .turbo: return String(localized: "fanspeed.turbo")
        }
    }

    var icon: String {
        switch self {
        case .off: return "fan.slash"
        case .min, .low: return "fan"
        case .medium: return "fan"
        case .high, .max, .turbo: return "fan.fill"
        }
    }
}

enum WaterUsagePreset: String, CaseIterable, Identifiable {
    case off, min, low, medium, high, max

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return String(localized: "water.off")
        case .min: return String(localized: "water.min")
        case .low: return String(localized: "water.low")
        case .medium: return String(localized: "water.medium")
        case .high: return String(localized: "water.high")
        case .max: return String(localized: "water.max")
        }
    }

    var icon: String {
        switch self {
        case .off: return "drop.slash"
        case .min, .low: return "drop"
        case .medium: return "drop.fill"
        case .high, .max: return "drop.circle.fill"
        }
    }
}

// MARK: - Do Not Disturb
struct DoNotDisturbConfig: Codable {
    var enabled: Bool
    var start: TimeValue
    var end: TimeValue

    struct TimeValue: Codable {
        var hour: Int
        var minute: Int

        var asDate: Date {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            return Calendar.current.date(from: components) ?? Date()
        }

        static func from(date: Date) -> TimeValue {
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            return TimeValue(hour: components.hour ?? 0, minute: components.minute ?? 0)
        }

        var formatted: String {
            String(format: "%02d:%02d", hour, minute)
        }
    }
}

// MARK: - Statistics
struct StatisticEntry: Codable, Identifiable {
    let type: String
    let value: Double
    let timestamp: String?

    var id: String { type }

    enum StatType: String {
        case time, area, count
    }

    var statType: StatType? {
        StatType(rawValue: type)
    }

    /// Time in seconds converted to formatted string
    var formattedTime: String {
        let totalSeconds = Int(value)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    /// Area in cm² converted to m²
    var formattedArea: String {
        let squareMeters = value / 10000.0
        return String(format: "%.1f m²", squareMeters)
    }

    /// Count as integer
    var formattedCount: String {
        return String(Int(value))
    }
}
