import Foundation

public struct EscapeDetector: Sendable {
    public let requiredDuration: TimeInterval
    public private(set) var holdStartTime: Date?
    public private(set) var isHolding: Bool = false

    public init(requiredDuration: TimeInterval = 10.0) {
        self.requiredDuration = requiredDuration
    }

    public mutating func flagsChanged(
        controlDown: Bool, optionDown: Bool,
        commandDown: Bool, at time: Date
    ) {
        let allHeld = controlDown && optionDown && commandDown
        if allHeld && !isHolding {
            holdStartTime = time
            isHolding = true
        } else if !allHeld {
            holdStartTime = nil
            isHolding = false
        }
    }

    public func isEscapeTriggered(at currentTime: Date) -> Bool {
        guard let start = holdStartTime else { return false }
        return currentTime.timeIntervalSince(start) >= requiredDuration
    }

    public mutating func reset() {
        holdStartTime = nil
        isHolding = false
    }
}
