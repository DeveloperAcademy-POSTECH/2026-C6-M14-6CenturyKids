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
        SymptomRecord(id: UUID(), patientId: UUID(), recordedDate: date(day), conditionText: nil,
                      symptoms: try entries.map { try entry($0.0, $0.1) })
    }
    func entry(_ type: SymptomType, _ presence: SymptomPresence = .present, count: Int? = nil, minutes: Int? = nil) throws -> SymptomEntry {
        try SymptomEntry(id: UUID(), symptomType: type, presence: presence, bodyPart: nil, bodySide: nil,
                         durationMinutes: minutes, occurrenceCount: count, detail: nil)
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

    @Test func 하루기록_주월은_증상마다_있음으로_나타난_날_수로_크기를_정한다() throws {
        let detail = RecordDetailViewModel.symptomDetail([
            try symptoms(17, [(.numbness, .present), (.numbness, .present), (.diarrhea, .absent)]),
            try symptoms(18, [(.numbness, .present), (.diarrhea, .present), (.constipation, .unknown)])
        ], period: .week, calendar: calendar)
        // 같은 날 부위별 항목 두 개는 하루, 없음·모름은 세지 않는다
        #expect(detail.symptoms.map(\.type) == [.numbness, .diarrhea])
        #expect(detail.symptoms.map(\.weight) == [2, 1])
        #expect(detail.records.map(\.recordedDate) == [date(18), date(17)])
    }

    @Test func 하루기록_일은_있음인_증상을_같은_크기로_증상_순서대로_보여준다() throws {
        let record = SymptomRecord(id: UUID(), patientId: UUID(), recordedDate: date(17), conditionText: nil, symptoms: [
            try entry(.numbness, minutes: 30), try entry(.numbness, minutes: 60),
            try entry(.nauseaVomiting, count: 2), try entry(.nauseaVomiting, count: 1),
            try entry(.constipation), try entry(.diarrhea, .absent, count: 4)
        ])
        let detail = RecordDetailViewModel.symptomDetail([record], period: .day, calendar: calendar)
        // 같은 증상의 부위별 항목은 한 칸, 없음은 빼고 증상 순서대로 같은 크기
        #expect(detail.symptoms.map(\.type) == [.nauseaVomiting, .constipation, .numbness])
        #expect(detail.symptoms.map(\.weight) == [1, 1, 1])
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

    // MARK: - 하루 기록 수정

    /// 17일 하루 기록(손발 저림 2회, 설사 있음)을 불러온 하루 기록 화면
    /// 화면 상태는 ViewModel을 약하게 잡으므로 테스트가 ViewModel을 들고 있어야 한다
    private func editing(_ repository: FakeRecordSymptomRepository) async throws -> (RecordDetailViewModel, RecordDetailScreenState, UUID) {
        let numbness = try entry(.numbness, count: 2)
        repository.records = [SymptomRecord(id: UUID(), patientId: UUID(), recordedDate: date(17), conditionText: nil,
                                            symptoms: [numbness, try entry(.diarrhea)])]
        let viewModel = RecordDetailViewModel(patientId: UUID(), painRepository: FakePainRepository(records: []),
                                              symptomRepository: repository, calendar: calendar, now: { date(17, 12) })
        let state = viewModel.symptom
        state.onAction?(.load)
        await waitUntil { state.loadState.isLoaded }
        state.onAction?(.edit(.numbness))
        return (viewModel, state, numbness.id)
    }

    private func input(_ id: UUID, in state: RecordDetailScreenState, count: String) -> SymptomEntryEditInput {
        guard case .symptom(let data) = state.content,
              let entry = data.records.flatMap(\.symptoms).first(where: { $0.id == id }) else { fatalError("카드 없음") }
        var input = SymptomEntryEditInput(entry)
        input.occurrenceText = count
        return input
    }

    @Test func 수정을_완료하면_그날_기록을_저장하고_그_카드의_편집을_닫는다() async throws {
        let repository = FakeRecordSymptomRepository()
        let (viewModel, state, id) = try await editing(repository)
        #expect(state.editingEntryIDs == [id])

        state.onAction?(.finishEdit(id, input(id, in: state, count: "3")))
        await waitUntil { !state.isSaving && repository.saved.count == 1 }
        #expect(repository.saved.first?.symptoms.first { $0.id == id }?.occurrenceCount == 3)
        #expect(state.editingEntryIDs.isEmpty)
        guard case .symptom(let data) = state.content else { Issue.record("하루 기록 없음"); return }
        #expect(data.records.flatMap(\.symptoms).first { $0.id == id }?.occurrenceCount == 3)
        withExtendedLifetime(viewModel) {}
    }

    @Test func 숫자가_아니면_저장하지_않고_카드에_이유를_남긴다() async throws {
        let repository = FakeRecordSymptomRepository()
        let (viewModel, state, id) = try await editing(repository)
        state.onAction?(.finishEdit(id, input(id, in: state, count: "두 번")))
        #expect(state.editErrors[id] == "횟수는 1에서 100 사이 숫자로 입력해 주세요.")
        #expect(state.editingEntryIDs == [id])
        #expect(repository.saved.isEmpty)
        withExtendedLifetime(viewModel) {}
    }

    @Test func 저장에_실패하면_편집을_유지하고_다시_시도하게_한다() async throws {
        let repository = FakeRecordSymptomRepository()
        repository.saveError = URLError(.notConnectedToInternet)
        let (viewModel, state, id) = try await editing(repository)
        state.onAction?(.finishEdit(id, input(id, in: state, count: "3")))
        await waitUntil { !state.isSaving && state.editErrors[id] != nil }
        #expect(state.editErrors[id] == "저장하지 못했어요. 다시 시도해 주세요.")
        #expect(state.editingEntryIDs == [id])
        withExtendedLifetime(viewModel) {}
    }

    @Test func 지우면_없음으로_저장되고_그리드에서_빠진다() async throws {
        let repository = FakeRecordSymptomRepository()
        let (viewModel, state, id) = try await editing(repository)
        state.onAction?(.delete(id))
        await waitUntil { !state.isSaving && repository.saved.count == 1 }
        let saved = try #require(repository.saved.first)
        #expect(!saved.symptoms.contains { $0.id == id })
        #expect(saved.symptoms.contains { $0.symptomType == .numbness && $0.presence == .absent })
        guard case .symptom(let data) = state.content else { Issue.record("하루 기록 없음"); return }
        #expect(data.symptoms.map(\.type) == [.diarrhea])
        withExtendedLifetime(viewModel) {}
    }

    @Test func 편집_중에는_기간을_바꾸지_않는다() async throws {
        let (viewModel, state, _) = try await editing(FakeRecordSymptomRepository())
        state.onAction?(.selectPeriod(.week))
        #expect(state.period == .day)
        state.onAction?(.endEdit)
        state.onAction?(.selectPeriod(.week))
        #expect(state.period == .week)
        withExtendedLifetime(viewModel) {}
    }

    private func waitUntilLoaded(_ state: RecordDetailScreenState) async {
        await waitUntil { state.loadState.isLoaded }
    }
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() { await Task.yield() }
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

private final class FakeRecordSymptomRepository: SymptomRepository {
    var records: [SymptomRecord] = []
    var saveError: Error?
    private(set) var saved: [SymptomRecord] = []
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [SymptomRecord] { records }
    func save(entity: SymptomRecord) async throws {
        if let saveError { throw saveError }
        saved.append(entity)
    }
    func findByPatientId(_ patientId: UUID) async throws -> [SymptomRecord] { records }
    func findById(_ id: UUID) async throws -> SymptomRecord? { nil }
    func deleteById(_ id: UUID) async throws {}
}
