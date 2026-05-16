import Foundation
import UserNotifications

final class NotificationService {
    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                AppLog.app.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            } else {
                AppLog.app.info("Notification authorization granted=\(granted, privacy: .public)")
            }
        }
    }

    func send(title: String, body: String, enabled: Bool) {
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLog.app.error("Failed to send notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
