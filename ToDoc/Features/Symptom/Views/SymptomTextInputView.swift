import SwiftUI

/// Figma 2113:6656·6644·6746·6709: 글로 증상 입력.
struct SymptomTextInputView: View {
    let question: SymptomConversationQuestion
    @Binding var text: String
    var isSubmitting = false
    /// 앞 질문에서 키보드를 쓰고 있었으면 다음 질문에서도 바로 올린다
    @Binding var keepsKeyboard: Bool
    var onNext: (() -> Void)?
    var onEnd: (() -> Void)?
    var onSwitchToVoice: (() -> Void)?
    @FocusState private var isFocused: Bool

    private var hasAnswer: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        SymptomChatLayout(title: question.text, sub: question.guidance, progress: question.progress ?? 0,
                          character: SymptomChatCharacter(current: isSubmitting ? .thinking : (isFocused ? .nodding : .hello)),
                          caption: isSubmitting ? nil : "증상을 입력해주세요.", isEditing: isFocused,
                          canSend: hasAnswer && !isSubmitting,
                          onClose: onEnd, onSwitchToVoice: onSwitchToVoice,
                          onSend: onNext.map { next in { keepsKeyboard = isFocused; next() } }) {
            // 보내는 동안엔 입력을 비워 안내 문구를 보이되, 같은 입력칸을 써서 키보드는 내리지 않는다
            TextField("답변", text: isSubmitting ? .constant("") : $text,
                      prompt: Text(isSubmitting ? "말씀을 정리하고 있어요..." : "")
                          .foregroundStyle(AppColors.Semantic.Text.disabled),
                      axis: .vertical)
                .lineLimit(1...2)
                .padding(.vertical, 5)
                .focused($isFocused)
                .accessibilityIdentifier("symptom.answer")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
        }
        .onAppear { if keepsKeyboard { isFocused = true } }
    }
}

#Preview("Figma 문자 입력") {
    @Previewable @State var text = ""
    @Previewable @State var keepsKeyboard = false
    SymptomTextInputView(question: .init(id: UUID(), text: "그 외의 불편에는 어떤 증상이 있었나요?",
                                         guidance: "말씀해 주신 내용에 대해 조금 더 여쭤볼게요",
                                         progress: 0.25, input: .text), text: $text,
                         keepsKeyboard: $keepsKeyboard, onNext: {}, onEnd: {}, onSwitchToVoice: {})
}
