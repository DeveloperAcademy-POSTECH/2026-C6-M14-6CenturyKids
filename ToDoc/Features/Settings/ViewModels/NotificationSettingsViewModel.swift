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
    private(set) var savedTime = DateComponents(hour: 20, minute: 0)
    private(set) var selectedTime = DateComponents(hour: 20, minute: 0)
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var errorMessage: String?

    var hasChanges: Bool { selectedTime != savedTime }
    var canSave: Bool { hasLoaded && hasChanges && !isLoading && !isSaving }
}
