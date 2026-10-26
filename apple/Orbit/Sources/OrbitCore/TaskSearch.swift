import Foundation

/// Read-only query over existing fields; does not change task order or storage.
public struct TaskSearch {
    public enum Status: String, CaseIterable { case all, open, completed }
    public var text = ""
    public var tagID: UUID?
    public var projectID: UUID?
    public var status: Status = .all
    public var undatedOnly = false
    public var unassignedOnly = false
    public init() {}

    public func results(in tasks: [OrbitTask]) -> [OrbitTask] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
        return tasks.filter { task in
            (tagID == nil || (task.tagIDs ?? []).contains(tagID!))
                && (projectID == nil || task.projectID == projectID)
                && (!undatedOnly || task.plannedDate == nil)
                && (!unassignedOnly || task.projectID == nil)
                && (status == .all || (status == .completed) == task.isCompleted)
                && (query.isEmpty || task.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU")).contains(query))
        }
    }
}
