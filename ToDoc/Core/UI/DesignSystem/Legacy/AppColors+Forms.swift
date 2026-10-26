import SwiftUI

extension AppColors {
    /// 설정 하이파이의 그룹형 화면 변형. 기본 팔레트와 독립적으로 변경합니다.
    enum Settings {
        static let background = Color(red: 241 / 255, green: 241 / 255, blue: 247 / 255)
        static let primary = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
        static let secondary = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
        static let caption = Color(red: 109 / 255, green: 109 / 255, blue: 114 / 255)
        static let action = Color(red: 100 / 255, green: 130 / 255, blue: 56 / 255)
        static let separator = Color.black.opacity(0.06)
    }

    enum Auth {
        static let brand = Color(red: 0.21, green: 0.31, blue: 0.04)
        static let loginFocus = Color.blue
        static let inputFocus = AppColors.gray
    }
}
