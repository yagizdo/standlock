import SwiftUI
import StandLockCore

/// One small card per scene, drawn by the same view as the panel, so a new scene shows up here
/// from its enum case alone.
struct MenuScenePicker: View {
    @Binding var selection: MenuScene

    /// Half the panel's card: 128 x 68.
    private static let scale: CGFloat = 0.5
    private static let width: CGFloat = 256 * scale
    private static let height: CGFloat = 136 * scale

    var body: some View {
        HStack(alignment: .top, spacing: SettingsTokens.cardSpacing) {
            ForEach(MenuScene.allCases, id: \.self) { scene in
                Button {
                    selection = scene
                } label: {
                    VStack(spacing: SettingsTokens.rowTextSpacing) {
                        thumbnail(scene)
                            .overlay {
                                if selection == scene {
                                    RoundedRectangle(cornerRadius: SettingsTokens.previewRadius)
                                        .strokeBorder(Color.accentColor, lineWidth: 2)
                                        .padding(SettingsTokens.chipRadius - SettingsTokens.previewRadius)
                                }
                            }
                            .padding(.bottom, SettingsTokens.stripItemSpacing)
                        Text(title(of: scene))
                            .foregroundStyle(selection == scene ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(title(of: scene)))
                .accessibilityAddTraits(selection == scene ? .isSelected : [])
            }
        }
        .padding(SettingsTokens.rowInsets)
    }

    @ViewBuilder
    private func thumbnail(_ scene: MenuScene) -> some View {
        if scene == .off {
            RoundedRectangle(cornerRadius: SettingsTokens.chipRadius)
                .fill(Color.secondary.opacity(0.12))
                .overlay(Image(systemName: "nosign").foregroundStyle(.secondary))
                .frame(width: Self.width, height: Self.height)
        } else {
            MenuSceneCard(scene: scene, look: .working, progress: 0.62, date: .distantPast, isMoving: false)
                .scaleEffect(Self.scale)
                .frame(width: Self.width, height: Self.height)
        }
    }

    private func title(of scene: MenuScene) -> LocalizedStringKey {
        switch scene {
        case .hourglass: "Hourglass"
        case .desk: "Desk"
        case .off: "Off"
        }
    }
}
