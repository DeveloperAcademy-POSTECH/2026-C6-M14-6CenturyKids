import Foundation
import Observation

/// 로그인한 환자 화면이 보관하는 메모리 초안입니다. 조회·저장·전송은 하지 않습니다.
@Observable final class PrevisitSession {
    var draft: PrevisitDraft
    private(set) var step: PrevisitStep
    private(set) var isWriting = false

    init(step: PrevisitStep = .day, draft: PrevisitDraft = .init()) {
        self.step = step
        self.draft = draft
    }

    var hasDraft: Bool {
        draft.day != nil || !draft.letter.isEmpty || draft.mood != nil
    }

    var canContinue: Bool {
        switch step {
        case .day: draft.day?.isSelectable == true
        case .letter: true // 기존 #137의 편지는 선택 입력입니다.
        case .mood: draft.mood != nil
        }
    }

    func start() { isWriting = true }
    func pause() { isWriting = false }

    func selectDay(_ day: PrevisitDay) {
        guard day.isSelectable else { return }
        draft.day = day
    }

    func refreshDays(_ days: [PrevisitDay]) {
        guard let selected = draft.day else { return }
        draft.day = days.first { $0.id == selected.id && $0.isSelectable }
        if draft.day == nil { step = .day }
    }

    func next() {
        guard canContinue else { return }
        switch step {
        case .day: step = .letter
        case .letter: step = .mood
        case .mood: break // 기분 선택 이후는 실제 저장 계약이 연결되어야 합니다.
        }
    }

    func previous() {
        switch step {
        case .day: pause()
        case .letter: step = .day
        case .mood: step = .letter
        }
    }

    func discard() {
        draft = .init()
        step = .day
        pause()
    }
}
