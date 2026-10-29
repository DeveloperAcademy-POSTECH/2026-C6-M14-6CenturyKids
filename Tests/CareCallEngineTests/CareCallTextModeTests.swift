import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 문자 대화: 질문 하나에 입력 칸 하나. 음성 통화와 같은 서비스 대화를 이어 간다. 가상 발화만
@MainActor
struct CareCallTextModeTests {
    let service = FakeCareCall()
    let repository = FakeSymptomRecords()
    let viewModel: CareCallViewModel
    var conversation: SymptomScreenState { viewModel.conversation }

    init() {
        viewModel = CareCallViewModel(service: service, repository: repository, pending: FakePendingCareCalls(), patientId: UUID())
    }

    private func turn(_ text: String, _ number: CareCallConfig.Effect.Detail.Number? = nil,
                      _ outcome: CareCallOutcome? = nil) -> CareCallTurn {
        CareCallTurn(utterance: text, number: number, outcome: outcome)
    }

    private func record() -> SymptomRecord {
        let entry = try! SymptomEntry(id: UUID(), symptomType: .diarrhea, presence: .present, bodyPart: nil, bodySide: nil,
                                      durationMinutes: nil, occurrenceCount: nil, detail: nil)
        return SymptomRecord(id: UUID(), patientId: UUID(), recordedDate: Date(timeIntervalSince1970: 1_000), conditionText: nil, symptoms: [entry])
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() { await Task.yield() }
        #expect(condition())
    }

    /// 문자로 대화 화면에 들어와 첫 질문을 받은 상태
    private func enterText() async {
        conversation.onAction?(.switchMode(.text))
        await viewModel.start()?.value
    }

    @Test func 문자로_시작하면_모델만_불러와_첫_질문을_글자_입력으로_보여_준다() async {
        await enterText()
        #expect(service.calls == [.model]) // 마이크·음성 인식은 준비하지 않는다
        #expect(conversation.question?.text == "오늘 컨디션은 어떠세요?")
        #expect(conversation.question?.input == .text)
        #expect(!conversation.isWorking && conversation.errorMessage == nil)
    }

    @Test func 대기_화면에서_모델을_불러오는_중이면_끝난_뒤_이어서_한다() async {
        service.hold = .model
        let preparing = viewModel.prepare()
        for _ in 0..<1_000 where !service.isHolding { await Task.yield() }
        viewModel.cancelPreparation() // 문자로 바꾸며 대기 화면을 떠남
        conversation.onAction?(.switchMode(.text))
        let task = viewModel.start()
        for _ in 0..<100 { await Task.yield() }
        #expect(service.calls == [.microphone, .model]) // 앞의 모델 불러오기가 끝나기 전엔 다시 부르지 않음
        service.release()
        await preparing?.value
        await task?.value
        #expect(service.calls == [.microphone, .model, .model])
        #expect(conversation.question?.text == "오늘 컨디션은 어떠세요?")
    }

    @Test func 횟수_지속_시간_질문이면_입력_칸을_바꾸고_답을_문장으로_넘긴다() async {
        await enterText()
        service.replies = [turn("구토는 하루에 몇 번 정도 하셨나요?", .count), turn("한 번 그러면 얼마나 가나요?", .minutes),
                           turn("변비는 있으셨나요?")]
        await viewModel.answer(.text("  어제 좀 토했어요 "))?.value
        #expect(conversation.question?.input == .frequency)
        await viewModel.answer(.frequency(.tenPlus))?.value
        #expect(conversation.question?.input == .duration)
        await viewModel.answer(.durationMinutes(90))?.value
        #expect(conversation.question?.input == .text && conversation.question?.text == "변비는 있으셨나요?")
        #expect(service.answers == ["어제 좀 토했어요", "열 번 넘게", "1시간 30분"])
    }

    @Test(arguments: [
        (SymptomConversationAnswer.frequency(.count(3)), "3번"), (.durationMinutes(30), "30분"), (.durationMinutes(120), "2시간"),
        (.durationMinutes(1440), "24시간"),
    ])
    func 숫자_입력은_엔진이_읽는_문장으로(answer: SymptomConversationAnswer, sentence: String) {
        #expect(CareCallViewModel.sentence(for: answer) == sentence)
    }

    @Test func 숫자_문장은_엔진이_같은_값으로_읽고_10회_이상은_정확한_값으로_남기지_않는다() {
        #expect(NumberParser.count(in: CareCallViewModel.sentence(for: .frequency(.count(7)))) == 7)
        #expect(NumberParser.count(in: CareCallViewModel.sentence(for: .frequency(.tenPlus))) == nil)
        #expect(NumberParser.minutes(in: CareCallViewModel.sentence(for: .durationMinutes(90))) == 90)
        #expect(NumberParser.minutes(in: CareCallViewModel.sentence(for: .durationMinutes(180))) == 180)
    }

    @Test func 빈_답이나_처리_중에는_보내지_않는다() async {
        await enterText()
        #expect(viewModel.answer(.text("   ")) == nil)
        service.hold = .answer
        let task = viewModel.answer(.text("괜찮아요"))
        #expect(conversation.isWorking)
        #expect(viewModel.answer(.text("또 보냄")) == nil)
        await waitUntil { service.isHolding }
        service.release()
        await task?.value
        #expect(service.answers == ["괜찮아요"])
    }

    @Test func 끝까지_답하면_요약으로_넘어간다() async {
        await enterText()
        let saved = record()
        service.replies = [turn("오늘 기록을 마쳤어요.", nil, .completed(saved))]
        await viewModel.answer(.text("없어요"))?.value
        #expect(conversation.summary?.record.id == saved.id)
        #expect(viewModel.answer(.text("더 말함")) == nil)
    }

    @Test func 응급이면_안내를_남기고_팝업으로_묻고_기록_중단하면_저장한다() async {
        await enterText()
        let saved = record()
        service.replies = [turn("응급 안내 문구", nil, .emergencyEnded(saved))]
        await viewModel.answer(.text("숨이 차요"))?.value
        #expect(conversation.question?.text == "응급 안내 문구" && conversation.summary == nil)
        #expect(conversation.isEmergency)
        #expect(viewModel.answer(.text("네")) == nil)
        for _ in 0..<100 { await Task.yield() }
        #expect(repository.saved.isEmpty) // 고르기 전에는 저장하지 않는다 (폰에는 남긴다)
        conversation.onAction?(.stopForEmergency)
        #expect(!conversation.isEmergency)
        await waitUntil { repository.saved.count == 1 }
        #expect(repository.saved.first?.id == saved.id)
    }

    @Test func 응급_뒤_기록을_이어_가면_응급_전_질문부터_다시_묻고_끝나면_더해_저장한다() async {
        await enterText()
        let emergency = record()
        service.replies = [turn("응급 안내 문구", nil, .emergencyEnded(emergency))]
        await viewModel.answer(.text("숨이 차요"))?.value
        service.resumeTurn = turn("변비는 있으셨나요?")
        conversation.onAction?(.continueAfterEmergency)
        #expect(!conversation.isEmergency && viewModel.outcome == nil)
        #expect(conversation.question?.text == "변비는 있으셨나요?")
        let finished = record()
        service.replies = [turn("오늘 기록을 마쳤어요.", nil, .completed(finished))]
        await viewModel.answer(.text("없어요"))?.value
        #expect(service.answers.last == "없어요")
        #expect(conversation.summary?.record.id == finished.id)
    }

    @Test func 응급_뒤_이어_가다_그만해도_응급으로_남긴_말은_저장한다() async {
        await enterText()
        service.replies = [turn("응급 안내 문구", nil, .emergencyEnded(record()))]
        await viewModel.answer(.text("숨이 차요"))?.value
        service.resumeTurn = turn("변비는 있으셨나요?")
        conversation.onAction?(.continueAfterEmergency)
        service.endOutcome = .interrupted(record())
        conversation.onAction?(.discard)
        await waitUntil { repository.saved.count == 1 }
    }

    @Test func 응급_팝업에서_고르지_않고_떠나도_저장한다() async {
        await enterText()
        service.replies = [turn("응급 안내 문구", nil, .emergencyEnded(record()))]
        await viewModel.answer(.text("숨이 차요"))?.value
        conversation.onAction?(.cancel)
        await waitUntil { repository.saved.count == 1 }
    }

    @Test func 문자_대화_중에_떠나면_받은_답까지_저장한다() async {
        await enterText()
        service.endOutcome = .interrupted(record())
        conversation.onAction?(.cancel)
        await waitUntil { repository.saved.count == 1 }
        #expect(service.endCount == 1)
    }

    @Test func 답을_처리하는_중에_떠나면_끝난_뒤_저장한다() async {
        await enterText()
        service.endOutcome = .interrupted(record())
        service.hold = .answer
        let task = viewModel.answer(.text("설사를 했어요"))
        conversation.onAction?(.cancel)
        #expect(service.endCount == 0)
        await waitUntil { service.isHolding }
        service.release()
        await task?.value
        await waitUntil { repository.saved.count == 1 }
        #expect(service.endCount == 1)
    }

    @Test func 통화_중에_문자로_바꾸면_같은_대화의_지금_질문을_문자로_보여_준다() async {
        await viewModel.prepare()?.value
        conversation.onAction?(.switchMode(.voice))
        service.hold = .call
        service.questionAfterCall = turn("구토는 하루에 몇 번 정도 하셨나요?", .count)
        let call = viewModel.start()
        for _ in 0..<1_000 where !service.isHolding { await Task.yield() }
        conversation.onAction?(.switchMode(.text)) // 통화를 끊는다 (stop이 붙잡은 통화를 놓아 준다)
        await call?.value
        #expect(service.stopCount == 1)
        #expect(conversation.question?.text == "구토는 하루에 몇 번 정도 하셨나요?" && conversation.question?.input == .frequency)
        #expect(conversation.summary == nil && conversation.errorMessage == nil)
        #expect(service.beginCount == 1)
    }

    @Test func 통화를_걸기_전에_문자로_바꾸면_통화하지_않고_문자로_시작한다() async {
        await viewModel.prepare()?.value
        conversation.onAction?(.switchMode(.voice))
        let call = viewModel.start()
        conversation.onAction?(.switchMode(.text)) // 첫 질문 전에 바꿈
        await call?.value
        await waitUntil { conversation.question != nil }
        #expect(!service.calls.contains(.call))
        #expect(conversation.question?.text == "오늘 컨디션은 어떠세요?" && service.beginCount == 1)
    }

    @Test func 문자에서_음성으로_바꾸면_준비부터_하고_같은_대화를_통화로_이어_간다() async {
        await enterText()
        service.outcome = .completed(record())
        conversation.onAction?(.switchMode(.voice))
        await waitUntil { conversation.summary != nil }
        #expect(service.calls == [.model, .microphone, .model, .speech, .call])
        #expect(service.beginCount == 1) // 새 대화를 시작하지 않는다
    }

    @Test func 답을_처리하는_중에_음성으로_바꾸면_끝난_뒤_통화한다() async {
        await viewModel.prepare()?.value
        await enterText()
        service.hold = .answer
        let task = viewModel.answer(.text("괜찮아요"))
        conversation.onAction?(.switchMode(.voice))
        await waitUntil { service.isHolding }
        #expect(!service.calls.contains(.call))
        service.release()
        await task?.value
        await waitUntil { service.calls.contains(.call) }
    }

    // MARK: - 재검토에서 찾은 경우

    @Test func 음성이_답_없이_끊긴_뒤_문자로_이어_답하고_떠나도_저장한다() async {
        await viewModel.prepare()?.value
        conversation.onAction?(.switchMode(.voice))
        await viewModel.start()?.value // 답 없이 끊김 (.interrupted(nil))
        conversation.onAction?(.switchMode(.text))
        #expect(conversation.question != nil && conversation.errorMessage == nil)
        await viewModel.answer(.text("설사를 했어요"))?.value
        service.endOutcome = .interrupted(record())
        conversation.onAction?(.cancel)
        await waitUntil { repository.saved.count == 1 }
    }

    @Test func 문자로_답한_뒤_음성_준비_중에_떠나도_받은_답을_저장한다() async {
        await enterText()
        await viewModel.answer(.text("설사를 했어요"))?.value
        service.hold = .microphone
        conversation.onAction?(.switchMode(.voice)) // 음성 준비를 시작한다
        await waitUntil { service.isHolding }
        service.endOutcome = .interrupted(record())
        conversation.onAction?(.cancel)
        service.release()
        await waitUntil { repository.saved.count == 1 }
        #expect(!service.calls.contains(.call))
    }

    @Test func 통화를_끊는_중에_다시_음성으로_바꾸면_요약이_아니라_통화를_이어_간다() async {
        await viewModel.prepare()?.value
        conversation.onAction?(.switchMode(.voice))
        service.hold = .call
        service.outcome = .interrupted(record())
        let call = viewModel.start()
        await waitUntil { service.isHolding }
        service.hold = .call // 이어 거는 통화도 붙잡는다
        conversation.onAction?(.switchMode(.text)) // 끊는 중에
        conversation.onAction?(.switchMode(.voice)) // 다시 음성으로
        await call?.value
        await waitUntil { service.isHolding }
        #expect(conversation.summary == nil) // 끊긴 첫 통화는 요약으로 넘기지 않는다
        let finished = record()
        service.outcome = .completed(finished) // 이어 건 통화는 끝까지 마친다
        service.release()
        await waitUntil { conversation.summary != nil }
        #expect(conversation.summary?.record.id == finished.id)
        #expect(service.calls.suffix(2) == [.speech, .call]) // 다시 걸 때는 음성 인식부터
    }

    @Test func 문자에서_음성으로_바꿨는데_마이크가_막혀_있으면_문자로_돌아온다() async {
        await enterText()
        service.errors[.microphone] = AudioRecorderError.microphoneDenied
        conversation.onAction?(.switchMode(.voice))
        await waitUntil { conversation.mode == .text }
        #expect(conversation.question?.text == "오늘 컨디션은 어떠세요?")
        #expect(conversation.errorMessage == "음성 통화를 준비하지 못했어요. 문자로 이어서 답해 주세요.")
        #expect(conversation.needsMicrophone) // 마이크 팝업으로 알린다
        #expect(!service.calls.contains(.call))
    }

    // MARK: - 진행률·안내 문구·마지막 질문

    @Test func 진행률_안내_문구_마지막_질문을_질문에_싣는다() async {
        await enterText()
        service.replies = [CareCallTurn(utterance: "구토는 하루에 몇 번 정도 하셨나요?", number: .count, outcome: nil, progress: 0.4, asksMore: true),
                           CareCallTurn(utterance: "그 밖에 불편한 점은 없으셨나요?", number: nil, outcome: nil, progress: 0.9, isLast: true)]
        await viewModel.answer(.text("토했어요"))?.value
        #expect(conversation.question?.progress == 0.4)
        #expect(conversation.question?.guidance == "말씀해 주신 내용에 대해 조금 더 여쭤볼게요")
        #expect(conversation.question?.isLastQuestion == false)
        await viewModel.answer(.frequency(.count(2)))?.value
        #expect(conversation.question?.guidance == nil && conversation.question?.isLastQuestion == true)
    }

    @Test func 마지막_질문에_답하면_처리하는_동안_정리_화면을_보여_준다() async {
        await enterText()
        service.replies = [CareCallTurn(utterance: "그 밖에 불편한 점은 없으셨나요?", number: nil, outcome: nil, isLast: true),
                           turn("오늘 기록을 마쳤어요.", nil, .completed(record()))]
        await viewModel.answer(.text("없어요"))?.value
        service.hold = .answer
        let task = viewModel.answer(.text("없어요"))
        #expect(conversation.isSummarizing)
        await waitUntil { service.isHolding }
        service.release()
        await task?.value
        #expect(!conversation.isSummarizing && conversation.summary != nil)
    }

    // MARK: - 이전 질문

    @Test func 이전_질문으로_돌아가면_그때_한_답을_다시_채운다() async {
        await enterText()
        #expect(!conversation.canGoPrevious && conversation.question?.allowsPrevious == false)
        let opening = conversation.question!
        let count = turn("구토는 하루에 몇 번 정도 하셨나요?", .count)
        service.replies = [count, turn("변비는 있으셨나요?")]
        service.backTurns = [(turn(opening.text), "토했어요")]
        await viewModel.answer(.text("토했어요"))?.value
        #expect(conversation.canGoPrevious && conversation.question?.allowsPrevious == true)
        service.backTurns.append((count, "3번"))
        await viewModel.answer(.frequency(.count(3)))?.value

        conversation.onAction?(.previous)
        #expect(conversation.question?.input == .frequency)
        #expect(conversation.restoredAnswer == .frequency(.count(3)))
        conversation.onAction?(.previous)
        #expect(conversation.question?.text == opening.text && conversation.answerText == "토했어요")
        #expect(!conversation.canGoPrevious)
    }

    @Test func 통화_중에는_이전_질문으로_가지_않는다() async {
        await viewModel.prepare()?.value
        conversation.onAction?(.switchMode(.voice))
        service.backTurns = [(turn("오늘 컨디션은 어떠세요?"), "괜찮아요")]
        viewModel.autoStartDelay = .zero
        await viewModel.open()?.value
        #expect(!conversation.canGoPrevious)
        conversation.onAction?(.previous)
        #expect(service.backTurns.count == 1)
    }

    @Test(arguments: [
        ("열 번 넘게", SymptomConversationQuestion.Input.frequency, SymptomConversationAnswer.frequency(.tenPlus)),
        ("3번", .frequency, .frequency(.count(3))),
        ("1시간 30분", .duration, .durationMinutes(90)),
        ("하루 종일요", .duration, .text("하루 종일요")),
        ("어제부터요", .text, .text("어제부터요")),
    ])
    func 되돌린_답은_입력_칸_값으로(text: String, input: SymptomConversationQuestion.Input, expected: SymptomConversationAnswer) {
        #expect(CareCallViewModel.answer(text, for: input) == expected)
    }
}
