import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

@MainActor
struct RecordDetailViewModelTests {
    let calendar = RecordDetailViewModel.calendar
    func date(_ day: Int, _ hour: Int = 9, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
    func pain(_ day: Int, _ hour: Int, _ before: Int, _ after: Int) throws -> PainRecord {
        try PainRecord(id: UUID(), patientId: UUID(), recordedDate: date(day, hour),
                       location: [BodyLocation(bodyPart: .headFace, bodySide: .left, bodyView: .front)], painBefore: before, painAfter: after)
    }
    func symptoms(_ day: Int, _ entries: [(SymptomType, SymptomPresence)]) throws -> SymptomRecord {
        SymptomRecord(id: UUID(), patientId: UUID(), recordedDate: date(day), conditionText: nil, symptoms: try entries.map {
            try SymptomEntry(id: UUID(), symptomType: $0.0, presence: $0.1, bodyPart: nil, bodySide: nil,
                             durationMinutes: nil, occurrenceCount: nil, detail: nil)
        })
    }

    @Test func 통증_주월은_기록한_날들의_하루_차이를_날_수로_평균낸다() throws {
        // 17일: 두 번 기록 → 평균 (8+6)/2 − (2+4)/2 = 4, 18일: 5 − 4 = 1 → (4 + 1) / 2 = 2.5 (기록 건수 3으로 나누지 않음)
        let detail = RecordDetailViewModel.painDetail([try pain(17, 9, 8, 2), try pain(17, 15, 6, 4), try pain(18, 9, 5, 4)],
                                                      period: .week, calendar: calendar)
        #expect(detail.averageDifference == 2.5)
        #expect(detail.days.map(\.averageBefore) == [7, 5])
        #expect(detail.days.map(\.averageAfter) == [3, 4])
        #expect(detail.records == nil)
    }

    @Test func 통증_일은_기록마다_시간축에_그리고_기록이_없으면_평균도_없다() throws {
        let detail = RecordDetailViewModel.painDetail([try pain(17, 15, 6, 4), try pain(17, 9, 8, 2)], period: .day, calendar: calendar)
        #expect(detail.averageDifference == 4)
        #expect(detail.records?.map(\.painBefore) == [8, 6])
        #expect(RecordDetailViewModel.painDetail([], period: .day, calendar: calendar).averageDifference == nil)
    }

    @Test func 하루기록은_증상마다_있음으로_답한_날_수로_크기를_정한다() throws {
        let detail = RecordDetailViewModel.symptomDetail([
            try symptoms(17, [(.numbness, .present), (.numbness, .present), (.diarrhea, .absent)]),
            try symptoms(18, [(.numbness, .present), (.diarrhea, .present), (.constipation, .unknown)])
        ], calendar: calendar)
        // 같은 날 부위별 항목 두 개는 하루, 없음·모름은 세지 않는다
        #expect(detail.symptoms.map(\.type) == [.numbness, .diarrhea])
        #expect(detail.symptoms.map(\.weight) == [2, 1])
        #expect(detail.symptoms.first?.label == "2일")
        #expect(detail.records.count == 2)
    }

    @Test func 주_이름은_목요일이_든_달의_몇_번째_주로_센다() throws {
        // 2026-09-28(월) ~ 10-04: 목요일이 10월 1일 → 10월 1번째 주
        #expect(RecordDetailViewModel.periodLabel(.week, start: date(28, 0), calendar: calendar) == "10월 1번째 주")
        #expect(RecordDetailViewModel.periodLabel(.week, start: date(21, 0), calendar: calendar) == "9월 4번째 주")
        #expect(RecordDetailViewModel.periodLabel(.day, start: date(17), calendar: calendar) == "9월 17일")
    }

    @Test func 조회하면_기간을_채우고_오늘_이후로는_넘어가지_않는다() async throws {
        let repository = FakePainRepository(records: [try pain(17, 9, 8, 2)])
        let today = date(17, 12)
        let viewModel = RecordDetailViewModel(patientId: UUID(), painRepository: repository,
                                              symptomRepository: FakeRecordSymptomRepository(), calendar: calendar, now: { today })
        let state = viewModel.pain
        state.onAction?(.selectPeriod(.week))
        await waitUntilLoaded(state)
        #expect(state.periodLabel == "9월 3번째 주")
        #expect(state.rangeLabel == "9월 14일 ~ 9월 20일")
        #expect(state.days.count == 7)
        // 통증 저장소는 끝 날짜를 포함하므로 마지막 날(일요일)을 넘긴다
        #expect(repository.ranges.last?.to == date(20, 0))
        guard case .pain(let detail) = state.content else { Issue.record("통증 내용 없음"); return }
        #expect(detail.averageDifference == 6)

        state.onAction?(.movePeriod(1))
        #expect(state.periodLabel == "9월 3번째 주")
        #expect(repository.ranges.count == 1)
    }

    private func waitUntilLoaded(_ state: RecordDetailScreenState) async {
        for _ in 0..<100 where !state.loadState.isLoaded { await Task.yield() }
    }
}

private final class FakePainRepository: PainRepository {
    let records: [PainRecord]
    private(set) var ranges: [(from: Date, to: Date)] = []
    init(records: [PainRecord]) { self.records = records }
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [PainRecord] {
        ranges.append((startDate, endDate)); return records
    }
    func save(entity: PainRecord) async throws {}
    func findByPatientId(_ patientId: UUID) async throws -> [PainRecord] { records }
    func findById(_ id: UUID) async throws -> PainRecord? { nil }
    func deleteById(_ id: UUID) async throws {}
}

private struct FakeRecordSymptomRepository: SymptomRepository {
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [SymptomRecord] { [] }
    func save(entity: SymptomRecord) async throws {}
    func findByPatientId(_ patientId: UUID) async throws -> [SymptomRecord] { [] }
    func findById(_ id: UUID) async throws -> SymptomRecord? { nil }
    func deleteById(_ id: UUID) async throws {}
}
