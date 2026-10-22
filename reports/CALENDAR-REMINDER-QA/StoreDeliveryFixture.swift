// Only the explicitly owned synthetic Simulator store is accepted. Stop Orbit
// before running this helper; never use it on a physical/personal container.
import Foundation
@main struct StoreDeliveryFixture {
    @MainActor static func main() throws {
        precondition(CommandLine.arguments.count == 2)
        let path = CommandLine.arguments[1]
        precondition(path.hasPrefix("/Users/atlhnv/Library/Developer/CoreSimulator/Devices/B99DFA70-E656-4B53-829F-47641F036CEC/data/Containers/Data/Application/"))
        precondition(path.hasSuffix("/Library/Application Support/Orbit/store.sqlite"))
        precondition(FileManager.default.fileExists(atPath: path))
        let store = try OrbitTaskStore(storeURL: URL(fileURLWithPath: path))
        let now = ceil(Date.now.timeIntervalSince1970)
        for (title, delta) in [("QA · Orbit foreground delivery", 30.0), ("QA · Orbit terminated delivery", 75.0)] {
            let task = try store.addTask(title: title, reminderAt: Date(timeIntervalSince1970: now + delta))
            print("\(task.title): \(task.id), fireAt \(now + delta)")
        }
        print("Own synthetic count: \(try store.tasks().count)")
    }
}
