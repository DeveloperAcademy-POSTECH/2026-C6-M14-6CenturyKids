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
        viewModel = CareCallViewModel(service: service, repository: repository, patientId: UUID())
    }

    private func turn(_ text: String, _ number: CareCallConfig.Effect.Detail.Number? = nil,
                      _ outcome: CareCallOutcome? = nil) -> CareCallTurn {
        CareCallTurn(utterance: text, number: number, outcome: outcome)
    }

    private func record() -> SymptomRecord {
        let entry = try! SymptomEntry(id: UUID(), symptomType: .diarrhea, presence: .present, bodyPart: nil, bodySide: nil,
                                      durationMinutes: nil, occurrenceCount: nil, detail: nil)
        return SymptomRecord(id: UUID(), recordedDate: Date(timeIntervalSince1970: 1_000), symptoms: [entry])
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

    @Test func 응급이면_안내를_남기고_더_받지_않는다() async {
        await enterText()
        service.replies = [turn("응급 안내 문구", nil, .emergencyEnded)]
        await viewModel.answer(.text("숨이 차요"))?.value
        #expect(conversation.question?.text == "응급 안내 문구" && conversation.summary == nil)
        #expect(viewModel.answer(.text("네")) == nil)
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
}
