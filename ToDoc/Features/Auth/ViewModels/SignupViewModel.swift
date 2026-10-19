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

    /// 동의 저장과 가입 완료 판정이 합의되기 전에는 부분 계정/프로필도 만들지 않습니다.
    func submit() async {
        guard !state.isWorking, state.step == .review else { return }
        state.errorMessage = "회원가입 연결을 준비 중이에요. 입력한 정보는 아직 저장되지 않았어요."
    }

    func resendConfirmation() async {
        guard !state.isWorking else { return }
        state.errorMessage = "가입 인증 메일 연결을 준비 중이에요. 아직 메일을 요청하지 않았어요."
    }

    func cancel() { requestID = nil }
    private var normalizedCode: String { state.doctorCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private func isCurrent(_ token: UUID) -> Bool { requestID == token && !Task.isCancelled }
}
