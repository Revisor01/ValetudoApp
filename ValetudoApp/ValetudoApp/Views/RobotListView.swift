import SwiftUI

struct RobotListView: View {
    @EnvironmentObject var robotManager: RobotManager
    @State private var showAddRobot = false

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
                    NavigationLink(destination: RobotDetailView(robot: robot)) {
                        RobotRowView(robot: robot, status: robotManager.robotStates[robot.id])
                    }
                }
                .onDelete(perform: deleteRobots)
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

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(robot.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    // Battery if online
                    if let battery = status?.batteryLevel {
                        Label("\(battery)%", systemImage: batteryIcon(level: battery, charging: status?.batteryStatus == "charging"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        RobotListView()
            .environmentObject(RobotManager())
    }
}
