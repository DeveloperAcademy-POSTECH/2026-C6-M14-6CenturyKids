//
//  HospitalArrivalService.swift
//  ToDoc
//
//  Created by seokho on 10/27/26.
//

import CoreLocation
import UIKit

/// 환자와 연결된 병원 반경에 들어오면 진료 전 기록 알림을 하루 한 번 알림 목록에 남긴다.
/// 항상 허용이고 앱을 보고 있지 않으면 잠금화면 알림도 띄운다 (앱이 꺼져 있으면 iOS가 앱을 깨워 넘긴다).
/// 앱을 사용하는 동안만 허용이면 iOS가 앱을 보고 있을 때만 넘겨 준다
final class HospitalArrivalService {
    static let radius: CLLocationDistance = 200
    static let body = "병원에 가셨나요? 진료 받기 전 기록해보세요"
    private static let monitorName = "HospitalArrival"
    /// 지금 이 기기에 로그인한 환자. 다른 환자의 감시가 남아 있어도 그 도착은 저장·알림하지 않는다
    private static let patientKey = "hospitalArrival.patientId"

    private let notifications: any NotificationRepository
    private let localNotifications: LocalNotificationRouter
    private let patients: any PatientRepository
    private let doctors: any DoctorRepository
    private let hospitals: any HospitalRepository
    private let defaults: UserDefaults
    private var monitorTask: Task<CLMonitor, Never>?
    private var listening: Task<Void, Never>?
    private var updating: Task<Void, Never>?
    /// 알림을 남긴 뒤 (홈 종 표시를 다시 읽는다)
    var onSaved: (() -> Void)?

    init(notifications: any NotificationRepository, localNotifications: LocalNotificationRouter,
         patients: any PatientRepository, doctors: any DoctorRepository, hospitals: any HospitalRepository,
         defaults: UserDefaults = .standard) {
        self.notifications = notifications
        self.localNotifications = localNotifications
        self.patients = patients
        self.doctors = doctors
        self.hospitals = hospitals
        self.defaults = defaults
    }

    /// 앱이 켜지자마자 부른다. 앱이 꺼진 채 병원에 들어가 iOS가 앱을 깨웠을 때 이벤트를 받으려면 같은 이름으로 다시 열어야 한다
    func start() {
        guard listening == nil else { return }
        listening = Task {
            let monitor = await monitor()
            do {
                for try await event in await monitor.events where event.state == .satisfied {
                    await arrive(event.identifier)
                }
            } catch {
                print("병원 도착 감시 실패: ", error)
            }
        }
    }

    /// 로그인한 환자의 병원을 감시한다. 권한이 없거나 연결된 병원·좌표가 없으면 감시를 멈춘다.
    /// 병원을 읽지 못했으면(네트워크 등) 이 환자의 감시만 그대로 둔다.
    /// 권한 창이 이어서 뜨면 연달아 불리므로 차례로 처리한다 (겹치면 같은 병원을 두 번 등록해 알림이 두 번 갈 수 있다)
    func update(patientId: UUID, authorized: Bool) async {
        defaults.set(patientId.uuidString, forKey: Self.patientKey)
        let previous = updating
        let work = Task {
            await previous?.value
            await apply(patientId: patientId, authorized: authorized)
        }
        updating = work
        await work.value
    }

    /// 로그아웃하면 바로 로그인 환자 표시를 지워 이후 도착을 무시하고, 감시를 모두 멈춘다
    func stop() {
        defaults.removeObject(forKey: Self.patientKey)
        let previous = updating
        updating = Task {
            await previous?.value
            let monitor = await monitor()
            for identifier in await monitor.identifiers { await monitor.remove(identifier) }
        }
    }

    private func apply(patientId: UUID, authorized: Bool) async {
        let monitor = await monitor()
        let target: (id: UUID, center: CLLocationCoordinate2D)?
        do {
            target = authorized ? try await hospitalCenter(of: patientId) : nil
        } catch {
            print("병원 위치 조회 실패: ", error)
            // 다른 환자의 감시는 남기지 않는다
            for identifier in await monitor.identifiers where !identifier.hasPrefix(patientId.uuidString) {
                await monitor.remove(identifier)
            }
            return
        }
        let wanted = target.map { Self.identifier(patientId: patientId, hospitalId: $0.id) }
        for identifier in await monitor.identifiers where identifier != wanted {
            await monitor.remove(identifier)
        }
        guard let target, let wanted else { return }
        let existing = await monitor.record(for: wanted)?.condition as? CLMonitor.CircularGeographicCondition
        guard existing?.center.latitude != target.center.latitude || existing?.center.longitude != target.center.longitude
                || existing?.radius != Self.radius else { return }
        // 병원 좌표가 바뀌었으면 새로 등록한다. 이미 반경 안에서 처음 등록해도 들어온 것으로 본다
        await monitor.remove(wanted)
        await monitor.add(CLMonitor.CircularGeographicCondition(center: target.center, radius: Self.radius),
                          identifier: wanted, assuming: .unsatisfied)
    }

    private func monitor() async -> CLMonitor {
        if let monitorTask { return await monitorTask.value }
        let task = Task { await CLMonitor(Self.monitorName) }
        monitorTask = task
        return await task.value
    }

    private func hospitalCenter(of patientId: UUID) async throws -> (id: UUID, center: CLLocationCoordinate2D)? {
        guard let doctorId = try await patients.findById(patientId)?.doctorId,
              let hospitalId = try await doctors.findById(doctorId)?.hospitalId,
              let hospital = try await hospitals.findById(hospitalId),
              let latitude = hospital.latitude, let longitude = hospital.longitude else { return nil }
        return (hospital.id, CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }

    private func arrive(_ identifier: String) async {
        let ids = identifier.split(separator: "/").compactMap { UUID(uuidString: String($0)) }
        guard ids.count == 2 else { return }
        guard defaults.string(forKey: Self.patientKey) == ids[0].uuidString else {
            await monitor().remove(identifier)
            return
        }
        // iOS가 한 번 들어온 것을 몇 초 간격으로 여러 번 넘기기도 해서, 하루에 한 번만 남긴다
        let notifiedToday = (try? await notifications.findByUserId(ids[0]))?
            .contains { $0.type == .previsitReminder && Calendar.current.isDateInToday($0.createdAt) } ?? false
        guard !notifiedToday else { return }
        let notification = AppNotification(id: UUID(), type: .previsitReminder,
                                           title: NotificationType.previsitReminder.displayName, body: Self.body,
                                           targetId: ids[1], createdAt: .now, readAt: nil)
        do {
            try await notifications.save(notification: notification, for: ids[0])
            onSaved?()
        } catch {
            print("병원 도착 알림 저장 실패: ", error)
        }
        guard CLLocationManager().authorizationStatus == .authorizedAlways,
              UIApplication.shared.applicationState != .active else { return }
        do {
            try await localNotifications.post(notification)
        } catch {
            print("병원 도착 알림 띄우기 실패: ", error)
        }
    }

    private static func identifier(patientId: UUID, hospitalId: UUID) -> String {
        "\(patientId.uuidString)/\(hospitalId.uuidString)"
    }
}
