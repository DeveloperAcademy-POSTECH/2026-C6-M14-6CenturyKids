import SwiftUI

struct SymptomTextInputView: View {
    let question: SymptomConversationQuestion
    @Binding var text: String
    var isSubmitting = false
    var isLastQuestion = false
    var showsPrevious = false
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onEnd: (() -> Void)?
    var onSwitchToVoice: (() -> Void)?

    private var hasAnswer: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        SymptomQuestionLayout(question: question,
                              nextTitle: hasAnswer ? (isLastQuestion ? "완료하기" : "이 답변으로 계속") : "답변을 입력해 주세요",
                              canProceed: hasAnswer && !isSubmitting,
                              showsPrevious: showsPrevious, onPrevious: onPrevious, onNext: onNext,
                              onEnd: onEnd, onSwitch: onSwitchToVoice) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("답변을 직접 입력해 주세요.")
                        .modifier(SymptomTextStyle(size: 16)).foregroundStyle(Color(white: 114 / 255))
                        .padding(.top, 8).padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .modifier(SymptomTextStyle(size: 16))
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("답변")
                    .accessibilityIdentifier("symptom.answer")
                    .disabled(isSubmitting)
            }
            .padding(27)
            .frame(height: 230)
            .background(Color(white: 243 / 255), in: RoundedRectangle(cornerRadius: 40))
        }
    }
}

#Preview("Figma 문자 입력") {
    @Previewable @State var text = ""
    SymptomTextInputView(question: .init(id: UUID(), text: "배가 아픈 건 언제부터였나요?",
                                         guidance: "말씀해 주신 내용에 대해 조금 더 여쭤볼게요",
                                         progress: 0.243, input: .text), text: $text,
                         onNext: {}, onEnd: {}, onSwitchToVoice: {})
}
