public enum EscalationLevel: Int, Codable, Sendable, Comparable, CaseIterable {
    case off = 0
    case gentle = 1
    case firm = 2
    case strict = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .off: "Off"
        case .gentle: "Gentle"
        case .firm: "Firm"
        case .strict: "Strict"
        }
    }
}
