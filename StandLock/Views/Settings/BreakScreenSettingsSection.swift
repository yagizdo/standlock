import SwiftUI
import StandLockCore

/// Break overlay options: custom colours with a contrast warning, a live preview,
/// the statistics footer and the break message.
struct BreakScreenSettingsSection: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var themeStore: ThemeStore

    private var breakScreen: BreakScreenPreferences {
        coordinator.preferences.breakScreen
    }

    var body: some View {
        Section("Break Screen") {
            Toggle(isOn: customColorsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Break Colors")
                        Text("Use your own background and text colors")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "paintpalette")
                }
            }

            if let customColors = breakScreen.customColors {
                ColorPicker("Background", selection: colorBinding(\.backgroundHex, fallback: .white), supportsOpacity: false)
                ColorPicker("Text", selection: colorBinding(\.textHex, fallback: .black), supportsOpacity: false)

                if customColors.paper.contrastRatio(with: customColors.ink) < 4.5 {
                    Label("Text may be hard to read on this background", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            BreakScreenPreviewCard(
                look: BreakScreenLook.resolve(theme: themeStore.current, level: .gentle, breakScreen: breakScreen),
                message: breakScreen.message,
                statistics: breakScreen.showsStatistics ? coordinator.todayStats : nil
            )

            Toggle(isOn: $coordinator.preferences.breakScreen.showsStatistics) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Statistics")
                        Text("Show today's break counts at the bottom")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "chart.bar")
                }
            }

            TextField("Break Message", text: $coordinator.preferences.breakScreen.message, prompt: Text("e.g. Drink some water"))
            Text("Shown under the timer during every break")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: coordinator.preferences.breakScreen) { _ in
            coordinator.savePreferences()
        }
    }

    /// On seeds the pair from the current theme's Gentle palette; off clears both.
    private var customColorsEnabled: Binding<Bool> {
        Binding(
            get: { breakScreen.customColors != nil },
            set: { isOn in
                if isOn {
                    let palette = themeStore.current.palette(for: .gentle)
                    coordinator.preferences.breakScreen.backgroundHex = (HexColor(palette.paper) ?? .white).hex
                    coordinator.preferences.breakScreen.textHex = (HexColor(palette.ink) ?? .black).hex
                } else {
                    coordinator.preferences.breakScreen.backgroundHex = nil
                    coordinator.preferences.breakScreen.textHex = nil
                }
            }
        )
    }

    private func colorBinding(
        _ keyPath: WritableKeyPath<BreakScreenPreferences, String?>, fallback: HexColor
    ) -> Binding<Color> {
        Binding(
            get: { Color(HexColor(hex: coordinator.preferences.breakScreen[keyPath: keyPath] ?? "") ?? fallback) },
            set: {
                // A colour with no sRGB conversion keeps the stored hex unchanged.
                guard let rgb = HexColor($0) else { return }
                coordinator.preferences.breakScreen[keyPath: keyPath] = rgb.hex
            }
        )
    }
}
