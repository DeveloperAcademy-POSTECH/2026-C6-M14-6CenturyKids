import Foundation
import Observation

@MainActor
@Observable
final class NotificationSettingsViewModel {
    @ObservationIgnored private let userId: UUID
    @ObservationIgnored private let notificationSettingsRepository: any NotificationSettingsRepository
    @ObservationIgnored private let synchronizeReminders: () async -> CareCallReminderStatus
    @ObservationIgnored private var loadedSettings: NotificationSettingsDTO?
    /// 서버가 알림을 보내는 저녁 시간대 (기본)
    static let eveningMinutes = (20 * 60)..<(24 * 60)
    /// 기기에서 직접 예약할 때는 하루 어느 시각이든 고를 수 있다
    static let allDayMinutes = 0..<(24 * 60)
    @ObservationIgnored let allowedMinutes: Range<Int>

    private(set) var savedTime = DateComponents(hour: 20, minute: 0)
    private(set) var selectedTime = DateComponents(hour: 20, minute: 0)
    private(set) var hasStoredTime = false
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var errorMessage: String?
    private(set) var reminderStatus = CareCallReminderStatus()
    private(set) var isScheduling = false

    var savedTimeString: String {
        String(format: "%02d:%02d:00", savedTime.hour ?? 20, savedTime.minute ?? 0)
    }

    var hasChanges: Bool { selectedTime != savedTime }
    var canSave: Bool {
        hasLoaded && !isLoading && !isSaving && !isScheduling
            && (!hasStoredTime || hasChanges || reminderStatus.warningMessage != nil)
    }

    init(
        userId: UUID,
        notificationSettingsRepository: any NotificationSettingsRepository,
        allowedMinutes: Range<Int> = NotificationSettingsViewModel.eveningMinutes,
        synchronizeReminders: @escaping () async -> CareCallReminderStatus = { .init() }
    ) {
        self.allowedMinutes = allowedMinutes
        self.userId = userId
        self.notificationSettingsRepository = notificationSettingsRepository
        self.synchronizeReminders = synchronizeReminders
    }

    func loadTime() async {
        guard !isLoading, !isSaving else { return }

        isLoading = true
        hasLoaded = false
        didSave = false
        errorMessage = nil
        defer { isLoading = false }

        do {
            let settings = try await notificationSettingsRepository.fetch(
                userId: userId
            )
            try Task.checkCancellation()

            loadedSettings = settings

            let defaultTime = DateComponents(hour: 20, minute: 0)

            guard let settings else {
                savedTime = defaultTime
                selectedTime = defaultTime
                hasStoredTime = false
                hasLoaded = true
                return
            }

            guard let time = parseTime(settings.notificationTime) else {
                savedTime = defaultTime
                selectedTime = defaultTime
                hasStoredTime = false
                hasLoaded = true
                errorMessage = "저장된 알림 시간을 읽을 수 없어요. 다시 설정해 주세요."
                return
            }

            savedTime = time
            selectedTime = time
            hasStoredTime = true
            hasLoaded = true
            await updateReminderStatus()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "알림 시간을 불러오지 못했어요. 다시 시도해 주세요."
        }
    }

    func selectTime(_ time: DateComponents) {
        guard hasLoaded, !isLoading, !isSaving else { return }

        guard let hour = time.hour, (0..<24).contains(hour),
              let minute = time.minute, (0..<60).contains(minute),
              allowedMinutes.contains(hour * 60 + minute) else {
            errorMessage = "알림 시간을 다시 선택해 주세요."
            return
        }

        selectedTime = DateComponents(hour: hour, minute: minute)
        didSave = false
        errorMessage = nil
    }

    func saveTime() async {
        guard canSave,
              let hour = selectedTime.hour,
              let minute = selectedTime.minute,
              allowedMinutes.contains(hour * 60 + minute) else {
            return
        }

        let timeToSave = DateComponents(hour: hour, minute: minute)

        let settings = NotificationSettingsDTO(
            userId: userId,
            notificationTime: String(format: "%02d:%02d:00", hour, minute),
            timezone: loadedSettings?.timezone ?? TimeZone.current.identifier,
            isEnabled: loadedSettings?.isEnabled ?? true
        )

        isSaving = true
        didSave = false
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await notificationSettingsRepository.save(settings: settings)

            loadedSettings = settings
            savedTime = timeToSave
            hasStoredTime = true
            didSave = true
            await updateReminderStatus()
        } catch {
            errorMessage = "알림 시간의 저장 결과를 확인하지 못했어요. 다시 시도해 주세요."
        }
    }

    /// 앱이 앞으로 올라올 때 부른다 (iPhone 설정에서 권한을 바꾸고 돌아온 경우 포함).
    func refreshSchedule() async {
        guard !isLoading, !isSaving, !isScheduling else { return }
        await updateReminderStatus()
    }

    private func updateReminderStatus() async {
        isScheduling = true
        defer { isScheduling = false }
        reminderStatus = await synchronizeReminders()
    }

    private func parseTime(_ value: String) -> DateComponents? {
        let parts = value.split(
            separator: ":",
            omittingEmptySubsequences: false
        )

        guard parts.count == 3,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              let second = Double(parts[2]),
              (0..<24).contains(hour),
              (0..<60).contains(minute),
              second == 0,
              allowedMinutes.contains(hour * 60 + minute) else {
            return nil
        }

        return DateComponents(hour: hour, minute: minute)
    }
}
