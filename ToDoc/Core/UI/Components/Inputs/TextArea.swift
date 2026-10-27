import SwiftUI
import UIKit

extension AppInputs {
    /// Figma Text Area. 너비는 부모가 정하고 230pt는 기본 최소 높이로만 사용합니다.
    struct TextArea: View {
        @Binding private var text: String

        private let title: String
        private let placeholder: String
        private let minHeight: CGFloat

        init(
            _ title: String,
            text: Binding<String>,
            placeholder: String = "",
            minHeight: CGFloat = 230
        ) {
            self.title = title
            _text = text
            self.placeholder = placeholder
            self.minHeight = minHeight
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                SwiftUI.TextEditor(text: $text)
                    .textEditorStyle(.plain)
                    .appTypography(.body)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .scrollContentBackground(.hidden)
                    .padding(editorPadding)
                    .accessibilityLabel(SwiftUI.Text(title))

                if text.isEmpty {
                    SwiftUI.Text(placeholder)
                        .appTypography(.body)
                        .foregroundStyle(AppColors.Semantic.Text.placeholder)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(32)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: minHeight, alignment: .topLeading)
            // Figma의 입력 배경 역할이 확정되기 전까지 원본 default를 유지합니다.
            .background(AppColors.Semantic.Background.default, in: RoundedRectangle(cornerRadius: 40))
        }

        /// TextEditor의 native 여백을 중복하지 않아 커서와 placeholder가 같은 32pt에서 시작합니다.
        private var editorPadding: EdgeInsets {
            let native = Self.nativeInsets
            return EdgeInsets(
                top: max(0, 32 - native.top),
                leading: max(0, 32 - native.left - Self.nativeLinePadding),
                bottom: max(0, 32 - native.bottom),
                trailing: max(0, 32 - native.right - Self.nativeLinePadding)
            )
        }

        private static let nativeInsets = UITextView().textContainerInset
        private static let nativeLinePadding = UITextView().textContainer.lineFragmentPadding
    }
}
