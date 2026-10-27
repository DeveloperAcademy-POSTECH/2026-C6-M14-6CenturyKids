import SwiftUI

extension AppInputs {
    /// Figma Chip. 선택 상태는 화면이 소유하며 Large는 부모의 열 너비를 따릅니다.
    struct Chip: View {
        enum Size {
            case large, small
        }

        private let title: String
        private let size: Size
        @Binding private var isSelected: Bool

        init(_ title: String, size: Size = .large, isSelected: Binding<Bool>) {
            self.title = title
            self.size = size
            self._isSelected = isSelected
        }

        var body: some View {
            SwiftUI.Button {
                isSelected.toggle()
            } label: {
                Text(title)
                    .appTypography(size == .large ? .label : .bodySmall)
                    .foregroundStyle(isSelected ? AppColors.Semantic.Text.onPrimary
                                     : AppColors.Semantic.Text.default)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, size == .large ? 16 : 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: size == .large ? .infinity : nil,
                           minHeight: size == .large ? 80 : 40)
                    .background(isSelected ? AppColors.Semantic.Primary.default
                                : AppColors.Semantic.Background.secondary, in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AppActions.PressStyle())
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}
