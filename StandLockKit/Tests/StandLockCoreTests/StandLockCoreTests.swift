import Foundation
import Testing
@testable import StandLockCore

@Suite("Schedule Model Tests")
struct ScheduleModelTests {

    // MARK: - TimeWindow

    @Test func timeWindowContains() {
        let window = TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        #expect(window.contains(hour: 10, minute: 30))
        #expect(window.contains(hour: 9, minute: 0))
        #expect(!window.contains(hour: 8, minute: 59))
        #expect(!window.contains(hour: 17, minute: 0)) // exclusive end
        #expect(!window.contains(hour: 20, minute: 0))
    }

    // MARK: - DaySelection

    @Test func daySelectionActiveDays() {
        let weekdays = DaySelection.weekdays.activeDays
        #expect(weekdays.count == 5)
        #expect(weekdays.contains(.monday))
        #expect(weekdays.contains(.friday))
        #expect(!weekdays.contains(.saturday))
        #expect(!weekdays.contains(.sunday))

        let weekends = DaySelection.weekends.activeDays
        #expect(weekends.count == 2)
        #expect(weekends.contains(.saturday))
        #expect(weekends.contains(.sunday))

        let everyDay = DaySelection.everyDay.activeDays
        #expect(everyDay.count == 7)

        let custom = DaySelection.custom([.monday, .wednesday, .friday]).activeDays
        #expect(custom.count == 3)
        #expect(!custom.contains(.tuesday))
    }

    // MARK: - JSON Round-Trips

    @Test func scheduleJsonBackwardCompatibilityWithoutIntervalCycle() throws {
        let original = Schedule(
            name: "Old Schedule",
            days: .weekdays,
            windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
            breakInterval: 2400, breakDuration: 600,
            intervalCycle: [IntervalStep(duration: 2400)]
        )
        let data = try JSONEncoder().encode(original)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "intervalCycle")
        let stripped = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Schedule.self, from: stripped)
        #expect(decoded.intervalCycle == nil)
        #expect(decoded.breakInterval == 2400)
        #expect(decoded.name == "Old Schedule")
    }

    // MARK: - BreakStatistics

    @Test func breakStatisticsCompletionRate() {
        var stats = BreakStatistics()
        stats.breaksCompleted = 3
        stats.breaksSkipped = 1
        #expect(stats.totalBreaks == 4)
        #expect(stats.completionRate == 0.75)

        let emptyStats = BreakStatistics()
        #expect(emptyStats.completionRate == 0)
    }

    @Test func breakStatisticsWeeklyReset() {
        var stats = BreakStatistics(date: Date())
        stats.weeklyEscapeCount = 5

        // Same week: should NOT reset
        stats.resetWeeklyIfNeeded(currentDate: Date())
        #expect(stats.weeklyEscapeCount == 5)

        // Next week: should reset
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!
        stats.resetWeeklyIfNeeded(currentDate: nextWeek)
        #expect(stats.weeklyEscapeCount == 0)
    }

    @Test func breakStatisticsDailyResetKeepsSameDayCounters() {
        var stats = BreakStatistics(date: Date())
        stats.breaksCompleted = 4
        stats.breaksSkipped = 2
        stats.breaksEscaped = 1
        stats.breaksDeferred = 3

        #expect(stats.resetDailyIfNeeded(currentDate: Date()) == false)
        #expect(stats.breaksCompleted == 4)
        #expect(stats.breaksSkipped == 2)
        #expect(stats.breaksEscaped == 1)
        #expect(stats.breaksDeferred == 3)
    }

    @Test func breakStatisticsDailyResetClearsCountersOnNewDay() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var stats = BreakStatistics(date: yesterday)
        stats.breaksCompleted = 4
        stats.breaksSkipped = 2
        stats.breaksEscaped = 1
        stats.breaksDeferred = 3
        stats.currentStreak = 7
        stats.weeklyEscapeCount = 2

        let now = Date()
        #expect(stats.resetDailyIfNeeded(currentDate: now) == true)
        #expect(stats.breaksCompleted == 0)
        #expect(stats.breaksSkipped == 0)
        #expect(stats.breaksEscaped == 0)
        #expect(stats.breaksDeferred == 0)
        #expect(Calendar.current.isDate(stats.date, inSameDayAs: now))

        // Streak and weekly escapes span days and must survive the rollover.
        #expect(stats.currentStreak == 7)
        #expect(stats.weeklyEscapeCount == 2)
    }

    // MARK: - AppPreferences

    @Test func appPreferencesBackwardCompatibility() throws {
        let json = """
        {
            "firmSkipDelay": 20,
            "firmEscapePhrase": "skip",
            "firmDailySkipLimit": 3,
            "strictEscapeHoldDuration": 10,
            "cameraDetection": "deferBreak",
            "microphoneDetection": "deferBreak",
            "calendarDetectionEnabled": true,
            "calendarLookAheadMinutes": 5,
            "screenSharingDetectionEnabled": true,
            "focusModeDetection": "deferBreak",
            "idleDetectionEnabled": true,
            "resetIntervalOnSkip": true
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: json)
        #expect(decoded.firmSkipDelay == 20)
        #expect(decoded.pauseMediaDuringBreak == true)
    }

    @Test func appPreferencesDecodesWithoutEscalationLevel() throws {
        let json = """
        {
            "firmSkipDelay": 10,
            "escalationLevel": 2
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: json)
        #expect(decoded.firmSkipDelay == 10)
    }

    // MARK: - DisciplineLevel

    @Test func dailySkipLimitPerDisciplineLevel() {
        let prefs = AppPreferences(gentleDailySkipLimit: 4, firmDailySkipLimit: 3)
        #expect(DisciplineLevel.gentle.dailySkipLimit(preferences: prefs) == 4)
        #expect(DisciplineLevel.firm.dailySkipLimit(preferences: prefs) == 3)
        #expect(DisciplineLevel.strict.dailySkipLimit(preferences: prefs) == nil)
    }

    // MARK: - EnforcementPolicy

    @Test func enforcementPolicyFirmUsesPreferences() {
        let prefs = AppPreferences(firmSkipDelay: 20, firmEscapePhrase: "let me go")
        let policy = DisciplineLevel.firm.enforcementPolicy(preferences: prefs)
        #expect(policy.tiers.count == 5)
        #expect(policy.tiers[0].skipDelay == 20)
        #expect(policy.tiers[0].dismissMechanism == .typePhrase(phrase: "let me go", requiresConfirmation: false))
        #expect(policy.tiers[2].dismissMechanism == .slotMachine(reelCount: 3, maxAttempts: 3))
        #expect(policy.tiers[2].skipDelay == 30)
        #expect(policy.tiers[3].dismissMechanism == .typePhrase(phrase: "let me go", requiresConfirmation: true))
        #expect(policy.tiers[3].skipDelay == 35)
        #expect(policy.tiers[4].dismissMechanism == .roastChallenge(sentenceCount: 3))
        #expect(policy.tiers[4].skipDelay == 40)
    }

    /// The phrase has no Settings field: a bad one from a file or an old default would leave a
    /// Firm break that no typing can skip.
    @Test(arguments: [
        "", "   ", "skip\nnow", "skip\u{7}now", "skip\tnow", "skip\u{2028}now",
        String(repeating: "a", count: 101), "a" + String(repeating: "\u{301}", count: 500),
    ])
    func untypeableFirmPhraseFallsBackToDefault(phrase: String) {
        let policy = DisciplineLevel.firm.enforcementPolicy(preferences: AppPreferences(firmEscapePhrase: phrase))
        let expected = AppPreferences.defaultFirmEscapePhrase
        #expect(policy.tiers[0].dismissMechanism == .typePhrase(phrase: expected, requiresConfirmation: false))
        #expect(policy.tiers[3].dismissMechanism == .typePhrase(phrase: expected, requiresConfirmation: true))
    }

    @Test func firmPhraseIsTrimmedBeforeUse() {
        let policy = DisciplineLevel.firm.enforcementPolicy(preferences: AppPreferences(firmEscapePhrase: " let me go "))
        #expect(policy.tiers[0].dismissMechanism == .typePhrase(phrase: "let me go", requiresConfirmation: false))
    }

    @Test func appPreferencesDefaultPhraseConstant() throws {
        #expect(AppPreferences().firmEscapePhrase == AppPreferences.defaultFirmEscapePhrase)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        #expect(decoded.firmEscapePhrase == AppPreferences.defaultFirmEscapePhrase)
    }

    @Test func postponeReturnDelayDefaultsToTwoMinutes() throws {
        #expect(AppPreferences().postponeReturnDelay == TimeInterval(120))
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        #expect(decoded.postponeReturnDelay == TimeInterval(120))
    }

    @Test func breakSoundsDefaultToOff() throws {
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        #expect(!decoded.soundBeforeBreak)
        #expect(!decoded.soundAfterBreak)
    }

    @Test func postponedReasonDisplayName() {
        #expect(DeferralReason.postponed.displayName == "Break postponed")
    }

    @Test func enforcementPolicyStrictUsesPreferences() {
        let prefs = AppPreferences(strictEscapeHoldDuration: 8)
        let policy = DisciplineLevel.strict.enforcementPolicy(preferences: prefs)
        #expect(policy.tiers.count == 4)
        if case .keyCombo(let d) = policy.tiers[0].dismissMechanism { #expect(d == 8) }
        else { Issue.record("Expected .keyCombo") }
        if case .keyCombo(let d) = policy.tiers[1].dismissMechanism { #expect(d == 13) }
        else { Issue.record("Expected .keyCombo") }
        if case .keyCombo(let d) = policy.tiers[2].dismissMechanism { #expect(d == 18) }
        else { Issue.record("Expected .keyCombo") }
        if case .keyCombo(let d) = policy.tiers[3].dismissMechanism { #expect(d == 23) }
        else { Issue.record("Expected .keyCombo") }
    }

    @Test(arguments: [25.0, 366.0 * 86_400, Double.infinity, Double.nan])
    func strictPolicyAlwaysOffersPracticalEmergencyEscape(hold: Double) {
        let policy = DisciplineLevel.strict.enforcementPolicy(
            preferences: AppPreferences(strictEscapeHoldDuration: hold)
        )
        for tier in policy.tiers {
            guard case .keyCombo(let duration) = tier.dismissMechanism else {
                Issue.record("Expected emergency key combo")
                continue
            }
            #expect(duration.isFinite && (0...30).contains(duration))
        }
    }

    @Test(arguments: [366.0 * 86_400, Double.infinity, Double.nan])
    func firmPolicyKeepsItsRecoveryDelayBounded(delay: Double) {
        let policy = DisciplineLevel.firm.enforcementPolicy(preferences: AppPreferences(firmSkipDelay: delay))
        #expect(policy.tiers.allSatisfy { $0.skipDelay.isFinite && (0...60).contains($0.skipDelay) })
    }

    @Test func enforcementPolicyTierClampsToRange() {
        let policy = DisciplineLevel.gentle.enforcementPolicy(preferences: AppPreferences())
        let last = policy.tier(at: 99)
        #expect(last == policy.tiers[5])
        let first = policy.tier(at: -1)
        #expect(first == policy.tiers[0])
    }

    // MARK: - Schedule with Progressive Enforcement

    @Test func scheduleJsonBackwardCompatibility() throws {
        let original = Schedule(
            name: "Old Schedule",
            days: .weekdays,
            windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
            breakInterval: 2400, breakDuration: 600,
            disciplineLevel: .gentle
        )
        let data = try JSONEncoder().encode(original)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "progressiveEnforcement")
        let stripped = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Schedule.self, from: stripped)
        #expect(decoded.progressiveEnforcement == false)
        #expect(decoded.name == "Old Schedule")
    }
}

@Suite("AppPreferences Calendar Selection")
struct AppPreferencesCalendarSelectionTests {

    @Test func calendarSelectionJsonRoundTrip() throws {
        let prefs = AppPreferences(
            calendarSelectionMode: .selected,
            selectedCalendarIdentifiers: ["work", "personal"]
        )
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(decoded.calendarSelectionMode == .selected)
        #expect(decoded.selectedCalendarIdentifiers == ["work", "personal"])
        #expect(decoded == prefs)
    }

    @Test func decodesWithoutCalendarSelectionAsAllCalendars() throws {
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        #expect(decoded.calendarSelectionMode == .all)
        #expect(decoded.selectedCalendarIdentifiers.isEmpty)
    }
}
