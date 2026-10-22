// Isolated Simulator harness. Compiles the production notification adapter and
// ReminderSynchronizer unchanged. No Orbit store or personal device is used.
import SwiftUI
import UserNotifications
import OrbitCore

@MainActor @Observable final class Probe {
    let client = IOSReminderNotificationClient()
    var log = "Isolated notification probe"
    var sync: ReminderSynchronizer?
    let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    init() {
        client.shouldPresent = { _ in true }
        client.didDeliver = { [weak self] in self?.record("FOREGROUND delegate received") }
    }
    func record(_ message: String) {
        log += "\n" + message
        let url = URL.documentsDirectory.appendingPathComponent("probe.log")
        let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (old + "\(Date.now): \(message)\n").write(to: url, atomically: true, encoding: .utf8)
    }
    func check(_ result: Bool, _ name: String) throws {
        guard result else { throw NSError(domain: "Probe", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
        record("PASS " + name)
    }
    func authorize() async {
        do {
            let allowed = try await client.center.requestAuthorization(options: [.alert, .sound])
            record("Authorization: \(allowed)")
        } catch { record("ERROR \(error)") }
    }
    func queueChecks() async {
        do {
            try check(await client.authorization() == .authorized, "authorized")
            let fire = Date(timeIntervalSince1970: ceil(Date.now.timeIntervalSince1970) + 600)
            let engine = ReminderSynchronizer(client: client) { _ in }
            sync = engine
            func entry(_ title: String, _ at: Date?, _ done: Bool = false) -> ReminderEntry {
                ReminderEntry(taskID: taskID, title: title, fireAt: at, completed: done)
            }
            let first = entry("Initial", fire)
            engine.update([first]); await engine.waitUntilIdle()
            var pending = await client.pending()
            try check(pending.count == 1 && pending[0].title == "Initial", "initial queue")
            let raw = await client.center.pendingNotificationRequests()
            let trigger = raw.first?.trigger as? UNCalendarNotificationTrigger
            try check(trigger?.nextTriggerDate() == fire, "UTC trigger matches absolute instant")
            let shifted = fire.addingTimeInterval(120)
            engine.update([entry("Renamed", shifted)]); await engine.waitUntilIdle()
            pending = await client.pending()
            try check(pending.count == 1 && pending[0].title == "Renamed" && pending[0].fireAt == shifted, "rename and reschedule replace old request")
            engine.update([entry("Renamed", shifted)], sound: .silent); await engine.waitUntilIdle()
            let silent = await client.center.pendingNotificationRequests()
            try check(silent.count == 1 && silent[0].content.sound == nil, "global silent sound replaces queued sound")
            engine.update([entry("Renamed", shifted, true)]); await engine.waitUntilIdle()
            try check(await client.pending().isEmpty, "completion cancels")
            engine.update([first]); await engine.waitUntilIdle()
            engine.update([entry("Initial", nil)]); await engine.waitUntilIdle()
            try check(await client.pending().isEmpty, "clear cancels")
            engine.update([first]); await engine.waitUntilIdle()
            engine.update([]); await engine.waitUntilIdle()
            try check(await client.pending().isEmpty, "delete cancels")
        } catch { record("FAIL \(error.localizedDescription)") }
    }
    func scheduleDelivery() async {
        let now = ceil(Date.now.timeIntervalSince1970)
        let engine = ReminderSynchronizer(client: client) { _ in }
        sync = engine
        engine.update([
            ReminderEntry(taskID: taskID, title: "Foreground delivery", fireAt: Date(timeIntervalSince1970: now + 15), completed: false),
            ReminderEntry(taskID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, title: "Terminated delivery", fireAt: Date(timeIntervalSince1970: now + 45), completed: false)
        ])
        await engine.waitUntilIdle()
        record("Delivery queued: \(await client.pending().count), base \(now)")
    }
    func inspect() async {
        let delivered = await client.center.deliveredNotifications()
        record("Delivered: " + delivered.map { $0.request.content.body }.sorted().joined(separator: ", "))
        record("Pending: \(await client.pending().count)")
    }
}
@main struct NotificationProbe: App {
    @State var probe = Probe()
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 18) {
                Text("Orbit notification probe").font(.headline)
                Button("1. Authorize") { Task { await probe.authorize() } }
                Button("2. Queue checks") { Task { await probe.queueChecks() } }
                Button("3. Schedule delivery") { Task { await probe.scheduleDelivery() } }
                Button("4. Inspect delivered") { Task { await probe.inspect() } }
                ScrollView { Text(probe.log).font(.caption.monospaced()).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding()
        }
    }
}
