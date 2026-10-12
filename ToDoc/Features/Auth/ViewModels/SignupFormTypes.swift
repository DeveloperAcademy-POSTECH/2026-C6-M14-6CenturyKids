import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

enum SignupStep: Int, CaseIterable {
    case role, name, email, password, passwordConfirmation, terms
    case doctorCode, doctorConfirmation, patientInfo, cancerType, cancerStage, review, completion

    var progress: String {
        switch self {
        case .role: "1/5"
        case .name, .email, .password, .passwordConfirmation: "환자 · 2/5"
        case .terms: "환자 · 3/5"
        case .doctorCode, .doctorConfirmation: "환자 · 4/5"
        case .patientInfo: "환자 정보 · 1/3"
        case .cancerType: "환자 정보 · 2/3"
        case .cancerStage: "환자 정보 · 3/3"
        case .review: "환자 정보 확인"
        case .completion: "가입 완료"
        }
    }
}

nonisolated enum SignupTerm: CaseIterable, Hashable, Identifiable, Sendable {
    case service, privacy, sensitiveInformation, notifications
    var id: Self { self }
    var isRequired: Bool { self != .notifications }
    var title: String {
        switch self {
        case .service: "서비스 이용약관"
        case .privacy: "개인정보 수집 및 이용 동의"
        case .sensitiveInformation: "민감정보 수집 및 이용 동의"
        case .notifications: "서비스 알림 수신 동의"
        }
    }
    var fullTitle: String { "[\(isRequired ? "필수" : "선택")] \(title)" }
}

extension CarcinomaType {
    var title: String { displayName }
}

extension CarcinomaStage {
    var title: String { displayName }
}

extension Sex {
    var title: String { displayName }
}

enum SignupStageChoice: Equatable {
    case known(CarcinomaStage), unknown, other
}

/// Domain Doctor를 대체하지 않는 가입 전 코드 조회 표시 데이터입니다.
struct SignupDoctorConnection: Equatable, Sendable {
    let hospitalName: String
    let department: String?
    let doctorName: String
}

/// Service 어댑터가 매핑할 가입 입력입니다. 비밀번호는 메모리에서만 사용합니다.
/// 기타 표현과 동의 항목을 버리거나 임의의 서버 값으로 변환하지 않습니다.
struct SignupSubmission: Sendable {
    enum Cancer: Equatable, Sendable { case listed(CarcinomaType), other(String) }
    enum Stage: Equatable, Sendable { case known(CarcinomaStage), unknown, other(String) }
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
