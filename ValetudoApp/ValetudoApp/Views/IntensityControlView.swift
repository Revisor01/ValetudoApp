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
                                Image(systemName: OperationModeHelpers.icon(for: preset))
                                    .foregroundStyle(OperationModeHelpers.color(for: preset))
                                    .frame(width: 24)
                                Text(OperationModeHelpers.displayName(for: preset))
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
                                Image(systemName: FanSpeedHelpers.icon(for: preset))
                                    .foregroundStyle(PresetHelpers.color(for: preset))
                                    .frame(width: 24)
                                Text(PresetHelpers.displayName(for: preset))
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
                                Image(systemName: WaterUsageHelpers.icon(for: preset))
                                    .foregroundStyle(PresetHelpers.color(for: preset))
                                    .frame(width: 24)
                                Text(PresetHelpers.displayName(for: preset))
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

}

#Preview {
    NavigationStack {
        IntensityControlView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
