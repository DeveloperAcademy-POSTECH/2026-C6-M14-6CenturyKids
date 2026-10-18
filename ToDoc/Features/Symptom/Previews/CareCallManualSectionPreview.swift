#if DEBUG
import SwiftUI

/// In-memory development samples only. Entered values never reach a repository or a care-call engine.
struct CareCallManualSectionPreview: View {
    @State private var step: CareCallManualStep
    @State private var draft = Self.sampleDraft
    @State private var notice: String?
    let showsControls: Bool

    init(initialStep: CareCallManualStep = .symptoms, showsControls: Bool = true) {
        _step = State(initialValue: initialStep)
        self.showsControls = showsControls
    }

    var body: some View {
        CareCallManualSectionView(step: step, draft: $draft,
            onNext: advance, onSkip: advance,
            onEnd: { notice = "Preview 대화를 종료했어요. 실제 기록은 저장하지 않았어요."; step = .symptoms },
            onSwitchToVoice: { notice = "음성 전환 동작을 확인했어요. 이 Preview에서는 마이크를 사용하지 않아요." })
        .overlay(alignment: .topTrailing) {
            if showsControls {
                Menu {
                    Text("개발 Preview · 예시 데이터")
                    ForEach(CareCallManualStep.allCases) { option in
                        Button("\(option.title) · \(option.figmaNodeID)") { step = option }
                    }
                    Button("예시 데이터 초기화") { draft = Self.sampleDraft; step = .symptoms }
                } label: {
                    Text("화면 선택")
                        .font(.caption).padding(8)
                        .background(.regularMaterial, in: Capsule())
                }
                .padding(.trailing, 12)
                .accessibilityIdentifier("carecall.manual.preview.scenes")
            }
        }
        .alert("개발 Preview", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("확인") { notice = nil }
        } message: { Text(notice ?? "") }
    }

    private func advance() {
        let sequence = CareCallManualStep.allCases
        guard let index = sequence.firstIndex(of: step), index + 1 < sequence.count else {
            notice = "입력한 예시 답변을 확인했어요. 실제 기록은 저장하지 않았어요."
            step = .symptoms
            return
        }
        step = sequence[index + 1]
    }

    private static var sampleDraft: CareCallManualDraft {
        var draft = CareCallManualDraft()
        draft.symptoms = [.appetite, .other]
        draft.dailyLife = "밥 먹기가 두려워요"
        draft.other = "오늘 비가 오려는지 항암 부작용인지 관절이 아프기 시작했어요"
        return draft
    }
}

#Preview("케어콜 전체 흐름 · 음성 ↔ 채팅") { CareCallConversationPreview() }
#Preview("수동 입력 디자인 · 개별 화면 선택") { CareCallManualSectionPreview() }
#Preview("증상 선택 · 72:3342") { CareCallManualSectionPreview(initialStep: .symptoms, showsControls: false) }
#Preview("일상 생활 · 1:5402") { CareCallManualSectionPreview(initialStep: .dailyLife, showsControls: false) }
#Preview("횟수 · 1:5457") { CareCallManualSectionPreview(initialStep: .frequency, showsControls: false) }
#Preview("지속 시간 · 1:5486") { CareCallManualSectionPreview(initialStep: .duration, showsControls: false) }
#Preview("그 외의 불편 · 72:3411") { CareCallManualSectionPreview(initialStep: .other, showsControls: false) }
#endif
