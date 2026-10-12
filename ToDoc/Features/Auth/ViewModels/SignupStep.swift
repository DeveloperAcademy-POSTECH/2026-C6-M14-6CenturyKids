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
