import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

@MainActor
struct PainRecordViewModelTests {
    let patientId = UUID()
    let chest = BodyLocation(bodyPart: .chest, bodySide: .center, bodyView: .front)

    func record(at date: Date, after: Int?) throws -> PainRecord {
        try PainRecord(id: UUID(), patientId: patientId, recordedDate: date, location: [chest], painBefore: 7, painAfter: after)
    }

    @Test func 가장_최근_기록이_복용_후_점수를_기다릴_때만_이어서_기록한다() async throws {
        let saved = Date(timeIntervalSince1970: 1_000_000)
        let pending = try record(at: saved, after: nil)

        let waiting = PainRecordViewModel(patientId: patientId, painRepository: StubPainRepository(latest: pending))
        await waiting.load()
        #expect(waiting.connectionState == .ready)
        #expect(waiting.pendingRecord?.id == pending.id)
        #expect(waiting.afterAvailableDate == saved.addingTimeInterval(60 * 60))

        let done = PainRecordViewModel(patientId: patientId, painRepository: StubPainRepository(latest: try record(at: saved, after: 3)))
        await done.load()
        #expect(done.pendingRecord == nil)

        let empty = PainRecordViewModel(patientId: patientId, painRepository: StubPainRepository(latest: nil))
        await empty.load()
        #expect(empty.pendingRecord == nil)
        #expect(empty.painBefore == nil)
        #expect(empty.painAfter == nil)
    }

    @Test func 점수를_고르지_않으면_먹기_전도_먹은_뒤도_저장하지_않는다() async throws {
        let repository = StubPainRepository(latest: nil)
        let viewModel = PainRecordViewModel(patientId: patientId, painRepository: repository)
        await viewModel.load()
        viewModel.selectLocation(chest)

        await #expect(throws: PainRecordViewModel.SaveError.missingScore) { _ = try await viewModel.saveBeforeRecord() }
        #expect(repository.saved.isEmpty)

        viewModel.setBeforeScore(7)
        _ = try await viewModel.saveBeforeRecord()
        await #expect(throws: PainRecordViewModel.SaveError.missingScore) { _ = try await viewModel.saveAfterRecord() }
        #expect(repository.filled.isEmpty)
    }

    @Test func 먹기_전_통증은_복용_후_점수_없이_저장하고_그_기록을_기다린다() async throws {
        let repository = StubPainRepository(latest: nil)
        var reminders: [Date] = []
        let viewModel = PainRecordViewModel(patientId: patientId, painRepository: repository,
                                            scheduleAfterReminder: { reminders.append($0) })
        await viewModel.load()
        viewModel.selectLocation(chest)
        viewModel.setBeforeScore(6)

        let now = Date(timeIntervalSince1970: 2_000_000)
        let record = try await viewModel.saveBeforeRecord(at: now)

        #expect(repository.saved.map(\.id) == [record.id])
        #expect(record.painBefore == 6)
        #expect(record.painAfter == nil)
        #expect(record.recordedDate == now)
        #expect(viewModel.pendingRecord?.id == record.id)
        #expect(reminders == [now.addingTimeInterval(60 * 60)])
    }

    @Test func 기존_통증을_마저_기록하면_같은_기록에_복용_후_점수를_채운다() async throws {
        let pending = try record(at: Date(timeIntervalSince1970: 1_000_000), after: nil)
        let repository = StubPainRepository(latest: pending)
        var cancelled = 0
        let viewModel = PainRecordViewModel(patientId: patientId, painRepository: repository,
                                            cancelAfterReminder: { cancelled += 1 })
        await viewModel.load()
        viewModel.setAfterScore(2)

        let record = try await viewModel.saveAfterRecord()

        #expect(repository.filled.count == 1)
        #expect(repository.filled.first?.id == pending.id)
        #expect(repository.filled.first?.painAfter == 2)
        #expect(record.painChange == 5)
        #expect(viewModel.pendingRecord == nil)
        #expect(cancelled == 1)
    }

    @Test func 새로운_통증을_기록하면_이전_기록은_먹기_전_점수만_남는다() async throws {
        let old = try record(at: Date(timeIntervalSince1970: 1_000_000), after: nil)
        let repository = StubPainRepository(latest: old)
        let viewModel = PainRecordViewModel(patientId: patientId, painRepository: repository)
        await viewModel.load()

        viewModel.startNewRecord()
        viewModel.selectLocation(chest)
        viewModel.setBeforeScore(8)
        let new = try await viewModel.saveBeforeRecord()

        #expect(repository.filled.isEmpty)
        #expect(viewModel.pendingRecord?.id == new.id)
        await #expect(throws: PainRecordViewModel.SaveError.self) {
            _ = try await PainRecordViewModel(patientId: patientId, painRepository: StubPainRepository(latest: nil))
                .saveAfterRecord()
        }
    }
}

private final class StubPainRepository: PainRepository {
    let latest: PainRecord?
    private(set) var saved: [PainRecord] = []
    private(set) var filled: [(id: UUID, painAfter: Int)] = []
    init(latest: PainRecord?) { self.latest = latest }

    func findLatestByPatientId(_ patientId: UUID) async throws -> PainRecord? { latest }
    func savePainAfter(recordId: UUID, painAfter: Int) async throws { filled.append((recordId, painAfter)) }
    func save(entity: PainRecord) async throws { saved.append(entity) }
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [PainRecord] { [] }
    func findByPatientId(_ patientId: UUID) async throws -> [PainRecord] { [] }
    func findById(_ id: UUID) async throws -> PainRecord? { nil }
    func deleteById(_ id: UUID) async throws {}
}
