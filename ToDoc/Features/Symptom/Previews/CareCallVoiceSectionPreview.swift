#if DEBUG
import SwiftUI

/// Development-only samples. This host never creates a VM, requests a microphone, or writes a record.
struct CareCallVoiceSectionPreview: View {
    @State private var session: CareCallVoicePreviewSession
    @State private var notice: String?
    let showsControls: Bool

    init(initialPhase: CareCallVoicePhase = .incoming, showsControls: Bool = true) {
        _session = State(initialValue: CareCallVoicePreviewSession(initialPhase: initialPhase))
        self.showsControls = showsControls
    }

    var body: some View {
        CareCallVoiceSectionView(phase: session.phase, answer: $session.answer,
            transcript: "어제 마라샹궈 먹었더니 배탈이 났는데\n제 얘기는 아니고 가상의 상황 설 ...",
            summaryItems: $session.items, editingItemID: $session.editingItemID,
            onContinue: { session.advance() }, onPrevious: { session.previous() },
            onEnd: { notice = "Preview 대화를 종료했어요. 실제 기록은 저장하지 않았어요."; session.navigate(to: .incoming) },
            onPostpone: { notice = "10분 미루기 예시예요. 실제 알림은 예약하지 않았어요." },
            onSwitchMode: { session.switchMode() },
            onShowRecord: { session.navigate(to: .summary) },
            onSave: { notice = "Preview 안의 수정 내용만 유지해요. 실제 기록은 저장하지 않았어요."; session.navigate(to: .completed) })
        .overlay(alignment: .topTrailing) {
            if showsControls {
                Menu {
                    Text("개발 Preview · 새 화면 예시 불러오기")
                    ForEach(CareCallVoicePhase.allCases) { option in
                        Button("\(option.title) · \(option.figmaNodeID)") {
                            session = CareCallVoicePreviewSession(initialPhase: option)
                        }
                    }
                    Button("예시 데이터 초기화") { session = CareCallVoicePreviewSession() }
                } label: {
                    Text("화면 선택")
                        .font(.caption).padding(8)
                        .background(.regularMaterial, in: Capsule())
                }
                .padding(.trailing, 12)
                .accessibilityIdentifier("carecall.voice.preview.scenes")
            }
        }
        .alert("개발 Preview", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("확인") { notice = nil }
        } message: { Text(notice ?? "") }
        .task(id: session.phase) {
            // Only the development host simulates a completed loading screen.
            guard session.phase == .loading else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, session.phase == .loading else { return }
            session.navigate(to: .completed)
        }
    }

}

#Preview("케어콜 전체 흐름 · 음성 ↔ 채팅") { CareCallConversationPreview() }
#Preview("음성 디자인 · 개별 화면 선택") { CareCallVoiceSectionPreview() }
#Preview("대화 시작 · 1:1837") { CareCallVoiceSectionPreview(initialPhase: .ready, showsControls: false) }
#Preview("음성 인식 · 1:1690") { CareCallVoiceSectionPreview(initialPhase: .listening, showsControls: false) }
#Preview("추가 질문 · 1:1718") { CareCallVoiceSectionPreview(initialPhase: .followUp, showsControls: false) }
#Preview("입력 전 · 1:1732") { CareCallVoiceSectionPreview(initialPhase: .emptyText, showsControls: false) }
#Preview("답변 확인 · 1:1758") { CareCallVoiceSectionPreview(initialPhase: .answer, showsControls: false) }
#Preview("마지막 답변 · 1:1787") { CareCallVoiceSectionPreview(initialPhase: .lastAnswer, showsControls: false) }
#Preview("정리 중 · 1:1816") { SymptomSummaryLoadingView() }
#Preview("정리 완료 · 1:1823") { CareCallVoiceSectionPreview(initialPhase: .completed, showsControls: false) }
#Preview("요약 · 1:1870") { CareCallVoiceSectionPreview(initialPhase: .summary, showsControls: false) }
#Preview("요약 수정 · 1:1903") { CareCallVoiceSectionPreview(initialPhase: .editing, showsControls: false) }
#endif
