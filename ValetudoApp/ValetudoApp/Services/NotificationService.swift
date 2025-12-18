import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false

    private init() {
        Task {
            await checkAuthorization()
        }
    }

    // MARK: - Authorization
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            print("Notification authorization failed: \(error)")
        }
    }

    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Notifications
    func notifyCleaningComplete(robotName: String, area: Int?) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.cleaning_complete.title")

        if let area = area {
            content.body = String(localized: "notification.cleaning_complete.body_with_area \(robotName) \(area)")
        } else {
            content.body = String(localized: "notification.cleaning_complete.body \(robotName)")
        }
        content.sound = .default
        content.categoryIdentifier = "CLEANING_COMPLETE"

        scheduleNotification(content: content, identifier: "cleaning_complete_\(UUID().uuidString)")
    }

    func notifyRobotError(robotName: String, error: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.error.title \(robotName)")
        content.body = error
        content.sound = .defaultCritical
        content.categoryIdentifier = "ROBOT_ERROR"
        content.interruptionLevel = .critical

        scheduleNotification(content: content, identifier: "error_\(UUID().uuidString)")
    }

    func notifyRobotStuck(robotName: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.stuck.title")
        content.body = String(localized: "notification.stuck.body \(robotName)")
        content.sound = .defaultCritical
        content.categoryIdentifier = "ROBOT_STUCK"

        scheduleNotification(content: content, identifier: "stuck_\(UUID().uuidString)")
    }

    func notifyConsumableLow(robotName: String, consumableName: String, percent: Int) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.consumable.title \(robotName)")
        content.body = String(localized: "notification.consumable.body \(consumableName) \(percent)")
        content.sound = .default
        content.categoryIdentifier = "CONSUMABLE_LOW"

        // Only notify once per consumable per day
        let identifier = "consumable_\(robotName)_\(consumableName)"
        scheduleNotification(content: content, identifier: identifier)
    }

    func notifyRobotOffline(robotName: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.offline.title")
        content.body = String(localized: "notification.offline.body \(robotName)")
        content.sound = .default
        content.categoryIdentifier = "ROBOT_OFFLINE"

        scheduleNotification(content: content, identifier: "offline_\(robotName)")
    }

    // MARK: - Helpers
    private func scheduleNotification(content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    // MARK: - Setup Categories
    func setupCategories() {
        let goHomeAction = UNNotificationAction(
            identifier: "GO_HOME",
            title: String(localized: "action.home"),
            options: []
        )

        let locateAction = UNNotificationAction(
            identifier: "LOCATE",
            title: String(localized: "action.locate"),
            options: []
        )

        let errorCategory = UNNotificationCategory(
            identifier: "ROBOT_ERROR",
            actions: [goHomeAction, locateAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let stuckCategory = UNNotificationCategory(
            identifier: "ROBOT_STUCK",
            actions: [goHomeAction, locateAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([errorCategory, stuckCategory])
    }
}
