import SwiftUI

/// Spacing, radii and text sizes shared by Settings pages.
enum SettingsTokens {
    static let pageInset: CGFloat = 24
    static let sectionSpacing: CGFloat = 18
    static let sectionTitleSpacing: CGFloat = 7
    static let cardRadius: CGFloat = 11
    static let rowInsets = EdgeInsets(top: 9, leading: 13, bottom: 9, trailing: 13)
    static let rowMinHeight: CGFloat = 40
    static let rowSpacing: CGFloat = 12
    static let pageTitleFont = Font.system(size: 15, weight: .semibold)
    static let sectionTitleFont = Font.system(size: 12.5, weight: .semibold)
    static let descriptionFont = Font.system(size: 11.5)
}
