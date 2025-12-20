import SwiftUI

struct ContentView: View {
    @EnvironmentObject var robotManager: RobotManager
    @State private var selectedTab = 0
    @State private var selectedRobotId: UUID?

    private var selectedRobot: RobotConfig? {
        guard let id = selectedRobotId else { return nil }
        return robotManager.robots.first { $0.id == id }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RobotListView(selectedRobotId: $selectedRobotId)
            }
            .tabItem {
                Label(String(localized: "tab.robots"), systemImage: "house.fill")
            }
            .tag(0)

            // Map Tab - only shows when a robot is selected
            if let robot = selectedRobot {
                MapTabView(robot: robot)
                    .id("map-\(robot.id)") // Force complete refresh when robot changes
                    .tabItem {
                        Label(String(localized: "tab.map"), systemImage: "map.fill")
                    }
                    .tag(1)
            }

            SettingsView()
                .tabItem {
                    Label(String(localized: "tab.settings"), systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .onChange(of: selectedRobotId) { _, newId in
            // When robot is deselected and we're on map tab, switch to robots tab
            if newId == nil && selectedTab == 1 {
                selectedTab = 0
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RobotManager())
}
