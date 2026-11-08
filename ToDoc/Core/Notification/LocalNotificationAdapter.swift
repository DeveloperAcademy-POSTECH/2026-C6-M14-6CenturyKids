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
    /// 권한은 묻지 않는다: 허용 전에 넣은 예약도 남아 있다가 허용하면 뜬다 (권한은 위치 권한 다음에 한 번 묻는다).
    static func schedulePainReminders() async {
        let center = UNUserNotificationCenter.current()
        do {
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
            let content = UNMutableNotificationContent()
            content.title = "통증을 다시 기록할 시간이에요"
            content.body = "약 먹고 1시간이 지났어요. 지금 통증은 어떤가요?"
            content.sound = .default
            content.userInfo = [deepLinkKey: "todoc://record/pain"]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
            try await center.add(UNNotificationRequest(identifier: painAfterReminderID, content: content, trigger: trigger))
        } catch {
            print("복용 후 통증 알림 예약 실패: ", error)
        }
    }

    /// 기기 설정에서 알림을 끄면 false. 아직 묻지 않았으면 위치 권한 뒤에 물으므로 켜진 것으로 본다.
    static func isPainReminderAllowed() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus != .denied
    }

    /// 먹은 뒤 통증을 기록하면 남은 알림을 지운다.
    static func cancelPainAfterReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [painAfterReminderID])
        center.removeDeliveredNotifications(withIdentifiers: [painAfterReminderID])
    }

    /// 알림 권한은 환자 화면에 들어와 위치 권한 창이 끝난 뒤 한 번만 묻는다 (LocationPermissionRequester).
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// 앱 알림 목록에 남긴 알림을 지금 띄운다. 누르면 deepLink 화면을 연다.
    static func post(_ notification: AppNotification, deepLink: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = [deepLinkKey: deepLink]
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: notification.id.uuidString, content: content, trigger: nil)
        )
    }

    /// 로그아웃하면 예약해 둔 통증 기록 알림을 지운다.
    static func cancelPainReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: painReminderHours.map { "painReminder.\($0)" } + [painAfterReminderID])
    }
}
