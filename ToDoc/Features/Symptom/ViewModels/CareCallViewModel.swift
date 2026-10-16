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

/// 케어콜 화면(CareCallFlowView)의 상태를 보관한다: 준비(대기 화면) → 음성 통화(대화 화면) → 요약 수정·저장.
/// 준비한 서비스로 그대로 통화한다. 저장하지 않고 떠나면 받은 답까지 자동으로 저장한다. 문자 대화는 아직 연결하지 않는다
@MainActor
final class CareCallViewModel {
    let preparation = CareCallScreenState()
    let conversation = SymptomScreenState()
    /// 마지막 통화 결과
    private(set) var outcome: CareCallOutcome?
    /// 저장할 기록 (요약에서 고친 내용 포함). 요약에는 '있음'만 보이지만 저장은 없음·모름까지 한다 (#84)
    private(set) var record: SymptomRecord?
    private let service: any CareCalling
    private let repository: any SymptomRepository
    private let patientId: UUID
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
    /// 통화 중에 대화 화면을 떠남 (끝나면 요약을 볼 사람이 없어 바로 저장한다)
    private var leftCall = false
    private var saving: Task<Void, Never>?
    private var isSaved = false

    /// patientId: 로그인한 환자 (화면에 연결할 때 getCurrentUserId()로 받아 넘긴다)
    init(service: any CareCalling, repository: any SymptomRepository, patientId: UUID) {
        self.service = service
        self.repository = repository
        self.patientId = patientId
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
                let outcome = try await service.run { activity in self.show(activity) } // 통화하는 동안만 잡는다
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
        leftCall = true
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
            self.record = record
            let summary = SymptomSummaryScreenState(record: SymptomRecordDisplay(record: record))
            summary.canSave = true
            summary.onAction = { [weak self] action in self?.handle(action) }
            conversation.summary = summary
            if leftCall { save(showingResult: false) }
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

    // MARK: - 요약 (수정·삭제·저장)

    private func handle(_ action: SymptomSummaryAction) {
        guard let summary = conversation.summary else { return }
        switch action {
        case .edit(let id):
            guard saving == nil else { return }
            summary.editingEntryID = id
            summary.editErrorMessage = nil
        case .discardEdit:
            summary.editingEntryID = nil
            summary.editErrorMessage = nil
        case .finishEdit(let id, let input):
            guard saving == nil else { return } // 저장 중에는 저장하는 기록을 바꾸지 않는다
            finishEdit(id, input, in: summary)
        case .delete(let id):
            guard saving == nil else { return }
            delete(id, in: summary)
        case .save: save(showingResult: true)
        case .cancel: save(showingResult: false) // 저장하지 않고 떠나면 받은 답까지 저장한다
        }
    }

    /// 고친 횟수·지속 시간·내용을 검증해 반영한다. 비운 칸은 값 없음. 검증에 걸리면 이유를 보여 주고 고치는 중으로 둔다
    private func finishEdit(_ id: UUID, _ input: SymptomEntryEditInput, in summary: SymptomSummaryScreenState) {
        guard let record, let entry = record.symptoms.first(where: { $0.id == id }) else { return }
        do {
            let detail = input.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            let edited = try SymptomEntry(
                id: entry.id, symptomType: entry.symptomType, presence: entry.presence, bodyPart: entry.bodyPart, bodySide: entry.bodySide,
                rawLocationText: entry.rawLocationText, durationMinutes: try Self.number(input.durationText, else: .invalidDuration),
                occurrenceCount: try Self.number(input.occurrenceText, else: .invalidOccurrenceCount), detail: detail.isEmpty ? nil : detail)
            update(record.symptoms.map { $0.id == id ? edited : $0 }, in: summary)
            summary.editingEntryID = nil
            summary.editErrorMessage = nil
        } catch {
            summary.editErrorMessage = switch error {
            case SymptomValueError.invalidDuration: "지속 시간은 10분에서 1440분 사이 숫자로 입력해 주세요."
            case SymptomValueError.invalidOccurrenceCount: "횟수는 1에서 100 사이 숫자로 입력해 주세요."
            case SymptomValueError.detailTooLong: "내용은 \(SymptomEntry.detailLimit)자까지 쓸 수 있어요."
            default: "입력한 내용을 확인해 주세요."
            }
        }
    }

    /// 환자가 요약에서 지운 증상은 '없음'으로 바꾸고 의료진이 알 수 있게 검토 필요로 남긴다.
    /// 같은 증상의 다른 부위 항목이 남아 있으면 그 항목만 뺀다
    private func delete(_ id: UUID, in summary: SymptomSummaryScreenState) {
        guard let record, let index = record.symptoms.firstIndex(where: { $0.id == id }) else { return }
        var symptoms = record.symptoms
        let removed = symptoms.remove(at: index)
        if !symptoms.contains(where: { $0.symptomType == removed.symptomType && $0.presence == .present }) {
            // 원래 내용에 이미 검토 필요 표시가 있으면 한 번만 쓴다
            let original = removed.detail.map { $0.hasPrefix("[검토 필요] ") ? String($0.dropFirst("[검토 필요] ".count)) : $0 }
            let note = ["[검토 필요] 환자가 요약에서 지움", original].compactMap(\.self).joined(separator: ": ")
            if let absent = try? SymptomEntry(id: UUID(), symptomType: removed.symptomType, presence: .absent, bodyPart: nil, bodySide: nil,
                                              durationMinutes: nil, occurrenceCount: nil,
                                              detail: String(note.prefix(SymptomEntry.detailLimit))) {
                symptoms.insert(absent, at: index)
            }
        }
        update(symptoms, in: summary)
        summary.editingEntryID = nil
    }

    private func update(_ symptoms: [SymptomEntry], in summary: SymptomSummaryScreenState) {
        guard let record else { return }
        let updated = SymptomRecord(id: record.id, recordedDate: record.recordedDate, symptoms: symptoms)
        self.record = updated
        summary.record = SymptomRecordDisplay(record: updated)
    }

    /// 기록을 한 번만 저장한다. 저장 버튼이면 결과를 보여 주고(성공 → 완료 화면, 실패 → 다시 저장),
    /// 떠나면서 하는 자동 저장은 화면에 아무것도 보여 주지 않는다
    @discardableResult
    func save(showingResult: Bool) -> Task<Void, Never>? {
        guard let record, !isSaved, saving == nil else { return nil }
        let summary = conversation.summary
        if showingResult {
            summary?.isSaving = true
            summary?.canSave = false
            summary?.errorMessage = nil
            summary?.editingEntryID = nil
        }
        let complete = if case .completed? = outcome { true } else { false }
        let task = Task {
            do {
                let stored = try await store(record, complete: complete)
                isSaved = true // 저장하지 않기로 한 기록도 다시 저장하지 않는다
                if showingResult, stored { conversation.didSave = true }
                if showingResult, !stored { summary?.errorMessage = "오늘 기록이 이미 있어서, 중간에 끊긴 이번 답은 저장하지 않았어요." }
            } catch {
                if showingResult { summary?.errorMessage = "저장하지 못했어요. 다시 저장해 주세요." }
            }
            summary?.isSaving = false
            summary?.canSave = !isSaved
            saving = nil
        }
        saving = task
        return task
    }

    /// 그날 기록은 하루 1건. 이미 있으면 끝까지 마친 통화는 그 기록을 이번 기록으로 바꾸고(같은 id),
    /// 끊긴 통화는 저장하지 않는다 (일부만 답한 기록이 그날 기록을 지우지 않게). 저장했으면 true
    private func store(_ record: SymptomRecord, complete: Bool) async throws -> Bool {
        let existing = try await repository.findByPatientIdAndDate(patientId, record.recordedDate)
        if existing != nil, !complete { return false }
        let replaced = SymptomRecord(id: existing?.id ?? record.id, recordedDate: record.recordedDate, symptoms: record.symptoms)
        try await repository.save(replaced, for: patientId)
        return true
    }

    private static func number(_ text: String, else error: SymptomValueError) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        guard let value = Int(trimmed) else { throw error }
        return value
    }
}
