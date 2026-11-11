import SwiftUI
import UIKit

struct SymptomRecordView: View {
    @State var state = SymptomScreenState()
    @State private var confirmsEnd = false
    @State private var keepsKeyboard = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
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
                SymptomSummaryLoadingView(showsInputBar: state.mode == .text, onClose: close)
            } else if let question = state.question {
                SymptomConversationContent(state: state, question: question, keepsKeyboard: $keepsKeyboard, onEnd: askEnd,
                    onSwitch: { state.onAction?(.switchMode($0)) })
                    .id(state.mode == .voice ? nil : question.id)
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
            // 백그라운드에서는 음성 합성이 끝 알림 없이 멈춰 통화가 말하는 중에 걸린다.
            // 나갈 때 통화를 잠시 끊고, 돌아오면 같은 질문부터 다시 건다 (기록 중단 팝업이 떠 있으면 환자의 선택을 기다린다)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    state.onAction?(.pause)
                } else if phase == .active, !confirmsEnd {
                    state.onAction?(.resume)
                }
            }
    }

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
    @Binding var keepsKeyboard: Bool
    let onEnd: () -> Void
    let onSwitch: (SymptomConversationMode) -> Void
    @State private var frequency: SymptomConversationAnswer.Frequency?

    var body: some View {
        Group {
            if state.mode == .voice {
                SymptomVoiceInputView(question: question, transcript: state.transcript,
                                      voiceState: state.voiceState,
                                      onEnd: onEnd, onSwitchToText: { onSwitch(.text) })
            } else {
                switch question.input {
                case .text:
                    SymptomTextInputView(question: question, text: $state.answerText,
                                         isSubmitting: state.isWorking || state.onAction == nil,
                                         keepsKeyboard: $keepsKeyboard,
                                         onNext: { state.onAction?(.answer(.text(state.answerText))) }, onEnd: onEnd,
                                         onSwitchToVoice: { onSwitch(.voice) })
                case .frequency:
                    SymptomFrequencyInputView(question: question, frequency: $frequency, isSubmitting: state.isWorking || state.onAction == nil,
                                              keepsKeyboard: $keepsKeyboard,
                                              onSubmit: { value in state.onAction?(.answer(.frequency(value))) },
                                              onEnd: onEnd, onSwitchToVoice: { onSwitch(.voice) })
                }
            }
        }
        .onAppear {
            if case .frequency(let value) = state.restoredAnswer { frequency = value }
        }
    }
}

#Preview("서비스 미연결") { SymptomRecordView() }
