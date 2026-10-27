//
//  LocalNotificationAdapter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import UserNotifications

/// 서버 없이 이 기기에서만 보내는 알림
enum LocalNotificationAdapter {
    private static let painReminderHours = [8, 12, 18]

    /// 돌발성 통증 기록 알림을 매일 8·12·18시에 예약한다.
    /// 같은 식별자로 다시 넣으면 기존 예약이 바뀌므로 앱을 열 때마다 불러도 쌓이지 않는다.
    static func schedulePainReminders() async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
            for hour in painReminderHours {
                let content = UNMutableNotificationContent()
                content.body = "돌발성 통증이 생겼다면 앱에 접속해서 기록해주세요"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
                try await center.add(UNNotificationRequest(identifier: "painReminder.\(hour)", content: content, trigger: trigger))
            }
        } catch {
            print("통증 기록 알림 예약 실패: ", error)
        }
    }

    /// 로그아웃하면 예약해 둔 통증 기록 알림을 지운다.
    static func cancelPainReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: painReminderHours.map { "painReminder.\($0)" })
    }
}
