import Foundation
import Testing
import OrbitCore

@Suite("Task reminders")
struct TaskReminderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Future validation, atomic creation and scheduling independence survive reopen")
    @MainActor func store() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("test.store")
        let id: UUID; let project: UUID
        let due = now.addingTimeInterval(3600)
        do {
            let s = try OrbitTaskStore(storeURL: url)
            let p = try s.addProject(name: "Проект"); project = p.id
            let t = try s.addTask(title: "Напомнить", now: now, projectID: p.id, deadlineDate: "2027-01-01", reminderAt: due)
            id = t.id
            #expect(t.plannedDate == nil && t.reminderAt == due)
            for invalid in [now, now.addingTimeInterval(-1)] {
                #expect(throws: TaskReminderError.past) { try s.addTask(title: "Нет", now: now, reminderAt: invalid) }
                #expect(throws: TaskReminderError.past) { try s.setReminderAt(invalid, for: id, now: now) }
                #expect(try s.tasks().count == 1 && t.reminderAt == due)
            }
            for invalid in [Date(timeIntervalSince1970: .infinity), Date(timeIntervalSince1970: .nan), Date(timeIntervalSince1970: 7_258_118_400), now.addingTimeInterval(1.5)] {
                #expect(throws: TaskReminderError.invalidDate) { try s.addTask(title: "Нет", now: now, reminderAt: invalid) }
                #expect(try s.tasks().count == 1)
            }
            let missing = UUID()
            #expect(throws: OrbitStoreError.taskNotFound(id: missing)) { try s.setReminderAt(nil, for: missing) }
            try s.setPlannedDate("2027-01-02", for: id)
            try s.setPlannedInterval(plannedTime: "09:08", durationMinutes: 7, for: id)
            try s.renameTask(title: "Новое название", for: id)
            try s.setDeadlineDate("2027-01-03", for: id)
            try s.setProject(nil, for: id)
            try s.setCompleted(true, for: id, at: now)
            #expect(t.reminderAt == due)
            #expect(throws: TaskReminderError.completedTask) { try s.setReminderAt(due.addingTimeInterval(600), for: id, now: now) }
            // An unchanged stored reminder is a no-op even after it has elapsed.
            try s.setReminderAt(due, for: id, now: due.addingTimeInterval(1))
            #expect(t.reminderAt == due)
            try s.setCompleted(false, for: id)
            try s.setProject(p.id, for: id)
        }
        let s = try OrbitTaskStore(storeURL: url)
        let t = try #require(s.tasks().first)
        #expect(t.id == id && t.createdAt == now && t.completedAt == nil)
        #expect(t.reminderAt == due && t.projectID == project && t.deadlineDate == "2027-01-03")
        #expect(t.plannedDate == "2027-01-02" && t.plannedTime == "09:08" && t.durationMinutes == 7)
        try s.setReminderAt(nil, for: id, now: due.addingTimeInterval(1))
        #expect(t.reminderAt == nil && t.durationMinutes == 7)
        try s.setReminderAt(due.addingTimeInterval(120), for: id, now: due)
        #expect(t.reminderAt == due.addingTimeInterval(120))
        #expect(OrbitTask(title: "Old init").reminderAt == nil)
        #expect(try s.addTask(title: "Old create").reminderAt == nil)
    }

    @Test("Plan orders nearest first, respects a bounded budget, excludes elapsed and completed")
    func planner() {
        let entries = (0..<70).map { i in
            ReminderEntry(taskID: UUID(), title: "\(i)", fireAt: now.addingTimeInterval(Double(i + 1) * 60), completed: false)
        }
        let extras = [ReminderEntry(taskID: UUID(), title: "past", fireAt: now, completed: false),
                      ReminderEntry(taskID: UUID(), title: "complete", fireAt: now.addingTimeInterval(30), completed: true),
                      ReminderEntry(taskID: UUID(), title: "unset", fireAt: nil, completed: false)]
        let result = ReminderPlanner.requests((entries + extras).reversed(), now: now, capacity: 64)
        #expect(result.count == 64 && result.first?.title == "0" && result.last?.title == "63")
        #expect(ReminderPlanner.requests(entries, now: now, capacity: -1).isEmpty)
        let tie = [UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, UUID(uuidString: "00000000-0000-0000-0000-000000000001")!]
            .map { ReminderEntry(taskID: $0, title: "tie", fireAt: now.addingTimeInterval(1), completed: false) }
        #expect(ReminderPlanner.requests(tie, now: now, capacity: 1).first?.identifier.hasSuffix("0001") == true)
    }

    @Test("Reconciliation is idempotent across restart, replaces rename/time, cancels clear/complete/delete")
    @MainActor func sync() async throws {
        let client = FakeNotifications()
        var status = ReminderSyncStatus()
        let sync = ReminderSynchronizer(client: client, clock: { now }) { status = $0 }
        let id = UUID(); let fire = now.addingTimeInterval(3600)
        func entry(_ title: String = "Task", _ date: Date? = nil, completed: Bool = false) -> ReminderEntry {
            ReminderEntry(taskID: id, title: title, fireAt: date ?? fire, completed: completed)
        }
        sync.update([entry()]); await sync.waitUntilIdle()
        #expect(client.requests.count == 1 && client.addCount == 1 && status.scheduledIDs.count == 1)
        sync.update([entry()]); await sync.waitUntilIdle()
        let restarted = ReminderSynchronizer(client: client, clock: { now }) { status = $0 }
        restarted.update([entry()]); await restarted.waitUntilIdle()
        #expect(client.addCount == 1)
        let foreign = ReminderRequest(identifier: "other.feature", title: "Foreign", fireAt: fire)
        client.requests.append(foreign)
        sync.update([entry("Renamed", fire.addingTimeInterval(120))]); await sync.waitUntilIdle()
        #expect(client.requests.contains(foreign) && client.addCount == 2)
        #expect(client.requests.first { $0.identifier != foreign.identifier }?.title == "Renamed")
        client.delivered = [ReminderRequest.prefix + id.uuidString, "foreign.delivered"]
        sync.update([entry(completed: true)]); await sync.waitUntilIdle()
        #expect(client.requests == [foreign] && client.delivered == ["foreign.delivered"])
        sync.update([entry()]); await sync.waitUntilIdle()
        #expect(client.requests.count == 2)
        sync.update([ReminderEntry(taskID: id, title: "Task", fireAt: nil, completed: false)]); await sync.waitUntilIdle()
        #expect(client.requests == [foreign])
        sync.update([entry()]); await sync.waitUntilIdle()
        sync.update([]); await sync.waitUntilIdle()
        #expect(client.requests == [foreign])
    }

    @Test("Denied permission cancels pending, errors stay visible and retry recovers; capacity counts foreign requests")
    @MainActor func failures() async {
        let client = FakeNotifications(); var status = ReminderSyncStatus()
        let sync = ReminderSynchronizer(client: client, clock: { now }) { status = $0 }
        let e = ReminderEntry(taskID: UUID(), title: "Task", fireAt: now.addingTimeInterval(60), completed: false)
        client.failAdd = true
        sync.update([e]); await sync.waitUntilIdle()
        #expect(status.error != nil && status.scheduledIDs.isEmpty)
        client.failAdd = false
        sync.update([e]); await sync.waitUntilIdle()
        #expect(status.error == nil && status.scheduledIDs.count == 1)
        client.permission = .denied
        sync.update([e]); await sync.waitUntilIdle()
        #expect(client.requests.isEmpty && status.authorization == .denied)
        client.permission = .notDetermined
        sync.update([e]); await sync.waitUntilIdle()
        #expect(client.requests.isEmpty && status.authorization == .notDetermined)
        client.permission = .authorized
        client.requests = (0..<64).map { ReminderRequest(identifier: "foreign.\($0)", title: "F", fireAt: now.addingTimeInterval(600)) }
        sync.update([e]); await sync.waitUntilIdle()
        #expect(client.requests.count == 64 && status.deferredCount == 1)
    }

    @Test("A delayed add after completion cannot leave a stale notification queued")
    @MainActor func staleAdd() async {
        let client = FakeNotifications(); client.holdAdd = true
        let e = ReminderEntry(taskID: UUID(), title: "Task", fireAt: now.addingTimeInterval(600), completed: false)
        let sync = ReminderSynchronizer(client: client, clock: { now }) { _ in }
        sync.update([e])
        await client.waitForAdd()
        sync.update([ReminderEntry(taskID: e.taskID, title: e.title, fireAt: e.fireAt, completed: true)])
        client.releaseAdd()
        await sync.waitUntilIdle()
        #expect(client.requests.isEmpty)
        // Superseding a pending add with a new time/title queues only the newest version.
        client.holdAdd = true
        sync.update([e]); await client.waitForAdd()
        let changed = ReminderEntry(taskID: e.taskID, title: "New", fireAt: now.addingTimeInterval(1200), completed: false)
        sync.update([changed]); client.releaseAdd(); await sync.waitUntilIdle()
        #expect(client.requests.count == 1 && client.requests.first?.title == "New" && client.requests.first?.fireAt == changed.fireAt)
    }

    @Test("Actual previous deadline/project binary upgrades with nil reminder", .enabled(if: ProcessInfo.processInfo.environment["ORBIT_REMINDER_FIXTURE"] != nil))
    @MainActor func upgrade() throws {
        let path = try #require(ProcessInfo.processInfo.environment["ORBIT_REMINDER_FIXTURE"])
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("upgrade.store")
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: path + suffix)
            if FileManager.default.fileExists(atPath: source.path) { try FileManager.default.copyItem(at: source, to: URL(fileURLWithPath: url.path + suffix)) }
        }
        let oracle = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path + ".json"))) as? [String: String])
        let s = try OrbitTaskStore(storeURL: url)
        let t = try #require(s.tasks().first)
        #expect(t.id.uuidString == oracle["task"] && t.projectID?.uuidString == oracle["project"])
        #expect(t.reminderAt == nil && t.deadlineDate == "2026-10-20" && t.title == "Старая задача")
        #expect(t.createdAt == Date(timeIntervalSince1970: 100) && t.completedAt == Date(timeIntervalSince1970: 200))
        #expect(t.plannedDate == "2026-10-16" && t.plannedTime == "23:08" && t.durationMinutes == 100)
        try s.setCompleted(false, for: t.id)
        try s.setReminderAt(now.addingTimeInterval(60), for: t.id, now: now)
        let reopened = try OrbitTaskStore(storeURL: url)
        #expect(try reopened.tasks().first?.reminderAt == now.addingTimeInterval(60))
        #expect(try reopened.tasks().first?.id == t.id)
    }
}

@MainActor
private final class FakeNotifications: ReminderNotificationClient {
    var permission: ReminderAuthorization = .authorized
    var requests: [ReminderRequest] = []
    var delivered: [String] = []
    var failAdd = false
    var holdAdd = false
    var addCount = 0
    private var held: CheckedContinuation<Void, Never>?
    private var entered: CheckedContinuation<Void, Never>?
    func authorization() async -> ReminderAuthorization { permission }
    func pending() async -> [ReminderRequest] { requests }
    func deliveredIDs() async -> [String] { delivered }
    func add(_ request: ReminderRequest) async throws {
        addCount += 1
        if holdAdd {
            await withCheckedContinuation { held = $0; entered?.resume(); entered = nil }
        }
        if failAdd { throw CocoaError(.fileWriteUnknown) }
        requests.removeAll { $0.identifier == request.identifier }
        requests.append(request)
    }
    func removePending(_ ids: [String]) { requests.removeAll { ids.contains($0.identifier) } }
    func removeDelivered(_ ids: [String]) { delivered.removeAll { ids.contains($0) } }
    func waitForAdd() async {
        if held != nil { return }
        await withCheckedContinuation { entered = $0 }
    }
    func releaseAdd() { holdAdd = false; held?.resume(); held = nil }
}
