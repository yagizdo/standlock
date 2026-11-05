import Foundation
import StandLockCore

/// Weekday abbreviations in the app's chosen language.
///
/// `Weekday`'s raw values are Sunday = 1 ... Saturday = 7, the same numbering
/// `Calendar` uses, so a symbol is a direct index.
struct WeekdaySymbols {
    /// Sunday-first, as `Calendar` always returns regardless of `firstWeekday`.
    private let symbols: [String]

    init(locale: Locale) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        // veryShortWeekdaySymbols is ambiguous in Turkish -- P, P, S, Ç, P, C, C.
        symbols = calendar.shortWeekdaySymbols
    }

    func short(for day: Weekday) -> String {
        symbols[day.rawValue - 1]
    }

    /// Monday-first, for the calendar grids that lay out weeks that way.
    var mondayFirst: [String] {
        Array(symbols[1...6]) + [symbols[0]]
    }
}
