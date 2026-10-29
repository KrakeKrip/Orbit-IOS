import Foundation

/// Conservative, offline suggestions. The editor applies these only on explicit tap.
public struct TaskQuickInput: Equatable, Sendable {
    public var title: String
    public var day: String?
    public var time: String?
    public var duration: Int?
    public static func parse(_ text: String, now: Date = .now, calendar: Calendar = .current) -> Self? {
        var title = text
        var day: String?
        var time: String?
        var duration: Int?
        func extract(_ pattern: String) -> [String]? {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) else { return nil }
            let ns = title as NSString
            let values = (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : ns.substring(with: match.range(at: $0)) }
            title = regex.stringByReplacingMatches(in: title, range: match.range, withTemplate: " ")
            return values
        }
        if let values = extract("(?<![\\p{L}])(?:сегодня|завтра|послезавтра)(?![\\p{L}])") {
            let word = values[0].lowercased()
            let offset = word == "сегодня" ? 0 : word == "завтра" ? 1 : 2
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            day = TaskPlannedDate.civilDateString(from: date, calendar: calendar)
        }
        if let values = extract("(?<![\\p{L}])в\\s+([0-9]{1,2}):([0-9]{2})(?![0-9])") {
            let value = String(format: "%02d:%02d", Int(values[1]) ?? -1, Int(values[2]) ?? -1)
            guard TaskTimeInterval.isValidTime(value) else { return nil }
            time = value
        }
        if time != nil, let values = extract("(?<![\\p{L}])на\\s+(?:([0-9]+)\\s*(минут(?:у|ы)?|мин|час(?:а|ов)?)|час)(?![\\p{L}])") {
            let count = values[1].isEmpty ? 1 : Int(values[1]) ?? 0
            guard count <= 1440 else { return nil }
            duration = count * (values[1].isEmpty || values[2].lowercased().hasPrefix("час") ? 60 : 1)
            guard let duration, TaskTimeInterval.isWritableDuration(duration) else { return nil }
        }
        guard day != nil || time != nil else { return nil }
        if time != nil && day == nil { day = TaskPlannedDate.civilDateString(from: now, calendar: calendar) }
        title = title.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !title.isEmpty else { return nil }
        return Self(title: title, day: day, time: time, duration: time == nil ? nil : duration ?? 30)
    }
}
