import SwiftUI

struct IntensityControlView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var fanSpeedPresets: [String] = []
    @State private var waterUsagePresets: [String] = []
    @State private var operationModePresets: [String] = []
    @State private var currentFanSpeed: String?
    @State private var currentWaterUsage: String?
    @State private var currentOperationMode: String?
    @State private var isLoading = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    private var status: RobotStatus? {
        robotManager.robotStates[robot.id]
    }

    var body: some View {
        List {
            // Operation Mode Section
            if !operationModePresets.isEmpty {
                Section {
                    ForEach(operationModePresets, id: \.self) { preset in
                        Button {
                            Task { await setOperationMode(preset) }
                        } label: {
                            HStack {
                                Image(systemName: iconForOperationMode(preset))
                                    .foregroundStyle(colorForOperationMode(preset))
                                    .frame(width: 24)
                                Text(displayNameForOperationMode(preset))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if currentOperationMode == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .disabled(isLoading)
                    }
                } header: {
                    Label(String(localized: "intensity.mode"), systemImage: "gearshape.2")
                } footer: {
                    Text(String(localized: "intensity.mode_desc"))
                }
            }

            // Fan Speed Section
            if !fanSpeedPresets.isEmpty {
                Section {
                    ForEach(fanSpeedPresets, id: \.self) { preset in
                        Button {
                            Task { await setFanSpeed(preset) }
                        } label: {
                            HStack {
                                Image(systemName: iconForFanSpeed(preset))
                                    .foregroundStyle(colorForPreset(preset))
                                    .frame(width: 24)
                                Text(displayNameForPreset(preset))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if currentFanSpeed == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .disabled(isLoading)
                    }
                } header: {
                    Label(String(localized: "intensity.fanspeed"), systemImage: "fan")
                }
            }

            // Water Usage Section
            if !waterUsagePresets.isEmpty {
                Section {
                    ForEach(waterUsagePresets, id: \.self) { preset in
                        Button {
                            Task { await setWaterUsage(preset) }
                        } label: {
                            HStack {
                                Image(systemName: iconForWaterUsage(preset))
                                    .foregroundStyle(colorForPreset(preset))
                                    .frame(width: 24)
                                Text(displayNameForPreset(preset))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if currentWaterUsage == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .disabled(isLoading)
                    }
                } header: {
                    Label(String(localized: "intensity.water"), systemImage: "drop")
                }
            }

            if fanSpeedPresets.isEmpty && waterUsagePresets.isEmpty && operationModePresets.isEmpty && !isLoading {
                Section {
                    Text(String(localized: "intensity.not_supported"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "intensity.title"))
        .task {
            await loadPresets()
        }
        .refreshable {
            await loadPresets()
        }
        .overlay {
            if isLoading && fanSpeedPresets.isEmpty && waterUsagePresets.isEmpty && operationModePresets.isEmpty {
                ProgressView()
            }
        }
    }

    // MARK: - Data Loading
    private func loadPresets() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        // Load fan speed presets
        do {
            fanSpeedPresets = try await api.getFanSpeedPresets()
            // Get current value from robot state
            if let fanSpeedAttr = status?.attributes.first(where: {
                $0.__class == "PresetSelectionStateAttribute" && $0.type == "fan_speed"
            }) {
                currentFanSpeed = fanSpeedAttr.value
            }
        } catch {
            print("Fan speed not supported: \(error)")
        }

        // Load water usage presets
        do {
            waterUsagePresets = try await api.getWaterUsagePresets()
            // Get current value from robot state
            if let waterAttr = status?.attributes.first(where: {
                $0.__class == "PresetSelectionStateAttribute" && $0.type == "water_grade"
            }) {
                currentWaterUsage = waterAttr.value
            }
        } catch {
            print("Water usage not supported: \(error)")
        }

        // Load operation mode presets
        do {
            operationModePresets = try await api.getOperationModePresets()
            // Get current value from robot state
            if let modeAttr = status?.attributes.first(where: {
                $0.__class == "PresetSelectionStateAttribute" && $0.type == "operation_mode"
            }) {
                currentOperationMode = modeAttr.value
            }
        } catch {
            print("Operation mode not supported: \(error)")
        }
    }

    // MARK: - Actions
    private func setFanSpeed(_ preset: String) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.setFanSpeed(preset: preset)
            currentFanSpeed = preset
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Failed to set fan speed: \(error)")
        }
    }

    private func setWaterUsage(_ preset: String) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.setWaterUsage(preset: preset)
            currentWaterUsage = preset
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Failed to set water usage: \(error)")
        }
    }

    private func setOperationMode(_ preset: String) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.setOperationMode(preset: preset)
            currentOperationMode = preset
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Failed to set operation mode: \(error)")
        }
    }

    // MARK: - Display Helpers
    private func displayNameForPreset(_ preset: String) -> String {
        switch preset.lowercased() {
        case "off": return String(localized: "preset.off")
        case "min": return String(localized: "preset.min")
        case "low": return String(localized: "preset.low")
        case "medium": return String(localized: "preset.medium")
        case "high": return String(localized: "preset.high")
        case "max": return String(localized: "preset.max")
        case "turbo": return String(localized: "preset.turbo")
        default: return preset.capitalized
        }
    }

    private func iconForFanSpeed(_ preset: String) -> String {
        switch preset.lowercased() {
        case "off": return "fan.slash"
        case "min", "low": return "fan"
        case "medium", "high": return "fan.fill"
        case "max", "turbo": return "wind"
        default: return "fan"
        }
    }

    private func iconForWaterUsage(_ preset: String) -> String {
        switch preset.lowercased() {
        case "off": return "drop.slash"
        case "min", "low": return "drop"
        case "medium": return "drop.fill"
        case "high", "max": return "drop.circle.fill"
        default: return "drop"
        }
    }

    private func colorForPreset(_ preset: String) -> Color {
        switch preset.lowercased() {
        case "off": return .gray
        case "min": return .green
        case "low": return .mint
        case "medium": return .blue
        case "high": return .orange
        case "max", "turbo": return .red
        default: return .blue
        }
    }

    // Operation Mode Helpers
    private func displayNameForOperationMode(_ preset: String) -> String {
        switch preset.lowercased() {
        case "vacuum": return String(localized: "mode.vacuum")
        case "mop": return String(localized: "mode.mop")
        case "vacuum_and_mop": return String(localized: "mode.vacuum_and_mop")
        case "vacuum_then_mop": return String(localized: "mode.vacuum_then_mop")
        default: return preset.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func iconForOperationMode(_ preset: String) -> String {
        switch preset.lowercased() {
        case "vacuum": return "tornado"
        case "mop": return "drop.fill"
        case "vacuum_and_mop", "vacuum_then_mop": return "sparkles"
        default: return "gearshape"
        }
    }

    private func colorForOperationMode(_ preset: String) -> Color {
        switch preset.lowercased() {
        case "vacuum": return .orange
        case "mop": return .blue
        case "vacuum_and_mop", "vacuum_then_mop": return .purple
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        IntensityControlView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
