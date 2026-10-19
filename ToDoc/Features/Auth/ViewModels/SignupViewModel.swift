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
    private var draft: Draft?
    private var accountID: UUID?
    private var attemptedAccountCreation = false
    private var savedUser = false
    private var savedConsent = false
    private var savedPatient = false

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
            state.errorMessage = "의사 연결을 준비 중이에요. 지금은 건너뛰고 가입할 수 있어요."; return
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

    /// 계정 생성과 사용자/환자/동의 저장은 서로 다른 요청입니다. 계정 생성 응답만으로 완료하지 않습니다.
    /// 성공한 단계는 기억하고, 실패한 단계부터 같은 UUID로 재시도합니다. DB 구현체도 upsert가 필요합니다.
    func submit() async {
        guard !state.isWorking, state.step == .review else { return }
        state.errorMessage = nil
        guard let auth = repositories.auth, let users = repositories.users,
              let patients = repositories.patients, let consents = repositories.consents else {
            state.errorMessage = "가입 정보 저장 연결을 준비 중이에요. 사용자·환자·약관 동의 저장소 연결 후 가입할 수 있어요."; return
        }
        if draft == nil {
            for step in [SignupStep.role, .name, .email, .password, .passwordConfirmation, .terms, .patientInfo, .cancerType, .cancerStage] {
                if let error = validationError(for: step) { state.errorMessage = error; return }
            }
            guard configuration.redirectURL != nil else {
                state.errorMessage = "인증 이메일의 앱 복귀 주소를 준비 중이에요."; return
            }
            guard normalizedCode.isEmpty || (verifiedDoctorCode == normalizedCode && verifiedDoctorID != nil) else {
                state.errorMessage = "의사 코드를 다시 확인하거나 건너뛰기를 선택해 주세요."; return
            }
        }
        guard let token = session.begin() else {
            state.errorMessage = "이전 인증 요청이 끝난 뒤 다시 시도해 주세요."; return
        }
        requestID = token; state.isWorking = true
        // 가입 확인을 위한 일시적인 세션은 다음 실행의 자동 로그인 대상으로 남기지 않습니다.
        session.loginPreference.isEnabled = false
        defer { state.isWorking = false; session.finish(token) }
        do {
            if draft == nil { draft = try makeDraft() }
            guard let draft else { return }
            state.isAccountLocked = true
            if !attemptedAccountCreation {
                // 요청이 실패해도 서버에는 계정이 만들어졌을 수 있습니다. 호출 전에 시도 사실을 기억합니다.
                attemptedAccountCreation = true
                accountID = try await auth.signUp(email: draft.email, password: draft.password)
                try checkCurrent(token)
                if !auth.isSignedIn() {
                    state.isAwaitingEmailConfirmation = true
                    state.errorMessage = "이메일 인증을 마친 뒤 ‘확인 후 가입 이어가기’를 눌러 주세요. 아직 가입 정보 저장은 완료되지 않았어요."
                    return
                }
            } else {
                // 확인 메일 대기/실패/취소 후에는 계정을 또 생성하지 않고 같은 자격으로 로그인합니다.
                let signedInID = try await auth.signIn(email: draft.email, password: draft.password)
                if let accountID, signedInID != accountID { throw AuthFlowError("가입 계정이 일치하지 않아요. 로그인 화면에서 계정을 확인해 주세요.") }
                accountID = signedInID
            }
            try checkCurrent(token)
            guard let id = accountID, try await auth.getCurrentUserId() == id else {
                throw AuthFlowError("인증된 계정을 확인하지 못했어요. 이메일 인증 후 다시 시도해 주세요.")
            }
            try checkCurrent(token)
            state.isAwaitingEmailConfirmation = false
            let user = try User(id: id, name: draft.name, birthday: draft.birthday, sex: draft.sex)
            let patient = Patient(user: user, doctorId: draft.doctorID, disease: draft.disease)
            // 기존 프로필을 발견했을 때 다른 가입 입력으로 덮어쓰지 않습니다.
            if !savedUser {
                if let existing = try await users.findById(id) {
                    guard sameUser(existing, user) else { throw AuthFlowError("이미 저장된 계정 정보가 달라요. 로그인 화면에서 기존 계정을 확인해 주세요.") }
                } else {
                    try checkCurrent(token); try await users.save(user: user)
                }
                savedUser = true
            }
            try checkCurrent(token)
            if !savedConsent {
                try await consents.saveConsent(userID: id, version: draft.version, acceptedTermIDs: draft.termIDs, acceptedAt: draft.acceptedAt)
                savedConsent = true
            }
            try checkCurrent(token)
            if !savedPatient {
                if let existing = try await patients.findById(id) {
                    guard samePatient(existing, patient) else { throw AuthFlowError("이미 저장된 환자 정보가 달라요. 기존 계정으로 로그인해 주세요.") }
                } else {
                    try checkCurrent(token); try await patients.save(patient: patient)
                }
                savedPatient = true
            }
            try checkCurrent(token)
            guard let storedUser = try await users.findById(id), sameUser(storedUser, user),
                  let storedPatient = try await patients.findById(id), samePatient(storedPatient, patient) else {
                throw AuthFlowError("저장 결과를 아직 확인하지 못했어요. 잠시 후 가입을 이어서 진행해 주세요.")
            }
            try checkCurrent(token)
            // 현재 디자인은 '가입 완료 → 로그인'입니다. 가입용 세션이 홈 진입으로 새지 않게 정리합니다.
            try await auth.signOut()
            try checkCurrent(token)
            state.password = ""; state.passwordConfirmation = ""; self.draft = nil
            state.step = .completion
        } catch {
            // 계정 ID/저장 진행률은 보존하되, 실패한 가입 세션으로 앱에 들어가지는 않습니다.
            do { if auth.isSignedIn() { try await auth.signOut() } }
            catch { state.errorMessage = "인증 상태 정리를 완료하지 못했어요. 연결을 확인한 뒤 가입을 이어가 주세요." }
            if isCurrent(token), state.errorMessage == nil {
                state.errorMessage = (error as? AuthFlowError)?.message ?? "가입이 아직 끝나지 않았어요. 이메일 인증·네트워크를 확인한 뒤 같은 정보로 이어서 진행해 주세요."
            }
        }
    }

    func resendConfirmation() async {
        guard !state.isWorking, state.isAwaitingEmailConfirmation,
              let auth = repositories.auth, let draft, let url = configuration.redirectURL,
              let token = session.begin() else { return }
        requestID = token; state.isWorking = true
        defer { state.isWorking = false; session.finish(token) }
        do {
            try await auth.resendSignUpConfirmationEmail(to: draft.email, redirectTo: url)
            if isCurrent(token) { state.errorMessage = "인증 메일을 다시 요청했어요. 메일함과 스팸함을 확인해 주세요." }
        } catch {
            if isCurrent(token) { state.errorMessage = "인증 메일을 요청하지 못했어요. 잠시 후 다시 시도해 주세요." }
        }
    }

    func cancel() { requestID = nil }
    private var normalizedCode: String { state.doctorCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private func isCurrent(_ token: UUID) -> Bool { requestID == token && !Task.isCancelled }
    private func checkCurrent(_ token: UUID) throws { if !isCurrent(token) { throw CancellationError() } }
    private func sameUser(_ a: User, _ b: User) -> Bool {
        // 기존 UserDTO는 생일의 시각을 저장하지 않습니다. 오전/오후가 없어져도 같은 날짜면 같은 생일입니다.
        a.id == b.id && a.name == b.name && Calendar.current.isDate(a.birthday, inSameDayAs: b.birthday) && a.sex == b.sex
    }
    private func samePatient(_ a: Patient, _ b: Patient) -> Bool {
        sameUser(a.user, b.user) && a.doctorId == b.doctorId && a.disease == b.disease
    }
    private func makeDraft() throws -> Draft {
        guard let birthday = state.birthday, let sex = state.sex, let cancer = state.cancerType,
              case .known(let stage) = state.stage, let version = configuration.termsVersion else {
            throw AuthFlowError("가입 정보를 다시 확인해 주세요.")
        }
        return Draft(email: AuthFormValidation.email(state.email), password: state.password,
                     name: state.name.trimmingCharacters(in: .whitespacesAndNewlines), birthday: birthday, sex: sex,
                     disease: .init(carcinoma: cancer, stage: stage), doctorID: verifiedDoctorID,
                     version: version, termIDs: state.acceptedTerms.map(\.consentID).sorted(), acceptedAt: Date())
    }
    /// 재시도를 위한 메모리 스냅샷입니다. 비밀번호는 디스크/UserDefaults/로그에 저장하지 않습니다.
    /// 앱 종료를 넘어 가입을 복구하는 기능은 서버의 가입 상태/트랜잭션 계약이 필요합니다.
    private struct Draft {
        let email: String, password: String, name: String
        let birthday: Date
        let sex: Sex
        let disease: CarcinomaDetail
        let doctorID: UUID?
        let version: String
        let termIDs: [String]
        let acceptedAt: Date
    }
}
