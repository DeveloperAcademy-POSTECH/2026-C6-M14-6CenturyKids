//
//  SupabaseDoctorRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/17/26.
//

import Foundation
import Supabase

final class SupabaseDoctorRepository: DoctorRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    private let columns = "user_id, hospital_id, code, user:users(id, name, birthday, sex)"
    
    func save(doctor: Doctor) async throws {
        try await client
            .from("doctors")
            .upsert(DoctorDTO(doctor: doctor))
            .execute()
    }
    
    func findById(_ id: UUID) async throws -> Doctor? {
        let dtos: [DoctorWithUserDTO] = try await client
            .from("doctors")
            .select(columns)
            .eq("user_id", value: id)
            .limit(1)
            .execute()
            .value
        
        guard let dto = dtos.first else {
            return nil
        }
        
        return try dto.toDomain()
    }
    
    func findByName(_ name: String) async throws -> [Doctor] {
        let dtos: [DoctorWithUserDTO] = try await client
            .from("doctors")
            .select(
                """
                user_id,
                hospital_id,
                code,
                user:users!inner(id, name, birthday, sex)
                """
            )
            .ilike("user.name", pattern: "%\(name)%")
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func findByHospitalId(_ hospitalId: UUID) async throws -> [Doctor] {
        let dtos: [DoctorWithUserDTO] = try await client
            .from("doctors")
            .select(columns)
            .eq("hospital_id", value: hospitalId)
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func findByCode(_ code: String) async throws -> Doctor? {
        let dtos: [DoctorWithUserDTO] = try await client
            .from("doctors")
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
}
