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
    let personalInfoState = PersonalInfoScreenState()
    let carcinomaState = DiagnosisScreenState()
    let stageState = DiagnosisScreenState()

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

        screenState.onReload = { [weak self] in
            Task { [weak self] in
                await self?.loadProfile()
            }
        }

        personalInfoState.onSave = { [weak self] in
            Task { [weak self] in
                await self?.savePersonalInfo()
            }
        }

        personalInfoState.onCancel = { [weak self] in
            self?.discardPersonalInfoChanges()
        }

        carcinomaState.onSave = { [weak self] in
            Task { [weak self] in
                await self?.saveDiagnosis(.carcinoma)
            }
        }

        carcinomaState.onCancel = { [weak self] in
            self?.discardDiagnosisChanges(.carcinoma)
        }

        stageState.onSave = { [weak self] in
            Task { [weak self] in
                await self?.saveDiagnosis(.stage)
            }
        }

        stageState.onCancel = { [weak self] in
            self?.discardDiagnosisChanges(.stage)
        }
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

    func loadPersonalInfo() async {
        personalInfoState.canSave = false
        personalInfoState.didSave = false
        personalInfoState.validationMessage = nil
        personalInfoState.errorMessage = nil

        do {
            guard let patient = try await patientRepository.findById(patientId) else {
                personalInfoState.errorMessage = "환자 정보를 찾지 못했어요."
                return
            }

            personalInfoState.name = patient.user.name
            personalInfoState.birthday = patient.user.birthday
            personalInfoState.sex = patient.user.sex
            personalInfoState.canSave = true
        } catch {
            personalInfoState.errorMessage = "개인 정보를 불러오지 못했어요."
        }
    }

    func loadDiagnosis(_ field: DiagnosisField) async {
        let state: DiagnosisScreenState
        switch field {
        case .carcinoma: state = carcinomaState
        case .stage: state = stageState
        }

        state.selection = nil
        state.canSave = false
        state.didSave = false
        state.errorMessage = nil

        do {
            guard let patient = try await patientRepository.findById(patientId) else {
                state.errorMessage = "환자 정보를 찾지 못했어요."
                return
            }

            guard let disease = patient.disease else {
                state.errorMessage = "진단 정보를 찾지 못했어요."
                return
            }

            switch field {
            case .carcinoma: state.selection = .carcinoma(disease.carcinoma)
            case .stage: state.selection = .stage(disease.stage)
            }
            state.canSave = true
        } catch {
            state.errorMessage = "진단 정보를 불러오지 못했어요."
        }
    }

    func savePersonalInfo() async {
        guard personalInfoState.canSave,
              !personalInfoState.isSaving else { return }

        personalInfoState.isSaving = true
        personalInfoState.didSave = false
        personalInfoState.validationMessage = nil
        personalInfoState.errorMessage = nil
        defer { personalInfoState.isSaving = false }

        let name = personalInfoState.name
        let birthday = personalInfoState.birthday
        let sex = personalInfoState.sex

        do {
            guard var user = try await userRepository.findById(patientId) else {
                personalInfoState.errorMessage = "사용자 정보를 찾지 못했어요."
                return
            }

            do {
                try user.updateName(name)
                try user.updateBirthday(birthday)
                user.updateSex(sex)
            } catch {
                personalInfoState.validationMessage = "이름과 생년월일을 확인해 주세요."
                return
            }

            try await userRepository.save(user: user)
            screenState.profile?.name = user.name
            personalInfoState.didSave = true
        } catch {
            personalInfoState.errorMessage = "개인 정보를 저장하지 못했어요. 다시 시도해 주세요."
        }
    }

    func saveDiagnosis(_ field: DiagnosisField) async {
        let state: DiagnosisScreenState
        switch field {
        case .carcinoma: state = carcinomaState
        case .stage: state = stageState
        }

        guard state.canSave, !state.isSaving,
              let selection = state.selection else { return }

        state.isSaving = true
        state.didSave = false
        state.errorMessage = nil
        defer { state.isSaving = false }

        do {
            guard let patient = try await patientRepository.findById(patientId) else {
                state.errorMessage = "환자 정보를 찾지 못했어요."
                return
            }

            guard var disease = patient.disease else {
                state.errorMessage = "진단 정보를 찾지 못했어요."
                return
            }

            switch (field, selection) {
            case (.carcinoma, .carcinoma(let type)):
                disease.updateCarcinomaType(type)
            case (.stage, .stage(let stage)):
                disease.updateStage(stage)
            default:
                state.errorMessage = "선택한 진단 정보를 확인해 주세요."
                return
            }

            let updatedPatient = Patient(
                user: patient.user,
                doctorId: patient.doctorId,
                disease: disease
            )
            try await patientRepository.save(patient: updatedPatient)

            screenState.profile?.cancerName = disease.carcinoma.displayName
            screenState.profile?.stageName = disease.stage.displayName
            state.didSave = true
        } catch {
            state.errorMessage = "진단 정보를 저장하지 못했어요. 다시 시도해 주세요."
        }
    }

    func discardPersonalInfoChanges() {
        guard !personalInfoState.isSaving,
              !personalInfoState.didSave else { return }

        personalInfoState.name = ""
        personalInfoState.birthday = Date()
        personalInfoState.sex = .female
        personalInfoState.canSave = false
        personalInfoState.validationMessage = nil
        personalInfoState.errorMessage = nil
    }

    func discardDiagnosisChanges(_ field: DiagnosisField) {
        let state: DiagnosisScreenState
        switch field {
        case .carcinoma: state = carcinomaState
        case .stage: state = stageState
        }

        guard !state.isSaving, !state.didSave else { return }

        state.selection = nil
        state.canSave = false
        state.errorMessage = nil
    }
}
