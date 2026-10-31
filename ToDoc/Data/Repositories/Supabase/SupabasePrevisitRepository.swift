//
//  SupabasePrevisitRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/31/26.
//

import Foundation
import Supabase

final class SupabasePrevisitRepository: PrevisitRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    private let columns = "id, patient_id, selected_date, memo, state_of_mind, submitted_at"
    
    func save(entity: PrevisitRecord) async throws {
        let dto = PrevisitRecordDTO(previsitRecord: entity)
        
        try await client
            .from("previsit_records")
            .upsert(dto)
            .execute()
    }
    
    func findById(_ id: UUID) async throws -> PrevisitRecord? {
        let dtos: [PrevisitRecordDTO] = try await client
            .from("previsit_records")
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
    
    func findByPatientId(_ patientId: UUID) async throws -> [PrevisitRecord] {
        let dtos: [PrevisitRecordDTO] = try await client
            .from("previsit_records")
            .select(columns)
            .eq("patient_id", value: patientId)
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func findByPatientIdAndDate(patientId: UUID, date: Date) async throws -> PrevisitRecord? {
        let calendar = Calendar.current

        let start = calendar.startOfDay(for: date)

        guard let end = calendar.date(
            byAdding: .day,
            value: 1,
            to: start
        ) else {
            throw DateConversionError.dayAddingError
        }
        
        let dtos: [PrevisitRecordDTO] = try await client
            .from("previsit_records")
            .select(columns)
            .eq("patient_id", value: patientId)
            .gte("submitted_at", value: start)
            .lt("submitted_at", value: end)
            .order("submitted_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        guard let dto = dtos.first else {
            return nil
        }
        
        return try dto.toDomain()
    }
    
    func deleteById(_ id: UUID) async throws {
        try await client
            .from("previsit_records")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
