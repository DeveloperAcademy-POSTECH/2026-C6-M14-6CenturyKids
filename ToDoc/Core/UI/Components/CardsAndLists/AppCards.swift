import SwiftUI

/// Figma 05 Components / Cards & Lists의 원본 컴포넌트 이름을 따릅니다.
enum AppCards {
    /// Row·Menu Card·Record Summary Card가 공유하는 원본 16pt 화살표입니다.
    struct Chevron: View {
        var color: Color = AppColors.Semantic.Text.sub

        var body: some View {
            Image("DesignSystem/Components/Cards/Chevron")
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(color)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        }
    }
}
