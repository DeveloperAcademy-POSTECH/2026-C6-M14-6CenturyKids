//
//  LocalNotificationAdapter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation
import UserNotifications

/// 서버 없이 이 기기에서만 보내는 알림
enum LocalNotificationAdapter {
    /// 알림을 눌렀을 때 열 주소(todoc://...)를 담는 키
    static let deepLinkKey = "deepLink"
    private static let painReminderHours = [8, 12, 18]
    private static let painAfterReminderID = "painAfterReminder"

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

    /// 먹기 전 통증을 저장하면 먹은 뒤 통증을 기록할 시각에 한 번 알린다.
    /// 기다리는 기록은 하나뿐이라 같은 식별자로 넣어, 새 기록을 저장하면 이전 예약이 바뀐다.
    static func schedulePainAfterReminder(at date: Date) async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
            let content = UNMutableNotificationContent()
            content.body = "약을 드신 지 1시간이 지났어요. 복용 후 통증을 기록해 주세요."
            content.sound = .default
            content.userInfo = [deepLinkKey: "todoc://record/pain"]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
            try await center.add(UNNotificationRequest(identifier: painAfterReminderID, content: content, trigger: trigger))
        } catch {
            print("복용 후 통증 알림 예약 실패: ", error)
        }
    }

    /// 먹은 뒤 통증을 기록하면 남은 알림을 지운다.
    static func cancelPainAfterReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [painAfterReminderID])
        center.removeDeliveredNotifications(withIdentifiers: [painAfterReminderID])
    }

    /// 로그아웃하면 예약해 둔 통증 기록 알림을 지운다.
    static func cancelPainReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: painReminderHours.map { "painReminder.\($0)" } + [painAfterReminderID])
    }
}
