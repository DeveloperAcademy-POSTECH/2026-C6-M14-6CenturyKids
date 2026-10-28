import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

@MainActor
struct RecordsViewModelTests {
    let calendar = RecordDetailViewModel.calendar
    func date(_ day: Int, _ hour: Int = 9, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
    func pain(_ day: Int, _ hour: Int, _ before: Int, _ after: Int?) throws -> PainRecord {
        try PainRecord(id: UUID(), patientId: UUID(), recordedDate: date(day, hour),
                       location: [BodyLocation(bodyPart: .headFace, bodySide: .left, bodyView: .front)], painBefore: before, painAfter: after)
    }
    func entry(_ type: SymptomType, _ presence: SymptomPresence = .present) throws -> SymptomEntry {
        try SymptomEntry(id: UUID(), symptomType: type, presence: presence, bodyPart: nil, bodySide: nil,
                         durationMinutes: nil, occurrenceCount: nil, detail: nil)
    }

    @Test func 그날_통증은_평균_복용_전후와_차이를_보여준다() throws {
        // 2일: (8+6)/2 → (2+4)/2 = 7 → 3, 차이 4. 1일 기록은 섞이지 않는다
        let snapshot = RecordsViewModel.snapshot(day: date(2, 0), pains: [
            try pain(2, 9, 8, 2), try pain(2, 15, 6, 4), try pain(1, 9, 5, 2)
        ], symptoms: [], calendar: calendar)
        #expect(snapshot.pain?.averageBefore == 7)
        #expect(snapshot.pain?.averageAfter == 3)
        #expect(snapshot.pain?.difference == 4)
        #expect(snapshot.symptom == nil)
        // 그날 통증이 없으면 어제 기록이 있어도 없음
        #expect(RecordsViewModel.snapshot(day: date(3, 0), pains: [try pain(2, 9, 8, 2)], symptoms: [], calendar: calendar).pain == nil)
    }

    @Test func 사후_미측정이면_변화량이_없고_섞여_있으면_짝이_맞는_기록끼리_잰다() throws {
        let snapshot = RecordsViewModel.snapshot(day: date(2), pains: [
            try pain(2, 9, 8, nil), try pain(1, 9, 5, nil)
        ], symptoms: [], calendar: calendar)
        #expect(snapshot.pain != nil)
        #expect(snapshot.pain?.averageBefore == 8)
        #expect(snapshot.pain?.averageAfter == nil)
        #expect(snapshot.pain?.difference == nil)

        let measured = RecordsViewModel.snapshot(day: date(2), pains: [
            try pain(2, 9, 8, nil), try pain(2, 15, 6, 0), try pain(1, 9, 5, 0)
        ], symptoms: [], calendar: calendar)
        // 복용 전 평균은 두 기록 (8+6)/2 = 7, 차이는 복용 후가 있는 기록만 6 − 0 = 6
        #expect(measured.pain?.averageBefore == 7)
        #expect(measured.pain?.averageAfter == 0)
        #expect(measured.pain?.difference == 6)
    }

    @Test func 그날_증상은_있음인_항목_수와_증상_순서대로_종류를_보여준다() throws {
        let record = SymptomRecord(id: UUID(), patientId: UUID(), recordedDate: date(2), conditionText: nil, symptoms: [
            try entry(.numbness), try entry(.numbness), try entry(.nauseaVomiting), try entry(.diarrhea, .absent)
        ])
        let snapshot = RecordsViewModel.snapshot(day: date(2, 0), pains: [], symptoms: [record], calendar: calendar)
        // 부위별 항목은 각각 1건, 없음은 세지 않는다
        #expect(snapshot.symptom?.presentCount == 3)
        #expect(snapshot.symptom?.types == [.nauseaVomiting, .numbness])
        #expect(snapshot.pain == nil)
    }

    @Test func 날짜는_요일까지_보여준다() {
        #expect(RecordsViewModel.dayLabel(date(2, 0), calendar: calendar) == "10월 2일 금요일")
    }

    @Test func 하루씩_옮기되_오늘_뒤로는_가지_않고_카드를_누르면_그날로_상세를_연다() async throws {
        let pains = FakePainRepository(records: [try pain(2, 9, 7, 5)])
        let symptoms = FakeRecordSymptomRepository()
        let today = { self.date(2, 12) }
        let detail = RecordDetailViewModel(patientId: UUID(), painRepository: pains, symptomRepository: symptoms,
                                           calendar: calendar, now: today)
        let viewModel = RecordsViewModel(patientId: UUID(), painRepository: pains, symptomRepository: symptoms,
                                         detail: detail, calendar: calendar, now: today)
        let state = viewModel.state
        state.onAction?(.load)
        await waitUntilLoaded(state)
        #expect(state.snapshot?.pain?.difference == 2)
        // 통증은 그날만 찾는다 (통증 저장소는 끝 날짜 포함)
        #expect(pains.ranges.last?.from == date(2, 0))
        #expect(pains.ranges.last?.to == date(2, 0))

        state.onAction?(.moveDay(1))
        #expect(pains.ranges.count == 1)

        state.onAction?(.moveDay(-1))
        #expect(state.dateLabel == "10월 1일 목요일")
        await waitUntilLoaded(state)
        #expect(state.snapshot?.pain == nil)

        state.onAction?(.select(.pain))
        #expect(detail.pain.periodLabel == "10월 1일")
    }

    @Test func 상세에서_날짜를_옮기고_돌아오면_목록도_그날로_맞춘다() async throws {
        let pains = FakePainRepository(records: [])
        let symptoms = FakeRecordSymptomRepository()
        let today = { self.date(2, 12) }
        let detail = RecordDetailViewModel(patientId: UUID(), painRepository: pains, symptomRepository: symptoms,
                                           calendar: calendar, now: today)
        let viewModel = RecordsViewModel(patientId: UUID(), painRepository: pains, symptomRepository: symptoms,
                                         detail: detail, calendar: calendar, now: today)
        let state = viewModel.state
        state.onAction?(.moveDay(-1))
        state.onAction?(.select(.symptom))
        detail.symptom.onAction?(.movePeriod(-1))
        #expect(detail.symptom.periodLabel == "9월 30일")
        // 돌아오면 목록이 다시 나타나며 조회한다
        state.onAction?(.load)
        #expect(state.dateLabel == "9월 30일 수요일")
        await waitUntilLoaded(state)
        #expect(pains.ranges.last?.from == date(30, 0, month: 9))

        // 주로 바꿔 이번 주에 머물면 기준 날(9월 30일)이 그대로이고, 상세를 열지 않은 조회는 날짜를 바꾸지 않는다
        state.onAction?(.select(.pain))
        detail.pain.onAction?(.selectPeriod(.week))
        state.onAction?(.load)
        #expect(state.dateLabel == "9월 30일 수요일")
        state.onAction?(.moveDay(1))
        state.onAction?(.load)
        #expect(state.dateLabel == "10월 1일 목요일")
    }

    private func waitUntilLoaded(_ state: RecordsScreenState) async {
        for _ in 0..<100 where !state.loadState.isLoaded { await Task.yield() }
    }
}
