import SwiftUI

/// Where the app lives, launch at login, and the way back when the icon is hidden.
struct OnboardingMenuBarStep: View {
    @Binding var launchAtLogin: Bool
    let loginError: String?

    var body: some View {
        VStack(spacing: SettingsTokens.sectionSpacing) {
            menuBarStrip

            OnboardingHeading(
                "StandLock lives in the menu bar",
                "Click the circle for the next break, Skip and Pause. It fills up as the next break gets closer."
            )

            SettingsSection {
                SettingsToggleRow(
                    "Launch at Startup",
                    symbol: "power",
                    description: "Turn on so breaks keep coming after you restart the Mac.",
                    isOn: $launchAtLogin
                )
                // Not a description: Show help hides those, and an error must stay.
                if let loginError {
                    Divider()
                    Text("Failed to update login item: \(loginError)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(SettingsTokens.rowInsets)
                }
                SettingsRowDivider()
                // A row title, not a description, for the same reason: it is the only way back.
                SettingsRow("Can't see the icon? Open StandLock again from Applications and Settings opens.", symbol: "questionmark.circle") {
                    EmptyView()
                }
            }
        }
    }

    /// A drawn strip of menu bar with the real icon picked out.
    private var menuBarStrip: some View {
        let strip = RoundedRectangle(cornerRadius: SettingsTokens.cardRadius)
        return HStack(spacing: 14) {
            Spacer()
            Image(systemName: "wifi")
                .foregroundStyle(.secondary)
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Image(nsImage: MenuBarIcon.make(progress: 0.62))
                .renderingMode(.template)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.14)))
            Text(Date(), format: .dateTime.weekday(.abbreviated).hour().minute())
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Color.primary.opacity(0.06), in: strip)
        .overlay(strip.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}
