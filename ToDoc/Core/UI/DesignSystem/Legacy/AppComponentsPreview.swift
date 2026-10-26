#if DEBUG
import SwiftUI

/// 공통 컴포넌트 변경 시 한 곳에서 상태를 비교합니다. 제품 흐름에는 연결하지 않습니다.
struct AppComponentsPreview: View {
    @State private var answer = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                AppHeader(title: "공통 컴포넌트", description: "선택·입력·진행 상태")
                Text("질문 · 오늘은 어떠셨나요?").appFont(.question)
                Text("본문 · 증상을 알려주세요.").appFont(.body)
                Text("설정 행 · 내 정보").appFont(.settingsRow)
                HStack {
                    AppCircleControl(title: "종료하기", asset: "CareConversationClose", action: {})
                    Spacer()
                    AppCircleControl(title: "음성 전환", asset: "CareConversationText", action: nil)
                }
                AppAnswerEditor(text: $answer, accessibilityIdentifier: "design-system.answer")
                Button {} label: { AppForwardLabel(title: "다음", asset: "CareConversationNext") }
                    .buttonStyle(AppButtonStyle())
                VStack(spacing: AppSpacing.content) {
                    Text("진행률 · 정상 / 범위 초과 / 미확인 / NaN").appTextStyle(.caption)
                    AppProgressTrack(value: 0.4)
                    AppProgressTrack(value: 2)
                    AppProgressTrack(value: nil)
                    AppProgressTrack(value: .nan)
                    AppProgressTrack(value: .infinity)
                }
            }.padding(.vertical, AppSpacing.section)
        }.appScreenStyle()
    }
}
#Preview("공통 입력·버튼·진행률") { AppComponentsPreview() }
#endif
