import SwiftUI

/// Spacing, radii and text sizes shared by Settings pages.
enum SettingsTokens {
    static let pageInset: CGFloat = 24
    static let pageTitleInsets = EdgeInsets(top: 14, leading: 24, bottom: 10, trailing: 24)
    static let sectionSpacing: CGFloat = 18
    static let sectionTitleSpacing: CGFloat = 7
    static let sectionTitleInset: CGFloat = 2
    static let cardRadius: CGFloat = 11
    static let rowInsets = EdgeInsets(top: 9, leading: 13, bottom: 9, trailing: 13)
    static let rowMinHeight: CGFloat = 40
    static let rowSpacing: CGFloat = 12
    static let rowTextSpacing: CGFloat = 1
    static let listItemSpacing: CGFloat = 6
    static let stripInsets = EdgeInsets(top: 5, leading: 11, bottom: 5, trailing: 11)
    static let stripRadius: CGFloat = 7
    static let stripItemSpacing: CGFloat = 4
    static let previewInsets = EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13)
    static let previewRadius: CGFloat = 9
    static let previewSpacing: CGFloat = 10
    static let messageFieldWidth: CGFloat = 170
    static let pageTitleFont = Font.system(size: 15, weight: .semibold)
    static let sectionTitleFont = Font.system(size: 12.5, weight: .semibold)
    static let descriptionFont = Font.system(size: 11.5)
}
