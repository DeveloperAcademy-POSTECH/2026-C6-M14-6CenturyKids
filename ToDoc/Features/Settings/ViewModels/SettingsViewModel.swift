//
//  SettingsViewModel.swift
//  ToDoc
//
//  Created by 허지우 on 10/18/26.
//

import Foundation
import Observation
import enum Auth.AuthError

@MainActor
@Observable
final class SettingsViewModel {
    let patientId: UUID
    let screenState = SettingsScreenState()
    let personalInfoState = PersonalInfoScreenState()
    let passwordChangeState = PasswordChangeScreenState()
    let carcinomaState = DiagnosisScreenState()
    let stageState = DiagnosisScreenState()
    let hospitalConnectionState = HospitalConnectionScreenState()

    @ObservationIgnored private let authRepository: any AuthRepository
    @ObservationIgnored private let authSession: AuthSessionState
    @ObservationIgnored private let userRepository: any UserRepository
    @ObservationIgnored private let patientRepository: any PatientRepository
    @ObservationIgnored private let doctorRepository: any DoctorRepository
    @ObservationIgnored private let hospitalRepository: any HospitalRepository
    @ObservationIgnored private var passwordChangeEmail: String?

    init(
        patientId: UUID,
        authRepository: any AuthRepository,
        authSession: AuthSessionState,
        userRepository: any UserRepository,
        patientRepository: any PatientRepository,
        doctorRepository: any DoctorRepository,
        hospitalRepository: any HospitalRepository
    ) {
        self.patientId = patientId
        self.authRepository = authRepository
        self.authSession = authSession
        self.userRepository = userRepository
        self.patientRepository = patientRepository
        self.doctorRepository = doctorRepository
        self.hospitalRepository = hospitalRepository

        personalInfoState.onLoad = { [weak self] in
            Task { await self?.loadPersonalInfo() }
        }
        
        screenState.onReload = { [weak self] in
            Task { [weak self] in
                await self?.loadProfile()
            }
        }

        screenState.onLogout = { [weak self] in
            Task { [weak self] in
                await self?.signOut()
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

        passwordChangeState.onSendCode = { [weak self] in
            Task { [weak self] in
                await self?.sendPasswordChangeCode()
            }
        }

        passwordChangeState.onContinue = { [weak self] in
            await self?.continuePasswordChange() ?? false
        }

        passwordChangeState.onInputChanged = { [weak self] in
            self?.validatePasswordInputs()
        }

        passwordChangeState.onSave = { [weak self] in
            Task { [weak self] in
                await self?.changePassword()
            }
        }

        passwordChangeState.onCancel = { [weak self] in
            self?.discardPasswordChange()
        }

        carcinomaState.onLoad = { [weak self] in
            Task { await self?.loadDiagnosis(.carcinoma) }
        }

        carcinomaState.onSave = { [weak self] in
            Task { [weak self] in
                await self?.saveDiagnosis(.carcinoma)
            }
        }

        carcinomaState.onCancel = { [weak self] in
            self?.discardDiagnosisChanges(.carcinoma)
        }

        carcinomaState.onBeginCustomCancer = { [weak self] in
            self?.beginCustomCarcinomaEntry()
        }

        carcinomaState.onCancelCustomCancer = { [weak self] in
            self?.cancelCustomCarcinomaEntry()
        }

        carcinomaState.onSaveCustomCancer = { [weak self] in
            Task { [weak self] in
                await self?.saveCustomCarcinoma()
            }
        }

        stageState.onLoad = { [weak self] in
            Task { await self?.loadDiagnosis(.stage) }
        }

        stageState.onSave = { [weak self] in
            Task { [weak self] in
                await self?.saveDiagnosis(.stage)
            }
        }

        stageState.onCancel = { [weak self] in
            self?.discardDiagnosisChanges(.stage)
        }

        hospitalConnectionState.onAction = { [weak self] action in
            switch action {
            case .load:
                Task { [weak self] in await self?.loadHospitalConnection() }
            case .verify:
                Task { [weak self] in await self?.verifyDoctorCode() }
            case .connect:
                Task { [weak self] in await self?.connectDoctor() }
            case .disconnect:
                Task { [weak self] in await self?.disconnectDoctor() }
            case .cancel:
                self?.discardHospitalConnectionChanges()
            }
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

    func loadHospitalConnection() async {
        let state = hospitalConnectionState
        guard !state.isBusy else { return }

        state.isBusy = true
        state.hasLoaded = false
        state.doctor = nil
        state.candidate = nil
        state.candidateDoctorId = nil
        state.code = ""
        state.canConnect = false
        state.canDisconnect = false
        state.errorMessage = nil
        state.successMessage = nil
        defer { state.isBusy = false }

        do {
            guard let patient = try await patientRepository.findById(patientId) else {
                state.errorMessage = "환자 정보를 찾지 못했어요."
                return
            }

            guard let doctorId = patient.doctorId else {
                state.hasLoaded = true
                return
            }

            guard let doctor = try await doctorRepository.findById(doctorId),
                  let hospital = try await hospitalRepository.findById(doctor.hospitalId)
            else {
                state.errorMessage = "병원 연결 정보를 찾지 못했어요."
                return
            }

            state.doctor = DoctorDisplayData(
                hospitalName: hospital.name,
                name: doctor.user.name
            )
            state.canDisconnect = true
            state.hasLoaded = true
        } catch {
            state.errorMessage = "병원 연결 정보를 불러오지 못했어요."
        }
    }

    func verifyDoctorCode() async {
        let state = hospitalConnectionState
        guard state.canVerify else { return }

        let code = state.code.trimmingCharacters(in: .whitespacesAndNewlines)

        state.isBusy = true
        state.candidate = nil
        state.candidateDoctorId = nil
        state.canConnect = false
        state.errorMessage = nil
        state.successMessage = nil
        defer { state.isBusy = false }

        do {
            guard let patient = try await patientRepository.findById(patientId) else {
                state.errorMessage = "환자 정보를 찾지 못했어요."
                return
            }

            guard let doctor = try await doctorRepository.findConnectionInfoByCode(code) else { //요기바뀜
                state.errorMessage = "의사 코드를 확인해 주세요."
                return
            }

            guard state.code.trimmingCharacters(in: .whitespacesAndNewlines) == code else {
                return
            }

            state.candidateDoctorId = doctor.doctorId
            state.candidate = DoctorDisplayData(
                hospitalName: doctor.hospitalName,
                name: doctor.doctorName
            )
            state.canConnect = patient.doctorId != doctor.doctorId
        } catch {
            state.errorMessage = "연결 정보를 확인하지 못했어요. 다시 시도해 주세요."
        }
    }

    func connectDoctor() async {
        let state = hospitalConnectionState
        guard !state.isBusy,
              state.canConnect,
              state.candidateDoctorId != nil,
              let candidate = state.candidate else { return }

        let code = state.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        state.isBusy = true
        state.errorMessage = nil
        state.successMessage = nil
        defer { state.isBusy = false }

        do {
            try await patientRepository.connectToDoctor(code: code)

            state.doctor = candidate
            state.candidate = nil
            state.candidateDoctorId = nil
            state.canConnect = false
            state.canDisconnect = true
            state.code = ""
            state.successMessage = "병원 연결이 완료됐어요."

            await loadProfile()
        } catch {
            state.errorMessage = "병원을 연결하지 못했어요. 다시 시도해 주세요."
        }
    }

    func disconnectDoctor() async {
        let state = hospitalConnectionState
        guard !state.isBusy, state.canDisconnect else { return }

        state.isBusy = true
        state.errorMessage = nil
        state.successMessage = nil
        defer { state.isBusy = false }

        do {
            try await patientRepository.disconnectFromDoctor()

            state.doctor = nil
            state.candidate = nil
            state.candidateDoctorId = nil
            state.canConnect = false
            state.canDisconnect = false
            state.code = ""
            state.successMessage = "병원 연결이 해제됐어요."

            screenState.profile?.doctorName = nil
            screenState.profile?.hospitalName = nil
        } catch {
            state.errorMessage = "병원 연결을 해제하지 못했어요. 다시 시도해 주세요."
        }
    }

    func discardHospitalConnectionChanges() {
        let state = hospitalConnectionState
        guard !state.isBusy else { return }

        state.code = ""
        state.candidate = nil
        state.candidateDoctorId = nil
        state.canConnect = false
        state.errorMessage = nil
        state.successMessage = nil
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

    func signOut() async {
        guard !screenState.isSigningOut else { return }

        screenState.isSigningOut = true
        screenState.logoutErrorMessage = nil
        defer { screenState.isSigningOut = false }

        do {
            try await authRepository.signOut()
            authSession.loginPreference.isEnabled = false
            authSession.patient = nil
        } catch {
            screenState.logoutErrorMessage = "로그아웃하지 못했어요. 다시 시도해 주세요."
        }
    }

    // 재인증 코드(reauthenticate)는 서버가 최근 세션에서 확인하지 않고 따로 확인할 방법도 없어,
    // 확인할 수 있는 재설정 인증코드를 로그인한 이메일로 보냅니다.
    func sendPasswordChangeCode() async {
        let state = passwordChangeState
        guard !state.isSendingCode, !state.isVerifyingCode, !state.isSaving else { return }

        state.isSendingCode = true
        state.errorMessage = nil
        state.codeError = nil
        defer { state.isSendingCode = false }

        do {
            guard let email = try await authRepository.getCurrentUserEmail(), !email.isEmpty else {
                state.errorMessage = "가입한 이메일을 확인하지 못했어요. 다시 로그인해 주세요."
                return
            }
            try await authRepository.sendPasswordResetEmail(to: email, redirectTo: nil)
            passwordChangeEmail = email
            state.verificationCode = ""
            state.isCodeVerified = false
            state.hasSentCode = true
        } catch {
            state.errorMessage = (error as? AuthError)?.errorCode == .overEmailSendRateLimit
                ? "인증코드를 너무 자주 요청했어요. 잠시 후 다시 시도해 주세요."
                : "인증코드를 보내지 못했어요. 다시 시도해 주세요."
        }
    }

    /// 서버에서 인증코드를 확인한 뒤에만 새 비밀번호 화면으로 넘어갑니다.
    func continuePasswordChange() async -> Bool {
        let state = passwordChangeState
        guard !state.isSendingCode, !state.isVerifyingCode, !state.isSaving else { return false }
        if state.isCodeVerified { return true }

        state.codeError = nil
        state.errorMessage = nil

        guard state.hasSentCode, let email = passwordChangeEmail else {
            state.codeError = "인증코드를 먼저 요청해 주세요."
            return false
        }

        let code = state.verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            state.codeError = "인증코드를 입력해 주세요."
            return false
        }

        state.isVerifyingCode = true
        defer { state.isVerifyingCode = false }

        do {
            try await authRepository.verifyPasswordResetCode(email: email, code: code)
            state.isCodeVerified = true
            return true
        } catch {
            if (error as? AuthError)?.errorCode == .otpExpired {
                state.codeError = "인증코드가 올바르지 않거나 만료되었어요. 다시 확인해 주세요."
            } else {
                state.errorMessage = "인증코드를 확인하지 못했어요. 다시 시도해 주세요."
            }
            return false
        }
    }

    func validatePasswordInputs() {
        let state = passwordChangeState
        state.canSubmitPassword = false
        state.confirmationError = nil
        state.errorMessage = nil
        state.newPasswordError = state.newPassword.isEmpty
            ? nil
            : AuthFormValidation.passwordChangeError(state.newPassword)

        guard !state.newPassword.isEmpty,
              state.newPasswordError == nil,
              !state.passwordConfirmation.isEmpty else { return }

        guard state.newPassword == state.passwordConfirmation else {
            state.confirmationError = "새 비밀번호가 일치하지 않아요."
            return
        }

        state.canSubmitPassword = true
    }

    func changePassword() async {
        let state = passwordChangeState
        guard !state.isSaving, !state.isSendingCode, !state.isVerifyingCode else { return }

        state.didSave = false
        state.errorMessage = nil
        state.codeError = nil
        state.confirmationError = nil

        guard state.isCodeVerified else {
            state.codeError = "인증코드를 먼저 확인해 주세요."
            return
        }

        state.newPasswordError = AuthFormValidation.passwordChangeError(state.newPassword)
        guard state.newPasswordError == nil else { return }

        guard state.newPassword == state.passwordConfirmation else {
            state.confirmationError = "새 비밀번호가 일치하지 않아요."
            return
        }

        let newPassword = state.newPassword
        state.isSaving = true
        defer { state.isSaving = false }

        do {
            try await authRepository.updatePassword(to: newPassword, nonce: nil)
            state.verificationCode = ""
            state.newPassword = ""
            state.passwordConfirmation = ""
            state.canSubmitPassword = false
            state.isCodeVerified = false
            state.hasSentCode = false
            passwordChangeEmail = nil
            state.didSave = true
        } catch {
            switch (error as? AuthError)?.errorCode {
            case .some(.samePassword):
                state.newPasswordError = "기존 비밀번호와 다른 비밀번호를 입력해 주세요."
            case .some(.weakPassword):
                state.newPasswordError = "비밀번호 조건에 맞게 다시 입력해 주세요."
            default:
                state.errorMessage = "비밀번호를 변경하지 못했어요. 다시 시도해 주세요."
            }
        }
    }

    func discardPasswordChange() {
        guard !passwordChangeState.isSaving, !passwordChangeState.isSendingCode,
              !passwordChangeState.isVerifyingCode else { return }

        passwordChangeEmail = nil
        passwordChangeState.verificationCode = ""
        passwordChangeState.hasSentCode = false
        passwordChangeState.isCodeVerified = false
        passwordChangeState.codeError = nil

        passwordChangeState.newPassword = ""
        passwordChangeState.passwordConfirmation = ""
        passwordChangeState.newPasswordError = nil
        passwordChangeState.confirmationError = nil
        passwordChangeState.canSubmitPassword = false

        passwordChangeState.didSave = false
        passwordChangeState.errorMessage = nil
    }

    func beginCustomCarcinomaEntry() {
        guard carcinomaState.canSave, !carcinomaState.isSaving else { return }

        if case .carcinoma(let type)? = carcinomaState.selection,
           !CarcinomaType.allCases.contains(type) {
            carcinomaState.customCancerName = type.rawValue
        } else {
            carcinomaState.customCancerName = ""
        }
        carcinomaState.errorMessage = nil
    }

    func cancelCustomCarcinomaEntry() {
        guard !carcinomaState.isSaving else { return }

        carcinomaState.customCancerName = ""
        carcinomaState.errorMessage = nil
    }

    func saveCustomCarcinoma() async {
        guard carcinomaState.canSaveCustomCancer,
              let type = CarcinomaType(name: carcinomaState.customCancerName) else { return }

        await persistDiagnosis(.carcinoma, selection: .carcinoma(type))
    }

    func saveDiagnosis(_ field: DiagnosisField) async {
        let state: DiagnosisScreenState
        switch field {
        case .carcinoma: state = carcinomaState
        case .stage: state = stageState
        }

        guard state.canSave, let selection = state.selection else { return }

        await persistDiagnosis(field, selection: selection)
    }

    private func persistDiagnosis(_ field: DiagnosisField, selection: DiagnosisChange) async {
        let state: DiagnosisScreenState
        switch field {
        case .carcinoma: state = carcinomaState
        case .stage: state = stageState
        }

        guard !state.isSaving else { return }

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
            state.selection = selection
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
