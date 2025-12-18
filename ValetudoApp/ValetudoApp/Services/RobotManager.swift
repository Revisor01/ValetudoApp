import Foundation
import SwiftUI

@MainActor
class RobotManager: ObservableObject {
    @Published var robots: [RobotConfig] = []
    @Published var robotStates: [UUID: RobotStatus] = [:]

    private var apis: [UUID: ValetudoAPI] = [:]
    private var refreshTask: Task<Void, Never>?
    private var previousStates: [UUID: RobotStatus] = [:]
    private let storageKey = "valetudo_robots"
    private let notificationService = NotificationService.shared

    init() {
        loadRobots()
        startRefreshing()
        notificationService.setupCategories()

        // Request notification permission
        Task {
            await notificationService.requestAuthorization()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Robot Management
    func addRobot(_ config: RobotConfig) {
        robots.append(config)
        apis[config.id] = ValetudoAPI(config: config)
        saveRobots()
        Task { await refreshRobot(config.id) }
    }

    func updateRobot(_ config: RobotConfig) {
        if let index = robots.firstIndex(where: { $0.id == config.id }) {
            robots[index] = config
            apis[config.id] = ValetudoAPI(config: config)
            saveRobots()
            Task { await refreshRobot(config.id) }
        }
    }

    func removeRobot(_ id: UUID) {
        robots.removeAll { $0.id == id }
        apis.removeValue(forKey: id)
        robotStates.removeValue(forKey: id)
        previousStates.removeValue(forKey: id)
        saveRobots()
    }

    func getAPI(for id: UUID) -> ValetudoAPI? {
        print("🤖 getAPI called for id: \(id)")
        print("🤖 Available APIs: \(apis.keys.map { $0.uuidString })")
        print("🤖 Available robots: \(robots.map { "\($0.name): \($0.id)" })")
        return apis[id]
    }

    func getRobotName(for id: UUID) -> String {
        robots.first { $0.id == id }?.name ?? "Robot"
    }

    // MARK: - Status Refresh
    private func startRefreshing() {
        refreshTask = Task {
            while !Task.isCancelled {
                await refreshAllRobots()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func refreshAllRobots() async {
        await withTaskGroup(of: Void.self) { group in
            for robot in robots {
                group.addTask { await self.refreshRobot(robot.id) }
            }
        }
    }

    func refreshRobot(_ id: UUID) async {
        guard let api = apis[id] else { return }
        let robotName = getRobotName(for: id)
        let previousState = previousStates[id]

        let isOnline = await api.checkConnection()

        if isOnline {
            do {
                let attributes = try await api.getAttributes()
                let info = try await api.getRobotInfo()

                let newStatus = RobotStatus(
                    isOnline: true,
                    attributes: attributes,
                    info: info
                )

                // Check for state changes and send notifications
                checkStateChanges(robotName: robotName, previous: previousState, current: newStatus)

                await MainActor.run {
                    self.previousStates[id] = self.robotStates[id]
                    self.robotStates[id] = newStatus
                }
            } catch {
                await MainActor.run {
                    self.robotStates[id] = RobotStatus(isOnline: false)
                }
            }
        } else {
            // Notify if robot went offline
            if previousState?.isOnline == true {
                notificationService.notifyRobotOffline(robotName: robotName)
            }

            await MainActor.run {
                self.previousStates[id] = self.robotStates[id]
                self.robotStates[id] = RobotStatus(isOnline: false)
            }
        }
    }

    // MARK: - State Change Notifications
    private func checkStateChanges(robotName: String, previous: RobotStatus?, current: RobotStatus) {
        guard let prevStatus = previous?.statusValue else { return }
        let currentStatus = current.statusValue ?? ""

        // Cleaning completed
        if prevStatus == "cleaning" && (currentStatus == "docked" || currentStatus == "idle") {
            notificationService.notifyCleaningComplete(robotName: robotName, area: current.cleanedArea)
        }

        // Robot stuck/error
        if currentStatus == "error" && prevStatus != "error" {
            let errorMsg = current.statusFlag ?? String(localized: "status.error")
            notificationService.notifyRobotError(robotName: robotName, error: errorMsg)
        }
    }

    // MARK: - Check Consumables
    func checkConsumables(for id: UUID) async {
        guard let api = apis[id] else { return }
        let robotName = getRobotName(for: id)

        do {
            let consumables = try await api.getConsumables()
            for consumable in consumables {
                if consumable.remainingPercent < 15 {
                    notificationService.notifyConsumableLow(
                        robotName: robotName,
                        consumableName: consumable.displayName,
                        percent: Int(consumable.remainingPercent)
                    )
                }
            }
        } catch {
            print("Failed to check consumables: \(error)")
        }
    }

    // MARK: - Persistence
    private func loadRobots() {
        print("🤖 loadRobots() called")
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([RobotConfig].self, from: data) {
            robots = decoded
            print("🤖 Loaded \(decoded.count) robots from storage")
            for robot in robots {
                apis[robot.id] = ValetudoAPI(config: robot)
                print("🤖 Created API for robot '\(robot.name)' with id \(robot.id)")
            }
        } else {
            print("🤖 No robots in storage or failed to decode")
        }
    }

    private func saveRobots() {
        if let encoded = try? JSONEncoder().encode(robots) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}

// MARK: - Robot Status
struct RobotStatus {
    let isOnline: Bool
    let attributes: [RobotAttribute]
    let info: RobotInfo?

    init(isOnline: Bool, attributes: [RobotAttribute] = [], info: RobotInfo? = nil) {
        self.isOnline = isOnline
        self.attributes = attributes
        self.info = info
    }

    var batteryLevel: Int? {
        attributes.first { $0.__class == "BatteryStateAttribute" }?.level
    }

    var batteryStatus: String? {
        attributes.first { $0.__class == "BatteryStateAttribute" }?.flag
    }

    var statusValue: String? {
        attributes.first { $0.__class == "StatusStateAttribute" }?.value
    }

    var statusFlag: String? {
        attributes.first { $0.__class == "StatusStateAttribute" }?.flag
    }

    var cleanedArea: Int? {
        // Area in cm² from CurrentStatisticsAttribute
        if let areaAttr = attributes.first(where: { $0.__class == "LatestCleanupStatisticsAttribute" && $0.type == "area" }) {
            return areaAttr.value.flatMap { Int($0) }
        }
        return nil
    }
}
