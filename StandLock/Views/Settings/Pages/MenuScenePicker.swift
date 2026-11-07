import SwiftUI
import StandLockCore

/// One small card per scene, drawn by the same view as the panel, so a new scene shows up here
/// from its enum case alone. `Off` comes first; after two rows a "+" card opens one more row.
struct MenuScenePicker: View {
    @Binding var selection: MenuScene

    /// Opens wide enough to show the selected scene.
    @State private var shownRows: Int

    init(selection: Binding<MenuScene>) {
        _selection = selection
        _shownRows = State(initialValue: MenuScenePickerLayout.rows(showing: selection.wrappedValue))
    }

    private enum Card: Hashable {
        case scene(MenuScene)
        case more
    }

    /// Half the panel's card: 128 x 68.
    private static let scale: CGFloat = 0.5
    private static let width: CGFloat = 256 * scale
    private static let height: CGFloat = 136 * scale

    /// Three cards fit at the window's minimum width.
    private static let columns = MenuScenePickerLayout.columns

    private var rows: [[Card]] {
        let layout = MenuScenePickerLayout.cards(rows: shownRows)
        let cards = layout.scenes.map(Card.scene) + (layout.hasMore ? [.more] : [])
        return stride(from: 0, to: cards.count, by: Self.columns).map {
            Array(cards[$0..<min($0 + Self.columns, cards.count)])
        }
    }

    var body: some View {
        // Not a `LazyVGrid`: on macOS 15 Tab reached only the first card in one.
        Grid(horizontalSpacing: SettingsTokens.cardSpacing, verticalSpacing: SettingsTokens.cardSpacing) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { card in
                        switch card {
                        case .scene(let scene): self.card(scene)
                        case .more: moreCard
                        }
                    }
                }
            }
        }
        .padding(SettingsTokens.rowInsets)
    }

    private func card(_ scene: MenuScene) -> some View {
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
                title(of: scene)
                    .foregroundStyle(selection == scene ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(title(of: scene))
        .accessibilityAddTraits(selection == scene ? .isSelected : [])
    }

    private var moreCard: some View {
        Button {
            shownRows += 1
        } label: {
            VStack(spacing: SettingsTokens.rowTextSpacing) {
                RoundedRectangle(cornerRadius: SettingsTokens.chipRadius)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(Image(systemName: "plus").font(.title2).foregroundStyle(.secondary))
                    .frame(width: Self.width, height: Self.height)
                    .padding(.bottom, SettingsTokens.stripItemSpacing)
                Text("More scenes")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("More scenes"))
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

    private func title(of scene: MenuScene) -> Text {
        switch scene {
        case .hourglass: Text("Hourglass")
        case .desk: Text("Desk")
        case .cat: Text(verbatim: "Yosun")
        case .penguin: Text("Penguin")
        case .frog: Text("Frog")
        case .fox: Text("Fox")
        case .capybara: Text("Capybara")
        case .robot: Text("Robot")
        case .campfire: Text("Campfire")
        case .hamster: Text("Hamster")
        case .sprout: Text("Sprout")
        case .off: Text("Off")
        }
    }
}
