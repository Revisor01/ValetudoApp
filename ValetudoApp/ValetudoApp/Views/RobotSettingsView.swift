import SwiftUI

struct RobotSettingsView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var volume: Double = 80
    @State private var carpetMode = false
    @State private var persistentMap = false
    @State private var isLoading = false

    // Capabilities
    @State private var hasVolumeControl = true
    @State private var hasSpeakerTest = true
    @State private var hasCarpetMode = true
    @State private var hasPersistentMap = true
    @State private var hasMappingPass = true
    @State private var hasAutoEmptyDock = false
    @State private var hasAutoEmptyTrigger = false
    @State private var hasMopDockClean = false
    @State private var hasMopDockDry = false
    @State private var hasQuirks = false

    @State private var volumeChanged = false
    @State private var showMappingAlert = false

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
            if hasCarpetMode {
                Section {
                    Toggle(isOn: $carpetMode) {
                        HStack {
                            Image(systemName: "square.grid.3x3")
                                .foregroundStyle(.orange)
                            Text(String(localized: "settings.carpet_mode"))
                        }
                    }
                    .onChange(of: carpetMode) { _, newValue in
                        Task { await setCarpetMode(newValue) }
                    }
                } header: {
                    Label(String(localized: "settings.cleaning"), systemImage: "sparkles")
                } footer: {
                    Text(String(localized: "settings.carpet_mode_desc"))
                }
            }

            // Map Settings Section
            if hasPersistentMap || hasMappingPass {
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

            // Dock Section (Auto Empty & Mop Dock)
            if hasAutoEmptyTrigger || hasMopDockClean || hasMopDockDry {
                Section {
                    if hasAutoEmptyTrigger {
                        Button {
                            Task { await triggerAutoEmpty() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.bin")
                                    .foregroundStyle(.purple)
                                Text(String(localized: "settings.empty_dustbin"))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled(isLoading)
                    }

                    if hasMopDockClean {
                        Button {
                            Task { await triggerMopClean() }
                        } label: {
                            HStack {
                                Image(systemName: "drop.triangle")
                                    .foregroundStyle(.blue)
                                Text(String(localized: "settings.clean_mop"))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled(isLoading)
                    }

                    if hasMopDockDry {
                        Button {
                            Task { await triggerMopDry() }
                        } label: {
                            HStack {
                                Image(systemName: "wind")
                                    .foregroundStyle(.cyan)
                                Text(String(localized: "settings.dry_mop"))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled(isLoading)
                    }

                    if hasAutoEmptyDock {
                        NavigationLink {
                            AutoEmptyDockSettingsView(robot: robot)
                        } label: {
                            HStack {
                                Image(systemName: "gearshape")
                                    .foregroundStyle(.gray)
                                Text(String(localized: "settings.dock_settings"))
                            }
                        }
                    }
                } header: {
                    Label(String(localized: "settings.dock"), systemImage: "house.lodge")
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

            // No settings available
            if !hasVolumeControl && !hasSpeakerTest && !hasCarpetMode && !hasPersistentMap && !hasMappingPass && !hasAutoEmptyTrigger && !hasMopDockClean && !hasMopDockDry && !hasQuirks && !isLoading {
                Section {
                    Text(String(localized: "settings.robot_no_settings"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "settings.robot_settings"))
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
    }

    private var volumeIcon: String {
        if volume == 0 { return "speaker.slash" }
        if volume < 33 { return "speaker.wave.1" }
        if volume < 66 { return "speaker.wave.2" }
        return "speaker.wave.3"
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
            hasVolumeControl = false
        }

        // Check speaker test capability (just mark as available if volume works)
        // We'll test it when the user presses the button

        // Load carpet mode
        do {
            carpetMode = try await api.getCarpetMode()
        } catch {
            hasCarpetMode = false
        }

        // Load persistent map
        do {
            persistentMap = try await api.getPersistentMap()
        } catch {
            hasPersistentMap = false
        }

        // Check capabilities
        do {
            let capabilities = try await api.getCapabilities()
            hasMappingPass = capabilities.contains("MappingPassCapability")
            hasAutoEmptyDock = capabilities.contains("AutoEmptyDockAutoEmptyIntervalControlCapability")
            hasAutoEmptyTrigger = capabilities.contains("AutoEmptyDockManualTriggerCapability")
            hasMopDockClean = capabilities.contains("MopDockCleanManualTriggerCapability")
            hasMopDockDry = capabilities.contains("MopDockDryManualTriggerCapability")
            hasQuirks = capabilities.contains("QuirksCapability")
        } catch {
            hasMappingPass = false
        }
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

    private func triggerAutoEmpty() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.triggerAutoEmptyDock()
        } catch {
            print("Failed to trigger auto empty: \(error)")
        }
    }

    private func triggerMopClean() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.triggerMopDockClean()
        } catch {
            print("Failed to trigger mop clean: \(error)")
        }
    }

    private func triggerMopDry() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.triggerMopDockDry()
        } catch {
            print("Failed to trigger mop dry: \(error)")
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
                        Picker(quirk.title, selection: Binding(
                            get: { quirk.value },
                            set: { newValue in
                                Task { await setQuirk(id: quirk.id, value: newValue) }
                            }
                        )) {
                            ForEach(quirk.options, id: \.self) { option in
                                Text(option.capitalized.replacingOccurrences(of: "_", with: " "))
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    } footer: {
                        Text(quirk.description)
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
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            quirks = try await api.getQuirks()
        } catch {
            print("Failed to load quirks: \(error)")
        }
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

#Preview {
    NavigationStack {
        RobotSettingsView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
