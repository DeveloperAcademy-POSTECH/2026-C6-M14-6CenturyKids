import SwiftUI

extension AppFeedback {
    /// Figma의 Dialog. 아직 통합되지 않은 Text / Button 두 원본 형식을 구분합니다.
    /// 표시와 닫기는 호출 화면이 관리하며 각 버튼은 전달한 동작만 실행합니다.
    struct Dialog: View {
        enum Style: String, CaseIterable {
            case text = "Text"
            case button = "Button"
        }

        private let title: String
        private let message: String?
        private let style: Style
        private let icon: Image?
        private let primary: AppActions.Action
        private let primaryKind: AppActions.Button.Kind
        private let secondary: AppActions.Action

        init(
            _ title: String,
            message: String? = nil,
            style: Style = .button,
            icon: Image? = nil,
            primary: AppActions.Action,
            primaryKind: AppActions.Button.Kind = .primary,
            secondary: AppActions.Action
        ) {
            self.title = title
            self.message = message
            self.style = style
            self.icon = icon
            self.primary = primary
            self.primaryKind = primaryKind
            self.secondary = secondary
        }

        var body: some View {
            VStack(spacing: 0) {
                content
                switch style {
                case .text:
                    textActions
                case .button:
                    buttonActions
                }
            }
            .frame(maxWidth: 300)
            .background(
                AppColors.Semantic.Background.default,
                in: RoundedRectangle(cornerRadius: 40)
            )
            .clipShape(RoundedRectangle(cornerRadius: 40))
        }

        private var content: some View {
            VStack(spacing: 12) {
                if style == .button, let icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .appTypography(.labelLarge)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .accessibilityAddTraits(.isHeader)
                if let message, !message.isEmpty {
                    Text(message)
                        .appTypography(.bodySmall)
                        .foregroundStyle(AppColors.Semantic.Text.sub)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }

        private var textActions: some View {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColors.Semantic.Border.default)
                    .frame(height: 1)
                    .accessibilityHidden(true)
                HStack(spacing: 0) {
                    textAction(secondary)
                    textAction(primary)
                }
                .overlay {
                    Rectangle()
                        .fill(AppColors.Semantic.Border.default)
                        .frame(width: 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }

        private func textAction(_ action: AppActions.Action) -> some View {
            SwiftUI.Button(action: action.perform) {
                Text(action.title)
                    .appTypography(.labelLarge)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AppActions.PressStyle())
            .disabled(!action.isEnabled)
        }

        private var buttonActions: some View {
            VStack(spacing: 4) {
                AppActions.Button(primary.title, kind: primaryKind, action: primary.perform)
                    .disabled(!primary.isEnabled)
                AppActions.TextButton(secondary.title, action: secondary.perform)
                    .disabled(!secondary.isEnabled)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
