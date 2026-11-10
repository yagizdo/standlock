import SwiftUI
import StandLockCore

struct BreakScreenSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var themeStore: ThemeStore
    /// `themeStore.current` is not published: this re-evaluates the preview when the Mac's
    /// appearance changes.
    @Environment(\.colorScheme) private var colorScheme
    /// Preview state only; never saved.
    @State private var previewsPomodoroChip = false

    private var breakScreen: BreakScreenPreferences {
        coordinator.preferences.breakScreen
    }

    var body: some View {
        SettingsPageLayout("Break Screen") {
            SettingsSection("Preview") {
                BreakScreenPreviewCard(
                    look: BreakScreenLook.resolve(theme: themeStore.current, level: .gentle, breakScreen: breakScreen),
                    message: breakScreen.displayMessage,
                    statistics: breakScreen.showsStatistics ? coordinator.todayStats : nil,
                    showsPomodoroChip: previewsPomodoroChip
                )
                .padding(SettingsTokens.previewInsets)

                Divider()

                SettingsToggleRow(
                    "Show Pomodoro chip",
                    symbol: "timer",
                    description: "Only changes this preview",
                    isOn: $previewsPomodoroChip
                )
            }

            SettingsSection("Look") {
                SettingsToggleRow(
                    "Custom Break Colors",
                    symbol: "paintpalette",
                    description: "Use your own background and text colors",
                    isOn: customColorsEnabled
                )

                if let customColors = breakScreen.customColors {
                    SettingsRowDivider()
                    colorRow("Background", \.backgroundHex, fallback: .white)
                    SettingsRowDivider()
                    colorRow("Text", \.textHex, fallback: .black)

                    if customColors.isHardToRead {
                        Divider()
                        Label("Text may be hard to read on this background", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(SettingsTokens.rowInsets)
                    }
                }
            }

            SettingsSection("Content") {
                SettingsRow("Break Message", symbol: "text.quote", description: "Shown under the timer during every break") {
                    TextField("Break Message", text: $coordinator.preferences.breakScreen.message, prompt: Text("e.g. Drink some water"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: SettingsTokens.textFieldWidth)
                }

                SettingsRowDivider()

                SettingsToggleRow(
                    "Show Statistics",
                    symbol: "chart.bar",
                    description: "Show today's break counts at the bottom",
                    isOn: $coordinator.preferences.breakScreen.showsStatistics
                )
            }

            SettingsSection("During a break") {
                SettingsToggleRow(
                    "Pause Media",
                    symbol: "pause.circle",
                    description: "Pause audio playback when a break starts",
                    isOn: $coordinator.preferences.pauseMediaDuringBreak
                )

                SettingsRowDivider()

                SettingsToggleRow(
                    "Sound when a break ends",
                    symbol: "bell",
                    isOn: $coordinator.preferences.soundAfterBreak
                )

                SettingsRowDivider()

                SettingsToggleRow(
                    "Sound before a break",
                    symbol: "bell.badge",
                    description: "Plays one minute before a break",
                    isOn: $coordinator.preferences.soundBeforeBreak
                )
            }
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

    /// A hex code field for typing or pasting a known colour, next to the system picker.
    private func colorRow(
        _ title: LocalizedStringKey,
        _ keyPath: WritableKeyPath<BreakScreenPreferences, String?>,
        fallback: HexColor
    ) -> some View {
        SettingsRow(title, symbol: "arrow.turn.down.right") {
            HStack(spacing: SettingsTokens.rowSpacing) {
                HexColorField(color: hexBinding(keyPath, fallback: fallback))
                ColorPicker(title, selection: colorBinding(keyPath, fallback: fallback), supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }

    private func hexBinding(
        _ keyPath: WritableKeyPath<BreakScreenPreferences, String?>, fallback: HexColor
    ) -> Binding<HexColor> {
        Binding(
            get: { HexColor(hex: coordinator.preferences.breakScreen[keyPath: keyPath] ?? "") ?? fallback },
            set: { newColor in
                // A field committing as Custom Break Colors turns off must not bring one colour back.
                guard coordinator.preferences.breakScreen.customColors != nil else { return }
                coordinator.preferences.breakScreen[keyPath: keyPath] = newColor.hex
            }
        )
    }

    private func colorBinding(
        _ keyPath: WritableKeyPath<BreakScreenPreferences, String?>, fallback: HexColor
    ) -> Binding<Color> {
        let hex = hexBinding(keyPath, fallback: fallback)
        return Binding(
            get: { Color(hex.wrappedValue) },
            set: {
                // A colour with no sRGB conversion keeps the stored hex unchanged.
                guard let rgb = HexColor($0) else { return }
                hex.wrappedValue = rgb
            }
        )
    }
}
