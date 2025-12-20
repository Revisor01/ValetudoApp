import SwiftUI

struct RobotListView: View {
    @EnvironmentObject var robotManager: RobotManager
    @Binding var selectedRobotId: UUID?
    @State private var showAddRobot = false
    @State private var navigateToRobot: RobotConfig?

    var body: some View {
        List {
            if robotManager.robots.isEmpty {
                ContentUnavailableView(
                    String(localized: "robots.empty"),
                    systemImage: "house.fill",
                    description: Text("robots.add")
                )
            } else {
                ForEach(robotManager.robots) { robot in
                    Button {
                        selectedRobotId = robot.id
                        navigateToRobot = robot
                    } label: {
                        RobotRowView(
                            robot: robot,
                            status: robotManager.robotStates[robot.id],
                            hasUpdate: robotManager.robotUpdateAvailable[robot.id] ?? false
                        )
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteRobots)
            }
        }
        .navigationDestination(item: $navigateToRobot) { robot in
            RobotDetailView(robot: robot)
        }
        .onChange(of: navigateToRobot) { oldValue, newValue in
            // Only clear selection when navigating BACK from detail view (not when switching tabs)
            if oldValue != nil && newValue == nil {
                selectedRobotId = nil
            }
        }
        .navigationTitle(String(localized: "robots.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddRobot = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddRobot) {
            AddRobotView()
        }
        .refreshable {
            await robotManager.refreshAllRobots()
        }
    }

    private func deleteRobots(at offsets: IndexSet) {
        for index in offsets {
            robotManager.removeRobot(robotManager.robots[index].id)
        }
    }
}

// MARK: - Robot Row
struct RobotRowView: View {
    let robot: RobotConfig
    let status: RobotStatus?
    var hasUpdate: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Online indicator dot
            Circle()
                .fill(status?.isOnline == true ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                // Robot name
                HStack(spacing: 6) {
                    Text(robot.name)
                        .font(.headline)

                    // Update indicator
                    if hasUpdate {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // Model name + Battery
                HStack(spacing: 8) {
                    // Model name
                    if let model = status?.info?.modelName {
                        Text(model)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Battery if online
                    if let battery = status?.batteryLevel {
                        HStack(spacing: 3) {
                            Image(systemName: batteryIcon(level: battery, charging: status?.batteryStatus == "charging"))
                            Text("\(battery)%")
                        }
                        .font(.caption)
                        .foregroundStyle(batteryColor(level: battery))
                    }
                }
            }

            Spacer()

            // Status badge on the right
            if status?.isOnline == true, let statusValue = status?.statusValue {
                StatusBadge(status: statusValue)
            } else {
                StatusBadge(status: "offline")
            }
        }
        .padding(.vertical, 4)
    }

    private func batteryIcon(level: Int, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        switch level {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryColor(level: Int) -> Color {
        switch level {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(localizedStatus)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var localizedStatus: String {
        switch status.lowercased() {
        case "idle": return String(localized: "status.idle")
        case "cleaning": return String(localized: "status.cleaning")
        case "paused": return String(localized: "status.paused")
        case "returning": return String(localized: "status.returning")
        case "docked": return String(localized: "status.docked")
        case "error": return String(localized: "status.error")
        case "offline": return String(localized: "robot.offline")
        default: return status
        }
    }

    private var statusColor: Color {
        switch status.lowercased() {
        case "cleaning": return .blue
        case "paused": return .orange
        case "returning": return .purple
        case "error", "offline": return .red
        default: return .green
        }
    }
}

#Preview {
    NavigationStack {
        RobotListView(selectedRobotId: .constant(nil))
            .environmentObject(RobotManager())
    }
}
