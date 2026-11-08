import Foundation

enum SignupStep: Int, CaseIterable {
    case role, name, email, password, passwordConfirmation, terms
    case patientInfo, cancerType, cancerStage, doctorCode, doctorConfirmation, review, completion

    var progress: String {
        switch self {
        case .role: "1/7"
        case .name, .email, .password, .passwordConfirmation: "계정 정보 · 2/7"
        case .terms: "약관 동의 · 3/7"
        case .patientInfo: "기본 정보 · 4/7"
        case .cancerType, .cancerStage: "진단 정보 · 5/7"
        case .doctorCode, .doctorConfirmation: "의사 연결 · 6/7"
        case .review: "정보 확인 · 7/7"
        case .completion: "가입 완료"
        }
    }
}
