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
        case notLoaded
    }

    private enum PatientSource {
        case repositories(auth: any AuthRepository, patient: any PatientRepository)
        case knownPatient(UUID)
    }

    let preparation = CareCallScreenState()
    let conversation = SymptomScreenState()
    private(set) var outcome: CareCallOutcome?
    private(set) var record: SymptomRecord?
    private var todayRecord: SymptomRecord?
    private let service: any CareCalling
    private let repository: any SymptomRepository
    private let pending: any PendingCareCallRepository
    private let pendingId = UUID()
    @ObservationIgnored private let patientSource: PatientSource
    private var patientId: UUID?
    private var isLoadingPatient = false
    private(set) var connectionState: ConnectionState = .loading
    private var preparing: Task<Void, Never>?
    private var last: Task<Void, Never>?
    private var generation = 0
    private var call: Task<Void, Never>?
    private var typing: Task<Void, Never>?
    private var began = false
    private var switchingMode = false
    private var hasCalled = false
    private var leftCall = false
    private var callAfterTyping = false
    private var paused = false
    private var autoStart: Task<Void, Never>?
    var autoStartDelay: Duration = .zero
    private var hadEmergency = false
    private var saving: Task<Void, Never>?
    private var isSaved = false
    @ObservationIgnored private var analytics: SymptomConversationAnalytics
    private var analyticsQuestion: SymptomConversationAnalytics.QuestionPresentation?
    @ObservationIgnored private var pendingVoiceAdvance = false
    private var showsPauseConfirmation = false

    init(service: any CareCalling, repository: any SymptomRepository, pending: any PendingCareCallRepository,
         authRepository: any AuthRepository, patientRepository: any PatientRepository,
         trackAnalytics: SymptomConversationAnalytics.Track? = nil) {
        self.service = service
        self.repository = repository
        self.pending = pending
        analytics = SymptomConversationAnalytics(track: trackAnalytics)
        patientSource = .repositories(auth: authRepository, patient: patientRepository)
        bind()
    }

    #if DEBUG
    init(service: any CareCalling, repository: any SymptomRepository, pending: any PendingCareCallRepository, patientId: UUID) {
        self.service = service
        self.repository = repository
        self.pending = pending
        analytics = SymptomConversationAnalytics()
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

    @discardableResult
    func prepare() -> Task<Void, Never>? {
        guard preparing == nil, preparation.preparation != .ready else { return nil }
        generation += 1
        let current = generation
        show(.preparing(.permissions))
        let previous = last
        let task = Task {
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

    private static func state(for error: Error) -> CareCallPreparationState {
        switch error {
        case AudioRecorderError.microphoneDenied: .microphoneDenied
        case LanguageModelError.modelMissing: .modelMissing
        case LanguageModelError.modelNotReady: .modelLoadFailed
        case SpeechRecognizerError.koreanUnsupported: .speechRecognitionUnsupported
        default: .failed
        }
    }

    private func handle(_ action: SymptomAction) {
        switch action {
        case .open: open()
        case .switchMode(let mode): switchMode(to: mode)
        case .start: start()
        case .answer(let answer): self.answer(answer)
        case .cancel: endCall()
        case .previous: goBack()
        case .pause:
            showsPauseConfirmation = true
            analytics.updateScreen(.paused)
            pause()
        case .resume:
            showsPauseConfirmation = false
            resume()
        case .discard:
            analytics.finishInterval(reason: "discarded")
            discard()
        case .stopForEmergency: stopForEmergency()
        case .continueAfterEmergency: continueAfterEmergency()
        }
    }

    var analyticsScreen: SymptomConversationAnalytics.Screen {
        guard !leftCall, !conversation.isEmergency else { return .hidden }
        if showsPauseConfirmation { return .paused }
        if conversation.summary != nil || conversation.didSave {
            if case .completed? = outcome { return .completed }
            return .hidden
        }
        if conversation.isSummarizing { return .visible(.summaryLoading, conversation.mode) }
        if conversation.question != nil { return .visible(.conversation, conversation.mode, analyticsQuestion) }
        return .hidden
    }

    func updateAnalyticsScreen(_ screen: SymptomConversationAnalytics.Screen) {
        analytics.updateScreen(screen)
    }

    private var isOver: Bool {
        if conversation.summary != nil || conversation.didSave { return true }
        if case .emergencyEnded? = outcome { return true }
        return false
    }

    @discardableResult
    func open() -> Task<Void, Never>? {
        guard conversation.mode == .voice else { return start() }
        guard !began, call == nil, typing == nil, !isOver else { return nil }
        conversation.errorMessage = nil
        conversation.isWorking = true
        let opening = typing({ [self] in
            var turn = try await beginConversation()
            turn.utterance = service.voiceOpening ?? turn.utterance
            return turn
        }) { "대화를 준비하지 못했어요. 다시 시도해 주세요." }
        let task = Task {
            await opening.value
            guard (try? await Task.sleep(for: autoStartDelay)) != nil, autoStart != nil else { return }
            autoStart = nil
            if conversation.mode == .voice, began, !leftCall, !isOver { startCall() }
        }
        autoStart = task
        return task
    }

    @discardableResult
    private func cancelAutoStart() -> Bool {
        guard let autoStart else { return false }
        autoStart.cancel()
        self.autoStart = nil
        return true
    }

    @discardableResult
    func start() -> Task<Void, Never>? {
        conversation.mode == .voice ? startCall() : startText()
    }

    private func switchMode(to mode: SymptomConversationMode) {
        guard mode != conversation.mode else { return }
        cancelAutoStart()
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
            if typing != nil {
                callAfterTyping = true // 문자 답을 처리 중이면 끝난 뒤 이어서 (typing에서)
            } else if began {
                startCall()
            }
        }
    }

    @discardableResult
    func startCall() -> Task<Void, Never>? {
        guard call == nil, typing == nil, !isOver else { return nil }
        conversation.errorMessage = nil
        conversation.needsMicrophone = false
        conversation.isWorking = true // 첫 질문을 말하기 전까지
        conversation.voiceState = .thinking
        conversation.isCalling = true
        let task = Task {
            if !preparation.canStart { await (prepare() ?? last)?.value }
            var outcome: CareCallOutcome?
            var failure: Error?
            do {
                try Task.checkCancellation()
                guard preparation.canStart else { throw CareCallServiceError.notPrepared }
                if hasCalled { try await service.prepareSpeech() }
                hasCalled = true
                try Task.checkCancellation()
                if !began {
                    todayRecord = try await today()
                    _ = try service.begin(patientId: try loadedPatientId(), previous: todayRecord)
                    began = true
                }
                outcome = try await service.run { activity in self.show(activity) } 
            } catch is CancellationError {
            } catch {
                failure = error
            }
            call = nil
            conversation.voiceState = .thinking
            conversation.isWorking = false
            conversation.isCalling = false
            let switched = switchingMode
            switchingMode = false
            if leftCall, outcome == nil {
                endText() // 통화를 걸기 전에 떠남: 문자로 받은 답이 있으면 그것까지 저장한다
            } else if switched, !leftCall, !Self.isFinal(outcome) {
                // 방식을 바꿈: 끝까지 마친 게 아니면 같은 대화를 바꾼 방식으로 이어 간다 (끊는 중에 다시 바꿨으면 그 방식).
                // 기록 중단 팝업으로 잠시 끊었으면 환자의 선택을 기다린다 (resume)
                if !paused { start() }
            } else if let outcome {
                finish(outcome)
            } else if case CareCallServiceError.notPrepared? = failure, began {
                // 문자로 하다 음성으로 바꿨는데 준비가 안 됨 (마이크 권한 등): 문자로 돌아온다
                conversation.mode = .text
                continueInText()
                conversation.errorMessage = "음성 통화를 준비하지 못했어요. 문자로 이어서 답해 주세요."
                conversation.needsMicrophone = preparation.preparation == .microphoneDenied
            } else if case CareCallServiceError.notPrepared? = failure {
                conversation.errorMessage = "통화 준비가 끝나지 않았어요. 다시 시도해 주세요."
            } else if let failure {
                finish(failure)
            }
        }
        call = task
        return task
    }

    @discardableResult
    func startText() -> Task<Void, Never>? {
        guard call == nil, typing == nil, !isOver else { return nil }
        conversation.errorMessage = nil
        if began {
            continueInText()
            return nil
        }
        conversation.isWorking = true
        return typing(beginConversation) { "대화를 준비하지 못했어요. 다시 시도해 주세요." }
    }

    private func beginConversation() async throws -> CareCallTurn {
        // 대기 화면에서 하던 준비가 아직 진행 중일 수 있다 (준비가 겹치지 않게)
        await last?.value
        try await service.loadModel()
        try Task.checkCancellation()
        todayRecord = try await today()
        let turn = try service.begin(patientId: try loadedPatientId(), previous: todayRecord)
        began = true
        return turn
    }

    @discardableResult
    func answer(_ answer: SymptomConversationAnswer) -> Task<Void, Never>? {
        let text = Self.sentence(for: answer)
        guard conversation.mode == .text, began, call == nil, typing == nil, !isOver, !text.isEmpty else { return nil }
        conversation.errorMessage = nil
        conversation.isWorking = true
        // 마지막 질문의 답이면 정리하는 화면을 보여 준다 (더 물을 게 생기면 다음 질문으로 돌아간다)
        conversation.isSummarizing = conversation.question?.isLastQuestion == true
        return typing {
            try await self.service.answer(text)
        } failed: { "답을 전하지 못했어요. 다시 보내 주세요." }
    }

    private func typing(_ step: @escaping () async throws -> CareCallTurn, failed message: @escaping () -> String) -> Task<Void, Never> {
        let task = Task {
            do {
                let turn = try await step()
                if let completion = turn.answerCompletion {
                    analytics.answerCompleted(completion, mode: .text)
                }
                show(turn, navigation: turn.answerCompletion == nil ? nil : .nextButton)
            } catch is CancellationError {
            } catch {
                conversation.errorMessage = message()
            }
            conversation.isWorking = false
            conversation.isSummarizing = false
            typing = nil
            let wantsCall = callAfterTyping
            callAfterTyping = false
            // 처리하는 동안 화면을 떠났거나 음성으로 바꿨으면 이어서 한다
            if leftCall {
                endText()
            } else if wantsCall, conversation.mode == .voice, began, !isOver {
                startCall()
            }
        }
        typing = task
        return task
    }

    private func continueInText() {
        guard let turn = service.current else { return }
        conversation.errorMessage = nil
        show(turn, navigation: takeVoiceAdvance())
    }

    private func takeVoiceAdvance() -> SymptomConversationAnalytics.QuestionPresentation.Navigation? {
        defer { pendingVoiceAdvance = false }
        return pendingVoiceAdvance ? .nextAutomatic : nil
    }

    private func show(_ turn: CareCallTurn, navigation: SymptomConversationAnalytics.QuestionPresentation.Navigation? = nil) {
        keep(service.progress)
        let input: SymptomConversationQuestion.Input = switch turn.number {
        case .count?: .frequency
        case nil: .text
        }
        conversation.question = question(turn.utterance, of: turn, input: input)
        analyticsQuestion = turn.questionID.map { .init(id: $0, navigation: navigation) }
        conversation.answerText = ""
        conversation.transcript = ""
        conversation.restoredAnswer = nil
        if let outcome = turn.outcome { finish(outcome) }
    }

    private static let moreGuidance = "말씀해 주신 내용에 대해 조금 더 여쭤볼게요"

    private func question(_ text: String, of turn: CareCallTurn?, input: SymptomConversationQuestion.Input) -> SymptomConversationQuestion {
        let canGoBack = conversation.mode == .text && service.canGoBack
        conversation.canGoPrevious = canGoBack
        return SymptomConversationQuestion(id: UUID(), text: text, guidance: turn?.asksMore == true ? Self.moreGuidance : nil,
                                           progress: turn?.progress, input: input, isLastQuestion: turn?.isLast ?? false,
                                           allowsPrevious: canGoBack)
    }

    private func goBack() {
        guard conversation.mode == .text, began, call == nil, typing == nil, !isOver, let back = service.back() else { return }
        conversation.errorMessage = nil
        show(back.turn, navigation: .previousButton)
        let restored = Self.answer(back.answer, for: conversation.question?.input ?? .text)
        conversation.restoredAnswer = restored
        if case .text(let text) = restored { conversation.answerText = text }
    }

    static func answer(_ text: String, for input: SymptomConversationQuestion.Input) -> SymptomConversationAnswer {
        switch input {
        case .frequency:
            if text == sentence(for: .frequency(.tenPlus)) { return .frequency(.tenPlus) }
            if let count = NumberParser.count(in: text), (0...10).contains(count) { return .frequency(.count(count)) }
        case .text:
            break
        }
        return .text(text)
    }

    static func sentence(for answer: SymptomConversationAnswer) -> String {
        switch answer {
        case .text(let text): text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .frequency(.count(let count)): "\(count)번"
        case .frequency(.tenPlus): "열 번 넘게"
        }
    }

    private static func isFinal(_ outcome: CareCallOutcome?) -> Bool {
        switch outcome {
        case .completed?, .emergencyEnded?: true
        case .interrupted?, nil: false
        }
    }

    func endCall() {
        analytics.updateScreen(.hidden)
        leftCall = true
        cancelAutoStart()
        if conversation.isEmergency {
            conversation.isEmergency = false
            save(showingResult: false)
        }
        if let call {
            call.cancel()
            Task { await service.stop() }
        } else if typing == nil {
            endText() // 문자 답을 처리 중이면 끝난 뒤에 (typing)
        }
    }

    private func endText() {
        guard began, !isOver else { return }
        began = false // 서비스가 대화를 닫는다 (두 번 끝내지 않게)
        finish(service.end())
    }

    private func pause() {
        // 통화를 걸기 전이면 자동 통화만 미뤄 두고, 계속 작성하면 건다
        if cancelAutoStart() {
            paused = true
            return
        }
        guard let call else { return }
        paused = true
        switchingMode = true
        call.cancel()
        Task { await service.stop() }
    }

    private func resume() {
        guard paused else { return }
        paused = false
        if call == nil, !isOver { start() }
    }

    private func discard() {
        paused = false
        if !hadEmergency {
            forget()
            isSaved = true // 끝낸 대화의 기록을 저장하지도 폰에 남기지도 않는다
        }
        endCall()
    }

    private func stopForEmergency() {
        conversation.isEmergency = false
        save(showingResult: false)
    }

    private func continueAfterEmergency() {
        guard case .emergencyEnded? = outcome, let turn = service.continueAfterEmergency() else { return }
        outcome = nil
        conversation.isEmergency = false
        show(turn)
        if conversation.mode == .voice { startCall() }
    }

    private func show(_ activity: CareCallActivity) {
        switch activity {
        case .speaking(let text):
            keep(service.progress) // 답을 분석한 뒤 다음 질문을 말한다
            let turn = service.current
            let navigation = takeVoiceAdvance()
            // 들어올 때 이미 보여 준 첫 문장이면 그대로 둔다 (화면과 캐릭터 영상을 다시 만들지 않게)
            let textChanged = conversation.question?.text != text
            if textChanged { conversation.question = question(text, of: turn, input: .text) }
            if textChanged || analyticsQuestion?.id != turn?.questionID {
                analyticsQuestion = turn?.questionID.map { .init(id: $0, navigation: navigation) }
            }
            // 마무리 인사를 하는 동안 정리 화면을 보여 준다
            if case .completed? = turn?.outcome { conversation.isSummarizing = true }
            conversation.transcript = ""
            conversation.voiceState = .aiSpeaking
            conversation.isWorking = false
        case .listening:
            conversation.voiceState = .patientSpeaking
        case .hearing(let text):
            conversation.transcript = text
        case .heard(let text):
            conversation.transcript = text
            conversation.voiceState = .thinking
            conversation.isWorking = true
        case .answerCompleted(let completion):
            analytics.answerCompleted(completion, mode: .voice)
            pendingVoiceAdvance = true
        }
    }

    private func finish(_ outcome: CareCallOutcome) {
        self.outcome = outcome
        conversation.voiceState = .thinking
        conversation.isWorking = false
        conversation.isSummarizing = false
        switch outcome {
        case .completed(let record) where record.symptoms.isEmpty:
            // 다시 거는 통화에서 달라진 게 없음: 더할 것이 없어 바로 완료 화면 (이때 보여 줄 화면은 화면 담당과 정할 예정)
            forget()
            isSaved = true
            self.record = todayRecord
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
        case .emergencyEnded(let record):
            self.record = record
            hadEmergency = true
            keep(record)
            if leftCall { save(showingResult: false) } else { conversation.isEmergency = true }
        }
    }

    private func finish(_ error: Error) {
        conversation.question = nil
        conversation.voiceState = .thinking
        conversation.isWorking = false
        conversation.errorMessage = "통화 중 문제가 생겼어요. 다시 시도해 주세요."
    }

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

    private func finishEdit(_ id: UUID, _ input: SymptomEntryEditInput, in summary: SymptomSummaryScreenState) {
        guard let record else { return }
        do {
            update(try record.editingEntry(id, with: input), in: summary)
            summary.editingEntryID = nil
            summary.editErrorMessage = nil
        } catch {
            summary.editErrorMessage = SymptomRecord.editErrorMessage(error)
        }
    }

    private func delete(_ id: UUID, in summary: SymptomSummaryScreenState) {
        guard let record else { return }
        update(record.removingEntry(id), in: summary)
        summary.editingEntryID = nil
    }

    private func update(_ updated: SymptomRecord, in summary: SymptomSummaryScreenState) {
        self.record = updated
        keep(updated)
        summary.record = SymptomRecordDisplay(record: updated)
    }

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
        let complete = Self.isFinal(outcome) || hadEmergency // 마친 통화·응급 종료는 그날 기록에 더한다
        let task = Task {
            do {
                let stored = try await store(record, complete: complete)
                forget() 
                isSaved = true
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

    private func today() async throws -> SymptomRecord? {
        await sendPending()
        return try await savedRecord(of: try loadedPatientId(), on: Date())
    }

    private func savedRecord(of patientId: UUID, on day: Date) async throws -> SymptomRecord? {
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return nil }
        return try await repository.findByPatientIdAndDate(patientId: patientId, from: start, to: end).first
    }

    private func keep(_ record: SymptomRecord?) {
        guard let record, !isSaved else { return }
        let complete = Self.isFinal(outcome) || hadEmergency
        try? pending.save(PendingCareCall(id: pendingId, record: record, complete: complete))
    }

    private func forget() {
        guard let patientId else { return }
        try? pending.delete(id: pendingId, patientId: patientId)
    }

    private func sendPending() async {
        guard let patientId else { return }
        for left in (try? pending.findAll(patientId: patientId)) ?? [] where left.id != pendingId {
            guard (try? await store(left.record, complete: left.complete)) != nil else { continue }
            try? pending.delete(id: left.id, patientId: patientId)
        }
    }

    private func store(_ record: SymptomRecord, complete: Bool) async throws -> Bool {
        guard let existing = try await savedRecord(of: record.patientId, on: record.recordedDate) else {
            try await repository.save(entity: record)
            return true
        }
        guard complete else { return false }
        try await repository.save(entity: Self.merge(existing, with: record))
        return true
    }

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
        let rank = Dictionary(uniqueKeysWithValues: SymptomType.allCases.enumerated().map { ($1, $0) })
        let sorted = symptoms.enumerated()
            .sorted { (rank[$0.element.symptomType] ?? 0, $0.offset) < (rank[$1.element.symptomType] ?? 0, $1.offset) }
            .map(\.element)
        return SymptomRecord(id: old.id, patientId: old.patientId, recordedDate: old.recordedDate, conditionText: old.conditionText,
                             symptoms: sorted)
    }

    private static func sameSpot(_ old: SymptomEntry, _ new: SymptomEntry) -> Bool {
        if new.bodyPart == nil, new.rawLocationText == nil { return true }
        if let part = new.bodyPart { return old.bodyPart == part }
        return old.rawLocationText == new.rawLocationText
    }

    private static let reviewMark = "[검토 필요]"
    private static let review = reviewMark + " "

    private static func text(of detail: String?) -> String? {
        guard let detail else { return nil }
        let text = detail.hasPrefix(reviewMark) ? detail.dropFirst(reviewMark.count).trimmingCharacters(in: .whitespaces) : detail
        return text.isEmpty ? nil : text
    }

    private static func filled(_ old: SymptomEntry, with new: SymptomEntry, note: String? = nil, label: String = "다시 통화",
                               textOnly: Bool = false) -> SymptomEntry {
        func cut(_ text: String, to room: Int) -> String { text.count <= room ? text : String(text.prefix(max(room - 1, 0))) + "…" }
        var oldText = text(of: old.detail)
        var added = (note ?? text(of: new.detail)).map { "\(label): " + $0 }
        var flagged = old.detail?.hasPrefix(reviewMark) == true || new.detail?.hasPrefix(reviewMark) == true
        if let o = oldText, let a = added, review.count + o.count + " / ".count + a.count > SymptomEntry.detailLimit {
            flagged = true
            let room = SymptomEntry.detailLimit - review.count - " / ".count
            let oldRoom = max(room / 2, room - a.count)
            oldText = cut(o, to: oldRoom)
            added = cut(a, to: room - min(o.count, oldRoom))
        }
        let body = [oldText, added].compactMap(\.self).joined(separator: " / ")
        let detail = body.isEmpty ? (flagged ? reviewMark : nil) : String(((flagged ? review : "") + body).prefix(SymptomEntry.detailLimit))
        let fill = textOnly ? nil : new
        let merged = try? SymptomEntry(id: old.id, symptomType: old.symptomType, presence: old.presence,
                                       bodyPart: old.bodyPart ?? fill?.bodyPart, bodySide: old.bodySide ?? fill?.bodySide,
                                       rawLocationText: old.rawLocationText ?? fill?.rawLocationText,
                                       durationMinutes: old.durationMinutes ?? fill?.durationMinutes,
                                       occurrenceCount: old.occurrenceCount ?? fill?.occurrenceCount, detail: detail)
        return merged ?? old
    }
}
