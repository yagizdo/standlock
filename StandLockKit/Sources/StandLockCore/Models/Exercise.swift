import Foundation

public struct Exercise: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let durationSeconds: Int?

    public init(id: UUID = UUID(), title: String, description: String,
                durationSeconds: Int? = nil) {
        self.id = id; self.title = title; self.description = description
        self.durationSeconds = durationSeconds
    }
}
