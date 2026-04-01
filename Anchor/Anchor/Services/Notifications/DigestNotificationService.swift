import UserNotifications

struct DigestNotificationService {

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func scheduleImmediateNotification(for digest: WeeklyDigest) {
        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Digest is Ready"
        content.body = String(digest.narrativeParagraph.prefix(120)) + "…"
        content.sound = .default
        content.categoryIdentifier = "DIGEST"

        let request = UNNotificationRequest(
            identifier: "digest-\(digest.id)",
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
