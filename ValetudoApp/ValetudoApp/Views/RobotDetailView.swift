import SwiftUI

struct RobotDetailView: View {
    @EnvironmentObject var robotManager: RobotManager
    let robot: RobotConfig

    @State private var segments: [Segment] = []
    @State private var consumables: [Consumable] = []
    @State private var selectedSegments: Set<String> = []
    @State private var isLoading = false
    @State private var showMap = false
    @State private var showTimers = false

    private var status: RobotStatus? {
        robotManager.robotStates[robot.id]
    }

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            // Status Section
            statusSection

            // Control Section
            if status?.isOnline == true {
                controlSection

                // Consumables Preview (top)
                consumablesPreviewSection

                // Rooms
                roomsSection

                // Intensity Control (Fan Speed / Water Usage)
                Section {
                    NavigationLink {
                        IntensityControlView(robot: robot)
                    } label: {
                        HStack {
                            Label(String(localized: "intensity.title"), systemImage: "slider.horizontal.3")
                            Spacer()
                            // Show current fan speed if available
                            if let fanSpeed = status?.attributes.first(where: {
                                $0.__class == "PresetSelectionStateAttribute" && $0.type == "fan_speed"
                            })?.value {
                                Text(fanSpeed.capitalized)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Statistics
                Section {
                    NavigationLink {
                        StatisticsView(robot: robot)
                    } label: {
                        Label(String(localized: "stats.title"), systemImage: "chart.bar")
                    }
                }

                // Timer Link
                Section {
                    NavigationLink {
                        TimersView(robot: robot)
                    } label: {
                        Label(String(localized: "timers.title"), systemImage: "clock")
                    }

                    NavigationLink {
                        DoNotDisturbView(robot: robot)
                    } label: {
                        Label(String(localized: "dnd.title"), systemImage: "moon.fill")
                    }

                    NavigationLink {
                        RobotSettingsView(robot: robot)
                    } label: {
                        Label(String(localized: "settings.robot_settings"), systemImage: "gearshape")
                    }
                }
            }
        }
        .navigationTitle(robot.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showMap = true
                } label: {
                    Image(systemName: "map")
                }
                .disabled(status?.isOnline != true)
            }
        }
        .sheet(isPresented: $showMap) {
            MapView(robot: robot)
        }
        .task {
            await loadData()
        }
        .refreshable {
            await robotManager.refreshRobot(robot.id)
            await loadData()
        }
    }

    // MARK: - Status Section
    @ViewBuilder
    private var statusSection: some View {
        Section {
            // Online status with blue icon and colored dot on right
            HStack {
                Image(systemName: "wifi")
                    .foregroundStyle(.blue)
                Text(status?.isOnline == true ?
                     String(localized: "robot.online") :
                     String(localized: "robot.offline"))
                Spacer()
                Circle()
                    .fill(status?.isOnline == true ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
            }

            if let battery = status?.batteryLevel {
                HStack {
                    Label(String(localized: "robot.battery"), systemImage: "battery.100")
                    Spacer()
                    Text("\(battery)%")
                        .foregroundStyle(.secondary)
                    if status?.batteryStatus == "charging" {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            }

            if let statusValue = status?.statusValue {
                HStack {
                    Label("Status", systemImage: "info.circle")
                    Spacer()
                    StatusBadge(status: statusValue)
                }
            }

            if let info = status?.info {
                if let model = info.modelName {
                    HStack {
                        Label("Model", systemImage: "cpu")
                        Spacer()
                        Text(model)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Control Section
    @ViewBuilder
    private var controlSection: some View {
        Section {
            HStack(spacing: 12) {
                ControlButton(title: String(localized: "action.start"), icon: "play.fill", color: .green) {
                    await performAction(.start)
                }

                ControlButton(title: String(localized: "action.pause"), icon: "pause.fill", color: .orange) {
                    await performAction(.pause)
                }

                ControlButton(title: String(localized: "action.stop"), icon: "stop.fill", color: .red) {
                    await performAction(.stop)
                }

                ControlButton(title: String(localized: "action.home"), icon: "house.fill", color: .blue) {
                    await performAction(.home)
                }
            }
            .buttonStyle(.plain)

            Button {
                Task { await locate() }
            } label: {
                Label(String(localized: "action.locate"), systemImage: "speaker.wave.3.fill")
            }
        }
    }

    // MARK: - Consumables Preview
    @ViewBuilder
    private var consumablesPreviewSection: some View {
        if !consumables.isEmpty {
            Section {
                NavigationLink {
                    ConsumablesView(robot: robot)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(String(localized: "consumables.title"), systemImage: "wrench.and.screwdriver")
                            Spacer()
                            // Show warning if any consumable is low
                            if consumables.contains(where: { $0.remainingPercent < 20 }) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }

                        // Mini preview of consumables
                        HStack(spacing: 16) {
                            ForEach(consumables.prefix(4)) { consumable in
                                VStack(spacing: 4) {
                                    Image(systemName: consumable.icon)
                                        .font(.caption)
                                        .foregroundStyle(consumable.iconColor)
                                    Text(consumable.remainingDisplay)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Rooms Section
    @ViewBuilder
    private var roomsSection: some View {
        if !segments.isEmpty {
            Section(String(localized: "rooms.title")) {
                ForEach(segments) { segment in
                    Button {
                        toggleSegment(segment.id)
                    } label: {
                        HStack {
                            Text(segment.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedSegments.contains(segment.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !selectedSegments.isEmpty {
                    Button {
                        Task { await cleanSelectedRooms() }
                    } label: {
                        Label(String(localized: "rooms.clean_selected"), systemImage: "play.fill")
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    // MARK: - Actions
    private func performAction(_ action: BasicAction) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.basicControl(action: action)
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Action failed: \(error)")
        }
    }

    private func locate() async {
        guard let api = api else { return }
        try? await api.locate()
    }

    private func loadData() async {
        guard let api = api else { return }
        async let segmentsTask: () = loadSegments()
        async let consumablesTask: () = loadConsumables()
        _ = await (segmentsTask, consumablesTask)
    }

    private func loadSegments() async {
        guard let api = api else { return }
        do {
            segments = try await api.getSegments()
        } catch {
            print("Failed to load segments: \(error)")
        }
    }

    private func loadConsumables() async {
        guard let api = api else { return }
        do {
            consumables = try await api.getConsumables()
        } catch {
            print("Failed to load consumables: \(error)")
        }
    }

    private func toggleSegment(_ id: String) {
        if selectedSegments.contains(id) {
            selectedSegments.remove(id)
        } else {
            selectedSegments.insert(id)
        }
    }

    private func cleanSelectedRooms() async {
        guard let api = api, !selectedSegments.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.cleanSegments(ids: Array(selectedSegments))
            selectedSegments.removeAll()
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Clean failed: \(error)")
        }
    }
}

// MARK: - Control Button
struct ControlButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    NavigationStack {
        RobotDetailView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
