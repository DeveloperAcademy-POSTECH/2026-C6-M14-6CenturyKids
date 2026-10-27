//
//  LocalNotificationRouter.swift
//  ToDoc
//
//  Created by seokho on 10/27/26.
//

import UserNotifications

/// 서버 없이 폰이 직접 띄우는 알림. 알림을 누르면 `onOpen`으로 알림 종류를 넘긴다.
/// 앱이 꺼진 상태에서 눌렀으면 화면이 준비되어 `onOpen`을 연결할 때까지 들고 있는다
final class LocalNotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private nonisolated static let typeKey = "type"

    private var pendingOpen: NotificationType?
    var onOpen: ((NotificationType) -> Void)? {
        didSet {
            guard let onOpen, let pendingOpen else { return }
            self.pendingOpen = nil
            onOpen(pendingOpen)
        }
    }

    /// 앱이 켜지자마자 불러야 꺼진 상태에서 누른 알림도 받는다
    func becomeDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func post(_ notification: AppNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = [Self.typeKey: notification.type.rawValue]
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: notification.id.uuidString, content: content, trigger: nil)
        )
    }

    // 두 메서드는 async 버전을 쓰지 않는다: async 버전은 끝났다는 신호를 메인 스레드 밖에서 보내 UIKit이 앱을 종료시킨다

    /// 앱이 백그라운드로 넘어가는 순간에 띄운 알림도 버려지지 않게 보여 준다 (앱을 보고 있을 때는 애초에 띄우지 않는다)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async { completionHandler([.banner, .list, .sound]) }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let raw = response.notification.request.content.userInfo[Self.typeKey] as? String
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if let raw, let type = NotificationType(rawValue: raw) {
                    if let onOpen = self.onOpen { onOpen(type) } else { self.pendingOpen = type }
                }
            }
            completionHandler()
        }
    }
}
