import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 앱 시작 지점에서 정해 주는 값입니다. 약관과 URL의 임의 기본값을 만들지 않습니다.
nonisolated struct AuthConfiguration {
    var terms: [SignupTerm: String] = [:]
    var termsVersion: String?
    var redirectURL: URL?

    var hasRequiredTerms: Bool {
        guard let termsVersion, !termsVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return SignupTerm.allCases.filter(\.isRequired).allSatisfy { hasContent(for: $0) }
    }
    func hasContent(for term: SignupTerm) -> Bool {
        !(terms[term]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
    /// 쿼리/fragment에는 일회용 토큰이 실릴 수 있으므로 주소의 고정 부분만 비교합니다.
    /// 토큰의 진위는 여기서 판정하지 않고 AuthCallbackRepository가 서버와 확인합니다.
    func accepts(_ url: URL) -> Bool {
        guard let redirectURL,
              let expected = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false),
              let actual = URLComponents(url: url, resolvingAgainstBaseURL: false),
              expected.scheme != nil, actual.user == nil, actual.password == nil else { return false }
        return actual.scheme?.lowercased() == expected.scheme?.lowercased()
            && actual.host?.lowercased() == expected.host?.lowercased()
            && actual.port == expected.port && actual.path == expected.path
    }
}

/// 구체 DB 클래스 대신 계약을 받습니다. 팀원이 구현체를 완성하면 DI 한 곳에서 넘기면 됩니다.
/// nil은 '미연결'이며 성공하는 가짜 저장소로 대체하지 않습니다.
nonisolated struct AuthRepositories {
    var auth: (any AuthRepository)?
    var users: (any UserRepository)?
    var patients: (any PatientRepository)?
    var doctors: (any DoctorRepository)?
    var hospitals: (any HospitalRepository)?
    var consents: (any SignupConsentRepository)?
    var callbacks: (any AuthCallbackRepository)?
}

/// 서버 오류 원문에는 주소나 내부 정보가 들어갈 수 있어 그대로 화면에 노출하지 않습니다.
/// 사용자가 해결할 수 있는 상황은 VM이 아래처럼 구체적인 한국어로 바꿉니다.
nonisolated struct AuthFlowError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

extension SignupTerm {
    /// DB에 보낼 안정적인 식별자입니다. 화면의 한글 제목이 바뀌어도 저장 값은 유지합니다.
    var consentID: String {
        switch self {
        case .service: "service"
        case .privacy: "privacy"
        case .sensitiveInformation: "sensitiveInformation"
        case .notifications: "notifications"
        }
    }
}
