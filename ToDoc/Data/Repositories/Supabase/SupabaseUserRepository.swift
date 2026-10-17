//
//  SupabaseUserRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/17/26.
//

import Foundation
import Supabase

final class SupabaseUserRepository: UserRepository {
    
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func save(user: User) async throws {
        let dto = UserDTO(user: user)
        
        try await client
            .from("users")
            .upsert(dto)
            .execute()
    }
    
    func findById(_ id: UUID) async throws -> User? {
        let dtos: [UserDTO] = try await client
            .from("users")
            .select(
                """
                id,
                name,
                birthday,
                sex
                """
            )
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        
        guard let dto = dtos.first else {
            return nil
        }
        
        return try dto.toDomain()
    }
    
    func findByName(_ name: String) async throws -> [User] {
        let dtos: [UserDTO] = try await client
            .from("users")
            .select(
                """
                id,
                name,
                birthday,
                sex
                """
            )
            .ilike("name", pattern: "%\(name)%")
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
}
