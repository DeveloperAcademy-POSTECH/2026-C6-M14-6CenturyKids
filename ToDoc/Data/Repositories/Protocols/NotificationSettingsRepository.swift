//
//  NotificationSettingsRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/26/26.
//

import Foundation

protocol NotificationSettingsRepository {
    func fetch(userId: UUID) async throws -> NotificationSettingsDTO?
    
    func save(settings: NotificationSettingsDTO) async throws
}
