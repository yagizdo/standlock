public enum DisciplineLevel: String, Codable, Sendable, CaseIterable {
    case gentle
    case firm
    case strict

    public var displayName: String {
        switch self {
        case .gentle: "Gentle"
        case .firm: "Firm"
        case .strict: "Strict"
        }
    }

    public var description: String {
        switch self {
        case .gentle: "Full-screen overlay with immediate skip button"
        case .firm: "Overlay with delayed skip and phrase-to-escape"
        case .strict: "Full input blocking with emergency escape combo"
        }
    }
}
