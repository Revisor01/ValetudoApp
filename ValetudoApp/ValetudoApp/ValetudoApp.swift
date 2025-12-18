import SwiftUI

@main
struct ValetudoApp: App {
    @StateObject private var robotManager = RobotManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(robotManager)
        }
    }
}
