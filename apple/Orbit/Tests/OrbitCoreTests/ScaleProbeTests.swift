import Foundation
import Testing
@testable import OrbitCore

@Suite("Synthetic scale probe") @MainActor struct ScaleProbeTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ORBIT_SCALE_PROBE"] == "1"))
    func measureStores() throws {
        for count in [1000, 5000, 10000] {
            let dir = try TempDir.make(); defer { TempDir.remove(dir) }
            let url = dir.appendingPathComponent("store")
            let projects = (0..<100).map { OrbitProject(name: "Project \($0)") }
            let tasks = (0..<count).map { index in
                OrbitTask(title: "Synthetic task \(index) with a longer title for search", plannedDate: "2026-10-30", projectID: projects[index % 100].id)
            }
            let store = try OrbitTaskStore(storeURL: url)
            var start = Date()
            _ = try store.restore(OrbitBackup(projects: projects, tasks: tasks))
            let restore = Date().timeIntervalSince(start)
            start = Date()
            let reopened = try OrbitTaskStore(storeURL: url)
            let loaded = try reopened.tasks()
            let load = Date().timeIntervalSince(start)
            #expect(loaded.count == count)
            var query = TaskSearch(); query.text = "task 999"
            start = Date(); let matches = query.results(in: loaded)
            let search = Date().timeIntervalSince(start)
            #expect(!matches.isEmpty)
            start = Date(); let data = try reopened.backup().encoded()
            let export = Date().timeIntervalSince(start)
            start = Date(); try reopened.setCompleted(true, for: Array(loaded.prefix(100).map(\.id)))
            let bulk = Date().timeIntervalSince(start)
            print("SCALE count=\(count) restore=\(restore)s open=\(load)s search=\(search)s export=\(export)s bulk100=\(bulk)s bytes=\(data.count)")
        }
    }
}
