import UserNotifications
import OrbitCore

extension ReminderSound {
    var title: String {
        switch self {
        case .standard: "Стандартный"
        case .silent: "Без звука"
        case .chime: "Колокольчик"
        case .drop: "Капля"
        case .signal: "Сигнал"
        }
    }
    var fileName: String? {
        switch self {
        case .standard, .silent: nil
        case .chime: "orbit-chime"
        case .drop: "orbit-drop"
        case .signal: "orbit-signal"
        }
    }
    var notificationSound: UNNotificationSound? {
        if self == .silent { return nil }
        if let fileName { return UNNotificationSound(named: UNNotificationSoundName(fileName + ".wav")) }
        return .default
    }
}

