//
//  NotificationSettingsViewModel.swift
//  ToDoc
//
//  Created by 허지우 on 10/19/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class NotificationSettingsViewModel {
    @ObservationIgnored private let defaults: UserDefaults
    private static let timeKey = "notification.liveActivityTimeMinutes"
    /// 선택 가능한 알림 시간: 20:00~23:59 (자정부터 분 단위)
    static let allowedMinutes = (20 * 60)..<(24 * 60)

    private(set) var savedTime = DateComponents(hour: 20, minute: 0)
    private(set) var selectedTime = DateComponents(hour: 20, minute: 0)
    private(set) var hasStoredTime = false
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var errorMessage: String?

    var hasChanges: Bool { selectedTime != savedTime }
    var canSave: Bool {
        hasLoaded && !isLoading && !isSaving && (!hasStoredTime || hasChanges)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadTime() {
        guard !isLoading, !isSaving else { return }

        isLoading = true
        hasLoaded = false
        didSave = false
        errorMessage = nil
        defer { isLoading = false }

        let defaultTime = DateComponents(hour: 20, minute: 0)

        guard let stored = defaults.object(forKey: Self.timeKey) else {
            savedTime = defaultTime
            selectedTime = defaultTime
            hasStoredTime = false
            hasLoaded = true
            return
        }

        guard let minutes = stored as? Int,
              (0..<1440).contains(minutes) else {
            savedTime = defaultTime
            selectedTime = defaultTime
            hasStoredTime = false
            hasLoaded = true
            errorMessage = "저장된 알림 시간을 읽을 수 없어요. 다시 설정해 주세요."
            return
        }

        // 범위가 생기기 전에 저장된 값은 기본값으로 보여 주고 다시 저장할 수 있게 둔다.
        guard Self.allowedMinutes.contains(minutes) else {
            savedTime = defaultTime
            selectedTime = defaultTime
            hasStoredTime = false
            hasLoaded = true
            return
        }

        let time = DateComponents(hour: minutes / 60, minute: minutes % 60)
        savedTime = time
        selectedTime = time
        hasStoredTime = true
        hasLoaded = true
    }

    func selectTime(_ time: DateComponents) {
        guard hasLoaded, !isLoading, !isSaving else { return }

        guard let hour = time.hour, (0..<24).contains(hour),
              let minute = time.minute, (0..<60).contains(minute),
              Self.allowedMinutes.contains(hour * 60 + minute) else {
            errorMessage = "알림 시간을 다시 선택해 주세요."
            return
        }

        selectedTime = DateComponents(hour: hour, minute: minute)
        didSave = false
        errorMessage = nil
    }

    func saveTime() {
        guard canSave,
              let hour = selectedTime.hour,
              let minute = selectedTime.minute else { return }

        isSaving = true
        didSave = false
        errorMessage = nil
        defer { isSaving = false }

        let minutesSinceMidnight = hour * 60 + minute
        defaults.set(minutesSinceMidnight, forKey: Self.timeKey)

        savedTime = selectedTime
        hasStoredTime = true
        didSave = true
    }
}
