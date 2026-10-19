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

        let time = DateComponents(hour: minutes / 60, minute: minutes % 60)
        savedTime = time
        selectedTime = time
        hasStoredTime = true
        hasLoaded = true
    }
}
