import SwiftUI
import UIKit

struct SymptomRecordView: View {
    @State var state = SymptomScreenState()
    /// 대화 중 종료하기를 눌러 기록 중단 팝업을 띄움
    @State private var confirmsEnd = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
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
                SymptomSummaryLoadingView()
            } else if let question = state.question {
                SymptomConversationContent(state: state, question: question, onEnd: askEnd,
                    onSwitch: { state.onAction?(.switchMode($0)) }).id(question.id)
                    .overlay { popup }
            } else if state.errorMessage != nil, !state.isWorking {
                SymptomServiceErrorView(onRetry: state.onAction.map { action in { action(.start) } },
                                        onHome: close)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("질문을 준비하고 있어요")
            }
        }.background(.white).toolbar(.hidden, for: .navigationBar)
            .onAppear { state.onAction?(.open) }
            .onDisappear { state.onAction?(.cancel) }
    }

    /// 질문 화면 위에 띄우는 팝업. 응급 → 기록 중단 → 오류 순으로 하나만
    @ViewBuilder
    private var popup: some View {
        if state.isEmergency {
            SymptomPopup.emergency(onStop: { state.onAction?(.stopForEmergency); close() },
                                   onContinue: { state.onAction?(.continueAfterEmergency) })
        } else if confirmsEnd {
            SymptomPopup.end(progress: state.question?.progress,
                             onContinue: { confirmsEnd = false; state.onAction?(.resume) },
                             onQuit: { confirmsEnd = false; state.onAction?(.discard); close() })
        } else if state.errorMessage != nil, state.needsMicrophone {
            SymptomPopup.microphone(onConfirm: clearError, onSettings: openSettings)
        } else if state.errorMessage != nil {
            SymptomPopup.service(onConfirm: clearError, onSettings: openSettings)
        }
    }

    private func askEnd() {
        confirmsEnd = true
        state.onAction?(.pause)
    }

    private func clearError() {
        state.errorMessage = nil
        state.needsMicrophone = false
    }

    private func openSettings() {
        clearError()
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
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
                                      isListening: state.isListening, onEnd: onEnd, onSwitchToText: { onSwitch(.text) })
            } else {
                switch question.input {
                case .text:
                    SymptomTextInputView(question: question, text: $state.answerText,
                                         isSubmitting: state.isWorking || state.onAction == nil, isLastQuestion: question.isLastQuestion,
                                         showsPrevious: question.allowsPrevious,
                                         onPrevious: previous,
                                         onNext: { state.onAction?(.answer(.text(state.answerText))) }, onEnd: onEnd,
                                         onSwitchToVoice: { onSwitch(.voice) })
                case .frequency:
                    SymptomFrequencyInputView(question: question, frequency: $frequency, isSubmitting: state.isWorking || state.onAction == nil,
                                              showsPrevious: question.allowsPrevious, onPrevious: previous,
                                              onSubmit: { value in state.onAction?(.answer(.frequency(value))) },
                                              onEnd: onEnd, onSwitchToVoice: { onSwitch(.voice) })
                case .duration:
                    SymptomDurationInputView(question: question, durationMinutes: $duration, isSubmitting: state.isWorking || state.onAction == nil,
                                             showsPrevious: question.allowsPrevious, onPrevious: previous,
                                             onSubmit: { value in state.onAction?(.answer(.durationMinutes(value))) },
                                             onEnd: onEnd, onSwitchToVoice: { onSwitch(.voice) })
                }
            }
        }
        .onAppear {
            // 이전 질문으로 돌아오면 그때 한 답을 다시 채운다
            switch state.restoredAnswer {
            case .frequency(let value): frequency = value
            case .durationMinutes(let value): duration = value
            case .text, nil: break
            }
        }
    }

    private var previous: (() -> Void)? {
        state.canGoPrevious && !state.isWorking ? { state.onAction?(.previous) } : nil
    }
}

#Preview("서비스 미연결") { SymptomRecordView() }
