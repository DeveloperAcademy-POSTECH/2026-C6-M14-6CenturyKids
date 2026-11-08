import SwiftUI

/// 전체 동의와 개별 동의에 같은 원형 체크박스와 선택 상태를 표시합니다.
struct AuthCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: AppSpacing.item) {
                ZStack {
                    Circle()
                        .fill(configuration.isOn ? AppColors.Semantic.Primary.default : AppColors.Semantic.Background.surface)
                    if configuration.isOn {
                        // 고정 원형 체크 안의 SF Symbol 크기를 유지합니다.
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.Semantic.Text.action)
                    } else {
                        Circle().strokeBorder(AppColors.Semantic.Border.default, lineWidth: 1)
                    }
                }
                .frame(width: 20, height: 20)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
                configuration.label
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: AppMetrics.Control.minimumHitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "선택됨" : "선택 안 됨")
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
