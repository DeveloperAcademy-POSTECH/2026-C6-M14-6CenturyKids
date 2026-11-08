//
//  LocalNotificationDelegate.swift
//  ToDoc
//
//  Created by seokho on 10/27/26.
//

import Foundation
import UserNotifications

/// 알림을 누르면 알림에 담긴 주소의 화면으로 보내고, 앱을 보고 있을 때도 알림을 띄웁니다.
final class LocalNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    // 두 메서드는 async 버전을 쓰지 않습니다: async 버전은 끝났다는 신호를 메인 스레드 밖에서 보내 UIKit이 앱을 종료시킵니다.

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let link = response.notification.request.content.userInfo[LocalNotificationAdapter.deepLinkKey] as? String
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.open(link) }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async { completionHandler([.banner, .list, .sound]) }
    }

    private func open(_ link: String?) {
        guard let link, let url = URL(string: link), let deepLink = DeepLink(url: url) else { return }
        router.handle(deepLink)
    }
}
