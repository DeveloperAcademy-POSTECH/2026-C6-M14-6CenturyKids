#if DEBUG
import Foundation

/// 이 파일의 저장소는 이 Preview 팩토리에서만 생성합니다. 앱 DI·서버·디스크에 연결하지 않습니다.
@MainActor enum AuthInteractivePreviewData {
    static func makeFlow() -> AuthFlowViewModel {
        let directory = PreviewDoctorDirectory()
        let repositories = AuthRepositories(
            auth: PreviewSignupAuth(), users: PreviewSignupUsers(), patients: PreviewSignupPatients(),
            doctors: directory, hospitals: directory, consents: PreviewSignupConsents()
        )
        let terms = Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { term in
            (term, """
            화면 확인용 예시 · 실제 약관이 아닙니다.

            \(term.title)

            약관 상세를 열고 닫거나, 동의를 선택한 뒤 다음 가입 화면으로 이동하는 흐름을 확인할 수 있습니다.
            이 Preview의 입력과 동의는 메모리에서만 처리되며 서버 저장, 계정 생성, 이메일 전송이 발생하지 않습니다.
            ‘처음부터’를 누르거나 Preview를 다시 실행하면 체험 데이터를 초기화합니다.
            """
            )
        })
        let flow = AuthFlowViewModel(
            repositories: repositories,
            configuration: .init(terms: terms, termsVersion: "preview-only", redirectURL: URL(string: "todoc-preview://auth/callback")),
            loginPreference: AuthLoginPreference()
        )
        fillExample(flow)
        return flow
    }

    /// 입력 편의를 위한 값이며 약관 동의와 현재 화면은 바꾸지 않습니다.
    static func fillExample(_ flow: AuthFlowViewModel) {
        let state = flow.signup.state
        guard !state.isWorking, !state.isAccountLocked else { return }
        state.name = "김예시"
        state.email = "preview@example.com"
        state.password = "Preview123!"
        state.passwordConfirmation = "Preview123!"
        state.birthday = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 15))
        state.sex = .female
        state.cancerType = .lung
        state.otherCancer = ""
        state.stage = .known(.stage1)
        // 코드의 확인 여부는 실제 SignupVM이 관리하므로 입력값만 제공합니다.
        if state.connection == nil { state.doctorCode = "PRE123" }
    }
}

private final class PreviewSignupAuth: AuthRepository {
    private var currentID: UUID?
    func signUp(email: String, password: String) async throws -> UUID {
        let id = UUID()
        currentID = id
        return id
    }
    func signOut() async throws { currentID = nil }
    func getCurrentUserId() async throws -> UUID {
        guard let currentID else { throw AuthFlowError("Preview 가입 세션이 없어요.") }
        return currentID
    }
    func isSignedIn() -> Bool { currentID != nil }

    // 가입 이후 로그인/재설정은 이번 체험 범위 밖이며 성공을 흉내 내지 않습니다.
    private var unsupported: AuthFlowError { AuthFlowError("가입 화면 체험용 Preview예요. 위의 ‘처음부터’로 다시 확인할 수 있어요.") }
    func signIn(email: String, password: String) async throws -> UUID { throw unsupported }
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID { throw unsupported }
    func resendSignUpConfirmationEmail(to email: String, redirectTo url: URL?) async throws { throw unsupported }
    func requestPasswordChangeVerification() async throws { throw unsupported }
    func sendPasswordResetEmail(to email: String, redirectTo url: URL?) async throws { throw unsupported }
    func updatePassword(to newPassword: String, nonce: String?) async throws { throw unsupported }
}

private final class PreviewSignupUsers: UserRepository {
    private var values: [UUID: User] = [:]
    func save(user: User) async throws { values[user.id] = user }
    func findById(_ id: UUID) async throws -> User? { values[id] }
    func findByName(_ name: String) async throws -> [User] { values.values.filter { $0.name == name } }
}

private final class PreviewSignupPatients: PatientRepository {
    private var values: [UUID: Patient] = [:]
    func save(patient: Patient) async throws { values[patient.user.id] = patient }
    func findById(_ id: UUID) async throws -> Patient? { values[id] }
    func findByName(_ name: String) async throws -> [Patient] { values.values.filter { $0.user.name == name } }
    func findByDoctorId(_ doctorId: UUID) async throws -> [Patient] { values.values.filter { $0.doctorId == doctorId } }
}

private final class PreviewSignupConsents: SignupConsentRepository {
    private var values: [UUID: (version: String, terms: [String], date: Date)] = [:]
    func saveConsent(userID: UUID, version: String, acceptedTermIDs: [String], acceptedAt: Date) async throws {
        values[userID] = (version, acceptedTermIDs, acceptedAt)
    }
}

/// PRE123 확인과 ‘지금은 건너뛰기’ 두 경로를 모두 체험할 수 있습니다.
private final class PreviewDoctorDirectory: DoctorRepository, HospitalRepository {
    private let hospitalID = UUID()
    private let doctorID = UUID()
    private func hospital() throws -> Hospital {
        try Hospital(id: hospitalID, name: "예시 병원", code: "PRE123", address: "경상북도 포항시 예시로 1")
    }
    private func doctor() throws -> Doctor {
        let user = try User(id: doctorID, name: "예시 의사", birthday: Date(timeIntervalSince1970: 315532800), sex: .female)
        return Doctor(user: user, code: "PRE123", hospitalId: hospitalID)
    }
    func save(doctor: Doctor) async throws { throw AuthFlowError("Preview에서는 의사 정보를 수정하지 않아요.") }
    func findById(_ id: UUID) async throws -> Doctor? { id == doctorID ? try doctor() : nil }
    func findByName(_ name: String) async throws -> [Doctor] { name == "예시 의사" ? [try doctor()] : [] }
    func findByHospitalId(_ hospitalId: UUID) async throws -> [Doctor] { hospitalId == hospitalID ? [try doctor()] : [] }
    func findByCode(_ code: String) async throws -> Doctor? { code.uppercased() == "PRE123" ? try doctor() : nil }
    func findById(_ id: UUID) async throws -> Hospital? { id == hospitalID ? try hospital() : nil }
    func findByName(_ name: String) async throws -> [Hospital] { name == "예시 병원" ? [try hospital()] : [] }
    func findByCode(_ code: String) async throws -> Hospital? { code.uppercased() == "PRE123" ? try hospital() : nil }
    func searchByAddress(_ keyword: String) async throws -> [Hospital] { [try hospital()].filter { $0.address.contains(keyword) } }
}
#endif
