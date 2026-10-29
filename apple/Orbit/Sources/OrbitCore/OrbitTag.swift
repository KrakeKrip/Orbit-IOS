import Foundation
import SwiftData

@Model public final class OrbitTag {
    public private(set) var id: UUID
    public private(set) var name: String
    public private(set) var createdAt: Date
    public private(set) var colorName: String?
    public static let colors = ["coral", "orange", "green", "blue", "purple", "pink", "gray"]
    public init(id: UUID = UUID(), name: String, createdAt: Date = .now, colorName: String? = nil) {
        self.id = id; self.name = name; self.createdAt = createdAt
        self.colorName = colorName
    }
    func rename(_ name: String) { self.name = name }
    func setColor(_ color: String) { colorName = color }
}
