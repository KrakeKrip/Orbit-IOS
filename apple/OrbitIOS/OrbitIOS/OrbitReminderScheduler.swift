import Foundation
import Observation
import UIKit
import UserNotifications
import OrbitCore
import AVFAudio

/// System authorization is requested only by an explicit reminder control.
/// Store commits stay successful even when system scheduling needs a retry.
@MainActor
@Observable
final class OrbitReminderScheduler {
    @ObservationIgnored private lazy var client = IOSReminderNotificationClient()
    @ObservationIgnored private var started = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var previewPlayer: AVAudioPlayer?
    @ObservationIgnored private var previewRevision = 0
    @ObservationIgnored private var previewID: String?
    private(set) var sound: ReminderSound
    private(set) var soundPreviewError: String?
    private var entries: [ReminderEntry] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sound = defaults.string(forKey: "orbit.reminder.sound").flatMap(ReminderSound.init(rawValue:)) ?? .standard
    }

    func setSound(_ value: ReminderSound) {
        guard value != sound else { return }
        stopSoundPreview()
        soundPreviewError = nil
        sound = value
        defaults.set(value.rawValue, forKey: "orbit.reminder.sound")
        refresh()
    }

    func stopSoundPreview() {
        previewRevision += 1
        previewPlayer?.stop(); previewPlayer = nil
        if started {
            client.soundPreviewIdentifier = nil
            if let previewID {
                client.removePending([previewID])
                client.removeDelivered([previewID])
            }
        }
        previewID = nil
    }

    func previewSound(_ value: ReminderSound) async {
        start()
        stopSoundPreview()
        soundPreviewError = nil
        let revision = previewRevision
        guard value != .silent else { return }
        do {
            if let file = value.fileName {
                guard let url = Bundle.main.url(forResource: file, withExtension: "wav") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                try AVAudioSession.sharedInstance().setCategory(.ambient)
                let player = try AVAudioPlayer(contentsOf: url)
                previewPlayer = player
                guard player.play() else { throw CocoaError(.fileReadUnknown) }
            } else {
                await requestAuthorization()
                guard previewRevision == revision else { return }
                let authorization = await client.authorization()
                guard previewRevision == revision else { return }
                guard authorization == .authorized else {
                    soundPreviewError = "Разрешите уведомления, чтобы прослушать системный звук."
                    return
                }
                let identifier = IOSReminderNotificationClient.previewPrefix + UUID().uuidString
                previewID = identifier
                client.soundPreviewIdentifier = identifier
                try await client.add(ReminderRequest(identifier: identifier,
                    title: "Проверка звука уведомлений", fireAt: Date(timeIntervalSince1970: ceil(Date.now.timeIntervalSince1970 + 1))))
                if previewRevision != revision { client.removePending([identifier]) }
            }
        } catch {
            guard previewRevision == revision else { return }
            soundPreviewError = "Не удалось прослушать звук. \(error.localizedDescription)"
        }
    }
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
        synchronizer.update(entries, sound: sound)
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
