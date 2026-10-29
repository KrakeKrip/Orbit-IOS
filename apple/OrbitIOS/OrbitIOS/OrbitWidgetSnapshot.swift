import Foundation
import OrbitCore
import WidgetKit

enum OrbitWidgetSnapshot {
    private struct Entry: Codable {
        let id: UUID
        let title: String
        let day: String?
        let time: String?
    }
    static func update(_ tasks: [OrbitTask]) {
        let entries = tasks.filter { !$0.isCompleted && $0.plannedDate != nil }
            .sorted { ($0.plannedDate ?? "", $0.plannedTime ?? "", $0.id.uuidString) < ($1.plannedDate ?? "", $1.plannedTime ?? "", $1.id.uuidString) }
            .map { Entry(id: $0.id, title: $0.title, day: $0.plannedDate, time: $0.plannedTime) }
        guard let data = try? JSONEncoder().encode(entries),
              let defaults = UserDefaults(suiteName: "group.local.orbit.ios"),
              data != defaults.data(forKey: "orbit.widget.tasks") else { return }
        defaults.set(data, forKey: "orbit.widget.tasks")
        WidgetCenter.shared.reloadTimelines(ofKind: "OrbitToday")
    }
}
