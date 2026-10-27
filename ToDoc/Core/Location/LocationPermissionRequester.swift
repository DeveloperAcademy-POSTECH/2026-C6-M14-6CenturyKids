//
//  LocationPermissionRequester.swift
//  ToDoc
//
//  Created by seokho on 10/27/26.
//

import CoreLocation

/// 위치 권한을 이어서 묻는다: '앱을 사용하는 동안'을 고르면 곧바로 '항상 허용으로 변경'을,
/// '항상 허용'으로 바꾸면 곧바로 알림 권한을 묻는다. 한 번 허용·허용 안 함이면 더 묻지 않는다
final class LocationPermissionRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let notifications: LocalNotificationRouter
    private var step = Step.idle
    /// 권한이 바뀔 때마다 (앱이 켜질 때 한 번도 불린다)
    var onChange: ((CLAuthorizationStatus) -> Void)?

    private enum Step { case idle, askedWhenInUse, askedAlways }

    init(notifications: LocalNotificationRouter) {
        self.notifications = notifications
        super.init()
        manager.delegate = self
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }

    /// 아직 고르지 않았을 때만 첫 번째 창을 띄운다 (한 번 허용은 앱을 다시 켜면 고르지 않은 상태로 돌아온다)
    func requestIfNeeded() {
        guard manager.authorizationStatus == .notDetermined else { return }
        step = .askedWhenInUse
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch (step, status) {
        case (.askedWhenInUse, .authorizedWhenInUse):
            // 한 번 허용도 같은 상태로 오지만, 이때는 iOS가 두 번째 창을 띄우지 않는다
            step = .askedAlways
            manager.requestAlwaysAuthorization()
        case (.askedAlways, .authorizedAlways):
            step = .idle
            Task { await notifications.requestAuthorization() }
        case (_, .notDetermined):
            break
        default:
            step = .idle
        }
        onChange?(status)
    }
}
