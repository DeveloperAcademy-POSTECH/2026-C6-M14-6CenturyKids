//
//  SupabaseNotificationSettingsRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/26/26.
//

import Foundation
import Supabase

final class SupabaseNotificationSettingsRepository: NotificationSettingsRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    private let columns = "user_id, notification_time, timezone, is_enabled"
    
    func fetch(userId: UUID) async throws -> NotificationSettingsDTO? {
        let dtos: [NotificationSettingsDTO] = try await client
            .from("notification_settings")
            .select(columns)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        guard let dto = dtos.first else { return nil }
        
        return dto
    }
    
    func save(settings: NotificationSettingsDTO) async throws {
        try await client
            .from("notification_settings")
            .upsert(settings, onConflict: "user_id")
            .execute()
    }
}
