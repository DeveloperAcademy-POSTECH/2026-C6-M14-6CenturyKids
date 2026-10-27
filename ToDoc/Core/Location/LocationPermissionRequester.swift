//
//  LocationPermissionRequester.swift
//  ToDoc
//
//  Created by seokho on 10/27/26.
//

import CoreLocation
import UIKit

/// 위치 권한을 이어서 묻는다: '앱을 사용하는 동안'을 고르면 곧바로 '항상 허용으로 변경'을 묻는다.
/// 위치 창이 모두 끝나면 무엇을 골랐든 알림 권한을 묻는다 (통증 기록 알림도 이 한 번으로 받는다). 한 번 고른 권한은 다시 묻지 않는다
final class LocationPermissionRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var step = Step.idle
    /// 권한이 바뀔 때마다 (앱이 켜질 때 한 번도 불린다)
    var onChange: ((CLAuthorizationStatus) -> Void)?

    private enum Step { case idle, askedWhenInUse, askedAlways }

    override init() {
        super.init()
        manager.delegate = self
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }

    /// 아직 고르지 않았을 때만 위치 창을 띄운다 (한 번 허용은 앱을 다시 켜면 고르지 않은 상태로 돌아온다).
    /// 위치를 이미 골랐으면 알림 권한만 묻는다 (알림도 이미 골랐으면 창이 뜨지 않는다)
    func requestIfNeeded() {
        guard manager.authorizationStatus == .notDetermined else {
            Task { await LocalNotificationAdapter.requestAuthorization() }
            return
        }
        step = .askedWhenInUse
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch (step, status) {
        case (_, .notDetermined), (.idle, _):
            break
        case (.askedWhenInUse, .authorizedWhenInUse):
            step = .askedAlways
            manager.requestAlwaysAuthorization()
            Task { await finishIfAlwaysAnswerMissing() }
        default:
            finish()
        }
        onChange?(status)
    }

    private func finish() {
        step = .idle
        Task { await LocalNotificationAdapter.requestAuthorization() }
    }

    /// '한 번 허용'이면 두 번째 창이 뜨지 않고, '사용하는 동안 유지'를 고르면 권한이 그대로라 위 메서드가 다시 불리지 않을 수 있다.
    /// 창이 뜨면 앱이 잠깐 비활성이 되므로, 1초 뒤에도 활성이면 창이 없는 것으로 보고, 아니면 창이 닫혀 다시 활성이 될 때 마친다
    private func finishIfAlwaysAnswerMissing() async {
        try? await Task.sleep(for: .seconds(1))
        if UIApplication.shared.applicationState != .active {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) { break }
        }
        guard step == .askedAlways else { return }
        finish()
    }
}
