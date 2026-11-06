import Foundation

/// Whether a Settings search finds `query` inside any of `terms`. An empty query finds everything.
///
/// No locale on purpose: `tr` folding lowers `İ` to `ı`, so a plain `i` could not find `İ`. All
/// four Turkish forms of the letter fold to `i` instead, which also serves an English keyboard.
public func settingsSearchMatches(query: String, terms: [String]) -> Bool {
    let needle = searchFolded(query.trimmingCharacters(in: .whitespacesAndNewlines))
    return needle.isEmpty || terms.contains { searchFolded($0).contains(needle) }
}

private func searchFolded(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        .replacingOccurrences(of: "ı", with: "i")
}
