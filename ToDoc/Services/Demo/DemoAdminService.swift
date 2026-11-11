import Foundation
import Observation

#if canImport(ToDocDomain)
import ToDocDomain
#endif

/// 시연용 관리자 기능. 서버가 권한으로 막으면 오류 없이 아무것도 안 바뀔 수 있어, 바꾼 뒤 다시 조회해 확인한다.
@MainActor @Observable
final class DemoAdminService {
    enum Failure: LocalizedError {
        case nothing(String)
        case notApplied(String)

        var errorDescription: String? {
            switch self {
            case .nothing(let message): message
            case .notApplied(let what): "\(what)을(를) 서버가 바꾸지 않았어요. 데이터베이스 권한을 확인해 주세요."
            }
        }
    }

    /// 스킵하면 복용 후 통증까지 남는 시간
    static let skippedWait: TimeInterval = 20

    @ObservationIgnored private let patientId: UUID
    @ObservationIgnored private let pain: any PainRepository
    @ObservationIgnored private let symptoms: any SymptomRepository
    @ObservationIgnored private let previsits: any PrevisitRepository
    @ObservationIgnored private let pendingCalls: any PendingCareCallRepository
    @ObservationIgnored private let schedulePainAfterReminder: (Date) async -> Void
    /// 바꾼 뒤 화면들이 다시 불러오게 한다
    @ObservationIgnored var onChanged: () async -> Void = {}

    init(patientId: UUID, pain: any PainRepository, symptoms: any SymptomRepository,
         previsits: any PrevisitRepository, pendingCalls: any PendingCareCallRepository,
         schedulePainAfterReminder: @escaping (Date) async -> Void) {
        self.patientId = patientId
        self.pain = pain
        self.symptoms = symptoms
        self.previsits = previsits
        self.pendingCalls = pendingCalls
        self.schedulePainAfterReminder = schedulePainAfterReminder
    }

    /// 기다리는 통증 기록의 시각을 앞당겨, 20초 뒤에 복용 후 통증을 기록할 수 있게 한다.
    /// 서버가 기록 시각으로 1시간을 확인하므로 같은 id·부위·복용 전 점수로 시각만 바꿔 다시 저장한다.
    func skipPainWait(now: Date = .now) async throws -> String {
        guard let pending = try await pain.findLatestByPatientId(patientId), pending.painAfter == nil else {
            throw Failure.nothing("복용 후 통증을 기다리는 기록이 없어요.")
        }
        let available = now.addingTimeInterval(Self.skippedWait)
        guard pending.recordedDate.addingTimeInterval(PainRecordViewModel.afterDelay) > available else {
            return "이미 복용 후 통증을 기록할 수 있어요."
        }
        let shifted = try PainRecord(id: pending.id, patientId: pending.patientId,
                                     recordedDate: available.addingTimeInterval(-PainRecordViewModel.afterDelay),
                                     location: pending.location, painBefore: pending.painBefore, painAfter: nil)
        try await pain.deleteById(pending.id)
        guard try await pain.findById(pending.id) == nil else { throw Failure.notApplied("통증 기록") }
        do {
            try await pain.save(entity: shifted)
        } catch {
            // 지운 기록을 잃지 않게 원래 시각으로 되돌려 둔다. 되돌리기도 실패하면 기록이 없어졌다고 알린다
            do {
                try await pain.save(entity: pending)
            } catch {
                throw Failure.nothing("통증 기록을 다시 저장하지 못해 기다리던 기록이 지워졌어요. 먹기 전 통증을 다시 기록해 주세요.")
            }
            throw error
        }
        await schedulePainAfterReminder(available)
        await onChanged()
        return "20초 뒤에 복용 후 통증을 기록할 수 있어요."
    }

    /// 오늘 증상 기록(서버·폰에 남은 저장 대기 통화)을 지워 처음부터 다시 기록할 수 있게 한다.
    func resetTodaySymptoms(now: Date = .now) async throws -> String {
        let calendar = RecordDetailViewModel.calendar
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { throw DateConversionError.dayAddingError }

        let leftCalls = try pendingCalls.findAll(patientId: patientId)
            .filter { calendar.isDate($0.record.recordedDate, inSameDayAs: now) }
        for call in leftCalls { try pendingCalls.delete(id: call.id, patientId: patientId) }

        let records = try await symptoms.findByPatientIdAndDate(patientId: patientId, from: start, to: end)
        guard !records.isEmpty || !leftCalls.isEmpty else { throw Failure.nothing("오늘 증상 기록이 없어요.") }
        for record in records { try await symptoms.deleteById(record.id) }
        guard try await symptoms.findByPatientIdAndDate(patientId: patientId, from: start, to: end).isEmpty else {
            throw Failure.notApplied("증상 기록")
        }
        await onChanged()
        return "오늘 증상 기록을 지웠어요."
    }

    /// 오늘 보낸 진료 전 기록을 지워 다시 작성할 수 있게 한다.
    func resetTodayPrevisit(now: Date = .now) async throws -> String {
        guard let record = try await previsits.findByPatientIdAndDate(patientId: patientId, date: now) else {
            throw Failure.nothing("오늘 보낸 진료 전 기록이 없어요.")
        }
        try await previsits.deleteById(record.id)
        guard try await previsits.findByPatientIdAndDate(patientId: patientId, date: now) == nil else {
            throw Failure.notApplied("진료 전 기록")
        }
        await onChanged()
        return "오늘 진료 전 기록을 지웠어요."
    }

    /// 10/16~11/19 증상·통증 기록을 지우고 목데이터로 다시 채운다. 진료 전 기록 2건은 고정 id로 덮어쓴다
    func seedMockData() async throws -> String {
        let data = try DemoMockData(patientId: patientId)
        let (start, end) = DemoMockData.range
        let lastDay = DemoMockData.calendar.date(byAdding: .day, value: -1, to: end)!
        // 증상 저장소는 끝 날 미포함, 통증 저장소는 끝 날 포함
        func oldSymptoms() async throws -> [SymptomRecord] {
            try await symptoms.findByPatientIdAndDate(patientId: patientId, from: start, to: end)
        }
        func oldPain() async throws -> [PainRecord] {
            try await pain.findByPatientIdAndDate(patientId: patientId, from: start, to: lastDay)
        }
        for record in try await oldSymptoms() { try await symptoms.deleteById(record.id) }
        for record in try await oldPain() { try await pain.deleteById(record.id) }
        guard try await oldSymptoms().isEmpty, try await oldPain().isEmpty else { throw Failure.notApplied("기존 기록 삭제") }

        for record in data.symptoms { try await symptoms.save(entity: record) }
        for record in data.pain { try await pain.save(entity: record) }
        for record in data.previsits { try await previsits.save(entity: record) }
        await onChanged()
        return "목데이터를 채웠어요. 증상 \(data.symptoms.count)일, 통증 \(data.pain.count)건, 진료 전 기록 \(data.previsits.count)건이에요."
    }
}
