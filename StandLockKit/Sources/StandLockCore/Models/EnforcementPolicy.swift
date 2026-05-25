import Foundation

public enum DismissMechanism: Sendable, Equatable {
    case button
    case holdButton(duration: TimeInterval)
    case typePhrase(phrase: String, requiresConfirmation: Bool)
    case keyCombo(duration: TimeInterval)
}

public struct EnforcementTier: Sendable, Equatable {
    public let skipDelay: TimeInterval
    public let dismissMechanism: DismissMechanism

    public init(skipDelay: TimeInterval, dismissMechanism: DismissMechanism) {
        self.skipDelay = skipDelay
        self.dismissMechanism = dismissMechanism
    }
}

public struct EnforcementPolicy: Sendable, Equatable {
    public let tiers: [EnforcementTier]

    public init(tiers: [EnforcementTier]) {
        precondition(!tiers.isEmpty, "EnforcementPolicy requires at least one tier")
        self.tiers = tiers
    }

    public func tier(at index: Int) -> EnforcementTier {
        tiers[min(max(index, 0), tiers.count - 1)]
    }
}
