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

    public func dailySkipLimit(preferences: AppPreferences) -> Int? {
        switch self {
        case .gentle: preferences.gentleDailySkipLimit
        case .firm: preferences.firmDailySkipLimit
        case .strict: nil
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

extension DisciplineLevel {
    public func enforcementPolicy(preferences: AppPreferences) -> EnforcementPolicy {
        switch self {
        case .gentle:
            return EnforcementPolicy(tiers: [
                EnforcementTier(skipDelay: 0, dismissMechanism: .button),
                EnforcementTier(skipDelay: 5, dismissMechanism: .button),
                EnforcementTier(skipDelay: 10, dismissMechanism: .findButton(count: 8, attempts: 3)),
                EnforcementTier(skipDelay: 12, dismissMechanism: .crateOpening(slotCount: 12, maxAttempts: 3)),
                EnforcementTier(skipDelay: 14, dismissMechanism: .slotMachine(reelCount: 3, maxAttempts: 3)),
                EnforcementTier(skipDelay: 16, dismissMechanism: .typePhrase(phrase: "My legs are decorative", requiresConfirmation: false)),
            ])
        case .firm:
            let phrase = preferences.firmEscapePhrase
            let base = preferences.firmSkipDelay
            return EnforcementPolicy(tiers: [
                EnforcementTier(skipDelay: base, dismissMechanism: .typePhrase(phrase: phrase, requiresConfirmation: false)),
                EnforcementTier(skipDelay: base + 5, dismissMechanism: .typePhrase(phrase: phrase, requiresConfirmation: false)),
                EnforcementTier(skipDelay: base + 10, dismissMechanism: .slotMachine(reelCount: 3, maxAttempts: 3)),
                EnforcementTier(skipDelay: base + 15, dismissMechanism: .typePhrase(phrase: phrase + " I really mean it", requiresConfirmation: true)),
                EnforcementTier(skipDelay: base + 20, dismissMechanism: .roastChallenge(sentenceCount: 3)),
            ])
        case .strict:
            let hold = preferences.strictEscapeHoldDuration
            return EnforcementPolicy(tiers: [
                EnforcementTier(skipDelay: 0, dismissMechanism: .keyCombo(duration: hold)),
                EnforcementTier(skipDelay: 0, dismissMechanism: .keyCombo(duration: hold + 5)),
                EnforcementTier(skipDelay: 0, dismissMechanism: .keyCombo(duration: hold + 10)),
                EnforcementTier(skipDelay: 0, dismissMechanism: .keyCombo(duration: hold + 15)),
            ])
        }
    }
}
