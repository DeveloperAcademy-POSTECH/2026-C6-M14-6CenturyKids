//
//  NotificationSettingsDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/26/26.
//

import Foundation

struct NotificationSettingsDTO: Codable {
    let userId: UUID
    let notificationTime: String
    let timezone: String
    let isEnabled: Bool
}

extension NotificationSettingsDTO {
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case notificationTime = "notification_time"
        case timezone
        case isEnabled = "is_enabled"
    }
}
