import SwiftUI

/// Figma 음성 입력. 통화 전에는 "대화 시작하기"를 눌러 통화를 걸고, 통화 중에는 같은 자리에 "음성 인식 중 .."을 보여 줍니다.
struct SymptomVoiceInputView: View {
    let question: SymptomConversationQuestion
    var transcript = ""
    var isListening = false
    var isCalling = false
    var onStart: (() -> Void)?
    var onEnd: (() -> Void)?
    var onSwitchToText: (() -> Void)?

    var body: some View {
        SymptomQuestionLayout(question: question, nextTitle: isCalling ? "음성 인식 중 .." : "대화 시작하기",
                              canProceed: !isCalling, switchTitle: "채팅 전환", nextIsStatus: isCalling,
                              onNext: onStart, onEnd: onEnd, onSwitch: onSwitchToText) {
            VStack(spacing: 40) {
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
                          onStart: {}, onEnd: {}, onSwitchToText: {})
}
