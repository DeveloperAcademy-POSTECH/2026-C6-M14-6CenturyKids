import Foundation
import UserNotifications

/// Replenishes one scheduled activity whenever the app is used. Daily notifications
/// continue independently; ActivityKit has no repeating schedule API.
@MainActor
final class CareCallReminderScheduler {
    private let repository: any NotificationSettingsRepository
    private let userId: UUID
    private let coordinator = SingleLiveActivityCoordinator()

    init(repository: any NotificationSettingsRepository, userId: UUID) {
        self.repository = repository
        self.userId = userId
    }

    func synchronize() async -> CareCallReminderStatus {
        var result = CareCallReminderStatus()
        do {
            try await coordinator.run { [self] in
                // Read inside the queue so a foreground refresh cannot restore an old time after Save.
                guard let settings = try await repository.fetch(userId: userId) else { return }
                var warnings: [String] = []
                if settings.isEnabled { await LocalNotificationAdapter.requestAuthorization() }
                do {
                    try await LocalNotificationAdapter.scheduleCareCallReminder(settings)
                    if settings.isEnabled,
                       await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied {
                        warnings.append("iPhone 설정에서 속닥의 알림을 켜 주세요.")
                    }
                } catch {
                    warnings.append("일반 알림을 예약하지 못했어요. 다시 시도해 주세요.")
                }
                do {
                    if settings.isEnabled {
                        guard let next = CareCallReminderSchedule(settings: settings)?.nextDate(after: .now) else {
                            result.warningMessage = "알림 시간을 다시 선택해 주세요."
                            return
                        }
                        try await LiveActivityService.scheduleSymptomLiveActivity(at: next)
                        result.nextLiveActivityDate = next
                    } else {
                        await LiveActivityService.cancelSymptomLiveActivities()
                    }
                } catch {
                    warnings.append("증상 실시간 현황을 예약하지 못했어요. \(error.localizedDescription)")
                }
                result.warningMessage = warnings.isEmpty ? nil : warnings.joined(separator: "\n")
            }
        } catch {
            result.warningMessage = "저장된 알림 시간을 불러오지 못했어요. 다시 시도해 주세요."
        }
        return result
    }
}
