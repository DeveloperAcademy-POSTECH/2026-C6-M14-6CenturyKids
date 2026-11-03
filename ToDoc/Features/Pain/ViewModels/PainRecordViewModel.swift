//
//  PainRecordViewModel.swift
//  ToDoc
//
//  Created by 허지우 on 10/17/26.
//

#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation
import Observation

/// 통증 기록은 두 번에 나눠 저장합니다.
/// 먹기 전 통증을 먼저 저장하고, 1시간 뒤 같은 기록에 먹은 뒤 통증을 채웁니다.
@MainActor
@Observable
final class PainRecordViewModel {
    enum ConnectionState {
        case loading
        case ready
        case signedOut
        case patientUnavailable
        case failed
    }

    private enum PatientSource {
        case repositories(auth: any AuthRepository, patient: any PatientRepository)
        case knownPatient(UUID)
    }

    enum SaveError: Error {
        case patientUnavailable
        case missingScore
        case noPendingRecord
        case tooEarly
        case alreadySaving
    }

    /// 먹기 전 통증을 저장하고 이만큼 지나야 먹은 뒤 통증을 기록할 수 있습니다.
    static let afterDelay: TimeInterval = 60 * 60

    @ObservationIgnored private let patientSource: PatientSource
    /// 먹은 뒤 통증을 기록할 시각에 한 번 알리고, 기록하면 지웁니다. 기기 알림은 컨테이너가 넣습니다.
    @ObservationIgnored private let scheduleAfterReminder: (Date) async -> Void
    @ObservationIgnored private let cancelAfterReminder: () -> Void
    /// 기기 알림이 꺼져 있으면 false입니다. 기기 설정은 컨테이너가 넣습니다.
    @ObservationIgnored private let checkRemindersAllowed: () async -> Bool
    private var patientId: UUID?
    private let painRepository: any PainRepository
    private var isLoading = false
    private(set) var connectionState: ConnectionState = .loading
    /// 가장 최근 기록이 먹은 뒤 통증을 기다리고 있으면 그 기록입니다.
    /// 새 기록을 저장하면 그 기록으로 바뀌어, 이전 기록은 먹기 전 점수만 남습니다.
    private(set) var pendingRecord: PainRecord?
    private(set) var selectedLocations: [BodyLocation] = []
    private(set) var painBefore: Int?
    private(set) var painAfter: Int?
    private(set) var isSaving = false
    /// 꺼져 있으면 타이머 화면이 1시간 뒤에 알려 줄 수 없다고 안내합니다.
    private(set) var remindersAllowed = true

    /// 이 시각부터 이어서 기록할 수 있습니다.
    var afterAvailableDate: Date? {
        pendingRecord.map { $0.recordedDate.addingTimeInterval(Self.afterDelay) }
    }

    init(
        authRepository: any AuthRepository,
        patientRepository: any PatientRepository,
        painRepository: any PainRepository,
        scheduleAfterReminder: @escaping (Date) async -> Void = { _ in },
        cancelAfterReminder: @escaping () -> Void = {},
        checkRemindersAllowed: @escaping () async -> Bool = { true }
    ) {
        patientSource = .repositories(auth: authRepository, patient: patientRepository)
        self.painRepository = painRepository
        self.scheduleAfterReminder = scheduleAfterReminder
        self.cancelAfterReminder = cancelAfterReminder
        self.checkRemindersAllowed = checkRemindersAllowed
    }

    #if DEBUG
    init(patientId: UUID, painRepository: any PainRepository,
         scheduleAfterReminder: @escaping (Date) async -> Void = { _ in },
         cancelAfterReminder: @escaping () -> Void = {},
         checkRemindersAllowed: @escaping () async -> Bool = { true }) {
        patientSource = .knownPatient(patientId)
        self.patientId = patientId
        self.painRepository = painRepository
        self.scheduleAfterReminder = scheduleAfterReminder
        self.cancelAfterReminder = cancelAfterReminder
        self.checkRemindersAllowed = checkRemindersAllowed
    }
    #endif

    /// 화면에 들어올 때마다 불러 이어서 기록할 기록이 있는지 다시 확인합니다.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        connectionState = .loading
        defer { isLoading = false }

        do {
            guard let patientId = try await resolvePatientId() else {
                connectionState = .patientUnavailable
                return
            }
            let latest = try await painRepository.findLatestByPatientId(patientId)
            guard !Task.isCancelled else { return }

            pendingRecord = latest?.painAfter == nil ? latest : nil
            startNewRecord()
            connectionState = .ready
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            if case let .repositories(authRepository, _) = patientSource, !authRepository.isSignedIn() {
                connectionState = .signedOut
            } else {
                connectionState = .failed
            }
        }
    }

    func selectLocation(_ location: BodyLocation) {
        guard !selectedLocations.contains(location) else { return }
        selectedLocations.append(location)
    }

    func removeLocation(_ location: BodyLocation) {
        selectedLocations.removeAll { $0 == location }
    }

    /// 몸 그림에서 누른 부위를 고르거나, 이미 골랐으면 뺍니다.
    func toggleLocation(_ location: BodyLocation) {
        if selectedLocations.contains(location) {
            removeLocation(location)
        } else {
            selectLocation(location)
        }
    }

    func removeAllLocations() {
        selectedLocations = []
    }

    func setBeforeScore(_ score: Int) {
        painBefore = score
    }

    func setAfterScore(_ score: Int) {
        painAfter = score
    }

    /// 입력을 비웁니다. 점수는 환자가 직접 고르기 전까지 비워 두어 다음·저장을 막습니다 (게이지의 10·0은 화면 표시일 뿐입니다).
    func startNewRecord() {
        selectedLocations = []
        painBefore = nil
        painAfter = nil
    }

    /// 먹기 전 통증을 저장하고 1시간 뒤 알림을 예약합니다. 저장한 시각이 기록 시각입니다.
    func saveBeforeRecord(at date: Date = Date()) async throws -> PainRecord {
        guard !isSaving else { throw SaveError.alreadySaving }
        guard let patientId else { throw SaveError.patientUnavailable }
        guard let painBefore else { throw SaveError.missingScore }

        let record = try PainRecord(
            id: UUID(),
            patientId: patientId,
            recordedDate: date,
            location: selectedLocations,
            painBefore: painBefore,
            painAfter: nil
        )

        isSaving = true
        defer { isSaving = false }
        try await painRepository.save(entity: record)

        pendingRecord = record
        await scheduleAfterReminder(date.addingTimeInterval(Self.afterDelay))
        return record
    }

    /// 기다리던 기록에 먹은 뒤 통증을 채우고 남은 알림을 지웁니다. 1시간이 지나기 전에는 저장하지 않습니다.
    func saveAfterRecord(at date: Date = Date()) async throws -> PainRecord {
        guard !isSaving else { throw SaveError.alreadySaving }
        guard let pending = pendingRecord else { throw SaveError.noPendingRecord }
        guard let availableDate = afterAvailableDate, date >= availableDate else { throw SaveError.tooEarly }
        guard let painAfter else { throw SaveError.missingScore }

        let record = try PainRecord(
            id: pending.id,
            patientId: pending.patientId,
            recordedDate: pending.recordedDate,
            location: pending.location,
            painBefore: pending.painBefore,
            painAfter: painAfter
        )

        isSaving = true
        defer { isSaving = false }
        try await painRepository.savePainAfter(recordId: pending.id, painAfter: painAfter)

        pendingRecord = nil
        cancelAfterReminder()
        return record
    }

    /// 타이머 화면에 들어오거나 설정에서 돌아오면 알림 권한을 다시 확인합니다.
    /// 다시 켰으면 남은 알림을 예약합니다 (같은 식별자라 이미 있으면 바뀝니다).
    func refreshReminderPermission(now: Date = Date()) async {
        remindersAllowed = await checkRemindersAllowed()
        if remindersAllowed, let date = afterAvailableDate, date > now {
            await scheduleAfterReminder(date)
        }
    }

    private func resolvePatientId() async throws -> UUID? {
        if let patientId { return patientId }
        guard case let .repositories(authRepository, patientRepository) = patientSource else { return nil }

        let userId = try await authRepository.getCurrentUserId()
        try Task.checkCancellation()
        let patient = try await patientRepository.findById(userId)
        try Task.checkCancellation()

        patientId = patient?.user.id
        return patientId
    }
}
