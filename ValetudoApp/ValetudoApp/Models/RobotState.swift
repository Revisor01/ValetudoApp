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
