import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

extension CarcinomaType { var title: String { displayName } }
extension CarcinomaStage { var title: String { displayName } }
extension Sex { var title: String { displayName } }

/// Domain Doctor를 대체하지 않는 가입 전 코드 조회 표시 데이터입니다.
struct SignupDoctorConnection: Equatable, Sendable {
    let hospitalName: String
    let department: String?
    let doctorName: String
}

/// Service 어댑터가 매핑할 가입 입력입니다. 비밀번호는 메모리에서만 사용합니다.
/// 기타 표현과 동의 항목을 버리거나 임의의 서버 값으로 변환하지 않습니다.
struct SignupSubmission: Sendable {
    let email: String
    let password: String
    let name: String
    let birthday: Date
    let sex: Sex
    let cancer: Cancer
    let stage: Stage
    let doctorCode: String?
    let acceptedTerms: Set<SignupTerm>
}
