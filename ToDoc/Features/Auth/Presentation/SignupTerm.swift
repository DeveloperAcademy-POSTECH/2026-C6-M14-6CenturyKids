import Foundation

nonisolated enum SignupTerm: CaseIterable, Hashable, Identifiable, Sendable {
    case service, privacy, sensitiveInformation, doctorConnection, thirdPartyProvision
    var id: Self { self }
    var isRequired: Bool { true }
    var title: String {
        switch self {
        case .service: "서비스 이용약관"
        case .privacy: "개인정보 수집·이용 동의"
        case .sensitiveInformation: "건강정보(민감정보) 수집·이용 동의"
        case .doctorConnection: "의료진·병원 연결 절차 동의"
        case .thirdPartyProvision: "의료진·병원 개인정보 제공 동의"
        }
    }
    var fullTitle: String {
        let agreement: String
        switch self {
        case .service: agreement = "서비스 이용약관에 동의합니다."
        case .privacy: agreement = "개인정보 수집·이용에 동의합니다."
        case .sensitiveInformation: agreement = "건강정보(민감정보)의 수집·이용에 동의합니다."
        case .doctorConnection: agreement = "의료진·병원 연결 절차에 동의합니다."
        case .thirdPartyProvision: agreement = "연결된 의료진·병원에 대한 개인정보 제공에 동의합니다."
        }
        return "[필수] \(agreement)"
    }
}
