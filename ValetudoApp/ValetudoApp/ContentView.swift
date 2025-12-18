import SwiftUI

struct ContentView: View {
    @EnvironmentObject var robotManager: RobotManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RobotListView()
            }
            .tabItem {
                Label(String(localized: "tab.robots"), systemImage: "house.fill")
            }
            .tag(0)

            SettingsView()
                .tabItem {
                    Label(String(localized: "tab.settings"), systemImage: "gearshape.fill")
                }
                .tag(1)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RobotManager())
}
