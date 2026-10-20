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
import Observation

/// 케어콜 화면(CareCallFlowView)의 상태를 보관한다: 준비(대기 화면) → 대화(음성 통화·문자 답) → 요약 수정·저장.
/// 음성과 문자를 오가도 서비스의 같은 대화를 이어 간다. 저장하지 않고 떠나면 받은 답까지 자동으로 저장한다.
/// 받은 답은 답마다 폰에도 남겨, 앱이 꺼지거나 저장이 실패하면 다음에 케어콜에 들어갈 때 조용히 올린다.
/// 화면에 들어오면 loadPatient()로 로그인 환자를 찾는다 (PainRecordViewModel과 같은 방식)
@MainActor
@Observable
final class CareCallViewModel {
    enum ConnectionState {
        case loading
        case ready
        case signedOut
        case patientUnavailable
        case failed
    }

    enum PatientError: Error {
        /// 로그인 환자를 아직 찾지 못함 (화면은 ready일 때만 통화를 보여 준다)
        case notLoaded
    }

    private enum PatientSource {
        case repositories(auth: any AuthRepository, patient: any PatientRepository)
        case knownPatient(UUID)
    }

    let preparation = CareCallScreenState()
    let conversation = SymptomScreenState()
    /// 마지막 통화 결과
    private(set) var outcome: CareCallOutcome?
    /// 저장할 기록 (요약에서 고친 내용 포함). 요약에는 '있음'만 보이지만 저장은 없음·모름까지 한다 (#84)
    private(set) var record: SymptomRecord?
    private let service: any CareCalling
    private let repository: any SymptomRepository
    /// 서버에 저장하기 전까지 받은 답을 남겨 두는 곳 (이 케어콜은 pendingId 한 건)
    private let pending: any PendingCareCallRepository
    private let pendingId = UUID()
    @ObservationIgnored private let patientSource: PatientSource
    private var patientId: UUID?
    private var isLoadingPatient = false
    private(set) var connectionState: ConnectionState = .loading
    /// 지금 진행 중인 준비 (없으면 준비 중이 아님)
    private var preparing: Task<Void, Never>?
    /// 마지막으로 시작한 준비. 취소해도 서비스 작업(모델 불러오기 등)은 끝까지 돌기 때문에 다음 준비는 이게 끝난 뒤 시작한다
    private var last: Task<Void, Never>?
    /// 준비 요청마다 늘린다. 취소·재시도 뒤에 늦게 끝난 이전 준비가 상태를 덮어쓰지 않게
    private var generation = 0
    /// 지금 진행 중인 통화
    private var call: Task<Void, Never>?
    /// 지금 처리 중인 문자 답 (대화 시작 포함)
    private var typing: Task<Void, Never>?
    /// 서비스에서 대화를 시작함 (이후로는 음성·문자 모두 이 대화를 이어 간다)
    private var began = false
    /// 방식을 바꾸려고 통화를 끊음 (끊긴 통화를 요약으로 넘기지 않고 바꾼 방식으로 이어 간다)
    private var switchingMode = false
    /// 통화를 건 적이 있음. 통화가 끝나면 서비스가 음성 인식을 닫아서, 다시 걸 때는 음성 인식부터 준비한다
    private var hasCalled = false
    /// 대화 중에 대화 화면을 떠남 (끝나면 요약을 볼 사람이 없어 바로 저장한다)
    private var leftCall = false
    private var saving: Task<Void, Never>?
    private var isSaved = false

    init(service: any CareCalling, repository: any SymptomRepository, pending: any PendingCareCallRepository,
         authRepository: any AuthRepository, patientRepository: any PatientRepository) {
        self.service = service
        self.repository = repository
        self.pending = pending
        patientSource = .repositories(auth: authRepository, patient: patientRepository)
        bind()
    }

    #if DEBUG
    /// 환자를 이미 아는 경우 (테스트·Preview)
    init(service: any CareCalling, repository: any SymptomRepository, pending: any PendingCareCallRepository, patientId: UUID) {
        self.service = service
        self.repository = repository
        self.pending = pending
        patientSource = .knownPatient(patientId)
        self.patientId = patientId
        connectionState = .ready
        bind()
    }
    #endif

    private func bind() {
        show(.idle)
        preparation.onAction = { [weak self] action in
            switch action {
            case .prepare: self?.prepare()
            case .cancel: self?.cancelPreparation()
            }
        }
        conversation.onAction = { [weak self] action in self?.handle(action) }
    }

    // MARK: - 로그인 환자

    /// 로그인한 사용자의 환자 정보를 찾는다. 환자 계정이 없으면 patientUnavailable, 실패하면 로그인 여부로 signedOut·failed
    func loadPatient() async {
        guard patientId == nil, !isLoadingPatient else { return }
        guard case let .repositories(authRepository, patientRepository) = patientSource else { return }

        isLoadingPatient = true
        connectionState = .loading
        defer { isLoadingPatient = false }

        do {
            let userId = try await authRepository.getCurrentUserId()
            guard !Task.isCancelled else { return }

            let patient = try await patientRepository.findById(userId)
            guard !Task.isCancelled else { return }

            guard let patient else {
                connectionState = .patientUnavailable
                return
            }

            patientId = patient.user.id
            connectionState = .ready
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            connectionState = authRepository.isSignedIn() ? .failed : .signedOut
        }
    }

    private func loadedPatientId() throws -> UUID {
        guard let patientId else { throw PatientError.notLoaded }
        return patientId
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

    // MARK: - 대화 (대화 화면)

    private func handle(_ action: SymptomAction) {
        switch action {
        case .switchMode(let mode): switchMode(to: mode)
        case .start: start()
        case .answer(let answer): self.answer(answer)
        case .cancel: endCall()
        // 엔진이 지난 답을 되돌리지 못해 이전 질문으로 가지 않는다 (canGoPrevious는 늘 false)
        case .previous: break
        }
    }

    /// 요약·완료로 넘어갔거나 응급 안내로 끝남 (더 묻지 않는다)
    private var isOver: Bool {
        if conversation.summary != nil || conversation.didSave { return true }
        if case .emergencyEnded? = outcome { return true }
        return false
    }

    /// 대화 화면이 보이면 불린다 (끊긴 뒤 "다시 시도"도). 지금 방식으로 대화를 시작하거나 이어 간다
    @discardableResult
    func start() -> Task<Void, Never>? {
        conversation.mode == .voice ? startCall() : startText()
    }

    /// 대화 중에 음성·문자를 바꾼다. 대화 전이면 방식만 정하고, 화면이 start를 부를 때 그 방식으로 시작한다
    private func switchMode(to mode: SymptomConversationMode) {
        guard mode != conversation.mode else { return }
        conversation.mode = mode
        guard !isOver else { return }
        switch mode {
        case .text:
            if let call { // 통화를 끊고(거는 중이어도) 끝나면 같은 대화를 문자로 이어 간다 (startCall에서)
                switchingMode = true
                call.cancel()
                Task { await service.stop() }
            } else if began {
                continueInText()
            }
        case .voice:
            if began, typing == nil { startCall() } // 문자 답을 처리 중이면 끝난 뒤 이어서 (typing에서)
        }
    }

    /// 음성 통화로 대화를 시작하거나 이어 간다. 문자로 시작해 음성 준비가 안 됐으면 준비부터 한다
    @discardableResult
    func startCall() -> Task<Void, Never>? {
        guard call == nil, typing == nil, !isOver else { return nil }
        conversation.errorMessage = nil
        conversation.isWorking = true // 첫 질문을 말하기 전까지
        let task = Task {
            if !preparation.canStart { await (prepare() ?? last)?.value }
            var outcome: CareCallOutcome?
            var failure: Error?
            do {
                // 들어가자마자 떠났으면 걸지 않는다 (서비스는 통화를 시작할 때 이전 stop 표시를 지우기 때문에 여기서 막는다)
                try Task.checkCancellation()
                guard preparation.canStart else { throw CareCallServiceError.notPrepared }
                // 통화가 끝나면 서비스가 음성 인식을 닫아서, 다시 걸 때는 음성 인식부터 준비한다
                if hasCalled { try await service.prepareSpeech() }
                hasCalled = true
                try Task.checkCancellation()
                if !began {
                    _ = try service.begin(patientId: try loadedPatientId(), previous: try await today())
                    began = true
                }
                outcome = try await service.run { activity in self.show(activity) } // 통화하는 동안만 잡는다
            } catch is CancellationError {
            } catch {
                failure = error
            }
            call = nil
            conversation.isListening = false
            conversation.isWorking = false
            let switched = switchingMode
            switchingMode = false
            if leftCall, outcome == nil {
                endText() // 통화를 걸기 전에 떠남: 문자로 받은 답이 있으면 그것까지 저장한다
            } else if switched, !leftCall, !Self.isFinal(outcome) {
                start() // 방식을 바꿈: 끝까지 마친 게 아니면 같은 대화를 바꾼 방식으로 이어 간다 (끊는 중에 다시 바꿨으면 그 방식)
            } else if let outcome {
                finish(outcome)
            } else if case CareCallServiceError.notPrepared? = failure, began {
                // 문자로 하다 음성으로 바꿨는데 준비가 안 됨 (마이크 권한 등): 문자로 돌아온다
                conversation.mode = .text
                continueInText()
                conversation.errorMessage = "음성 통화를 준비하지 못했어요. 문자로 이어서 답해 주세요."
            } else if case CareCallServiceError.notPrepared? = failure {
                conversation.errorMessage = "통화 준비가 끝나지 않았어요. 다시 시도해 주세요."
            } else if let failure {
                finish(failure)
            }
        }
        call = task
        return task
    }

    /// 문자로 대화를 시작하거나 이어 간다. 문자에는 모델만 있으면 된다 (마이크·음성 인식 준비가 없어도 된다)
    @discardableResult
    func startText() -> Task<Void, Never>? {
        guard call == nil, typing == nil, !isOver else { return nil }
        conversation.errorMessage = nil
        if began {
            continueInText()
            return nil
        }
        conversation.isWorking = true
        return typing {
            // 대기 화면에서 하던 준비가 모델을 불러오는 중일 수 있다 (2.4GB를 두 번 불러오지 않게)
            await self.last?.value
            try await self.service.loadModel()
            try Task.checkCancellation()
            let turn = try self.service.begin(patientId: try self.loadedPatientId(), previous: try await self.today())
            self.began = true
            return turn
        } failed: { "대화를 준비하지 못했어요. 다시 시도해 주세요." }
    }

    /// 문자 답을 보낸다. 횟수·지속 시간 입력은 말로 한 답처럼 문장으로 바꿔 같은 엔진에 넣는다
    @discardableResult
    func answer(_ answer: SymptomConversationAnswer) -> Task<Void, Never>? {
        let text = Self.sentence(for: answer)
        guard conversation.mode == .text, began, call == nil, typing == nil, !isOver, !text.isEmpty else { return nil }
        conversation.errorMessage = nil
        conversation.isWorking = true
        return typing {
            try await self.service.answer(text)
        } failed: { "답을 전하지 못했어요. 다시 보내 주세요." }
    }

    /// 문자 대화 한 단계를 진행하고 다음 질문을 보여 준다
    private func typing(_ step: @escaping () async throws -> CareCallTurn, failed message: @escaping () -> String) -> Task<Void, Never> {
        let task = Task {
            do {
                show(try await step())
            } catch is CancellationError {
            } catch {
                conversation.errorMessage = message()
            }
            conversation.isWorking = false
            typing = nil
            // 처리하는 동안 화면을 떠났거나 음성으로 바꿨으면 이어서 한다
            if leftCall {
                endText()
            } else if conversation.mode == .voice, began, !isOver {
                startCall()
            }
        }
        typing = task
        return task
    }

    /// 답을 기다리는 지금 질문을 문자 입력으로 보여 준다
    private func continueInText() {
        guard let turn = service.current else { return }
        conversation.errorMessage = nil
        show(turn)
    }

    private func show(_ turn: CareCallTurn) {
        keep(service.progress)
        let input: SymptomConversationQuestion.Input = switch turn.number {
        case .count?: .frequency
        case .minutes?: .duration
        case nil: .text
        }
        conversation.question = SymptomConversationQuestion(id: UUID(), text: turn.utterance, guidance: nil, progress: nil, input: input)
        conversation.answerText = ""
        conversation.transcript = ""
        if let outcome = turn.outcome { finish(outcome) }
    }

    /// 문자 입력 → 엔진에 넣을 문장. "10+"는 정확한 횟수로 저장되지 않게 "열 번 넘게"로 (NumberParser가 읽지 않는다)
    static func sentence(for answer: SymptomConversationAnswer) -> String {
        switch answer {
        case .text(let text): text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .frequency(.count(let count)): "\(count)번"
        case .frequency(.tenPlus): "열 번 넘게"
        case .durationMinutes(let minutes) where minutes >= 60:
            minutes % 60 == 0 ? "\(minutes / 60)시간" : "\(minutes / 60)시간 \(minutes % 60)분"
        case .durationMinutes(let minutes): "\(minutes)분"
        }
    }

    private static func isFinal(_ outcome: CareCallOutcome?) -> Bool {
        switch outcome {
        case .completed?, .emergencyEnded?: true
        case .interrupted?, nil: false
        }
    }

    /// 대화 화면을 떠날 때 불린다. 통화 중이면 끊고(끊긴 곳까지의 기록은 outcome에 남는다), 문자 대화면 받은 답까지 끝낸다
    func endCall() {
        leftCall = true
        if let call {
            call.cancel()
            Task { await service.stop() }
        } else if typing == nil {
            endText() // 문자 답을 처리 중이면 끝난 뒤에 (typing)
        }
    }

    /// 마치지 않은 대화를 여기서 끝내고 받은 답까지 결과로 받는다 (떠났으면 finish가 바로 저장한다)
    private func endText() {
        guard began, !isOver else { return }
        began = false // 서비스가 대화를 닫는다 (두 번 끝내지 않게)
        finish(service.end())
    }

    private func show(_ activity: CareCallActivity) {
        switch activity {
        case .speaking(let text):
            keep(service.progress) // 답을 분석한 뒤 다음 질문을 말한다
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
        case .completed(let record) where record.symptoms.isEmpty:
            // 다시 거는 통화에서 달라진 게 없음: 더할 것이 없어 바로 완료 화면 (이때 보여 줄 화면은 화면 담당과 정할 예정)
            forget()
            isSaved = true
            conversation.didSave = true
        case .completed(let record), .interrupted(let record?):
            self.record = record
            keep(record)
            let summary = SymptomSummaryScreenState(record: SymptomRecordDisplay(record: record))
            summary.canSave = true
            summary.onAction = { [weak self] action in self?.handle(action) }
            conversation.summary = summary
            if leftCall { save(showingResult: false) }
        case .interrupted(nil):
            forget()
            conversation.question = nil
            conversation.errorMessage = "통화가 끊겼어요. 다시 시도해 주세요."
        case .emergencyEnded:
            forget() // 응급 종료는 저장하지 않는다. 마지막으로 말한 응급 안내가 화면에 남는다 (응급 화면은 디자인 팀과 정할 예정)
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
        let updated = SymptomRecord(id: record.id, patientId: record.patientId, recordedDate: record.recordedDate,
                                    conditionText: record.conditionText, symptoms: symptoms)
        self.record = updated
        keep(updated)
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
                forget() // 저장했거나 저장하지 않기로 정함. 실패하면 남겨 두고 다음에 케어콜에 들어갈 때 올린다
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

    /// 오늘 이미 저장된 기록 (있으면 다시 거는 통화). 지난번에 올리지 못한 기록을 먼저 올린다
    /// (그 기록이 오늘 것이면 이번 통화는 다시 거는 통화가 된다)
    private func today() async throws -> SymptomRecord? {
        await sendPending()
        return try await repository.findByPatientIdAndDate(try loadedPatientId(), Date())
    }

    // MARK: - 폰에 남기기

    /// 지금까지 받은 답을 폰에 남긴다. 남기지 못해도 대화는 이어 간다 (서버 저장은 따로 한다)
    private func keep(_ record: SymptomRecord?) {
        guard let record, !isSaved else { return }
        let complete = if case .completed? = outcome { true } else { false }
        try? pending.save(PendingCareCall(id: pendingId, record: record, complete: complete))
    }

    /// 이 케어콜에서 남긴 기록만 지운다 (지난 케어콜에서 올리지 못한 기록은 그대로)
    private func forget() {
        guard let patientId else { return }
        try? pending.delete(id: pendingId, patientId: patientId)
    }

    /// 지난 케어콜에서 앱이 꺼졌거나 저장에 실패해 남은 기록을 저장 규칙대로 조용히 올린다. 실패한 기록은 남겨 두고 다음에
    private func sendPending() async {
        guard let patientId else { return }
        for left in (try? pending.findAll(patientId: patientId)) ?? [] where left.id != pendingId {
            guard (try? await store(left.record, complete: left.complete)) != nil else { continue }
            try? pending.delete(id: left.id, patientId: patientId)
        }
    }

    /// 그날 기록은 하루 1건. 이미 있으면 끝까지 마친 통화(다시 거는 통화)는 그 기록에 더하고,
    /// 끊긴 통화는 저장하지 않는다 (일부만 답한 기록으로 그날 기록을 바꾸지 않게). 저장했으면 true
    private func store(_ record: SymptomRecord, complete: Bool) async throws -> Bool {
        guard let existing = try await repository.findByPatientIdAndDate(record.patientId, record.recordedDate) else {
            try await repository.save(entity: record)
            return true
        }
        guard complete else { return false }
        try await repository.save(entity: Self.merge(existing, with: record))
        return true
    }

    /// 다시 거는 통화의 기록을 그날 기록에 더한다 (덮어쓰지 않는다). 기록 id·환자·날짜·컨디션은 그날 기록 것
    /// - 그날 기록에 없는 증상(지난 통화가 끊겨 못 물음)과 기타 증상은 그대로 추가
    /// - 전에 없음·모름이었는데 이번에 있음 → 이번 항목으로 바꾼다
    /// - 전에도 있음 → 같은 부위면 기존 값을 두고 빈 칸만 채우고 내용에 "다시 통화: …"를 덧붙인다, 다른 부위면 추가
    /// - 이번에 없음·모름인데 그날 기록에 이미 있는 증상은 그대로 둔다. 전에 있던 증상을 이번에 없다고 하면(좋아짐)
    ///   환자가 한 말("다시 통화: 구토가 나아졌어요", 말이 없으면 "지금은 없다고 함")을,
    ///   검토가 필요한 답(요약에서 지움 등)이면 그 내용을 덧붙여 의료진이 보게 한다
    static func merge(_ old: SymptomRecord, with new: SymptomRecord) -> SymptomRecord {
        var symptoms = old.symptoms
        for entry in new.symptoms {
            let sameType = symptoms.filter { $0.symptomType == entry.symptomType }
            if entry.symptomType == .other || sameType.isEmpty {
                symptoms.append(entry)
                continue
            }
            guard entry.presence == .present else {
                let present = symptoms.indices.filter { symptoms[$0].symptomType == entry.symptomType && symptoms[$0].presence == .present }
                if entry.presence == .absent, !present.isEmpty {
                    // 없어졌다는 말은 그 증상 전체에 대한 말이라 부위별 항목마다 남긴다 (검토 필요 표시는 맨 앞에).
                    // 환자가 한 말이 있으면 그 말 그대로("다시 통화: 구토가 나아졌어요"), 없으면 "지금은 없다고 함"
                    for index in present {
                        symptoms[index] = filled(symptoms[index], with: entry, note: text(of: entry.detail) == nil ? "지금은 없다고 함" : nil)
                    }
                } else if entry.detail?.hasPrefix(Self.reviewMark) == true,
                          let index = symptoms.firstIndex(where: { $0.symptomType == entry.symptomType }) {
                    symptoms[index] = filled(symptoms[index], with: entry)
                }
                continue
            }
            if !sameType.contains(where: { $0.presence == .present }) {
                // 전 통화 내용(검토 필요 메모 등)은 버리지 않고 이번 항목에 "전 통화: …"로 남긴다
                let previous = sameType.first { $0.detail != nil }
                symptoms.removeAll { $0.symptomType == entry.symptomType }
                symptoms.append(previous.map { filled(entry, with: $0, label: "전 통화", textOnly: true) } ?? entry)
            } else if let index = symptoms.firstIndex(where: { $0.symptomType == entry.symptomType && $0.presence == .present
                                                                && sameSpot($0, entry) }) {
                symptoms[index] = filled(symptoms[index], with: entry)
            } else {
                symptoms.append(entry)
            }
        }
        // 목록 순서로 (같은 종류 안에서는 원래 순서)
        let rank = Dictionary(uniqueKeysWithValues: SymptomType.allCases.enumerated().map { ($1, $0) })
        let sorted = symptoms.enumerated()
            .sorted { (rank[$0.element.symptomType] ?? 0, $0.offset) < (rank[$1.element.symptomType] ?? 0, $1.offset) }
            .map(\.element)
        // 다시 거는 통화는 컨디션을 묻지 않으니 처음 통화의 컨디션을 그대로 둔다
        return SymptomRecord(id: old.id, patientId: old.patientId, recordedDate: old.recordedDate, conditionText: old.conditionText,
                             symptoms: sorted)
    }

    /// 같은 곳의 증상인지. 이번에 부위를 말하지 않았으면 같은 증상으로 본다
    private static func sameSpot(_ old: SymptomEntry, _ new: SymptomEntry) -> Bool {
        if new.bodyPart == nil, new.rawLocationText == nil { return true }
        if let part = new.bodyPart { return old.bodyPart == part }
        return old.rawLocationText == new.rawLocationText
    }

    private static let reviewMark = "[검토 필요]"
    private static let review = reviewMark + " "

    /// 검토 필요 표시를 뗀 내용 (표시만 있으면 nil)
    private static func text(of detail: String?) -> String? {
        guard let detail else { return nil }
        let text = detail.hasPrefix(reviewMark) ? detail.dropFirst(reviewMark.count).trimmingCharacters(in: .whitespaces) : detail
        return text.isEmpty ? nil : text
    }

    /// 전에도 있던 증상: 기존 값(유무 포함)은 두고 빈 칸만 이번 값으로 채운다. 이번 내용은 "다시 통화: …"로 덧붙인다.
    /// 검토 필요 표시는 맨 앞에 하나만. 길면 전 내용을 줄여 이번 답은 남긴다
    /// note가 있으면 덧붙일 항목의 내용 대신 그 말을 덧붙인다. label은 덧붙이는 말 앞 이름.
    /// textOnly면 내용만 덧붙이고 빈 칸(부위·횟수·지속 시간)은 채우지 않는다
    private static func filled(_ old: SymptomEntry, with new: SymptomEntry, note: String? = nil, label: String = "다시 통화",
                               textOnly: Bool = false) -> SymptomEntry {
        func cut(_ text: String, to room: Int) -> String { text.count <= room ? text : String(text.prefix(max(room - 1, 0))) + "…" }
        var oldText = text(of: old.detail)
        var added = (note ?? text(of: new.detail)).map { "\(label): " + $0 }
        var flagged = old.detail?.hasPrefix(reviewMark) == true || new.detail?.hasPrefix(reviewMark) == true
        // 길면 둘 다 남기도록 나눠 줄인다 (어느 쪽도 반보다 적게 줄이지 않는다). 잘랐으면 의료진이 원문을 보게 검토 필요
        if let o = oldText, let a = added, review.count + o.count + " / ".count + a.count > SymptomEntry.detailLimit {
            flagged = true
            let room = SymptomEntry.detailLimit - review.count - " / ".count
            let oldRoom = max(room / 2, room - a.count)
            oldText = cut(o, to: oldRoom)
            added = cut(a, to: room - min(o.count, oldRoom))
        }
        let body = [oldText, added].compactMap(\.self).joined(separator: " / ")
        // 내용 없이 검토 필요 표시만 있어도 표시는 남긴다
        let detail = body.isEmpty ? (flagged ? reviewMark : nil) : String(((flagged ? review : "") + body).prefix(SymptomEntry.detailLimit))
        let fill = textOnly ? nil : new
        let merged = try? SymptomEntry(id: old.id, symptomType: old.symptomType, presence: old.presence,
                                       bodyPart: old.bodyPart ?? fill?.bodyPart, bodySide: old.bodySide ?? fill?.bodySide,
                                       rawLocationText: old.rawLocationText ?? fill?.rawLocationText,
                                       durationMinutes: old.durationMinutes ?? fill?.durationMinutes,
                                       occurrenceCount: old.occurrenceCount ?? fill?.occurrenceCount, detail: detail)
        return merged ?? old
    }

    private static func number(_ text: String, else error: SymptomValueError) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        guard let value = Int(trimmed) else { throw error }
        return value
    }
}
