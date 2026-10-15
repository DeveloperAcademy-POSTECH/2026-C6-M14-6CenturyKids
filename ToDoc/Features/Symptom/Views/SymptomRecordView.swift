import SwiftUI

struct SymptomRecordView: View {
    @State var state = SymptomScreenState()
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?
    var body: some View {
        Group {
            if state.didSave {
                SymptomCompletionView(onShowRecord: onShowRecord, onHome: onHome)
            } else if let summary = state.summary {
                SymptomSummaryView(state: summary, onBack: close)
            } else if state.isSummarizing {
                SymptomSummaryLoadingView(onCancel: close)
            } else if let question = state.question {
                VStack(spacing: 0) {
                    if let error = state.errorMessage { Text(error).foregroundStyle(.red).padding(12) }
                    SymptomConversationContent(state: state, question: question, onEnd: close,
                        onSwitch: { state.onAction?(.switchMode($0)) }).id(question.id)
                }
            } else {
                VStack(spacing: 20) {
                    Text("대화 기능 연결 전이에요").font(.headline)
                    if state.isWorking { ProgressView("질문을 준비하고 있어요") }
                    if let error = state.errorMessage { Text(error) }
                    Button("다시 시도") { state.onAction?(.start) }.disabled(state.isWorking || state.onAction == nil)
                    Button("종료하기", action: close)
                }.padding(24).buttonStyle(.bordered)
            }
        }.background(.white).toolbar(.hidden, for: .navigationBar)
            .onAppear { state.onAction?(.start) }
            .onDisappear { state.onAction?(.cancel) }
    }
    private func close() { if let onClose { onClose() } else { dismiss() } }
}

private struct SymptomConversationContent: View {
    @Bindable var state: SymptomScreenState
    let question: SymptomConversationQuestion
    let onEnd: () -> Void
    let onSwitch: (SymptomConversationMode) -> Void
    @State private var frequency: SymptomConversationAnswer.Frequency?
    @State private var duration: Int?

    var body: some View {
        Group {
            if state.mode == .voice {
                SymptomVoiceInputView(question: question, transcript: state.transcript,
                                      isListening: state.isListening, isWorking: state.isWorking,
                                      onEnd: onEnd, onSwitchToText: { onSwitch(.text) })
            } else {
                switch question.input {
                case .text:
                    SymptomTextInputView(question: question, text: $state.answerText,
                                         isSubmitting: state.isWorking || state.onAction == nil, isLastQuestion: question.isLastQuestion,
                                         showsPrevious: question.allowsPrevious,
                                         onPrevious: state.canGoPrevious ? { state.onAction?(.previous) } : nil,
                                         onNext: { state.onAction?(.answer(.text(state.answerText))) }, onEnd: onEnd,
                                         onSwitchToVoice: { onSwitch(.voice) })
                case .frequency:
                    SymptomFrequencyInputView(question: question, frequency: $frequency, isSubmitting: state.isWorking || state.onAction == nil,
                                              onSubmit: { value in state.onAction?(.answer(.frequency(value))) },
                                              onEnd: onEnd, onSwitchToVoice: { onSwitch(.voice) })
                case .duration:
                    SymptomDurationInputView(question: question, durationMinutes: $duration, isSubmitting: state.isWorking || state.onAction == nil,
                                             onSubmit: { value in state.onAction?(.answer(.durationMinutes(value))) },
                                             onEnd: onEnd, onSwitchToVoice: { onSwitch(.voice) })
                }
            }
        }
        .onAppear {
            switch state.restoredAnswer {
            case .frequency(let value): frequency = value
            case .durationMinutes(let value): duration = value
            case .text, nil: break
            }
        }
    }

}

#Preview("서비스 미연결") { SymptomRecordView() }
