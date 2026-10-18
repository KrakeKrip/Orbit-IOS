import Foundation
import OrbitCore

/// Opens the iOS app's own sandbox store at one explicit URL.
/// The app never accepts launch overrides and never touches
/// any store outside its own container.
enum IOSStore {
    /// `<app sandbox>/Library/Application Support/Orbit/store.sqlite`.
    static func storeURL(fileManager: FileManager = .default) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport
            .appendingPathComponent("Orbit", isDirectory: true)
            .appendingPathComponent("store.sqlite")
    }

    /// Prepares the directory (OrbitTaskStore does not create directories itself)
    /// and opens the local store. Failure is thrown to the caller and shown
    /// as an explicit error state; the store file is never deleted and no
    /// in-memory fallback is used.
    @MainActor
    static func open() throws -> OrbitTaskStore {
        let url = storeURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return try OrbitTaskStore(storeURL: url)
    }
}
