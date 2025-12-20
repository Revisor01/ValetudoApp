import SwiftUI

@main
struct ValetudoApp: App {
    @StateObject private var robotManager = RobotManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(robotManager)
            } else {
                OnboardingView()
                    .environmentObject(robotManager)
            }
        }
    }
}
