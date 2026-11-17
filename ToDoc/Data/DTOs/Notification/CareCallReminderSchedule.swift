import Foundation

/// Both the local notification and ActivityKit use this same wall-clock schedule.
struct CareCallReminderSchedule {
    let components: DateComponents

    init?(settings: NotificationSettingsDTO) {
        let parts = settings.notificationTime.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let hour = Int(parts[0]), (0..<24).contains(hour),
              let minute = Int(parts[1]), (0..<60).contains(minute),
              let seconds = Double(parts[2]), seconds == 0 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: settings.timezone) ?? .current
        var components = DateComponents(hour: hour, minute: minute, second: 0)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        self.components = components
    }

    func nextDate(after now: Date) -> Date? {
        components.calendar?.nextDate(after: now, matching: components,
                                      matchingPolicy: .nextTime, repeatedTimePolicy: .first)
    }
}

struct CareCallReminderStatus {
    var nextLiveActivityDate: Date?
    var warningMessage: String?
}
