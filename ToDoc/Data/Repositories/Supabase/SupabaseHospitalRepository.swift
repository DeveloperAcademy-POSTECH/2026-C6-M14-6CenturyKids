//
//  SupabaseHospitalRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/17/26.
//

import Foundation
import Supabase

final class SupabaseHospitalRepository: HospitalRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    private let columns = "id, name, code, address"
    
    func findById(_ id: UUID) async throws -> Hospital? {
        let dtos: [HospitalDTO] = try await client
            .from("hospitals")
            .select(columns)
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        
        guard let dto = dtos.first else {
            return nil
        }
        
        return try dto.toDomain()
    }
    
    func findByName(_ name: String) async throws -> [Hospital] {
        let dtos: [HospitalDTO] = try await client
            .from("hospitals")
            .select(columns)
            .ilike("name", pattern: "%\(name)%")
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func findByCode(_ code: String) async throws -> Hospital? {
        let dtos: [HospitalDTO] = try await client
            .from("hospitals")
            .select(columns)
            .eq("code", value: code)
            .limit(1)
            .execute()
            .value
        
        guard let dto = dtos.first else {
            return nil
        }
        
        return try dto.toDomain()
    }
    
    func searchByAddress(_ keyword: String) async throws -> [Hospital] {
        let dtos: [HospitalDTO] = try await client
            .from("hospitals")
            .select(columns)
            .ilike("address", pattern: "%\(keyword)%")
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
}
