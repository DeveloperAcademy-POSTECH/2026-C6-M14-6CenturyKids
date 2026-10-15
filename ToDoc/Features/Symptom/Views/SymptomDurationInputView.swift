import SwiftUI

struct SymptomDurationInputView: View {
    let question: SymptomConversationQuestion
    @Binding var durationMinutes: Int?
    var isSubmitting = false
    var onSubmit: ((Int) -> Void)?
    var onEnd: (() -> Void)?
    var onSwitchToVoice: (() -> Void)?

    private var hours: Int { (durationMinutes ?? 0) / 60 }
    private var minutes: Int { (durationMinutes ?? 0) % 60 }
    private var minuteValues: [Int] {
        if hours == 24 { return [0] }
        var values = Array(stride(from: 0, through: 55, by: 5))
        if !values.contains(minutes) { values.append(minutes) }
        return values.sorted()
    }
    private var canSubmit: Bool {
        guard let durationMinutes else { return false }
        return (10...1440).contains(durationMinutes) && !isSubmitting && onSubmit != nil
    }

    var body: some View {
        SymptomQuestionLayout(question: question, nextTitle: canSubmit ? "다음" : "답변을 입력해 주세요",
                              canProceed: canSubmit, onNext: { if let durationMinutes { onSubmit?(durationMinutes) } },
                              onEnd: onEnd, onSwitch: onSwitchToVoice) {
            HStack(spacing: 20) {
                VStack(spacing: 30) {
                    SymptomNumberWheel(title: "지속 시간", labels: (0...24).map(String.init),
                                       selectedIndex: hours, hasSelection: durationMinutes != nil) {
                        durationMinutes = $0 * 60 + ($0 == 24 ? 0 : minutes)
                    }
                    Text("시간").modifier(SymptomTextStyle(size: 20, weight: .semibold))
                }
                VStack(spacing: 30) {
                    SymptomNumberWheel(title: "지속 시간 분", labels: minuteValues.map(String.init),
                                       selectedIndex: minuteValues.firstIndex(of: minutes) ?? 0,
                                       hasSelection: durationMinutes != nil) {
                        durationMinutes = hours * 60 + minuteValues[$0]
                    }
                    Text("분").modifier(SymptomTextStyle(size: 20, weight: .semibold))
                }
            }
            .padding(.horizontal, 5)
            .disabled(isSubmitting)
            if let durationMinutes, !(10...1440).contains(durationMinutes) {
                // 원본에 없는 검증 오류는 사용자 승인에 따라 기본 텍스트로 표시합니다.
                Text("지속 시간은 10분~24시간으로 입력해 주세요.")
                    .font(.footnote).foregroundStyle(.red)
            }
        }
    }
}

#Preview("Figma 지속 시간 입력") {
    @Previewable @State var duration: Int? = 90
    SymptomDurationInputView(question: .init(id: UUID(), text: "얼마나 지속 되었나요?",
        guidance: "말씀해 주신 내용에 대해 조금 더 여쭤볼게요", progress: 0.243, input: .duration), durationMinutes: $duration)
}
