import Foundation

/// Picks the theme the app should render in.
///
/// The selection is a theme id rather than a two-case enum, so a theme added later
/// reaches this function with no change here and no migration of the stored value.
/// An id the build no longer ships resolves to the system default instead of trapping,
/// which is what makes downgrading safe.
///
/// - Parameters:
///   - selection: The user's explicit choice, or `nil` to follow the system.
///   - available: Theme ids the app ships, e.g. `["light", "dark"]`.
///   - systemPrefersDark: Whether the Mac is currently in dark appearance.
/// - Returns: A member of `available`, or `"light"` when `available` is empty.
public func resolveTheme(
    selection: String?,
    available: [String],
    systemPrefersDark: Bool
) -> String {
    if let selection, available.contains(selection) {
        return selection
    }
    let systemDefault = systemPrefersDark ? "dark" : "light"
    if available.contains(systemDefault) {
        return systemDefault
    }
    return available.first ?? "light"
}
