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

    func loadProfile() async {
        guard !screenState.isLoading else { return }

        screenState.isLoading = true
        screenState.loadState = .loading
        screenState.canEdit = false
        defer { screenState.isLoading = false }

        do {
            guard let patient = try await patientRepository.findById(patientId) else {
                screenState.profile = nil
                screenState.loadState = .missingProfile
                return
            }

            guard let disease = patient.disease else {
                screenState.profile = nil
                screenState.loadState = .failed
                return
            }

            var profile = ProfileDisplayData(
                name: patient.user.name,
                cancerName: disease.carcinoma.displayName,
                stageName: disease.stage.displayName,
                hospitalName: nil,
                doctorName: nil
            )

            if let doctorId = patient.doctorId {
                guard let doctor = try await doctorRepository.findById(doctorId),
                      let hospital = try await hospitalRepository.findById(doctor.hospitalId)
                else {
                    screenState.profile = nil
                    screenState.loadState = .failed
                    return
                }

                profile.doctorName = doctor.user.name
                profile.hospitalName = hospital.name
            }

            screenState.profile = profile
            screenState.loadState = .loaded
            screenState.canEdit = true
        } catch {
            screenState.profile = nil
            screenState.loadState = .failed
        }
    }
}
