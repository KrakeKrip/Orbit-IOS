import Foundation
import Observation
import UIKit
import UserNotifications
import OrbitCore

@MainActor
final class IOSReminderNotificationClient: NSObject, ReminderNotificationClient, UNUserNotificationCenterDelegate {
    let center = UNUserNotificationCenter.current()
    var shouldPresent: (UNNotificationRequest) -> Bool = { _ in false }
    var didDeliver: () -> Void = {}
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
                                .map(Date.init(timeIntervalSince1970:)) ?? .distantPast)
        }
    }
    func deliveredIDs() async -> [String] {
        await center.deliveredNotifications().map { $0.request.identifier }
    }
    func add(_ request: ReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Orbit"
        content.body = request.title
        content.sound = .default
        content.userInfo = ["fireAt": request.fireAt.timeIntervalSince1970]
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
            let visible = shouldPresent(notification.request)
            didDeliver()
            return visible ? [.banner, .list, .sound] : []
        }
    }
}

/// System authorization is requested only by an explicit reminder control.
/// Store commits stay successful even when system scheduling needs a retry.
@MainActor
@Observable
final class OrbitReminderScheduler {
    @ObservationIgnored private lazy var client = IOSReminderNotificationClient()
    @ObservationIgnored private var started = false
    private var entries: [ReminderEntry] = []
    private(set) var status = ReminderSyncStatus()
    private(set) var isRequesting = false
    private(set) var authorizationError: String?
    @ObservationIgnored private lazy var synchronizer = ReminderSynchronizer(client: client) { [weak self] status in
        self?.status = status
        if status.authorization == .authorized && status.error == nil { self?.authorizationError = nil }
    }

    func start() {
        guard !started else { return }
        started = true
        client.shouldPresent = { [weak self] request in
            guard let self, let entry = self.entries.first(where: {
                ReminderRequest.prefix + $0.taskID.uuidString == request.identifier
            }), !entry.completed, let date = entry.fireAt,
                let timestamp = request.content.userInfo["fireAt"] as? Double else { return false }
            return entry.title == request.content.body && abs(date.timeIntervalSince1970 - timestamp) < 0.5
        }
        client.didDeliver = { [weak self] in self?.refresh() }
        refresh()
    }
    func update(_ tasks: [OrbitTask]) {
        entries = tasks.map { ReminderEntry(taskID: $0.id, title: $0.title, fireAt: $0.reminderAt, completed: $0.isCompleted) }
        refresh()
    }
    func refresh() {
        guard started else { return }
        synchronizer.update(entries)
    }
    func requestAuthorization() async {
        start()
        guard !isRequesting else { return }
        isRequesting = true
        authorizationError = nil
        defer { isRequesting = false; refresh() }
        if await client.authorization() != .denied {
            do {
                let granted = try await client.center.requestAuthorization(options: [.alert, .sound])
                if !granted { authorizationError = "Система не разрешила уведомления. Проверьте настройки уведомлений Orbit." }
            }
            catch { authorizationError = "Не удалось запросить уведомления: \(error.localizedDescription)" }
        }
    }
    func openSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    var message: String {
        if let authorizationError { return authorizationError }
        if let error = status.error { return error }
        switch status.authorization {
        case .unknown: return "Проверяем доступ к уведомлениям…"
        case .notDetermined: return "Разрешите уведомления, чтобы Orbit напоминал о задачах."
        case .denied: return "Уведомления выключены. Включите их: Настройки → Приложения → Orbit → Уведомления."
        case .authorized:
            if status.deferredCount > 0 {
                return "Ближайшие напоминания запланированы. Ещё \(status.deferredCount) ждут очереди: откройте Orbit позже для обновления."
            }
            return "Уведомления разрешены. Запланировано: \(status.scheduledIDs.count). Фокусирование и настройки iPhone могут отключать звук или показ."
        }
    }
}
