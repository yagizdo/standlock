import SwiftUI
import EventKit
import ApplicationServices

enum PermissionStatus {
    case granted, notGranted, denied
}

@Observable
@MainActor
final class PermissionChecker {
    var inputMonitoringGranted = false
    var accessibilityGranted = false
    var calendarStatus: EKAuthorizationStatus = .notDetermined

    private var pollTimer: Timer?

    var calendarPermissionStatus: PermissionStatus {
        switch calendarStatus {
        case .fullAccess: .granted
        case .denied, .restricted: .denied
        default: .notGranted
        }
    }

    func refreshStatus() {
        inputMonitoringGranted = CGPreflightListenEventAccess()
        accessibilityGranted = AXIsProcessTrusted()
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func startPolling() {
        refreshStatus()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }

    func requestCalendar() {
        Task {
            let store = EKEventStore()
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            calendarStatus = granted ? .fullAccess : .denied
        }
    }
}
