import SwiftUI
import StandLockCore

@MainActor
final class BreakDismissalState: ObservableObject {
    @Published var availability = DismissalAvailability()
}
