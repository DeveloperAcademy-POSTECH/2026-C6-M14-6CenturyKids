import SwiftUI

/// Figma 수동 입력의 미답변 변형. 공통 CTA 크기에 원본 solid border·regular label을 유지합니다.
struct CareCallManualPendingButton: View {
    var body: some View {
        Button("답변을 입력해 주세요") {}
            .appFont(.body)
            .frame(maxWidth: .infinity, minHeight: AppMetrics.PillButton.height)
            .foregroundStyle(AppColors.CareCall.pendingText)
            .background(AppColors.CareCall.pendingFill, in: Capsule())
            .overlay {
                Capsule().stroke(AppColors.CareCall.pendingBorder, lineWidth: AppMetrics.PillButton.outerBorderWidth)
                    .allowsHitTesting(false)
            }
            // PlainButtonStyle의 비활성 글자 처리를 포함한 원본 렌더를 보존합니다.
            .buttonStyle(.plain)
            .disabled(true)
    }
}
