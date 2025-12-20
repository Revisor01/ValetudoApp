import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let error): return error.localizedDescription
        case .invalidResponse: return "Invalid response"
        case .httpError(let code): return "HTTP Error: \(code)"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        }
    }
}

actor ValetudoAPI {
    private let config: RobotConfig
    private let session: URLSession
    private let decoder: JSONDecoder

    init(config: RobotConfig) {
        self.config = config

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
    }

    // MARK: - Base Request
    private func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let baseURL = config.baseURL,
              let url = URL(string: "/api/v2\(endpoint)", relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let username = config.username, let password = config.password, !username.isEmpty {
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        do {
            let result = try decoder.decode(T.self, from: data)
            return result
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func requestVoid(_ endpoint: String, method: String = "PUT", body: Data? = nil) async throws {
        guard let baseURL = config.baseURL,
              let url = URL(string: "/api/v2\(endpoint)", relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Debug: Log the request
        print("[API DEBUG] \(method) \(url.absoluteString)")
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            print("[API DEBUG] Body: \(bodyString)")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let username = config.username, let password = config.password, !username.isEmpty {
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        if let body = body {
            request.httpBody = body
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Robot Info
    func getRobotInfo() async throws -> RobotInfo {
        try await request("/robot")
    }

    func getCapabilities() async throws -> Capabilities {
        try await request("/robot/capabilities")
    }

    // MARK: - State
    func getAttributes() async throws -> [RobotAttribute] {
        try await request("/robot/state/attributes")
    }

    func getMap() async throws -> RobotMap {
        try await request("/robot/state/map")
    }

    // MARK: - Segments
    func getSegments() async throws -> [Segment] {
        try await request("/robot/capabilities/MapSegmentationCapability")
    }

    // MARK: - Controls
    func basicControl(action: BasicAction) async throws {
        let body = try JSONEncoder().encode(BasicControlRequest(action: action.rawValue))
        try await requestVoid("/robot/capabilities/BasicControlCapability", body: body)
    }

    func cleanSegments(ids: [String], iterations: Int = 1) async throws {
        let body = try JSONEncoder().encode(SegmentCleanRequest(segmentIds: ids, iterations: iterations))
        try await requestVoid("/robot/capabilities/MapSegmentationCapability", body: body)
    }

    func goTo(x: Int, y: Int) async throws {
        let body = try JSONEncoder().encode(GoToRequest(x: x, y: y))
        try await requestVoid("/robot/capabilities/GoToLocationCapability", body: body)
    }

    func locate() async throws {
        let body = try JSONEncoder().encode(["action": "locate"])
        try await requestVoid("/robot/capabilities/LocateCapability", body: body)
    }

    // MARK: - Consumables
    func getConsumables() async throws -> [Consumable] {
        try await request("/robot/capabilities/ConsumableMonitoringCapability")
    }

    func resetConsumable(type: String, subType: String?) async throws {
        var endpoint = "/robot/capabilities/ConsumableMonitoringCapability/\(type)"
        if let subType = subType {
            endpoint += "/\(subType)"
        }
        let body = try JSONEncoder().encode(ActionRequest(action: "reset"))
        try await requestVoid(endpoint, body: body)
    }

    // MARK: - Timers
    func getTimers() async throws -> [ValetudoTimer] {
        let response: [String: ValetudoTimer] = try await request("/timers")
        return Array(response.values)
    }

    func createTimer(_ timer: CreateTimerRequest) async throws {
        let body = try JSONEncoder().encode(timer)
        try await requestVoid("/timers", method: "POST", body: body)
    }

    func updateTimer(_ timer: ValetudoTimer) async throws {
        let body = try JSONEncoder().encode(timer)
        try await requestVoid("/timers/\(timer.id)", method: "PUT", body: body)
    }

    func deleteTimer(id: String) async throws {
        try await requestVoid("/timers/\(id)", method: "DELETE")
    }

    // MARK: - Segment Rename
    func renameSegment(id: String, name: String) async throws {
        let body = try JSONEncoder().encode(SegmentRenameRequest(segmentId: id, name: name))
        try await requestVoid("/robot/capabilities/MapSegmentRenameCapability", body: body)
    }

    // MARK: - Fan Speed Control
    func getFanSpeedPresets() async throws -> [String] {
        try await request("/robot/capabilities/FanSpeedControlCapability/presets")
    }

    func setFanSpeed(preset: String) async throws {
        let body = try JSONEncoder().encode(PresetControlRequest(name: preset))
        try await requestVoid("/robot/capabilities/FanSpeedControlCapability/preset", body: body)
    }

    // MARK: - Water Usage Control
    func getWaterUsagePresets() async throws -> [String] {
        try await request("/robot/capabilities/WaterUsageControlCapability/presets")
    }

    func setWaterUsage(preset: String) async throws {
        let body = try JSONEncoder().encode(PresetControlRequest(name: preset))
        try await requestVoid("/robot/capabilities/WaterUsageControlCapability/preset", body: body)
    }

    // MARK: - Statistics
    func getTotalStatistics() async throws -> [StatisticEntry] {
        try await request("/robot/capabilities/TotalStatisticsCapability")
    }

    func getCurrentStatistics() async throws -> [StatisticEntry] {
        try await request("/robot/capabilities/CurrentStatisticsCapability")
    }

    // MARK: - Do Not Disturb
    func getDoNotDisturb() async throws -> DoNotDisturbConfig {
        try await request("/robot/capabilities/DoNotDisturbCapability")
    }

    func setDoNotDisturb(config: DoNotDisturbConfig) async throws {
        let body = try JSONEncoder().encode(config)
        try await requestVoid("/robot/capabilities/DoNotDisturbCapability", body: body)
    }

    // MARK: - Speaker Volume
    func getSpeakerVolume() async throws -> Int {
        let response: SpeakerVolumeResponse = try await request("/robot/capabilities/SpeakerVolumeControlCapability")
        return response.volume
    }

    func setSpeakerVolume(_ volume: Int) async throws {
        let body = try JSONEncoder().encode(SpeakerVolumeRequest(volume: volume))
        try await requestVoid("/robot/capabilities/SpeakerVolumeControlCapability", body: body)
    }

    // MARK: - Speaker Test
    func testSpeaker() async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: "play_test_sound"))
        try await requestVoid("/robot/capabilities/SpeakerTestCapability", body: body)
    }

    // MARK: - Carpet Mode
    func getCarpetMode() async throws -> Bool {
        let response: EnabledResponse = try await request("/robot/capabilities/CarpetModeControlCapability")
        return response.enabled
    }

    func setCarpetMode(enabled: Bool) async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: enabled ? "enable" : "disable"))
        try await requestVoid("/robot/capabilities/CarpetModeControlCapability", body: body)
    }

    // MARK: - Persistent Map
    func getPersistentMap() async throws -> Bool {
        let response: EnabledResponse = try await request("/robot/capabilities/PersistentMapControlCapability")
        return response.enabled
    }

    func setPersistentMap(enabled: Bool) async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: enabled ? "enable" : "disable"))
        try await requestVoid("/robot/capabilities/PersistentMapControlCapability", body: body)
    }

    // MARK: - Mapping Pass
    func startMappingPass() async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: "start_mapping"))
        try await requestVoid("/robot/capabilities/MappingPassCapability", body: body)
    }

    // MARK: - Map Reset
    func resetMap() async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: "reset"))
        try await requestVoid("/robot/capabilities/MapResetCapability", body: body)
    }

    // MARK: - Zone Cleaning
    func cleanZones(_ zones: [CleaningZone]) async throws {
        let body = try JSONEncoder().encode(ZoneCleanRequest(zones: zones))
        try await requestVoid("/robot/capabilities/ZoneCleaningCapability", body: body)
    }

    // MARK: - Virtual Restrictions
    func getVirtualRestrictions() async throws -> VirtualRestrictions {
        try await request("/robot/capabilities/CombinedVirtualRestrictionsCapability")
    }

    func setVirtualRestrictions(_ restrictions: VirtualRestrictions) async throws {
        let body = try JSONEncoder().encode(VirtualRestrictionsRequest(restrictions: restrictions))
        try await requestVoid("/robot/capabilities/CombinedVirtualRestrictionsCapability", body: body)
    }

    // MARK: - Map Segment Edit
    func joinSegments(segmentAId: String, segmentBId: String) async throws {
        let body = try JSONEncoder().encode(JoinSegmentsRequest(segmentAId: segmentAId, segmentBId: segmentBId))
        try await requestVoid("/robot/capabilities/MapSegmentEditCapability", body: body)
    }

    func splitSegment(segmentId: String, pointA: ZonePoint, pointB: ZonePoint) async throws {
        let body = try JSONEncoder().encode(SplitSegmentRequest(segmentId: segmentId, pointA: pointA, pointB: pointB))
        try await requestVoid("/robot/capabilities/MapSegmentEditCapability", body: body)
    }

    // MARK: - Operation Mode Control
    func getOperationModePresets() async throws -> [String] {
        try await request("/robot/capabilities/OperationModeControlCapability/presets")
    }

    func setOperationMode(preset: String) async throws {
        let body = try JSONEncoder().encode(PresetControlRequest(name: preset))
        try await requestVoid("/robot/capabilities/OperationModeControlCapability/preset", body: body)
    }

    // MARK: - Auto Empty Dock
    func getAutoEmptyDockIntervalPresets() async throws -> [String] {
        try await request("/robot/capabilities/AutoEmptyDockAutoEmptyIntervalControlCapability/presets")
    }

    func setAutoEmptyDockInterval(preset: String) async throws {
        let body = try JSONEncoder().encode(PresetControlRequest(name: preset))
        try await requestVoid("/robot/capabilities/AutoEmptyDockAutoEmptyIntervalControlCapability/preset", body: body)
    }

    func triggerAutoEmptyDock() async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: "trigger"))
        try await requestVoid("/robot/capabilities/AutoEmptyDockManualTriggerCapability", body: body)
    }

    // MARK: - Mop Dock
    func triggerMopDockClean() async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: "trigger"))
        try await requestVoid("/robot/capabilities/MopDockCleanManualTriggerCapability", body: body)
    }

    func triggerMopDockDry() async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: "trigger"))
        try await requestVoid("/robot/capabilities/MopDockDryManualTriggerCapability", body: body)
    }

    // MARK: - Manual Control
    func manualControl(action: String, movementSpeed: Int? = nil, angle: Int? = nil, duration: Int? = nil) async throws {
        let body = try JSONEncoder().encode(ManualControlRequest(action: action, movementSpeed: movementSpeed, angle: angle, duration: duration))
        try await requestVoid("/robot/capabilities/ManualControlCapability", body: body)
    }

    // MARK: - Quirks
    func getQuirks() async throws -> [Quirk] {
        try await request("/robot/capabilities/QuirksCapability")
    }

    func setQuirk(id: String, value: String) async throws {
        let body = try JSONEncoder().encode(QuirkSetRequest(id: id, value: value))
        try await requestVoid("/robot/capabilities/QuirksCapability", body: body)
    }

    // MARK: - WiFi
    func getWifiStatus() async throws -> WifiStatus {
        try await request("/robot/capabilities/WifiConfigurationCapability")
    }

    func scanWifi() async throws -> [WifiNetwork] {
        try await request("/robot/capabilities/WifiScanCapability")
    }

    func setWifiConfig(ssid: String, password: String) async throws {
        let body = try JSONEncoder().encode(WifiConfigRequest(ssid: ssid, password: password))
        try await requestVoid("/robot/capabilities/WifiConfigurationCapability", body: body)
    }

    // MARK: - Key Lock
    func getKeyLock() async throws -> Bool {
        let response: EnabledResponse = try await request("/robot/capabilities/KeyLockCapability")
        return response.enabled
    }

    func setKeyLock(enabled: Bool) async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: enabled ? "enable" : "disable"))
        try await requestVoid("/robot/capabilities/KeyLockCapability", body: body)
    }

    // MARK: - Obstacle Avoidance
    func getObstacleAvoidance() async throws -> Bool {
        let response: EnabledResponse = try await request("/robot/capabilities/ObstacleAvoidanceControlCapability")
        return response.enabled
    }

    func setObstacleAvoidance(enabled: Bool) async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: enabled ? "enable" : "disable"))
        try await requestVoid("/robot/capabilities/ObstacleAvoidanceControlCapability", body: body)
    }

    // MARK: - Pet Obstacle Avoidance
    func getPetObstacleAvoidance() async throws -> Bool {
        let response: EnabledResponse = try await request("/robot/capabilities/PetObstacleAvoidanceControlCapability")
        return response.enabled
    }

    func setPetObstacleAvoidance(enabled: Bool) async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: enabled ? "enable" : "disable"))
        try await requestVoid("/robot/capabilities/PetObstacleAvoidanceControlCapability", body: body)
    }

    // MARK: - Carpet Sensor Mode
    func getCarpetSensorMode() async throws -> String {
        let response: ModeResponse = try await request("/robot/capabilities/CarpetSensorModeControlCapability")
        return response.mode
    }

    func getCarpetSensorModePresets() async throws -> [String] {
        try await request("/robot/capabilities/CarpetSensorModeControlCapability/presets")
    }

    func setCarpetSensorMode(mode: String) async throws {
        let body = try JSONEncoder().encode(ModeRequest(mode: mode))
        try await requestVoid("/robot/capabilities/CarpetSensorModeControlCapability", body: body)
    }

    // MARK: - Collision Avoidant Navigation
    func getCollisionAvoidantNavigation() async throws -> Bool {
        let response: EnabledResponse = try await request("/robot/capabilities/CollisionAvoidantNavigationControlCapability")
        return response.enabled
    }

    func setCollisionAvoidantNavigation(enabled: Bool) async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: enabled ? "enable" : "disable"))
        try await requestVoid("/robot/capabilities/CollisionAvoidantNavigationControlCapability", body: body)
    }

    // MARK: - Mop Dock Auto Drying
    func getMopDockAutoDrying() async throws -> Bool {
        let response: EnabledResponse = try await request("/robot/capabilities/MopDockMopAutoDryingControlCapability")
        return response.enabled
    }

    func setMopDockAutoDrying(enabled: Bool) async throws {
        let body = try JSONEncoder().encode(ActionRequest(action: enabled ? "enable" : "disable"))
        try await requestVoid("/robot/capabilities/MopDockMopAutoDryingControlCapability", body: body)
    }

    // MARK: - Mop Dock Wash Temperature
    func getMopDockWashTemperaturePresets() async throws -> [String] {
        try await request("/robot/capabilities/MopDockMopWashTemperatureControlCapability/presets")
    }

    func setMopDockWashTemperature(preset: String) async throws {
        let body = try JSONEncoder().encode(PresetControlRequest(name: preset))
        try await requestVoid("/robot/capabilities/MopDockMopWashTemperatureControlCapability/preset", body: body)
    }

    // MARK: - MQTT
    func getMQTTConfig() async throws -> MQTTConfig {
        try await request("/valetudo/config/interfaces/mqtt")
    }

    func setMQTTConfig(_ config: MQTTConfig) async throws {
        let body = try JSONEncoder().encode(config)
        try await requestVoid("/valetudo/config/interfaces/mqtt", body: body)
    }

    // MARK: - NTP
    func getNTPConfig() async throws -> NTPConfig {
        try await request("/ntpclient/config")
    }

    func setNTPConfig(_ config: NTPConfig) async throws {
        let body = try JSONEncoder().encode(config)
        try await requestVoid("/ntpclient/config", body: body)
    }

    func getNTPStatus() async throws -> NTPStatus {
        try await request("/ntpclient/status")
    }

    // MARK: - System Info
    func getValetudoVersion() async throws -> ValetudoVersion {
        try await request("/valetudo/version")
    }

    func getSystemHostInfo() async throws -> SystemHostInfo {
        try await request("/system/host/info")
    }

    func getUpdaterState() async throws -> UpdaterState {
        try await request("/updater/state")
    }

    func checkForUpdates() async throws {
        let body = try JSONEncoder().encode(["action": "check"])
        try await requestVoid("/updater", body: body)
    }

    func downloadUpdate() async throws {
        let body = try JSONEncoder().encode(["action": "download"])
        try await requestVoid("/updater", body: body)
    }

    func applyUpdate() async throws {
        let body = try JSONEncoder().encode(["action": "apply"])
        try await requestVoid("/updater", body: body)
    }

    // MARK: - Connection Check
    func checkConnection() async -> Bool {
        do {
            let _: RobotInfo = try await request("/robot")
            return true
        } catch {
            return false
        }
    }
}
