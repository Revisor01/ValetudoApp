import Foundation
import SwiftUI

@MainActor
class RobotManager: ObservableObject {
    @Published var robots: [RobotConfig] = []
    @Published var robotStates: [UUID: RobotStatus] = [:]
    @Published var robotUpdateAvailable: [UUID: Bool] = [:]
    @AppStorage("demo_mode_enabled") var demoModeEnabled: Bool = false {
        didSet {
            if demoModeEnabled {
                setupDemoRobot()
            } else {
                removeDemoRobot()
            }
        }
    }

    private var apis: [UUID: ValetudoAPI] = [:]
    private var refreshTask: Task<Void, Never>?
    private var previousStates: [UUID: RobotStatus] = [:]
    private var lastConsumableCheck: [UUID: Date] = [:]
    private let storageKey = "valetudo_robots"
    private let notificationService = NotificationService.shared

    // Demo robot ID (fixed UUID for consistency)
    static let demoRobotId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init() {
        loadRobots()
        startRefreshing()
        notificationService.setupCategories()

        // Setup demo robot if enabled
        if demoModeEnabled {
            setupDemoRobot()
        }

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
        apis[id]
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

                // Check for updates and consumables (in background, don't block refresh)
                Task {
                    await self.checkUpdateForRobot(id)
                    await self.checkConsumables(for: id)
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

    func checkUpdateForRobot(_ id: UUID) async {
        guard let api = apis[id] else { return }
        do {
            let updaterState = try await api.getUpdaterState()
            await MainActor.run {
                self.robotUpdateAvailable[id] = updaterState.isUpdateAvailable
            }
        } catch {
            // Silently ignore - not all robots support this
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

        // Robot stuck (specific flag)
        if current.statusFlag == "stuck" && previous?.statusFlag != "stuck" {
            notificationService.notifyRobotStuck(robotName: robotName)
        }

        // Robot error (general error state)
        if currentStatus == "error" && prevStatus != "error" {
            let errorMsg = current.statusFlag ?? String(localized: "status.error")
            notificationService.notifyRobotError(robotName: robotName, error: errorMsg)
        }
    }

    // MARK: - Check Consumables
    func checkConsumables(for id: UUID) async {
        guard let api = apis[id] else { return }

        // Only check consumables once per hour to avoid spam
        if let lastCheck = lastConsumableCheck[id],
           Date().timeIntervalSince(lastCheck) < 3600 {
            return
        }

        lastConsumableCheck[id] = Date()
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
            // Silently ignore consumable check failures
        }
    }

    // MARK: - Persistence
    private func loadRobots() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([RobotConfig].self, from: data) {
            robots = decoded
            for robot in robots {
                apis[robot.id] = ValetudoAPI(config: robot)
            }
        }
    }

    private func saveRobots() {
        if let encoded = try? JSONEncoder().encode(robots) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - Demo Mode
    private func setupDemoRobot() {
        let demoConfig = RobotConfig(
            id: RobotManager.demoRobotId,
            name: "Demo Robot",
            host: "demo.local"
        )

        // Add demo robot if not already present
        if !robots.contains(where: { $0.id == RobotManager.demoRobotId }) {
            robots.insert(demoConfig, at: 0)
        }

        // Create demo status with realistic data
        let demoStatus = createDemoStatus()
        robotStates[RobotManager.demoRobotId] = demoStatus
    }

    private func removeDemoRobot() {
        robots.removeAll { $0.id == RobotManager.demoRobotId }
        robotStates.removeValue(forKey: RobotManager.demoRobotId)
        apis.removeValue(forKey: RobotManager.demoRobotId)
    }

    private func createDemoStatus() -> RobotStatus {
        let demoAttributes: [RobotAttribute] = [
            // Battery
            RobotAttribute(__class: "BatteryStateAttribute", type: nil, subType: nil, value: nil, level: 78, flag: "none"),
            // Status
            RobotAttribute(__class: "StatusStateAttribute", type: nil, subType: nil, value: "docked", level: nil, flag: "none"),
            // Attachments
            RobotAttribute(__class: "AttachmentStateAttribute", type: "dustbin", subType: nil, value: "true", level: nil, flag: nil),
            RobotAttribute(__class: "AttachmentStateAttribute", type: "watertank", subType: nil, value: "true", level: nil, flag: nil),
            RobotAttribute(__class: "AttachmentStateAttribute", type: "mop", subType: nil, value: "false", level: nil, flag: nil),
            // Presets
            RobotAttribute(__class: "PresetSelectionStateAttribute", type: "fan_speed", subType: nil, value: "medium", level: nil, flag: nil),
            RobotAttribute(__class: "PresetSelectionStateAttribute", type: "water_grade", subType: nil, value: "medium", level: nil, flag: nil),
            RobotAttribute(__class: "PresetSelectionStateAttribute", type: "operation_mode", subType: nil, value: "vacuum", level: nil, flag: nil)
        ]

        let demoInfo = RobotInfo(
            manufacturer: "Dreame",
            modelName: "L10s Ultra",
            implementation: "DreameValetudoRobot"
        )

        return RobotStatus(
            isOnline: true,
            attributes: demoAttributes,
            info: demoInfo
        )
    }

    func isDemoRobot(_ id: UUID) -> Bool {
        return id == RobotManager.demoRobotId && demoModeEnabled
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

    // MARK: - Attachment States
    var dustbinAttached: Bool? {
        if let attr = attributes.first(where: { $0.__class == "AttachmentStateAttribute" && $0.type == "dustbin" }) {
            return attr.value == "true"
        }
        return nil
    }

    var mopAttached: Bool? {
        if let attr = attributes.first(where: { $0.__class == "AttachmentStateAttribute" && $0.type == "mop" }) {
            return attr.value == "true"
        }
        return nil
    }

    var waterTankAttached: Bool? {
        if let attr = attributes.first(where: { $0.__class == "AttachmentStateAttribute" && $0.type == "watertank" }) {
            return attr.value == "true"
        }
        return nil
    }

    // Returns true if any attachment is missing that the robot expects
    var hasMissingAttachments: Bool {
        // Only check attachments that the robot reports (not nil)
        if dustbinAttached == false { return true }
        if mopAttached == false { return true }
        if waterTankAttached == false { return true }
        return false
    }
}
