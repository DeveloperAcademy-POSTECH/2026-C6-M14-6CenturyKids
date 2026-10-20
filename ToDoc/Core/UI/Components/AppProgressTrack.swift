import SwiftUI

/// 화면과 VoiceOver가 같은 유효한 진행률을 사용합니다.
struct AppProgressTrack: View {
    let value: Double?
    var label = "대화 진행"

    private var progress: Double? {
        guard let value, value.isFinite else { return nil }
        return min(1, max(0, value))
    }

    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(AppColors.Surface.progressTrack)
                .overlay(alignment: .leading) {
                    Capsule().fill(AppGradients.conversationProgress)
                        .frame(width: geometry.size.width * (progress ?? 0))
                }
        }
        .frame(height: AppMetrics.Conversation.progressHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(progress.map { "\(Int($0 * 100))퍼센트" } ?? "확인 중")
    }
}
