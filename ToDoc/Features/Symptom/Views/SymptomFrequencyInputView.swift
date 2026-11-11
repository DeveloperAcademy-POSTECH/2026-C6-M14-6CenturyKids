import SwiftUI

/// Figma 2113:6721: 횟수 입력. 숫자 키패드로 받고 10보다 크면 10+로 보낸다.
struct SymptomFrequencyInputView: View {
    let question: SymptomConversationQuestion
    @Binding var frequency: SymptomConversationAnswer.Frequency?
    var isSubmitting = false
    @Binding var keepsKeyboard: Bool
    var onSubmit: ((SymptomConversationAnswer.Frequency) -> Void)?
    var onEnd: (() -> Void)?
    var onSwitchToVoice: (() -> Void)?
    @State private var digits = ""
    @FocusState private var isFocused: Bool

    private var canSubmit: Bool { frequency != nil && !isSubmitting && onSubmit != nil }

    var body: some View {
        SymptomChatLayout(title: question.text, sub: question.guidance, progress: question.progress ?? 0,
                          character: SymptomChatCharacter(current: isSubmitting ? .thinking : (isFocused ? .nodding : .hello)),
                          caption: isSubmitting ? nil : "증상을 입력해주세요.", isEditing: isFocused, canSend: canSubmit,
                          onClose: onEnd, onSwitchToVoice: onSwitchToVoice,
                          onSend: { if let frequency { keepsKeyboard = isFocused; onSubmit?(frequency) } }) {
            HStack(spacing: 0) {
                TextField("횟수", text: $digits,
                          prompt: Text("00").foregroundStyle(AppColors.Semantic.Text.disabled))
                    .keyboardType(.numberPad)
                    .fixedSize()
                    .focused($isFocused)
                    .disabled(isSubmitting)
                    .accessibilityIdentifier("symptom.answer")
                Text("번 했어요")
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
        }
        .onAppear { if keepsKeyboard { isFocused = true } }
        .onChange(of: digits) { _, value in
            guard value != "10+" else { return }
            let number = String(value.filter(\.isNumber).prefix(3))
            if number != value { digits = number; return }
            frequency = Self.frequency(number)
        }
        .onChange(of: frequency, initial: true) { _, value in
            guard Self.frequency(digits) != value else { return }
            digits = switch value {
            case .count(let count): String(count)
            case .tenPlus: "10+"
            case nil: ""
            }
        }
    }

    private static func frequency(_ text: String) -> SymptomConversationAnswer.Frequency? {
        if text.hasSuffix("+") { return .tenPlus }
        guard let count = Int(text) else { return nil }
        return count > 10 ? .tenPlus : .count(count)
    }
}

#Preview("Figma 횟수 입력") {
    @Previewable @State var frequency: SymptomConversationAnswer.Frequency?
    @Previewable @State var keepsKeyboard = false
    SymptomFrequencyInputView(question: .init(id: UUID(), text: "구토는 하루에 몇 번 정도 하셨나요?",
        guidance: "말씀하신 증상에 대해 조금 더 여쭤볼게요.", progress: 0.3, input: .frequency),
                              frequency: $frequency, keepsKeyboard: $keepsKeyboard)
}
