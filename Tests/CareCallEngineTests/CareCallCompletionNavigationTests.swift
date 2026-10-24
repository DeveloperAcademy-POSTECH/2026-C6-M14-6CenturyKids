import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

struct CareCallCompletionNavigationTests {
    @Test func 홈_이동은_저장_성공_후_한번만_허용하고_기록_날짜를_만들지_않는다() {
        var navigation = CareCallCompletionNavigation()
        let beforeSave = navigation.beginHome(didSave: false)
        #expect(!beforeSave)
        #expect(navigation.beginRecord(didSave: true, recordedDate: nil) == nil)
        #expect(!navigation.didNavigate)
        let firstHome = navigation.beginHome(didSave: true)
        let secondHome = navigation.beginHome(didSave: true)
        #expect(firstHome)
        #expect(!secondHome)
        #expect(navigation.beginRecord(didSave: true, recordedDate: Date()) == nil)
    }

    @MainActor
    @Test func 저장_실패는_요약을_유지하고_재시도_성공한_기록의_날짜를_재조회한다() async throws {
        let patientId = UUID()
        let calendar = RecordDetailViewModel.calendar
        let savedDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 23, minute: 59)))
        let record = SymptomRecord(id: UUID(), patientId: patientId, recordedDate: savedDate,
                                  conditionText: "괜찮아요", symptoms: [
            try SymptomEntry(id: UUID(), symptomType: .constipation, presence: .present,
                             bodyPart: nil, bodySide: nil, durationMinutes: nil,
                             occurrenceCount: nil, detail: "어제부터예요")
        ])
        let service = FakeCareCall()
        service.opening = CareCallTurn(utterance: "대화를 마쳤어요", number: nil, outcome: .completed(record))
        let repository = CompletionSymptomRepository()
        let viewModel = CareCallViewModel(service: service, repository: repository,
                                         pending: FakePendingCareCalls(), patientId: patientId)
        await viewModel.startText()?.value
        let summary = try #require(viewModel.conversation.summary)
        var navigation = CareCallCompletionNavigation()

        repository.failNextSave = true
        await viewModel.save(showingResult: true)?.value
        let failedMove = navigation.beginRecord(didSave: viewModel.conversation.didSave,
                                                recordedDate: viewModel.record?.recordedDate)
        #expect(failedMove == nil && !viewModel.conversation.didSave)
        #expect(summary.canSave && summary.record.symptoms[0].detail == "어제부터예요")

        await viewModel.save(showingResult: true)?.value
        let completionDate = navigation.beginRecord(didSave: viewModel.conversation.didSave,
                                                    recordedDate: viewModel.record?.recordedDate)
        let date = try #require(completionDate)
        #expect(date == savedDate)
        #expect(navigation.beginRecord(didSave: true, recordedDate: savedDate) == nil)
        let homeAfterRecord = navigation.beginHome(didSave: true)
        #expect(!homeAfterRecord)
        let detail = RecordDetailViewModel(patientId: patientId, painRepository: FakePainRepository(records: []),
                                          symptomRepository: repository, calendar: calendar,
                                          now: { savedDate.addingTimeInterval(120) })
        detail.symptom.period = .day
        detail.show(.symptom, at: date)
        detail.symptom.onAction?(.load)
        for _ in 0..<1_000 where !detail.symptom.loadState.isLoaded { await Task.yield() }
        let start = detail.symptom.calendar.startOfDay(for: savedDate)
        let end = try #require(detail.symptom.calendar.date(byAdding: .day, value: 1, to: start))
        #expect(repository.queries.last?.patientId == patientId)
        #expect(repository.queries.last?.from == start && repository.queries.last?.to == end)
        guard case .symptom(let content) = detail.symptom.content else {
            Issue.record("저장한 하루 기록을 조회하지 못함"); return
        }
        #expect(content.records.map(\.id) == [record.id])
        summary.onAction?(.cancel)
        #expect(repository.saved.count == 1)
        #expect(repository.saveAttempts == 2) // 실패 1회 + 성공 1회. 이동과 재조회는 저장하지 않습니다.
        withExtendedLifetime(detail) {}
    }
}

private final class CompletionSymptomRepository: SymptomRepository {
    struct Failure: Error {}
    var failNextSave = false
    private(set) var saved: [SymptomRecord] = []
    private(set) var saveAttempts = 0
    private(set) var queries: [(patientId: UUID, from: Date, to: Date)] = []
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [SymptomRecord] {
        queries.append((patientId, startDate, endDate))
        return saved.filter { $0.patientId == patientId && startDate <= $0.recordedDate && $0.recordedDate < endDate }
    }
    func save(entity: SymptomRecord) async throws {
        saveAttempts += 1
        if failNextSave { failNextSave = false; throw Failure() }
        saved.append(entity)
    }
    func findByPatientId(_ patientId: UUID) async throws -> [SymptomRecord] { saved.filter { $0.patientId == patientId } }
    func findById(_ id: UUID) async throws -> SymptomRecord? { saved.first { $0.id == id } }
    func deleteById(_ id: UUID) async throws {}
}
