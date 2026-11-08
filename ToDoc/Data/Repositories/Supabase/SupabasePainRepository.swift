//
//  SupabasePainRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/18/26.
//

import Foundation
import Supabase

final class SupabasePainRepository: PainRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    private let recordColumns = "id, patient_id, occurred_at, pain_before, pain_after"
    private let locationColumns = "pain_record_id, part, side, view"
    private let recordWithLocationsColumns =
        """
        id,
        patient_id,
        occurred_at,
        pain_before,
        pain_after,
        locations:pain_locations(pain_record_id, part, side, view)
        """
    
    func save(entity: PainRecord) async throws {
        let params = SavePainRecordParams(
            pId: entity.id,
            pPatientId: entity.patientId,
            pOccurredAt: entity.recordedDate,
            pPainBefore: entity.painBefore,
            pPainAfter: entity.painAfter,
            pLocations: entity.location.map {
                PainLocationParam(bodyLocation: $0)
            }
        )
        
        try await client
            .rpc("save_pain_record", params: params)
            .execute()
    }
    
    func findById(_ id: UUID) async throws -> PainRecord? {
        let recordDTOs: [PainRecordDTO] = try await client
            .from("pain_records")
            .select(recordColumns)
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        
        guard let recordDTO = recordDTOs.first else {
            return nil
        }
        
        let locationDTOs: [PainLocationDTO] = try await client
            .from("pain_locations")
            .select(locationColumns)
            .eq("pain_record_id", value: id)
            .execute()
            .value
        
        let locations = try locationDTOs.map { try $0.toDomain() }
        
        return try recordDTO.toDomain(locations: locations)
    }
    
    func findByPatientId(_ patientId: UUID) async throws -> [PainRecord] {
        let dtos: [PainRecordWithLocationsDTO] = try await client
            .from("pain_records")
            .select(recordWithLocationsColumns)
            .eq("patient_id", value: patientId)
            .order("occurred_at", ascending: false)
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func findByPatientIdAndDate(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [PainRecord] {
        let calendar = Calendar.current
        
        let start = calendar.startOfDay(for: startDate)
        
        guard let end = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: endDate)
        ) else {
            throw DateConversionError.dayAddingError
        }
        
        let dtos: [PainRecordWithLocationsDTO] = try await client
            .from("pain_records")
            .select(recordWithLocationsColumns)
            .eq("patient_id", value: patientId)
            .gte("occurred_at", value: start)
            .lt("occurred_at", value: end)
            .order("occurred_at", ascending: true)
            .execute()
            .value
        
        return try dtos.map { try $0.toDomain() }
    }
    
    func findLatestByPatientId(_ patientId: UUID) async throws -> PainRecord? {
        let dtos: [PainRecordWithLocationsDTO] = try await client
            .from("pain_records")
            .select(recordWithLocationsColumns)
            .eq("patient_id", value: patientId)
            .order("occurred_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return try dtos.first?.toDomain()
    }
    
    func savePainAfter(recordId: UUID, painAfter: Int) async throws {
        try await client
            .rpc("record_pain_after", params: SavePainAfterParams(pId: recordId, pPainAfter: painAfter))
            .execute()
    }
    
    func deleteById(_ id: UUID) async throws {
        try await client
            .from("pain_records")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
