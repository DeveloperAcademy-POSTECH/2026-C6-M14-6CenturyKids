import ActivityKit
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
    static let skippedWait: TimeInterval = 2

    @ObservationIgnored private let patientId: UUID
    @ObservationIgnored private let pain: any PainRepository
    @ObservationIgnored private let symptoms: any SymptomRepository
    @ObservationIgnored private let previsits: any PrevisitRepository
    @ObservationIgnored private let pendingCalls: any PendingCareCallRepository
    @ObservationIgnored private let schedulePainAfterReminder: (Date) async -> Void
    @ObservationIgnored private let cancelPainAfterReminder: () -> Void
    /// 바꾼 뒤 화면들이 다시 불러오게 한다
    @ObservationIgnored var onChanged: () async -> Void = {}

    init(patientId: UUID, pain: any PainRepository, symptoms: any SymptomRepository,
         previsits: any PrevisitRepository, pendingCalls: any PendingCareCallRepository,
         schedulePainAfterReminder: @escaping (Date) async -> Void, cancelPainAfterReminder: @escaping () -> Void) {
        self.patientId = patientId
        self.pain = pain
        self.symptoms = symptoms
        self.previsits = previsits
        self.pendingCalls = pendingCalls
        self.schedulePainAfterReminder = schedulePainAfterReminder
        self.cancelPainAfterReminder = cancelPainAfterReminder
    }

    /// 기다리는 통증 기록의 시각을 앞당겨, available부터 복용 후 통증을 기록할 수 있게 한다.
    /// 서버가 기록 시각으로 1시간을 확인하므로 같은 id·부위·복용 전 점수로 시각만 바꿔 다시 저장한다.
    func skipPainWait(until available: Date) async throws {
        guard let pending = try await pain.findLatestByPatientId(patientId), pending.painAfter == nil else {
            throw Failure.nothing("복용 후 통증을 기다리는 기록이 없어요.")
        }
        guard pending.recordedDate.addingTimeInterval(PainRecordViewModel.afterDelay) > available else { return }
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

    /// 오늘 통증 기록을 지워 처음부터 다시 기록할 수 있게 한다.
    func resetTodayPain(now: Date = .now) async throws -> String {
        // 통증 저장소는 끝 날을 포함하므로 오늘 하루만 찾는다
        let records = try await pain.findByPatientIdAndDate(patientId: patientId, from: now, to: now)
        guard !records.isEmpty else { throw Failure.nothing("오늘 통증 기록이 없어요.") }
        for record in records {
            try await pain.deleteById(record.id)
            await LiveActivityService.endPainLiveActivity(recordID: record.id)
        }
        // 복용 후 통증을 기다리던 기록을 지웠으면 그 1시간 알림도 남기지 않는다
        if records.contains(where: { $0.painAfter == nil }) { cancelPainAfterReminder() }
        guard try await pain.findByPatientIdAndDate(patientId: patientId, from: now, to: now).isEmpty else {
            throw Failure.notApplied("통증 기록")
        }
        await onChanged()
        return "오늘 통증 기록을 지웠어요."
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

    /// 시연 한 판을 처음으로 되돌린다: 오늘 증상·통증·진료 전 기록을 지우고 증상 실시간 현황을 띄운다.
    /// 지울 기록이 없는 것은 실패로 보지 않는다
    func restartDemo() async throws {
        func reset(_ run: () async throws -> String) async throws {
            do { _ = try await run() } catch Failure.nothing {}
        }
        try await reset { try await resetTodaySymptoms() }
        try await reset { try await resetTodayPain() }
        try await reset { try await resetTodayPrevisit() }
        try await LiveActivityService.startLocalSymptomLiveActivity()
    }

    /// 10/16~11/19 증상·통증·진료 전 기록을 지우고 목데이터로 다시 채운다
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
        func oldPrevisits() async throws -> [PrevisitRecord] {
            try await previsits.findByPatientId(patientId).filter { $0.submittedAt >= start && $0.submittedAt < end }
        }
        for record in try await oldSymptoms() { try await symptoms.deleteById(record.id) }
        for record in try await oldPain() {
            try await pain.deleteById(record.id)
            await LiveActivityService.endPainLiveActivity(recordID: record.id)
        }
        // 지운 기록을 기다리던 1시간 알림이 남지 않게 (목데이터 통증은 모두 복용 후까지 기록돼 있다). 라이브 액티비티는 위에서 기록마다 끈다
        cancelPainAfterReminder()
        for record in try await oldPrevisits() { try await previsits.deleteById(record.id) }
        guard try await oldSymptoms().isEmpty, try await oldPain().isEmpty, try await oldPrevisits().isEmpty else {
            throw Failure.notApplied("기존 기록 삭제")
        }

        for record in data.symptoms { try await symptoms.save(entity: record) }
        for record in data.pain { try await pain.save(entity: record) }
        for record in data.previsits { try await previsits.save(entity: record) }
        await onChanged()
        return "목데이터를 채웠어요. 증상 \(data.symptoms.count)일, 통증 \(data.pain.count)건, 진료 전 기록 \(data.previsits.count)건이에요."
    }

    /// 이 환자의 모든 증상·통증·진료 전 기록과 폰에 남은 저장 대기 통화를 지운다 (날짜 상관없이)
    func clearAllRecords() async throws -> String {
        for call in try pendingCalls.findAll(patientId: patientId) { try pendingCalls.delete(id: call.id, patientId: patientId) }
        for record in try await symptoms.findByPatientId(patientId) { try await symptoms.deleteById(record.id) }
        for record in try await pain.findByPatientId(patientId) {
            try await pain.deleteById(record.id)
            await LiveActivityService.endPainLiveActivity(recordID: record.id)
        }
        cancelPainAfterReminder()
        for record in try await previsits.findByPatientId(patientId) { try await previsits.deleteById(record.id) }
        await LiveActivityService.endAllLiveActivities()
        guard try await symptoms.findByPatientId(patientId).isEmpty, try await pain.findByPatientId(patientId).isEmpty,
              try await previsits.findByPatientId(patientId).isEmpty else {
            throw Failure.notApplied("기록")
        }
        await onChanged()
        return "모든 기록을 지웠어요."
    }
}
