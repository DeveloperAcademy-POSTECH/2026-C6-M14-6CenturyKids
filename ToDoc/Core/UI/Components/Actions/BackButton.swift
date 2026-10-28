import SwiftUI

extension AppActions {
    /// Figma의 Back Button. 큰 글자에서는 문구에 맞춰 높이가 늘어납니다.
    struct BackButton: View {
        private let title: String
        private let action: () -> Void

        init(_ title: String = "이전", action: @escaping () -> Void) {
            self.title = title
            self.action = action
        }

        var body: some View {
            SwiftUI.Button(action: action) {
                Text(title)
                    .appTypography(.labelLarge)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .padding(16)
                    .frame(width: 80)
                    .frame(minHeight: 80)
                    .background(AppColors.Semantic.Background.secondary, in: shape)
                    .overlay {
                        // 테두리는 현재 보이는 시안의 그라데이션이며 최종 표현은 미확정입니다.
                        shape.strokeBorder(AppGradients.backBorder, lineWidth: 2)
                            .allowsHitTesting(false)
                    }
                    .contentShape(shape)
            }
            .buttonStyle(PressStyle())
        }

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: 40)
        }
    }
}
