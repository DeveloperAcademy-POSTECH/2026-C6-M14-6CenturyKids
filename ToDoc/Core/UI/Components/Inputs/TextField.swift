import SwiftUI
import UIKit

extension AppInputs {
    /// Figma Text Field. 오류는 메시지로, 비활성은 native disabled 환경으로 전달합니다.
    struct TextField: View {
        @Binding private var text: String
        @Environment(\.isEnabled) private var isEnabled

        private let title: String
        private let placeholder: String
        private let showsLabel: Bool
        private let helper: String?
        private let error: String?
        private let isSecure: Bool
        private let keyboardType: UIKeyboardType
        private let textContentType: UITextContentType?

        init(
            _ title: String,
            text: Binding<String>,
            placeholder: String = "",
            showsLabel: Bool = true,
            helper: String? = nil,
            error: String? = nil,
            isSecure: Bool = false,
            keyboardType: UIKeyboardType = .default,
            textContentType: UITextContentType? = nil
        ) {
            self.title = title
            _text = text
            self.placeholder = placeholder
            self.showsLabel = showsLabel
            self.helper = helper
            self.error = error
            self.isSecure = isSecure
            self.keyboardType = keyboardType
            self.textContentType = textContentType
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                if showsLabel {
                    SwiftUI.Text(title)
                        .appTypography(.label)
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }

                input
                    .textFieldStyle(.plain)
                    .appTypography(.body)
                    .foregroundStyle(textColor)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 64)
                    .frame(maxWidth: .infinity)
                    .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        if isEnabled && error != nil {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(AppColors.Semantic.Border.error, lineWidth: 1.5)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel(SwiftUI.Text(title))
                    .accessibilityHint(SwiftUI.Text(message ?? ""))

                if let message {
                    SwiftUI.Text(message)
                        .appTypography(.bodySmall)
                        .foregroundStyle(messageColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        @ViewBuilder
        private var input: some View {
            if isSecure {
                SwiftUI.SecureField(title, text: $text, prompt: prompt)
            } else {
                SwiftUI.TextField(title, text: $text, prompt: prompt)
            }
        }

        private var prompt: SwiftUI.Text {
            SwiftUI.Text(placeholder)
                .foregroundStyle(isEnabled ? AppColors.Semantic.Text.placeholder : AppColors.Semantic.Text.disabled)
        }

        private var message: String? { error ?? helper }

        private var textColor: Color {
            isEnabled ? AppColors.Semantic.Text.default : AppColors.Semantic.Text.disabled
        }

        private var backgroundColor: Color {
            isEnabled ? AppColors.Semantic.Background.default : AppColors.Semantic.Background.secondary
        }

        private var messageColor: Color {
            guard isEnabled else { return AppColors.Semantic.Text.disabled }
            return error == nil ? AppColors.Semantic.Text.sub : AppColors.Semantic.Text.error
        }
    }
}
