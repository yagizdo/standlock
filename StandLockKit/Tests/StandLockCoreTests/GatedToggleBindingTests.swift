import Testing
import SwiftUI

/// Tests for the gated toggle binding pattern used by PermissionChecker.gatedToggle().
@Suite("Gated Toggle Binding")
@MainActor
struct GatedToggleBindingTests {

    private func makeBinding(
        available: Bool,
        preference: Binding<Bool>,
        onDenied: @escaping () -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { available && preference.wrappedValue },
            set: { newValue in
                if newValue && !available {
                    onDenied()
                } else {
                    preference.wrappedValue = newValue
                }
            }
        )
    }

    // MARK: - Getter

    @Test func getterReturnsTrueWhenAvailableAndPreferenceOn() {
        var value = true
        let pref = Binding(get: { value }, set: { value = $0 })
        let binding = makeBinding(available: true, preference: pref, onDenied: {})
        #expect(binding.wrappedValue == true)
    }

    @Test func getterReturnsFalseWhenAvailableButPreferenceOff() {
        var value = false
        let pref = Binding(get: { value }, set: { value = $0 })
        let binding = makeBinding(available: true, preference: pref, onDenied: {})
        #expect(binding.wrappedValue == false)
    }

    @Test func getterReturnsFalseWhenUnavailableRegardlessOfPreference() {
        var value = true
        let pref = Binding(get: { value }, set: { value = $0 })
        let binding = makeBinding(available: false, preference: pref, onDenied: {})
        #expect(binding.wrappedValue == false)
    }

    // MARK: - Setter

    @Test func setterUpdatesPreferenceWhenAvailable() {
        var value = false
        let pref = Binding(get: { value }, set: { value = $0 })
        var denied = false
        let binding = makeBinding(available: true, preference: pref, onDenied: { denied = true })

        binding.wrappedValue = true
        #expect(value == true)
        #expect(denied == false)
    }

    @Test func setterCallsDeniedWhenEnablingWhileUnavailable() {
        var value = false
        let pref = Binding(get: { value }, set: { value = $0 })
        var denied = false
        let binding = makeBinding(available: false, preference: pref, onDenied: { denied = true })

        binding.wrappedValue = true
        #expect(value == false)
        #expect(denied == true)
    }

    @Test func setterAllowsDisablingWhenUnavailable() {
        var value = true
        let pref = Binding(get: { value }, set: { value = $0 })
        var denied = false
        let binding = makeBinding(available: false, preference: pref, onDenied: { denied = true })

        binding.wrappedValue = false
        #expect(value == false)
        #expect(denied == false)
    }

    @Test func setterAllowsDisablingWhenAvailable() {
        var value = true
        let pref = Binding(get: { value }, set: { value = $0 })
        let binding = makeBinding(available: true, preference: pref, onDenied: {})

        binding.wrappedValue = false
        #expect(value == false)
    }
}
