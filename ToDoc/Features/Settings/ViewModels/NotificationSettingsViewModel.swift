import Foundation
import Observation

@MainActor
@Observable
final class NotificationSettingsViewModel {
    @ObservationIgnored private let userId: UUID
    @ObservationIgnored private let notificationSettingsRepository: any NotificationSettingsRepository
    static let allowedMinutes = (20 * 60)..<(24 * 60)

    private(set) var savedTime = DateComponents(hour: 20, minute: 0)
    private(set) var selectedTime = DateComponents(hour: 20, minute: 0)
    private(set) var hasStoredTime = false
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var errorMessage: String?

    var savedTimeString: String {
        String(format: "%02d:%02d:00", savedTime.hour ?? 20, savedTime.minute ?? 0)
    }

    var hasChanges: Bool { selectedTime != savedTime }
    var canSave: Bool {
        hasLoaded && !isLoading && !isSaving && (!hasStoredTime || hasChanges)
    }

    init(
        userId: UUID,
        notificationSettingsRepository: any NotificationSettingsRepository
    ) {
        self.userId = userId
        self.notificationSettingsRepository = notificationSettingsRepository
    }

    func loadTime() {
        guard !isLoading, !isSaving else { return }

        isLoading = true
        hasLoaded = false
        didSave = false
        errorMessage = nil
        defer { isLoading = false }

        let defaultTime = DateComponents(hour: 20, minute: 0)

        guard let stored = defaults.object(forKey: Self.timeKey) else {
            savedTime = defaultTime
            selectedTime = defaultTime
            hasStoredTime = false
            hasLoaded = true
            return
        }

        guard let minutes = stored as? Int,
              (0..<1440).contains(minutes) else {
            savedTime = defaultTime
            selectedTime = defaultTime
            hasStoredTime = false
            hasLoaded = true
            errorMessage = "저장된 알림 시간을 읽을 수 없어요. 다시 설정해 주세요."
            return
        }

        guard Self.allowedMinutes.contains(minutes) else {
            savedTime = defaultTime
            selectedTime = defaultTime
            hasStoredTime = false
            hasLoaded = true
            return
        }

        let time = DateComponents(hour: minutes / 60, minute: minutes % 60)
        savedTime = time
        selectedTime = time
        hasStoredTime = true
        hasLoaded = true
    }

    func selectTime(_ time: DateComponents) {
        guard hasLoaded, !isLoading, !isSaving else { return }

        guard let hour = time.hour, (0..<24).contains(hour),
              let minute = time.minute, (0..<60).contains(minute),
              Self.allowedMinutes.contains(hour * 60 + minute) else {
            errorMessage = "알림 시간을 다시 선택해 주세요."
            return
        }

        selectedTime = DateComponents(hour: hour, minute: minute)
        didSave = false
        errorMessage = nil
    }

    func saveTime() {
        guard canSave,
              let hour = selectedTime.hour,
              let minute = selectedTime.minute else { return }

        isSaving = true
        didSave = false
        errorMessage = nil
        defer { isSaving = false }

        let minutesSinceMidnight = hour * 60 + minute
        defaults.set(minutesSinceMidnight, forKey: Self.timeKey)

        savedTime = selectedTime
        hasStoredTime = true
        didSave = true
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
              Self.allowedMinutes.contains(hour * 60 + minute) else {
            return nil
        }

        return DateComponents(hour: hour, minute: minute)
    }
}
