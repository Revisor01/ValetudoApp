import SwiftUI

struct RobotSettingsView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var volume: Double = 80
    @State private var carpetMode = false
    @State private var persistentMap = false
    @State private var isLoading = false

    @State private var hasVolumeControl = true
    @State private var hasSpeakerTest = true
    @State private var hasCarpetMode = true
    @State private var hasPersistentMap = true
    @State private var hasMappingPass = true

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

            // No settings available
            if !hasVolumeControl && !hasSpeakerTest && !hasCarpetMode && !hasPersistentMap && !hasMappingPass && !isLoading {
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

        // Check if mapping pass is available (we check via capabilities)
        do {
            let capabilities = try await api.getCapabilities()
            hasMappingPass = capabilities.contains("MappingPassCapability")
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
}

#Preview {
    NavigationStack {
        RobotSettingsView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
