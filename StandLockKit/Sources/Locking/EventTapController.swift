import CoreGraphics
import ApplicationServices
import Foundation

public final class EventTapController: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    public private(set) var isActive: Bool = false
    public private(set) var isBlocking: Bool = false
    private let onEscapeTriggered: @Sendable () -> Void
    var escapeDetector: EscapeDetector

    public init(
        escapeHoldDuration: TimeInterval = 10.0,
        onEscapeTriggered: @escaping @Sendable () -> Void
    ) {
        self.onEscapeTriggered = onEscapeTriggered
        self.escapeDetector = EscapeDetector(requiredDuration: escapeHoldDuration)
    }

    public var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }
    public var hasInputMonitoringPermission: Bool { CGPreflightListenEventAccess() }

    public func startBlocking() {
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: userInfo
        )

        if eventTap != nil {
            isBlocking = true
        } else {
            eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: eventMask,
                callback: eventTapCallback,
                userInfo: userInfo
            )
            isBlocking = false
        }

        guard let tap = eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isActive = true
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
        isActive = false
        isBlocking = false
    }

    func handleEvent(
        proxy: CGEventTapProxy, type: CGEventType, event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            let flags = event.flags
            escapeDetector.flagsChanged(
                controlDown: flags.contains(.maskControl),
                optionDown: flags.contains(.maskAlternate),
                commandDown: flags.contains(.maskCommand),
                at: Date()
            )
            if escapeDetector.isEscapeTriggered(at: Date()) {
                onEscapeTriggered()
                return Unmanaged.passUnretained(event)
            }
        }

        return isBlocking ? nil : Unmanaged.passUnretained(event)
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handleEvent(proxy: proxy, type: type, event: event)
}
