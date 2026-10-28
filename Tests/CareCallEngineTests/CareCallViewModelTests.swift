import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 케어콜 서비스를 흉내 내는 가짜. 단계마다 오류를 낼 수 있고, hold 단계에서 release()(통화는 stop())까지 붙잡는다
@MainActor
final class FakeCareCall: CareCalling {
    enum Step { case microphone, model, speech, call, answer }
    private(set) var calls: [Step] = []
    var errors: [Step: Error] = [:]
    var hold: Step?
    var isHolding: Bool { held != nil }
    /// 통화에서 차례로 알릴 진행 상황과 돌려줄 결과
    var activities: [CareCallActivity] = []
    var outcome: CareCallOutcome = .interrupted(nil)
    /// 통화가 끝났을 때 대화가 와 있는 질문 (없으면 그대로)
    var questionAfterCall: CareCallTurn?
    /// 문자 대화: 첫 질문, 답마다 차례로 돌려줄 다음 질문, 중간에 끝낼 때의 결과
    var opening = CareCallTurn(utterance: "오늘 컨디션은 어떠세요?", number: nil, outcome: nil)
    var replies: [CareCallTurn] = []
    var endOutcome: CareCallOutcome = .interrupted(nil)
    private(set) var current: CareCallTurn?
    /// 지금까지 받은 답으로 만든 기록 (답마다 폰에 남기는지 볼 때)
    var progress: SymptomRecord?
    private(set) var answers: [String] = []
    private(set) var beginCount = 0
    /// begin에 넘어온 환자
    private(set) var patientIds: [UUID] = []
    /// begin에 넘어온 오늘 기록 (다시 거는 통화면 있음)
    private(set) var previousRecords: [SymptomRecord?] = []
    private(set) var endCount = 0
    private(set) var stopCount = 0
    private var held: CheckedContinuation<Void, Never>?

    func requestMicrophone() async throws { try await run(.microphone) }
    func loadModel() async throws { try await run(.model) }
    func prepareSpeech() async throws { try await run(.speech) }

    func begin(patientId: UUID, previous: SymptomRecord?) throws -> CareCallTurn {
        beginCount += 1
        patientIds.append(patientId)
        previousRecords.append(previous)
        current = opening
        return opening
    }

    func run(onActivity: @escaping (CareCallActivity) -> Void) async throws -> CareCallOutcome {
        activities.forEach(onActivity)
        try await run(.call)
        if let questionAfterCall { current = questionAfterCall }
        return outcome
    }

    func answer(_ text: String) async throws -> CareCallTurn {
        answers.append(text)
        try await run(.answer)
        if !replies.isEmpty { current = replies.removeFirst() }
        return current!
    }

    func end() -> CareCallOutcome {
        endCount += 1
        current = nil
        return endOutcome
    }

    func stop() async {
        stopCount += 1
        release()
    }

    /// 이전 질문: 돌아갈 질문과 그때 한 답 (마지막 것부터 돌아간다)
    var backTurns: [(turn: CareCallTurn, answer: String)] = []
    var canGoBack: Bool { !backTurns.isEmpty }

    func back() -> (turn: CareCallTurn, answer: String)? {
        guard let last = backTurns.popLast() else { return nil }
        current = last.turn
        return last
    }

    /// 응급 뒤 기록을 이어 가면 다시 물을 질문
    var resumeTurn: CareCallTurn?

    func continueAfterEmergency() -> CareCallTurn? {
        if let resumeTurn { current = resumeTurn }
        return resumeTurn
    }

    func release() {
        held?.resume()
        held = nil
    }

    private func run(_ step: Step) async throws {
        calls.append(step)
        if hold == step {
            hold = nil
            await withCheckedContinuation { held = $0 }
        }
        if let error = errors.removeValue(forKey: step) { throw error }
    }
}

/// 증상 기록 저장소 가짜. 같은 날 기록 하나만 다룬다. failNextSave면 다음 저장이 실패한다
@MainActor
final class FakeSymptomRecords: SymptomRepository {
    struct Failure: Error {}
    var existing: SymptomRecord?
    private(set) var saved: [SymptomRecord] = []
    var failNextSave = false
    private(set) var queriedRanges: [ClosedRange<Date>] = []
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [SymptomRecord] {
        queriedRanges.append(startDate...endDate)
        return existing.map { [$0] } ?? []
    }
    func save(entity: SymptomRecord) async throws {
        if failNextSave {
            failNextSave = false
            throw Failure()
        }
        saved.append(entity)
    }
    func findByPatientId(_ patientId: UUID) async throws -> [SymptomRecord] { saved }
    func findById(_ id: UUID) async throws -> SymptomRecord? { nil }
    func deleteById(_ id: UUID) async throws {}
}

@MainActor
struct CareCallViewModelTests {
    let service = FakeCareCall()
    let repository = FakeSymptomRecords()
    let viewModel: CareCallViewModel
    var state: CareCallScreenState { viewModel.preparation }

    let patientId = UUID()

    init() {
        viewModel = CareCallViewModel(service: service, repository: repository, pending: FakePendingCareCalls(), patientId: patientId)
    }

    private func waitUntilHolding() async {
        for _ in 0..<1_000 where !service.isHolding { await Task.yield() }
        #expect(service.isHolding)
    }

    @Test func 마이크_모델_음성인식_순서로_준비하고_끝나면_시작할_수_있다() async {
        #expect(state.preparation == .idle && !state.canStart)
        let task = viewModel.prepare()
        #expect(state.preparation == .preparing(.permissions) && state.isPreparing)
        await task?.value
        #expect(service.calls == [.microphone, .model, .speech])
        #expect(state.preparation == .ready)
        #expect(state.canStart && !state.isPreparing)
    }

    @Test func 단계마다_진행_상태를_보여_준다() async {
        service.hold = .speech
        let task = viewModel.prepare()
        await waitUntilHolding()
        #expect(state.preparation == .preparing(.speechAssets))
        service.release()
        await task?.value
        #expect(state.preparation == .ready)
    }

    @Test(arguments: [
        (FakeCareCall.Step.microphone, AudioRecorderError.microphoneDenied as Error, CareCallPreparationState.microphoneDenied),
        (.model, LanguageModelError.modelMissing, .modelMissing),
        (.model, LanguageModelError.modelNotReady, .modelLoadFailed),
        (.speech, SpeechRecognizerError.koreanUnsupported, .speechRecognitionUnsupported),
        (.speech, SpeechRecognizerError.noAudioFormat, .failed),
    ])
    func 오류는_화면_상태로_바꾼다(step: FakeCareCall.Step, error: Error, expected: CareCallPreparationState) async {
        service.errors[step] = error
        await viewModel.prepare()?.value
        #expect(state.preparation == expected)
        #expect(!state.canStart && !state.isPreparing)
    }

    @Test func 실패하면_다시_준비할_수_있다() async {
        service.errors[.model] = LanguageModelError.modelNotReady
        await viewModel.prepare()?.value
        #expect(state.preparation == .modelLoadFailed)
        await viewModel.prepare()?.value
        #expect(state.preparation == .ready)
        #expect(service.calls == [.microphone, .model, .microphone, .model, .speech])
    }

    @Test func 준비_중이거나_끝났으면_다시_불러도_한_번만_준비한다() async {
        service.hold = .model
        let task = viewModel.prepare()
        await waitUntilHolding()
        #expect(viewModel.prepare() == nil) // 앱으로 돌아와 다시 불림
        service.release()
        await task?.value
        #expect(viewModel.prepare() == nil) // 이미 준비됨
        #expect(service.calls == [.microphone, .model, .speech])
    }

    @Test func 준비_중에_화면을_떠나면_멈추고_처음_상태로() async {
        service.hold = .model
        let task = viewModel.prepare()
        await waitUntilHolding()
        state.onAction?(.cancel)
        #expect(state.preparation == .idle && !state.isPreparing)
        service.release()
        await task?.value
        #expect(state.preparation == .idle) // 늦게 끝난 이전 준비가 덮어쓰지 않음
        #expect(service.calls == [.microphone, .model])

        state.onAction?(.prepare) // 다시 들어오면 처음부터
        for _ in 0..<1_000 where state.preparation != .ready { await Task.yield() }
        #expect(state.preparation == .ready)
    }

    @Test func 떠났다_바로_돌아와도_이전_준비가_끝난_뒤에_서비스를_부른다() async {
        service.hold = .model // 모델을 불러오는 중에 떠남
        let first = viewModel.prepare()
        await waitUntilHolding()
        viewModel.cancelPreparation()
        let second = viewModel.prepare()
        #expect(state.preparation == .preparing(.permissions))
        for _ in 0..<100 { await Task.yield() }
        #expect(service.calls == [.microphone, .model]) // 이전 모델 불러오기가 끝나기 전엔 다시 부르지 않음
        service.release()
        await first?.value
        await second?.value
        #expect(service.calls == [.microphone, .model, .microphone, .model, .speech])
        #expect(state.preparation == .ready)
    }

    @Test func 준비가_끝난_뒤_떠나도_그대로() async {
        await viewModel.prepare()?.value
        state.onAction?(.cancel) // 전화를 받아 통화 화면으로 넘어갈 때도 불린다
        #expect(state.preparation == .ready && state.canStart)
    }

    // MARK: - 통화

    private var conversation: SymptomScreenState { viewModel.conversation }

    private func entry(_ type: SymptomType, _ presence: SymptomPresence, _ detail: String? = nil, part: BodyPart? = nil) -> SymptomEntry {
        try! SymptomEntry(id: UUID(), symptomType: type, presence: presence, bodyPart: part, bodySide: nil,
                          durationMinutes: nil, occurrenceCount: nil, detail: detail)
    }

    private func record(_ entries: [SymptomEntry]) -> SymptomRecord {
        SymptomRecord(id: UUID(), patientId: patientId, recordedDate: Date(timeIntervalSince1970: 1_000),
                      conditionText: "그럭저럭이요", symptoms: entries)
    }

    /// 준비를 마치고 음성 대화 화면에 들어간 상태
    private func enterVoiceCall() async {
        await viewModel.prepare()?.value
        conversation.onAction?(.switchMode(.voice))
    }

    @Test func 통화_진행을_대화_화면에_옮긴다() async {
        await enterVoiceCall()
        service.activities = [.speaking("오늘 컨디션은 어떠세요?"), .listening, .heard("그럭저럭이요")]
        service.hold = .call
        let task = viewModel.startCall()
        for _ in 0..<1_000 where !service.isHolding { await Task.yield() }
        #expect(conversation.question?.text == "오늘 컨디션은 어떠세요?")
        #expect(conversation.transcript == "그럭저럭이요")
        #expect(conversation.isWorking && !conversation.isListening) // 분석 중
        service.release()
        await task?.value
    }

    @Test func 듣는_동안_들은_말을_바로_보여_준다() async {
        await enterVoiceCall()
        service.activities = [.speaking("오늘 컨디션은 어떠세요?"), .listening, .hearing("그럭"), .hearing("그럭저럭이요")]
        service.hold = .call
        let task = viewModel.startCall()
        for _ in 0..<1_000 where !service.isHolding { await Task.yield() }
        #expect(conversation.transcript == "그럭저럭이요")
        #expect(conversation.isListening && !conversation.isWorking) // 아직 듣는 중
        service.release()
        await task?.value
    }

    @Test func 끝까지_마치면_요약으로_넘어가고_없음_모름은_결과에만_남긴다() async {
        await enterVoiceCall()
        let saved = record([entry(.nauseaVomiting, .present, "구토 횟수: 하루 세 번이요"), entry(.constipation, .absent),
                            entry(.diarrhea, .unknown, "[검토 필요]")])
        service.outcome = .completed(saved)
        await viewModel.startCall()?.value
        let summary = conversation.summary?.record
        #expect(summary?.id == saved.id)
        #expect(summary?.symptoms.map(\.presence) == [.present, .absent, .unknown]) // 화면에 전부 넘기고
        #expect(summary?.presentSymptoms.map(\.symptomType) == [.nauseaVomiting]) // 화면은 '있음'만 보여 준다
        #expect(summary?.presentSymptoms.first?.detail == "구토 횟수: 하루 세 번이요")
        guard case .completed(let kept)? = viewModel.outcome else { Issue.record("결과 없음"); return }
        #expect(kept.symptoms.count == 3)
        #expect(viewModel.startCall() == nil) // 요약까지 갔으면 다시 걸지 않음
    }

    @Test func 화면을_떠나면_통화를_끊고_끊긴_곳까지_남긴다() async {
        await enterVoiceCall()
        let partial = record([entry(.nauseaVomiting, .present)])
        service.outcome = .interrupted(partial)
        service.hold = .call
        let task = viewModel.startCall()
        for _ in 0..<1_000 where !service.isHolding { await Task.yield() }
        conversation.onAction?(.cancel)
        await task?.value
        #expect(service.stopCount == 1)
        guard case .interrupted(let kept?)? = viewModel.outcome else { Issue.record("끊긴 기록 없음"); return }
        #expect(kept.id == partial.id)
        #expect(conversation.summary != nil)
    }

    @Test func 들어가자마자_떠나면_통화를_걸지_않는다() async {
        await enterVoiceCall()
        let task = viewModel.startCall()
        conversation.onAction?(.cancel) // 통화가 시작되기 전에 화면을 떠남
        await task?.value
        #expect(!service.calls.contains(.call))
        #expect(!conversation.isWorking && conversation.errorMessage == nil)
    }

    @Test func 답이_없이_끊기면_다시_시도할_수_있고_음성_인식부터_다시_준비한다() async {
        await enterVoiceCall()
        service.outcome = .interrupted(nil)
        await viewModel.startCall()?.value
        #expect(conversation.question == nil)
        #expect(conversation.errorMessage == "통화가 끊겼어요. 다시 시도해 주세요.")

        service.outcome = .completed(record([entry(.diarrhea, .present)]))
        conversation.onAction?(.start) // "다시 시도"
        for _ in 0..<1_000 where conversation.summary == nil { await Task.yield() }
        #expect(service.calls == [.microphone, .model, .speech, .call, .speech, .call])
        #expect(conversation.summary != nil && conversation.errorMessage == nil)
    }

    @Test func 통화_중_오류면_알리고_다시_시도할_수_있다() async {
        await enterVoiceCall()
        service.errors[.call] = SpeechRecognizerError.noAudioFormat
        await viewModel.startCall()?.value
        #expect(conversation.question == nil && !conversation.isWorking)
        #expect(conversation.errorMessage == "통화 중 문제가 생겼어요. 다시 시도해 주세요.")
    }

    @Test func 준비가_안_됐으면_준비부터_하고_실패하면_통화하지_않는다() async {
        conversation.onAction?(.switchMode(.voice))
        service.errors[.microphone] = AudioRecorderError.microphoneDenied
        await viewModel.startCall()?.value
        #expect(service.calls == [.microphone])
        #expect(conversation.errorMessage == "통화 준비가 끝나지 않았어요. 다시 시도해 주세요.")
        #expect(!conversation.isWorking && service.beginCount == 0)
    }

    @Test func 응급으로_끝나면_마지막_안내를_그대로_둔다() async {
        await enterVoiceCall()
        service.activities = [.speaking("응급 안내 문구")]
        service.outcome = .emergencyEnded(record([]))
        await viewModel.startCall()?.value
        #expect(conversation.question?.text == "응급 안내 문구")
        #expect(conversation.summary == nil && conversation.errorMessage == nil)
    }

    @Test func 음성으로_들어오면_첫_질문만_보여_주고_대화_시작하기를_기다린다() async {
        await enterVoiceCall()
        await viewModel.open()?.value
        #expect(conversation.question?.text == "오늘 컨디션은 어떠세요?")
        #expect(service.beginCount == 1 && !service.calls.contains(.call))
        #expect(!conversation.isCalling && !conversation.isWorking)
        service.hold = .call
        conversation.onAction?(.start) // 대화 시작하기
        await waitUntilHolding()
        #expect(conversation.isCalling && service.beginCount == 1) // 같은 대화를 통화로
        service.release()
        for _ in 0..<1_000 where conversation.isCalling { await Task.yield() }
        #expect(!conversation.isCalling)
    }

    @Test func 통화_중_마무리_인사를_하는_동안_정리_화면을_보여_준다() async {
        await enterVoiceCall()
        service.questionAfterCall = nil
        service.opening = CareCallTurn(utterance: "오늘 기록을 마쳤어요.", number: nil, outcome: .completed(record([])))
        service.activities = [.speaking("오늘 기록을 마쳤어요.")]
        service.hold = .call
        let task = viewModel.startCall()
        await waitUntilHolding()
        #expect(conversation.isSummarizing)
        service.release()
        await task?.value
        #expect(!conversation.isSummarizing)
    }

    @Test func 기록_중단_팝업을_띄우면_통화를_멈추고_계속하면_다시_건다() async {
        await enterVoiceCall()
        await viewModel.open()?.value
        service.hold = .call
        service.outcome = .interrupted(record([entry(.diarrhea, .present)]))
        conversation.onAction?(.start)
        await waitUntilHolding()
        conversation.onAction?(.pause)
        for _ in 0..<1_000 where conversation.isCalling { await Task.yield() }
        #expect(service.stopCount == 1)
        #expect(conversation.summary == nil && conversation.question != nil) // 멈춘 통화를 요약으로 넘기지 않는다
        service.outcome = .completed(record([entry(.diarrhea, .present)]))
        conversation.onAction?(.resume) // 계속 작성하기
        for _ in 0..<1_000 where conversation.summary == nil { await Task.yield() }
        #expect(service.calls.filter { $0 == .call }.count == 2)
        #expect(service.beginCount == 1)
    }

    @Test func 통화_중에_그만하면_받은_답을_저장하지_않는다() async {
        await enterVoiceCall()
        await viewModel.open()?.value
        service.hold = .call
        service.outcome = .interrupted(record([entry(.diarrhea, .present)]))
        conversation.onAction?(.start)
        await waitUntilHolding()
        conversation.onAction?(.pause)
        conversation.onAction?(.discard) // 그만하기
        conversation.onAction?(.cancel) // 화면을 떠남
        for _ in 0..<1_000 where conversation.isCalling { await Task.yield() }
        for _ in 0..<200 { await Task.yield() }
        #expect(repository.saved.isEmpty)
    }

    @Test func 통화_중_응급_뒤_이어_가면_다시_건다() async {
        await enterVoiceCall()
        service.outcome = .emergencyEnded(record([]))
        await viewModel.startCall()?.value
        #expect(conversation.isEmergency && repository.saved.isEmpty)
        service.resumeTurn = CareCallTurn(utterance: "변비는 있으셨나요?", number: nil, outcome: nil)
        service.outcome = .completed(record([entry(.diarrhea, .present)]))
        conversation.onAction?(.continueAfterEmergency)
        #expect(!conversation.isEmergency)
        for _ in 0..<1_000 where conversation.summary == nil { await Task.yield() }
        #expect(service.calls.filter { $0 == .call }.count == 2)
        #expect(repository.saved.isEmpty) // 요약에서 저장한다
    }

    // MARK: - 요약 수정·저장

    /// 통화를 끝까지 마치고 요약 화면에 온 상태
    private func reachSummary(_ entries: [SymptomEntry]) async -> SymptomSummaryScreenState {
        await enterVoiceCall()
        service.outcome = .completed(record(entries))
        await viewModel.startCall()?.value
        return conversation.summary!
    }

    private func input(_ entry: SymptomEntryDisplay, occurrence: String = "", duration: String = "", detail: String? = nil) -> SymptomEntryEditInput {
        var input = SymptomEntryEditInput(entry)
        input.occurrenceText = occurrence
        input.durationText = duration
        if let detail { input.detail = detail }
        return input
    }

    @Test func 요약에서_횟수를_고치면_반영하고_잘못된_값은_이유를_알린다() async {
        let summary = await reachSummary([entry(.diarrhea, .present, "많이요")])
        let shown = summary.record.symptoms[0]
        summary.onAction?(.edit(shown.id))
        #expect(summary.editingEntryID == shown.id)
        summary.onAction?(.finishEdit(shown.id, input(shown, occurrence: "0")))
        #expect(summary.editErrorMessage == "횟수는 1에서 100 사이 숫자로 입력해 주세요.")
        #expect(summary.editingEntryID == shown.id) // 고치는 중으로 둔다
        summary.onAction?(.finishEdit(shown.id, input(shown, occurrence: " 3 ", detail: "하루 세 번이요")))
        #expect(summary.editingEntryID == nil && summary.editErrorMessage == nil)
        #expect(summary.record.symptoms[0].occurrenceCount == 3 && summary.record.symptoms[0].detail == "하루 세 번이요")
        #expect(viewModel.record?.symptoms[0].occurrenceCount == 3)
    }

    @Test func 지우면_없음과_검토_필요로_바꾸고_다른_부위가_남으면_그_항목만_뺀다() async {
        let summary = await reachSummary([entry(.nauseaVomiting, .present, "[검토 필요] 구토 횟수: 두 번"),
                                          entry(.numbness, .present, part: .armHand), entry(.numbness, .present, part: .legFoot)])
        summary.onAction?(.delete(summary.record.symptoms[0].id))
        summary.onAction?(.delete(summary.record.symptoms.first { $0.bodyPart == .armHand }!.id))
        #expect(summary.record.presentSymptoms.map(\.symptomType) == [.numbness]) // 요약에는 '있음'만
        let saved = viewModel.record!.symptoms
        #expect(saved.map(\.presence) == [.absent, .present])
        #expect(saved[0].detail == "[검토 필요] 환자가 지움: 구토 횟수: 두 번")
        #expect(saved[1].bodyPart == .legFoot)
    }

    @Test func 요약에서_고쳐도_환자와_컨디션은_그대로_저장한다() async {
        let summary = await reachSummary([entry(.diarrhea, .present, "많이요"), entry(.constipation, .present)])
        summary.onAction?(.delete(summary.record.symptoms[1].id))
        summary.onAction?(.save)
        for _ in 0..<1_000 where !conversation.didSave { await Task.yield() }
        #expect(service.patientIds == [patientId])
        #expect(repository.saved.first?.patientId == patientId)
        #expect(repository.saved.first?.conditionText == "그럭저럭이요")
    }

    @Test func 저장하면_없음_모름까지_저장하고_완료_화면으로() async {
        let summary = await reachSummary([entry(.diarrhea, .present), entry(.constipation, .absent), entry(.oralPain, .unknown)])
        #expect(summary.canSave)
        summary.onAction?(.save)
        #expect(summary.isSaving && !summary.canSave)
        await viewModel.save(showingResult: true)?.value // 이미 저장 중이면 nil
        for _ in 0..<1_000 where !conversation.didSave { await Task.yield() }
        #expect(conversation.didSave && !summary.isSaving)
        #expect(repository.saved.count == 1 && repository.saved[0].symptoms.count == 3)
        summary.onAction?(.cancel) // 완료 화면으로 바뀌며 떠나도 다시 저장하지 않음
        for _ in 0..<100 { await Task.yield() }
        #expect(repository.saved.count == 1)
    }

    @Test func 저장에_실패하면_알리고_다시_저장할_수_있다() async {
        let summary = await reachSummary([entry(.diarrhea, .present)])
        repository.failNextSave = true
        await viewModel.save(showingResult: true)?.value
        #expect(summary.errorMessage == "저장하지 못했어요. 다시 저장해 주세요.")
        #expect(summary.canSave && !conversation.didSave)
        await viewModel.save(showingResult: true)?.value
        #expect(conversation.didSave && repository.saved.count == 1)
    }

    @Test func 저장하지_않고_요약을_떠나면_자동으로_저장한다() async {
        let summary = await reachSummary([entry(.diarrhea, .present)])
        summary.onAction?(.cancel)
        for _ in 0..<1_000 where repository.saved.isEmpty { await Task.yield() }
        #expect(repository.saved.count == 1)
        #expect(!conversation.didSave) // 떠난 화면에는 아무것도 보여 주지 않음
    }

    @Test func 통화_중에_떠나면_끊긴_곳까지_바로_저장한다() async {
        await enterVoiceCall()
        service.outcome = .interrupted(record([entry(.nauseaVomiting, .present)]))
        service.hold = .call
        let task = viewModel.startCall()
        for _ in 0..<1_000 where !service.isHolding { await Task.yield() }
        conversation.onAction?(.cancel)
        await task?.value
        for _ in 0..<1_000 where repository.saved.isEmpty { await Task.yield() }
        #expect(repository.saved.first?.symptoms.map(\.symptomType) == [.nauseaVomiting])
    }

    @Test func 오늘_기록이_있으면_다시_거는_통화로_시작하고_마치면_그_기록에_더한다() async {
        let old = record([entry(.nauseaVomiting, .present, "아침"), entry(.diarrhea, .absent)])
        repository.existing = old
        let summary = await reachSummary([entry(.diarrhea, .present, "저녁")])
        #expect(service.previousRecords.first??.id == old.id) // 오늘 기록을 넘겨 다시 거는 통화로 시작
        summary.onAction?(.save)
        for _ in 0..<1_000 where !conversation.didSave { await Task.yield() }
        let saved = repository.saved.first
        #expect(saved?.id == old.id) // 그날 기록 하나에 더한다
        #expect(saved?.symptoms.map(\.detail) == ["아침", "저녁"]) // 전에 답한 구토는 그대로, 없음이던 설사는 있음으로
        #expect(saved?.symptoms.map(\.presence) == [.present, .present])
    }

    @Test func 오늘_기록이_없으면_처음_통화로_시작한다() async {
        await enterVoiceCall()
        await viewModel.startCall()?.value
        #expect(service.previousRecords.count == 1 && service.previousRecords.first! == nil)
        // 오늘 기록은 오늘 0시부터 다음 날 0시까지(끝 날짜 제외)로 찾는다
        let today = Calendar.current.startOfDay(for: Date())
        #expect(repository.queriedRanges.first == today...Calendar.current.date(byAdding: .day, value: 1, to: today)!)
    }

    @Test func 다시_거는_통화에서_달라진_게_없으면_바로_완료_화면으로() async {
        repository.existing = record([entry(.diarrhea, .present)])
        await enterVoiceCall()
        service.outcome = .completed(record([]))
        await viewModel.startCall()?.value
        #expect(conversation.didSave && conversation.summary == nil)
        #expect(repository.saved.isEmpty) // 더할 것이 없다
        #expect(viewModel.startCall() == nil)
    }

    @Test func 같은_날_기록이_있으면_끊긴_통화는_저장하지_않고_알린다() async {
        repository.existing = record([entry(.nauseaVomiting, .present, "아침")])
        await enterVoiceCall()
        service.outcome = .interrupted(record([entry(.diarrhea, .present)]))
        await viewModel.startCall()?.value
        let summary = conversation.summary!
        summary.onAction?(.save)
        for _ in 0..<1_000 where summary.errorMessage == nil { await Task.yield() }
        #expect(repository.saved.isEmpty && !conversation.didSave)
        #expect(summary.errorMessage == "오늘 기록이 이미 있어서, 중간에 끊긴 이번 답은 저장하지 않았어요.")
        #expect(!summary.canSave)
        summary.onAction?(.cancel) // 떠나도 다시 저장하지 않는다
        for _ in 0..<100 { await Task.yield() }
        #expect(repository.saved.isEmpty)
    }

    @Test func 그날_기록이_없으면_끊긴_통화도_저장한다() async {
        await enterVoiceCall()
        service.outcome = .interrupted(record([entry(.diarrhea, .present)]))
        await viewModel.startCall()?.value
        conversation.summary?.onAction?(.save)
        for _ in 0..<1_000 where !conversation.didSave { await Task.yield() }
        #expect(repository.saved.count == 1)
    }
}

/// 로그인 저장소 가짜. 로그인 확인(getCurrentUserId)만 쓴다
final class FakeAuth: AuthRepository {
    struct Failure: Error {}
    var userId: UUID?
    var signedIn = true
    func getCurrentUserId() async throws -> UUID {
        guard let userId else { throw Failure() }
        return userId
    }
    func getCurrentUserEmail() async throws -> String? { nil }
    func isSignedIn() -> Bool { signedIn }
    func signUp(email: String, password: String) async throws -> UUID { throw Failure() }
    func resendSignUpConfirmationEmail(to email: String, redirectTo url: URL?) async throws {}
    func signIn(email: String, password: String) async throws -> UUID { throw Failure() }
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID { throw Failure() }
    func signOut() async throws {}
    func requestPasswordChangeVerification() async throws {}
    func sendPasswordResetEmail(to email: String, redirectTo url: URL?) async throws {}
    func updatePassword(to newPassword: String, nonce: String?) async throws {}
}

/// 환자 저장소 가짜. findById만 쓴다
final class FakePatients: PatientRepository {
    var patient: Patient?
    func findById(_ id: UUID) async throws -> Patient? { patient?.user.id == id ? patient : nil }
    func save(patient: Patient) async throws {}
    func findByName(_ name: String) async throws -> [Patient] { [] }
    func findByDoctorId(_ doctorId: UUID) async throws -> [Patient] { [] }
    func connectToDoctor(code: String) async throws {}
    func disconnectFromDoctor() async throws {}
}

/// 화면에 들어오면 ViewModel이 로그인 환자를 찾는다 (PainRecordViewModel과 같은 방식)
@MainActor
struct CareCallPatientTests {
    let service = FakeCareCall()
    let auth = FakeAuth()
    let patients = FakePatients()
    let viewModel: CareCallViewModel

    init() {
        viewModel = CareCallViewModel(service: service, repository: FakeSymptomRecords(), pending: FakePendingCareCalls(),
                                      authRepository: auth, patientRepository: patients)
    }

    private func patient(_ id: UUID) throws -> Patient {
        Patient(user: try User(id: id, name: "홍길동", birthday: Date(timeIntervalSince1970: 0), sex: .male), doctorId: nil, disease: nil)
    }

    @Test func 환자를_찾으면_준비되고_그_환자로_통화한다() async throws {
        let id = UUID()
        auth.userId = id
        patients.patient = try patient(id)
        #expect(viewModel.connectionState == .loading)
        await viewModel.loadPatient()
        #expect(viewModel.connectionState == .ready)
        await viewModel.startText()?.value
        #expect(service.patientIds == [id])
    }

    @Test func 환자_계정이_없으면_알린다() async {
        auth.userId = UUID()
        await viewModel.loadPatient()
        #expect(viewModel.connectionState == .patientUnavailable)
    }

    @Test(arguments: [(true, CareCallViewModel.ConnectionState.failed), (false, .signedOut)])
    func 조회에_실패하면_로그인_여부로_가린다(signedIn: Bool, expected: CareCallViewModel.ConnectionState) async {
        auth.signedIn = signedIn
        await viewModel.loadPatient()
        #expect(viewModel.connectionState == expected)
    }

    @Test func 환자를_찾기_전에는_통화를_시작하지_않는다() async {
        await viewModel.startText()?.value
        #expect(service.patientIds.isEmpty)
    }
}
