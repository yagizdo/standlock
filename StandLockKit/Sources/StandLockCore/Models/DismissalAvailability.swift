/// One decision shared by the coordinator, menu, break screen, and keyboard handler.
public struct DismissalAvailability: Equatable, Sendable {
    public let normalSkipAllowed: Bool
    public let emergencyEscapeAllowed: Bool
    public let remainingConsecutiveSkips: Int?

    public init(progressiveEnforcement: Bool = false, consecutiveSkipLimit: Int? = nil,
                consecutiveDismissals: Int = 0, dailySkipLimit: Int? = nil, dailySkips: Int = 0) {
        let remaining = progressiveEnforcement ? consecutiveSkipLimit.map {
            max(0, min(20, max(1, $0)) - max(0, consecutiveDismissals))
        } : nil
        remainingConsecutiveSkips = remaining
        emergencyEscapeAllowed = remaining != 0
        normalSkipAllowed = emergencyEscapeAllowed && dailySkipLimit.map { dailySkips < $0 } != false
    }
}
