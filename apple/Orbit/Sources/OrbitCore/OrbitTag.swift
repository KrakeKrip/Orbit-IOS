import Foundation
import SwiftData

@Model public final class OrbitTag {
    public private(set) var id: UUID
    public private(set) var name: String
    public private(set) var createdAt: Date
    public init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id; self.name = name; self.createdAt = createdAt
    }
    func rename(_ name: String) { self.name = name }
}
