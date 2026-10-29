import SwiftUI
import WidgetKit

struct WidgetTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let day: String?
    let time: String?
}
struct OrbitEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
}
struct OrbitProvider: TimelineProvider {
    func placeholder(in context: Context) -> OrbitEntry { OrbitEntry(date: .now, tasks: []) }
    func getSnapshot(in context: Context, completion: @escaping (OrbitEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<OrbitEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(Date.now.addingTimeInterval(900))))
    }
    private func entry() -> OrbitEntry {
        let data = UserDefaults(suiteName: "group.local.orbit.ios")?.data(forKey: "orbit.widget.tasks")
        let all = data.flatMap { try? JSONDecoder().decode([WidgetTask].self, from: $0) } ?? []
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: .now)
        let today = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        return OrbitEntry(date: .now, tasks: all.filter { $0.day == today })
    }
}
struct OrbitWidgetView: View {
    var entry: OrbitEntry
    @Environment(\.widgetFamily) private var family
    private func taskURL(_ task: WidgetTask) -> URL {
        URL(string: "orbit://task/\(task.id.uuidString)")!
    }
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                VStack { Image(systemName: "checklist"); Text("\(entry.tasks.count)").font(.headline) }
            case .accessoryInline:
                Text(entry.tasks.first.map { "Orbit: " + $0.title } ?? "Orbit · Нет задач на сегодня")
            default:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Сегодня · \(entry.tasks.count)").font(.headline)
                    if entry.tasks.isEmpty { Text("Нет запланированных задач").font(.caption).foregroundStyle(.secondary) }
                    ForEach(entry.tasks.prefix(family == .accessoryRectangular ? 1 : family == .systemSmall ? 2 : 4)) { task in
                        if family == .systemMedium {
                            Link(destination: taskURL(task)) { taskRow(task) }
                        } else {
                            taskRow(task)
                        }
                    }
                    if family == .systemSmall || family == .systemMedium { Spacer(minLength: 0) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.widgetURL((family == .accessoryRectangular || family == .accessoryInline) ? entry.tasks.first.map(taskURL) ?? URL(string: "orbit://today") : URL(string: "orbit://today"))
            .privacySensitive().containerBackground(.background, for: .widget)
    }
    private func taskRow(_ task: WidgetTask) -> some View {
        HStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.89, green: 0.29, blue: 0.24)).frame(width: 3)
            VStack(alignment: .leading) {
                Text(task.title).font(.subheadline).lineLimit(2)
                if let time = task.time {
                    Text(time).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.fixedSize(horizontal: false, vertical: true)
    }

}
@main
struct OrbitWidgets: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OrbitToday", provider: OrbitProvider()) { OrbitWidgetView(entry: $0) }
            .configurationDisplayName("Сегодня в Orbit")
            .description("Задачи на сегодня. Нажмите, чтобы открыть Orbit.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
