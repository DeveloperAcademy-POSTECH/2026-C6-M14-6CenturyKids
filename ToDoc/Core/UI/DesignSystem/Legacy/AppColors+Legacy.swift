import SwiftUI

/// 기존 화면 호환용 색상입니다. 새 컴포넌트는 AppColors.Semantic을 사용합니다.
extension AppColors {
    static let primary = Color("DesignSystem/Primary")
    static let disabled = Color("DesignSystem/Disabled")
    static let secondary = Color("DesignSystem/Secondary")
    static let gray = Color("DesignSystem/Gray")
    static let background = Color("DesignSystem/Background")

    enum Text {
        static let primary = Color("DesignSystem/TextPrimary")
        static let secondary = Color("DesignSystem/TextSecondary")
        static let subAction = Color("DesignSystem/SubAction")
    }

    enum Button {
        static let primaryForeground = Color("DesignSystem/OnPrimary")
        static let disabledForeground = Color("DesignSystem/OnDisabled")
        static let secondaryForeground = Color("DesignSystem/OnSecondary")
        static let backBackground = Color("DesignSystem/BackBackground")
    }
}
