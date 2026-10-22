import Foundation
import UserNotifications
import OrbitCore

@MainActor
final class IOSReminderNotificationClient: NSObject, ReminderNotificationClient, UNUserNotificationCenterDelegate {
    let center = UNUserNotificationCenter.current()
    var shouldPresent: (UNNotificationRequest) -> Bool = { _ in false }
    var didDeliver: () -> Void = {}
    var soundPreviewIdentifier: String?
    static let previewPrefix = "orbit.sound-preview."
    override init() { super.init(); center.delegate = self }

    func authorization() async -> ReminderAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
    func pending() async -> [ReminderRequest] {
        await center.pendingNotificationRequests().map { request in
            ReminderRequest(identifier: request.identifier, title: request.content.body,
                            fireAt: (request.content.userInfo["fireAt"] as? Double)
                                .map(Date.init(timeIntervalSince1970:)) ?? .distantPast,
                            sound: (request.content.userInfo["sound"] as? String).flatMap(ReminderSound.init(rawValue:)) ?? .standard)
        }
    }
    func deliveredIDs() async -> [String] {
        await center.deliveredNotifications().map { $0.request.identifier }
    }
    func add(_ request: ReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Orbit"
        content.body = request.title
        content.sound = request.sound.notificationSound
        content.userInfo = ["fireAt": request.fireAt.timeIntervalSince1970, "sound": request.sound.rawValue]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.fireAt)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
    }
    func removePending(_ identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    func removeDelivered(_ identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await MainActor.run {
            if notification.request.identifier.hasPrefix(Self.previewPrefix) {
                return notification.request.identifier == soundPreviewIdentifier ? [.sound] : []
            }
            let visible = shouldPresent(notification.request)
            didDeliver()
            return visible ? [.banner, .list, .sound] : []
        }
    }
}

