import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

@MainActor final class SignupViewModel {
    let state = SignupScreenState()
    let repositories: AuthRepositories
    let session: AuthSessionState
    let configuration: AuthConfiguration
    init(repositories: AuthRepositories, session: AuthSessionState, configuration: AuthConfiguration) {
        self.repositories = repositories; self.session = session; self.configuration = configuration
        state.termsContent = configuration.terms; state.hasRequiredTermsContent = configuration.hasRequiredTerms
        state.onAction = { [weak self] action in self?.handle(action) }
    }
    private var requestID: UUID?
    private var verifiedDoctorID: UUID?
    private var verifiedDoctorCode: String?
    private var accountID: UUID?
    private var creationAttempted = false
    private var draft: Draft?
    private(set) var completedPatient: Patient?
    private struct Draft {
        let email: String
        let password: String
        let user: User
        let disease: CarcinomaDetail
        let doctorID: UUID?
    }
    /// 최종 확인에서 연 수정 화면은 입력을 마치거나 돌아갈 때 최종 확인으로 복귀합니다.
    private var reviewEditStart: SignupStep?
    /// View는 어떤 버튼이 눌렸는지만 전달합니다. 다음 단계와 검증은 이곳에서 결정합니다.
    func handle(_ action: SignupAction) {
        if case .cancel = action { cancel(); return }
        guard !state.isWorking else { return }
        switch action {
        case .submit: Task { await submit() }
        case .resendConfirmation: Task { await resendConfirmation() }
        case .verifyDoctorCode: Task { await verifyDoctorCode() }
        default:
            guard !state.isAccountLocked else {
                state.errorMessage = "계정 생성을 시작한 정보로 가입을 이어가고 있어요. 아래 버튼으로 다시 시도해 주세요."
                return
            }
            state.errorMessage = nil; state.currentValidationError = nil
            switch action {
            case .next: next()
            case .back: back()
            case .skipDoctorCode:
                verifiedDoctorID = nil; verifiedDoctorCode = nil
                state.doctorCode = ""; state.connection = nil; state.step = .review
            case .changeDoctorCode:
                verifiedDoctorID = nil; verifiedDoctorCode = nil; state.connection = nil; state.step = .doctorCode
            case .editBasicInfo: reviewEditStart = .patientInfo; state.step = .patientInfo
            case .editDiagnosis: reviewEditStart = .cancerType; state.step = .cancerType
            default: break
            }
        }
    }

    private func next() {
        state.hasAttemptedStep = true
        state.currentValidationError = validationError(for: state.step)
        guard state.currentValidationError == nil else { return }
        state.hasAttemptedStep = false
        switch state.step {
        case .passwordConfirmation where configuration.isLocalSignupTest:
            state.step = .patientInfo
        case .patientInfo where reviewEditStart == .patientInfo,
             .cancerStage where reviewEditStart == .cancerType:
            reviewEditStart = nil; state.step = .review
        case .doctorCode: return // 조회와 건너뛰기는 각자의 명시적인 버튼만 처리합니다.
        case .review, .completion: return
        default: state.step = SignupStep(rawValue: state.step.rawValue + 1) ?? state.step
        }
    }
    private func back() {
        state.hasAttemptedStep = false
        if state.step == reviewEditStart {
            reviewEditStart = nil; state.step = .review
            return
        }
        switch state.step {
        case .patientInfo where configuration.isLocalSignupTest: state.step = .passwordConfirmation
        case .review: state.step = state.connection == nil ? .doctorCode : .doctorConfirmation
        case .completion, .role: break
        default: state.step = SignupStep(rawValue: state.step.rawValue - 1) ?? .role
        }
    }

    /// '기타/모름'을 DB가 표현하지 못하는 동안 임의의 암종·병기로 바꾸어 저장하지 않습니다.
    /// 팀에서 해당 Model/DB 계약을 정하면 이 검증과 Draft 변환만 확장하면 됩니다.
    private func validationError(for step: SignupStep) -> String? {
        switch step {
        case .role: return state.isPatient ? nil : "의사 가입은 iPad용 흐름 연결 후 이용할 수 있어요."
        case .name: return AuthFormValidation.nameError(state.name)
        case .email: return AuthFormValidation.emailError(state.email)
        case .password: return AuthFormValidation.passwordError(state.password)
        case .passwordConfirmation: return state.passwordMatches ? nil : "비밀번호가 일치하지 않아요."
        case .terms:
            if configuration.isLocalSignupTest { return nil }
            guard configuration.hasRequiredTerms else { return "약관 본문과 버전을 준비 중이에요. 준비 후 가입할 수 있어요." }
            guard SignupTerm.allCases.filter(\.isRequired).allSatisfy(state.acceptedTerms.contains) else { return "필수 약관에 동의해 주세요." }
            return state.acceptedTerms.allSatisfy(configuration.hasContent(for:)) ? nil : "선택한 약관의 본문을 준비 중이에요."
        case .patientInfo:
            if let error = AuthFormValidation.nameError(state.name) { return error }
            guard let birthday = state.birthday, let sex = state.sex else { return "생년월일과 성별을 선택해 주세요." }
            do { _ = try User(id: UUID(), name: state.name, birthday: birthday, sex: sex); return nil }
            catch { return "생년월일과 이름을 확인해 주세요. 미래 날짜는 선택할 수 없어요." }
        case .cancerType:
            return state.usesOtherCancer ? "직접 입력한 암 이름은 저장 형식 연결을 준비 중이에요." : (state.cancerType == nil ? "암 종류를 선택해 주세요." : nil)
        case .cancerStage:
            if case .known = state.stage { return nil }
            return state.stage == nil ? "병기를 선택해 주세요." : "모름·직접 입력 병기는 저장 형식 연결을 준비 중이에요."
        default: return nil
        }
    }

    /// 코드 확인은 의사와 소속 병원을 함께 읽습니다. 검증된 의사의 ID만 최종 Patient에 넣습니다.
    func verifyDoctorCode() async {
        guard !state.isWorking, !state.isAccountLocked else { return }
        let code = normalizedCode
        state.errorMessage = nil; state.hasAttemptedStep = true
        guard code.range(of: "^[A-Z0-9]{6}$", options: .regularExpression) != nil else {
            state.currentValidationError = "영문·숫자 6자리 코드를 입력해 주세요."; return
        }
        state.currentValidationError = nil
        guard let doctors = repositories.doctors, let hospitals = repositories.hospitals else {
            state.errorMessage = "의사 연결을 준비 중이에요. 건너뛰고 다음 화면을 확인할 수 있어요."; return
        }
        let token = UUID(); requestID = token; state.isWorking = true
        defer { state.isWorking = false }
        do {
            guard let doctor = try await doctors.findByCode(code), doctor.code.uppercased() == code,
                  let hospital = try await hospitals.findById(doctor.hospitalId), hospital.id == doctor.hospitalId else {
                throw AuthFlowError("해당 코드의 의사와 병원을 찾지 못했어요. 코드를 확인해 주세요.")
            }
            guard isCurrent(token), normalizedCode == code else { return }
            verifiedDoctorID = doctor.user.id; verifiedDoctorCode = code
            state.connection = SignupDoctorConnection(hospitalName: hospital.name, department: nil, doctorName: doctor.user.name)
            state.step = .doctorConfirmation
        } catch {
            if isCurrent(token) { state.errorMessage = (error as? AuthFlowError)?.message ?? "의사 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요." }
        }
    }

    /// 계정 생성 → 기존 정보 확인·저장 → Patient 조회로 완료를 확인합니다. 성공 세션은 유지합니다.
    func submit() async {
        guard !state.isWorking, state.step == .review else { return }
        state.errorMessage = nil
        guard configuration.allowsSignupRequests,
              let auth = repositories.auth, let users = repositories.users, let patients = repositories.patients else {
            state.errorMessage = "회원가입 연결을 준비 중이에요. 입력한 정보는 아직 저장되지 않았어요."
            return
        }
        guard session.patient == nil, accountID != nil || !auth.isSignedIn() else {
            state.errorMessage = "로그인된 계정이 있어요. 현재 계정을 확인한 뒤 가입해 주세요."
            return
        }
        guard !creationAttempted || accountID != nil else {
            state.errorMessage = "가입 요청 결과를 확인하지 못했어요. 다시 가입하기 전에 로그인으로 계정을 확인해 주세요."
            return
        }
        if draft == nil {
            let required: [SignupStep] = [.role, .name, .email, .password, .passwordConfirmation, .terms, .patientInfo, .cancerType, .cancerStage]
            for step in required {
                if let error = validationError(for: step) { state.errorMessage = error; return }
            }
            guard normalizedCode.isEmpty || (verifiedDoctorCode == normalizedCode && verifiedDoctorID != nil),
                  let birthday = state.birthday, let sex = state.sex, let cancer = state.cancerType,
                  case .known(let stage) = state.stage,
                  let user = try? User(id: UUID(), name: state.name, birthday: birthday, sex: sex) else {
                state.errorMessage = "입력한 정보와 의사 코드를 다시 확인해 주세요."
                return
            }
            draft = Draft(email: AuthFormValidation.email(state.email), password: state.password, user: user,
                          disease: CarcinomaDetail(carcinoma: cancer, stage: stage), doctorID: verifiedDoctorID)
        }
        guard let draft else { return }
        guard let token = session.begin() else {
            // 아직 가입 요청을 시작하지 않았다면 다음 제출에서 수정한 입력을 다시 검증합니다.
            if !creationAttempted { self.draft = nil }
            state.errorMessage = "이전 인증 요청을 마무리하고 있어요. 잠시 후 다시 시도해 주세요."
            return
        }
        requestID = token; state.isWorking = true; state.isAccountLocked = true
        defer { session.finish(token); state.isWorking = false }
        let isContinuation = accountID != nil
        do {
            if accountID == nil {
                // 응답 유실도 계정 생성 가능성이 있으므로 같은 요청을 자동 반복하지 않습니다.
                creationAttempted = true
                session.loginPreference.isEnabled = false
                accountID = try await auth.signUp(email: draft.email, password: draft.password)
            }
            try checkCurrent(token)
            guard let id = accountID else { throw AuthFlowError("가입한 계정을 확인하지 못했어요.") }
            if !auth.isSignedIn() {
                state.isAwaitingEmailConfirmation = true
                guard isContinuation else {
                    throw AuthFlowError("이메일의 가입 확인을 마친 뒤 ‘확인 후 가입 이어가기’를 눌러 주세요.")
                }
                let signedInID = try await auth.signIn(email: draft.email, password: draft.password)
                try checkCurrent(token)
                guard signedInID == id else { throw AuthFlowError("가입한 계정과 로그인한 계정이 달라요.") }
            }
            let currentID = try await auth.getCurrentUserId()
            try checkCurrent(token)
            guard currentID == id else { throw AuthFlowError("가입한 계정의 인증을 확인하지 못했어요.") }
            state.isAwaitingEmailConfirmation = false
            let user = try User(id: id, name: draft.user.name, birthday: draft.user.birthday, sex: draft.user.sex)
            let patient = Patient(user: user, doctorId: draft.doctorID, disease: draft.disease)

            let existingUser = try await users.findById(id)
            try checkCurrent(token)
            if let existingUser {
                guard matches(existingUser, user) else { throw profileConflict() }
            } else {
                try await users.save(user: user)
                try checkCurrent(token)
            }
            let existingPatient = try await patients.findById(id)
            try checkCurrent(token)
            if let existingPatient {
                guard matches(existingPatient, patient) else { throw profileConflict() }
            } else {
                try await patients.save(patient: patient)
                try checkCurrent(token)
            }
            let storedPatient = try await patients.findById(id)
            try checkCurrent(token)
            guard let storedPatient, matches(storedPatient, patient) else { throw profileConflict() }
            // Patient.findById가 User를 함께 반환하므로 별도의 User 재조회는 필요하지 않습니다.
            completedPatient = storedPatient
            state.email = draft.email
            state.password = ""; state.passwordConfirmation = ""
            self.draft = nil
            state.step = .completion
        } catch {
            if isCurrent(token) {
                state.errorMessage = (error as? AuthFlowError)?.message ?? "가입을 마치지 못했어요. 입력한 정보를 유지했으니 연결을 확인한 뒤 다시 시도해 주세요."
            }
        }
    }

    private func matches(_ actual: User, _ expected: User) -> Bool {
        actual.id == expected.id && actual.name == expected.name && actual.sex == expected.sex &&
            Calendar(identifier: .gregorian).isDate(actual.birthday, inSameDayAs: expected.birthday)
    }
    private func matches(_ actual: Patient, _ expected: Patient) -> Bool {
        matches(actual.user, expected.user) && actual.doctorId == expected.doctorId && actual.disease == expected.disease
    }
    private func profileConflict() -> AuthFlowError {
        AuthFlowError("저장된 가입 정보를 확인하지 못했어요. 가입을 반복하지 말고 저장 상태를 확인해 주세요.")
    }
    private func checkCurrent(_ token: UUID) throws {
        guard isCurrent(token) else { throw CancellationError() }
    }

    func resendConfirmation() async {
        guard !state.isWorking else { return }
        state.errorMessage = "가입 인증 메일 연결을 준비 중이에요. 아직 메일을 요청하지 않았어요."
    }

    func cancel() { requestID = nil }
    private var normalizedCode: String { state.doctorCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private func isCurrent(_ token: UUID) -> Bool { requestID == token && !Task.isCancelled }
}
