import SwiftUI

/// CTA의 문구 중심 정렬과 장식 아이콘을 공유하며 Button의 상태·액션은 소유하지 않습니다.
struct AppForwardLabel: View {
    enum Placement { case trailing, inline }
    let title: String
    let asset: String
    var placement: Placement = .trailing

    var body: some View {
        HStack(spacing: placement == .inline ? AppSpacing.tight : nil) {
            if placement == .trailing {
                Color.clear.frame(width: AppMetrics.PillButton.iconSize, height: AppMetrics.PillButton.iconSize)
                Spacer(minLength: AppSpacing.compact)
            }
            Text(title)
            if placement == .trailing { Spacer(minLength: AppSpacing.compact) }
            Image(asset).frame(width: AppMetrics.PillButton.iconSize, height: AppMetrics.PillButton.iconSize)
                .accessibilityHidden(true)
        }
    }
}
