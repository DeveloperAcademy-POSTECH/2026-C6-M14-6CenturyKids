import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 폰에 남긴 케어콜 기록 가짜 (메모리). failSave면 남기기가 실패한다
final class FakePendingCareCalls: PendingCareCallRepository {
    private(set) var items: [UUID: PendingCareCall] = [:]
    var failSave = false

    func save(_ pending: PendingCareCall) throws {
        if failSave { throw FakeSymptomRecords.Failure() }
        items[pending.id] = pending
    }

    func findAll(patientId: UUID) throws -> [PendingCareCall] {
        items.values.filter { $0.record.patientId == patientId }.sorted { $0.record.recordedDate < $1.record.recordedDate }
    }

    func delete(id: UUID, patientId: UUID) throws {
        items[id] = nil
    }
}

/// 받은 답은 답마다 폰에 남기고, 앱이 꺼지거나 저장이 실패하면 다음에 케어콜에 들어갈 때 조용히 올린다. 가상 데이터만
@MainActor
struct PendingCareCallTests {
    let service = FakeCareCall()
    let repository = FakeSymptomRecords()
    let pending = FakePendingCareCalls()
    let patientId = UUID()

    private func makeViewModel(patientId: UUID? = nil) -> CareCallViewModel {
        CareCallViewModel(service: service, repository: repository, pending: pending, patientId: patientId ?? self.patientId)
    }

    private func record(_ type: SymptomType = .diarrhea, patientId: UUID? = nil, date: Date = Date()) -> SymptomRecord {
        let entry = try! SymptomEntry(id: UUID(), symptomType: type, presence: .present, bodyPart: nil, bodySide: nil,
                                      durationMinutes: nil, occurrenceCount: nil, detail: nil)
        return SymptomRecord(id: UUID(), patientId: patientId ?? self.patientId, recordedDate: date, conditionText: nil, symptoms: [entry])
    }

    private func turn(_ text: String, _ outcome: CareCallOutcome? = nil) -> CareCallTurn {
        CareCallTurn(utterance: text, number: nil, outcome: outcome)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() { await Task.yield() }
        #expect(condition())
    }

    /// 문자로 대화를 시작해 첫 질문을 받은 상태
    private func enterText(_ viewModel: CareCallViewModel) async {
        viewModel.conversation.onAction?(.switchMode(.text))
        await viewModel.start()?.value
    }

    @Test func 답할_때마다_받은_답까지_폰에_남긴다() async {
        let viewModel = makeViewModel()
        await enterText(viewModel)
        #expect(pending.items.isEmpty) // 아직 받은 답이 없음
        service.progress = record(.diarrhea)
        service.replies = [turn("하루에 몇 번 정도 하셨나요?")]
        await viewModel.answer(.text("설사를 했어요"))?.value
        let kept = try! pending.findAll(patientId: patientId)
        #expect(kept.count == 1 && kept[0].record.symptoms.first?.symptomType == .diarrhea && !kept[0].complete)
        service.progress = record(.nauseaVomiting)
        service.replies = [turn("그 밖에 더 불편하신 점 있으세요?")]
        await viewModel.answer(.text("세 번이요"))?.value
        #expect(try! pending.findAll(patientId: patientId).map { $0.record.symptoms.first?.symptomType } == [.nauseaVomiting]) // 같은 케어콜은 덮어쓴다
    }

    @Test func 음성_통화에서도_다음_질문을_말할_때마다_남긴다() async {
        let viewModel = makeViewModel()
        await viewModel.prepare()?.value
        service.progress = record(.constipation)
        service.activities = [.speaking("오늘 컨디션은 어떠세요?"), .heard("변비가 있어요"), .speaking("언제부터 그랬나요?")]
        service.hold = .call
        viewModel.conversation.onAction?(.switchMode(.voice))
        let call = viewModel.start()
        for _ in 0..<1_000 where !service.isHolding { await Task.yield() }
        #expect(try! pending.findAll(patientId: patientId).first?.record.symptoms.first?.symptomType == .constipation)
        service.release()
        await call?.value
    }

    @Test func 저장하면_폰에_남긴_기록을_지운다() async {
        let viewModel = makeViewModel()
        await enterText(viewModel)
        service.replies = [turn("감사합니다", .completed(record()))]
        await viewModel.answer(.text("없어요"))?.value
        #expect(try! pending.findAll(patientId: patientId).first?.complete == true) // 끝까지 마친 통화로 남긴다
        await viewModel.save(showingResult: true)?.value
        #expect(repository.saved.count == 1 && pending.items.isEmpty)
    }

    @Test func 저장에_실패하면_남겨_두고_다음에_케어콜에_들어갈_때_조용히_올린다() async {
        let first = makeViewModel()
        await enterText(first)
        service.replies = [turn("감사합니다", .completed(record()))]
        await first.answer(.text("없어요"))?.value
        repository.failNextSave = true
        first.conversation.summary?.onAction?(.cancel) // 요약을 떠나며 자동 저장 → 실패
        await waitUntil { !repository.failNextSave } // 자동 저장이 실패할 때까지
        #expect(pending.items.count == 1)

        let next = makeViewModel()
        await enterText(next)
        #expect(repository.saved.count == 1 && pending.items.isEmpty)
        #expect(next.conversation.errorMessage == nil) // 아무것도 알리지 않는다
    }

    @Test func 앱이_꺼진_뒤에도_마지막_답까지_남은_기록을_다음에_올린다() async {
        let first = makeViewModel()
        await enterText(first)
        service.progress = record(.oralPain)
        service.replies = [turn("언제부터 그랬나요?")]
        await first.answer(.text("입안이 헐었어요"))?.value
        // 여기서 앱이 꺼짐: 끝내는 코드가 불리지 않는다

        service.progress = nil
        let next = makeViewModel()
        await enterText(next)
        #expect(repository.saved.first?.symptoms.first?.symptomType == .oralPain)
        #expect(pending.items.isEmpty)
    }

    @Test func 그날_기록이_있는데_끊긴_다시_거는_통화는_올리지_않고_지운다() async {
        repository.existing = record(.nauseaVomiting)
        try! pending.save(PendingCareCall(id: UUID(), record: record(.diarrhea), complete: false))
        await enterText(makeViewModel())
        #expect(repository.saved.isEmpty && pending.items.isEmpty)
    }

    @Test func 그날_기록이_있으면_끝까지_마친_다시_거는_통화는_그_기록에_더해_올린다() async {
        let existing = record(.nauseaVomiting)
        repository.existing = existing
        try! pending.save(PendingCareCall(id: UUID(), record: record(.diarrhea), complete: true))
        await enterText(makeViewModel())
        #expect(repository.saved.count == 1 && repository.saved[0].id == existing.id)
        #expect(Set(repository.saved[0].symptoms.map(\.symptomType)) == [.nauseaVomiting, .diarrhea])
        #expect(pending.items.isEmpty)
    }

    @Test func 다른_환자의_남은_기록은_올리지_않는다() async {
        let other = UUID()
        try! pending.save(PendingCareCall(id: UUID(), record: record(patientId: other), complete: true))
        await enterText(makeViewModel())
        #expect(repository.saved.isEmpty)
        #expect(try! pending.findAll(patientId: other).count == 1)
    }

    @Test func 올리지_못한_지난_기록은_이번_케어콜이_끝나도_지우지_않는다() async {
        let left = PendingCareCall(id: UUID(), record: record(.rashItching, date: Date(timeIntervalSinceNow: -86_400)), complete: true)
        try! pending.save(left)
        repository.failNextSave = true // 들어갈 때 올리기 실패
        let viewModel = makeViewModel()
        await enterText(viewModel)
        service.replies = [turn("감사합니다", .completed(record()))]
        await viewModel.answer(.text("없어요"))?.value
        await viewModel.save(showingResult: true)?.value
        #expect(repository.saved.count == 1) // 이번 기록만 저장
        #expect(try! pending.findAll(patientId: patientId).map(\.id) == [left.id])
    }

    @Test func 응급으로_끝나면_그날_기록에_더해_저장한다() async {
        let existing = record(.nauseaVomiting)
        repository.existing = existing
        let viewModel = makeViewModel()
        await enterText(viewModel)
        service.replies = [turn("응급 안내", .emergencyEnded(record()))]
        await viewModel.answer(.text("숨이 차요"))?.value
        viewModel.conversation.onAction?(.stopForEmergency) // 응급 팝업의 기록 중단
        await waitUntil { repository.saved.count == 1 }
        #expect(repository.saved[0].id == existing.id) // 다시 거는 통화처럼 그날 기록에 더한다
        #expect(Set(repository.saved[0].symptoms.map(\.symptomType)) == [.nauseaVomiting, .diarrhea])
        #expect(pending.items.isEmpty)
    }

    @Test func 응급_기록을_올리지_못하면_폰에_남겨_다음에_올린다() async {
        repository.failNextSave = true
        let viewModel = makeViewModel()
        await enterText(viewModel)
        service.replies = [turn("응급 안내", .emergencyEnded(record()))]
        await viewModel.answer(.text("숨이 차요"))?.value
        viewModel.conversation.onAction?(.stopForEmergency)
        await waitUntil { !pending.items.isEmpty && repository.saved.isEmpty }
        #expect(pending.items.values.first?.complete == true)
    }

    @Test(arguments: [CareCallOutcome.interrupted(nil)])
    func 저장하지_않는_결과면_남긴_기록을_지운다(outcome: CareCallOutcome) async {
        let viewModel = makeViewModel()
        await enterText(viewModel)
        service.progress = record()
        service.replies = [turn("다음 질문")]
        await viewModel.answer(.text("설사를 했어요"))?.value
        #expect(pending.items.count == 1)
        service.replies = [turn("응급 안내", outcome)]
        await viewModel.answer(.text("숨이 차요"))?.value
        #expect(pending.items.isEmpty)
    }

    @Test func 폰에_남기지_못해도_대화는_이어_간다() async {
        pending.failSave = true
        let viewModel = makeViewModel()
        await enterText(viewModel)
        service.progress = record()
        service.replies = [turn("하루에 몇 번 정도 하셨나요?")]
        await viewModel.answer(.text("설사를 했어요"))?.value
        #expect(viewModel.conversation.question?.text == "하루에 몇 번 정도 하셨나요?")
        #expect(viewModel.conversation.errorMessage == nil)
    }

    @Test func 기록_중단에서_그만하면_저장하지_않고_폰에서도_지운다() async {
        let viewModel = makeViewModel()
        await enterText(viewModel)
        service.progress = record()
        service.replies = [turn("변비는 있으셨나요?")]
        await viewModel.answer(.text("설사를 했어요"))?.value
        #expect(!pending.items.isEmpty)
        service.endOutcome = .interrupted(record())
        viewModel.conversation.onAction?(.pause)
        viewModel.conversation.onAction?(.discard)
        viewModel.conversation.onAction?(.cancel) // 화면을 떠나도 저장하지 않는다
        for _ in 0..<200 { await Task.yield() }
        #expect(repository.saved.isEmpty && pending.items.isEmpty)
    }

}
