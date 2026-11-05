/// True when the schedule asks for Strict, whatever the permissions allow right now.
public func scheduleUsesStrict(_ schedule: Schedule) -> Bool {
    schedule.isEnabled && schedule.disciplineLevel == .strict
}

/// True when the schedule reads Strict but the break will run as Firm.
public func scheduleNeedsStrictPermission(_ schedule: Schedule, strictAvailable: Bool) -> Bool {
    scheduleUsesStrict(schedule) && !strictAvailable
}
