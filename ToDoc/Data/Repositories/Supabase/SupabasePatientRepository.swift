//
//  SupabasePatientRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/17/26.
//

import Foundation
import Supabase

final class SupabasePatientRepository: PatientRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    private let columns = "user_id, doctor_id, carcinoma_type, carcinoma_stage, user:users(id, name, birthday, sex)"
    
    func save(patient: Patient) async throws {
        try await client
            .from("patients")
            .upsert(PatientDTO(patient: patient))
            .execute()
    }
    
    func findById(_ id: UUID) async throws -> Patient? {
        let dtos: [PatientWithUserDTO] = try await client
            .from("patients")
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
    
    func findByName(_ name: String) async throws -> [Patient] {
        let dtos: [PatientWithUserDTO] = try await client
            .from("patients")
            .select(
                """
                user_id,
                doctor_id,
                carcinoma_type,
                carcinoma_stage,
                user:users!inner(id, name, birthday, sex)
                """
            )
            .ilike("user.name", pattern: "%\(name)%")
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func findByDoctorId(_ doctorId: UUID) async throws -> [Patient] {
        let dtos: [PatientWithUserDTO] = try await client
            .from("patients")
            .select(columns)
            .eq("doctor_id", value: doctorId)
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func connectToDoctor(code: String) async throws {
        try await client
            .rpc(
                "connect_patient_to_doctor",
                params: ["p_code": code]
            )
            .execute()
    }
}
