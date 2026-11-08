import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

nonisolated struct AuthConfiguration {
    var redirectURL: URL? = URL(string: "todoc://auth/change-password")
    var allowsSignupRequests = true
}

nonisolated struct AuthRepositories {
    var auth: (any AuthRepository)?
    var users: (any UserRepository)?
    var patients: (any PatientRepository)?
    var doctors: (any DoctorRepository)?
    var hospitals: (any HospitalRepository)?
}

/// 서버 오류 원문에는 주소나 내부 정보가 들어갈 수 있어 그대로 화면에 노출하지 않습니다.
/// 사용자가 해결할 수 있는 상황은 VM이 아래처럼 구체적인 한국어로 바꿉니다.
nonisolated struct AuthFlowError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}
