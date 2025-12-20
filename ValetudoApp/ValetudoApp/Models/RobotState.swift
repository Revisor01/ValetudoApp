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

// MARK: - Speaker Volume
struct SpeakerVolumeResponse: Codable {
    let volume: Int
}

struct SpeakerVolumeRequest: Codable {
    let action: String
    let value: Int

    init(volume: Int) {
        self.action = "set_volume"
        self.value = volume
    }
}

// MARK: - Carpet Mode / Persistent Map
struct EnabledResponse: Codable {
    let enabled: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // API returns 1/0 as Int, handle both Bool and Int
        if let boolValue = try? container.decode(Bool.self, forKey: .enabled) {
            enabled = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .enabled) {
            enabled = intValue != 0
        } else {
            enabled = false
        }
    }

    enum CodingKeys: String, CodingKey {
        case enabled
    }
}

struct ActionRequest: Codable {
    let action: String
}

struct ModeResponse: Codable {
    let mode: String
}

struct ModeRequest: Codable {
    let mode: String
}

// MARK: - Segment Rename
struct SegmentRenameRequest: Codable {
    let action: String
    let segment_id: String
    let name: String

    init(segmentId: String, name: String) {
        self.action = "rename_segment"
        self.segment_id = segmentId
        self.name = name
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

// MARK: - Zone Cleaning
struct ZonePoint: Codable, Equatable {
    var x: Int
    var y: Int
}

struct ZonePoints: Codable, Equatable {
    var pA: ZonePoint
    var pB: ZonePoint
    var pC: ZonePoint
    var pD: ZonePoint
}

struct CleaningZone: Codable, Identifiable, Equatable {
    var id = UUID()
    var points: ZonePoints
    var iterations: Int

    enum CodingKeys: String, CodingKey {
        case points, iterations
    }

    init(points: ZonePoints, iterations: Int = 1) {
        self.points = points
        self.iterations = iterations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.points = try container.decode(ZonePoints.self, forKey: .points)
        self.iterations = try container.decodeIfPresent(Int.self, forKey: .iterations) ?? 1
    }
}

struct ZoneCleanRequest: Codable {
    let action: String
    let zones: [CleaningZoneRequest]

    init(zones: [CleaningZone]) {
        self.action = "clean"
        self.zones = zones.map { CleaningZoneRequest(points: $0.points, iterations: $0.iterations) }
    }
}

struct CleaningZoneRequest: Codable {
    let points: ZonePoints
    let iterations: Int
}

// MARK: - Virtual Restrictions
struct VirtualWallPoints: Codable, Equatable {
    var pA: ZonePoint
    var pB: ZonePoint
}

struct VirtualWall: Codable, Identifiable, Equatable {
    var id = UUID()
    var points: VirtualWallPoints

    enum CodingKeys: String, CodingKey {
        case points
    }

    init(points: VirtualWallPoints) {
        self.points = points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.points = try container.decode(VirtualWallPoints.self, forKey: .points)
    }
}

struct NoGoArea: Codable, Identifiable, Equatable {
    var id = UUID()
    var points: ZonePoints

    enum CodingKeys: String, CodingKey {
        case points
    }

    init(points: ZonePoints) {
        self.points = points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.points = try container.decode(ZonePoints.self, forKey: .points)
    }
}

struct NoMopArea: Codable, Identifiable, Equatable {
    var id = UUID()
    var points: ZonePoints

    enum CodingKeys: String, CodingKey {
        case points
    }

    init(points: ZonePoints) {
        self.points = points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.points = try container.decode(ZonePoints.self, forKey: .points)
    }
}

struct VirtualRestrictions: Codable {
    var virtualWalls: [VirtualWall]
    var restrictedZones: [NoGoArea]
    var noMopZones: [NoMopArea]

    init(virtualWalls: [VirtualWall] = [], restrictedZones: [NoGoArea] = [], noMopZones: [NoMopArea] = []) {
        self.virtualWalls = virtualWalls
        self.restrictedZones = restrictedZones
        self.noMopZones = noMopZones
    }

    // Custom decoder to handle missing optional fields from API
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.virtualWalls = try container.decodeIfPresent([VirtualWall].self, forKey: .virtualWalls) ?? []
        self.restrictedZones = try container.decodeIfPresent([NoGoArea].self, forKey: .restrictedZones) ?? []
        self.noMopZones = try container.decodeIfPresent([NoMopArea].self, forKey: .noMopZones) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case virtualWalls
        case restrictedZones
        case noMopZones
    }
}

struct VirtualRestrictionsRequest: Codable {
    let virtualWalls: [VirtualWallRequest]
    let restrictedZones: [RestrictedZoneRequest]

    init(restrictions: VirtualRestrictions) {
        self.virtualWalls = restrictions.virtualWalls.map { VirtualWallRequest(points: $0.points) }
        // Combine noGo and noMop zones with their types
        var zones: [RestrictedZoneRequest] = restrictions.restrictedZones.map {
            RestrictedZoneRequest(points: $0.points, type: "regular")
        }
        zones.append(contentsOf: restrictions.noMopZones.map {
            RestrictedZoneRequest(points: $0.points, type: "mop")
        })
        self.restrictedZones = zones
    }
}

struct VirtualWallRequest: Codable {
    let points: VirtualWallPoints
}

struct RestrictedZoneRequest: Codable {
    let points: ZonePoints
    let type: String
}

// MARK: - Map Segment Edit
struct JoinSegmentsRequest: Codable {
    let action: String
    let segment_a_id: String
    let segment_b_id: String

    init(segmentAId: String, segmentBId: String) {
        self.action = "join_segments"
        self.segment_a_id = segmentAId
        self.segment_b_id = segmentBId
    }
}

struct SplitSegmentRequest: Codable {
    let action: String
    let segment_id: String
    let pA: ZonePoint
    let pB: ZonePoint

    init(segmentId: String, pointA: ZonePoint, pointB: ZonePoint) {
        self.action = "split_segment"
        self.segment_id = segmentId
        self.pA = pointA
        self.pB = pointB
    }
}

// MARK: - Manual Control
struct ManualControlRequest: Codable {
    let action: String
    let movementSpeed: Int?
    let angle: Int?
    let duration: Int?

    enum CodingKeys: String, CodingKey {
        case action
        case movementSpeed = "movement_speed"
        case angle
        case duration
    }
}

// MARK: - Quirks
struct Quirk: Codable, Identifiable {
    let id: String
    let options: [String]
    let title: String
    let description: String
    let value: String
}

struct QuirkSetRequest: Codable {
    let id: String
    let value: String
}

// MARK: - WiFi
struct WifiStatus: Codable {
    let state: String
    let details: WifiDetails?

    struct WifiDetails: Codable {
        let bssid: String?
        let ssid: String?
        let signal: Int?
        let upspeed: Double?
        let frequency: String?
        let ips: [String]?
    }
}

struct WifiNetwork: Codable, Identifiable {
    let bssid: String
    let details: NetworkDetails

    var id: String { bssid }

    struct NetworkDetails: Codable {
        let signal: Int
        let ssid: String
    }

    var signalStrength: String {
        if details.signal > -50 { return "Excellent" }
        if details.signal > -60 { return "Good" }
        if details.signal > -70 { return "Fair" }
        return "Weak"
    }

    var signalIcon: String {
        if details.signal > -50 { return "wifi" }
        if details.signal > -60 { return "wifi" }
        if details.signal > -70 { return "wifi.exclamationmark" }
        return "wifi.slash"
    }
}

struct WifiConfigRequest: Codable {
    let ssid: String
    let credentials: WifiCredentials

    struct WifiCredentials: Codable {
        let type: String
        let typeSpecificSettings: TypeSettings

        struct TypeSettings: Codable {
            let password: String
        }

        init(password: String) {
            self.type = "wpa2_psk"
            self.typeSpecificSettings = TypeSettings(password: password)
        }
    }

    init(ssid: String, password: String) {
        self.ssid = ssid
        self.credentials = WifiCredentials(password: password)
    }
}

// MARK: - MQTT
struct MQTTConfig: Codable {
    var enabled: Bool
    var connection: MQTTConnection
    var identity: MQTTIdentity
    var interfaces: MQTTInterfaces
    var customizations: MQTTCustomizations

    struct MQTTConnection: Codable {
        var host: String
        var port: Int
        var tls: TLSConfig
        var authentication: AuthConfig

        struct TLSConfig: Codable {
            var enabled: Bool
            var ca: String
            var ignoreCertificateErrors: Bool
        }

        struct AuthConfig: Codable {
            var credentials: CredentialsConfig

            struct CredentialsConfig: Codable {
                var enabled: Bool
                var username: String
                var password: String
            }
        }
    }

    struct MQTTIdentity: Codable {
        var identifier: String
    }

    struct MQTTInterfaces: Codable {
        var homie: HomieConfig
        var homeassistant: HomeAssistantConfig

        struct HomieConfig: Codable {
            var enabled: Bool
            var cleanAttributesOnShutdown: Bool
        }

        struct HomeAssistantConfig: Codable {
            var enabled: Bool
            var cleanAutoconfOnShutdown: Bool
        }
    }

    struct MQTTCustomizations: Codable {
        var topicPrefix: String
        var provideMapData: Bool
    }
}

// MARK: - NTP
struct NTPConfig: Codable {
    var enabled: Bool
    var server: String
    var port: Int
    var interval: Int
    var timeout: Int
}

struct NTPStatus: Codable {
    let state: NTPState?
    let robotTime: String?

    struct NTPState: Codable {
        let timestamp: String?
        let offset: Int?
    }
}

// MARK: - Valetudo Info
struct ValetudoVersion: Codable {
    let release: String
    let commit: String
}

struct SystemHostInfo: Codable {
    let hostname: String
    let arch: String
    let mem: MemInfo
    let uptime: Double
    let load: LoadInfo?

    struct MemInfo: Codable {
        let total: Int
        let free: Int
        let valetudo_current: Int
        let valetudo_max: Int
    }

    struct LoadInfo: Codable {
        let _1: Double
        let _5: Double
        let _15: Double

        enum CodingKeys: String, CodingKey {
            case _1 = "1"
            case _5 = "5"
            case _15 = "15"
        }
    }
}

// MARK: - Updater
struct UpdaterState: Codable {
    let `__class`: String?
    let busy: Bool?
    let currentVersion: String?
    let version: String?
    let releaseTimestamp: String?
    let downloadUrl: String?
    let downloadPath: String?
    let metaData: UpdaterMetaData?

    struct UpdaterMetaData: Codable {
        let progress: UpdateProgress?

        struct UpdateProgress: Codable {
            let current: Int?
            let total: Int?
        }
    }

    var stateType: String {
        `__class` ?? "unknown"
    }

    var isUpdateAvailable: Bool {
        stateType == "ValetudoUpdaterApprovalPendingState"
    }

    var isDownloading: Bool {
        stateType == "ValetudoUpdaterDownloadingState"
    }

    var isReadyToApply: Bool {
        stateType == "ValetudoUpdaterApplyPendingState"
    }

    var isIdle: Bool {
        stateType == "ValetudoUpdaterIdleState"
    }
}

struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String
    let published_at: String
    let body: String?
}

// MARK: - GoTo Presets
struct GoToPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var x: Int
    var y: Int
    var robotId: UUID

    init(id: UUID = UUID(), name: String, x: Int, y: Int, robotId: UUID) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.robotId = robotId
    }
}

@MainActor
class GoToPresetStore: ObservableObject {
    @Published var presets: [GoToPreset] = []

    private let saveKey = "goToPresets"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        if let decoded = try? JSONDecoder().decode([GoToPreset].self, from: data) {
            presets = decoded
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    func addPreset(_ preset: GoToPreset) {
        presets.append(preset)
        save()
    }

    func deletePreset(_ preset: GoToPreset) {
        presets.removeAll { $0.id == preset.id }
        save()
    }

    func updatePreset(_ preset: GoToPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            save()
        }
    }

    func presets(for robotId: UUID) -> [GoToPreset] {
        presets.filter { $0.robotId == robotId }
    }
}

