import SwiftUI

struct RobotSettingsView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var volume: Double = 80
    @State private var carpetMode = false
    @State private var persistentMap = false
    @State private var keyLock = false
    @State private var obstacleAvoidance = false
    @State private var petObstacleAvoidance = false
    @State private var isLoading = false
    @State private var isInitialLoad = true

    // Capabilities (default to DebugConfig.showAllCapabilities for testing)
    @State private var hasVolumeControl = DebugConfig.showAllCapabilities
    @State private var hasSpeakerTest = DebugConfig.showAllCapabilities
    @State private var hasCarpetMode = DebugConfig.showAllCapabilities
    @State private var hasPersistentMap = DebugConfig.showAllCapabilities
    @State private var hasMappingPass = DebugConfig.showAllCapabilities
    @State private var hasAutoEmptyDock = DebugConfig.showAllCapabilities
    @State private var hasQuirks = DebugConfig.showAllCapabilities
    @State private var hasWifiConfig = DebugConfig.showAllCapabilities
    @State private var hasWifiScan = DebugConfig.showAllCapabilities
    @State private var hasKeyLock = DebugConfig.showAllCapabilities
    @State private var hasObstacleAvoidance = DebugConfig.showAllCapabilities
    @State private var hasPetObstacleAvoidance = DebugConfig.showAllCapabilities
    @State private var hasCarpetSensorMode = DebugConfig.showAllCapabilities
    @State private var hasMapReset = DebugConfig.showAllCapabilities
    @State private var hasCollisionAvoidance = DebugConfig.showAllCapabilities
    @State private var hasMopDockAutoDrying = DebugConfig.showAllCapabilities
    @State private var hasMopDockWashTemperature = DebugConfig.showAllCapabilities

    // Carpet sensor mode
    @State private var carpetSensorMode: String = ""
    @State private var carpetSensorModePresets: [String] = []

    // New capability states
    @State private var collisionAvoidance = false
    @State private var mopDockAutoDrying = false
    @State private var mopDockWashTemperaturePresets: [String] = []
    @State private var currentWashTemperature: String = ""

    @State private var volumeChanged = false
    @State private var showMappingAlert = false
    @State private var showMapResetAlert = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            // Speaker Section
            if hasVolumeControl || hasSpeakerTest {
                Section {
                    if hasVolumeControl {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: volumeIcon)
                                    .foregroundStyle(.blue)
                                Text(String(localized: "settings.volume"))
                                Spacer()
                                Text("\(Int(volume))%")
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $volume, in: 0...100, step: 10) {
                                Text("Volume")
                            } onEditingChanged: { editing in
                                if !editing {
                                    volumeChanged = true
                                    Task { await setVolume() }
                                }
                            }
                        }
                    }

                    if hasSpeakerTest {
                        Button {
                            Task { await testSpeaker() }
                        } label: {
                            HStack {
                                Image(systemName: "play.circle")
                                    .foregroundStyle(.blue)
                                Text(String(localized: "settings.test_speaker"))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled(isLoading)
                    }
                } header: {
                    Label(String(localized: "settings.speaker"), systemImage: "speaker.wave.2")
                }
            }

            // Cleaning Settings Section
            if hasCarpetMode || hasObstacleAvoidance || hasPetObstacleAvoidance || hasCollisionAvoidance || hasCarpetSensorMode {
                Section {
                    if hasCarpetMode {
                        Toggle(isOn: $carpetMode) {
                            HStack {
                                Image(systemName: "square.grid.3x3")
                                    .foregroundStyle(.orange)
                                Text(String(localized: "settings.carpet_mode"))
                            }
                        }
                        .onChange(of: carpetMode) { _, newValue in
                            guard !isInitialLoad else { return }
                            Task { await setCarpetMode(newValue) }
                        }
                    }

                    if hasObstacleAvoidance {
                        Toggle(isOn: $obstacleAvoidance) {
                            HStack {
                                Image(systemName: "eye.trianglebadge.exclamationmark")
                                    .foregroundStyle(.purple)
                                Text(String(localized: "settings.obstacle_avoidance"))
                            }
                        }
                        .onChange(of: obstacleAvoidance) { _, newValue in
                            guard !isInitialLoad else { return }
                            Task { await setObstacleAvoidance(newValue) }
                        }
                    }

                    if hasPetObstacleAvoidance {
                        Toggle(isOn: $petObstacleAvoidance) {
                            HStack {
                                Image(systemName: "pawprint.fill")
                                    .foregroundStyle(.brown)
                                Text(String(localized: "settings.pet_obstacle_avoidance"))
                            }
                        }
                        .onChange(of: petObstacleAvoidance) { _, newValue in
                            guard !isInitialLoad else { return }
                            Task { await setPetObstacleAvoidance(newValue) }
                        }
                    }

                    if hasCollisionAvoidance {
                        Toggle(isOn: $collisionAvoidance) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.yellow)
                                Text(String(localized: "settings.collision_avoidance"))
                            }
                        }
                        .onChange(of: collisionAvoidance) { _, newValue in
                            guard !isInitialLoad else { return }
                            Task { await setCollisionAvoidance(newValue) }
                        }
                    }

                    if hasCarpetSensorMode && !carpetSensorModePresets.isEmpty {
                        Picker(selection: $carpetSensorMode) {
                            ForEach(carpetSensorModePresets, id: \.self) { preset in
                                Text(displayNameForCarpetSensorMode(preset)).tag(preset)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sensor.fill")
                                    .foregroundStyle(.teal)
                                Text(String(localized: "settings.carpet_sensor_mode"))
                            }
                        }
                        .onChange(of: carpetSensorMode) { _, newValue in
                            guard !isInitialLoad && !newValue.isEmpty else { return }
                            Task { await setCarpetSensorMode(newValue) }
                        }
                    }
                } header: {
                    Label(String(localized: "settings.cleaning"), systemImage: "sparkles")
                }
            }

            // Device Lock Section
            if hasKeyLock {
                Section {
                    Toggle(isOn: $keyLock) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.red)
                            Text(String(localized: "settings.key_lock"))
                        }
                    }
                    .onChange(of: keyLock) { _, newValue in
                        guard !isInitialLoad else { return }
                        Task { await setKeyLock(newValue) }
                    }
                } header: {
                    Label(String(localized: "settings.device"), systemImage: "gearshape")
                } footer: {
                    Text(String(localized: "settings.key_lock_desc"))
                }
            }

            // Map Settings Section
            if hasPersistentMap || hasMappingPass || hasMapReset {
                Section {
                    if hasPersistentMap {
                        Toggle(isOn: $persistentMap) {
                            HStack {
                                Image(systemName: "map")
                                    .foregroundStyle(.green)
                                Text(String(localized: "settings.persistent_map"))
                            }
                        }
                        .onChange(of: persistentMap) { _, newValue in
                            guard !isInitialLoad else { return }
                            Task { await setPersistentMap(newValue) }
                        }
                    }

                    if hasMappingPass {
                        Button {
                            showMappingAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "point.bottomleft.forward.to.arrowtriangle.uturn.scurvepath")
                                    .foregroundStyle(.orange)
                                Text(String(localized: "settings.start_mapping"))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled(isLoading)
                    }

                    if hasMapReset {
                        Button(role: .destructive) {
                            showMapResetAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                Text(String(localized: "settings.map_reset"))
                                    .foregroundStyle(.red)
                            }
                        }
                        .disabled(isLoading)
                    }
                } header: {
                    Label(String(localized: "settings.map"), systemImage: "map")
                } footer: {
                    if hasPersistentMap && hasMappingPass {
                        Text(String(localized: "settings.persistent_map_desc"))
                    } else if hasPersistentMap {
                        Text(String(localized: "settings.persistent_map_desc"))
                    } else if hasMappingPass {
                        Text(String(localized: "settings.start_mapping_desc"))
                    }
                }
            }

            // Quirks Section
            if hasQuirks {
                Section {
                    NavigationLink {
                        QuirksView(robot: robot)
                    } label: {
                        HStack {
                            Image(systemName: "wrench.adjustable")
                                .foregroundStyle(.orange)
                            Text(String(localized: "settings.quirks"))
                        }
                    }
                } header: {
                    Label(String(localized: "settings.advanced"), systemImage: "slider.horizontal.3")
                } footer: {
                    Text(String(localized: "settings.quirks_desc"))
                }
            }

            // Valetudo System Section
            Section {
                // WiFi Settings
                if hasWifiConfig || hasWifiScan {
                    NavigationLink {
                        WifiSettingsView(robot: robot)
                    } label: {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundStyle(.blue)
                            Text(String(localized: "settings.wifi"))
                        }
                    }
                }

                // MQTT Settings
                NavigationLink {
                    MQTTSettingsView(robot: robot)
                } label: {
                    HStack {
                        Image(systemName: "network")
                            .foregroundStyle(.green)
                        Text("MQTT")
                    }
                }

                // NTP Settings
                NavigationLink {
                    NTPSettingsView(robot: robot)
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.orange)
                        Text("NTP")
                    }
                }

                // System Info
                NavigationLink {
                    ValetudoInfoView(robot: robot)
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.gray)
                        Text("Valetudo")
                    }
                }
            } header: {
                Label(String(localized: "settings.system"), systemImage: "gearshape.2")
            }

            // No settings available
            if !hasVolumeControl && !hasSpeakerTest && !hasCarpetMode && !hasPersistentMap && !hasMappingPass && !hasAutoEmptyDock && !hasMopDockAutoDrying && !hasMopDockWashTemperature && !hasQuirks && !isLoading {
                Section {
                    Text(String(localized: "settings.robot_no_settings"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "settings.section_robot"))
        .task {
            await loadSettings()
        }
        .refreshable {
            await loadSettings()
        }
        .overlay {
            if isLoading && !hasVolumeControl && !hasCarpetMode && !hasPersistentMap && !hasMappingPass {
                ProgressView()
            }
        }
        .alert(
            String(localized: "settings.mapping_warning_title"),
            isPresented: $showMappingAlert
        ) {
            Button(String(localized: "settings.cancel"), role: .cancel) { }
            Button(String(localized: "settings.mapping_start"), role: .destructive) {
                Task { await startMappingPass() }
            }
        } message: {
            Text(String(localized: "settings.mapping_warning_message"))
        }
        .alert(
            String(localized: "settings.map_reset_warning_title"),
            isPresented: $showMapResetAlert
        ) {
            Button(String(localized: "settings.cancel"), role: .cancel) { }
            Button(String(localized: "settings.map_reset_confirm"), role: .destructive) {
                Task { await resetMap() }
            }
        } message: {
            Text(String(localized: "settings.map_reset_warning_message"))
        }
    }

    private var volumeIcon: String {
        if volume == 0 { return "speaker.slash" }
        if volume < 33 { return "speaker.wave.1" }
        if volume < 66 { return "speaker.wave.2" }
        return "speaker.wave.3"
    }

    private func displayNameForCarpetSensorMode(_ mode: String) -> String {
        // Convert API mode names to user-friendly display names
        switch mode.lowercased() {
        case "off":
            return String(localized: "settings.carpet_sensor.off")
        case "low":
            return String(localized: "settings.carpet_sensor.low")
        case "medium":
            return String(localized: "settings.carpet_sensor.medium")
        case "high":
            return String(localized: "settings.carpet_sensor.high")
        case "auto":
            return String(localized: "settings.carpet_sensor.auto")
        case "avoidance":
            return String(localized: "settings.carpet_sensor.avoidance")
        case "adaptation":
            return String(localized: "settings.carpet_sensor.adaptation")
        default:
            // Fallback: capitalize and replace underscores
            return mode.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }

    // MARK: - Data Loading
    private func loadSettings() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        // Load speaker volume
        do {
            volume = Double(try await api.getSpeakerVolume())
        } catch {
            if !DebugConfig.showAllCapabilities { hasVolumeControl = false }
        }

        // Check speaker test capability (just mark as available if volume works)
        // We'll test it when the user presses the button

        // Load carpet mode
        do {
            carpetMode = try await api.getCarpetMode()
        } catch {
            if !DebugConfig.showAllCapabilities { hasCarpetMode = false }
        }

        // Load persistent map
        do {
            persistentMap = try await api.getPersistentMap()
        } catch {
            if !DebugConfig.showAllCapabilities { hasPersistentMap = false }
        }

        // Check capabilities
        do {
            let capabilities = try await api.getCapabilities()
            hasMappingPass = DebugConfig.showAllCapabilities || capabilities.contains("MappingPassCapability")
            hasAutoEmptyDock = DebugConfig.showAllCapabilities || capabilities.contains("AutoEmptyDockAutoEmptyIntervalControlCapability")
            hasQuirks = DebugConfig.showAllCapabilities || capabilities.contains("QuirksCapability")
            hasWifiConfig = DebugConfig.showAllCapabilities || capabilities.contains("WifiConfigurationCapability")
            hasWifiScan = DebugConfig.showAllCapabilities || capabilities.contains("WifiScanCapability")
            hasKeyLock = DebugConfig.showAllCapabilities || capabilities.contains("KeyLockCapability")
            hasObstacleAvoidance = DebugConfig.showAllCapabilities || capabilities.contains("ObstacleAvoidanceControlCapability")
            hasPetObstacleAvoidance = DebugConfig.showAllCapabilities || capabilities.contains("PetObstacleAvoidanceControlCapability")
            hasCarpetSensorMode = DebugConfig.showAllCapabilities || capabilities.contains("CarpetSensorModeControlCapability")
            hasMapReset = DebugConfig.showAllCapabilities || capabilities.contains("MapResetCapability")
            hasCollisionAvoidance = DebugConfig.showAllCapabilities || capabilities.contains("CollisionAvoidantNavigationControlCapability")
            hasMopDockAutoDrying = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopAutoDryingControlCapability")
            hasMopDockWashTemperature = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopWashTemperatureControlCapability")
        } catch {
            hasMappingPass = DebugConfig.showAllCapabilities
        }

        // Load new capability states
        if hasKeyLock {
            do {
                keyLock = try await api.getKeyLock()
            } catch {
                if !DebugConfig.showAllCapabilities { hasKeyLock = false }
            }
        }

        if hasObstacleAvoidance {
            do {
                obstacleAvoidance = try await api.getObstacleAvoidance()
            } catch {
                if !DebugConfig.showAllCapabilities { hasObstacleAvoidance = false }
            }
        }

        if hasPetObstacleAvoidance {
            do {
                petObstacleAvoidance = try await api.getPetObstacleAvoidance()
            } catch {
                if !DebugConfig.showAllCapabilities { hasPetObstacleAvoidance = false }
            }
        }

        // Load carpet sensor mode presets
        if hasCarpetSensorMode {
            do {
                carpetSensorModePresets = try await api.getCarpetSensorModePresets()
                if !carpetSensorModePresets.isEmpty {
                    carpetSensorMode = try await api.getCarpetSensorMode()
                }
            } catch {
                if !DebugConfig.showAllCapabilities {
                    hasCarpetSensorMode = false
                }
                carpetSensorModePresets = []
            }
        }

        // Load collision avoidance
        if hasCollisionAvoidance {
            do {
                collisionAvoidance = try await api.getCollisionAvoidantNavigation()
            } catch {
                if !DebugConfig.showAllCapabilities { hasCollisionAvoidance = false }
            }
        }

        // Load mop dock auto drying
        if hasMopDockAutoDrying {
            do {
                mopDockAutoDrying = try await api.getMopDockAutoDrying()
            } catch {
                if !DebugConfig.showAllCapabilities { hasMopDockAutoDrying = false }
            }
        }

        // Load mop dock wash temperature presets
        if hasMopDockWashTemperature {
            do {
                mopDockWashTemperaturePresets = try await api.getMopDockWashTemperaturePresets()
                // Get current value from robot state
                if let tempAttr = robotManager.robotStates[robot.id]?.attributes.first(where: {
                    $0.__class == "PresetSelectionStateAttribute" && $0.type == "mop_dock_mop_cleaning_water_temperature"
                }) {
                    currentWashTemperature = tempAttr.value ?? ""
                }
            } catch {
                if !DebugConfig.showAllCapabilities { hasMopDockWashTemperature = false }
                mopDockWashTemperaturePresets = []
            }
        }

        // Mark initial load as complete to enable onChange handlers
        isInitialLoad = false
    }

    // MARK: - Actions
    private func setVolume() async {
        guard let api = api else { return }

        do {
            try await api.setSpeakerVolume(Int(volume))
        } catch {
            print("Failed to set volume: \(error)")
        }
    }

    private func testSpeaker() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.testSpeaker()
        } catch {
            hasSpeakerTest = false
            print("Speaker test not supported: \(error)")
        }
    }

    private func setCarpetMode(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setCarpetMode(enabled: enabled)
        } catch {
            print("Failed to set carpet mode: \(error)")
            // Revert on failure
            carpetMode = !enabled
        }
    }

    private func setPersistentMap(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setPersistentMap(enabled: enabled)
        } catch {
            print("Failed to set persistent map: \(error)")
            // Revert on failure
            persistentMap = !enabled
        }
    }

    private func setKeyLock(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setKeyLock(enabled: enabled)
        } catch {
            print("Failed to set key lock: \(error)")
            keyLock = !enabled
        }
    }

    private func setObstacleAvoidance(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setObstacleAvoidance(enabled: enabled)
        } catch {
            print("Failed to set obstacle avoidance: \(error)")
            obstacleAvoidance = !enabled
        }
    }

    private func setPetObstacleAvoidance(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setPetObstacleAvoidance(enabled: enabled)
        } catch {
            print("Failed to set pet obstacle avoidance: \(error)")
            petObstacleAvoidance = !enabled
        }
    }

    private func setCarpetSensorMode(_ mode: String) async {
        guard let api = api else { return }

        do {
            try await api.setCarpetSensorMode(mode: mode)
        } catch {
            print("Failed to set carpet sensor mode: \(error)")
            // Revert to previous value on failure
            await loadCarpetSensorMode()
        }
    }

    private func loadCarpetSensorMode() async {
        guard let api = api else { return }
        do {
            carpetSensorMode = try await api.getCarpetSensorMode()
        } catch {
            // Ignore errors
        }
    }

    private func resetMap() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.resetMap()
        } catch {
            print("Failed to reset map: \(error)")
        }
    }

    private func startMappingPass() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.startMappingPass()
        } catch {
            print("Failed to start mapping pass: \(error)")
            hasMappingPass = false
        }
    }

    private func setCollisionAvoidance(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setCollisionAvoidantNavigation(enabled: enabled)
        } catch {
            print("Failed to set collision avoidance: \(error)")
            collisionAvoidance = !enabled
        }
    }

    private func setMopDockAutoDrying(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockAutoDrying(enabled: enabled)
        } catch {
            print("Failed to set mop dock auto drying: \(error)")
            mopDockAutoDrying = !enabled
        }
    }

    private func setWashTemperature(_ preset: String) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockWashTemperature(preset: preset)
        } catch {
            print("Failed to set wash temperature: \(error)")
        }
    }

    private func displayNameForWashTemperature(_ preset: String) -> String {
        switch preset.lowercased() {
        case "cold":
            return String(localized: "settings.wash_temp.cold")
        case "warm":
            return String(localized: "settings.wash_temp.warm")
        case "hot":
            return String(localized: "settings.wash_temp.hot")
        default:
            return preset.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }
}

// MARK: - Auto Empty Dock Settings View
struct AutoEmptyDockSettingsView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var presets: [String] = []
    @State private var selectedPreset: String?
    @State private var isLoading = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            if presets.isEmpty && !isLoading {
                Text(String(localized: "settings.no_presets"))
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            Task { await selectPreset(preset) }
                        } label: {
                            HStack {
                                Text(preset.capitalized.replacingOccurrences(of: "_", with: " "))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } footer: {
                    Text(String(localized: "settings.auto_empty_interval_desc"))
                }
            }
        }
        .navigationTitle(String(localized: "settings.auto_empty_interval"))
        .task {
            await loadPresets()
        }
        .overlay {
            if isLoading && presets.isEmpty {
                ProgressView()
            }
        }
    }

    private func loadPresets() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            presets = try await api.getAutoEmptyDockIntervalPresets()
        } catch {
            print("Failed to load presets: \(error)")
        }
    }

    private func selectPreset(_ preset: String) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.setAutoEmptyDockInterval(preset: preset)
            selectedPreset = preset
        } catch {
            print("Failed to set preset: \(error)")
        }
    }
}

// MARK: - Quirks View
struct QuirksView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var quirks: [Quirk] = []
    @State private var isLoading = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            if quirks.isEmpty && !isLoading {
                Text(String(localized: "settings.no_quirks"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(quirks) { quirk in
                    Section {
                        Picker(selection: Binding(
                            get: { quirk.value },
                            set: { newValue in
                                Task { await setQuirk(id: quirk.id, value: newValue) }
                            }
                        )) {
                            ForEach(quirk.options, id: \.self) { option in
                                Text(option.capitalized.replacingOccurrences(of: "_", with: " "))
                                    .tag(option)
                            }
                        } label: {
                            Text(quirk.title)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .pickerStyle(.menu)
                    } footer: {
                        Text(quirk.description)
                            .lineLimit(2)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.quirks"))
        .task {
            await loadQuirks()
        }
        .refreshable {
            await loadQuirks()
        }
        .overlay {
            if isLoading && quirks.isEmpty {
                ProgressView()
            }
        }
    }

    private func loadQuirks() async {
        // In DEBUG mode, always show debug quirks
        if DebugConfig.showAllCapabilities {
            quirks = debugQuirks
            return
        }

        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            quirks = try await api.getQuirks()
        } catch {
            print("Failed to load quirks: \(error)")
        }
    }

    private var debugQuirks: [Quirk] {
        [
            Quirk(id: "carpetModeSensitivity", options: ["low", "medium", "high"], title: "Carpet Mode Sensitivity", description: "Adjusts carpet detection sensitivity based on carpet type", value: "medium"),
            Quirk(id: "tightMopPattern", options: ["on", "off"], title: "Tight Mop Pattern", description: "Enabling this makes your robot move in a much tighter pattern when mopping.", value: "off"),
            Quirk(id: "mopDockMopOnlyMode", options: ["on", "off"], title: "Mop Only", description: "Disable the vacuum functionality when the mop pads are attached.", value: "off"),
            Quirk(id: "mopDockMopCleaningFrequency", options: ["every_segment", "every_5_m2", "every_10_m2", "every_15_m2", "every_20_m2", "every_25_m2"], title: "Mop Cleaning Frequency", description: "Controls mop cleaning and re-wetting intervals during cleanup", value: "every_10_m2"),
            Quirk(id: "mopDockUvTreatment", options: ["on", "off"], title: "Wastewater UV Treatment", description: "Disinfect the waste water tank after each successful cleanup using the in-built UV-C light.", value: "on"),
            Quirk(id: "mopDryingTime", options: ["2h", "3h", "4h"], title: "Mop Drying Time", description: "Define how long the mop should be dried after a cleanup", value: "3h"),
            Quirk(id: "mopDockDetergent", options: ["on", "off"], title: "Detergent", description: "Select if the Dock should automatically add detergent to the water", value: "on"),
            Quirk(id: "mopDockWetDrySwitch", options: ["wet", "dry"], title: "Pre-Wet Mops", description: "Allows selection of pre-wetting mops or running dry for spill cleanup", value: "wet"),
            Quirk(id: "edgeExtensionFrequency", options: ["automatic", "each_cleanup", "every_7_days"], title: "Edge Extension: Frequency", description: "Controls when mop and side brush extend for corner coverage", value: "automatic"),
            Quirk(id: "carpetDetectionAutoDeepCleaning", options: ["on", "off"], title: "Deep Carpet Cleaning", description: "When enabled, the robot will automatically slowly clean detected carpets with twice the cleanup passes in alternating directions.", value: "off"),
            Quirk(id: "mopDockWaterUsage", options: ["low", "medium", "high"], title: "Mop Dock Mop Wash Intensity", description: "Higher settings mean more water and longer wash cycles.", value: "medium"),
            Quirk(id: "sideBrushExtend", options: ["on", "off"], title: "Edge Extension: Side Brush", description: "Automatically extend the side brush to further reach into corners or below furniture", value: "on"),
            Quirk(id: "detachMops", options: ["on", "off"], title: "Detach Mops", description: "When enabled, the robot will leave the mop pads in the dock when running a vacuum-only cleanup", value: "on"),
            Quirk(id: "cleanRoute", options: ["quick", "standard", "intensive", "deep"], title: "Clean Route", description: "Trade speed for thoroughness and vice-versa. These settings only apply when mopping.", value: "standard"),
            Quirk(id: "sideBrushOnCarpet", options: ["on", "off"], title: "Side Brush on Carpet", description: "Select if the side brush should spin when cleaning carpets.", value: "on"),
            Quirk(id: "mopDockAutoRepair", options: ["select_to_trigger", "trigger"], title: "Mop Dock Auto Repair", description: "Addresses air in system preventing proper water tank filling. Select trigger to start.", value: "select_to_trigger"),
            Quirk(id: "waterHookupTest", options: ["select_to_trigger", "trigger"], title: "Water Hookup Test", description: "Tests permanent water hookup installation with voice prompts.", value: "select_to_trigger"),
            Quirk(id: "drainInternalWaterTank", options: ["select_to_trigger", "trigger"], title: "Drain Internal Water Tank", description: "Drain the internal water tank of the robot into the dock. May take up to 3 minutes.", value: "select_to_trigger"),
            Quirk(id: "mopDockCleaningProcess", options: ["select_to_trigger", "trigger"], title: "Mop Dock Cleaning Process", description: "Triggers manual base cleaning with user guidance.", value: "select_to_trigger")
        ]
    }

    private func setQuirk(id: String, value: String) async {
        guard let api = api else { return }

        do {
            try await api.setQuirk(id: id, value: value)
            await loadQuirks()
        } catch {
            print("Failed to set quirk: \(error)")
        }
    }
}

// MARK: - WiFi Settings View
struct WifiSettingsView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var wifiStatus: WifiStatus?
    @State private var networks: [WifiNetwork] = []
    @State private var isLoading = false
    @State private var isScanning = false
    @State private var showConnectSheet = false
    @State private var selectedNetwork: WifiNetwork?
    @State private var password = ""

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            // Current Connection
            if let status = wifiStatus, let details = status.details {
                Section {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text(details.ssid ?? "Unknown")
                                .fontWeight(.medium)
                            if let signal = details.signal {
                                Text("\(signal) dBm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(status.state.capitalized)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if let ips = details.ips, !ips.isEmpty {
                        HStack {
                            Text("IP")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(ips.joined(separator: ", "))
                                .font(.caption)
                        }
                    }

                    if let freq = details.frequency {
                        HStack {
                            Text(String(localized: "wifi.frequency"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(freq.uppercased())
                                .font(.caption)
                        }
                    }
                } header: {
                    Label(String(localized: "wifi.current"), systemImage: "wifi")
                }
            }

            // Available Networks
            Section {
                if isScanning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(String(localized: "wifi.scanning"))
                            .foregroundStyle(.secondary)
                    }
                } else if networks.isEmpty {
                    Button {
                        Task { await scanNetworks() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "wifi.scan"))
                        }
                    }
                } else {
                    ForEach(networks) { network in
                        Button {
                            selectedNetwork = network
                            showConnectSheet = true
                        } label: {
                            HStack {
                                Image(systemName: network.signalIcon)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading) {
                                    Text(network.details.ssid)
                                        .foregroundStyle(.primary)
                                    Text("\(network.details.signal) dBm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if wifiStatus?.details?.ssid == network.details.ssid {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }

                    Button {
                        Task { await scanNetworks() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "wifi.rescan"))
                        }
                    }
                }
            } header: {
                Label(String(localized: "wifi.available"), systemImage: "wifi.exclamationmark")
            }
        }
        .navigationTitle(String(localized: "settings.wifi"))
        .task {
            await loadStatus()
        }
        .refreshable {
            await loadStatus()
            await scanNetworks()
        }
        .sheet(isPresented: $showConnectSheet) {
            if let network = selectedNetwork {
                NavigationStack {
                    Form {
                        Section {
                            Text(network.details.ssid)
                                .fontWeight(.medium)
                        } header: {
                            Text(String(localized: "wifi.network"))
                        }

                        Section {
                            SecureField(String(localized: "wifi.password"), text: $password)
                        }

                        Section {
                            Button {
                                Task {
                                    await connectToNetwork(network)
                                    showConnectSheet = false
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    if isLoading {
                                        ProgressView()
                                    } else {
                                        Text(String(localized: "wifi.connect"))
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(password.isEmpty || isLoading)
                        }
                    }
                    .navigationTitle(String(localized: "wifi.connect_to"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "settings.cancel")) {
                                showConnectSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func loadStatus() async {
        guard let api = api else { return }
        do {
            wifiStatus = try await api.getWifiStatus()
        } catch {
            print("Failed to load WiFi status: \(error)")
        }
    }

    private func scanNetworks() async {
        guard let api = api else { return }
        isScanning = true
        defer { isScanning = false }

        do {
            networks = try await api.scanWifi()
            // Sort by signal strength
            networks.sort { $0.details.signal > $1.details.signal }
        } catch {
            print("Failed to scan WiFi: \(error)")
        }
    }

    private func connectToNetwork(_ network: WifiNetwork) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.setWifiConfig(ssid: network.details.ssid, password: password)
            password = ""
            await loadStatus()
        } catch {
            print("Failed to connect: \(error)")
        }
    }
}

// MARK: - MQTT Settings View
struct MQTTSettingsView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var config: MQTTConfig?
    @State private var isLoading = false
    @State private var isSaving = false

    // Editable fields
    @State private var enabled = false
    @State private var host = ""
    @State private var port = "1883"
    @State private var username = ""
    @State private var password = ""
    @State private var identifier = ""
    @State private var useAuth = false
    @State private var homeAssistant = true
    @State private var homie = false
    @State private var provideMapData = true
    @State private var showPassword = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "mqtt.enabled"), isOn: $enabled)
            }

            if enabled {
                Section {
                    TextField(String(localized: "mqtt.host"), text: $host)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    TextField(String(localized: "mqtt.port"), text: $port)
                        .keyboardType(.numberPad)
                } header: {
                    Label(String(localized: "mqtt.connection"), systemImage: "network")
                }

                Section {
                    Toggle(String(localized: "mqtt.use_auth"), isOn: $useAuth)
                    if useAuth {
                        TextField(String(localized: "mqtt.username"), text: $username)
                            .autocapitalization(.none)
                        HStack {
                            if showPassword {
                                TextField(String(localized: "mqtt.password"), text: $password)
                                    .autocapitalization(.none)
                            } else {
                                SecureField(String(localized: "mqtt.password"), text: $password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Label(String(localized: "mqtt.authentication"), systemImage: "lock")
                } footer: {
                    if useAuth {
                        Text(String(localized: "mqtt.credentials_note"))
                    }
                }

                Section {
                    TextField(String(localized: "mqtt.identifier"), text: $identifier)
                        .autocapitalization(.none)
                } header: {
                    Label(String(localized: "mqtt.identity"), systemImage: "tag")
                } footer: {
                    Text(String(localized: "mqtt.identifier_desc"))
                }

                Section {
                    Toggle("Home Assistant", isOn: $homeAssistant)
                    Toggle("Homie", isOn: $homie)
                    Toggle(String(localized: "mqtt.provide_map"), isOn: $provideMapData)
                } header: {
                    Label(String(localized: "mqtt.interfaces"), systemImage: "square.stack.3d.up")
                }

                Section {
                    Button {
                        Task { await saveConfig() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text(String(localized: "settings.save"))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || host.isEmpty)
                }
            }
        }
        .navigationTitle("MQTT")
        .task {
            await loadConfig()
        }
        .overlay {
            if isLoading && config == nil {
                ProgressView()
            }
        }
    }

    private func loadConfig() async {
        guard let api = api else {
            print("[MQTT DEBUG] No API available")
            return
        }
        isLoading = true
        defer { isLoading = false }

        print("[MQTT DEBUG] Loading MQTT config...")
        do {
            config = try await api.getMQTTConfig()
            print("[MQTT DEBUG] MQTT config loaded: enabled=\(config?.enabled ?? false), host=\(config?.connection.host ?? "nil")")
            if let config = config {
                enabled = config.enabled
                host = config.connection.host
                port = String(config.connection.port)
                // Don't load redacted credentials - leave empty for user to enter new ones
                let loadedUsername = config.connection.authentication.credentials.username
                let loadedPassword = config.connection.authentication.credentials.password
                print("[MQTT DEBUG] Username from API: '\(loadedUsername)', Password: '\(loadedPassword)'")
                username = loadedUsername == "<redacted>" ? "" : loadedUsername
                password = loadedPassword == "<redacted>" ? "" : loadedPassword
                useAuth = config.connection.authentication.credentials.enabled
                identifier = config.identity.identifier
                homeAssistant = config.interfaces.homeassistant.enabled
                homie = config.interfaces.homie.enabled
                provideMapData = config.customizations.provideMapData
            }
        } catch {
            print("[MQTT DEBUG] Failed to load MQTT config: \(error)")
        }
    }

    private func saveConfig() async {
        guard let api = api, var config = config else { return }
        isSaving = true
        defer { isSaving = false }

        config.enabled = enabled
        config.connection.host = host
        config.connection.port = Int(port) ?? 1883
        config.connection.authentication.credentials.enabled = useAuth
        config.connection.authentication.credentials.username = username
        config.connection.authentication.credentials.password = password
        config.identity.identifier = identifier
        config.interfaces.homeassistant.enabled = homeAssistant
        config.interfaces.homie.enabled = homie
        config.customizations.provideMapData = provideMapData

        do {
            try await api.setMQTTConfig(config)
            self.config = config
        } catch {
            print("Failed to save MQTT config: \(error)")
        }
    }
}

// MARK: - NTP Settings View
struct NTPSettingsView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var config: NTPConfig?
    @State private var status: NTPStatus?
    @State private var isLoading = false
    @State private var isSaving = false

    @State private var enabled = true
    @State private var server = "valetudo.pool.ntp.org"
    @State private var port = "123"

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        Form {
            // Current Time Section
            if let status = status, let robotTime = status.robotTime {
                Section {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text(String(localized: "ntp.robot_time"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatRobotTime(robotTime))
                                .font(.system(.body, design: .monospaced))
                        }
                        Spacer()
                        Button {
                            Task { await loadStatus() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }

                    if let state = status.state, let lastSync = state.timestamp {
                        HStack {
                            Text(String(localized: "ntp.last_sync"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatSyncTime(lastSync))
                                .font(.caption)
                        }
                    }

                    if let state = status.state, let offset = state.offset {
                        HStack {
                            Text("Offset")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(offset) ms")
                                .font(.caption)
                        }
                    }
                } header: {
                    Label(String(localized: "ntp.status"), systemImage: "clock.badge.checkmark")
                }
            }

            Section {
                Toggle(String(localized: "ntp.enabled"), isOn: $enabled)
            }

            if enabled {
                Section {
                    TextField(String(localized: "ntp.server"), text: $server)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    TextField(String(localized: "ntp.port"), text: $port)
                        .keyboardType(.numberPad)
                } header: {
                    Label(String(localized: "ntp.config"), systemImage: "clock")
                } footer: {
                    Text(String(localized: "ntp.desc"))
                }

                Section {
                    Button {
                        Task { await saveConfig() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text(String(localized: "settings.save"))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || server.isEmpty)
                }
            }
        }
        .navigationTitle("NTP")
        .task {
            await loadConfig()
            await loadStatus()
        }
        .refreshable {
            await loadStatus()
        }
        .overlay {
            if isLoading && config == nil {
                ProgressView()
            }
        }
    }

    private func loadConfig() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            config = try await api.getNTPConfig()
            if let config = config {
                enabled = config.enabled
                server = config.server
                port = String(config.port)
            }
        } catch {
            print("Failed to load NTP config: \(error)")
        }
    }

    private func loadStatus() async {
        guard let api = api else {
            print("[NTP DEBUG] No API available")
            return
        }
        print("[NTP DEBUG] Loading NTP status...")
        do {
            status = try await api.getNTPStatus()
            print("[NTP DEBUG] NTP status loaded: \(String(describing: status))")
        } catch {
            print("[NTP DEBUG] Failed to load NTP status: \(error)")
        }
    }

    private func saveConfig() async {
        guard let api = api, var config = config else { return }
        isSaving = true
        defer { isSaving = false }

        config.enabled = enabled
        config.server = server
        config.port = Int(port) ?? 123

        do {
            try await api.setNTPConfig(config)
            self.config = config
        } catch {
            print("Failed to save NTP config: \(error)")
        }
    }

    private func formatRobotTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .medium
            return displayFormatter.string(from: date)
        }
        return isoString
    }

    private func formatSyncTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = RelativeDateTimeFormatter()
            displayFormatter.unitsStyle = .abbreviated
            return displayFormatter.localizedString(for: date, relativeTo: Date())
        }
        return isoString
    }
}

// MARK: - Valetudo Info View
struct ValetudoInfoView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var version: ValetudoVersion?
    @State private var updaterState: UpdaterState?
    @State private var hostInfo: SystemHostInfo?
    @State private var latestRelease: GitHubRelease?
    @State private var isLoading = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    private var hasUpdate: Bool {
        guard let current = updaterState?.currentVersion,
              let latest = latestRelease?.tag_name else { return false }
        return current != latest
    }

    var body: some View {
        List {
            // Update Available Banner
            if hasUpdate, let latest = latestRelease {
                Section {
                    Link(destination: URL(string: latest.html_url)!) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text(String(localized: "update.available"))
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("\(updaterState?.currentVersion ?? "") → \(latest.tag_name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Version Info
            Section {
                HStack {
                    Text("Version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Text(updaterState?.currentVersion ?? version?.release ?? "-")
                        if hasUpdate {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                        } else if latestRelease != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                if let version = version {
                    HStack {
                        Text("Commit")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(version.commit.prefix(8)))
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                if let latest = latestRelease {
                    Link(destination: URL(string: latest.html_url)!) {
                        HStack {
                            Text(String(localized: "update.latest"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(latest.tag_name)
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Label("Valetudo", systemImage: "app.badge")
            }

            if let info = hostInfo {
                Section {
                    HStack {
                        Text("Hostname")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(info.hostname)
                    }
                    HStack {
                        Text("Architecture")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(info.arch)
                    }
                    HStack {
                        Text("Uptime")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatUptime(info.uptime))
                    }
                    if let load = info.load {
                        HStack {
                            Text("Load")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f / %.2f / %.2f", load._1, load._5, load._15))
                                .font(.caption)
                        }
                    }
                } header: {
                    Label(String(localized: "info.system"), systemImage: "cpu")
                }

                Section {
                    HStack {
                        Text(String(localized: "info.total"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatBytes(info.mem.total))
                    }
                    HStack {
                        Text(String(localized: "info.free"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatBytes(info.mem.free))
                    }
                    HStack {
                        Text("Valetudo")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatBytes(info.mem.valetudo_current))
                    }

                    // Memory usage bar
                    let usedPercent = Double(info.mem.total - info.mem.free) / Double(info.mem.total)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(usedPercent > 0.8 ? Color.red : Color.blue)
                                .frame(width: geometry.size.width * usedPercent)
                        }
                    }
                    .frame(height: 8)
                } header: {
                    Label(String(localized: "info.memory"), systemImage: "memorychip")
                }
            }
        }
        .navigationTitle("Valetudo")
        .task {
            await loadInfo()
        }
        .refreshable {
            await loadInfo()
        }
        .overlay {
            if isLoading && version == nil {
                ProgressView()
            }
        }
    }

    private func loadInfo() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            version = try await api.getValetudoVersion()
            hostInfo = try await api.getSystemHostInfo()
            updaterState = try await api.getUpdaterState()
        } catch {
            print("Failed to load info: \(error)")
        }

        // Check GitHub for latest release
        await checkForUpdate()
    }

    private func checkForUpdate() async {
        guard let url = URL(string: "https://api.github.com/repos/Hypfer/Valetudo/releases/latest") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            latestRelease = try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            print("Failed to check for updates: \(error)")
        }
    }

    private func formatUptime(_ seconds: Double) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1024 / 1024
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Station Settings View (Dock/Station specific settings)
struct StationSettingsView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var isLoading = false
    @State private var isInitialLoad = true

    // Capabilities
    @State private var hasAutoEmptyDock = DebugConfig.showAllCapabilities
    @State private var hasMopDockAutoDrying = DebugConfig.showAllCapabilities
    @State private var hasMopDockWashTemperature = DebugConfig.showAllCapabilities

    // Settings
    @State private var mopDockAutoDrying = false
    @State private var mopDockWashTemperaturePresets: [String] = []
    @State private var currentWashTemperature: String = ""

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            // Auto Empty Dock Settings
            if hasAutoEmptyDock {
                Section {
                    NavigationLink {
                        AutoEmptyDockSettingsView(robot: robot)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.bin")
                                .foregroundStyle(.purple)
                            Text(String(localized: "settings.auto_empty_interval"))
                        }
                    }
                } header: {
                    Label(String(localized: "settings.auto_empty"), systemImage: "arrow.up.bin")
                } footer: {
                    Text(String(localized: "settings.auto_empty_interval_desc"))
                }
            }

            // Mop Dock Settings
            if hasMopDockAutoDrying || hasMopDockWashTemperature {
                Section {
                    if hasMopDockAutoDrying {
                        Toggle(isOn: $mopDockAutoDrying) {
                            HStack {
                                Image(systemName: "wind")
                                    .foregroundStyle(.cyan)
                                Text(String(localized: "settings.mop_auto_drying"))
                            }
                        }
                        .onChange(of: mopDockAutoDrying) { _, newValue in
                            guard !isInitialLoad else { return }
                            Task { await setMopDockAutoDrying(newValue) }
                        }
                    }

                    if hasMopDockWashTemperature {
                        Picker(selection: $currentWashTemperature) {
                            ForEach(mopDockWashTemperaturePresets.isEmpty ? ["cold", "warm", "hot"] : mopDockWashTemperaturePresets, id: \.self) { preset in
                                Text(displayNameForWashTemperature(preset)).tag(preset)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "thermometer.medium")
                                    .foregroundStyle(.orange)
                                Text(String(localized: "settings.wash_temperature"))
                            }
                        }
                        .onChange(of: currentWashTemperature) { _, newValue in
                            guard !isInitialLoad && !newValue.isEmpty else { return }
                            Task { await setWashTemperature(newValue) }
                        }
                    }
                } header: {
                    Label(String(localized: "settings.mop_dock"), systemImage: "drop.triangle")
                } footer: {
                    Text(String(localized: "settings.dock_settings_desc"))
                }
            }

            // No settings available
            if !hasAutoEmptyDock && !hasMopDockAutoDrying && !hasMopDockWashTemperature && !isLoading {
                Section {
                    Text(String(localized: "settings.no_station_settings"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "settings.section_station"))
        .task {
            await loadSettings()
        }
        .refreshable {
            await loadSettings()
        }
        .overlay {
            if isLoading && !hasAutoEmptyDock && !hasMopDockAutoDrying && !hasMopDockWashTemperature {
                ProgressView()
            }
        }
    }

    private func loadSettings() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        // Check capabilities
        do {
            let capabilities = try await api.getCapabilities()
            hasAutoEmptyDock = DebugConfig.showAllCapabilities || capabilities.contains("AutoEmptyDockAutoEmptyIntervalControlCapability")
            hasMopDockAutoDrying = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopAutoDryingControlCapability")
            hasMopDockWashTemperature = DebugConfig.showAllCapabilities || capabilities.contains("MopDockMopWashTemperatureControlCapability")
        } catch {
            // Use debug defaults
        }

        // Load mop dock auto drying
        if hasMopDockAutoDrying {
            do {
                mopDockAutoDrying = try await api.getMopDockAutoDrying()
            } catch {
                if !DebugConfig.showAllCapabilities { hasMopDockAutoDrying = false }
            }
        }

        // Load mop dock wash temperature presets
        if hasMopDockWashTemperature {
            do {
                mopDockWashTemperaturePresets = try await api.getMopDockWashTemperaturePresets()
                if let tempAttr = robotManager.robotStates[robot.id]?.attributes.first(where: {
                    $0.__class == "PresetSelectionStateAttribute" && $0.type == "mop_dock_mop_cleaning_water_temperature"
                }) {
                    currentWashTemperature = tempAttr.value ?? ""
                }
            } catch {
                if !DebugConfig.showAllCapabilities { hasMopDockWashTemperature = false }
                // Use debug defaults
                if DebugConfig.showAllCapabilities {
                    mopDockWashTemperaturePresets = ["cold", "warm", "hot"]
                    currentWashTemperature = "warm"
                }
            }
        }

        isInitialLoad = false
    }

    private func setMopDockAutoDrying(_ enabled: Bool) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockAutoDrying(enabled: enabled)
        } catch {
            print("Failed to set mop dock auto drying: \(error)")
            mopDockAutoDrying = !enabled
        }
    }

    private func setWashTemperature(_ preset: String) async {
        guard let api = api else { return }

        do {
            try await api.setMopDockWashTemperature(preset: preset)
        } catch {
            print("Failed to set wash temperature: \(error)")
        }
    }

    private func displayNameForWashTemperature(_ preset: String) -> String {
        switch preset.lowercased() {
        case "cold":
            return String(localized: "settings.wash_temp.cold")
        case "warm":
            return String(localized: "settings.wash_temp.warm")
        case "hot":
            return String(localized: "settings.wash_temp.hot")
        default:
            return preset.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }
}

#Preview {
    NavigationStack {
        RobotSettingsView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
