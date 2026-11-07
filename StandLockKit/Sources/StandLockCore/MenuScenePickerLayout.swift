import Foundation

/// The cards in the menu scene picker: `Off` first, then the scenes in their declared order.
/// Two rows show at first. While scenes are left over, the last slot is a "+" card that opens
/// one more row.
public enum MenuScenePickerLayout {
    public static let columns = 3
    public static let firstRows = 2

    static var order: [MenuScene] {
        [.off] + MenuScene.allCases.filter { $0 != .off }
    }

    /// The scenes shown in `rows` rows, and whether a "+" card takes the last slot.
    public static func cards(rows: Int) -> (scenes: [MenuScene], hasMore: Bool) {
        let slots = rows * columns
        if order.count <= slots {
            return (order, false)
        }
        return (Array(order.prefix(slots - 1)), true)
    }

    /// The rows to open with: the first two, or more so the selected scene is on screen.
    public static func rows(showing selected: MenuScene) -> Int {
        var rows = firstRows
        while !cards(rows: rows).scenes.contains(selected) {
            rows += 1
        }
        return rows
    }
}
