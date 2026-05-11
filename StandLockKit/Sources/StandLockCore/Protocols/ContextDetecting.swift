public protocol ContextDetecting: Sendable {
    func currentContext() async -> DetectionContext
}
