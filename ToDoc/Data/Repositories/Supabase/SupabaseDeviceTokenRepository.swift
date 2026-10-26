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
                onConflict: "user_id,installation_id,token_type,environment"
            )
            .execute()
    }
    
    func removeToken(userId: UUID, installationId: String) async throws {
        try await client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .eq("installation_id", value: installationId)
            .execute()
    }
    
    func testStartLiveActivity() async throws {
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        let responseText: String = try await client.functions.invoke(
            "start-live-activity",
            options: FunctionInvokeOptions(
                body: StartLiveActivityRequest(
                    installation_id: InstallationId.value,
                    environment: environment
                )
            ),
            decode: { data, response in
                print("Edge Function HTTP 상태:", response.statusCode)
                return String(decoding: data, as: UTF8.self)
            }
        )
        
        print("Edge Function 응답:", responseText)
    }
}

private nonisolated struct StartLiveActivityRequest: Encodable, Sendable {
    let installation_id: String
    let environment: String
}

private nonisolated struct StartLiveActivityResponse: Decodable, Sendable {
    let accepted: Bool
    let apnsStatus: Int
    let apnsResponse: String
}
