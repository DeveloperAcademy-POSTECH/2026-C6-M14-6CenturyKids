//
//  PainRecordViewModel.swift
//  ToDoc
//
//  Created by 허지우 on 10/17/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class PainRecordViewModel {
    private let patientId: UUID
    private let painRepository: any PainRepository

    init(patientId: UUID, painRepository: any PainRepository) {
        self.patientId = patientId
        self.painRepository = painRepository
    }
}
