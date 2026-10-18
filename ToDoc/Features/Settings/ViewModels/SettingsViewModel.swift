//
//  SettingsViewModel.swift
//  ToDoc
//
//  Created by 허지우 on 10/18/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    let patientId: UUID
    let screenState = SettingsScreenState()

    @ObservationIgnored private let userRepository: any UserRepository
    @ObservationIgnored private let patientRepository: any PatientRepository
    @ObservationIgnored private let doctorRepository: any DoctorRepository
    @ObservationIgnored private let hospitalRepository: any HospitalRepository

    init(
        patientId: UUID,
        userRepository: any UserRepository,
        patientRepository: any PatientRepository,
        doctorRepository: any DoctorRepository,
        hospitalRepository: any HospitalRepository
    ) {
        self.patientId = patientId
        self.userRepository = userRepository
        self.patientRepository = patientRepository
        self.doctorRepository = doctorRepository
        self.hospitalRepository = hospitalRepository
    }
}
