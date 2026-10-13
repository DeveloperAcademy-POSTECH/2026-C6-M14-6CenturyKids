import SwiftUI

struct SymptomSeverityInputView: View {
    let question: SymptomConversationQuestion
    @Binding var severity: Double?
    var isSubmitting = false
    var onSubmit: ((Double) -> Void)?
    var onEnd: (() -> Void)?
    var onSwitchToVoice: (() -> Void)?

    private var values: [Double] {
        var values = (0...10).map(Double.init)
        if let severity, severity.isFinite, (0...10).contains(severity), !values.contains(severity) {
            values.append(severity) // 엔진에서 받은 소수 점수를 정수로 바꾸지 않습니다.
        }
        return values.sorted()
    }
    private var canSubmit: Bool {
        guard let severity else { return false }
        return severity.isFinite && (0...10).contains(severity) && !isSubmitting && onSubmit != nil
    }

    var body: some View {
        SymptomQuestionLayout(question: question, nextTitle: canSubmit ? "다음" : "답변을 입력해 주세요",
                              canProceed: canSubmit, onNext: { if let severity { onSubmit?(severity) } },
                              onEnd: onEnd, onSwitch: onSwitchToVoice) {
            VStack(spacing: 30) {
                SymptomNumberWheel(title: "불편함 정도", labels: values.map { $0.rounded() == $0 ? String(Int($0)) : String($0) },
                                   selectedIndex: values.firstIndex(of: severity ?? 0) ?? 0, hasSelection: severity != nil) {
                    severity = values[$0]
                }
                .disabled(isSubmitting)
                Text("만큼 불편했어요").modifier(SymptomTextStyle(size: 20, weight: .semibold))
            }
        }
    }
}

#Preview("Figma 불편함 입력") {
    @Previewable @State var severity: Double? = 9
    SymptomSeverityInputView(question: .init(id: UUID(), text: "설사 때문에 얼마나 불편했나요?",
        guidance: "말씀해 주신 내용에 대해 조금 더 여쭤볼게요", progress: 0.243, input: .severity), severity: $severity)
}
