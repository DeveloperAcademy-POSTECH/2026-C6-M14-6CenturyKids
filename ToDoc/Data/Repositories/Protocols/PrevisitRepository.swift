//
//  PrevisitRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/31/26.
//

import Foundation

protocol PrevisitRepository: RecordRepository where Entity == PrevisitRecord {
    func findByPatientIdAndDate(patientId: UUID, date: Date) async throws -> PrevisitRecord?
}
