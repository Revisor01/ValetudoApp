import AppIntents
import SwiftUI

// MARK: - Robot Entity for Siri
struct RobotEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Roboter", table: "AppIntents")
    )
    static var defaultQuery = RobotQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct RobotQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [RobotEntity] {
        let robots = await loadRobots()
        return robots.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [RobotEntity] {
        await loadRobots()
    }

    private func loadRobots() async -> [RobotEntity] {
        guard let data = UserDefaults.standard.data(forKey: "valetudo_robots"),
              let configs = try? JSONDecoder().decode([RobotConfig].self, from: data) else {
            return []
        }
        return configs.map { RobotEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Room Entity for Siri
struct RoomEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Raum", table: "AppIntents")
    )
    static var defaultQuery = RoomQuery()

    var id: String
    var name: String
    var robotId: UUID

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct RoomQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [RoomEntity] {
        let rooms = await loadAllRooms()
        return rooms.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [RoomEntity] {
        await loadAllRooms()
    }

    private func loadAllRooms() async -> [RoomEntity] {
        guard let data = UserDefaults.standard.data(forKey: "valetudo_robots"),
              let configs = try? JSONDecoder().decode([RobotConfig].self, from: data) else {
            return []
        }

        var allRooms: [RoomEntity] = []
        for config in configs {
            let api = ValetudoAPI(config: config)
            if let segments = try? await api.getSegments() {
                for segment in segments {
                    allRooms.append(RoomEntity(
                        id: segment.id,
                        name: segment.name ?? "Room \(segment.id)",
                        robotId: config.id
                    ))
                }
            }
        }
        return allRooms
    }
}

// MARK: - Special Location Entity for Siri (uses local GoToPresets)
struct LocationEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Ort", table: "AppIntents")
    )
    static var defaultQuery = LocationQuery()

    var id: UUID
    var name: String
    var x: Int
    var y: Int
    var robotId: UUID

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct LocationQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [LocationEntity] {
        let locations = loadAllLocations()
        return locations.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LocationEntity] {
        loadAllLocations()
    }

    private func loadAllLocations() -> [LocationEntity] {
        guard let data = UserDefaults.standard.data(forKey: "goToPresets"),
              let presets = try? JSONDecoder().decode([GoToPreset].self, from: data) else {
            return []
        }

        return presets.map { preset in
            LocationEntity(
                id: preset.id,
                name: preset.name,
                x: preset.x,
                y: preset.y,
                robotId: preset.robotId
            )
        }
    }
}

// MARK: - Start Robot Intent
struct StartRobotIntent: AppIntent {
    static var title: LocalizedStringResource = "Roboter starten"
    static var description = IntentDescription("Startet den Saugroboter")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Roboter")
    var robot: RobotEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let config = getConfig(for: robot.id) else {
            return .result(dialog: "Roboter nicht gefunden")
        }

        let api = ValetudoAPI(config: config)
        try await api.basicControl(action: .start)
        return .result(dialog: "\(robot.name) startet die Reinigung")
    }
}

// MARK: - Stop Robot Intent
struct StopRobotIntent: AppIntent {
    static var title: LocalizedStringResource = "Roboter stoppen"
    static var description = IntentDescription("Stoppt den Saugroboter")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Roboter")
    var robot: RobotEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let config = getConfig(for: robot.id) else {
            return .result(dialog: "Roboter nicht gefunden")
        }

        let api = ValetudoAPI(config: config)
        try await api.basicControl(action: .stop)
        return .result(dialog: "\(robot.name) gestoppt")
    }
}

// MARK: - Pause Robot Intent
struct PauseRobotIntent: AppIntent {
    static var title: LocalizedStringResource = "Roboter pausieren"
    static var description = IntentDescription("Pausiert den Saugroboter")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Roboter")
    var robot: RobotEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let config = getConfig(for: robot.id) else {
            return .result(dialog: "Roboter nicht gefunden")
        }

        let api = ValetudoAPI(config: config)
        try await api.basicControl(action: .pause)
        return .result(dialog: "\(robot.name) pausiert")
    }
}

// MARK: - Send Robot Home Intent
struct SendRobotHomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Roboter nach Hause schicken"
    static var description = IntentDescription("Schickt den Saugroboter zur Ladestation")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Roboter")
    var robot: RobotEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let config = getConfig(for: robot.id) else {
            return .result(dialog: "Roboter nicht gefunden")
        }

        let api = ValetudoAPI(config: config)
        try await api.basicControl(action: .home)
        return .result(dialog: "\(robot.name) fährt nach Hause")
    }
}

// MARK: - Clean Rooms Intent
struct CleanRoomsIntent: AppIntent {
    static var title: LocalizedStringResource = "Räume reinigen"
    static var description = IntentDescription("Reinigt bestimmte Räume")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Roboter")
    var robot: RobotEntity

    @Parameter(title: "Räume")
    var rooms: [RoomEntity]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let config = getConfig(for: robot.id) else {
            return .result(dialog: "Roboter nicht gefunden")
        }

        let api = ValetudoAPI(config: config)
        let segmentIds = rooms.map { $0.id }
        try await api.cleanSegments(ids: segmentIds)

        let roomNames = rooms.map { $0.name }.joined(separator: ", ")
        return .result(dialog: "\(robot.name) reinigt \(roomNames)")
    }
}

// MARK: - Go To Location Intent
struct GoToLocationIntent: AppIntent {
    static var title: LocalizedStringResource = "Zu Ort fahren"
    static var description = IntentDescription("Schickt den Roboter zu einem bestimmten Ort")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Roboter")
    var robot: RobotEntity

    @Parameter(title: "Ort")
    var location: LocationEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let config = getConfig(for: robot.id) else {
            return .result(dialog: "Roboter nicht gefunden")
        }

        let api = ValetudoAPI(config: config)
        try await api.goTo(x: location.x, y: location.y)
        return .result(dialog: "\(robot.name) fährt zu \(location.name)")
    }
}

// MARK: - Helper Functions
private func getConfig(for robotId: UUID) -> RobotConfig? {
    guard let data = UserDefaults.standard.data(forKey: "valetudo_robots"),
          let configs = try? JSONDecoder().decode([RobotConfig].self, from: data) else {
        return nil
    }
    return configs.first { $0.id == robotId }
}

// MARK: - App Shortcuts Provider
struct RobotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRobotIntent(),
            phrases: [
                "Start \(\.$robot) with \(.applicationName)",
                "Starte \(\.$robot) mit \(.applicationName)"
            ],
            shortTitle: "Start Robot",
            systemImageName: "play.fill"
        )

        AppShortcut(
            intent: StopRobotIntent(),
            phrases: [
                "Stop \(\.$robot) with \(.applicationName)",
                "Stoppe \(\.$robot) mit \(.applicationName)"
            ],
            shortTitle: "Stop Robot",
            systemImageName: "stop.fill"
        )

        AppShortcut(
            intent: PauseRobotIntent(),
            phrases: [
                "Pause \(\.$robot) with \(.applicationName)",
                "Pausiere \(\.$robot) mit \(.applicationName)"
            ],
            shortTitle: "Pause Robot",
            systemImageName: "pause.fill"
        )

        AppShortcut(
            intent: SendRobotHomeIntent(),
            phrases: [
                "Send \(\.$robot) home with \(.applicationName)",
                "Schick \(\.$robot) nach Hause mit \(.applicationName)"
            ],
            shortTitle: "Send Home",
            systemImageName: "house.fill"
        )
    }
}
