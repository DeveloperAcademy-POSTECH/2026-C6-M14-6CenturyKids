import SwiftUI

struct SymptomVoiceInputView: View {
    let question: SymptomConversationQuestion
    var transcript = ""
    var isListening = false
    var isWorking = false
    var onEnd: (() -> Void)?
    var onSwitchToText: (() -> Void)?

    var body: some View {
        SymptomQuestionLayout(question: question, switchTitle: "채팅 전환", showsNext: false,
                              onEnd: onEnd, onSwitch: onSwitchToText) {
            VStack(spacing: AppSpacing.question) {
                Text(isListening ? "듣고 있어요. 편하게 말씀해 주세요." : isWorking ? "답변을 확인하고 있어요." : "안내를 듣고 답해 주세요.")
                    .appFont(.body).multilineTextAlignment(.center)
                    .accessibilityIdentifier("symptom.voice.status")
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: AppMetrics.Conversation.inputRadius)
                        .fill(AppGradients.conversationPortrait)
                        .overlay(alignment: .top) {
                            if !isListening { Image("CareCallHakro")
                                .resizable()
                                .frame(width: geometry.size.width + 27, height: geometry.size.width + 27)
                                .offset(x: -1.5, y: 13)
                                .accessibilityHidden(true) }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.Conversation.inputRadius))
                }
                .frame(height: AppMetrics.Conversation.inputHeight)
                Text(transcript.isEmpty ? "말하는 내용이 실시간으로 표시됩니다." : transcript)
                    .appFont(.body)
                    .foregroundStyle(isListening ? AppColors.Text.primary : AppColors.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("symptom.transcript")
            }
        }
    }
}

#Preview("Figma 음성 입력") {
    SymptomVoiceInputView(question: .init(id: UUID(), text: "오늘 몸 상태는 좀 어떠셨어요?",
                                          guidance: nil, progress: 0.243, input: .text),
                          isListening: true, onEnd: {}, onSwitchToText: {})
}
