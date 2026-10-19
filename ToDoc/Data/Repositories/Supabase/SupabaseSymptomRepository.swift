//
//  SupabaseSymptomRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/19/26.
//

import Foundation
import Supabase

final class SupabaseSymptomRepository: SymptomRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    private let recordWithEntriesColumns =
        """
        id,
        patient_id,
        date,
        recorded_at,
        condition,
        entries:symptom_entries(id, symptom_record_id, type, part, side, raw_location, presence, duration, count, detail)
        """
    
    func save(entity: SymptomRecord) async throws {
        let date = DateOnlyFormatter.string(from: entity.recordedDate)
        
        let params = SaveSymptomRecordParams(
            pId: entity.id,
            pPatientId: entity.patientId,
            pDate: date,
            pRecordedAt: entity.recordedDate,
            pCondition: entity.conditionText,
            pSymptoms: entity.symptoms.map {
                SymptomEntryParam(symptomEntry: $0)
            }
        )
        
        try await client
            .rpc("save_symptom_record", params: params)
            .execute()
    }
    
    func findById(_ id: UUID) async throws -> SymptomRecord? {
        let dtos: [SymptomRecordWithEntriesDTO] = try await client
            .from("symptom_records")
            .select(recordWithEntriesColumns)
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        
        guard let dto = dtos.first else {
            return nil
        }
        
        return try dto.toDomain()
    }
    
    func findByPatientId(_ patientId: UUID) async throws -> [SymptomRecord] {
        let dtos: [SymptomRecordWithEntriesDTO] = try await client
            .from("symptom_records")
            .select(recordWithEntriesColumns)
            .eq("patient_id", value: patientId)
            .order("date", ascending: false)
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [SymptomRecord] {
        let start = DateOnlyFormatter.string(from: startDate)
        let end = DateOnlyFormatter.string(from: endDate)
        
        let dtos: [SymptomRecordWithEntriesDTO] = try await client
            .from("symptom_records")
            .select(recordWithEntriesColumns)
            .eq("patient_id", value: patientId)
            .gte("date", value: start)
            .lt("date", value: end)
            .order("date", ascending: true)
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func deleteById(_ id: UUID) async throws {
        try await client
            .from("symptom_records")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
