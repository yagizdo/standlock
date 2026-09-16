public struct CalendarInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let source: String

    public init(id: String, title: String, source: String) {
        self.id = id
        self.title = title
        self.source = source
    }
}
