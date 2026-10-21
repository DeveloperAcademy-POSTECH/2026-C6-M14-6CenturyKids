import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 사용자 확정 약관을 기본 표시합니다. 가입 요청 활성화와 복귀 URL 설정은 별도입니다.
nonisolated struct AuthConfiguration {
    var terms: [SignupTerm: String] = SignupTermsContent.provided
    var termsVersion: String? = SignupTermsContent.version
    var termsEffectiveDate: String? = SignupTermsContent.effectiveDate
    var redirectURL: URL?
    /// 실제 가입 요청은 별도 활성화하며 약관 표시만으로 자동 허용하지 않습니다.
    /// 기본 제품 경로는 확인 전까지 요청하지 않으며, 로컬 검사는 별도로 활성화합니다.
    var allowsSignupRequests = false

    /// 승인 약관을 대신하지 않는, 사용자가 명시적으로 선택한 Debug 실서버 검사입니다.
    var isLocalSignupTest: Bool {
#if DEBUG
        localSignupTest
#else
        false
#endif
    }
#if DEBUG
    var localSignupTest = false
#endif

    var hasRequiredTerms: Bool {
        guard let termsVersion, !termsVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let termsEffectiveDate, !termsEffectiveDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return hasRequiredTermsContent && terms.values.allSatisfy {
            !$0.contains("[서비스명]") && !$0.contains("[운영사명]")
        }
    }
    var hasRequiredTermsContent: Bool {
        SignupTerm.allCases.filter(\.isRequired).allSatisfy { hasContent(for: $0) }
    }
    func hasContent(for term: SignupTerm) -> Bool {
        !(terms[term]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

}

/// 기존 Repository만 주입합니다. 신규 서버 계약은 합의 전까지 연결하지 않습니다.
/// nil은 '미연결'이며 성공하는 가짜 저장소로 대체하지 않습니다.
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

extension SignupTerm {
    /// 로컬 약관 본문 파일의 항목 식별자입니다. 서버 저장 계약을 정의하지 않습니다.
    nonisolated var catalogID: String {
        switch self {
        case .service: "service"
        case .privacy: "privacy"
        case .sensitiveInformation: "sensitiveInformation"
        case .doctorConnection: "doctorConnection"
        case .thirdPartyProvision: "thirdPartyProvision"
        }
    }
}
