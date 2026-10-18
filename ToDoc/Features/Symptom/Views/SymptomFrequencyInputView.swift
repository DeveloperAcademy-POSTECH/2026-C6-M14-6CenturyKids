import SwiftUI

struct SymptomFrequencyInputView: View {
    let question: SymptomConversationQuestion
    @Binding var frequency: SymptomConversationAnswer.Frequency?
    var isSubmitting = false
    var onSubmit: ((SymptomConversationAnswer.Frequency) -> Void)?
    var onEnd: (() -> Void)?
    var onSwitchToVoice: (() -> Void)?

    private var values: [SymptomConversationAnswer.Frequency] {
        (0...10).map { .count($0) } + [.tenPlus]
    }
    private var canSubmit: Bool {
        guard let frequency else { return false }
        return values.contains(frequency) && !isSubmitting && onSubmit != nil
    }

    var body: some View {
        SymptomQuestionLayout(question: question, nextTitle: canSubmit ? "다음" : "답변을 입력해 주세요",
                              canProceed: canSubmit, onNext: { if let frequency { onSubmit?(frequency) } },
                              onEnd: onEnd, onSwitch: onSwitchToVoice) {
            VStack(spacing: 30) {
                SymptomNumberWheel(title: "횟수", labels: (0...10).map(String.init) + ["10+"],
                                   selectedIndex: values.firstIndex(of: frequency ?? .count(0)) ?? 0,
                                   hasSelection: frequency != nil) { frequency = values[$0] }
                    .disabled(isSubmitting)
                Text("번 했어요").appFont(.sectionTitle)
            }
        }
    }
}

#Preview("Figma 횟수 입력") {
    @Previewable @State var frequency: SymptomConversationAnswer.Frequency? = .count(10)
    SymptomFrequencyInputView(question: .init(id: UUID(), text: "설사를 몇 번 하셨나요?",
        guidance: "말씀해 주신 내용에 대해 조금 더 여쭤볼게요", progress: 0.243, input: .frequency), frequency: $frequency)
}
