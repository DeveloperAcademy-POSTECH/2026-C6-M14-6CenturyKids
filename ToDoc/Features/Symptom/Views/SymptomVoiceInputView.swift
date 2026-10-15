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
            VStack(spacing: 40) {
                Text(isListening ? "듣고 있어요. 편하게 말씀해 주세요." : isWorking ? "답변을 확인하고 있어요." : "안내를 듣고 답해 주세요.")
                    .modifier(SymptomTextStyle(size: 16)).multilineTextAlignment(.center)
                    .accessibilityIdentifier("symptom.voice.status")
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 40)
                        .fill(LinearGradient(colors: [Color(white: 241 / 255), Color(white: 230 / 255)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(alignment: .top) {
                            if !isListening { Image("CareCallHakro")
                                .resizable()
                                .frame(width: geometry.size.width + 27, height: geometry.size.width + 27)
                                .offset(x: -1.5, y: 13)
                                .accessibilityHidden(true) }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 40))
                }
                .frame(height: 230)
                Text(transcript.isEmpty ? "말하는 내용이 실시간으로 표시됩니다." : transcript)
                    .modifier(SymptomTextStyle(size: 16))
                    .foregroundStyle(isListening ? Color.black : Color(white: 114 / 255))
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
