//
//  CareCallViewModel.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation

/// 케어콜 화면(CareCallFlowView)의 상태를 보관한다: 준비(대기 화면) → 음성 통화(대화 화면) → 요약.
/// 준비한 서비스로 그대로 통화한다. 문자 대화와 요약 수정·저장은 아직 연결하지 않는다
@MainActor
final class CareCallViewModel {
    let preparation = CareCallScreenState()
    let conversation = SymptomScreenState()
    /// 마지막 통화 결과. 저장은 Service를 연결할 때 한다 (요약에는 '있음'만 보이지만 저장은 없음·모름까지, #84)
    private(set) var outcome: CareCallOutcome?
    private let service: any CareCalling
    /// 지금 진행 중인 준비 (없으면 준비 중이 아님)
    private var preparing: Task<Void, Never>?
    /// 마지막으로 시작한 준비. 취소해도 서비스 작업(모델 불러오기 등)은 끝까지 돌기 때문에 다음 준비는 이게 끝난 뒤 시작한다
    private var last: Task<Void, Never>?
    /// 준비 요청마다 늘린다. 취소·재시도 뒤에 늦게 끝난 이전 준비가 상태를 덮어쓰지 않게
    private var generation = 0
    /// 지금 진행 중인 통화
    private var call: Task<Void, Never>?
    /// 통화를 건 적이 있음. 통화가 끝나면 서비스가 음성 인식을 닫아서, 다시 걸 때는 음성 인식부터 준비한다
    private var hasCalled = false

    init(service: any CareCalling) {
        self.service = service
        show(.idle)
        preparation.onAction = { [weak self] action in
            switch action {
            case .prepare: self?.prepare()
            case .cancel: self?.cancelPreparation()
            }
        }
        conversation.onAction = { [weak self] action in self?.handle(action) }
    }

    // MARK: - 준비 (대기 화면)

    /// 대기 화면이 보일 때마다(앱으로 돌아올 때 포함) 불린다. 준비 중이거나 이미 끝났으면 그대로 두고,
    /// 실패했으면 처음 단계부터 다시 한다 (서비스가 끝난 단계는 건너뛴다)
    @discardableResult
    func prepare() -> Task<Void, Never>? {
        guard preparing == nil, preparation.preparation != .ready else { return nil }
        generation += 1
        let current = generation
        show(.preparing(.permissions))
        let previous = last
        let task = Task {
            // 화면을 떠났다 바로 돌아오면 취소한 준비가 아직 모델을 불러오는 중일 수 있다 (2.4GB를 두 번 불러오지 않게)
            await previous?.value
            do {
                try advance(to: .preparing(.permissions), current)
                try await service.requestMicrophone()
                try advance(to: .preparing(.model), current)
                try await service.loadModel()
                try advance(to: .preparing(.speechAssets), current)
                try await service.prepareSpeech()
                try advance(to: .ready, current)
            } catch {
                guard current == generation else { return } // 취소했거나 새 준비가 시작됨
                show(Self.state(for: error))
            }
            if current == generation { preparing = nil }
        }
        preparing = task
        last = task
        return task
    }

    /// 대기 화면을 떠날 때 불린다. 준비 중이면 멈추고 처음 상태로 돌린다.
    /// 준비가 끝났으면 그대로 둔다 (전화를 받아 통화 화면으로 넘어갈 때도 불린다)
    func cancelPreparation() {
        guard let preparing else { return }
        generation += 1
        preparing.cancel()
        self.preparing = nil
        show(.idle)
    }

    private func advance(to state: CareCallPreparationState, _ current: Int) throws {
        try Task.checkCancellation()
        guard current == generation else { throw CancellationError() }
        show(state)
    }

    private func show(_ state: CareCallPreparationState) {
        preparation.preparation = state
        if case .preparing = state { preparation.isPreparing = true } else { preparation.isPreparing = false }
        preparation.canStart = state == .ready
    }

    /// 준비 오류 → 화면 상태. 원래 오류 문구는 화면에 내보내지 않는다
    private static func state(for error: Error) -> CareCallPreparationState {
        switch error {
        case AudioRecorderError.microphoneDenied: .microphoneDenied
        case LanguageModelError.modelMissing: .modelMissing
        case LanguageModelError.loadFailed: .modelLoadFailed
        case SpeechRecognizerError.koreanUnsupported: .speechRecognitionUnsupported
        default: .failed
        }
    }

    // MARK: - 통화 (대화 화면)

    private func handle(_ action: SymptomAction) {
        switch action {
        case .switchMode(let mode): conversation.mode = mode
        case .start: startCall()
        case .cancel: endCall()
        // 음성 통화는 스스로 듣고 다음 질문으로 넘어가서 이전·답변 버튼을 쓰지 않는다. 문자 대화는 아직 연결 전
        case .previous, .answer: break
        }
    }

    /// 대화 화면이 보이면 불린다 (끊긴 뒤 "다시 시도"도). 통화 중이거나 이미 요약까지 갔으면 그대로 둔다
    @discardableResult
    func startCall() -> Task<Void, Never>? {
        guard conversation.mode == .voice else {
            conversation.errorMessage = "문자 대화는 아직 연결 전이에요."
            return nil
        }
        guard call == nil, conversation.summary == nil else { return nil }
        guard preparation.canStart else {
            conversation.errorMessage = "통화 준비가 끝나지 않았어요. 다시 시도해 주세요."
            return nil
        }
        conversation.errorMessage = nil
        conversation.isWorking = true // 첫 질문을 말하기 전까지
        let retry = hasCalled
        hasCalled = true
        let task = Task {
            do {
                if retry { try await service.prepareSpeech() }
                // 들어가자마자 떠났으면 걸지 않는다 (서비스는 통화를 시작할 때 이전 stop 표시를 지우기 때문에 여기서 막는다)
                try Task.checkCancellation()
                let outcome = try await service.run { [weak self] activity in self?.show(activity) }
                finish(outcome)
            } catch is CancellationError {
                conversation.isWorking = false
            } catch {
                finish(error)
            }
            call = nil
        }
        call = task
        return task
    }

    /// 대화 화면을 떠날 때 불린다. 통화 중이면 끊는다 (끊긴 곳까지의 기록은 outcome에 남는다)
    func endCall() {
        guard let call else { return }
        call.cancel()
        Task { await service.stop() }
    }

    private func show(_ activity: CareCallActivity) {
        switch activity {
        case .speaking(let text):
            conversation.question = SymptomConversationQuestion(id: UUID(), text: text, guidance: nil, progress: nil, input: .text)
            conversation.transcript = ""
            conversation.isListening = false
            conversation.isWorking = false
        case .listening:
            conversation.isListening = true
        case .heard(let text):
            conversation.transcript = text
            conversation.isListening = false
            conversation.isWorking = true // 분석 중
        }
    }

    private func finish(_ outcome: CareCallOutcome) {
        self.outcome = outcome
        conversation.isListening = false
        conversation.isWorking = false
        switch outcome {
        case .completed(let record), .interrupted(let record?):
            conversation.summary = SymptomSummaryScreenState(record: Self.display(record))
        case .interrupted(nil):
            conversation.question = nil
            conversation.errorMessage = "통화가 끊겼어요. 다시 시도해 주세요."
        case .emergencyEnded:
            break // 마지막으로 말한 응급 안내가 화면에 남는다 (응급 화면은 디자인 팀과 정할 예정)
        }
    }

    private func finish(_ error: Error) {
        conversation.question = nil
        conversation.isListening = false
        conversation.isWorking = false
        conversation.errorMessage = "통화 중 문제가 생겼어요. 다시 시도해 주세요."
    }

    /// 요약 화면용. 없음·모름도 그대로 넘기고, 화면이 presentSymptoms로 있음만 보여 준다 (#76)
    private static func display(_ record: SymptomRecord) -> SymptomRecordDisplay {
        SymptomRecordDisplay(id: record.id, recordedDate: record.recordedDate, symptoms: record.symptoms.map {
            SymptomEntryDisplay(id: $0.id, symptomType: $0.symptomType, presence: $0.presence, bodyPart: $0.bodyPart,
                                bodySide: $0.bodySide, rawLocationText: $0.rawLocationText, durationMinutes: $0.durationMinutes,
                                occurrenceCount: $0.occurrenceCount, detail: $0.detail)
        })
    }
}
