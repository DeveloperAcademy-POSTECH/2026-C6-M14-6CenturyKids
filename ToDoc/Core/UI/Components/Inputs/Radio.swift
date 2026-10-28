import SwiftUI

extension AppInputs {
    /// 카드처럼 부모 전체가 눌리는 곳에서도 같은 라디오 표시를 사용합니다.
    struct RadioIndicator: View {
        let isSelected: Bool

        var body: some View {
            Circle()
                .fill(AppColors.Semantic.Background.surface)
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? AppColors.Semantic.Primary.default
                                      : AppColors.Semantic.Border.default,
                                      lineWidth: isSelected ? 7 : 1.5)
                }
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
        }
    }

    /// Figma Radio. 같은 selection에 묶인 값 중 하나만 선택합니다.
    struct Radio<Value: Hashable>: View {
        private let title: String
        private let value: Value
        @Binding private var selection: Value

        init(_ title: String, value: Value, selection: Binding<Value>) {
            self.title = title
            self.value = value
            self._selection = selection
        }

        var body: some View {
            SwiftUI.Button {
                selection = value
            } label: {
                RadioIndicator(isSelected: isSelected)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AppActions.PressStyle())
            .accessibilityLabel(title)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }

        private var isSelected: Bool { selection == value }
    }
}
