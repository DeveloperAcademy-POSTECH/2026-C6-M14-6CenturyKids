import SwiftUI

extension AppTypography.Token {
    // 설정 하이파이의 글자 크기·굵기와 Auto 행간을 보존합니다.
    static let settingsPageTitle = Self(size: 32, weight: .bold)
    static let settingsProfileName = Self(size: 21, weight: .medium)
    static let settingsRow = Self(size: 17, weight: .medium)
    static let settingsNavigation = Self(size: 17, weight: .bold)
    static let settingsCaption = Self(size: 14, weight: .medium)
    static let settingsSectionCaption = Self(size: 13, weight: .medium)
    static let settingsDetail = Self(size: 12, weight: .medium)
    static let authBrand = Self(size: 26, weight: .bold, relativeTo: .title2)
}
