import SwiftUI

/// Figma 05 Components / Actions의 원본 컴포넌트 이름을 따릅니다.
enum AppActions {
    /// Bottom Action에 전달하는 문구·활성 상태·동작 한 묶음입니다.
    struct Action {
        let title: String
        let isEnabled: Bool
        let perform: () -> Void

        init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
            self.title = title
            self.isEnabled = isEnabled
            self.perform = action
        }
    }

    /// Figma의 Button. 너비는 부모가 정하며 눌림·비활성은 시스템 상태를 따릅니다.
    struct Button: View {
        enum Kind {
            case primary, secondary
        }

        private let title: String
        private let kind: Kind
        private let action: () -> Void

        init(_ title: String, kind: Kind = .primary, action: @escaping () -> Void) {
            self.title = title
            self.kind = kind
            self.action = action
        }

        var body: some View {
            SwiftUI.Button(action: action) {
                Text(title)
                    .appTypography(.labelLarge)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(ActionButtonStyle(kind: kind))
        }
    }

    private struct ActionButtonStyle: ButtonStyle {
        let kind: Button.Kind
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 0) {
                Color.clear.frame(width: 12, height: 12)
                    .accessibilityHidden(true)

                configuration.label.frame(maxWidth: .infinity)

                Group {
                    if case .primary = kind {
                        // Figma Vector 1144와 같은 12×12 기존 에셋입니다.
                        Image("HomePrimaryArrow")
                            .renderingMode(.original)
                            .resizable()
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(background(isPressed: configuration.isPressed), in: shape)
            .overlay {
                if case .primary = kind, isEnabled, !configuration.isPressed {
                    shape.strokeBorder(AppGradients.primaryBorder, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(shape)
        }

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: 40)
        }

        private var foreground: Color {
            switch kind {
            case .primary:
                isEnabled ? AppColors.Semantic.Text.onPrimary
                    : AppColors.Semantic.Text.onPrimaryDisabled
            case .secondary:
                AppColors.Semantic.Text.sub
            }
        }

        private func background(isPressed: Bool) -> Color {
            switch kind {
            case .primary:
                if !isEnabled { return AppColors.Semantic.Primary.disabled }
                return isPressed ? AppColors.Semantic.Primary.pressed
                    : AppColors.Semantic.Primary.default
            case .secondary:
                return AppColors.Semantic.Background.secondary
            }
        }
    }

    /// 별도 눌림 색상이 정의되지 않은 보조 액션의 공통 피드백입니다.
    struct PressStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
        }
    }
}
