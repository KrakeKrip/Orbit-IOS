import Foundation

public enum TaskReminderError: Error, Equatable {
    case invalidDate
    case past
    case completedTask
}

public enum TaskReminder {
    /// Whole-second instants in the product's UTC year range; future writes only.
    public static func validate(_ value: Date?, now: Date) throws {
        guard let value else { return }
        guard value.timeIntervalSince1970.isFinite,
              value.timeIntervalSince1970.rounded(.towardZero) == value.timeIntervalSince1970,
              value >= Date(timeIntervalSince1970: -2_208_988_800),
              value < Date(timeIntervalSince1970: 7_258_118_400) else { throw TaskReminderError.invalidDate }
        guard value > now else { throw TaskReminderError.past }
    }
}

/// Value snapshots only: never hold SwiftData model objects across suspension.
public struct ReminderEntry: Equatable, Sendable {
    public let taskID: UUID
    public let title: String
    public let fireAt: Date?
    public let completed: Bool
    public init(taskID: UUID, title: String, fireAt: Date?, completed: Bool) {
        self.taskID = taskID; self.title = title; self.fireAt = fireAt; self.completed = completed
    }
}

/// One device-wide preference, never stored on individual tasks.
public enum ReminderSound: String, CaseIterable, Sendable {
    case standard, silent, chime, drop, signal
}

public struct ReminderRequest: Equatable, Sendable {
    public static let prefix = "orbit.reminder."
    public let identifier: String
    public let title: String
    public let fireAt: Date
    public let sound: ReminderSound
    public init(identifier: String, title: String, fireAt: Date, sound: ReminderSound = .standard) {
        self.sound = sound
        self.identifier = identifier; self.title = title; self.fireAt = fireAt
    }
}

public enum ReminderAuthorization: Equatable, Sendable {
    case unknown, notDetermined, denied, authorized
}

public struct ReminderSyncStatus: Sendable {
    public var authorization: ReminderAuthorization = .unknown
    public var scheduledIDs: Set<String> = []
    public var deferredCount = 0
    public var error: String?
    public init() {}
}

public enum ReminderPlanner {
    /// Conservative per-app budget; foreign notification identifiers are left alone.
    public static let maximumPending = 64
    public static func requests(_ entries: [ReminderEntry], now: Date, capacity: Int, sound: ReminderSound = .standard) -> [ReminderRequest] {
        entries.compactMap { entry -> ReminderRequest? in
            guard !entry.completed, let date = entry.fireAt,
                  (try? TaskReminder.validate(date, now: now)) != nil else { return nil }
            return ReminderRequest(identifier: ReminderRequest.prefix + entry.taskID.uuidString,
                                   title: entry.title, fireAt: date, sound: sound)
        }
        .sorted { ($0.fireAt, $0.identifier) < ($1.fireAt, $1.identifier) }
        .prefix(max(0, capacity)).map { $0 }
    }
}

@MainActor
public protocol ReminderNotificationClient: AnyObject {
    func authorization() async -> ReminderAuthorization
    func pending() async -> [ReminderRequest]
    func deliveredIDs() async -> [String]
    func add(_ request: ReminderRequest) async throws
    func removePending(_ identifiers: [String])
    func removeDelivered(_ identifiers: [String])
}

/// One serial worker coalesces reloads. A stale async add is removed before
/// processing the newest snapshot, so completion/clear/delete cannot leave it queued.
@MainActor
public final class ReminderSynchronizer {
    private let client: any ReminderNotificationClient
    private let clock: () -> Date
    private let publish: (ReminderSyncStatus) -> Void
    private var entries: [ReminderEntry] = []
    private var sound: ReminderSound = .standard
    private var revision = 0
    private var worker: Task<Void, Never>?

    public init(client: any ReminderNotificationClient, clock: @escaping () -> Date = { .now },
                publish: @escaping (ReminderSyncStatus) -> Void) {
        self.client = client; self.clock = clock; self.publish = publish
    }
    public func update(_ entries: [ReminderEntry], sound: ReminderSound = .standard) {
        self.entries = entries; self.sound = sound; revision += 1
        if worker == nil { worker = Task { await drain() } }
    }
    public func waitUntilIdle() async { await worker?.value }

    private func drain() async {
        while true {
            let version = revision
            let snapshot = entries
            let snapshotSound = sound
            let authorization = await client.authorization()
            let pending = await client.pending()
            let delivered = await client.deliveredIDs()
            guard revision == version else { continue }
            let foreign = pending.filter { !$0.identifier.hasPrefix(ReminderRequest.prefix) }.count
            let all = ReminderPlanner.requests(snapshot, now: clock(), capacity: snapshot.count, sound: snapshotSound)
            let desired = authorization == .authorized
                ? Array(all.prefix(max(0, ReminderPlanner.maximumPending - foreign))) : []
            let desiredIDs = Set(desired.map(\.identifier))
            let activeIDs = Set(snapshot.filter { !$0.completed && $0.fireAt != nil }
                .map { ReminderRequest.prefix + $0.taskID.uuidString })
            client.removePending(pending.filter {
                $0.identifier.hasPrefix(ReminderRequest.prefix) && !desiredIDs.contains($0.identifier)
            }.map(\.identifier))
            client.removeDelivered(delivered.filter {
                $0.hasPrefix(ReminderRequest.prefix) && (!activeIDs.contains($0) || desiredIDs.contains($0))
            })
            var status = ReminderSyncStatus()
            status.authorization = authorization
            status.deferredCount = authorization == .authorized ? all.count - desired.count : 0
            for request in desired {
                guard revision == version else { break }
                guard request.fireAt > clock() else { continue }
                if pending.contains(request) { continue }
                do {
                    try await client.add(request)
                    if revision != version { client.removePending([request.identifier]); break }
                } catch {
                    // An obsolete replacement must not keep its prior time/title queued.
                    client.removePending([request.identifier])
                    status.error = "Не удалось запланировать уведомление: \(error.localizedDescription)"
                }
            }
            guard revision == version else { continue }
            let verified = await client.pending()
            guard revision == version else { continue }
            status.scheduledIDs = Set(verified.filter { desired.contains($0) }.map(\.identifier))
            let stillFuture = desired.filter { $0.fireAt > clock() }
            if status.error == nil && stillFuture.contains(where: { !status.scheduledIDs.contains($0.identifier) }) {
                status.error = "Не все уведомления запланированы. Повторите попытку."
            }
            publish(status)
            worker = nil
            return
        }
    }
}
