import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// Figma 1:5324. 알림을 오늘 / 최근 7일 / 이전 30일로 나누고 최근 알림부터 보여 줍니다.
extension NotificationSectionData {
    static func sections(_ notifications: [AppNotification], now: Date, calendar: Calendar) -> [NotificationSectionData] {
        let today = calendar.startOfDay(for: now)
        let groups = Dictionary(grouping: notifications.sorted { $0.createdAt > $1.createdAt }) { notification in
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: notification.createdAt), to: today).day ?? 0
            return days <= 0 ? 0 : days < 7 ? 1 : 2
        }
        return [(0, "오늘"), (1, "최근 7일"), (2, "이전 30일")].compactMap { index, title in
            guard let items = groups[index] else { return nil }
            return NotificationSectionData(
                id: title, title: title, hasUnread: items.contains { $0.readAt == nil },
                items: items.map {
                    NotificationRowData(id: $0.id, title: $0.title, body: $0.body,
                                        timeLabel: timeLabel($0.createdAt, now: now), isRead: $0.readAt != nil)
                }
            )
        }
    }

    /// 1분 안은 '방금 전', 하루 안은 분·시간, 그 뒤는 지난 날수
    static func timeLabel(_ date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "방금 전"
        case ..<3600: return "\(seconds / 60)분 전"
        case ..<86400: return "\(seconds / 3600)시간 전"
        default: return "\(seconds / 86400)일 전"
        }
    }
}
