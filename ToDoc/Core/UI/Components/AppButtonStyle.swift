import SwiftUI

/// 공통 CTA 스타일. 비활성 조건과 액션은 호출 화면이 전달합니다.
struct AppButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, back }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appTextStyle(.label)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .back ? AppSpacing.BackButton.padding
                     : AppSpacing.PillButton.horizontalPadding)
            .padding(.vertical, AppSpacing.PillButton.verticalPadding)
            .frame(maxWidth: kind == .back ? nil : .infinity,
                   minHeight: AppMetrics.PillButton.height)
            .frame(width: kind == .back ? AppMetrics.BackButton.size : nil)
            .background(background, in: shape)
            .overlay {
                if let border {
                    // 선의 중심을 바깥으로 반 두께 옮겨 Outside 2를 재현합니다.
                    shape.inset(by: -AppMetrics.PillButton.outerBorderWidth / 2)
                        .stroke(border, lineWidth: AppMetrics.PillButton.outerBorderWidth)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(shape)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppMetrics.PillButton.cornerRadius, style: .circular)
    }

    private var background: Color {
        switch kind {
        case .primary: isEnabled ? AppColors.primary : AppColors.disabled
        case .secondary: AppColors.secondary
        case .back: AppColors.Button.backBackground
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: isEnabled ? AppColors.Button.primaryForeground : AppColors.Button.disabledForeground
        case .secondary, .back: AppColors.Button.secondaryForeground
        }
    }

    private var border: LinearGradient? {
        switch kind {
        case .primary: isEnabled ? AppGradients.primaryBorder : AppGradients.disabledBorder
        case .secondary: nil
        case .back: AppGradients.backBorder
        }
    }
}
