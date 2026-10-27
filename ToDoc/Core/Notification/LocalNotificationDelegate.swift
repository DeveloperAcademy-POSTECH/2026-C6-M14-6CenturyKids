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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let link = response.notification.request.content.userInfo[LocalNotificationAdapter.deepLinkKey] as? String
        await open(link)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func open(_ link: String?) {
        guard let link, let url = URL(string: link), let deepLink = DeepLink(url: url) else { return }
        router.handle(deepLink)
    }
}
