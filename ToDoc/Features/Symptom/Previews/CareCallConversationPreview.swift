#if DEBUG
import SwiftUI

/// One interactive walkthrough for both Figma sections. No VM, microphone, or persistence.
struct CareCallConversationPreview: View {
    @State private var session = CareCallConversationPreviewSession()
    @State private var unusedText = ""
    @State private var notice: String?
    @State private var showsEndConfirmation = false

    var body: some View {
        content
            .overlay(alignment: .topTrailing) { previewControls }
            .alert("대화를 종료할까요?", isPresented: $showsEndConfirmation) {
                Button("계속하기", role: .cancel) {}
                Button("종료하기", role: .destructive) { session = CareCallConversationPreviewSession() }
            } message: { Text("Preview에서 입력한 답변이 초기화돼요.") }
            .alert("개발 Preview", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("확인") { notice = nil }
            } message: { Text(notice ?? "") }
            .task(id: session.stage) {
                guard session.stage == .loading else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, session.stage == .loading else { return }
                session.stage = .completed
            }
    }

    @ViewBuilder private var content: some View {
        switch session.stage {
        case .incoming:
            CareCallIncomingView(canAnswer: true, onAnswer: { session.enter(.voice) },
                onEnd: { showsEndConfirmation = true },
                onPostpone: { notice = "10분 미루기 예시예요. 실제 알림은 예약하지 않았어요." },
                onSwitchToText: { session.enter(.text) })
        case .conversation:
            if session.mode == .text {
                CareCallManualSectionView(step: session.question.step, draft: $session.draft,
                    questionText: session.questionText, progressValue: session.progress,
                    onNext: { session.advance() }, onSkip: { session.skip() },
                    onEnd: { showsEndConfirmation = true },
                    onSwitchToVoice: { session.switchMode() })
            } else {
                CareCallVoiceSectionView(phase: session.isListening ? .listening : .ready,
                    answer: $unusedText,
                    transcript: "Preview에서는 마이크를 사용하지 않아요.\n채팅 전환으로 직접 답변할 수 있어요.",
                    summaryItems: $session.summaryItems, editingItemID: $session.editingItemID,
                    questionText: session.questionText, progressValue: session.progress,
                    showsFollowUpGuidance: session.question.step != .symptoms,
                    alwaysShowsModeSwitch: true,
                    onContinue: session.isListening ? nil : { session.isListening = true },
                    onEnd: { showsEndConfirmation = true },
                    onSwitchMode: { session.switchMode() })
            }
        case .loading:
            SymptomSummaryLoadingView()
        case .completed:
            SymptomCompletionView(onShowRecord: { session.stage = .summary },
                onHome: { session = CareCallConversationPreviewSession() })
        case .summary:
            CareCallVoiceSummaryView(items: $session.summaryItems, editingItemID: $session.editingItemID,
                onBack: { session.stage = .completed },
                onSave: { notice = "Preview의 수정 내용만 유지해요. 실제 기록은 저장하지 않았어요." })
        }
    }

    private var previewControls: some View {
        Menu {
            Text("개발 Preview · 화면 흐름 확인용")
            if session.stage == .conversation {
                if session.mode == .voice {
                    Button("예시 음성 답변으로 계속") { session.useSampleVoiceAnswer() }
                }
                Button("이전 질문") { session.previous() }
                    .disabled(!session.canGoPrevious)
            }
            Button("처음부터 다시 확인", role: .destructive) { showsEndConfirmation = true }
        } label: {
            Text("Preview")
                .font(.caption).padding(8)
                .background(.regularMaterial, in: Capsule())
        }
        .padding(.trailing, 12)
        .accessibilityIdentifier("carecall.conversation.preview.controls")
    }
}

#Preview("케어콜 전체 흐름 · 음성 ↔ 채팅") { CareCallConversationPreview() }
#endif
