import SwiftUI

/// 입력은 호출 화면의 Binding에 남겨 모드 전환에서도 초안을 유지합니다.
struct AppAnswerEditor: View {
    @Binding var text: String
    var accessibilityLabel = "답변"
    let accessibilityIdentifier: String
    var isEnabled = true
    var placeholder = "답변을 직접 입력해 주세요."

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder).appFont(.body)
                    .foregroundStyle(AppColors.Text.secondary)
                    .padding(.top, AppMetrics.Conversation.placeholderTop)
                    .padding(.leading, AppMetrics.Conversation.placeholderLeading)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $text).appFont(.body)
                .scrollContentBackground(.hidden)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier(accessibilityIdentifier)
                .disabled(!isEnabled)
        }
        .padding(AppMetrics.Conversation.inputPadding)
        .frame(height: AppMetrics.Conversation.inputHeight)
        .appSurface(.conversationInput)
    }
}
