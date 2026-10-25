//
//  SupabaseDeviceTokenRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/25/26.
//

import Foundation
import Supabase

final class SupabaseDeviceTokenRepository: DeviceTokenRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func save(token: DeviceTokenDTO) async throws {
        try await client
            .from("device_tokens")
            .upsert(
                token,
                onConflict: "user_id,installation_id,token_type"
            )
            .execute()
    }
    
    func delete(token: DeviceTokenDTO) async throws {
        let userId = token.userId
        let installationId = token.installationId
        
        try await client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .eq("installation_id", value: installationId)
            .execute()
    }
}
